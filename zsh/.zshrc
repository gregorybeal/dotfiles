# ~/.zshrc — stowed from ~/dotfiles/zsh
# Minimal zsh config, no framework. Plugins via zinit (see .zsh/plugins.zsh).

# =========================================================
# History
# =========================================================

HISTFILE="$XDG_STATE_HOME/zsh/history"
HISTSIZE=100000
SAVEHIST=100000

setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt EXTENDED_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS   # supersedes HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_FIND_NO_DUPS
setopt HIST_REDUCE_BLANKS

# =========================================================
# Shell behaviour
# =========================================================

setopt AUTOCD
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt NOBEEP
setopt NUMERIC_GLOB_SORT
setopt CORRECT
setopt INTERACTIVE_COMMENTS

# =========================================================
# zoxide
# =========================================================

command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"

# =========================================================
# Completion
# =========================================================

autoload -Uz compinit
compinit -d "$XDG_CACHE_HOME/zsh/zcompdump"
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no

# =========================================================
# Fuzzy finder (fzf shell integration — OS-dependent path)
# =========================================================

# First match wins — a system with more than one of these (e.g. Debian ships
# both /usr/share/fzf and /usr/share/doc/fzf/examples) must not source the
# keybindings twice.
for _fzf_dir in \
  /opt/homebrew/opt/fzf/shell \
  /usr/local/opt/fzf/shell \
  /usr/share/fzf \
  /usr/share/doc/fzf/examples
do
  if [[ -f $_fzf_dir/key-bindings.zsh ]]; then
    source "$_fzf_dir/key-bindings.zsh"
    [[ -f $_fzf_dir/completion.zsh ]] && source "$_fzf_dir/completion.zsh"
    break
  fi
done
unset _fzf_dir

# =========================================================
# Modular config
# =========================================================

source "$HOME/.zsh/fzf.zsh"
[ -f "$HOME/.aliases.sh" ] && source "$HOME/.aliases.sh"
source "$HOME/.zsh/bindings.zsh"
source "$HOME/.zsh/ssh-agent.zsh"
source "$HOME/.zsh/plugins.zsh"

# ---------- Prompt ----------
export VIRTUAL_ENV_DISABLE_PROMPT=1
FUNCNEST=100
command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"

source "$HOME/.zsh/local-tools.zsh"

# =========================================================
# Local-only / secrets
# =========================================================

[ -f "$HOME/.secrets" ] && source "$HOME/.secrets"
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
