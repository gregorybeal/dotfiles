#!/bin/zsh
# store-filter.zsh — Alfred Script Filter: list POS stores as Alfred items.
#
# The store-level companion to reg-filter.zsh: one item per store, picking one
# opens every register at it in Royal TSX. Same two required Alfred settings as
# reg-filter.zsh (see mac/alfred/README.md): "Alfred filters results"
# UNCHECKED, and "with input as" set to argv — NOT {query}, which never
# populates $1. This runs on every keystroke and store-json.py filters itself
# (see reglib.query_matches for why: Alfred's own built-in live filter can fail
# on query text spanning a digit-to-letter boundary in one word).
# Reuses the schema discovery and helpers from ~/.zsh/local-tools.zsh, same as
# the register filter, so the two never drift.
#
# Emits Alfred JSON on stdout. Each item's arg is "<proto> <store>"; the cmd/alt
# modifiers swap the protocol. store-connect.zsh consumes that.
emulate -L zsh
setopt pipefail

# Alfred runs with a minimal environment. Put Homebrew ahead of the system so
# sqlite3 is found, then load the same machine-local config an interactive shell
# would (REG_DB, REG_HOSTS_FILE, ...).
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
[[ -f $HOME/.zshrc.local ]] && source "$HOME/.zshrc.local" 2>/dev/null
source "$HOME/.zsh/local-tools.zsh" 2>/dev/null

# The ssh config is the inventory: it decides which registers (and so which
# stores) exist; the database only decorates them. _reg_meta_full
# (host<TAB>ip<TAB>store<TAB>city<TAB>state<TAB>regional) is shared with the
# register filter and the RoyalJSON generator.
hosts=$(_reg_hosts 2>/dev/null) || {
    print -r -- '{"items":[{"title":"No register inventory","subtitle":"generate it: scripts/gen_ssh_registers.py","valid":false}]}'
    exit 0
}

print -r -- "$hosts" | python3 "${0:A:h}/store-json.py" <(_reg_meta_full) "$1"
