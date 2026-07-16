# Shared aliases for bash + zsh

# Listing (upgraded to eza below if present)
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'

# Safety
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Updating (brew/mas, so effectively Mac-only; update fetches metadata first,
# then upgrade installs — the old order ran them backwards, and `mas update`
# is not a mas subcommand)
if command -v brew >/dev/null 2>&1; then
    alias update='brew update && brew upgrade && mas upgrade'
fi

# Colors
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias df='df -h'

# tmux shortcuts
alias t='tmux'
alias ta='tmux attach -t'
alias tls='tmux ls'
alias tn='tmux new -s'
alias tk='tmux kill-session -t'

# Git shortcuts
alias gs='git status'
alias gd='git diff'
alias gl='git log --oneline --graph --decorate -20'
alias glog='PAGER="less -F -X" git log'
alias gadog='PAGER="less -F -X" git log --all --decorate --oneline --graph'
alias gp='git pull'
alias gpu='git push'
alias gco='git checkout'
alias gcm='git commit -m'
alias gca='git commit --amend'
alias gb='git branch'

# gh CLI shortcuts
alias ghsw='gh auth switch'
alias ghst='gh auth status'
alias ghl='gh pr list'
alias ghv='gh pr view --web'
alias ghc='gh pr create --fill --web'
alias ghi='gh issue list --assignee @me'

# uv (Python toolchain)
alias uvr='uv run'                          # run a script/command in project env
alias uvs='uv sync'                         # install/update from lockfile
alias uva='uv add'                          # add a dependency
alias uvrm='uv remove'                      # remove a dependency
alias uvt='uv tool'                         # uv tool subcommands
alias uvti='uv tool install'                # install a CLI tool globally
alias uvtu='uv tool upgrade --all'          # upgrade all installed tools
alias uvtl='uv tool list'                   # list installed tools
alias uvpy='uv python'                      # python version management
alias uvx='uv tool run'                     # one-off run (like pipx run)

# Editor
alias vim='nvim'

# Quick edits / reloads
alias reload-shell='exec $SHELL -l'
alias edit-zsh='${EDITOR:-vi} ~/.zshrc'
alias edit-tmux='${EDITOR:-vi} ~/.tmux.conf'
alias edit-ssh='${EDITOR:-vi} ~/.ssh/config'

# Modern CLI tool fallbacks — guarded, since bash in particular often runs
# on remote/restricted hosts that don't have these installed.
if command -v bat >/dev/null 2>&1; then alias cat='bat --paging=never'; fi
if command -v batcat >/dev/null 2>&1; then alias cat='batcat --paging=never'; fi
if command -v eza >/dev/null 2>&1; then
    alias ls='eza -a --icons'
    alias ll='eza -lh --icons --git'
    alias la='eza -lah --icons --git'
    alias tree='eza --tree --icons'
fi
if command -v fdfind >/dev/null 2>&1; then alias fd='fdfind'; fi
# No grep→rg alias: rg is not a drop-in (it recurses the cwd when given no
# path, and its flag set differs). grep stays grep; use rg by name.

# zsh-only: route ls's tab-completion through eza's own completion function
if [ -n "$ZSH_VERSION" ] && command -v eza >/dev/null 2>&1; then
    compdef eza=ls
fi

# IT-specific
alias myip='curl -s ifconfig.me; echo'
alias ports='netstat -tulanp 2>/dev/null || ss -tulnp'
alias dfh='df -h'
alias duh='du -h --max-depth=1 2>/dev/null | sort -h'

# Mac Global Protect (launchctl + these LaunchAgents only exist on macOS)
if [ "$(uname -s)" = "Darwin" ]; then
    alias gpstart='launchctl load /Library/LaunchAgents/com.paloaltonetworks.gp.pangp*'
    alias gpstop='launchctl unload /Library/LaunchAgents/com.paloaltonetworks.gp.pangp*'
fi

# SSH Tunnels
alias socks-up='tmux new -d -s sock1080 "ssh -N -D 127.0.0.1:1080 gbeal@lassssgate01.traderjoes.com" && tmux new -d -s sock1081 "ssh -N -D 127.0.0.1:1081 greg@100.118.20.30"'
alias socks-down='tmux kill-session -t sock1080 2>/dev/null; tmux kill-session -t sock1081 2>/dev/null'

# Tools
alias hdm='uv run --directory /Users/gbeal/Tools/hdmenu Menu.py'
alias cdid='uv run --project /Users/gbeal/Tools/Analysis /Users/gbeal/Tools/Analysis/loyalty_lookup.py'
