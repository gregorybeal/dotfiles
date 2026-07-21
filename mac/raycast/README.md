# Register Lookup — Raycast extension

Raycast equivalent of the `mac/alfred` register/store workflows, with one
upgrade Alfred can't really do: a live preview pane (Raycast's built-in
`List.Item.Detail`) showing store number, city, state, regional, and IP as
you move through results — no Quick Look hack, no modifier-key conflicts.

This extension has **no register-lookup or Royal TSX logic of its own**. Both
commands shell out to the exact same scripts the Alfred workflow uses:

| Raycast command   | Calls (for results)     | Calls (to connect)       |
| ------------------ | ------------------------ | -------------------------- |
| Search Registers   | `../alfred/reg-filter.zsh`   | `../alfred/reg-connect.zsh`   |
| Search Stores      | `../alfred/store-filter.zsh` | `../alfred/store-connect.zsh` |

So filtering behavior, the SSH-config-is-the-inventory model, REG_DB
metadata, and the stored-Royal-TSX-object-first / ad-hoc-fallback connect
logic all stay identical across Alfred and Raycast by construction — fix a
bug or add a field in one place (`reg-json.py`/`store-json.py`/
`reglib.py`/`local-tools.zsh`) and both pick it up.

The two JSON generators also emit a `variables` object per item (city,
state, regional, ip, and for stores a full per-register host/ip list) —
Alfred ignores extra JSON keys, so this is invisible there; this extension
reads it directly instead of re-parsing the formatted subtitle string.

## Setup

This wasn't built or tested from this checkout (no Node/Raycast available
here) — do this on your Mac:

```sh
cd ~/dotfiles/mac/raycast
npm install
npm run dev     # opens Raycast in local-extension dev mode
```

If `npm install` complains about the `@raycast/api`/`@raycast/utils`
version pins in `package.json`, just bump them:

```sh
npm install @raycast/api@latest
```

Once `npm run dev` is running, "Search Registers" and "Search Stores" show
up in Raycast like any other command — no separate install step. Quit dev
mode (Ctrl+C) and the commands disappear until you run it again, unless you
`ray build` and install the extension properly (Raycast → Extensions →
"Add Extension" → point it at this folder, or `npx @raycast/api@latest
publish` if you want it in your own private "Store").

## Path assumption

Both commands assume this repo lives at `~/dotfiles` (same assumption the
Alfred Script Filter fields themselves make — see `../alfred/README.md`).
Override with `REG_ALFRED_DIR` if yours is elsewhere, e.g. in your shell
profile or Raycast's per-extension environment settings:

```sh
export REG_ALFRED_DIR="$HOME/somewhere-else/mac/alfred"
```

## Icon

`assets/icon.png` is a placeholder (generated, not designed) — swap it for
something real whenever you get to it; Raycast doesn't care about the
content, just that a 512×512 PNG exists at that path.

## Keyboard shortcuts

Same shape as the Alfred cmd/alt modifiers, translated to Raycast's
convention (default action needs no shortcut, everything else does):

- **Enter** — open (VNC)
- **⌘Enter** — open via SSH
- **⌥Enter** — open via SFTP
- **⇧Enter** — copy IP address (registers only, hidden when a register has no
  IP on record — mirrors both the shift modifier in Alfred and
  `mods.shift.valid` in `reg-json.py`)
- **⌘.** — copy hostname / store number
