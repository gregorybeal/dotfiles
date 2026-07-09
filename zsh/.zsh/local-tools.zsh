# ---------- reg-tool ----------
[ -f "$HOME/.config/reg-tool/reg.sh" ] && source "$HOME/.config/reg-tool/reg.sh"

# ---------- fzf register tools ----------
_REG_CONF="${REG_CONF:-$HOME/.ssh/conf.d/registers}"
_REG_DB="${REG_DB:-$HOME/store_registers.db}"

_reg_hosts() {
    if [[ ! -f $_REG_CONF ]]; then
        print -u2 "no register inventory at $_REG_CONF"
        print -u2 "generate it: scripts/gen_ssh_registers.py --db <db> --user <user>"
        return 1
    fi
    awk '/^Host / && $2 !~ /[?*]/ {print $2}' "$_REG_CONF"
}

# fssh [query] — fuzzy-pick a register and SSH in
fssh() {
    local host all
    all=$(_reg_hosts) || return
    host=$(print -r -- "$all" | fzf --prompt='ssh ❯ ' --reverse --height=40% \
            --query="$1" \
            --preview "sqlite3 -readonly '$_REG_DB' \
              \"SELECT 'host : '||register_hostname||char(10)||'ip   : '||COALESCE(register_ip,'?') \
                 FROM registers WHERE register_hostname='{}';\"" \
            --preview-window=down,3,wrap) || return
    [[ -n $host ]] && ssh "$host"
}

# frun [cmd] — run a command on one or more registers (Tab to multi-select)
frun() {
    local hosts all cmd="$*"
    all=$(_reg_hosts) || return
    if [[ -z $cmd ]]; then
        echo -n "command ❯ "; read -r cmd
    fi
    [[ -z $cmd ]] && return
    hosts=$(print -r -- "$all" | fzf --prompt='run ❯ ' --reverse --height=40% --multi) || return
    [[ -z $hosts ]] && return
    while IFS= read -r h; do
        print -P "%F{cyan}=== $h ===%f"
        # -n: without it ssh drains the herestring and the loop ends after one host
        ssh -n "$h" "$cmd"
    done <<< "$hosts"
}

# fstore [store] — open a tmux session with one pane per register at a store
fstore() {
    command -v tmux >/dev/null || { print -u2 "fstore: tmux not found"; return 1 }

    local store="$1" all
    all=$(_reg_hosts) || return
    if [[ -z $store ]]; then
        store=$(print -r -- "$all" | sed -E 's/reg[0-9]+$//' | sort -u \
                | fzf --prompt='store ❯ ' --reverse --height=40%) || return
    fi
    [[ -z $store ]] && return
    [[ $store == <-> ]] && store=$(printf '%04d' "$((10#$store))")

    local hosts
    hosts=(${(f)"$(awk -v s="$store" \
        '$1=="Host" && $2 ~ ("^" s "reg[0-9][0-9]$") {print $2}' "$_REG_CONF")"})
    if (( ${#hosts} == 0 )); then
        print -u2 "fstore: no registers found for store $store"
        return 1
    fi

    local up=""; [[ -n $REG_SSH_USER ]] && up="${REG_SSH_USER}@"

    if tmux has-session -t "=$store" 2>/dev/null; then
        if [[ -n $TMUX ]]; then tmux switch-client -t "$store"
        else tmux attach-session -t "$store"; fi
        return
    fi

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

# Ctrl-G — inline fuzzy register picker (inserts hostname at cursor)
fzf-reg-widget() {
    local selected all
    all=$(_reg_hosts) || { zle reset-prompt; return }
    selected=$(print -r -- "$all" | fzf --height=40% --reverse --multi --prompt='reg ❯ ') || return
    [[ -z $selected ]] && { zle reset-prompt; return }
    LBUFFER+="${selected//$'\n'/ }"
    zle reset-prompt
}
zle -N fzf-reg-widget
bindkey '^G' fzf-reg-widget

# ---------- yazi directory jump ----------
function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    command yazi "$@" --cwd-file="$tmp"
    IFS= read -r -d '' cwd < "$tmp"
    [ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
    command rm -f -- "$tmp"
}
