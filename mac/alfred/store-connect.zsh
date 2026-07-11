#!/bin/zsh
# store-connect.zsh — Alfred action: open every register at the selected store
# in Royal TSX.
#
# Alfred passes the chosen item's arg ("<proto> <store>") as $1 $2, or as a
# single space/tab-delimited {query}. The default action is vnc; the cmd and alt
# modifiers swap in ssh and sftp (see store-json.py). The connect-all logic lives
# in _reg_rtsx_store (~/.zsh/local-tools.zsh), shared with frtsx-store, so the
# Alfred and shell paths open a store identically.
emulate -L zsh
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# Load the same machine-local config an interactive shell would (REG_DB,
# REG_RTSX_USER, REG_RTSX_TARGET, REG_HOSTS_FILE, ...) and the shared helpers.
[[ -f $HOME/.zshrc.local ]] && source "$HOME/.zshrc.local" 2>/dev/null
source "$HOME/.zsh/local-tools.zsh" 2>/dev/null

# Alfred "input as argv" gives us $1=proto $2=store. Also accept a single
# space- or tab-delimited argument, so `store-connect.zsh "vnc 0003"` works.
local proto="$1" store="$2"
if [[ -z $store && $proto == *[[:space:]]* ]]; then
    store="${proto#*[[:space:]]}"
    proto="${proto%%[[:space:]]*}"
fi
[[ -n $proto && -n $store ]] || {
    print -u2 "store-connect: expected '<proto> <store>', got: $*"
    exit 1
}

_reg_rtsx_store "$proto" "$store"
