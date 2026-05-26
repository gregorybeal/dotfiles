#!/usr/bin/env bash
# reg-tool — register fzf picker + SSH tunnels + tmux integration
# Sourced from ~/.zshrc or ~/.bashrc

REG_TOOL_DIR="$HOME/.config/reg-tool"
REG_INVENTORY="$REG_TOOL_DIR/registers.csv"

[ -f "$REG_TOOL_DIR/config" ] && source "$REG_TOOL_DIR/config"

REG_JUMPBOX="${REG_JUMPBOX:-jumpbox}"
REG_USER="${REG_USER:-posuser}"
REG_LOG_PATH="${REG_LOG_PATH:-/var/log/pos/application.log}"

# ---------- inventory ----------

_reg_list() {
    [ -f "$REG_INVENTORY" ] || { echo "No inventory at $REG_INVENTORY — run reg-refresh" >&2; return 1; }
    grep -vE '^\s*(#|$)' "$REG_INVENTORY" | \
        awk -F',' '{ printf "%-8s reg-%-3s  %-16s  %s\n", $1, $2, $3, $4 }'
}

_reg_preview_cmd() {
    cat <<'EOF'
ip=$(echo {} | awk '{print $3}')
store=$(echo {} | awk '{print $1}')
echo "Store: $store"
echo "IP:    $ip"
echo ""
echo "--- ping ---"
ping -c 1 -W 1 "$ip" 2>&1 | tail -2
EOF
}

_reg_pick() {
    local sel
    sel=$(_reg_list | fzf \
        --prompt="Register> " \
        --header="store    reg     ip                notes" \
        --height=60% --reverse --border \
        --preview="$(_reg_preview_cmd)" \
        --preview-window=right:40%:wrap) || return 1
    echo "$sel" | awk '{print $3}'
}

_reg_pick_multi() {
    _reg_list | fzf \
        --multi \
        --prompt="Registers (Tab to select)> " \
        --header="store    reg     ip                notes" \
        --height=60% --reverse --border | awk '{print $3}'
}

_reg_action() {
    printf "ssh\nvnc\nrdp\nweb\nlog-tail\nlog-grep\nstatus\nssh+log (tmux split)\nclose-tunnels\n" | \
        fzf --prompt="Action> " --height=40% --reverse --border
}

# ---------- tunnels ----------

_reg_port_in_use() {
    if command -v lsof >/dev/null 2>&1; then
        lsof -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1
    else
        ss -ltn 2>/dev/null | awk '{print $4}' | grep -q ":$1$"
    fi
}

_reg_tunnel() {
    local lport="$1" ip="$2" rport="$3" label="$4"
    if _reg_port_in_use "$lport"; then
        echo "Port $lport already in use — assuming tunnel exists"
        return 0
    fi
    ssh -fN -L "$lport:$ip:$rport" "$REG_JUMPBOX" && \
        echo "Tunnel: localhost:$lport -> $ip:$rport ($label)"
}

# ---------- main entrypoints ----------

reg() {
    local ip action
    ip=$(_reg_pick) || return
    action=$(_reg_action) || return

    case "$action" in
        ssh)
            ssh -J "$REG_JUMPBOX" "$REG_USER@$ip"
            ;;
        vnc)
            _reg_tunnel 5901 "$ip" 5900 "VNC"
            echo "-> Connect VNC client to localhost:5901"
            ;;
        rdp)
            _reg_tunnel 13389 "$ip" 3389 "RDP"
            echo "-> RDP to localhost:13389"
            ;;
        web)
            local port lport
            printf "Remote web port [8080]: "
            read -r port
            port="${port:-8080}"
            lport="1${port}"
            _reg_tunnel "$lport" "$ip" "$port" "Web"
            echo "-> Open http://localhost:$lport"
            ;;
        log-tail)
            ssh -J "$REG_JUMPBOX" "$REG_USER@$ip" "tail -f $REG_LOG_PATH"
            ;;
        log-grep)
            local pattern
            printf "grep pattern: "
            read -r pattern
            ssh -J "$REG_JUMPBOX" "$REG_USER@$ip" "grep -i '$pattern' $REG_LOG_PATH | tail -100"
            ;;
        status)
            ssh -J "$REG_JUMPBOX" "$REG_USER@$ip" \
                "echo '=== uptime ==='; uptime; \
                 echo; echo '=== disk ==='; df -h /; \
                 echo; echo '=== flooid procs ==='; ps -ef | grep -i flooid | grep -v grep"
            ;;
        "ssh+log (tmux split)")
            reg-tmux-pair "$ip"
            ;;
        close-tunnels)
            pkill -f "ssh -fN -L.*$ip" && echo "Tunnels to $ip closed"
            ;;
    esac
}

