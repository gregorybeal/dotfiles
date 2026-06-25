# ~/.zshrc — managed by dotfiles repo

# ---------- Oh My Zsh ----------
export ZSH="$HOME/.oh-my-zsh"
# Theme handled by Starship below — set to empty so omz doesn't override
ZSH_THEME=""

plugins=(
    git
    ssh-agent
    history-substring-search
    sudo
    ansible
    docker
    pip
    zsh-autosuggestions
    zsh-syntax-highlighting
)

# Only source omz if it's installed (so this file works on a fresh box
# before omz is set up)
if [ -f "$ZSH/oh-my-zsh.sh" ]; then
    source "$ZSH/oh-my-zsh.sh"
fi

# ---------- Starship prompt ----------
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi

# ---------- History ----------
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE     # commands starting with space aren't saved
setopt HIST_REDUCE_BLANKS
setopt INC_APPEND_HISTORY
setopt EXTENDED_HISTORY

# ---------- Options ----------
setopt AUTO_CD               # type a dir name to cd into it
setopt AUTO_PUSHD            # cd pushes onto dir stack
setopt PUSHD_IGNORE_DUPS
setopt CORRECT               # spelling correction
setopt INTERACTIVE_COMMENTS  # allow # comments in interactive shells

# ---------- Key bindings ----------
bindkey -e                                    # emacs mode
bindkey '^[[A' history-substring-search-up    # up arrow
bindkey '^[[B' history-substring-search-down  # down arrow
bindkey '^R' history-incremental-search-backward

# ---------- Shared aliases ----------
[ -f "$HOME/.aliases.sh" ] && source "$HOME/.aliases.sh"

# -------- 1password ssh-agent -------
export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

# ---------- reg-tool ----------
[ -f "$HOME/.config/reg-tool/reg.sh" ] && source "$HOME/.config/reg-tool/reg.sh"

# ---------- fzf ----------
# Installed via brew / apt — adds Ctrl-R fuzzy history search, Ctrl-T file picker
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] && source /usr/share/doc/fzf/examples/key-bindings.zsh
[ -f /usr/share/fzf/key-bindings.zsh ] && source /usr/share/fzf/key-bindings.zsh

# ---------- uv (Python toolchain) ----------
if command -v uv >/dev/null 2>&1; then
    eval "$(uv generate-shell-completion zsh)"
    eval "$(uvx --generate-shell-completion zsh 2>/dev/null)" 2>/dev/null || true
fi
# Make sure uv's tool bin dir is in PATH
[ -d "$HOME/.local/share/uv/tools" ] && export PATH="$HOME/.local/bin:$PATH"

# ---------- Local-only / secrets ----------
# Anything machine-specific or sensitive goes here, NOT in the repo
[ -f "$HOME/.secrets" ] && source "$HOME/.secrets"
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"

