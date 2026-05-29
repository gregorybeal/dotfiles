# ~/.bashrc — managed by dotfiles repo
# Lightweight: only the essentials, since bash often runs on remote/restricted hosts

# ---------- History ----------
HISTSIZE=50000
HISTFILESIZE=50000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend
shopt -s checkwinsize
shopt -s globstar  # enable ** recursive globbing

# ---------- Prompt: Starship if available, fall back to a simple prompt ----------
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
else
    # Fallback: simple prompt with git branch
    parse_git_branch() {
        git branch 2>/dev/null | sed -n 's/^\* \(.*\)/ (\1)/p'
    }
    PS1='\[\e[36m\]\u@\h\[\e[0m\] \[\e[33m\]\w\[\e[0m\]\[\e[32m\]$(parse_git_branch)\[\e[0m\]\n\$ '
fi
# ---------- Prompt: Starship if available, fall back to a simple prompt ----------
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
else
    # Fallback: simple prompt with git branch
    parse_git_branch() {
        git branch 2>/dev/null | sed -n 's/^\* \(.*\)/ (\1)/p'
    }
    PS1='\[\e[36m\]\u@\h\[\e[0m\] \[\e[33m\]\w\[\e[0m\]\[\e[32m\]$(parse_git_branch)\[\e[0m\]\n\$ '
fi

# ---------- Shared aliases ----------
[ -f "$HOME/.aliases.sh" ] && source "$HOME/.aliases.sh"

# ---------- reg-tool (only on machines where it's installed) ----------
[ -f "$HOME/.config/reg-tool/reg.sh" ] && source "$HOME/.config/reg-tool/reg.sh"

# ---------- fzf ----------
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

# ---------- uv (Python toolchain) ----------
if command -v uv >/dev/null 2>&1; then
    eval "$(uv generate-shell-completion bash)"
fi

# ---------- PATH additions ----------
[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH"
[ -d "$HOME/bin" ] && export PATH="$HOME/bin:$PATH"
[ -d "$HOME/.fzf/bin" ] && export PATH="$HOME/.fzf/bin:$PATH"

# ---------- Local-only ----------
[ -f "$HOME/.secrets" ] && source "$HOME/.secrets"
[ -f "$HOME/.bashrc.local" ] && source "$HOME/.bashrc.local"
