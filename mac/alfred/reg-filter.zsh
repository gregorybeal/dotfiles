#!/bin/zsh
# reg-filter.zsh — Alfred Script Filter: list POS registers as Alfred items.
#
# Two Alfred settings, both required (see mac/alfred/README.md for the full
# why): leave "Alfred filters results" UNCHECKED, and once that unlocks the
# "with input as" dropdown, set it to argv — NOT {query}. {query} mode does a
# literal text substitution into the Script field itself and never touches $1;
# argv is what actually puts Alfred's live query in $1, which this script (via
# reg-json.py) needs on every keystroke to filter itself (plain
# case-insensitive substring per whitespace-split term — see
# reglib.query_matches). Do NOT check "Alfred filters results" either: Alfred's
# own built-in live filter can fail on query text that crosses a digit-to-letter
# boundary inside one word — e.g. typing the full hostname "0112reg99" can
# return zero results even though "0112" alone matches everything — which is
# exactly the bug this design avoids.
#
# Reuses the schema discovery and helpers from ~/.zsh/local-tools.zsh, so it
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

# The ssh config is the inventory: it decides which registers exist. Metadata
# decorates it. A register the database has never heard of still gets an item.
# _reg_meta_full (host<TAB>ip<TAB>store<TAB>city<TAB>state<TAB>regional) comes
# from local-tools.zsh, shared with the RoyalJSON generator.
hosts=$(_reg_hosts 2>/dev/null) || {
    print -r -- '{"items":[{"title":"No register inventory","subtitle":"generate it: scripts/gen_ssh_registers.py","valid":false}]}'
    exit 0
}

print -r -- "$hosts" | python3 "${0:A:h}/reg-json.py" <(_reg_meta_full) "$1"