reg-multi() {
    local ips cmd
    ips=$(_reg_pick_multi)
    [ -z "$ips" ] && return

    printf "Command to run on all selected: "
    read -r cmd

    while read -r ip; do
        echo ""
        echo "=== $ip ==="
        ssh -J "$REG_JUMPBOX" "$REG_USER@$ip" "$cmd"
    done <<< "$ips"
}

reg-store() {
    local store="$1"
    if [ -z "$store" ]; then
        echo "Usage: reg-store <store_id>"
        return 1
    fi
    local ip
    ip=$(_reg_list | grep "^$store " | fzf \
        --prompt="Store $store> " \
        --height=40% --reverse --border | awk '{print $3}')
    [ -z "$ip" ] && return
    ssh -J "$REG_JUMPBOX" "$REG_USER@$ip"
}

# ---------- tmux integration ----------

reg-tmux-store() {
    local store="$1"
    if [ -z "$store" ]; then
        echo "Usage: reg-tmux-store <store_id>"
        return 1
    fi

    local ips
    ips=$(_reg_list | grep "^$store " | awk '{print $3}')
    if [ -z "$ips" ]; then
        echo "No registers found for store $store"
        return 1
    fi

    local session="store-$store"
    if tmux has-session -t "$session" 2>/dev/null; then
        tmux attach -t "$session"
        return
    fi

    local first=1
    while read -r ip; do
        if [ $first -eq 1 ]; then
            tmux new-session -d -s "$session" -n "reg-$store" \
                "ssh -J $REG_JUMPBOX $REG_USER@$ip"
            first=0
        else
            tmux split-window -t "$session" \
                "ssh -J $REG_JUMPBOX $REG_USER@$ip"
            tmux select-layout -t "$session" tiled
        fi
    done <<< "$ips"

    tmux attach -t "$session"
}

reg-tmux-pair() {
    local ip="$1"
    [ -z "$ip" ] && { echo "Usage: reg-tmux-pair <ip>"; return 1; }

    local session="reg-${ip//./-}"
    if tmux has-session -t "$session" 2>/dev/null; then
        tmux attach -t "$session"
        return
    fi

    tmux new-session -d -s "$session" \
        "ssh -J $REG_JUMPBOX $REG_USER@$ip"
    tmux split-window -h -t "$session" \
        "ssh -J $REG_JUMPBOX $REG_USER@$ip 'tail -f $REG_LOG_PATH'"
    tmux attach -t "$session"
}

# ---------- inventory + tunnel management ----------

reg-refresh() {
    local source="${1:-local}"
    python3 "$REG_TOOL_DIR/refresh.py" --source "$source"
}

reg-tunnels() {
    echo "Active tunnels through $REG_JUMPBOX:"
    pgrep -af "ssh -fN -L.*$REG_JUMPBOX" 2>/dev/null | \
        grep -oE '\-L [^ ]+' || echo "  (none)"
}

reg-tunnels-kill() {
    pkill -f "ssh -fN -L.*$REG_JUMPBOX" && echo "All tunnels closed" || echo "No tunnels to close"
}
