# ~/.config/zsh/.zshenv

# ---------- XDG base directories ----------
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

# ---------- Editor ----------
export EDITOR="nvim"
export VISUAL="nvim"

# ---------- Pager (colorized man pages) ----------
if command -v bat >/dev/null 2>&1; then
  export MANPAGER="bat -l man -p"
elif command -v batcat >/dev/null 2>&1; then
  export MANPAGER="batcat -l man -p"
fi

# ---------- GPG ----------
export GPG_TTY=$(tty)

# ---------- PATH additions ----------
export PATH="$HOME/.local/bin:$PATH"
[[ -d "$HOME/bin" ]] && export PATH="$HOME/bin:$PATH"
[[ -d "$HOME/.fzf/bin" ]] && export PATH="$HOME/.fzf/bin:$PATH"
[[ -f "$HOME/.atuin/bin/env" ]] && source "$HOME/.atuin/bin/env"

# ---------- macOS ----------
if [[ "$(uname -s)" == "Darwin" ]]; then
  [[ -d /opt/homebrew/bin ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
  export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
fi
