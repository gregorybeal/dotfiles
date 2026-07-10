# Royal TSX register connections (design B)

Turns the register inventory into **real Royal TSX connection objects** — one
VNC, one SSH, one SFTP per register — via a [RoyalJSON][rjson] Dynamic Folder,
so `frtsx` and the Alfred workflow can `connect` any register and get its
configured secure gateway and credential instead of ad hoc defaults.

Why not templates / "Connect using Template"? That feature is **not exposed to
AppleScript** (the scripting dictionary has `connect` and `adhoc`, no template
verb — confirmed against `sdef "/Applications/Royal TSX.app"`), so it can only be
driven from Royal TSX's own UI. Real per-protocol objects keep the external
fzf/Alfred pickers able to open SSH and SFTP, which templates could not.

## Files

| File | Role |
|------|------|
| `reg-royaljson.zsh` | Dynamic Folder command. Loads `~/.zshrc.local` + `~/.zsh/local-tools.zsh`, then pipes the inventory to the formatter. Point Royal TSX at this. |
| `reg-royaljson.py`  | Formats the inventory as RoyalJSON. Emits VNC/SSH/SFTP objects grouped into per-store folders, each inheriting credentials + gateway from its parent. |

The inventory feed (`_reg_hosts` + `_reg_meta_full`) is shared with the fzf tools
and the Alfred filter in `~/.zsh/local-tools.zsh`, so nothing drifts.

## One-time setup in Royal TSX

1. **Add a Dynamic Folder** (New → Dynamic Folder).
2. Set its command to run this script with zsh, e.g.
   `/bin/zsh -c "$HOME/dotfiles/mac/royaltsx/reg-royaljson.zsh"`
   (Type: *Script*, or *Command* returning stdout — whichever your Royal TSX
   version calls it). It must emit the script's stdout unchanged.
3. On **that folder**, set the **Credentials** and the **Secure Gateway** the
   registers should use. Every generated connection has `CredentialsFromParent`
   / `SecureGatewayFromParent`, so it inherits them — the JSON never carries a
   secret. (The generated per-store subfolders also inherit, so the chain
   reaches this folder.)
4. Refresh the folder. The registers appear as VNC/SSH/SFTP objects.

`connect` matches objects **by name**, and the names are the contract:

| Protocol | Object name        | Source of truth |
|----------|--------------------|-----------------|
| VNC      | `0003reg01`        | `_reg_rtsx_name` (zsh) |
| SSH      | `0003reg01 [SSH]`  | and `object_name` (py) |
| SFTP     | `0003reg01 [SFTP]` | must stay identical |

If you change the suffixes, change them in **both** `reg-royaljson.py` and
`_reg_rtsx_name` in `~/.zsh/local-tools.zsh`, or every handoff silently degrades
to ad hoc.

## Environment knobs

Set these in `~/.zshrc.local` (read by the Dynamic Folder command, `frtsx`, and
Alfred alike):

| Variable | Effect |
|----------|--------|
| `REG_RTSX_TARGET=hostname\|ip` | Force the `ComputerName`. Default: hostname when the system resolves it, else the IP. **Set to `hostname`** if your secure gateway resolves register names (then the tab titles are names, not IPs). |
| `REG_HOSTS_FILE=/path` | Override `/etc/hosts` for that resolution check. |
| `REG_RTSX_PROTOS=vnc,ssh,sftp` | Which objects to emit per register (default all three). Drop to `vnc` for a lighter tree. |
| `REG_RTSX_GROUP=store\|flat` | Per-store folders (default) or one flat connection list. |

## Fallback

A register that is in the ssh inventory but not yet materialised in Royal TSX
still connects: `_reg_rtsx_connect` falls back to an ad hoc connection (the old
behaviour), which uses Royal TSX's ad hoc defaults rather than the stored
object's gateway/credential. Refresh the Dynamic Folder to pick up new
registers.

[rjson]: https://docs.royalapps.com/r2023/scripting/rjson/the-data-format.html
