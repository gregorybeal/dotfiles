# ~/.zshrc — managed by dotfiles repo

# ---------- Oh My Zsh ----------
export ZSH="$HOME/.oh-my-zsh"
# Theme handled by Starship below — set to empty so omz doesn't override
ZSH_THEME=""

plugins=(
    git
    ssh-agent
    history-substring-search
    sudo
    ansible
    docker
    pip
    zsh-autosuggestions
    zsh-syntax-highlighting
)

# Only source omz if it's installed (so this file works on a fresh box
# before omz is set up)
if [ -f "$ZSH/oh-my-zsh.sh" ]; then
    source "$ZSH/oh-my-zsh.sh"
fi

# ---------- Starship prompt ----------
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi

# ---------- History ----------
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE     # commands starting with space aren't saved
setopt HIST_REDUCE_BLANKS
setopt INC_APPEND_HISTORY
setopt EXTENDED_HISTORY

# ---------- Options ----------
setopt AUTO_CD               # type a dir name to cd into it
setopt AUTO_PUSHD            # cd pushes onto dir stack
setopt PUSHD_IGNORE_DUPS
setopt CORRECT               # spelling correction
setopt INTERACTIVE_COMMENTS  # allow # comments in interactive shells

# ---------- Key bindings ----------
bindkey -e                                    # emacs mode
bindkey '^[[A' history-substring-search-up    # up arrow
bindkey '^[[B' history-substring-search-down  # down arrow
bindkey '^R' history-incremental-search-backward

# ---------- Shared aliases ----------
[ -f "$HOME/.aliases.sh" ] && source "$HOME/.aliases.sh"

# ---------- reg-tool ----------
[ -f "$HOME/.config/reg-tool/reg.sh" ] && source "$HOME/.config/reg-tool/reg.sh"

# ---------- fzf ----------
# Installed via brew / apt — adds Ctrl-R fuzzy history search, Ctrl-T file picker
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] && source /usr/share/doc/fzf/examples/key-bindings.zsh
[ -f /usr/share/fzf/key-bindings.zsh ] && source /usr/share/fzf/key-bindings.zsh

# ---------- Local-only / secrets ----------
# Anything machine-specific or sensitive goes here, NOT in the repo
[ -f "$HOME/.secrets" ] && source "$HOME/.secrets"
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"

# ---------- PATH additions ----------
# Homebrew on Apple Silicon
[ -d /opt/homebrew/bin ] && export PATH="/opt/homebrew/bin:$PATH"
# User-local bins
[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH"
[ -d "$HOME/bin" ] && export PATH="$HOME/bin:$PATH"
[ -d "$HOME/.fzf/bin" ] && export PATH="$HOME/.fzf/bin:$PATH"
