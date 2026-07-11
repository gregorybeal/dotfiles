# reg-mounts.zsh — sshfs mounts of register filesystems: fmount / fumount /
# fmounts.
_REG_MNT="${REG_MNT:-$HOME/mnt/reg}"

# ---------- sshfs register mounts ----------
# sshfs shells out to ssh, so ~/.ssh/config drives these: the ProxyJump,
# User and ControlMaster from the generated conf.d/registers block all
# apply, and a warm control socket makes a mount near-instant.

# `mount` prints "<src> on <path> ..." on both Linux and macOS, so $3 is
# the mountpoint either way.
_reg_is_mounted() {
    mount | awk -v p="$1" '$3 == p { found = 1 } END { exit !found }'
}

_reg_unmount() {
    if command -v fusermount3 >/dev/null 2>&1; then fusermount3 -u "$1"
    elif command -v fusermount >/dev/null 2>&1; then fusermount -u "$1"
    else umount "$1"; fi   # macOS: fuse-t mounts unmount like any NFS mount
}

_reg_mounts() {
    mount | awk -v d="$_REG_MNT/" 'index($3, d) == 1 { print $3 }'
}

# fmount [-w] [query] — fuzzy-pick a register and sshfs-mount its root.
# Prints the mountpoint, so `cd "$(fmount)"` works. Read-only unless -w.
fmount() {
    command -v sshfs >/dev/null 2>&1 || {
        print -u2 "fmount: sshfs not found"
        print -u2 "  linux: sudo apt install sshfs"
        print -u2 "  macos: brew tap macos-fuse-t/cask && brew install fuse-t-sshfs"
        return 1
    }

    local rw=0
    [[ $1 == -w ]] && { rw=1; shift }

    local host
    host=$(_reg_pick mount "$1") || return
    [[ -n $host ]] || return

    local mp="$_REG_MNT/$host"
    if _reg_is_mounted "$mp"; then
        print -u2 "fmount: $host already mounted"
        print -r -- "$mp"
        return 0
    fi
    mkdir -p "$mp" || return

    local -a opts
    opts=(reconnect ServerAliveInterval=15 ServerAliveCountMax=3 follow_symlinks)
    (( rw )) || opts+=(ro)
    if [[ $OSTYPE == darwin* ]]; then
        opts+=(volname="$host" noappledouble)
    else
        opts+=(idmap=user)   # show remote posuser's files as us, not a stray uid
    fi

    if sshfs "$host:/" "$mp" -o "${(j:,:)opts}"; then
        print -r -- "$mp"
    else
        rmdir "$mp" 2>/dev/null
        print -u2 "fmount: failed to mount $host"
        return 1
    fi
}

# fumount [-a] — unmount register mounts (Tab to multi-select, -a for all)
fumount() {
    local all_mounts sel
    all_mounts=$(_reg_mounts)
    if [[ -z $all_mounts ]]; then
        print -u2 "fumount: no register mounts under $_REG_MNT"
        return 1
    fi

    if [[ $1 == -a ]]; then
        sel="$all_mounts"
    else
        sel=$(print -r -- "$all_mounts" \
                | fzf --prompt='unmount ❯ ' --reverse --height=40% --multi) || return
    fi
    [[ -n $sel ]] || return

    local mp rc=0
    while IFS= read -r mp; do
        # </dev/null: keep the unmount helper off the loop's herestring
        if _reg_unmount "$mp" </dev/null; then
            rmdir "$mp" 2>/dev/null
            print -P "%F{green}unmounted%f $mp"
        else
            print -u2 "fumount: failed to unmount $mp"
            rc=1
        fi
    done <<< "$sel"
    return $rc
}

# fmounts — list active register mounts
fmounts() {
    local m
    m=$(_reg_mounts)
    [[ -n $m ]] && print -r -- "$m" || print "(no register mounts)"
}

