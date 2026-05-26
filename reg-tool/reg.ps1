# reg-tool — PowerShell version
# Sourced from $PROFILE

$script:RegToolDir   = "$env:USERPROFILE\.config\reg-tool"
$script:RegInventory = "$script:RegToolDir\registers.csv"

# Load config
$configFile = "$script:RegToolDir\config"
if (Test-Path $configFile) {
    Get-Content $configFile | ForEach-Object {
        if ($_ -match '^\s*([A-Z_]+)\s*=\s*"?([^"]*)"?\s*$') {
            Set-Variable -Name $matches[1] -Value $matches[2] -Scope Script
        }
    }
}
if (-not $script:REG_JUMPBOX)  { $script:REG_JUMPBOX  = "jumpbox" }
if (-not $script:REG_USER)     { $script:REG_USER     = "posuser" }
if (-not $script:REG_LOG_PATH) { $script:REG_LOG_PATH = "/var/log/pos/application.log" }

# ---------- inventory ----------

function _Reg-List {
    if (-not (Test-Path $script:RegInventory)) {
        Write-Host "No inventory at $script:RegInventory — run reg-refresh" -ForegroundColor Yellow
        return
    }
    Get-Content $script:RegInventory |
        Where-Object { $_ -notmatch '^\s*(#|$)' } |
        ForEach-Object {
            $parts = $_ -split ','
            "{0,-8} reg-{1,-3} {2,-16} {3}" -f $parts[0], $parts[1], $parts[2], $parts[3]
        }
}

function _Reg-Pick {
    $sel = _Reg-List | fzf --prompt="Register> " `
        --header="store    reg     ip                notes" `
        --height=60% --reverse --border
    if (-not $sel) { return $null }
    ($sel -split '\s+')[2]
}

function _Reg-Action {
    @("ssh", "vnc", "rdp", "web", "log-tail", "log-grep", "status", "ssh+log (tmux split)", "close-tunnels") |
        fzf --prompt="Action> " --height=40% --reverse --border
}

# ---------- tunnels ----------

function _Reg-Tunnel {
    param([int]$LocalPort, [string]$Ip, [int]$RemotePort, [string]$Label)
    $existing = Get-NetTCPConnection -LocalPort $LocalPort -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host "Port $LocalPort already in use — assuming tunnel exists" -ForegroundColor Yellow
        return
    }
    Start-Process ssh -ArgumentList "-fN", "-L", "${LocalPort}:${Ip}:${RemotePort}", $script:REG_JUMPBOX -WindowStyle Hidden
    Start-Sleep -Milliseconds 500
    Write-Host "Tunnel: localhost:$LocalPort -> ${Ip}:$RemotePort ($Label)" -ForegroundColor Green
}

# ---------- main ----------

function reg {
    $ip = _Reg-Pick
    if (-not $ip) { return }
    $action = _Reg-Action
    if (-not $action) { return }

    switch ($action) {
        "ssh" { ssh -J $script:REG_JUMPBOX "$($script:REG_USER)@$ip" }
        "vnc" {
            _Reg-Tunnel 5901 $ip 5900 "VNC"
            Write-Host "-> Connect VNC client to localhost:5901"
        }
        "rdp" {
            _Reg-Tunnel 13389 $ip 3389 "RDP"
            mstsc /v:localhost:13389
        }
        "web" {
            $port = Read-Host "Remote web port [8080]"
            if (-not $port) { $port = 8080 }
            $lport = "1$port"
            _Reg-Tunnel ([int]$lport) $ip ([int]$port) "Web"
            Start-Process "http://localhost:$lport"
        }
        "log-tail" {
            ssh -J $script:REG_JUMPBOX "$($script:REG_USER)@$ip" "tail -f $script:REG_LOG_PATH"
        }
        "log-grep" {
            $pattern = Read-Host "grep pattern"
            ssh -J $script:REG_JUMPBOX "$($script:REG_USER)@$ip" "grep -i '$pattern' $script:REG_LOG_PATH | tail -100"
        }
        "status" {
            ssh -J $script:REG_JUMPBOX "$($script:REG_USER)@$ip" "uptime; echo; df -h /; echo; ps -ef | grep -i flooid | grep -v grep"
        }
        "ssh+log (tmux split)" {
            reg-tmux-pair $ip
        }
        "close-tunnels" {
            Get-CimInstance Win32_Process -Filter "Name='ssh.exe'" |
                Where-Object { $_.CommandLine -like "*$ip*" -and $_.CommandLine -like "*-fN*" } |
                ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
            Write-Host "Tunnels to $ip closed"
        }
    }
}

