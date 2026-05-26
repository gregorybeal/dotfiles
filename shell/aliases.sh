# Shared aliases for bash + zsh

# Listing
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Safety
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Colors
alias grep='grep --color=auto'
alias diff='diff --color=auto'

# tmux shortcuts
alias t='tmux'
alias ta='tmux attach -t'
alias tls='tmux ls'
alias tn='tmux new -s'
alias tk='tmux kill-session -t'

# Git shortcuts (in addition to omz git plugin)
alias gs='git status'
alias gd='git diff'
alias gl='git log --oneline --graph --decorate -20'
alias gp='git pull'
alias gpu='git push'
alias gco='git checkout'
alias gcm='git commit -m'
alias gca='git commit --amend'
alias gb='git branch'

# gh CLI shortcuts
alias ghs='gh pr status'
alias ghl='gh pr list'
alias ghv='gh pr view --web'
alias ghc='gh pr create --fill --web'
alias ghi='gh issue list --assignee @me'

# Quick edits / reloads
alias reload-shell='exec $SHELL -l'
alias edit-zsh='${EDITOR:-vi} ~/.zshrc'
alias edit-tmux='${EDITOR:-vi} ~/.tmux.conf'
alias edit-ssh='${EDITOR:-vi} ~/.ssh/config'

# Modern CLI tool fallbacks (use better tool if present)
if command -v bat >/dev/null 2>&1; then alias cat='bat --paging=never'; fi
if command -v batcat >/dev/null 2>&1; then alias cat='batcat --paging=never'; fi
if command -v eza >/dev/null 2>&1; then alias ls='eza'; alias ll='eza -lah --git'; fi
if command -v fdfind >/dev/null 2>&1; then alias fd='fdfind'; fi

# IT-specific
alias myip='curl -s ifconfig.me; echo'
alias ports='netstat -tulanp 2>/dev/null || ss -tulnp'
alias dfh='df -h'
alias duh='du -h --max-depth=1 2>/dev/null | sort -h'
