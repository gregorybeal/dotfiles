#!/bin/zsh
# reg-royaljson.zsh — emit the register inventory as RoyalJSON for a Royal TSX
# Dynamic Folder.
#
# Point a Dynamic Folder's command at this script (Type: Script/Command, on
# macOS run with zsh). Royal TSX runs it, reads its stdout as RoyalJSON, and
# materialises every register as real VNC / SSH / SFTP connection objects. Set
# the folder's credential and secure gateway once — every generated object
# inherits them (CredentialsFromParent / SecureGatewayFromParent), so frtsx and
# Alfred can `connect` any register with its gateway and login already in place.
#
# It reuses the same schema discovery and helpers as the fzf tools and the Alfred
# filter (~/.zsh/local-tools.zsh), so the inventory never drifts between them.
emulate -L zsh
setopt pipefail

# Royal TSX runs this with a minimal environment. Put Homebrew ahead of the
# system so sqlite3 is found, then load the same machine-local config an
# interactive shell would (REG_DB, REG_RTSX_TARGET, REG_HOSTS_FILE, ...).
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
[[ -f $HOME/.zshrc.local ]] && source "$HOME/.zshrc.local" 2>/dev/null
source "$HOME/.zsh/local-tools.zsh" 2>/dev/null

# The ssh config is the inventory: it decides which registers exist; the database
# only decorates them. A register the database has never heard of still gets its
# connection objects, just without store metadata. An empty document is valid
# RoyalJSON, so a missing inventory yields an empty folder rather than an error.
hosts=$(_reg_hosts 2>/dev/null) || { print -r -- '{"Objects":[]}'; exit 0 }

print -r -- "$hosts" | python3 "${0:A:h}/reg-royaljson.py" <(_reg_meta_full)
