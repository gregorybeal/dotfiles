# local-tools.zsh — loader for the register/local tool modules.
#
# This file stays the single entry point: ~/.zshrc sources it, and so do the
# standalone launchers that need the same helpers outside an interactive
# shell (mac/alfred/*.zsh, mac/royaltsx/reg-royaljson.zsh). Splitting the
# implementation into per-concern files keeps each one readable; sourcing
# them from here keeps every consumer's contract unchanged.
#
# %x is the file being sourced; :A resolves the stow symlink back into the
# repo, so the modules load from wherever this file really lives.
() {
    local dir="${${(%):-%x}:A:h}" f
    for f in reg-db reg-pick reg-ssh reg-mounts reg-vnc reg-rtsx misc; do
        source "$dir/$f.zsh"
    done
}
