# Royal TS (Windows) register connections, driven from WSL

The Windows counterpart of [`mac/royaltsx/`](../../mac/royaltsx/README.md): the
same RoyalJSON Dynamic Folder (one VNC, one SSH, one SFTP object per
register, inheriting credentials + secure gateway from the folder), and the
same `frtsx` / `frtsx-store` / Ctrl-P pickers in zsh — they just talk to Royal
TS for Windows instead of Royal TSX.

| | macOS | WSL |
|---|---|---|
| Generator | `mac/royaltsx/reg-royaljson.zsh` | the same script, run in WSL by `reg-royaljson.ps1` |
| Connect a stored object | AppleScript `connect` | `rtscli.exe action connect -n=<name>` |
| Ad hoc fallback | AppleScript `adhoc` / `open rtsx://…` | `explorer.exe "rtsx://<proto>%3a%2f%2f<host>?using=adhoc"` |
| Hostname-vs-IP check | `/etc/hosts` | Windows `C:\Windows\System32\drivers\etc\hosts` |

## One-time setup in Royal TS

1. **Add a Dynamic Folder** (Add → Dynamic Folder) in the document you keep
   open.
2. On its **Dynamic Folder Script** page set **Script Interpreter: PowerShell**
   and paste in [`reg-royaljson.ps1`](reg-royaljson.ps1).
3. On **that folder**, set the **Credentials** and the **Secure Gateway** the
   registers should use. Every generated object has `CredentialsFromParent` /
   `SecureGatewayFromParent`, so nothing secret goes through the script.
4. **Reload** the folder. The registers appear as VNC / SSH / SFTP objects.

The WSL side needs the register inventory set up exactly as on the Mac
(`~/.ssh/conf.d/registers`, `REG_DB` in `~/.zshrc.local`, `sqlite3`) — `make
doctor`'s *registers* section checks it.

## Using it from WSL

`frtsx` (or Ctrl-P) picks registers and hands them to Royal TS — Enter = VNC,
Ctrl-S = SSH, Ctrl-F = SFTP, Tab multi-selects. `frtsx-store` opens a whole
store. The document holding the Dynamic Folder must be **open** in Royal TS
(and the folder reloaded) for `connect` to find the objects; otherwise every
handoff falls back to ad hoc.

`rtscli.exe` is found automatically in `C:\Program Files\Royal TS V<n>\`
(newest version wins). Set `REG_RTSCLI=/mnt/c/.../rtscli.exe` in
`~/.zshrc.local` for any other install location.

## Environment knobs

Everything in the [Mac README](../../mac/royaltsx/README.md#environment-knobs)
applies (`REG_RTSX_TARGET`, `REG_RTSX_PROTOS`, `REG_RTSX_GROUP`, …), plus:

| Variable | Effect |
|----------|--------|
| `REG_RTSCLI=/path/rtscli.exe` | Use this rtscli instead of the auto-detected one. |
| `REG_HOSTS_FILE` | Defaults to the **Windows** hosts file on WSL, since that's what Royal TS resolves through. |
| `REG_RTSX_DEBUG=1` | Print rtscli's exit code and output for each connect — use it when a handoff unexpectedly goes ad hoc. |

## Not yet verified on a real Royal TS

This was built from Royal's docs, not against a running Royal TS:

- **Not-found detection.** rtscli's exit codes aren't documented, so a handoff
  counts as "not found" on a non-zero exit *or* output containing "not found" /
  "no connection" / "could not find". If a missing object ever silently does
  nothing instead of going ad hoc, run with `REG_RTSX_DEBUG=1` and adjust the
  pattern in `_reg_rtsx_connect` (`zsh/.zsh/reg-rtsx.zsh`).
- **SFTP ad hoc** uses the `sftp` protocol identifier, which Royal's published
  Windows list doesn't include (it does work on Royal TSX). Stored `[SFTP]`
  objects are unaffected.
- **`REG_RTSX_USER`** becomes `user@host` in the ad hoc URI, which Royal TS
  reads as *the name of a stored credential*, not a login name.
