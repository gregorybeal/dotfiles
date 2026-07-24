# ~/.bashrc — stowed from ~/dotfiles/bash
# Lightweight: only the essentials, since bash often runs on remote/restricted hosts

# ---------- History ----------
HISTSIZE=50000
HISTFILESIZE=50000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend
shopt -s checkwinsize
shopt -s globstar

# ---------- PATH additions ----------
[[ "$(uname -s)" == "Darwin" ]] && [[ -d /opt/homebrew/bin ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH"
[ -d "$HOME/bin" ] && export PATH="$HOME/bin:$PATH"
[ -d "$HOME/.fzf/bin" ] && export PATH="$HOME/.fzf/bin:$PATH"
[ -f "$HOME/.atuin/bin/env" ] && source "$HOME/.atuin/bin/env"

# ---------- Prompt ----------
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
else
    parse_git_branch() {
        git branch 2>/dev/null | sed -n 's/^\* \(.*\)/ (\1)/p'
    }
    PS1='\[\e[36m\]\u@\h\[\e[0m\] \[\e[33m\]\w\[\e[0m\]\[\e[32m\]$(parse_git_branch)\[\e[0m\]\n\$ '
fi

# ---------- Shared aliases ----------
[ -f "$HOME/.aliases.sh" ] && source "$HOME/.aliases.sh"

# ---------- fzf ----------
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

# ---------- uv (Python toolchain) ----------
command -v uv >/dev/null 2>&1 && eval "$(uv generate-shell-completion bash)"

# ---------- Local-only ----------
[ -f "$HOME/.secrets" ] && source "$HOME/.secrets"
[ -f "$HOME/.bashrc.local" ] && source "$HOME/.bashrc.local"

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/gbeal/.lmstudio/bin"
# End of LM Studio CLI section

