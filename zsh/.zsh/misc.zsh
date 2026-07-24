# misc.zsh — small non-register helpers.

# ---------- yazi directory jump ----------
function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    command yazi "$@" --cwd-file="$tmp"
    IFS= read -r -d '' cwd < "$tmp"
    [ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
    command rm -f -- "$tmp"
}

# ---------- fuzzy alias picker ----------
# falias [query] — fuzzy-pick from `alias` and pre-load the name onto the
# next prompt (print -z), not execute it directly: aliases only exist in
# *this* shell, and stopping short of running it means you can still type
# arguments before pressing Enter yourself — real alias expansion, not a
# reimplementation of it. Same "pick, don't run" idea as _fzf_file_no_hidden
# in fzf.zsh.
falias() {
    local out
    out=$(alias | fzf --query="$1" --prompt='alias ❯ ') || return
    [[ -n $out ]] || return
    print -z -- "${out%%=*} "
}
