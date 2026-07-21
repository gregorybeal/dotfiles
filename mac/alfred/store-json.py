#!/usr/bin/env python3
"""Format stores (not individual registers) as Alfred Script Filter JSON.

Reads the inventory + metadata inputs described in reglib (stdin + argv[1]),
groups the registers by store and emits one item per store. Picking a store
opens every register at it in Royal TSX (store-connect.zsh → _reg_rtsx_store).

Each item's arg is "<proto> <store>" (a plain space so Alfred's "input as argv"
splits it into $1=proto $2=store). The store is the hostname prefix with the
regNN suffix stripped (e.g. 0003), which is what the awk in _reg_rtsx_store
matches. cmd/alt swap the protocol, mirroring the per-register filter.

The live Alfred query arrives in argv[2] (empty/absent = show every store) and
is matched with reglib.query_matches, not Alfred's own live filter — see that
docstring for why. The Script Filter must have "Alfred filters results"
UNCHECKED so it's invoked on every keystroke with the current query.

Each item also carries a "variables" object (Alfred's per-item workflow
variables — harmless/unused here) with the raw city/state/regional fields and
the full per-register host/ip list broken out. Alfred ignores it; it exists so
other consumers of this same JSON (e.g. the Raycast extension in ../raycast)
don't have to re-parse the formatted subtitle string.
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
    query = sys.argv[2] if len(sys.argv) > 2 else ""
    inventory = reglib.read_inventory(sys.stdin)

    # Group registers by store (hostname prefix), preserving first-seen order.
    order = []
    stores = {}       # key -> {"count": int, "meta": {...}, "registers": [(host, ip), ...]}
    for host in inventory:
        key = STRIP_REG.sub("", host)
        s = stores.get(key)
        if s is None:
            order.append(key)
            s = stores[key] = {"count": 0, "meta": meta.get(host, {}), "registers": []}
        s["count"] += 1
        if not s["meta"]:                       # fill metadata from any register
            s["meta"] = meta.get(host, {})
        s["registers"].append((host, meta.get(host, {}).get("ip", "")))

    items = []
    for key in order:
        s = stores[key]
        m = s["meta"]
        num = m.get("store") or key.lstrip("0") or key
        if not reglib.query_matches(query, key, num, m.get("city"),
                                     m.get("state"), m.get("regional")):
            continue
        sub = store_subtitle(s["count"], m)
        arg = lambda proto: "{} {}".format(proto, key)
        plural = "{} register{}".format(s["count"], "" if s["count"] == 1 else "s")
        items.append({
            "uid": key,
            "title": "Store {}".format(num),
            "subtitle": sub,
            "arg": arg("vnc"),
            "mods": {
                "cmd": {"subtitle": "SSH — {}".format(plural), "arg": arg("ssh")},
                "alt": {"subtitle": "SFTP — {}".format(plural), "arg": arg("sftp")},
            },
            "text": {"copy": key},
            "variables": {
                "store": num,
                "city": m.get("city", ""),
                "state": m.get("state", ""),
                "regional": m.get("regional", ""),
                "registers": json.dumps(
                    [{"host": h, "ip": r_ip} for h, r_ip in s["registers"]]
                ),
            },
        })

    if not items:
        if inventory and query.strip():
            items = [{"title": "No matches", "subtitle":
                      'no store matches "{}"'.format(query.strip()),
                      "valid": False}]
        else:
            items = [{"title": "No stores", "subtitle":
                      "check REG_DB and the ssh config", "valid": False}]

    json.dump({"items": items}, sys.stdout, ensure_ascii=False)


if __name__ == "__main__":
    main()
