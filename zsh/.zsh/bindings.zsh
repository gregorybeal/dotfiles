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
