#!/bin/sh
# frtsx-launch.sh — open a Ghostty window running the frtsx register picker.
#
# Bind this to a global hotkey (Keyboard Cowboy → ShellScripts, or Karabiner's
# shell_command) so frtsx is reachable from anywhere, not just an open terminal.
#
# The window runs an interactive zsh so ~/.zshrc (and ~/.zshrc.local) load and
# define frtsx with all its config — REG_DB, REG_RTSX_USER, and so on. When you
# pick a register, frtsx hands off to Royal TSX and the shell exits, so the
# window closes on its own: a picker that flashes up and is gone.
#
# macOS only: frtsx already refuses elsewhere, and Ghostty/Royal TSX are Mac.

# Keyboard Cowboy and Karabiner run scripts with a minimal PATH, so resolve
# Ghostty absolutely rather than trusting PATH.
ghostty=/Applications/Ghostty.app/Contents/MacOS/ghostty
[ -x "$ghostty" ] || ghostty=$(command -v ghostty 2>/dev/null)
[ -x "$ghostty" ] || {
    printf 'frtsx-launch: Ghostty not found\n' >&2
    exit 1
}

# -e runs the command in a new window instead of the default shell. `zsh -ic`
# gives an interactive shell (so frtsx and its env are loaded) and runs frtsx.
exec "$ghostty" -e zsh -ic frtsx
