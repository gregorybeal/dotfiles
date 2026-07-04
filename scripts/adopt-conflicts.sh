#!/usr/bin/env bash
# scripts/adopt-conflicts.sh — move pre-existing files/symlinks out of the
# way of Stow before it runs, so a single conflict (e.g. Ubuntu's default
# skel ~/.bashrc, a manually-configured ~/.config/ghostty/config from before
# you adopted this repo, or — the case this was missing — a leftover real
# symlink from the old chezmoi setup pointing into its source repo instead
# of this one) doesn't abort deployment of every package. Stow itself is
# all-or-nothing per invocation: if ANY target conflicts, it aborts
# EVERYTHING, not just the conflicting package.
#
# Never deletes anything — conflicting files/symlinks are moved to a
# timestamped backup directory so you can diff/recover them afterward.
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

# Stow reports conflicts in (at least) two message shapes:
#   cannot stow .../pkg/path over existing target REL since neither a
#     link nor a directory and --adopt not specified      (a real file/dir)
#   existing target is not owned by stow: REL              (a symlink —
#     valid or dangling — that doesn't point into this repo, e.g. a
#     leftover chezmoi symlink_ target)
CONFLICTS="$(stow --simulate -v -d "$DOTFILES" -t "$HOME" "${PACKAGES[@]}" 2>&1 \
    | sed -n \
        -e 's/.*over existing target \(\S*\) since.*/\1/p' \
        -e 's/.*existing target is not owned by stow: *//p' \
    | sort -u)"

if [ -z "$CONFLICTS" ]; then
    exit 0
fi

while IFS= read -r rel; do
    [ -z "$rel" ] && continue
    target="$HOME/$rel"
    # If Stow's simulation flagged this path at all, it's already
    # determined it's not one of its own correctly-pointing symlinks —
    # back it up regardless of whether it's a real file, real directory,
    # or a symlink (valid or dangling) pointing somewhere else.
    if [ -e "$target" ] || [ -L "$target" ]; then
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
