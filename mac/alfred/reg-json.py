#!/usr/bin/env python3
"""Format registers as Alfred Script Filter JSON.

Reads the ssh-config host list (the inventory) on stdin, one per line, and a
metadata TSV — host<TAB>ip<TAB>store<TAB>city<TAB>state<TAB>regional — from the
file named in argv[1]. Knows nothing about the database schema; the caller has
already resolved it. Does the join, the target choice and the JSON escaping.

Target per register mirrors _reg_rtsx_target: the hostname when the system can
resolve it (so Royal TSX titles the tab with the name), else the IP.
  REG_RTSX_TARGET=hostname|ip forces one; REG_HOSTS_FILE overrides /etc/hosts.
  REG_RTSX_USER, if set, preselects a credential (user?@host).
"""
import json
import os
import sys


def load_meta(path):
    meta = {}
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                f = line.rstrip("\n").split("\t")
                f += [""] * (6 - len(f))
                host, ip, store, city, state, regional = f[:6]
                if host:
                    meta[host] = dict(ip=ip, store=store, city=city,
                                      state=state, regional=regional)
    except OSError:
        pass
    return meta


def hosts_in(path):
    """Alias names present in a hosts file (never the address in column 1)."""
    names = set()
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.split("#", 1)[0].split()
                names.update(line[1:])
    except OSError:
        pass
    return names


def subtitle(m):
    bits = []
    if m.get("store"):
        bits.append("store {}".format(m["store"]))
    loc = ", ".join(x for x in (m.get("city"), m.get("state")) if x)
    if loc:
        bits.append(loc)
    if m.get("regional"):
        bits.append(m["regional"])
    return " · ".join(bits)


def main():
    meta = load_meta(sys.argv[1]) if len(sys.argv) > 1 else {}
    inventory = [h.strip() for h in sys.stdin if h.strip()]

    mode = os.environ.get("REG_RTSX_TARGET", "").lower()
    hosts_file = os.environ.get("REG_HOSTS_FILE", "/etc/hosts")
    resolvable = hosts_in(hosts_file) if mode not in ("hostname", "ip") else set()
    user = os.environ.get("REG_RTSX_USER", "")
    cred = "{}?@".format(user) if user else ""

    items = []
    for host in inventory:
        m = meta.get(host, {})
        ip = m.get("ip", "")

        if mode == "hostname":
            target = host
        elif mode == "ip":
            target = ip or host
        else:
            target = host if host in resolvable else (ip or host)

        sub = subtitle(m)
        match = " ".join(x for x in (
            host, m.get("store"), m.get("city"), m.get("state"),
            m.get("regional"), ip) if x)

        # "<proto> <target>" — a plain space, so Alfred's "input as argv" splits
        # it into $1=proto $2=target. target has no spaces (hostname/IP, or
        # user?@host), so this is unambiguous.
        arg = lambda proto: "{} {}{}".format(proto, cred, target)
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
