#!/bin/zsh
# reg-connect.zsh — Alfred action: open the selected register in Royal TSX.
#
# Alfred passes the chosen item's arg ("<proto> <host>") as $1 $2, or as a
# single space/tab-delimited {query}. The default action is vnc; the cmd and alt
# modifiers swap in ssh and sftp (see reg-json.py).
#
# This is frtsx's handoff without the picker: it opens the register's *stored*
# Royal TSX object — the one the RoyalJSON dynamic folder generated, which
# carries the secure gateway and credential inherited from its folder — and
# falls back to an ad hoc connection when no such object exists. That logic lives
# in _reg_rtsx_connect (~/.zsh/local-tools.zsh), shared with frtsx, so the two
# handoffs stay identical.
emulate -L zsh
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# Load the same machine-local config an interactive shell would (REG_DB,
# REG_RTSX_USER, REG_RTSX_TARGET, REG_HOSTS_FILE, ...) and the shared helpers.
[[ -f $HOME/.zshrc.local ]] && source "$HOME/.zshrc.local" 2>/dev/null
source "$HOME/.zsh/local-tools.zsh" 2>/dev/null

# Alfred "input as argv" gives us $1=proto $2=host. Also accept a single
# space- or tab-delimited argument, so `reg-connect.zsh "vnc 0003reg01"` works.
local proto="$1" host="$2"
if [[ -z $host && $proto == *[[:space:]]* ]]; then
    host="${proto#*[[:space:]]}"
    proto="${proto%%[[:space:]]*}"
fi
[[ -n $proto && -n $host ]] || {
    print -u2 "reg-connect: expected '<proto> <host>', got: $*"
    exit 1
}

_reg_rtsx_connect "$proto" "$host"
