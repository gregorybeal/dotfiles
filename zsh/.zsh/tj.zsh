# tj.zsh — one front door for all your tools.
#
# Source this from ~/.zshrc (after compinit). It builds its menu from tag
# comments in your own scripts, so the catalog can't drift from the code.
#
#   Scripts (bash/zsh/python, executable, in $TJ_PATHS) — one tag line, name = filename:
#     # tj: Create a Jira ticket from an .eml file | jmail ~/Downloads/foo.eml
#
#   Functions in sourced zsh files (listed in $TJ_FN_FILES):
#     # tj-fn: fssh | SSH to a register picked with fzf | fssh 0123
#
#   Anything else (aliases, lnav, one-liners) — one line per tool in $TJ_EXTRAS:
#     lnav-reg | Open register logs in lnav with TJ formats | lnav ~/logs/retail_error*.log
#
# Format is always:  description | usage   (usage is optional; defaults to the name)
#
# Commands:
#   tj                  fuzzy picker (enter: put command on the prompt, ctrl-r: run now,
#                       ctrl-e: open the tool's source in $EDITOR)
#   tj <name> [args]    run a tool directly (logged)
#   tj -l               list tools        tj -m    markdown cheat sheet (Obsidian)
#   tj -s [days]        usage stats       tj -u    executables with no tag yet
#   tj -e <name>        edit a tool       tj --send [pane]   picker for a tmux popup
#
# tmux popup (add to ~/.tmux.conf):
#   bind t display-popup -E -w 85% -h 75% "zsh -ic 'tj --send'"

