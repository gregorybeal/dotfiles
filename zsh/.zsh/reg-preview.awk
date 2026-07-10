# reg-preview.awk — format `sqlite3 -line` output for the fzf preview pane.
#
#   sqlite3 -readonly -line db "SELECT ..." | awk -v title=register -f reg-preview.awk
#
# Reads "key = value" lines, aligns them, and colours the values. Knows nothing
# about the schema: it never names a column. It strips one caller-supplied key
# prefix (-v strip=register_) so the pane stays readable when the database
# changes shape. The prefix is per-section on purpose: stripping "store_" inside
# the register block would turn store_number into a bare "number".
#
# Exits 1 on empty input so the caller can print its own fallback.
# Set -v nocolor=1 to disable ANSI (for tests, or a dumb terminal).

BEGIN {
    if (nocolor) { HDR = ""; DIM = ""; IP = ""; OK = ""; NO = ""; OFF = "" }
    else {
        HDR = "\033[1;36m"      # bold cyan
        DIM = "\033[2m"         # dim, for keys
        IP  = "\033[36m"        # cyan, for addresses
        OK  = "\033[32m"        # green
        NO  = "\033[31m"        # red
        OFF = "\033[0m"
    }
}

{
    p = index($0, " = ")
    if (p == 0) next

    k = substr($0, 1, p - 1)
    gsub(/^[ \t]+|[ \t]+$/, "", k)
    v = substr($0, p + 3)

    n++
    val[n] = v

    short = k
    if (strip != "" && index(short, strip) == 1)
        short = substr(short, length(strip) + 1)
    key[n] = short
    if (length(short) > w) w = length(short)
}

END {
    if (n == 0) exit 1

    printf "%s%s%s\n", HDR, title, OFF

    # Build the padding format once: %*s is not portable across every awk.
    fmt = "  " DIM "%" w "s" OFF "  %s\n"

    for (i = 1; i <= n; i++) {
        v = val[i]
        # 0 is dim, not red: dual_printer=0 means "no", not "broken".
        # N is red: store_valid=N really is a problem.
        if (v == "")                                   out = DIM "—" OFF
        else if (v ~ /^([0-9]{1,3}\.){3}[0-9]{1,3}$/)  out = IP v OFF
        else if (v == "Y" || v == "1")                 out = OK v OFF
        else if (v == "N")                             out = NO v OFF
        else if (v == "0")                             out = DIM v OFF
        else                                           out = v
        printf fmt, key[i], out
    }
}
