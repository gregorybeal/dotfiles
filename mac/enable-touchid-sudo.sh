#!/usr/bin/env bash
# mac/enable-touchid-sudo.sh — enable Touch ID for `sudo` on macOS.
# Idempotent — safe to re-run.
#
# Works in Ghostty (and any terminal) once pam_tid is enabled — Ghostty needs
# no special config of its own. The extra piece is pam_reattach, which is what
# makes the Touch ID prompt appear when you run sudo *inside tmux* (this repo
# uses tmux); without it, sudo inside tmux silently falls back to a password.
#
# Both auth lines go in /etc/pam.d/sudo_local — the Apple-blessed drop-in
# (macOS 14 Sonoma+) that /etc/pam.d/sudo includes and that survives OS
# updates. We never edit /etc/pam.d/sudo directly, which macOS overwrites on
# every update.

set -e

if [ "$(uname -s)" != "Darwin" ]; then
    echo "This script only applies to macOS."
    exit 1
fi

SUDO_LOCAL="/etc/pam.d/sudo_local"

# sudo_local is a macOS 14 (Sonoma) feature. On older macOS, /etc/pam.d/sudo
# has no `include sudo_local`, so a drop-in would be ignored.
if [ ! -f /etc/pam.d/sudo_local.template ] && ! grep -q "sudo_local" /etc/pam.d/sudo 2>/dev/null; then
    echo "This macOS version has no sudo_local support (needs macOS 14 Sonoma+)."
    echo "Skipping — enable Touch ID for sudo manually if you want it here."
    exit 0
fi

# --- pam_reattach: makes Touch ID work inside tmux/screen ---
# Installed via Brewfile (brew "pam-reattach"). Path differs by CPU arch.
REATTACH_LINE=""
for lib in /opt/homebrew/lib/pam/pam_reattach.so /usr/local/lib/pam/pam_reattach.so; do
    if [ -f "$lib" ]; then
        REATTACH_LINE="auth       optional       $lib"
        break
    fi
done
if [ -z "$REATTACH_LINE" ]; then
    echo "Note: pam-reattach not installed — Touch ID won't prompt inside tmux."
    echo "      Install it with 'brew install pam-reattach' (or 'make brew') and re-run."
fi

TID_LINE="auth       sufficient     pam_tid.so"

# Build the desired file content. pam_reattach MUST come before pam_tid.
build_content() {
    echo "# Managed by dotfiles (mac/enable-touchid-sudo.sh) — Touch ID for sudo."
    [ -n "$REATTACH_LINE" ] && echo "$REATTACH_LINE"
    echo "$TID_LINE"
}
DESIRED="$(build_content)"

# Already correct? Bail out without touching sudo.
if [ -f "$SUDO_LOCAL" ] && [ "$(cat "$SUDO_LOCAL")" = "$DESIRED" ]; then
    echo "Touch ID for sudo already enabled ($SUDO_LOCAL up to date) — skipping."
    exit 0
fi

echo "Enabling Touch ID for sudo (writing $SUDO_LOCAL, needs one sudo prompt)..."
printf '%s\n' "$DESIRED" | sudo tee "$SUDO_LOCAL" >/dev/null
sudo chmod 444 "$SUDO_LOCAL"

echo "✓ Touch ID for sudo enabled."
[ -n "$REATTACH_LINE" ] && echo "  (incl. tmux support via pam_reattach)"
echo "  Open a new sudo session to try it — e.g. 'sudo -k' then 'sudo true'."