# ---------- psmux integration ----------

function reg-tmux-store {
    param([string]$Store)

    if (-not $Store) {
        Write-Host "Usage: reg-tmux-store <store_id>"
        return
    }

    if (-not (Get-Command tmux -ErrorAction SilentlyContinue)) {
        Write-Host "psmux/tmux not found in PATH" -ForegroundColor Red
        return
    }

    $ips = Get-Content $script:RegInventory |
        Where-Object { $_ -notmatch '^\s*(#|$)' -and $_ -match "^$Store," } |
        ForEach-Object { ($_ -split ',')[2] }

    if (-not $ips) {
        Write-Host "No registers found for store $Store" -ForegroundColor Yellow
        return
    }

    $session = "store-$Store"
    $existing = tmux ls 2>$null | Select-String "^$session`:"
    if ($existing) {
        tmux attach -t $session
        return
    }

    $first = $true
    foreach ($ip in $ips) {
        $sshCmd = "ssh -J $script:REG_JUMPBOX $($script:REG_USER)@$ip"
        if ($first) {
            tmux new-session -d -s $session -n "reg-$Store" $sshCmd
            $first = $false
        } else {
            tmux split-window -t $session $sshCmd
            tmux select-layout -t $session tiled
        }
    }

    tmux attach -t $session
}

function reg-tmux-pair {
    param([string]$Ip)

    if (-not $Ip) {
        Write-Host "Usage: reg-tmux-pair <ip>"
        return
    }

    $session = "reg-$($Ip -replace '\.', '-')"
    $sshCmd  = "ssh -J $script:REG_JUMPBOX $($script:REG_USER)@$Ip"
    $logCmd  = "ssh -J $script:REG_JUMPBOX $($script:REG_USER)@$Ip 'tail -f $script:REG_LOG_PATH'"

    $existing = tmux ls 2>$null | Select-String "^$session`:"
    if ($existing) {
        tmux attach -t $session
        return
    }

    tmux new-session -d -s $session $sshCmd
    tmux split-window -h -t $session $logCmd
    tmux attach -t $session
}

# Fzf-pick a register then open the paired tmux view
function reg-tmux {
    $ip = _Reg-Pick
    if (-not $ip) { return }
    reg-tmux-pair $ip
}

# ---------- inventory + tunnel management ----------

function reg-refresh {
    param([string]$Source = "local")
    python "$script:RegToolDir\refresh.py" --source $Source
}

function reg-tunnels {
    Write-Host "Active tunnels through $script:REG_JUMPBOX:"
    $procs = Get-CimInstance Win32_Process -Filter "Name='ssh.exe'" |
        Where-Object { $_.CommandLine -like "*$script:REG_JUMPBOX*" -and $_.CommandLine -like "*-fN*" }
    if (-not $procs) {
        Write-Host "  (none)"
        return
    }
    foreach ($p in $procs) {
        if ($p.CommandLine -match '-L\s+(\S+)') { "  $($matches[1])" }
    }
}

function reg-tunnels-kill {
    $procs = Get-CimInstance Win32_Process -Filter "Name='ssh.exe'" |
        Where-Object { $_.CommandLine -like "*$script:REG_JUMPBOX*" -and $_.CommandLine -like "*-fN*" }
    if (-not $procs) {
        Write-Host "No tunnels to close"
        return
    }
    $procs | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
    Write-Host "All tunnels closed"
}
