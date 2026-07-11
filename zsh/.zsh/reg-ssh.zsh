# reg-ssh.zsh — SSH into registers: fssh (pick + ssh, tmux-tiled for several),
# frun (run a command across registers), fstore (a store's registers as tmux
# panes), and the Ctrl-O pick-and-ssh widget.

# _reg_tmux_panes <session> <ssh-target>... — one tiled pane per target,
# attaching (or switching to) an existing session of that name instead.
_reg_tmux_panes() {
    command -v tmux >/dev/null || { print -u2 "tmux not found"; return 1 }
    local session="$1"; shift
    local -a targets=("$@")
    (( ${#targets} )) || return 1

    if tmux has-session -t "=$session" 2>/dev/null; then
        if [[ -n $TMUX ]]; then tmux switch-client -t "$session"
        else tmux attach-session -t "$session"; fi
        return
    fi

    tmux new-session -d -s "$session" -x 250 -y 60 -n registers "ssh ${targets[1]}"
    tmux select-pane -t "$session" -T "${targets[1]}"
    local t
    for t in ${targets[2,-1]}; do
        tmux split-window -t "$session" "ssh $t"
        tmux select-pane -t "$session" -T "$t"
        tmux select-layout -t "$session" tiled >/dev/null
    done
    tmux select-layout -t "$session" tiled >/dev/null
    tmux setw -t "$session" pane-border-status top
    tmux setw -t "$session" pane-border-format " #{pane_title} "

    if [[ -n $TMUX ]]; then tmux switch-client -t "$session"
    else tmux attach-session -t "$session"; fi
}

# fssh [query] — fuzzy-pick registers and SSH in (Tab to multi-select).
# One host opens a plain ssh session; several open a tmux window of tiled panes,
# since a single shell cannot ssh to more than one host.
fssh() {
    local out
    out=$(_reg_pick_multi ssh "$1") || return
    [[ -n $out ]] || return
    local -a hosts=("${(@f)out}")

    if (( ${#hosts} == 1 )); then
        ssh "${hosts[1]}"
        return
    fi

    # Name the session after the store when they all share one, else "fssh".
    local session="fssh" prefix=${hosts[1]:0:4}
    local h; for h in $hosts; do [[ ${h:0:4} == $prefix ]] || { prefix=""; break } done
    [[ -n $prefix ]] && session=$prefix
    _reg_tmux_panes "$session" "${hosts[@]}"
}

# frun [cmd] — run a command on one or more registers (Tab to multi-select)
frun() {
    local hosts cmd="$*"
    _reg_hosts >/dev/null || return
    if [[ -z $cmd ]]; then
        echo -n "command ❯ "; read -r cmd
    fi
    [[ -z $cmd ]] && return
    hosts=$(_reg_pick_multi run) || return
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
    _reg_tmux_panes "$store" ${hosts/#/$up}
}


# Ctrl-O — pick a register and ssh straight in.
# Sets the buffer rather than calling ssh from inside the widget: zle owns
# the terminal here, and it lands the command in history for atuin/Ctrl-R.
fzf-ssh-widget() {
    local host
    host=$(_reg_pick ssh) || { zle reset-prompt; return }
    [[ -z $host ]] && { zle reset-prompt; return }
    BUFFER="ssh ${(q)host}"
    zle accept-line
}
zle -N fzf-ssh-widget
bindkey '^O' fzf-ssh-widget
