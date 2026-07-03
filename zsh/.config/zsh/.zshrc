# ~/.config/zsh/.zshrc — stowed from ~/dotfiles/zsh
# Minimal zsh config, no framework. Plugins via zinit (see plugins.zsh).

# Normally ZDOTDIR and the XDG_* vars are set by ~/.zshenv and
# $ZDOTDIR/.zshenv before .zshrc is ever reached — but that only happens
# on a genuinely fresh shell startup. If this file gets manually `source`d
# in an existing shell that predates that (e.g. an old terminal still
# running from before this repo was stowed), fall back the same way so
# the sourcing/HISTFILE/compinit paths below don't silently break.
: "${ZDOTDIR:=$HOME/.config/zsh}"
[ -z "$XDG_STATE_HOME" ] && [ -f "$ZDOTDIR/.zshenv" ] && source "$ZDOTDIR/.zshenv"

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
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
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
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

# =========================================================
# Fuzzy finder (fzf shell integration — OS-dependent path)
# =========================================================

if [[ -f /opt/homebrew/opt/fzf/shell/key-bindings.zsh ]]; then
  source /opt/homebrew/opt/fzf/shell/key-bindings.zsh
  source /opt/homebrew/opt/fzf/shell/completion.zsh
fi
if [[ -f /usr/local/opt/fzf/shell/key-bindings.zsh ]]; then
  source /usr/local/opt/fzf/shell/key-bindings.zsh
  source /usr/local/opt/fzf/shell/completion.zsh
fi
if [[ -f /usr/share/fzf/key-bindings.zsh ]]; then
  source /usr/share/fzf/key-bindings.zsh
  source /usr/share/fzf/completion.zsh
fi
if [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]]; then
  source /usr/share/doc/fzf/examples/key-bindings.zsh
  source /usr/share/doc/fzf/examples/completion.zsh
fi

# =========================================================
# Modular config
# =========================================================

source "$ZDOTDIR/fzf.zsh"
[ -f "$HOME/.aliases.sh" ] && source "$HOME/.aliases.sh"
source "$ZDOTDIR/bindings.zsh"
source "$ZDOTDIR/plugins.zsh"
source "$ZDOTDIR/prompt.zsh"
source "$ZDOTDIR/local-tools.zsh"

# =========================================================
# Local-only / secrets
# =========================================================

[ -f "$HOME/.secrets" ] && source "$HOME/.secrets"
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
