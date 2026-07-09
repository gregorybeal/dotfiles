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

# ---------- VNC tunnels ----------
# ProxyJump already gets us to the register, so the forward targets the
# register's own loopback rather than an IP routed through the gateway.
_REG_VNC_PORT="${REG_VNC_PORT:-5900}"   # VNC port on the register
_REG_VNC_BASE="${REG_VNC_BASE:-5901}"   # first local port to try

_reg_port_free() {
    if command -v ss >/dev/null 2>&1; then
        [[ -z "$(ss -ltnH "sport = :$1" 2>/dev/null)" ]]
    elif command -v lsof >/dev/null 2>&1; then
        ! lsof -iTCP:"$1" -sTCP:LISTEN -Pn >/dev/null 2>&1
    else
        return 0
    fi
}

_reg_free_port() {
    local p=$_REG_VNC_BASE
    while (( p < _REG_VNC_BASE + 100 )); do
        _reg_port_free $p && { print -r -- $p; return 0 }
        (( p++ ))
    done
    print -u2 "fvnc: no free local port in ${_REG_VNC_BASE}-$((_REG_VNC_BASE + 99))"
    return 1
}

# Active fvnc tunnels, one "pid lport host" per line.
# `ps -ax -o` rather than `-eo`: on macOS `ps -e` means "show environment".
_reg_vnc_tunnels() {
    ps -ax -o pid=,args= 2>/dev/null | awk -v rport=":localhost:$_REG_VNC_PORT" '
        # $2 is the executable: anchor on it so an unrelated command line that
        # merely mentions the forward spec is not mistaken for a tunnel.
        $2 != "ssh" && $2 !~ /\/ssh$/ { next }
        {
            pid = $1; host = $NF; lport = ""
            for (i = 1; i <= NF; i++)
                if ($i == "-L" && index($(i+1), "127.0.0.1:") == 1 \
                              && index($(i+1), rport) > 0) {
                    split($(i+1), a, ":"); lport = a[2]
                }
            if (lport != "") print pid, lport, host
        }'
}

_reg_vnc_open() {
    local addr="$1"
    if [[ -n $REG_VNC_CMD ]]; then
        eval "$REG_VNC_CMD $addr"
    elif [[ $OSTYPE == darwin* ]]; then
        open "vnc://$addr"
    elif command -v vncviewer >/dev/null 2>&1; then
        vncviewer "$addr" >/dev/null 2>&1 &!
    elif command -v remmina >/dev/null 2>&1; then
        remmina -c "vnc://$addr" >/dev/null 2>&1 &!
    else
        print "no VNC viewer found — point yours at $addr"
        print "set REG_VNC_CMD to choose one, e.g. REG_VNC_CMD=vncviewer"
    fi
}

# fvnc [query] — tunnel to a register's VNC port and open a viewer
fvnc() {
    local all host lport
    all=$(_reg_hosts) || return
    host=$(print -r -- "$all" \
            | fzf --prompt='vnc ❯ ' --reverse --height=40% --query="$1") || return
    [[ -n $host ]] || return

    # Reuse an existing tunnel to this host instead of stacking another.
    lport=$(_reg_vnc_tunnels | awk -v h="$host" '$3 == h { print $2; exit }')

    if [[ -n $lport ]]; then
        print -P "%F{yellow}reusing%f tunnel on localhost:${lport}"
    else
        lport=$(_reg_free_port) || return
        # ControlPath=none gives a dedicated process we can find and kill,
        # rather than a forward multiplexed onto a shared master socket.
        ssh -f -N \
            -o ExitOnForwardFailure=yes \
            -o ControlPath=none \
            -L "127.0.0.1:${lport}:localhost:${_REG_VNC_PORT}" \
            "$host" || { print -u2 "fvnc: tunnel to $host failed"; return 1 }
        print -P "%F{green}tunnel%f $host:${_REG_VNC_PORT} → localhost:${lport}"
    fi

    _reg_vnc_open "127.0.0.1:${lport}"
}

# fvnc-list — show active VNC tunnels
fvnc-list() {
    local t
    t=$(_reg_vnc_tunnels)
    [[ -z $t ]] && { print "(no vnc tunnels)"; return 0 }
    printf "%-8s %-6s %s\n" PID PORT HOST
    print -r -- "$t" | awk '{ printf "%-8s %-6s %s\n", $1, $2, $3 }'
}

# fvnc-kill [-a] — close VNC tunnels (Tab to multi-select, -a for all)
fvnc-kill() {
    local t sel
    t=$(_reg_vnc_tunnels)
    [[ -z $t ]] && { print -u2 "fvnc-kill: no vnc tunnels"; return 1 }

    if [[ $1 == -a ]]; then
        sel="$t"
    else
        sel=$(print -r -- "$t" | fzf --prompt='close ❯ ' --reverse --height=40% \
                --multi --header='PID      PORT   HOST') || return
    fi
    [[ -n $sel ]] || return

    local pid lport host rc=0
    while read -r pid lport host; do
        if kill "$pid" 2>/dev/null; then
            print -P "%F{green}closed%f $host (localhost:$lport)"
        else
            print -u2 "fvnc-kill: could not kill pid $pid ($host)"
            rc=1
        fi
    done <<< "$sel"
    return $rc
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

# Ctrl-O — pick a register and ssh straight in.
# Sets the buffer rather than calling ssh from inside the widget: zle owns
# the terminal here, and it lands the command in history for atuin/Ctrl-R.
fzf-ssh-widget() {
    local host all
    all=$(_reg_hosts) || { zle reset-prompt; return }
    host=$(print -r -- "$all" | fzf --height=40% --reverse --prompt='ssh ❯ ') || {
        zle reset-prompt; return
    }
    [[ -z $host ]] && { zle reset-prompt; return }
    BUFFER="ssh ${(q)host}"
    zle accept-line
}
zle -N fzf-ssh-widget
bindkey '^O' fzf-ssh-widget

# ---------- yazi directory jump ----------
function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    command yazi "$@" --cwd-file="$tmp"
    IFS= read -r -d '' cwd < "$tmp"
    [ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
    command rm -f -- "$tmp"
}
