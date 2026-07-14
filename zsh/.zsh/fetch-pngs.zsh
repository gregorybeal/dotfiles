#!/usr/bin/env zsh
#
# fetch-pngs — recursively pull all .png files from a remote directory
# over SSH, preserving the directory structure.
#
# Uses your existing ~/.ssh/config, so host aliases, ProxyJump, and the
# 1Password SSH agent all work exactly as they do with plain `ssh`.
#
# Usage:
#   fetch-pngs <remote_host> <remote_dir> [local_dir]
#
# Options (env vars, since this is meant to be sourced/called like your
# other reg-fzf.zsh helpers):
#   DRY_RUN=1     show what would be transferred, don't actually copy
#   FLAT=1        drop into local_dir with flattened names instead of
#                 mirroring the remote directory structure
#
# Examples:
#   fetch-pngs jumphost /var/log/screenshots ~/Downloads/screenshots
#   DRY_RUN=1 fetch-pngs reg-0142 /opt/app/receipts ./pngs
#   FLAT=1 fetch-pngs jumphost /data/exports ./flat-pngs

set -euo pipefail

fetch-pngs() {
    local remote_host="${1:-}"
    local remote_dir="${2:-}"
    local local_dir="${3:-./downloaded_pngs}"

    if [[ -z "$remote_host" || -z "$remote_dir" ]]; then
        print -u2 "Usage: fetch-pngs <remote_host> <remote_dir> [local_dir]"
        return 1
    fi

    mkdir -p "$local_dir"

    local -a rsync_flags
    rsync_flags=(-avz --progress --prune-empty-dirs)

    if [[ "${DRY_RUN:-0}" == "1" ]]; then
        rsync_flags+=(--dry-run)
        print "-- dry run: no files will be copied --"
    fi

    if [[ "${FLAT:-0}" == "1" ]]; then
        # Flatten: rsync can't flatten directly, so pull the file list and
        # scp each one into local_dir with a path-derived name to avoid
        # collisions.
        print "-- flat mode: fetching file list from ${remote_host} --"
        ssh "$remote_host" "find '${remote_dir%/}' -type f \( -iname '*.png' \)" \
        | while IFS= read -r remote_file; do
            local rel="${remote_file#${remote_dir%/}/}"
            local flat_name="${rel:gs/\//__/}"
            if [[ "${DRY_RUN:-0}" == "1" ]]; then
                print "would fetch: $remote_file -> $local_dir/$flat_name"
            else
                scp -q "${remote_host}:${remote_file}" "$local_dir/$flat_name"
            fi
        done
        return 0
    fi

    # Default: mirror remote directory structure locally.
    # --include='*/' must come before the *.png include so rsync
    # descends into subdirectories before filtering files.
    rsync "${rsync_flags[@]}" \
        --include='*/' \
        --include='*.png' \
        --include='*.PNG' \
        --exclude='*' \
        -e ssh \
        "${remote_host}:${remote_dir%/}/" \
        "$local_dir/"
}

# Allow running directly as a script (not just sourcing the function).
if [[ "${(%):-%N}" == "$0" ]]; then
    fetch-pngs "$@"
fi
