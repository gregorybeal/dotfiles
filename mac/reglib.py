"""reglib — shared helpers for the register formatters.

Used by mac/alfred/reg-json.py, mac/alfred/store-json.py and
mac/royaltsx/reg-royaljson.py, which each read the same two inputs:

  stdin    — the ssh-config host list (the inventory), one hostname per line
  argv[1]  — a metadata TSV: host<TAB>ip<TAB>store<TAB>city<TAB>state<TAB>regional
             (produced by _reg_meta_full in ~/.zsh/local-tools.zsh)

The formatters know nothing about the database schema; the caller has already
resolved it. This module owns the input parsing and the hostname-vs-IP target
choice, so those behave identically across Alfred and the RoyalJSON generator.

Stdlib only. The scripts add this file's directory to sys.path and
`import reglib` — no packaging, no install step.
"""
import os


def load_meta(path):
    """host -> dict(ip, store, city, state, regional) from the metadata TSV.

    Tolerates missing columns (padded to empty) and a missing/unreadable file
    (returns {}), so a register absent from the database still formats.
    """
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


def read_inventory(stream):
    """The stdin host list as a list, blank lines dropped, order preserved."""
    return [h.strip() for h in stream if h.strip()]


def subtitle(m):
    """'store N · City, ST · Regional' from whichever fields exist."""
    bits = []
    if m.get("store"):
        bits.append("store {}".format(m["store"]))
    loc = ", ".join(x for x in (m.get("city"), m.get("state")) if x)
    if loc:
        bits.append(loc)
    if m.get("regional"):
        bits.append(m["regional"])
    return " · ".join(bits)


def query_matches(query, *fields):
    """True if every whitespace-split term in `query` is a case-insensitive
    substring of `fields` joined together.

    This is what the Alfred filters use instead of Alfred's own built-in live
    filter ("Alfred filters results" + a "match" field). That filter has a real
    quirk: its fuzzy scoring can fail on query text that crosses a digit-to-
    letter boundary inside one unbroken word — searching the full hostname
    "0112reg99" can return zero results even though "0112" alone matches
    everything, because there is no space/case-change for it to anchor on.
    Royal Apps' own official Alfred workflow for Royal TSX does its own manual
    substring filtering for exactly this reason, rather than trust Alfred's
    matcher. Plain substring-per-term is deterministic: the full hostname
    always matches itself.

    Using this means the Script Filter must have "Alfred filters results"
    UNCHECKED — the script is invoked on every keystroke and returns only the
    items that already match, instead of Alfred filtering a static list.
    """
    query = (query or "").strip().lower()
    if not query:
        return True
    haystack = " ".join(str(f) for f in fields if f).lower()
    return all(term in haystack for term in query.split())


def make_target_of(environ=os.environ):
    """target_of(host, ip) — what to hand Royal TSX for a register.

    Mirrors _reg_rtsx_target: the hostname when the system can resolve it (so
    Royal TSX titles the tab with the name), else the IP.
      REG_RTSX_TARGET=hostname|ip forces one;
      REG_HOSTS_FILE overrides /etc/hosts for the resolution check.
    The hosts file is read once, here, not per register.
    """
    mode = environ.get("REG_RTSX_TARGET", "").lower()
    hosts_file = environ.get("REG_HOSTS_FILE", "/etc/hosts")
    resolvable = hosts_in(hosts_file) if mode not in ("hostname", "ip") else set()

    def target_of(host, ip):
        if mode == "hostname":
            return host
        if mode == "ip":
            return ip or host
        return host if host in resolvable else (ip or host)

    return target_of
