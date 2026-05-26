#!/usr/bin/env python3
"""
Refresh registers.csv from the POS SQLite dashboard.
Supports local file or remote (via SSH+scp from jump box).

Usage:
    refresh.py                       # local DB (default)
    refresh.py --source remote       # via jump box
    refresh.py --source local --db /alt/path.db
"""
import argparse
import csv
import os
import sqlite3
import subprocess
import sys
import tempfile
from pathlib import Path

CONFIG_DIR = Path.home() / ".config" / "reg-tool"
OUTPUT_CSV = CONFIG_DIR / "registers.csv"

# --- TWEAK THIS QUERY to match your actual schema ---
# Expected output columns (in order): store_id, register_id, ip, notes
QUERY = """
SELECT
    store_id,
    register_id,
    ip_address    AS ip,
    COALESCE(notes, type, '') AS notes
FROM registers
WHERE ip_address IS NOT NULL
  AND ip_address != ''
ORDER BY store_id, register_id;
"""


def load_config():
    cfg = {}
    config_file = CONFIG_DIR / "config"
    if not config_file.exists():
        print(f"Missing config: {config_file}", file=sys.stderr)
        sys.exit(1)
    for line in config_file.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" in line:
            k, v = line.split("=", 1)
            cfg[k.strip()] = os.path.expandvars(v.strip().strip('"').strip("'"))
    return cfg


def fetch_remote_db(cfg):
    """SCP the remote DB to a temp file and return its path."""
    host = cfg.get("REG_SQLITE_REMOTE_HOST")
    remote_path = cfg.get("REG_SQLITE_REMOTE_PATH")
    if not host or not remote_path:
        print("REG_SQLITE_REMOTE_HOST / REG_SQLITE_REMOTE_PATH not set", file=sys.stderr)
        sys.exit(1)

    tmp = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
    tmp.close()
    print(f"Fetching {host}:{remote_path} ...", file=sys.stderr)
    result = subprocess.run(
        ["scp", "-q", f"{host}:{remote_path}", tmp.name],
        capture_output=True, text=True,
    )
    if result.returncode != 0:
        print(f"scp failed: {result.stderr}", file=sys.stderr)
        os.unlink(tmp.name)
        sys.exit(1)
    return tmp.name


def query_db(db_path):
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    rows = conn.execute(QUERY).fetchall()
    conn.close()
    return rows


def write_csv(rows, out_path):
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["# store_id", "register_id", "ip", "notes"])
        for r in rows:
            w.writerow([r["store_id"], r["register_id"], r["ip"], r["notes"] or ""])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", choices=["local", "remote"], default="local")
    ap.add_argument("--db", help="Override DB path (local source only)")
    ap.add_argument("--out", default=str(OUTPUT_CSV))
    args = ap.parse_args()

    cfg = load_config()
    cleanup = None

    if args.source == "local":
        db_path = args.db or cfg.get("REG_SQLITE_LOCAL")
        if not db_path or not Path(db_path).exists():
            print(f"Local DB not found: {db_path}", file=sys.stderr)
            sys.exit(1)
    else:
        db_path = fetch_remote_db(cfg)
        cleanup = db_path

    try:
        rows = query_db(db_path)
        write_csv(rows, Path(args.out))
        print(f"Wrote {len(rows)} registers to {args.out}")
    finally:
        if cleanup:
            os.unlink(cleanup)


if __name__ == "__main__":
    main()