# ---------- PATH additions ----------
# Homebrew on Apple Silicon
[ -d /opt/homebrew/bin ] && export PATH="/opt/homebrew/bin:$PATH"
# User-local bins
[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH"
[ -d "$HOME/bin" ] && export PATH="$HOME/bin:$PATH"
[ -d "$HOME/.fzf/bin" ] && export PATH="$HOME/.fzf/bin:$PATH"

# ---------- FZF SSH Logic ----------
# reg-fzf.zsh — fuzzy register picker built on the generated SSH config.
# Source from ~/.zshrc:  source ~/path/reg-fzf.zsh
#
# The host list comes from the generated Include file, so it is exactly the
# set that is connectable (invalid stores already filtered out). Selecting a
# name just hands it to ssh — ProxyJump / User / host-key settings all come
# from the SSH config.

_REG_CONF="${REG_CONF:-$HOME/.ssh/conf.d/registers}"
_REG_DB="${REG_DB:-$HOME/store_registers.db}"   # only used by the preview

# all connectable register aliases (skips the Host ????reg?? wildcard)
_reg_hosts() {
    awk '/^Host / && $2 !~ /[?*]/ {print $2}' "$_REG_CONF"
}

# fuzzy-pick one register and SSH in.  Optional arg seeds the query: fssh 0999
fssh() {
    local host
    host=$(_reg_hosts | fzf --prompt='ssh ❯ ' --reverse --height=40% \
            --query="$1" \
            --preview "sqlite3 -readonly '$_REG_DB' \
              \"SELECT 'host : '||hostname||char(10)||'ip   : '||COALESCE(ip_address,'?') \
                 FROM registers WHERE hostname='{}';\" 2>/dev/null" \
            --preview-window=down,3,wrap) || return
    [[ -n $host ]] && ssh "$host"
}

# fuzzy-pick one or more (Tab to multi-select), run a command on each.
#   frun uptime           -> runs `uptime` on the picked host(s)
#   frun                  -> prompts for the command after you pick
frun() {
    local hosts cmd="$*"
    hosts=$(_reg_hosts | fzf --prompt='run ❯ ' --reverse --height=40% --multi) || return
    [[ -z $hosts ]] && return
    if [[ -z $cmd ]]; then
        echo -n "command for $(grep -c . <<<"$hosts") host(s): "
        read -r cmd
    fi
    [[ -z $cmd ]] && return
    while IFS= read -r h; do
        print -P "%F{cyan}=== $h ===%f"
        ssh "$h" "$cmd"
    done <<< "$hosts"
}




# reg-fzf.zsh — fuzzy register tools built on the generated SSH config.
# Source from ~/.zshrc:  source ~/path/reg-fzf.zsh
#
# Host list comes from the generated Include file, so it is exactly the set
# that is connectable (invalid stores already filtered). Selecting a name just
# hands it to ssh — ProxyJump / User / host-key settings come from the config.

_REG_CONF="${REG_CONF:-$HOME/.ssh/conf.d/registers}"
_REG_DB="${REG_DB:-$HOME/store_registers.db}"   # only used by the fssh preview

# all connectable register aliases (skips the Host ????reg?? wildcard)
_reg_hosts() {
    awk '/^Host / && $2 !~ /[?*]/ {print $2}' "$_REG_CONF"
}

# fuzzy-pick one register and SSH in.  Optional arg seeds the query: fssh 0999
fssh() {
    local host
    host=$(_reg_hosts | fzf --prompt='ssh ❯ ' --reverse --height=40% \
            --query="$1" \
            --preview "sqlite3 -readonly '$_REG_DB' \
              \"SELECT 'host : '||hostname||char(10)||'ip   : '||COALESCE(ip_address,'?') \
                 FROM registers WHERE hostname='{}';\" 2>/dev/null" \
            --preview-window=down,3,wrap) || return
    [[ -n $host ]] && ssh "$host"
}

# run a command on picked register(s). Command first, then fzf opens.
#   frun uptime   -> runs `uptime` on the host(s) you pick
#   frun          -> prompts for the command, then opens fzf
frun() {
    local hosts cmd="$*"
    if [[ -z $cmd ]]; then
        echo -n "command ❯ "; read -r cmd
    fi
    [[ -z $cmd ]] && return
    hosts=$(_reg_hosts | fzf --prompt='run ❯ ' --reverse --height=40% --multi) || return
    [[ -z $hosts ]] && return
    while IFS= read -r h; do
        print -P "%F{cyan}=== $h ===%f"
        ssh "$h" "$cmd"
    done <<< "$hosts"
}

# Ctrl-G: type any command, then pick register(s) inline at the cursor.
#   ssh <C-g>   /   scp file.tar <C-g>:/tmp/   /   ansible -m ping <C-g>
# Tab multi-selects; multiple picks are inserted space-separated.
fzf-reg-widget() {
    local selected
    selected=$(_reg_hosts | fzf --height=40% --reverse --multi --prompt='reg ❯ ') || return
    [[ -z $selected ]] && { zle reset-prompt; return }
    LBUFFER+="${selected//$'\n'/ }"
    zle reset-prompt
}
zle -N fzf-reg-widget
bindkey '^G' fzf-reg-widget   # shadows send-break; swap to '^O' or '\eg' if needed



# reg-fzf.zsh — fuzzy register tools built on the generated SSH config.
# Source from ~/.zshrc:  source ~/path/reg-fzf.zsh
#
# Host list comes from the generated Include file, so it is exactly the set
# that is connectable (invalid stores already filtered). Selecting a name just
# hands it to ssh — ProxyJump / User / host-key settings come from the config.

_REG_CONF="${REG_CONF:-$HOME/.ssh/conf.d/registers}"
_REG_DB="${REG_DB:-$HOME/store_registers.db}"   # only used by the fssh preview

# all connectable register aliases (skips the Host ????reg?? wildcard)
_reg_hosts() {
    awk '/^Host / && $2 !~ /[?*]/ {print $2}' "$_REG_CONF"
}

# fuzzy-pick one register and SSH in.  Optional arg seeds the query: fssh 0999
fssh() {
    local host
    host=$(_reg_hosts | fzf --prompt='ssh ❯ ' --reverse --height=40% \
            --query="$1" \
            --preview "sqlite3 -readonly '$_REG_DB' \
              \"SELECT 'host : '||hostname||char(10)||'ip   : '||COALESCE(ip_address,'?') \
                 FROM registers WHERE hostname='{}';\" 2>/dev/null" \
            --preview-window=down,3,wrap) || return
    [[ -n $host ]] && ssh "$host"
}

# run a command on picked register(s). Command first, then fzf opens.
#   frun uptime   -> runs `uptime` on the host(s) you pick
#   frun          -> prompts for the command, then opens fzf
frun() {
    local hosts cmd="$*"
    if [[ -z $cmd ]]; then
        echo -n "command ❯ "; read -r cmd
    fi
    [[ -z $cmd ]] && return
    hosts=$(_reg_hosts | fzf --prompt='run ❯ ' --reverse --height=40% --multi) || return
    [[ -z $hosts ]] && return
    while IFS= read -r h; do
        print -P "%F{cyan}=== $h ===%f"
        ssh "$h" "$cmd"
    done <<< "$hosts"
}

# Ctrl-G: type any command, then pick register(s) inline at the cursor.
#   ssh <C-g>   /   scp file.tar <C-g>:/tmp/   /   ansible -m ping <C-g>
# Tab multi-selects; multiple picks are inserted space-separated.
fzf-reg-widget() {
    local selected
    selected=$(_reg_hosts | fzf --height=40% --reverse --multi --prompt='reg ❯ ') || return
    [[ -z $selected ]] && { zle reset-prompt; return }
    LBUFFER+="${selected//$'\n'/ }"
    zle reset-prompt
}
zle -N fzf-reg-widget
bindkey '^G' fzf-reg-widget   # shadows send-break; swap to '^O' or '\eg' if needed

# fstore [store] — open a tmux session named after the store, one pane per
# register at that store, each ssh'd in (tiled, pane borders show the host).
#   fstore 112     -> store 0112 (zero-padded automatically)
#   fstore         -> fuzzy-pick the store
#   REG_SSH_USER=root fstore 112   -> force a login user for the ssh'd panes
# Reuses an existing session of the same name instead of rebuilding it.
fstore() {
    command -v tmux >/dev/null || { print -u2 "fstore: tmux not found"; return 1 }

    local store="$1"
    if [[ -z $store ]]; then
        store=$(_reg_hosts | sed -E 's/reg[0-9]+$//' | sort -u \
                | fzf --prompt='store ❯ ' --reverse --height=40%) || return
    fi
    [[ -z $store ]] && return
    [[ $store == <-> ]] && store=$(printf '%04d' "$((10#$store))")  # 112 -> 0112

    local hosts
    hosts=(${(f)"$(awk -v s="$store" \
        '$1=="Host" && $2 ~ ("^" s "reg[0-9][0-9]$") {print $2}' "$_REG_CONF")"})
    if (( ${#hosts} == 0 )); then
        print -u2 "fstore: no registers found for store $store"
        return 1
    fi

    local up=""; [[ -n $REG_SSH_USER ]] && up="${REG_SSH_USER}@"

    # already built? just go there
    if tmux has-session -t "=$store" 2>/dev/null; then
        if [[ -n $TMUX ]]; then tmux switch-client -t "$store"
        else tmux attach-session -t "$store"; fi
        return
    fi

    # build it: oversized virtual size during construction avoids "pane too
    # small" on big stores; it reflows to your real terminal on attach.
    tmux new-session -d -s "$store" -x 250 -y 60 -n registers "ssh ${up}${hosts[1]}"
    tmux select-pane -t "$store" -T "${hosts[1]}"
    local h
    for h in $hosts[2,-1]; do
        tmux split-window -t "$store" "ssh ${up}${h}"
        tmux select-pane -t "$store" -T "$h"
        tmux select-layout -t "$store" tiled >/dev/null
    done
    tmux select-layout -t "$store" tiled >/dev/null
    tmux setw -t "$store" pane-border-status top
    tmux setw -t "$store" pane-border-format " #{pane_title} "

    if [[ -n $TMUX ]]; then tmux switch-client -t "$store"
    else tmux attach-session -t "$store"; fi
}

###### Yazi — fuzzy directory jump tool
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	command yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
	command rm -f -- "$tmp"
}


###### Zoxide
eval "$(zoxide init zsh)"eval "$(atuin init zsh)"


#### JiraTUI completions
#compdef jiratui

_jiratui_completion() {
    local -a completions
    local -a completions_with_descriptions
    local -a response
    (( ! $+commands )) && return 1

    response=("${(@f)$(env COMP_WORDS="${words[*]}" COMP_CWORD=$((CURRENT-1)) _JIRATUI_COMPLETE=zsh_complete jiratui)}")

    for type key descr in ${response}; do
        if [[ "$type" == "plain" ]]; then
            if [[ "$descr" == "_" ]]; then
                completions+=("$key")
            else
                completions_with_descriptions+=("$key":"$descr")
            fi
        elif [[ "$type" == "dir" ]]; then
            _path_files -/
        elif [[ "$type" == "file" ]]; then
            _path_files -f
        fi
    done

    if [ -n "$completions_with_descriptions" ]; then
        _describe -V unsorted completions_with_descriptions -U
    fi

    if [ -n "$completions" ]; then
        compadd -U -V unsorted -a completions
    fi
}

if [[ $zsh_eval_context[-1] == loadautofunc ]]; then
    # autoload from fpath, call function directly
    _jiratui_completion "$@"
else
    # eval/source/. command, register function for later
    compdef _jiratui_completion jiratui
fi