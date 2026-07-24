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
#
# Preview highlights the expansion as shell syntax via bat. There's no real
# file to point bat at (it's the RHS of an alias, not a path), so --language
# forces the grammar instead of bat's usual by-extension detection; "zsh" is
# one of the names bat maps to its Bash grammar (`bat --list-languages`), and
# close enough to zsh syntax for alias bodies. --delimiter='=' + {2..} feeds
# it everything after the alias's name= (an alias name can't itself contain
# "=", so splitting on the first one is unambiguous).
falias() {
    local out
    out=$(alias | fzf --delimiter='=' --query="$1" --prompt='alias ❯ ' \
        --preview='printf "%s\n" {2..} | bat --language=zsh --color=always --style=plain,numbers') \
        || return
    [[ -n $out ]] || return
    print -z -- "${out%%=*} "
}
