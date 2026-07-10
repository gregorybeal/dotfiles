#!/bin/zsh
# reg-connect.zsh — Alfred action: open the selected register in Royal TSX.
#
# Alfred passes the chosen item's arg ("<proto>\t<target>") as $1 or {query}.
# The default action is vnc; the cmd and alt modifiers swap in ssh and sftp.
# This is frtsx's handoff without the tunnel or the picker: adhoc via osascript
# (errors are visible, unlike `open`), falling back to open rtsx:// if the
# automation permission is refused.
emulate -L zsh
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# Alfred "input as argv" gives us $1=proto $2=target. Also accept a single
# space- or tab-delimited argument, so `reg-connect.zsh "vnc host"` works too.
local proto="$1" target="$2"
if [[ -z $target && $proto == *[[:space:]]* ]]; then
    target="${proto#*[[:space:]]}"
    proto="${proto%%[[:space:]]*}"
fi
[[ -n $proto && -n $target ]] || {
    print -u2 "reg-connect: expected '<proto> <target>', got: $*"
    exit 1
}

local conn="${proto}://${target}"
if command -v osascript >/dev/null 2>&1; then
    printf 'tell application "Royal TSX" to adhoc "%s"\n' "$conn" \
        | osascript - >/dev/null 2>&1 && exit 0
fi
open "rtsx://${conn}"
