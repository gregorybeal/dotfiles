#!/usr/bin/env python3
"""Format stores (not individual registers) as Alfred Script Filter JSON.

Reads the inventory + metadata inputs described in reglib (stdin + argv[1]),
groups the registers by store and emits one item per store. Picking a store
opens every register at it in Royal TSX (store-connect.zsh → _reg_rtsx_store).

Each item's arg is "<proto> <store>" (a plain space so Alfred's "input as argv"
splits it into $1=proto $2=store). The store is the hostname prefix with the
regNN suffix stripped (e.g. 0003), which is what the awk in _reg_rtsx_store
matches. cmd/alt swap the protocol, mirroring the per-register filter.
"""
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import reglib

STRIP_REG = re.compile(r"reg\d+$")


def store_subtitle(count, m):
    bits = ["{} register{}".format(count, "" if count == 1 else "s")]
    loc = ", ".join(x for x in (m.get("city"), m.get("state")) if x)
    if loc:
        bits.append(loc)
    if m.get("regional"):
        bits.append(m["regional"])
    return " · ".join(bits)


def main():
    meta = reglib.load_meta(sys.argv[1]) if len(sys.argv) > 1 else {}
    inventory = reglib.read_inventory(sys.stdin)

    # Group registers by store (hostname prefix), preserving first-seen order.
    order = []
    stores = {}       # key -> {"count": int, "meta": {...}}
    for host in inventory:
        key = STRIP_REG.sub("", host)
        s = stores.get(key)
        if s is None:
            order.append(key)
            s = stores[key] = {"count": 0, "meta": meta.get(host, {})}
        s["count"] += 1
        if not s["meta"]:                       # fill metadata from any register
            s["meta"] = meta.get(host, {})

    items = []
    for key in order:
        s = stores[key]
        m = s["meta"]
        num = m.get("store") or key.lstrip("0") or key
        sub = store_subtitle(s["count"], m)
        match = " ".join(x for x in (
            key, num, m.get("city"), m.get("state"), m.get("regional")) if x)
        arg = lambda proto: "{} {}".format(proto, key)
        plural = "{} register{}".format(s["count"], "" if s["count"] == 1 else "s")
        items.append({
            "uid": key,
            "title": "Store {}".format(num),
            "subtitle": sub,
            "arg": arg("vnc"),
            "match": match,
            "mods": {
                "cmd": {"subtitle": "SSH — {}".format(plural), "arg": arg("ssh")},
                "alt": {"subtitle": "SFTP — {}".format(plural), "arg": arg("sftp")},
            },
            "text": {"copy": key},
        })

    if not items:
        items = [{"title": "No stores", "subtitle":
                  "check REG_DB and the ssh config", "valid": False}]

    json.dump({"items": items}, sys.stdout, ensure_ascii=False)


if __name__ == "__main__":
    main()
