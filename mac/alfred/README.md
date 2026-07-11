# Alfred → Royal TSX register workflows

Two Script Filter → action pairs, wired up in Alfred's own UI (these files are
the scripts they run — nothing here is stowed). Both reuse the register
inventory helpers in `~/.zsh/local-tools.zsh`, so they never drift from the fzf
tools (`frtsx`, `fssh`, …) or the RoyalJSON generator in `../royaltsx/`.

| Workflow | Script Filter | Action | Opens |
|----------|---------------|--------|-------|
| One register | `reg-filter.zsh` → `reg-json.py` | `reg-connect.zsh` → `_reg_rtsx_connect` | the picked register |
| A whole store | `store-filter.zsh` → `store-json.py` | `store-connect.zsh` → `_reg_rtsx_store` | every register at the picked store |

Both hand off to the register's **stored** Royal TSX connection object (secure
gateway + credential inherited from its folder), falling back to an ad hoc
connection when no object exists. See `../royaltsx/README.md`.

## Wiring one up in Alfred

For each pair, in the workflow editor:

1. **Script Filter** — set the keyword (e.g. `reg` and `store`), "Alfred filters
   results", language **/bin/zsh**, "with input as **{query}**", and the script:
   `"$HOME/dotfiles/mac/alfred/reg-filter.zsh"` (or `store-filter.zsh`).
2. **Run Script action** the Script Filter connects to — language **/bin/zsh**,
   "with input as **argv**", script:
   `"$HOME/dotfiles/mac/alfred/reg-connect.zsh" "$@"` (or `store-connect.zsh`).

Modifiers on the results: **⌘** = SSH, **⌥** = SFTP (default is VNC), matching
`frtsx`'s Enter / Ctrl-S / Ctrl-F.

Item args are `"<proto> <host>"` / `"<proto> <store>"` — a plain space that
Alfred's "input as argv" splits. Set `REG_RTSX_DEBUG=1` in `~/.zshrc.local` to
surface the osascript result in Alfred's workflow debugger when a handoff
unexpectedly opens ad hoc.
