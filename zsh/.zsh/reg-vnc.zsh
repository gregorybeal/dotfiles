# reg-vnc.zsh — self-closing SSH tunnels to registers' VNC ports and the
# viewer handoff: fvnc / fvnc-list / fvnc-kill.

# ---------- VNC tunnels ----------
# ProxyJump already gets us to the register, so the forward targets the
# register's own loopback rather than an IP routed through the gateway.
_REG_VNC_PORT="${REG_VNC_PORT:-5900}"    # VNC port on the register
_REG_VNC_BASE="${REG_VNC_BASE:-5901}"    # first local port to try
_REG_VNC_GRACE="${REG_VNC_GRACE:-20}"    # seconds for the viewer to connect

# Test bindability rather than inspecting the listener table: zsh/net/tcp is
# a builtin module, so this behaves identically on macOS and Linux and needs
# no privileges. `lsof` cannot see other users' listening sockets unless run
# as root, and would report a busy port as free; macOS has no `ss` at all.
_reg_port_free() {
    zmodload -s zsh/net/tcp 2>/dev/null || return 0   # cannot check; assume free
    if ztcp -l "$1" 2>/dev/null; then
        ztcp -c "$REPLY" 2>/dev/null
        return 0
    fi
    return 1
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
# `-ax` not `-e`: on macOS `ps -e` means "show environment".
# `-ww`: macOS ps truncates args to terminal width, which would cut the
# trailing hostname off our tunnel's command line.
_reg_vnc_tunnels() {
    ps -axww -o uid=,pid=,args= 2>/dev/null \
      | awk -v me="$(id -u)" -v rport=":localhost:$_REG_VNC_PORT" '
        $1 != me { next }                        # only our own processes
        $3 != "ssh" && $3 !~ /\/ssh$/ { next }   # anchor on the executable, so an
                                                 # unrelated command line that merely
                                                 # mentions the forward spec is skipped
        {
            pid = $2; lport = ""
            # argv ends "<host> sleep <n>"; tolerate an old-style "-N ... <host>"
            host = ($(NF-1) == "sleep") ? $(NF-2) : $NF
            for (i = 1; i <= NF; i++)
                if ($i == "-L" &&
                    index($(i+1), "127.0.0.1:") == 1 &&
                    index($(i+1), rport) > 0) {
                    split($(i+1), a, ":"); lport = a[2]
                }
            if (lport != "") print pid, lport, host
        }'
}

# Fetch the VNC password, if $REG_VNC_PASS_CMD is configured. Printed on stdout
# and never written to disk; the caller passes it to the viewer via the
# environment. Set it in ~/.zshrc.local, e.g.
#   REG_VNC_PASS_CMD='op read op://Private/register-vnc/password'
_reg_vnc_password() {
    [[ -n $REG_VNC_PASS_CMD ]] || return 1
    local pw errf rc
    errf=$(mktemp "${TMPDIR:-/tmp}/fvnc-pw.XXXXXX") || return 1
    pw=$(eval "$REG_VNC_PASS_CMD" 2>"$errf"); rc=$?
    if (( rc != 0 )) || [[ -z $pw ]]; then
        print -u2 "fvnc: REG_VNC_PASS_CMD exited $rc$( (( rc == 0 )) && print -n ' but produced no output')"
        print -u2 "  cmd: $REG_VNC_PASS_CMD"
        [[ -s $errf ]] && sed 's/^/  /' "$errf" >&2
        (( rc == 127 )) && print -u2 "  hint: it must be a command that *prints* the password, not the password itself"
        print -u2 "  the viewer will prompt"
        rm -f "$errf"
        return 1
    fi
    rm -f "$errf"
    print -r -- "$pw"
}

# Percent-encode for a URL: everything outside the unreserved set. Byte-wise,
# so a non-ASCII password survives. perl is on every macOS; the zsh fallback is
# ASCII-only but never runs there.
_reg_urlenc() {
    if command -v perl >/dev/null 2>&1; then
        print -rn -- "$1" | perl -pe 's/([^A-Za-z0-9._~-])/sprintf("%%%02X", ord($1))/ge'
        return
    fi
    local s=$1 out="" c i
    for (( i = 1; i <= ${#s}; i++ )); do
        c=$s[i]
        case $c in
            [A-Za-z0-9._~-]) out+=$c ;;
            *) out+=$(printf '%%%02X' "'$c") ;;
        esac
    done
    print -rn -- "$out"
}

# Apple's Screen Sharing. It scales client-side (View → Turn Scaling On, which
# persists — every register is 127.0.0.1, so set it once), and it does take a
# password: vnc://user:pass@host.
#
# The URL goes to osascript on *stdin*, never in argv, so the password cannot be
# read out of `ps`. printf is a zsh builtin, so it forks nothing either.
# Classic VNC auth carries no username, hence the leading colon: vnc://:pass@host
_reg_vnc_screensharing() {
    local addr="$1" pw="$2" user="$3" cred=""
    if [[ -n $pw ]]; then
        cred="$(_reg_urlenc "$user"):$(_reg_urlenc "$pw")@"
    elif [[ -n $user ]]; then
        cred="$(_reg_urlenc "$user")@"
    fi
    printf 'tell application "Screen Sharing" to open location "vnc://%s%s"\n' \
        "$cred" "$addr" | osascript -
}

# Viewer:
#   1. REG_VNC_CMD    — an explicit override, given the address; VNC_USERNAME and
#                       VNC_PASSWORD are exported for it
#   2. Screen Sharing — macOS. Scales client-side (View → Turn Scaling On, which
#                       persists) and takes the password in the URL
#   3. remmina        — Linux
_reg_vnc_open() {
    local addr="$1" pw
    pw=$(_reg_vnc_password) || pw=""
    # Classic VNC auth (RFB security type 2) has no username — only VeNCrypt/plain
    # does. Set REG_VNC_USER only if your server actually asks for one; it is not
    # the SSH login, which the ssh config already supplies.
    local user="${REG_VNC_USER:-}"

    if [[ -n $REG_VNC_CMD ]]; then
        VNC_USERNAME="$user" VNC_PASSWORD="$pw" eval "$REG_VNC_CMD $addr"
    elif [[ $OSTYPE == darwin* ]]; then
        _reg_vnc_screensharing "$addr" "$pw" "$user"
    elif command -v remmina >/dev/null 2>&1; then
        remmina -c "vnc://$addr" >/dev/null 2>&1 &!
    else
        print "no VNC viewer found — point yours at $addr"
        print "set REG_VNC_CMD to launch one"
    fi
}

# _reg_vnc_tunnel_open <host> — print the local port on stdout, reusing an
# existing tunnel to that host rather than stacking another. Progress messages
# go to stderr so `lport=$(_reg_vnc_tunnel_open ...)` stays clean.
_reg_vnc_tunnel_open() {
    local host="$1" lport errf
    lport=$(_reg_vnc_tunnels | awk -v h="$host" '$3 == h { print $2; exit }')
    if [[ -n $lport ]]; then
        print -u2 -P "%F{yellow}reusing%f tunnel to $host on localhost:${lport}"
        print -r -- "$lport"
        return 0
    fi

    lport=$(_reg_free_port) || return 1
    # `sleep N` rather than -N, so the tunnel cleans itself up: ssh exits once
    # the remote command has ended *and* no forwarded connection remains. It
    # therefore dies N seconds from now if the viewer never connects, lives as
    # long as the VNC session does, and exits ~1s after the viewer disconnects.
    # ControlPath=none keeps it a dedicated process rather than a forward
    # multiplexed onto a shared master socket.
    # The backgrounded ssh holds its stdout/stderr open for the whole life of
    # the remote command, so leaving them attached would make `x=$(fvnc)` or
    # `fvnc | less` hang for the grace period. Point them at a temp file, and
    # replay it only if the tunnel failed (ssh forks after the forward is set
    # up, so any error is already written by the time it returns non-zero).
    errf=$(mktemp "${TMPDIR:-/tmp}/fvnc.XXXXXX") || return 1
    if ssh -f \
        -o ExitOnForwardFailure=yes \
        -o ControlPath=none \
        -L "127.0.0.1:${lport}:localhost:${_REG_VNC_PORT}" \
        "$host" sleep "$_REG_VNC_GRACE" >"$errf" 2>&1
    then
        rm -f "$errf"
    else
        print -u2 "fvnc: tunnel to $host failed"
        [[ -s $errf ]] && print -u2 -- "$(<"$errf")"
        rm -f "$errf"
        return 1
    fi
    print -u2 -P "%F{green}tunnel%f $host:${_REG_VNC_PORT} → localhost:${lport} %F{242}(self-closing)%f"
    print -r -- "$lport"
}

# fvnc [query] — tunnel to registers' VNC ports and open a viewer for each
# (Tab to multi-select). Each host gets its own local port and its own
# self-closing tunnel.
fvnc() {
    local out
    out=$(_reg_pick_multi vnc "$1") || return
    [[ -n $out ]] || return
    local -a hosts=("${(@f)out}")

    local host lport rc=0
    for host in $hosts; do
        if lport=$(_reg_vnc_tunnel_open "$host"); then
            _reg_vnc_open "127.0.0.1:${lport}"
        else
            rc=1
        fi
    done
    return $rc
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
