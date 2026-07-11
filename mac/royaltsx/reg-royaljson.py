#!/usr/bin/env python3
"""Format registers as RoyalJSON for a Royal TSX Dynamic Folder.

Reads the inventory + metadata inputs described in reglib (stdin + argv[1])
and emits a RoyalJSON document on stdout.

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

Environment (REG_RTSX_TARGET / REG_HOSTS_FILE handled by reglib):
  REG_RTSX_PROTOS=vnc,ssh,sftp  which objects to emit per register (default all)
  REG_RTSX_GROUP=store|flat     group into per-store folders (default) or emit a
                                flat list of connections
"""
import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import reglib

# proto -> the RoyalJSON Type (and subtype) for that connection object.
PROTO_TYPE = {
    "vnc":  {"Type": "VNCConnection"},
    "ssh":  {"Type": "TerminalConnection", "TerminalConnectionType": "SSH"},
    "sftp": {"Type": "FileTransferConnection", "FileTransferConnectionType": "SFTP"},
}
STORE_KEY = re.compile(r"^(\d{4})")


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
    meta = reglib.load_meta(sys.argv[1]) if len(sys.argv) > 1 else {}
    inventory = reglib.read_inventory(sys.stdin)
    target_of = reglib.make_target_of()

    protos = [p for p in re.split(r"[,\s]+",
              os.environ.get("REG_RTSX_PROTOS", "vnc,ssh,sftp").lower().strip())
              if p in PROTO_TYPE]
    if not protos:
        protos = list(PROTO_TYPE)
    group = os.environ.get("REG_RTSX_GROUP", "store").lower() != "flat"

    # Preserve inventory order; bucket by leading store number when grouping.
    folders = {}          # key -> {"label": str, "conns": [...]}
    flat = []
    for host in inventory:
        m = meta.get(host, {})
        target = target_of(host, m.get("ip", ""))
        desc = reglib.subtitle(m)
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
