#!/usr/bin/env python3
"""Format registers as Alfred Script Filter JSON.

Reads the inventory + metadata inputs described in reglib (stdin + argv[1]).
Each item's arg is "<proto> <host>" (a plain space so Alfred's "input as argv"
splits it into $1=proto $2=host). reg-connect.zsh turns that into a connection:
it opens the stored Royal TSX object for that host+proto, falling back to ad
hoc. The register hostname is the object-name key, so this file passes the bare
host, not a resolved target — reg-connect owns hostname/IP resolution (shared
with frtsx via _reg_rtsx_connect). The resolved target is still shown in the
subtitle/copy text, via reglib's REG_RTSX_TARGET/REG_HOSTS_FILE handling.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import reglib


def main():
    meta = reglib.load_meta(sys.argv[1]) if len(sys.argv) > 1 else {}
    inventory = reglib.read_inventory(sys.stdin)
    target_of = reglib.make_target_of()

    items = []
    for host in inventory:
        m = meta.get(host, {})
        ip = m.get("ip", "")
        target = target_of(host, ip)

        sub = reglib.subtitle(m)
        match = " ".join(x for x in (
            host, m.get("store"), m.get("city"), m.get("state"),
            m.get("regional"), ip) if x)

        # "<proto> <host>" — a plain space, so Alfred's "input as argv" splits
        # it into $1=proto $2=host. A register hostname has no spaces, so this is
        # unambiguous; reg-connect.zsh resolves the object name and the ad hoc
        # target from the host.
        arg = lambda proto: "{} {}".format(proto, host)
        items.append({
            "uid": host,
            "title": host,
            "subtitle": sub or "(not in inventory database)",
            "arg": arg("vnc"),
            "match": match,
            "mods": {
                "cmd": {"subtitle": "SSH — {}".format(target), "arg": arg("ssh")},
                "alt": {"subtitle": "SFTP — {}".format(target), "arg": arg("sftp")},
            },
            "text": {"copy": target, "largetype": "{}\n{}".format(host, sub)},
        })

    if not items:
        items = [{"title": "No registers", "subtitle":
                  "check REG_DB and the ssh config", "valid": False}]

    json.dump({"items": items}, sys.stdout, ensure_ascii=False)


if __name__ == "__main__":
    main()
