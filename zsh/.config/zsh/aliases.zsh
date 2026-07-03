# Shared aliases (bash + zsh)
[ -f "$HOME/.aliases.sh" ] && source "$HOME/.aliases.sh"

# ---------- Modern CLI tools (override the shared fallbacks above) ----------
alias ls='eza --icons'
alias ll='eza -lh --icons --git'
alias la='eza -lah --icons --git'
alias tree='eza --tree --icons'
compdef eza=ls

alias cat='bat'
alias grep='rg --color=auto'
alias diff='diff --color=auto'
alias df='df -h'

alias -- -='cd -'
alias vim='nvim'

# ---------- Git (extra, on top of ~/.aliases.sh git shortcuts) ----------
alias glog='PAGER="less -F -X" git log'
alias gadog='PAGER="less -F -X" git log --all --decorate --oneline --graph'
