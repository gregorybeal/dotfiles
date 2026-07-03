# ~/.zsh/prompt.zsh
export VIRTUAL_ENV_DISABLE_PROMPT=1
FUNCNEST=100
command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"
