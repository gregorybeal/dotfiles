# =========================================================
# zinit (self-installing)
# =========================================================

ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
if [[ ! -d "$ZINIT_HOME" ]]; then
  mkdir -p "$(dirname "$ZINIT_HOME")"
  git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi
source "${ZINIT_HOME}/zinit.zsh"

# =========================================================
# fzf-tab — must load after compinit, before widget-wrapping
# plugins (autosuggestions, fast-syntax-highlighting)
# =========================================================

zinit light Aloxaf/fzf-tab

zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
zstyle ':fzf-tab:*' fzf-flags --height=60% --layout=reverse

# =========================================================
# Plugins
# =========================================================

zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-history-substring-search
zinit light jeffreytse/zsh-vi-mode
zinit light zdharma-continuum/fast-syntax-highlighting
