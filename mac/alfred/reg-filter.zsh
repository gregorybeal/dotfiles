#!/bin/zsh
# reg-filter.zsh — Alfred Script Filter: list POS registers as Alfred items.
#
# Set the Script Filter to "Alfred filters results": this runs once per keyword
# invocation, emits every register, and lets Alfred do the live matching. It
# reuses the schema discovery and helpers from ~/.zsh/local-tools.zsh, so it
# stays in step with the fzf tools and never re-hardcodes a table or column.
#
# Emits Alfred JSON on stdout. Each item's arg is "<proto>\t<target>"; the
# cmd/alt modifiers swap the protocol. reg-connect.zsh consumes that.
emulate -L zsh
setopt pipefail

# Alfred runs with a minimal environment. Put Homebrew ahead of the system so
# sqlite3 is found, then load the same machine-local config an interactive shell
# would (REG_DB, REG_RTSX_USER, REG_RTSX_TARGET, REG_HOSTS_FILE, ...).
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
[[ -f $HOME/.zshrc.local ]] && source "$HOME/.zshrc.local" 2>/dev/null
source "$HOME/.zsh/local-tools.zsh" 2>/dev/null

# host<TAB>ip<TAB>store<TAB>city<TAB>state<TAB>regional for every register in the
# database, using whichever of those columns exist. Same discovery primitives as
# _reg_meta, with the IP added so the target can be an IP when /etc/hosts is not
# set up. Empty string for any column the schema lacks.
_reg_alfred_meta() {
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

# The ssh config is the inventory: it decides which registers exist. Metadata
# decorates it. A register the database has never heard of still gets an item.
hosts=$(_reg_hosts 2>/dev/null) || {
    print -r -- '{"items":[{"title":"No register inventory","subtitle":"generate it: scripts/gen_ssh_registers.py","valid":false}]}'
    exit 0
}

print -r -- "$hosts" | python3 "${0:A:h}/reg-json.py" <(_reg_alfred_meta)
