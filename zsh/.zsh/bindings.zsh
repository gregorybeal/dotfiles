# =========================================================
# Keymap
# =========================================================

# Emacs keymap, explicitly. Without this zsh picks the keymap from $VISUAL /
# $EDITOR, and "nvim" matches *vi* — so an unset keymap silently lands you in
# vi mode even with no vi-mode plugin installed.
bindkey -e

# =========================================================
# Key bindings
# =========================================================
# bindkey accepts a widget that does not exist yet; the name resolves when the
# key is pressed. So these can sit here even though autosuggestions and
# history-substring-search are loaded later, in plugins.zsh.

bindkey '^[[1;5C' forward-word            # Ctrl-Right
bindkey '^[[1;5D' backward-word           # Ctrl-Left
bindkey '^F' _fzf_file_no_hidden          # Ctrl-F: fzf, no hidden files
bindkey '^\' autosuggest-toggle           # Ctrl-\: toggle autosuggestions
bindkey '^[[B' history-substring-search-down

# atuin owns Ctrl-R and Up (no --disable-up-arrow); Down stays on
# history-substring-search above, since atuin's init does not bind it.
command -v atuin >/dev/null 2>&1 && eval "$(atuin init zsh)"

# =========================================================
# ssh-agent (persistent across sessions)
# Replicates the OMZ ssh-agent plugin's behaviour: reuse a
# running agent via a per-host env file, start one if needed,
# load default keys. macOS uses the 1Password agent instead
# (SSH_AUTH_SOCK set in .zshenv), so this is Linux/WSL-only.
# =========================================================

if [[ "$(uname -s)" != "Darwin" ]]; then
  _ssh_env_cache="$HOME/.ssh/environment-${HOST%%.*}"

  [[ -f "$_ssh_env_cache" ]] && source "$_ssh_env_cache" >/dev/null

  if [[ ! -S "$SSH_AUTH_SOCK" ]]; then
    ssh-agent -s | sed '/^echo/d' >! "$_ssh_env_cache"
    chmod 600 "$_ssh_env_cache"
    source "$_ssh_env_cache" >/dev/null
  fi

  for _id in id_rsa id_dsa id_ecdsa id_ed25519 id_ed25519_sk identity; do
    if [[ -f "$HOME/.ssh/$_id" ]] && ! ssh-add -l 2>/dev/null | grep -q "$HOME/.ssh/$_id"; then
      ssh-add "$HOME/.ssh/$_id" >/dev/null 2>&1
    fi
  done
  unset _id _ssh_env_cache
fi
