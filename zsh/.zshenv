# ~/.zshenv — stowed from ~/dotfiles/zsh. Points zsh at the real config in $ZDOTDIR.
#
# zsh reads exactly one .zshenv automatically, resolved via $ZDOTDIR-or-$HOME
# BEFORE that read happens (not after) — so it finds this file (from $HOME,
# since ZDOTDIR isn't set yet), but does NOT go back and read a second
# .zshenv once this one sets ZDOTDIR below. We have to relay to it
# ourselves, or $ZDOTDIR/.zshenv (XDG vars, EDITOR, PATH, etc.) never runs
# for ANY shell — interactive or not.
export XDG_CONFIG_HOME="$HOME/.config"
[[ -d "$XDG_CONFIG_HOME/zsh" ]] && export ZDOTDIR="$XDG_CONFIG_HOME/zsh"
[[ -f "$ZDOTDIR/.zshenv" ]] && source "$ZDOTDIR/.zshenv"
