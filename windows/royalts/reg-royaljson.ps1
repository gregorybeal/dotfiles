# reg-royaljson.ps1 — Royal TS (Windows) Dynamic Folder script.
#
# Paste this into the Dynamic Folder's Script tab with Script Interpreter set to
# PowerShell. It runs the same RoyalJSON generator the Mac uses
# (mac/royaltsx/reg-royaljson.zsh) inside WSL and passes its stdout through, so
# the objects — and the names frtsx connects by — are identical on both.
#
# wsl.exe starts the *default* distro as its default user; insert
# `-d <distro>` before `-e` if the dotfiles live in a different one
# (`wsl.exe -l -v` lists them). The generator's output is pure ASCII, so no
# console code page can mangle it on the way back to Royal TS. Its stderr is
# dropped so a stray warning can't corrupt the JSON.
$ErrorActionPreference = 'Stop'
wsl.exe -e zsh -c '~/dotfiles/mac/royaltsx/reg-royaljson.zsh 2>/dev/null'
