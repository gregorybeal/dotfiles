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

1. **Script Filter** — set the keyword (e.g. `reg` and `store`), language
   **/bin/zsh**, the script:
   `"$HOME/dotfiles/mac/alfred/reg-filter.zsh"` (or `store-filter.zsh`) —
   leave **"Alfred filters results" UNCHECKED**, and once it's unchecked, set
   the now-enabled **"with input as"** dropdown to **`argv`** (NOT `{query}`).
2. **Run Script action** the Script Filter connects to — language **/bin/zsh**,
   "with input as **argv**", script:
   `"$HOME/dotfiles/mac/alfred/reg-connect.zsh" "$@"` (or `store-connect.zsh`).

Two independent settings, both matter, and it's easy to get one right and miss
the other:

- **"Alfred filters results" must stay unchecked.** Checked, Alfred emits the
  full list once and filters it live using its own fuzzy matcher — which has a
  real bug: query text that crosses a digit-to-letter boundary inside one word
  can score zero even though a shorter prefix matched fine a keystroke earlier
  (typing the full hostname `0112reg99` can show *no* results, even though
  `0112` alone matched every register at that store). Unchecked, Alfred
  re-invokes the script on every keystroke and `reg-json.py`/`store-json.py`
  filter themselves with a plain case-insensitive substring match per
  whitespace-split query term (`reglib.query_matches`) — so the full hostname
  always matches itself. Same reason Royal Apps' own official Alfred workflow
  for Royal TSX does its own manual filtering instead of trusting Alfred's.
- **"With input as" must be `argv`, not `{query}`.** This dropdown only
  becomes selectable once "Alfred filters results" is unchecked, and it's easy
  to leave on the wrong option. `{query}` mode does a literal text substitution
  of the string `{query}` inside the Script field itself — since these scripts
  are invoked by file path with no such token in the field, that mode never
  populates `$1`, so the live query never reaches the script and it always
  returns the *entire* unfiltered list no matter what you type. `argv` mode is
  what actually puts the live query in `$1`, which is what `reg-filter.zsh` /
  `store-filter.zsh` read.

Item args are `"<proto> <host>"` / `"<proto> <store>"` — a plain space that
Alfred's "input as argv" splits. Set `REG_RTSX_DEBUG=1` in `~/.zshrc.local` to
surface the osascript result in Alfred's workflow debugger when a handoff
unexpectedly opens ad hoc.
