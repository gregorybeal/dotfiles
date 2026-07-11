# ---------- fzf register tools ----------
_REG_CONF="${REG_CONF:-$HOME/.ssh/conf.d/registers}"
_REG_DB="${REG_DB:-$HOME/store_registers.db}"
_REG_MNT="${REG_MNT:-$HOME/mnt/reg}"
# Formatter for the fzf preview pane, kept beside this file. %x is the file
# being sourced; :A resolves the stow symlink back into the repo.
_REG_PREVIEW_AWK="${${(%):-%x}:A:h}/reg-preview.awk"

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

# "hostname<TAB>store<TAB>city<TAB>state<TAB>regional" for every register in the
# database, using whichever of those columns actually exist. Fails when there is
# no usable database, so callers fall back to bare hostnames.
_reg_meta() {
    [[ -f $_REG_DB ]] || return 1
    command -v sqlite3 >/dev/null 2>&1 || return 1

    local schema tbl hostc sschema stbl skey
    schema=$(_reg_db_schema) || return 1
    tbl=${schema%%$'\t'*}
    hostc=${${schema#*$'\t'}%%$'\t'*}
    sschema=$(_reg_db_store) || return 1
    stbl=${sschema%%$'\t'*}
    skey=${sschema##*$'\t'}

    # Display columns, in order, skipping any this schema does not have.
    local c
    local -a want=(store_number store_city store_state store_regional) cols=()
    for c in $want; do
        _reg_db_has_col "$stbl" "$c" && cols+=("s.\"$c\"")
    done
    (( ${#cols} )) || return 1

    local join
    if _reg_db_has_col "$tbl" "$skey"; then
        join="s.\"$skey\" = r.\"$skey\""
    else
        join="s.\"$skey\" = substr(r.\"$hostc\", 1, 4)"
    fi

    sqlite3 -readonly -separator $'\t' "$_REG_DB" \
        "SELECT r.\"$hostc\", ${(j:, :)cols} FROM \"$tbl\" r
         LEFT JOIN \"$stbl\" s ON $join;" 2>/dev/null
}

# Like _reg_meta, but one row per register with the IP included, for consumers
# that build their own join/output rather than the aligned picker rows:
#   host<TAB>ip<TAB>store<TAB>city<TAB>state<TAB>regional
# Empty string for any column the schema lacks. Used by the Alfred script filter
# (mac/alfred/reg-filter.zsh) and the RoyalJSON generator (mac/royaltsx/). Same
# discovery primitives as _reg_meta; the IP lets the target be an address when
# /etc/hosts is not set up.
_reg_meta_full() {
    [[ -f $_REG_DB ]] && command -v sqlite3 >/dev/null 2>&1 || return 1
    local schema tbl hostc ipc
    schema=$(_reg_db_schema) || return 1
    tbl=${schema%%$'\t'*}
    hostc=${${schema#*$'\t'}%%$'\t'*}
    ipc=${schema##*$'\t'}

    local -a sel=("r.\"$hostc\"")
    sel+=("${ipc:+r.\"$ipc\"}"); [[ -n $ipc ]] || sel[-1]="''"

    local c sschema stbl skey join=""
    local -a scols=(store_number store_city store_state store_regional)
    if sschema=$(_reg_db_store); then
        stbl=${sschema%%$'\t'*}
        skey=${sschema##*$'\t'}
        for c in $scols; do
            if _reg_db_has_col "$stbl" "$c"; then sel+=("s.\"$c\""); else sel+=("''"); fi
        done
        if _reg_db_has_col "$tbl" "$skey"; then
            join="LEFT JOIN \"$stbl\" s ON s.\"$skey\" = r.\"$skey\""
        else
            join="LEFT JOIN \"$stbl\" s ON s.\"$skey\" = substr(r.\"$hostc\", 1, 4)"
        fi
    else
        sel+=("''" "''" "''" "''")
    fi

    sqlite3 -readonly -separator $'\t' "$_REG_DB" \
        "SELECT ${(j:, :)sel} FROM \"$tbl\" r $join;" 2>/dev/null
}

# The picker's rows: hostnames from the ssh config (still the inventory),
# decorated with store/city/state/regional from the database when it has them,
# aligned into columns. Field 1 is always the hostname — what fzf's {1} and the
# callers take. REG_PICK_PLAIN=1 forces bare hostnames.
_reg_rows() {
    local hosts
    hosts=$(_reg_hosts) || return 1

    local meta
    if [[ ${REG_PICK_PLAIN:-0} == 1 ]] || ! meta=$(_reg_meta) || [[ -z $meta ]]; then
        print -r -- "$hosts"
        return 0
    fi

    # Left join onto the ssh config, preserving its order and its host set: a
    # register missing from the database still gets a row, just a bare one.
    local joined
    joined=$(awk -F'\t' -v OFS='\t' '
        NR == FNR { key = $1; sub(/^[^\t]*\t/, ""); m[key] = $0; next }
        { print ($1 in m) ? $1 OFS m[$1] : $1 }' =(print -r -- "$meta") =(print -r -- "$hosts"))

    if command -v column >/dev/null 2>&1; then
        print -r -- "$joined" | column -t -s $'\t'
    else
        print -r -- "$joined"
    fi
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

    # The awk formatter aligns and colours the rows. Without it, fall back to
    # sqlite's own -line output rather than losing the preview entirely.
    # `registers` -> strip `register_`; `stores` -> strip `store_`. A table whose
    # name does not fit that pattern simply gets no prefix stripped.
    local nocolor=""
    [[ ${REG_PREVIEW_COLOR:-1} == 0 ]] && nocolor="-v nocolor=1"
    local fmt_reg="cat" fmt_store="cat"
    local regstrip="${tbl%s}_"
    if [[ -r $_REG_PREVIEW_AWK ]]; then
        local awkf=${(q)_REG_PREVIEW_AWK}
        fmt_reg="awk -v title=' register' -v strip=${(q)regstrip} $nocolor -f $awkf"
    fi

    # The store join is optional: plenty of inventories have no stores table.
    local storeq="" sschema stbl skey storesel where
    if sschema=$(_reg_db_store); then
        stbl=${sschema%%$'\t'*}
        skey=${sschema##*$'\t'}
        storesel=$(_reg_db_sel "$stbl") || storesel='*'
        local storestrip="${stbl%s}_"
        [[ -r $_REG_PREVIEW_AWK ]] && \
            fmt_store="awk -v title=' store' -v strip=${(q)storestrip} $nocolor -f ${(q)_REG_PREVIEW_AWK}"

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
                [ -n \"\$s\" ] && { printf '\\n'; printf '%s\\n' \"\$s\" | $fmt_store; };"
    fi

    reply=(
        --preview "h={1}; case \$h in \
                     *[!A-Za-z0-9_.-]*) printf ' %s\\n (no preview)\\n' \"\$h\";; \
                     *) r=\$($regq); \
                        if [ -n \"\$r\" ]; then printf '%s\\n' \"\$r\" | $fmt_reg; \
                        else printf ' %s\\n (not in %s)\\n' \"\$h\" ${(q)_REG_DB:t}; fi; \
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
    all=$(_reg_rows) || return
    _reg_preview_args
    print -r -- "$all" | fzf --prompt="${prompt} ❯ " --reverse --height=60% \
        --query="$query" "${reply[@]}" | awk '{print $1}'
}

# _reg_pick_expect <prompt> <expect-keys> <header> [query] — prints the pressed
# key (empty for Enter) on line 1, then one selected host per line. Tab
# multi-selects.
_reg_pick_expect() {
    local prompt="$1" keys="$2" header="$3" query="${4-}" all
    local -a reply
    all=$(_reg_rows) || return
    _reg_preview_args
    print -r -- "$all" | fzf --prompt="${prompt} ❯ " --reverse --height=60% --multi \
        --query="$query" --header="$header" --expect="$keys" "${reply[@]}" \
        | awk 'NR == 1 { print; next } { print $1 }'
}

# _reg_pick_multi <prompt> [query] — same, with Tab to multi-select
_reg_pick_multi() {
    local prompt="$1" query="${2-}" all
    local -a reply
    all=$(_reg_rows) || return
    _reg_preview_args
    print -r -- "$all" | fzf --prompt="${prompt} ❯ " --reverse --height=60% --multi \
        --query="$query" "${reply[@]}" | awk '{print $1}'
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

    if command -v osascript >/dev/null 2>&1; then
        # Enumerate every connection and exact-match the name in AppleScript,
        # then connect its id. Royal TSX does not support a `whose name is …`
        # filter on connections (its own Alfred workflow enumerates and loops
        # for exactly this reason), and the id keeps the match unambiguous when
        # one hostname is a prefix of another. The name is passed as an argv
        # value, not spliced into the script, so it needs no escaping.
        # "notfound" (or an empty result on any error) falls through to ad hoc.
        local res errf; errf=$(_reg_osa_errfile)
        res=$(osascript \
            -e 'on run argv' \
            -e 'set theName to item 1 of argv' \
            -e 'tell application "Royal TSX"' \
            -e 'set {conIds, conNames} to {id, name} of every connection' \
            -e 'repeat with i from 1 to count of conNames' \
            -e 'if (item i of conNames) is theName then' \
            -e 'activate' \
            -e 'connect (item i of conIds)' \
            -e 'return "ok"' \
            -e 'end if' \
            -e 'end repeat' \
            -e 'return "notfound"' \
            -e 'end tell' \
            -e 'end run' \
            -- "$name" 2>"$errf")
        _reg_osa_debug "$errf"
        [[ -n $REG_RTSX_DEBUG ]] && \
            print -u2 -P "%F{242}[rtsx] connect \"${name}\" -> ${res:-<none>}%f"
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
    [[ $OSTYPE == darwin* ]] || { print -u2 "frtsx: Royal TSX is macOS-only"; return 1 }

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

# ---------- yazi directory jump ----------
function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    command yazi "$@" --cwd-file="$tmp"
    IFS= read -r -d '' cwd < "$tmp"
    [ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
    command rm -f -- "$tmp"
}
