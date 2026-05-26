# ~/.bashrc — managed by dotfiles repo
# Lightweight: only the essentials, since bash often runs on remote/restricted hosts

# ---------- History ----------
HISTSIZE=50000
HISTFILESIZE=50000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend
shopt -s checkwinsize
shopt -s globstar  # enable ** recursive globbing

# ---------- Prompt (simple, works without nerd fonts) ----------
# Format: [user@host dir (git-branch)]$
parse_git_branch() {
    git branch 2>/dev/null | sed -n 's/^\* \(.*\)/ (\1)/p'
}
PS1='\[\e[36m\]\u@\h\[\e[0m\] \[\e[33m\]\w\[\e[0m\]\[\e[32m\]$(parse_git_branch)\[\e[0m\]\n\$ '

# ---------- Shared aliases ----------
[ -f "$HOME/.aliases.sh" ] && source "$HOME/.aliases.sh"

# ---------- reg-tool (only on machines where it's installed) ----------
[ -f "$HOME/.config/reg-tool/reg.sh" ] && source "$HOME/.config/reg-tool/reg.sh"

# ---------- fzf ----------
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

# ---------- Local-only ----------
[ -f "$HOME/.secrets" ] && source "$HOME/.secrets"
[ -f "$HOME/.bashrc.local" ] && source "$HOME/.bashrc.local"
