#!/usr/bin/env python3
"""Format registers as RoyalJSON for a Royal TSX Dynamic Folder.

Reads the ssh-config host list (the inventory) on stdin, one per line, and a
metadata TSV — host<TAB>ip<TAB>store<TAB>city<TAB>state<TAB>regional — from the
file named in argv[1] (the same feed as the Alfred filter; produced by
_reg_meta_full in ~/.zsh/local-tools.zsh). Emits a RoyalJSON document on stdout.

Each register becomes up to three real connection objects — VNC, SSH and
FileTransfer/SFTP — so the picker (frtsx / Alfred) can `connect` any of them by
name and get the *stored* connection's secure gateway and credential rather than
ad hoc defaults. The object names match _reg_rtsx_name exactly (VNC keeps the
bare hostname; ssh/sftp get "[SSH]"/"[SFTP]" suffixes) — that agreement is what
lets `connect` find them.

Credentials and the secure gateway are NOT written here: every object sets
CredentialsFromParent / SecureGatewayFromParent, so it inherits whatever the
dynamic folder (or a parent folder) is configured with. Set those once on the
folder in Royal TSX; re-import/refresh never clobbers them.

Environment (mirrors the frtsx/_reg_rtsx_target knobs):
  REG_RTSX_TARGET=hostname|ip   force the ComputerName (default: hostname when
                                the system resolves it, else the IP)
  REG_HOSTS_FILE=/path          override /etc/hosts for that resolution check
  REG_RTSX_PROTOS=vnc,ssh,sftp  which objects to emit per register (default all)
  REG_RTSX_GROUP=store|flat     group into per-store folders (default) or emit a
                                flat list of connections
"""
import json
import os
import re
import sys

# proto -> the RoyalJSON Type (and subtype) for that connection object.
PROTO_TYPE = {
    "vnc":  {"Type": "VNCConnection"},
    "ssh":  {"Type": "TerminalConnection", "TerminalConnectionType": "SSH"},
    "sftp": {"Type": "FileTransferConnection", "FileTransferConnectionType": "SFTP"},
}
STORE_KEY = re.compile(r"^(\d{4})")


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


def object_name(host, proto):
    """Must match _reg_rtsx_name in ~/.zsh/local-tools.zsh."""
    if proto == "ssh":
        return "{} [SSH]".format(host)
    if proto == "sftp":
        return "{} [SFTP]".format(host)
    return host


def connection(host, proto, target, desc):
    obj = dict(PROTO_TYPE[proto])           # Type (+ subtype)
    obj["Name"] = object_name(host, proto)
    obj["ComputerName"] = target
    obj["CredentialsFromParent"] = True
    obj["SecureGatewayFromParent"] = True
    if desc:
        obj["Description"] = desc
    return obj


def folder_label(key, m):
    loc = ", ".join(x for x in (m.get("city"), m.get("state")) if x)
    store = m.get("store") or key
    return "Store {} — {}".format(store, loc) if loc else "Store {}".format(store)


def main():
    meta = load_meta(sys.argv[1]) if len(sys.argv) > 1 else {}
    inventory = [h.strip() for h in sys.stdin if h.strip()]

    mode = os.environ.get("REG_RTSX_TARGET", "").lower()
    hosts_file = os.environ.get("REG_HOSTS_FILE", "/etc/hosts")
    resolvable = hosts_in(hosts_file) if mode not in ("hostname", "ip") else set()
    protos = [p for p in re.split(r"[,\s]+",
              os.environ.get("REG_RTSX_PROTOS", "vnc,ssh,sftp").lower().strip())
              if p in PROTO_TYPE]
    if not protos:
        protos = list(PROTO_TYPE)
    group = os.environ.get("REG_RTSX_GROUP", "store").lower() != "flat"

    def target_of(host, m):
        ip = m.get("ip", "")
        if mode == "hostname":
            return host
        if mode == "ip":
            return ip or host
        return host if host in resolvable else (ip or host)

    # Preserve inventory order; bucket by leading store number when grouping.
    folders = {}          # key -> {"label": str, "conns": [...]}
    flat = []
    for host in inventory:
        m = meta.get(host, {})
        target = target_of(host, m)
        desc = subtitle(m)
        conns = [connection(host, p, target, desc) for p in protos]

        if not group:
            flat.extend(conns)
            continue
        km = STORE_KEY.match(host)
        key = km.group(1) if km else "_misc"
        f = folders.get(key)
        if f is None:
            label = folder_label(key, m) if km else "Ungrouped"
            f = folders[key] = {"label": label, "conns": []}
        f["conns"].extend(conns)

    if group:
        objects = [
            {
                "Type": "Folder",
                "Name": f["label"],
                "CredentialsFromParent": True,
                "SecureGatewayFromParent": True,
                "Objects": f["conns"],
            }
            for f in folders.values()
        ]
    else:
        objects = flat

    json.dump({"Objects": objects}, sys.stdout, ensure_ascii=False, indent=2)


if __name__ == "__main__":
    main()
