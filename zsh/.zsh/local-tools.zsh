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

# Find the table and columns that hold hostnames and IPs, printed as
# "table<TAB>hostcol<TAB>ipcol". Nothing about the inventory db's schema is
# guaranteed — the name "registers" was inherited from gen_ssh_registers.py and
# is not always right — so discover it instead of assuming, and let the user
# pin it with REG_DB_TABLE / REG_DB_HOST_COL / REG_DB_IP_COL.
_reg_db_schema() {
    if [[ -n $REG_DB_TABLE && -n $REG_DB_HOST_COL ]]; then
        print -r -- "${REG_DB_TABLE}"$'\t'"${REG_DB_HOST_COL}"$'\t'"${REG_DB_IP_COL:-}"
        return 0
    fi

    local -a tables cols
    local t hostc ipc c
    tables=(${(f)"$(sqlite3 -readonly "$_REG_DB" \
        "SELECT name FROM sqlite_master WHERE type IN ('table','view');" 2>/dev/null)"})

    for t in $tables; do
        cols=(${(f)"$(sqlite3 -readonly "$_REG_DB" "PRAGMA table_info('$t');" 2>/dev/null \
            | awk -F'|' '{print $2}')"})
        (( ${#cols} )) || continue

        # Prefer the most specific name, then anything host-ish.
        hostc=""
        for c in register_hostname hostname host_name host; do
            (( ${cols[(I)$c]} )) && { hostc=$c; break }
        done
        [[ -n $hostc ]] || for c in $cols; do
            [[ ${c:l} == *host* ]] && { hostc=$c; break }
        done
        [[ -n $hostc ]] || continue

        ipc=""
        for c in register_ip ip_address ipaddress ip addr; do
            (( ${cols[(I)$c]} )) && { ipc=$c; break }
        done
        [[ -n $ipc ]] || for c in $cols; do
            [[ ${c:l} == *ip* ]] && { ipc=$c; break }
        done

        print -r -- "$t"$'\t'"$hostc"$'\t'"$ipc"
        return 0
    done
    return 1
}

# Find the store table and the column holding the store number, as
# "table<TAB>keycol". Registers are named NNNNregNN, so the first four
# characters are the store number — the same derivation gen_ssh_registers.py
# uses to join. Pin with REG_DB_STORE_TABLE / REG_DB_STORE_COL.
_reg_db_store() {
    if [[ -n $REG_DB_STORE_TABLE && -n $REG_DB_STORE_COL ]]; then
        print -r -- "${REG_DB_STORE_TABLE}"$'\t'"${REG_DB_STORE_COL}"
        return 0
    fi

    local regtbl schema
    schema=$(_reg_db_schema) && regtbl=${schema%%$'\t'*}

    local -a tables cols
    local t c keyc
    tables=(${(f)"$(sqlite3 -readonly "$_REG_DB" \
        "SELECT name FROM sqlite_master WHERE type IN ('table','view');" 2>/dev/null)"})

    for t in $tables; do
        [[ $t == $regtbl ]] && continue          # the register table is not the store table
        cols=(${(f)"$(sqlite3 -readonly "$_REG_DB" "PRAGMA table_info('$t');" 2>/dev/null \
            | awk -F'|' '{print $2}')"})
        keyc=""
        for c in store_number store_num storenumber store_id store; do
            (( ${cols[(I)$c]} )) && { keyc=$c; break }
        done
        [[ -n $keyc ]] && { print -r -- "$t"$'\t'"$keyc"; return 0 }
    done
    return 1
}

_reg_db_cols() {
    sqlite3 -readonly "$_REG_DB" "PRAGMA table_info('$1');" 2>/dev/null | awk -F'|' '{print $2}'
}

_reg_db_has_col() {
    local -a cols; cols=(${(f)"$(_reg_db_cols "$1")"})
    (( ${cols[(I)$2]} ))
}

# A quoted, comma-separated column list for <table>, minus bookkeeping columns
# nobody wants staring at them in a preview pane. Still schema-agnostic: it
# names what to *hide*, never what to show.
_reg_db_sel() {
    local c out=""
    local -a skip=(id rowid sync_lock last_updated)
    for c in ${(f)"$(_reg_db_cols "$1")"}; do
        (( ${skip[(Ie)${c:l}]} )) && continue
        out+="${out:+, }\\\"$c\\\""
    done
    [[ -n $out ]] || return 1
    print -r -- "$out"
}

# Sets `reply` to the fzf preview flags, or leaves it empty when there is no
# database, no sqlite3, or no table that looks like an inventory. A missing
# table is a configuration fact, not a per-keystroke error, so it produces no
# preview rather than an error smeared across the pane. A query that fails at
# runtime still shows its error there.
#
# The preview uses `sqlite3 -line` to dump *every* column of the matched
# register row, then of the matched store row. Nothing is hardcoded, so city,
# state, regional and whatever else exists show up on their own, and a schema
# change cannot silently break it.
#
# fzf substitutes {} with a *shell-quoted* token — 0003reg01 arrives as
# '0003reg01' — so it must not be wrapped in quotes again, or sqlite sees
# ='' 0003reg01''. Assign it to h first (the shell strips fzf's quoting),
# then quote it exactly once. The case guard keeps a hostname that somehow
# contains a quote from breaking out of the SQL string.
_reg_preview_args() {
    reply=()
    [[ -f $_REG_DB ]] || return 0
    command -v sqlite3 >/dev/null 2>&1 || return 0

    local schema tbl hostc
    schema=$(_reg_db_schema) || return 0
    tbl=${schema%%$'\t'*}
    hostc=${${schema#*$'\t'}%%$'\t'*}

    local db=${(q)_REG_DB}
    local regsel; regsel=$(_reg_db_sel "$tbl") || regsel='*'
    local regq="sqlite3 -readonly -line $db \"SELECT $regsel FROM \\\"$tbl\\\" WHERE \\\"$hostc\\\"='\$h';\""

    # The store join is optional: plenty of inventories have no stores table.
    local storeq="" sschema stbl skey storesel where
    if sschema=$(_reg_db_store); then
        stbl=${sschema%%$'\t'*}
        skey=${sschema##*$'\t'}
        storesel=$(_reg_db_sel "$stbl") || storesel='*'

        # Prefer a real foreign key on the register row over deriving the store
        # from the hostname prefix. The prefix form only matches by accident when
        # the key column is INTEGER (affinity turns '0004' into 4), and it assumes
        # the NNNNregNN naming holds.
        if _reg_db_has_col "$tbl" "$skey"; then
            where="\\\"$skey\\\"=(SELECT \\\"$skey\\\" FROM \\\"$tbl\\\" WHERE \\\"$hostc\\\"='\$h')"
        else
            where="\\\"$skey\\\"=substr('\$h',1,4)"
        fi

        storeq="s=\$(sqlite3 -readonly -line $db \"SELECT $storesel FROM \\\"$stbl\\\" WHERE $where;\"); \
                [ -n \"\$s\" ] && { printf '\\n'; printf '%s\\n' \"\$s\"; };"
    fi

    reply=(
        --preview "h={}; case \$h in \
                     *[!A-Za-z0-9_.-]*) printf 'host : %s\\n(no preview)\\n' \"\$h\";; \
                     *) r=\$($regq); \
                        if [ -n \"\$r\" ]; then printf '%s\\n' \"\$r\"; \
                        else printf 'host : %s\\n(not in %s)\\n' \"\$h\" ${(q)_REG_DB:t}; fi; \
                        $storeq ;; \
                   esac"
        --preview-window=right,50%,wrap
    )
}

# _reg_pick <prompt> [query] — the one picker every f* tool uses, so search,
# preview and prompt style stay identical across them.
_reg_pick() {
    local prompt="$1" query="${2-}" all
    local -a reply
    all=$(_reg_hosts) || return
    _reg_preview_args
    print -r -- "$all" | fzf --prompt="${prompt} ❯ " --reverse --height=40% \
        --query="$query" "${reply[@]}"
}

# _reg_pick_expect <prompt> <expect-keys> <header> [query] — prints the pressed
# key (empty for Enter) on line 1, then one selected host per line. Tab
# multi-selects.
_reg_pick_expect() {
    local prompt="$1" keys="$2" header="$3" query="${4-}" all
    local -a reply
    all=$(_reg_hosts) || return
    _reg_preview_args
    print -r -- "$all" | fzf --prompt="${prompt} ❯ " --reverse --height=40% --multi \
        --query="$query" --header="$header" --expect="$keys" "${reply[@]}"
}

# _reg_pick_multi <prompt> [query] — same, with Tab to multi-select
_reg_pick_multi() {
    local prompt="$1" query="${2-}" all
    local -a reply
    all=$(_reg_hosts) || return
    _reg_preview_args
    print -r -- "$all" | fzf --prompt="${prompt} ❯ " --reverse --height=40% --multi \
        --query="$query" "${reply[@]}"
}

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

    local host
    host=$(_reg_pick mount "$1") || return
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
_REG_VNC_PORT="${REG_VNC_PORT:-5900}"    # VNC port on the register
_REG_VNC_BASE="${REG_VNC_BASE:-5901}"    # first local port to try
_REG_VNC_GRACE="${REG_VNC_GRACE:-20}"    # seconds for the viewer to connect
# A RealVNC connection file exported once from the GUI, with the password saved.
# fvnc rewrites its host/port per tunnel and forces Scaling.
_REG_VNC_TEMPLATE="${REG_VNC_TEMPLATE:-$HOME/.config/fvnc/register.vnc}"
# Client-side scale: the viewer resizes what it draws, the register's own
# display is untouched. RealVNC's exports omit this key entirely, so set it.
# AspectFit keeps the aspect ratio; Fit stretches; None gives scrollbars.
_REG_VNC_SCALING="${REG_VNC_SCALING:-AspectFit}"

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

# RealVNC's viewer binary. Named `vncviewer` too, so never look it up on PATH —
# that is TigerVNC's. Override with REG_VNC_BIN.
_reg_realvnc_bin() {
    if [[ -n $REG_VNC_BIN ]]; then
        [[ -x $REG_VNC_BIN ]] && { print -r -- "$REG_VNC_BIN"; return 0 }
        return 1
    fi
    local p="/Applications/VNC Viewer.app/Contents/MacOS/vncviewer"
    [[ -x $p ]] && { print -r -- "$p"; return 0 }
    return 1
}

# Copy the exported .vnc template, pointing it at this tunnel's local port, and
# print the temp file's path. The format is not assumed: whichever host (and
# optional port) key the exported file actually uses is rewritten in place, so
# the saved password, Scaling and everything else carry over untouched.
# Pure zsh on purpose: `grep` is aliased to `rg` in this shell, and zsh expands
# aliases when a function is *defined*, so a bare grep here silently became rg.
# No external text tools, no alias can reach it.
_reg_realvnc_config() {
    local lport="$1" tmpl="$_REG_VNC_TEMPLATE" out
    [[ -f $tmpl ]] || return 1

    local -a lines
    lines=("${(@f)$(<"$tmpl")}")

    # Some exports glue the port onto Host=, others keep a separate Port= line.
    local l key has_port=0
    for l in $lines; do
        key=${${${l%%=*}//[[:space:]]/}:l}
        [[ $key == port ]] && has_port=1
    done

    out=$(mktemp "${TMPDIR:-/tmp}/fvnc-XXXXXX") || return 1
    chmod 600 "$out"

    local seen_host=0 seen_scaling=0
    {
        # Quoted expansion: unquoted `$lines` would silently drop blank lines.
        for l in "${lines[@]}"; do
            key=${${${l%%=*}//[[:space:]]/}:l}
            case $key in
                host)
                    seen_host=1
                    if (( has_port )); then print -r -- "Host=127.0.0.1"
                    else print -r -- "Host=127.0.0.1:${lport}"; fi ;;
                port)    print -r -- "Port=${lport}" ;;
                scaling) seen_scaling=1; print -r -- "Scaling=${_REG_VNC_SCALING}" ;;
                *)       print -r -- "$l" ;;
            esac
        done
        # RealVNC's export omits Scaling when it is at the default, so add it.
        (( seen_scaling )) || print -r -- "Scaling=${_REG_VNC_SCALING}"
    } >"$out"

    if (( ! seen_host )); then
        print -u2 "fvnc: no Host= line in $tmpl — is that a RealVNC connection file?"
        rm -f "$out"
        return 1
    fi
    print -r -- "$out"
}

# Viewer preference:
#   1. REG_VNC_CMD                     — an explicit override
#   2. RealVNC + exported .vnc config  — scales (Scaling=AspectFit) and carries
#                                        its own saved password, so no prompt
#   3. TigerVNC (vncviewer on PATH)    — takes VNC_PASSWORD from the environment,
#                                        but has NO client-side scaling at all
#   4. Screen Sharing / remmina        — cannot be fed a password
_reg_vnc_open() {
    local addr="$1" pw
    pw=$(_reg_vnc_password) || pw=""
    # Classic VNC auth (RFB security type 2) has no username — only VeNCrypt/plain
    # does. Set REG_VNC_USER only if your server actually asks for one; it is not
    # the SSH login, which the ssh config already supplies.
    local user="${REG_VNC_USER:-}"

    local rbin rcfg
    if [[ -n $REG_VNC_CMD ]]; then
        VNC_USERNAME="$user" VNC_PASSWORD="$pw" eval "$REG_VNC_CMD $addr"
    elif rbin=$(_reg_realvnc_bin) && rcfg=$(_reg_realvnc_config "${addr##*:}"); then
        "$rbin" -config "$rcfg" >/dev/null 2>&1 &!
        # The viewer reads the config at startup; give it a moment, then remove
        # it — it holds the saved password.
        ( sleep 10; rm -f "$rcfg" ) >/dev/null 2>&1 &!
    elif command -v vncviewer >/dev/null 2>&1; then
        # -ViewOnly=0 explicitly: TigerVNC persists settings to default.tigervnc,
        # and a saved ViewOnly=1 silently swallows every keystroke and click.
        #
        # -RemoteResize=0: it defaults to *true*, which asks the register to
        # change its own screen resolution as this window is resized. Never do
        # that to a live POS terminal. Disabling it leaves the remote untouched;
        # the desktop is then shown 1:1 with scrollbars, because TigerVNC has no
        # client-side scaling at all (zero mentions of "scal" in 1.16.2's
        # parameters.cxx / DesktopWindow.cxx). RealVNC above is the viewer that
        # scales client-side; this branch is a fallback that will not fit.
        #
        # $REG_VNC_ARGS goes last so it can override anything set here.
        VNC_USERNAME="$user" VNC_PASSWORD="$pw" \
            vncviewer -ViewOnly=0 -RemoteResize=0 ${=REG_VNC_ARGS} "$addr" >/dev/null 2>&1 &!
    elif [[ $OSTYPE == darwin* ]]; then
        [[ -n $pw ]] && print -u2 "fvnc: Screen Sharing cannot take a password; install tiger-vnc"
        open "vnc://$addr"
    elif command -v remmina >/dev/null 2>&1; then
        remmina -c "vnc://$addr" >/dev/null 2>&1 &!
    else
        print "no VNC viewer found — point yours at $addr"
        print "install one: brew install tiger-vnc  /  sudo apt install tigervnc-viewer"
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

# Ctrl-G — inline fuzzy register picker (inserts hostname at cursor)
fzf-reg-widget() {
    local selected
    selected=$(_reg_pick_multi reg) || { zle reset-prompt; return }
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
    local host
    host=$(_reg_pick ssh) || { zle reset-prompt; return }
    [[ -z $host ]] && { zle reset-prompt; return }
    BUFFER="ssh ${(q)host}"
    zle accept-line
}
zle -N fzf-ssh-widget
bindkey '^O' fzf-ssh-widget

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

# frtsx [query] — pick a register by hostname and hand it to Royal TSX as an ad
# hoc connection. Enter opens VNC, Ctrl-S opens SSH.
#
# Royal TSX gets the IP, not the hostname: register names only resolve through
# the generated ssh config, which Royal TSX does not read. You still search by
# hostname — the IP is looked up after you pick.
#
# No tunnel and no credentials here: Royal TSX's ad hoc connection settings
# already supply the secure gateway and the credential. The URI carries only
# the protocol and the host, which is the form Royal Apps document
# (rtsx://web://host). Escaping is only needed when the URI carries
# user:pass@host:port, and query strings are ignored by Royal TSX on macOS.
frtsx() {
    [[ $OSTYPE == darwin* ]] || { print -u2 "frtsx: Royal TSX is macOS-only"; return 1 }

    local out key proto host ip rc=0
    out=$(_reg_pick_expect rtsx ctrl-s 'enter=vnc   ctrl-s=ssh   tab=multi-select' "$1") || return
    local -a lines; lines=("${(@f)out}")
    key=${lines[1]}
    local -a hosts=("${lines[@]:1}")   # line 1 is the key; the rest are hosts
    (( ${#hosts} )) || return

    [[ $key == ctrl-s ]] && proto=ssh || proto=vnc
    for host in $hosts; do
        if ip=$(_reg_ip "$host"); then
            print -P "%F{green}rtsx%f ${proto} → ${host} %F{242}(${ip})%f"
            open "rtsx://${proto}://${ip}"
        else
            rc=1
        fi
    done
    return $rc
}

# ---------- yazi directory jump ----------
function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    command yazi "$@" --cwd-file="$tmp"
    IFS= read -r -d '' cwd < "$tmp"
    [ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
    command rm -f -- "$tmp"
}
