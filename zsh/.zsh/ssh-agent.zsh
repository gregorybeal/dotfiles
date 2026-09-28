# =========================================================
# ssh-agent (persistent across sessions)
# macOS uses the 1Password agent directly (SSH_AUTH_SOCK set in .zshenv).
# WSL bridges to 1Password on Windows: socat serves a unix socket and hands
# each connection to npiperelay.exe, which talks to 1Password's named pipe.
# Needs socat (apt) + npiperelay.exe on the Windows PATH (winget install
# albertony.npiperelay), and 1Password → Settings → Developer → "Use the SSH
# agent" on Windows. Without those, and on plain Linux, fall back to a local
# ssh-agent — replicates the OMZ ssh-agent plugin: reuse a running agent via
# a per-host env file, start one if needed, load default keys.
# =========================================================

if [[ "$(uname -s)" != "Darwin" ]]; then
  if [[ -n $WSL_DISTRO_NAME ]] && (( $+commands[socat] && $+commands[npiperelay.exe] )); then
    export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"
    # ssh-add -l exits 2 only when it can't reach an agent at all (0 = keys,
    # 1 = agent up but empty), so 2 means the relay isn't running yet.
    ssh-add -l >/dev/null 2>&1
    if (( $? == 2 )); then
      mkdir -p -m 700 "${SSH_AUTH_SOCK:h}"
      rm -f "$SSH_AUTH_SOCK"
      # setsid detaches the relay from this shell so closing the tab (or the
      # tmux pane that started it) doesn't take it down.
      (setsid socat UNIX-LISTEN:"$SSH_AUTH_SOCK",fork \
        EXEC:"npiperelay.exe -ei -s //./pipe/openssh-ssh-agent",nofork \
        >/dev/null 2>&1 &)
    fi
  else
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
fi
