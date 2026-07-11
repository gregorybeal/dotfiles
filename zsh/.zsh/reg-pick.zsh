# reg-pick.zsh — the fzf picker every register tool shares: rows, preview,
# pick helpers, and the Ctrl-G insert-hostname widget.

# Formatter for the fzf preview pane, kept beside this file. %x is the file
# being sourced; :A resolves the stow symlink back into the repo.
_REG_PREVIEW_AWK="${${(%):-%x}:A:h}/reg-preview.awk"

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
