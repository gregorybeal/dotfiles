#!/usr/bin/env bash
# scripts/adopt-conflicts.sh — move pre-existing real files out of the way
# of Stow before it runs, so a single conflicting file (e.g. Ubuntu's
# default skel ~/.bashrc, or a manually-configured ~/.config/ghostty/config
# from before you adopted this repo) doesn't abort deployment of every
# package. Stow itself is all-or-nothing per invocation: if ANY target
# conflicts, it aborts EVERYTHING, not just the conflicting package.
#
# Never deletes anything — conflicting files are moved to a timestamped
# backup directory so you can diff/recover them afterward.
set -e

DOTFILES="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DOTFILES"

PACKAGES=("$@")
if [ ${#PACKAGES[@]} -eq 0 ]; then
    echo "Usage: $0 <package> [package...]" >&2
    exit 1
fi

BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
FOUND=0

CONFLICTS="$(stow --simulate -v -d "$DOTFILES" -t "$HOME" "${PACKAGES[@]}" 2>&1 \
    | sed -n 's/.*over existing target \(\S*\) since.*/\1/p' \
    | sort -u)"

if [ -z "$CONFLICTS" ]; then
    exit 0
fi

while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    target="$HOME/$rel"
    # Only move real files/dirs — never touch an existing symlink (that's
    # a legitimate re-stow case, not a conflict Stow would even report).
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        FOUND=1
        mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
        echo "  Backing up ~/$rel -> $BACKUP_DIR/$rel"
        mv "$target" "$BACKUP_DIR/$rel"
    fi
done <<< "$CONFLICTS"

if [ "$FOUND" -eq 1 ]; then
    echo ""
    echo "Pre-existing files backed up to $BACKUP_DIR"
    echo "(nothing was deleted — review and remove the backup once you've confirmed you don't need it)"
fi
