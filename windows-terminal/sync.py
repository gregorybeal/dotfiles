#!/usr/bin/env python3
"""Merge windows-terminal/settings.json into Windows Terminal's live settings.

Run from WSL: `make wt` (or ./windows-terminal/sync.py [--dry-run]).

Why merge instead of copy/symlink: WT's settings.json also holds per-machine
state — generated profile GUIDs, profiles for whatever shells that PC has —
and symlinks from /mnt/c into the WSL filesystem aren't reliable. So the repo
file carries only what we manage, and this script overlays it:

  * top-level keys           replaced
  * profiles.defaults        deep-merged
  * schemes, themes          upserted by "name"
  * keybindings              upserted by "keys"
  * x-wslProfile             (repo-only key) applied to this distro's profile,
                             which also becomes defaultProfile; {distro} in
                             string values expands to $WSL_DISTRO_NAME. Keys
                             that profiles.defaults manages are removed from
                             that profile so the defaults actually apply.

The live file is backed up next to itself before being rewritten. WT watches
the file and reloads on save. Override the target with $WT_SETTINGS.
"""
import datetime
import difflib
import json
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
MANAGED = os.path.join(HERE, "settings.json")
FONT_GLOB = re.compile(r"firacode.*nerd", re.I)


def die(msg):
    sys.exit(f"wt-sync: {msg}")


def win_env(var):
    """Read a Windows env var via cmd.exe (run from C: — cmd.exe warns on a \\\\wsl$ cwd)."""
    try:
        out = subprocess.run(["cmd.exe", "/c", f"echo %{var}%"], cwd="/mnt/c",
                             capture_output=True, text=True, check=True).stdout.strip()
        return subprocess.run(["wslpath", "-u", out], capture_output=True,
                              text=True, check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return None


def find_settings(localappdata):
    if os.environ.get("WT_SETTINGS"):
        return os.environ["WT_SETTINGS"]
    candidates = [
        "Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json",
        "Packages/Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe/LocalState/settings.json",
        "Microsoft/Windows Terminal/settings.json",  # unpackaged (scoop, portable)
    ]
    for rel in candidates:
        path = os.path.join(localappdata, rel)
        if os.path.exists(path):
            return path
    die("no Windows Terminal settings.json found — launch WT once, or set WT_SETTINGS")


def load_jsonc(text):
    """json.loads that tolerates // and /* */ comments and trailing commas."""
    out, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if c == '"':
            j = i + 1
            while j < n and text[j] != '"':
                j += 2 if text[j] == "\\" else 1
            out.append(text[i:j + 1])
            i = j + 1
        elif text.startswith("//", i):
            i = text.find("\n", i)
            i = n if i < 0 else i
        elif text.startswith("/*", i):
            i = text.find("*/", i + 2) + 2
        else:
            out.append(c)
            i += 1
    return json.loads(re.sub(r",(\s*[}\]])", r"\1", "".join(out)))


def upsert(existing, managed, key):
    """Replace items in `existing` whose `key` matches a managed item; append the rest."""
    managed_keys = {json.dumps(m.get(key)) for m in managed}
    kept = [e for e in existing if json.dumps(e.get(key)) not in managed_keys]
    return kept + managed


def deep_merge(base, over):
    for k, v in over.items():
        if isinstance(v, dict) and isinstance(base.get(k), dict):
            deep_merge(base[k], v)
        else:
            base[k] = v
    return base


def expand(obj, distro):
    if isinstance(obj, str):
        return obj.replace("{distro}", distro)
    if isinstance(obj, dict):
        return {k: expand(v, distro) for k, v in obj.items()}
    return obj


def find_wsl_profile(profiles, distro):
    # Store-installed distros get a CanonicalGroupLimited.* source and a
    # versioned name ("Ubuntu 24.04.1 LTS"); `wsl --install` ones get
    # Windows.Terminal.Wsl and the bare distro name. Try exact, then fuzzy.
    wslish = [p for p in profiles if p.get("source", "").startswith(
        ("Windows.Terminal.Wsl", "CanonicalGroupLimited"))]
    for p in wslish:
        if p.get("name") == distro:
            return p
    squash = lambda s: re.sub(r"[^a-z0-9]", "", s.lower())
    fuzzy = [p for p in wslish if squash(distro) in squash(p.get("name", ""))]
    if len(fuzzy) == 1:
        return fuzzy[0]
    return wslish[0] if len(wslish) == 1 else None


def check_font(localappdata):
    dirs = ["/mnt/c/Windows/Fonts", os.path.join(localappdata, "Microsoft/Windows/Fonts")]
    for d in dirs:
        try:
            if any(FONT_GLOB.search(f) for f in os.listdir(d)):
                return
        except OSError:
            pass
    print("wt-sync: ⚠ FiraCode Nerd Font isn't installed on Windows — WT will fall back\n"
          "         to Cascadia and prompt icons will be tofu. Get it from\n"
          "         https://www.nerdfonts.com/font-downloads (right-click → Install for all users).")


def main():
    dry = "--dry-run" in sys.argv[1:]
    distro = os.environ.get("WSL_DISTRO_NAME") or die("not running under WSL")

    localappdata = win_env("LOCALAPPDATA")
    if not (localappdata or os.environ.get("WT_SETTINGS")):
        die("couldn't resolve %LOCALAPPDATA% via cmd.exe — set WT_SETTINGS")
    target = find_settings(localappdata)

    with open(target, encoding="utf-8-sig") as f:
        before = f.read()
    live = load_jsonc(before)
    with open(MANAGED, encoding="utf-8") as f:
        managed = json.load(f)

    wsl_overlay = expand(managed.pop("x-wslProfile", {}), distro)
    m_profiles = managed.pop("profiles", {})

    for key in ("schemes", "themes"):
        live[key] = upsert(live.get(key, []), managed.pop(key, []), "name")
    live["keybindings"] = upsert(live.get("keybindings", []), managed.pop("keybindings", []), "keys")
    live.update(managed)

    profiles = live.setdefault("profiles", {})
    if isinstance(profiles, list):  # legacy shape: bare list of profiles
        profiles = live["profiles"] = {"list": profiles}
    deep_merge(profiles.setdefault("defaults", {}), m_profiles.get("defaults", {}))

    wsl = find_wsl_profile(profiles.get("list", []), distro)
    if wsl:
        # Per-profile keys beat profiles.defaults, so an old font/colorScheme
        # set on this profile would hide the managed ones — drop them.
        for k in m_profiles.get("defaults", {}):
            wsl.pop(k, None)
        wsl.update(wsl_overlay)
        live["defaultProfile"] = wsl["guid"]
    else:
        print(f"wt-sync: ⚠ no WT profile found for distro '{distro}' — defaultProfile left as-is")

    after = json.dumps(live, indent=4, ensure_ascii=False) + "\n"
    if after == before:
        print("wt-sync: already up to date")
    elif dry:
        sys.stdout.writelines(difflib.unified_diff(
            before.splitlines(True), after.splitlines(True), target, "merged"))
    else:
        stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
        shutil.copy2(target, f"{target}.bak-{stamp}")
        with open(target, "w", encoding="utf-8") as f:
            f.write(after)
        print(f"wt-sync: updated {target}\n         (backup: {os.path.basename(target)}.bak-{stamp})")

    if localappdata:
        check_font(localappdata)


if __name__ == "__main__":
    main()