typeset -ga TJ_PATHS TJ_FN_FILES
(( ${#TJ_PATHS} )) || TJ_PATHS=(~/bin ~/.local/bin ~/scripts)
: ${TJ_EXTRAS:=${XDG_CONFIG_HOME:-$HOME/.config}/tj/extras}
: ${TJ_LOG:=${XDG_STATE_HOME:-$HOME/.local/state}/tj/usage.log}

_tj_trim() {
  local s=$1
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  print -r -- "$s"
}

# Emits one row per tool: name \t kind \t desc \t usage \t file:line \t command
_tj_index() {
  emulate -L zsh
  local d f hit n rest name desc usage cmd
  for d in $TJ_PATHS; do
    [[ -d $d ]] || continue
    for f in $d/*(N-.x); do
      hit=$(grep -I -m1 -n '^# tj:' -- $f 2>/dev/null) || continue
      n=${hit%%:*}; rest=${hit#*:\# tj:}
      name=${f:t}
      desc=$(_tj_trim "${rest%%|*}")
      [[ $rest == *\|* ]] && usage=$(_tj_trim "${rest#*|}") || usage=$name
      print -r -- "$name"$'\t'script$'\t'"${desc:-(no description)}"$'\t'"${usage:-$name}"$'\t'"$f:$n"$'\t'"$f"
    done
  done
  for f in $TJ_FN_FILES; do
    [[ -r $f ]] || continue
    grep -n '^# tj-fn:' -- $f 2>/dev/null | while IFS= read -r hit; do
      n=${hit%%:*}; rest=${hit#*:\# tj-fn:}
      name=$(_tj_trim "${rest%%|*}"); rest=${rest#*|}
      desc=$(_tj_trim "${rest%%|*}")
      [[ $rest == *\|* ]] && usage=$(_tj_trim "${rest#*|}") || usage=$name
      print -r -- "$name"$'\t'fn$'\t'"${desc:-(no description)}"$'\t'"${usage:-$name}"$'\t'"$f:$n"$'\t'"$f"
    done
  done
  if [[ -r $TJ_EXTRAS ]]; then
    n=0
    while IFS= read -r hit || [[ -n $hit ]]; do
      (( n++ ))
      cmd=$(_tj_trim "$hit")
      [[ -z $cmd || $cmd == \#* ]] && continue
      [[ $hit == *\|*\|* ]] || continue
      name=$(_tj_trim "${hit%%|*}"); rest=${hit#*|}
      desc=$(_tj_trim "${rest%%|*}")
      cmd=$(_tj_trim "${rest#*|}")
      print -r -- "$name"$'\t'extra$'\t'"${desc:-(no description)}"$'\t'"$cmd"$'\t'"$TJ_EXTRAS:$n"$'\t'"$cmd"
    done < $TJ_EXTRAS
  fi
}

_tj_row() { _tj_index | awk -F'\t' -v n="$1" '$1==n {print; exit}' }

_tj_log() {
  zmodload -F zsh/datetime b:strftime p:EPOCHSECONDS 2>/dev/null
  local ts; strftime -s ts '%Y-%m-%dT%H:%M:%S' $EPOCHSECONDS
  mkdir -p ${TJ_LOG:h} && print -r -- "$ts"$'\t'"$1" >> $TJ_LOG
}

# Picker rows: display \t name \t kind \t desc \t usage \t src \t cmd \t count — most-used first
_tj_menu() {
  local log=$TJ_LOG; [[ -r $log ]] || log=/dev/null
  _tj_index | awk -F'\t' -v OFS='\t' '
    FILENAME == ARGV[1] { c[$2]++; next }
    { n = ($1 in c) ? c[$1] : 0
      tag = ($2 == "script") ? "" : " [" $2 "]"
      printf "%-22s %s%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\n", $1, $3, tag, $1, $2, $3, $4, $5, $6, n }
  ' $log - | sort -t$'\t' -k8,8nr -k2,2
}

_tj_pick() {
  local preview='printf "\033[1m%s\033[0m  (%s)\n\n%s\n\nUsage:  %s\nSource: %s\nUsed:   %s times via tj\n\n" {2} {3} {4} {5} {6} {8}
f={6}; l=${f##*:}; f=${f%:*}; [ -r "$f" ] && sed -n "${l},$((l+20))p" "$f"'
  _tj_menu | fzf --delimiter=$'\t' --with-nth=1 --query="$1" --prompt='tj> ' \
    --expect=ctrl-r,ctrl-e \
    --header='enter: put on prompt · ctrl-r: run now · ctrl-e: edit source' \
    --preview="$preview" --preview-window='right,50%,wrap'
}

_tj_edit() { # file:line
  local f=${1%:*} l=${1##*:}
  ${EDITOR:-vi} +$l $f
}

_tj_interactive() { # mode(insert|send) target-pane query
  emulate -L zsh
  local mode=$1 target=$2 out key line
  local -a fields
  out=$(_tj_pick "$3") || return 0
  key=${out%%$'\n'*}; line=${out#*$'\n'}
  [[ -z $line ]] && return 0
  fields=("${(@ps:\t:)line}")
  local name=$fields[2] src=$fields[6]
  case $key in
    ctrl-e) _tj_edit $src ;;
    ctrl-r)
      if [[ $mode == send ]]; then
        tmux send-keys -t $target -l "tj $name" && tmux send-keys -t $target Enter
      else
        tj $name
      fi ;;
    *)
      if [[ $mode == send ]]; then
        tmux send-keys -t $target -l "tj $name "
      else
        print -z "tj $name "
      fi ;;
  esac
}

tj() {
  emulate -L zsh
  case $1 in
    -h|--help)
      sed -n '1,/^$/p' ${functions_source[tj]:-$TJ_SELF} 2>/dev/null | sed 's/^# \{0,1\}//' ;;
    -l|--list)
      _tj_index | awk -F'\t' '{printf "%-22s %s\n", $1, $3}' | sort ;;
    -m|--md)
      print '| Tool | What it does | Usage |'
      print '|---|---|---|'
      _tj_index | sort | awk -F'\t' '{gsub(/\|/,"\\|",$4); printf "| `%s` | %s | `%s` |\n", $1, $3, $4}' ;;
    -s|--stats)
      [[ -r $TJ_LOG ]] || { print "No usage logged yet ($TJ_LOG)."; return 0 }
      local cutoff=0000
      if [[ -n $2 ]]; then
        zmodload -F zsh/datetime b:strftime p:EPOCHSECONDS 2>/dev/null
        strftime -s cutoff '%Y-%m-%dT%H:%M:%S' $(( EPOCHSECONDS - $2 * 86400 ))
      fi
      print "Runs via tj${2:+ (last $2 days)}:"
      awk -F'\t' -v c=$cutoff '$1 >= c { n[$2]++; last[$2]=substr($1,1,10) }
        END { for (k in n) printf "  %5d  %-22s last %s\n", n[k], k, last[k] }' $TJ_LOG | sort -rn
      local unused=$(_tj_index | awk -F'\t' -v c=$cutoff '
        FILENAME == ARGV[1] { if ($1 >= c) u[$2]=1; next } !($1 in u) { print "  " $1 }' $TJ_LOG -)
      [[ -n $unused ]] && print "\nNot used${2:+ in that window}:\n$unused" ;;
    -u|--untagged)
      local d f
      for d in $TJ_PATHS; do
        for f in $d/*(N-.x); do
          grep -I -q -m1 '^# tj:' -- $f 2>/dev/null || print -r -- "${f/#$HOME/~}"
        done
      done ;;
    -e|--edit)
      local row=$(_tj_row "$2")
      [[ -n $row ]] || { print -u2 "tj: no tool named '$2'"; return 1 }
      _tj_edit ${${(ps:\t:)row}[5]} ;;
    --send)
      _tj_interactive send "${2:-$(tmux display -p '#{pane_id}')}" ;;
    '')
      _tj_interactive insert ;;
    *)
      local name=$1 row kind cmd; shift
      row=$(_tj_row $name)
      if [[ -z $row ]]; then
        print -u2 "tj: no tool named '$name'"
        _tj_interactive insert '' $name
        return 1
      fi
      local -a f; f=("${(@ps:\t:)row}")
      kind=$f[2]; cmd=$f[6]
      _tj_log $name
      case $kind in
        script) "$cmd" "$@" ;;
        fn)     (( $+functions[$name] )) || source "$cmd"; "$name" "$@" ;;
        extra)  eval "$cmd ${(j: :)${(q)@}}" ;;
      esac ;;
  esac
}

TJ_SELF=${${(%):-%x}:A}

_tj_complete() {
  if (( CURRENT == 2 )); then
    local -a items
    items=(${(f)"$(_tj_index | awk -F'\t' '{gsub(/:/,"\\:",$1); print $1 ":" $3}')"})
    _describe 'tool' items
  else
    _files
  fi
}
(( $+functions[compdef] )) && compdef _tj_complete tj
