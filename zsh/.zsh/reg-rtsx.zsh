# reg-rtsx.zsh — Royal TSX handoff: frtsx / frtsx-store open registers'
# *stored* connection objects (created by mac/royaltsx's RoyalJSON dynamic
# folder), falling back to ad hoc; plus the Ctrl-P picker widget.
#
# Two backends, same contract (object names, ad hoc fallback):
#   macOS — Royal TSX, driven over AppleScript (osascript)
#   WSL   — Royal TS for Windows, driven through its rtscli.exe (see
#           windows/royalts/README.md)

# Royal TS on Windows resolves through the *Windows* hosts file, so that is the
# one that decides hostname-vs-IP (here and in reglib, hence the export).
# Only a default: a REG_HOSTS_FILE set in ~/.zshrc.local (before or after this
# file loads) still wins.
if [[ -n $WSL_DISTRO_NAME && -z $REG_HOSTS_FILE ]]; then
    export REG_HOSTS_FILE=/mnt/c/Windows/System32/drivers/etc/hosts
fi

# _reg_rtscli — print the path to Royal TS's rtscli.exe; fails off WSL or when
# Royal TS isn't installed. REG_RTSCLI overrides; otherwise the newest
# "C:\Program Files\Royal TS V<n>" install wins (n = numeric glob sort).
_reg_rtscli() {
    [[ -n $WSL_DISTRO_NAME ]] || return 1
    if [[ -n $REG_RTSCLI ]]; then
        [[ -x $REG_RTSCLI ]] && print -r -- "$REG_RTSCLI"
        return
    fi
    local -a found=("/mnt/c/Program Files/Royal TS V"<->/rtscli.exe(N-.n))
    (( ${#found} )) || return 1
    print -r -- "${found[-1]}"
}

# Is there a Royal TS(X) to hand off to from here?
_reg_rtsx_available() {
    [[ $OSTYPE == darwin* ]] || _reg_rtscli >/dev/null
}

# ---------- Royal TSX ----------
# _reg_ip <host> — resolve a register hostname to its IP address.
#
# `ssh -G` parses the real ssh config (the Include, the Host ????reg?? wildcard
# block, any local overrides) and prints the effective HostName without touching
# the network. A host with no HostName makes ssh echo the host back, so treat
# that as unresolved and fall through to the inventory database.
_reg_ip() {
    local host="$1" ip
    ip=$(ssh -G "$host" 2>/dev/null | awk '/^hostname /{print $2; exit}')
    if [[ -n $ip && $ip != $host ]]; then
        print -r -- "$ip"
        return 0
    fi

    ip=""   # ssh -G echoed the host back; don't let that leak into the result
    if [[ -f $_REG_DB ]] && command -v sqlite3 >/dev/null 2>&1; then
        local schema tbl hostc ipc
        if schema=$(_reg_db_schema); then
            tbl=${schema%%$'\t'*}
            hostc=${${schema#*$'\t'}%%$'\t'*}
            ipc=${schema##*$'\t'}
            # :gs (not //) — inside double quotes zsh leaves \' as backslash-quote,
            # so the // form would emit o\'\'brien rather than SQL's o''brien.
            [[ -n $ipc ]] && ip=$(sqlite3 -readonly "$_REG_DB" \
                "SELECT \"$ipc\" FROM \"$tbl\" WHERE \"$hostc\"='${host:gs/'/''}';" 2>/dev/null)
            if [[ -n $ip ]]; then
                print -r -- "$ip"
                return 0
            fi
        fi
    fi

    print -u2 "no IP for $host: no HostName in the ssh config, and not in ${_REG_DB:t}"
    return 1
}

# Is <name> mapped in /etc/hosts? Royal TSX resolves through the system
# resolver, not ~/.ssh/config, so a hosts entry is what lets it take a register
# by name — and the tab title is then the hostname instead of a bare IP.
# Install the entries with: gen_ssh_registers.py --format hosts --install-hosts
_reg_in_etc_hosts() {
    local hf=${REG_HOSTS_FILE:-/etc/hosts}
    [[ -r $hf ]] || return 1
    # Strip comments first, then match only alias fields — never the IP in $1.
    awk -v n="$1" '
        { sub(/#.*/, "") }
        NF >= 2 { for (i = 2; i <= NF; i++) if ($i == n) { found = 1; exit } }
        END { exit !found }' "$hf"
}

# What to hand Royal TSX for <host>: the hostname when the system can resolve
# it, else the IP. REG_RTSX_TARGET=hostname|ip forces one.
_reg_rtsx_target() {
    local host="$1"
    case ${REG_RTSX_TARGET:l} in
        hostname) print -r -- "$host"; return 0 ;;
        ip)       _reg_ip "$host"; return ;;
    esac
    if _reg_in_etc_hosts "$host"; then
        print -r -- "$host"
        return 0
    fi
    _reg_ip "$host"
}

# osascript stderr routing. The Royal TSX osascript calls normally swallow their
# stderr, so a failure — a `whose` filter Royal TSX rejects, a denied automation
# (TCC) prompt — is invisible and the handoff just quietly degrades to ad hoc.
# That is exactly how the "ad hoc even when the object exists" regression hid.
# Set REG_RTSX_DEBUG=1 to surface it: osascript's stderr goes to a temp file that
# is then dumped to *this* process's stderr (Alfred captures that in its workflow
# debugger; an interactive shell shows it inline). Unset, stderr goes to
# /dev/null as before, adding no temp file and no cost.
#
# _reg_osa_errfile prints the path to redirect osascript's stderr to;
# _reg_osa_debug dumps that file to stderr and removes it. A /dev/null path is
# the "debug off" sentinel and is left alone.
_reg_osa_errfile() {
    if [[ -n $REG_RTSX_DEBUG ]]; then
        mktemp "${TMPDIR:-/tmp}/rtsx-osa.XXXXXX" 2>/dev/null && return
    fi
    print -r -- /dev/null
}
_reg_osa_debug() {
    local errf="$1"
    [[ $errf == /dev/null ]] && return
    [[ -s $errf ]] && print -u2 -P "%F{yellow}[rtsx osascript]%f $(<$errf)"
    rm -f "$errf"
}

# Hand a connection string to Royal TSX.
#
# `adhoc` is a documented AppleScript command taking the same string the URL
# scheme carries. It is preferred over `open rtsx://…` because osascript reports
# an error when the app rejects the command, whereas `open` returns 0 as soon as
# LaunchServices accepts the URL — Royal Apps' own note that a query string
# "fails without error" is that gap. It also needs no URL escaping and does not
# depend on the rtsx:// handler still being registered.
#
# The catch is macOS automation permission (TCC): the first call prompts, and a
# denied prompt makes osascript fail. `open` needs no permission, so it stays as
# the fallback. Set REG_RTSX_DEBUG=1 to see why a denied prompt failed.
_reg_rtsx_adhoc() {
    local conn="$1"
    if [[ -n $WSL_DISTRO_NAME ]]; then
        # Royal TS for Windows: its legacy rtsx:// scheme wants the protocol
        # separator URL-encoded (%3a%2f%2f) and using=adhoc. Royal TSX's
        # "user?@" becomes "user@", which Royal TS reads as a credential name.
        # explorer.exe hands the URI to the registered handler and always
        # exits non-zero, so there is no failure signal to check.
        local proto=${conn%%://*} rest=${conn#*://}
        explorer.exe "rtsx://${proto}%3a%2f%2f${rest/\?@/@}?using=adhoc"
        return 0
    fi
    if command -v osascript >/dev/null 2>&1; then
        local errf; errf=$(_reg_osa_errfile)
        printf 'tell application "Royal TSX" to adhoc "%s"\n' "$conn" \
            | osascript - >/dev/null 2>"$errf" && { _reg_osa_debug "$errf"; return 0 }
        _reg_osa_debug "$errf"
        print -u2 "frtsx: osascript adhoc failed (automation permission?); using open"
    fi
    open "rtsx://${conn}"
}

# The Royal TSX connection-object name for <host> at <proto>. This is the
# contract between the picker (which connects by name) and the RoyalJSON
# generator (mac/royaltsx/reg-royaljson.py, which creates the objects): they
# MUST agree, or `connect` never finds the object and every handoff silently
# degrades to ad hoc. VNC is the primary object and keeps the bare hostname, so
# the tree reads cleanly; ssh/sftp are suffixed siblings.
#   vnc  -> <host>
#   ssh  -> <host> [SSH]
#   sftp -> <host> [SFTP]
_reg_rtsx_name() {
    local host="$1"
    case ${2:l} in
        ssh)  print -r -- "${host} [SSH]"  ;;
        sftp) print -r -- "${host} [SFTP]" ;;
        *)    print -r -- "$host"          ;;
    esac
}

# Connect <host> over <proto> by opening its *stored* Royal TSX object — the one
# the RoyalJSON dynamic folder generated, which already carries the secure
# gateway and credential inherited from its folder. That is the whole point of
# the design-B setup: no ad hoc defaults, each register its own configured
# connection.
#
# Falls back to an ad hoc connection (the old behaviour) when no such object
# exists, so a register that is in the ssh inventory but not yet materialised in
# Royal TSX still connects. <target> is only the fallback's host (hostname or
# IP); the stored object has its own ComputerName. It is resolved on demand, so
# the common path (object present) never touches the database or /etc/hosts.
_reg_rtsx_connect() {
    local proto="$1" host="$2" target="${3-}"
    local name; name=$(_reg_rtsx_name "$host" "$proto")

    local rtscli
    if rtscli=$(_reg_rtscli); then
        # rtscli connects every object with that name; the names are unique by
        # the contract above. Its exit codes aren't documented, so treat either
        # a non-zero exit or a not-found message as "no stored object". Run
        # from C: so the Windows side doesn't inherit a \\wsl$ working dir.
        local out rc
        out=$(cd /mnt/c 2>/dev/null; "$rtscli" action connect -n="$name" 2>&1); rc=$?
        out=${out//$'\r'/}
        [[ -n $REG_RTSX_DEBUG ]] && \
            print -u2 -P "%F{242}[rtsx] rtscli connect \"${name}\" -> rc=${rc}${out:+: ${out//\%/%%}}%f"
        if (( rc == 0 )) && [[ ${out:l} != *("not found"|"no connection"|"could not find")* ]]; then
            return 0
        fi
        print -u2 -P "%F{242}frtsx: no stored object \"${name}\"; connecting ad hoc%f"
    elif command -v osascript >/dev/null 2>&1; then
        # Resolve the object id and connect it. The fast path is `get object id
        # with name` — a single round trip that makes Royal TSX do the lookup
        # internally, instead of marshalling id+name of *every* connection (many
        # thousands, with a per-store × per-protocol tree) across the Apple Event
        # bridge on each call. Only if that finds nothing do we fall back to
        # enumerating and exact-matching (Royal TSX has no `whose name is …`
        # filter on connections, so a loop is the fallback), then to ad hoc.
        # The name is passed as an argv value, not spliced in, so it needs no
        # escaping. "notfound" (or an empty result on any error) → ad hoc.
        local res errf t0; errf=$(_reg_osa_errfile)
        [[ -n $REG_RTSX_DEBUG ]] && zmodload zsh/datetime 2>/dev/null && t0=$EPOCHREALTIME
        res=$(osascript \
            -e 'on run argv' \
            -e 'set theName to item 1 of argv' \
            -e 'tell application "Royal TSX"' \
            -e 'set theId to ""' \
            -e 'try' \
            -e 'set theId to (get object id with name theName as text)' \
            -e 'end try' \
            -e 'if theId is "" then' \
            -e 'set {conIds, conNames} to {id, name} of every connection' \
            -e 'repeat with i from 1 to count of conNames' \
            -e 'if (item i of conNames) is theName then set theId to (item i of conIds)' \
            -e 'end repeat' \
            -e 'end if' \
            -e 'if theId is "" then return "notfound"' \
            -e 'activate' \
            -e 'connect theId' \
            -e 'return "ok"' \
            -e 'end tell' \
            -e 'end run' \
            -- "$name" 2>"$errf")
        _reg_osa_debug "$errf"
        if [[ -n $REG_RTSX_DEBUG ]]; then
            local took=""
            [[ -n $t0 ]] && took=$(printf ' %.2fs' $(( EPOCHREALTIME - t0 )))
            print -u2 -P "%F{242}[rtsx] connect \"${name}\" -> ${res:-<none>}${took}%f"
        fi
        [[ $res == ok ]] && return 0
        print -u2 -P "%F{242}frtsx: no stored object \"${name}\"; connecting ad hoc%f"
    fi

    # Ad hoc fallback: uses Royal TSX's ad hoc defaults, not the stored object's
    # gateway/credential, so per-store gateways don't apply here.
    [[ -n $target ]] || target=$(_reg_rtsx_target "$host") || return 1
    local cred=""
    [[ -n $REG_RTSX_USER ]] && cred="${REG_RTSX_USER}?@"
    _reg_rtsx_adhoc "${proto}://${cred}${target}"
}

# frtsx [query] — pick a register by hostname and open it in Royal TSX. Enter
# opens VNC, Ctrl-S opens SSH, Ctrl-F opens SFTP (Tab multi-selects).
#
# Each protocol maps to a stored connection object created by the RoyalJSON
# dynamic folder (mac/royaltsx/), so the connection's secure gateway and
# credential come from its folder — not from ad hoc defaults. VNC is the primary
# object; ssh/sftp are the "[SSH]"/"[SFTP]" siblings (see _reg_rtsx_name). A
# register with no stored object falls back to an ad hoc connection.
#
# sftp:// / FileTransfer works even though it is not in Royal Apps' published
# protocol-identifier list — verified against a real Royal TSX.
frtsx() {
    _reg_rtsx_available || { print -u2 "frtsx: needs Royal TSX (macOS) or Royal TS + rtscli.exe (WSL)"; return 1 }

    local out key proto host rc=0
    out=$(_reg_pick_expect rtsx ctrl-s,ctrl-f \
        'enter=vnc   ctrl-s=ssh   ctrl-f=sftp   tab=multi-select' "$1") || return
    local -a lines; lines=("${(@f)out}")
    key=${lines[1]}
    local -a hosts=("${lines[@]:1}")   # line 1 is the key; the rest are hosts
    (( ${#hosts} )) || return

    case $key in
        ctrl-s) proto=ssh  ;;
        ctrl-f) proto=sftp ;;
        *)      proto=vnc  ;;   # Enter
    esac

    for host in $hosts; do
        print -P "%F{green}rtsx%f ${proto} → ${host}"
        _reg_rtsx_connect "$proto" "$host" || rc=1
    done
    return $rc
}

# _reg_rtsx_store <proto> <store> — connect every register at <store> over
# <proto> through the stored-object handoff. The store number is zero-padded, so
# 3 and 0003 are the same. Shared by frtsx-store and the Alfred store action, so
# the shell and Alfred open a store identically.
_reg_rtsx_store() {
    local proto="$1" store="$2"
    [[ $store == <-> ]] && store=$(printf '%04d' "$((10#$store))")

    local -a hosts
    hosts=(${(f)"$(awk -v s="$store" \
        '$1=="Host" && $2 ~ ("^" s "reg[0-9][0-9]$") {print $2}' "$_REG_CONF")"})
    if (( ${#hosts} == 0 )); then
        print -u2 "frtsx-store: no registers found for store $store"
        return 1
    fi

    local host rc=0
    for host in $hosts; do
        print -P "%F{green}rtsx%f ${proto} → ${host}"
        _reg_rtsx_connect "$proto" "$host" || rc=1
    done
    return $rc
}

# frtsx-store [store] — open *every* register at a store in Royal TSX, one
# connection each. The Royal TSX analogue of fstore (which tiles SSH panes in
# tmux). With no argument, fuzzy-pick the store the same way fstore does; the
# same keys as frtsx choose the protocol: Enter=VNC, Ctrl-S=SSH, Ctrl-F=SFTP.
# Passing a store number connects it as VNC — set REG_RTSX_STORE_PROTO to change
# that default. Uses the same stored-object handoff as frtsx (_reg_rtsx_connect).
frtsx-store() {
    _reg_rtsx_available || { print -u2 "frtsx-store: needs Royal TSX (macOS) or Royal TS + rtscli.exe (WSL)"; return 1 }

    local store="$1" proto="${REG_RTSX_STORE_PROTO:-vnc}" all
    all=$(_reg_hosts) || return
    if [[ -z $store ]]; then
        local out
        out=$(print -r -- "$all" | sed -E 's/reg[0-9]+$//' | sort -u \
                | fzf --prompt='rtsx store ❯ ' --reverse --height=40% \
                      --header='enter=vnc   ctrl-s=ssh   ctrl-f=sftp' \
                      --expect=ctrl-s,ctrl-f) || return
        local -a lines; lines=("${(@f)out}")
        store=${lines[2]}                        # line 1 is the pressed key
        case ${lines[1]} in
            ctrl-s) proto=ssh  ;;
            ctrl-f) proto=sftp ;;
        esac
    fi
    [[ -z $store ]] && return

    _reg_rtsx_store "$proto" "$store"
}

# Ctrl-P — open the Royal TSX picker straight from the prompt.
# Unlike Ctrl-O (which fills the buffer with `ssh <host>` so it lands in
# history), frtsx hands off to another application: there is no command worth
# recording, so run it in place. `zle -I` invalidates the display first, since
# frtsx prints; `zle reset-prompt` redraws afterwards.
# ^P was zsh's default up-line-or-history, which nothing configures here and
# which atuin already owns on the Up arrow.
fzf-rtsx-widget() {
    zle -I
    frtsx
    zle reset-prompt
}
zle -N fzf-rtsx-widget
# ^P was zsh's default up-line-or-history; atuin owns the Up arrow.
bindkey '^P' fzf-rtsx-widget
