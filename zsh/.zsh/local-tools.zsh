# ---------- reg-tool ----------
[ -f "$HOME/.config/reg-tool/reg.sh" ] && source "$HOME/.config/reg-tool/reg.sh"

# ---------- fzf register tools ----------
_REG_CONF="${REG_CONF:-$HOME/.ssh/conf.d/registers}"
_REG_DB="${REG_DB:-$HOME/store_registers.db}"
_REG_MNT="${REG_MNT:-$HOME/mnt/reg}"

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

# ---------- sshfs register mounts ----------
# sshfs shells out to ssh, so ~/.ssh/config drives these: the ProxyJump,
# User and ControlMaster from the generated conf.d/registers block all
# apply, and a warm control socket makes a mount near-instant.

# `mount` prints "<src> on <path> ..." on both Linux and macOS, so $3 is
# the mountpoint either way.
_reg_is_mounted() {
    mount | awk -v p="$1" '$3 == p { found = 1 } END { exit !found }'
}

_reg_unmount() {
    if command -v fusermount3 >/dev/null 2>&1; then fusermount3 -u "$1"
    elif command -v fusermount >/dev/null 2>&1; then fusermount -u "$1"
    else umount "$1"; fi   # macOS: fuse-t mounts unmount like any NFS mount
}

_reg_mounts() {
    mount | awk -v d="$_REG_MNT/" 'index($3, d) == 1 { print $3 }'
}

# fmount [-w] [query] — fuzzy-pick a register and sshfs-mount its root.
# Prints the mountpoint, so `cd "$(fmount)"` works. Read-only unless -w.
fmount() {
    command -v sshfs >/dev/null 2>&1 || {
        print -u2 "fmount: sshfs not found"
        print -u2 "  linux: sudo apt install sshfs"
        print -u2 "  macos: brew tap macos-fuse-t/cask && brew install fuse-t-sshfs"
        return 1
    }

    local rw=0
    [[ $1 == -w ]] && { rw=1; shift }

    local all host
    all=$(_reg_hosts) || return
    host=$(print -r -- "$all" \
            | fzf --prompt='mount ❯ ' --reverse --height=40% --query="$1") || return
    [[ -n $host ]] || return

    local mp="$_REG_MNT/$host"
    if _reg_is_mounted "$mp"; then
        print -u2 "fmount: $host already mounted"
        print -r -- "$mp"
        return 0
    fi
    mkdir -p "$mp" || return

    local -a opts
    opts=(reconnect ServerAliveInterval=15 ServerAliveCountMax=3 follow_symlinks)
    (( rw )) || opts+=(ro)
    if [[ $OSTYPE == darwin* ]]; then
        opts+=(volname="$host" noappledouble)
    else
        opts+=(idmap=user)   # show remote posuser's files as us, not a stray uid
    fi

    if sshfs "$host:/" "$mp" -o "${(j:,:)opts}"; then
        print -r -- "$mp"
    else
        rmdir "$mp" 2>/dev/null
        print -u2 "fmount: failed to mount $host"
        return 1
    fi
}

# fumount [-a] — unmount register mounts (Tab to multi-select, -a for all)
fumount() {
    local all_mounts sel
    all_mounts=$(_reg_mounts)
    if [[ -z $all_mounts ]]; then
        print -u2 "fumount: no register mounts under $_REG_MNT"
        return 1
    fi

    if [[ $1 == -a ]]; then
        sel="$all_mounts"
    else
        sel=$(print -r -- "$all_mounts" \
                | fzf --prompt='unmount ❯ ' --reverse --height=40% --multi) || return
    fi
    [[ -n $sel ]] || return

    local mp rc=0
    while IFS= read -r mp; do
        # </dev/null: keep the unmount helper off the loop's herestring
        if _reg_unmount "$mp" </dev/null; then
            rmdir "$mp" 2>/dev/null
            print -P "%F{green}unmounted%f $mp"
        else
            print -u2 "fumount: failed to unmount $mp"
            rc=1
        fi
    done <<< "$sel"
    return $rc
}

# fmounts — list active register mounts
fmounts() {
    local m
    m=$(_reg_mounts)
    [[ -n $m ]] && print -r -- "$m" || print "(no register mounts)"
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
