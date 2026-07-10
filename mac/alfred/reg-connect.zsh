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

local input="${1:-$*}"
local proto="${input%%$'\t'*}"
local target="${input#*$'\t'}"
[[ -n $proto && -n $target && $proto != $target ]] || {
    print -u2 "reg-connect: bad input: $input"
    exit 1
}

local conn="${proto}://${target}"
if command -v osascript >/dev/null 2>&1; then
    printf 'tell application "Royal TSX" to adhoc "%s"\n' "$conn" \
        | osascript - >/dev/null 2>&1 && exit 0
fi
open "rtsx://${conn}"
