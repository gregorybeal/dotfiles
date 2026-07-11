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
