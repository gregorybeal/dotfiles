# Bootstrap dotfiles on Windows.
# Requires either an elevated PowerShell window OR Developer Mode enabled
# (Settings -> Privacy & security -> For developers -> Developer Mode).
# Idempotent — safe to re-run.

$ErrorActionPreference = "Stop"
$Dotfiles = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "Dotfiles root: $Dotfiles" -ForegroundColor Cyan
Write-Host ""

function Link-File {
    param([string]$Src, [string]$Dst)

    if (Test-Path $Dst) {
        $item = Get-Item $Dst -Force
        if ($item.LinkType -eq "SymbolicLink" -and $item.Target -eq $Src) {
            Write-Host "  [ok]   $Dst (already linked)"
            return
        }
        $backup = "$Dst.backup"
        Move-Item -Path $Dst -Destination $backup -Force
        Write-Host "  [bak]  $Dst -> $backup" -ForegroundColor Yellow
    }

    $parent = Split-Path -Parent $Dst
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    try {
        New-Item -ItemType SymbolicLink -Path $Dst -Target $Src -Force | Out-Null
        Write-Host "  [link] $Dst" -ForegroundColor Green
    } catch {
        Write-Host "  [FAIL] $Dst — symlink creation requires admin or Developer Mode" -ForegroundColor Red
        Write-Host "         $_" -ForegroundColor Red
    }
}

# --- PowerShell profile ---
Write-Host "PowerShell profile:"
$profilePath = $PROFILE
Link-File "$Dotfiles\powershell\Microsoft.PowerShell_profile.ps1" $profilePath

# --- tmux (used by psmux) ---
Write-Host "tmux/psmux config:"
Link-File "$Dotfiles\tmux\.tmux.conf" "$env:USERPROFILE\.tmux.conf"

# --- Starship ---
Write-Host "Starship config:"
$starshipConfigDir = "$env:USERPROFILE\.config"
if (-not (Test-Path $starshipConfigDir)) {
    New-Item -ItemType Directory -Path $starshipConfigDir -Force | Out-Null
}
Link-File "$Dotfiles\starship\starship.toml" "$starshipConfigDir\starship.toml"

# --- git ---
Write-Host "git config:"
Link-File "$Dotfiles\git\.gitconfig" "$env:USERPROFILE\.gitconfig"

# --- ssh (Windows-specific, no ControlMaster) ---
Write-Host "SSH config:"
Link-File "$Dotfiles\ssh\config.windows" "$env:USERPROFILE\.ssh\config"

# --- reg-tool ---
Write-Host "reg-tool:"
$regToolDir = "$env:USERPROFILE\.config\reg-tool"
if (-not (Test-Path $regToolDir)) {
    New-Item -ItemType Directory -Path $regToolDir -Force | Out-Null
}
Link-File "$Dotfiles\reg-tool\reg.ps1"     "$regToolDir\reg.ps1"
Link-File "$Dotfiles\reg-tool\refresh.py"  "$regToolDir\refresh.py"

if (-not (Test-Path "$regToolDir\config")) {
    Copy-Item "$Dotfiles\reg-tool\config.example" "$regToolDir\config"
    Write-Host "  [new]  $regToolDir\config (edit this to set jumpbox + paths)" -ForegroundColor Green
} else {
    Write-Host "  [keep] $regToolDir\config (already exists)"
}

Write-Host ""
Write-Host "Done. Next steps:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  1. Install dependencies if you haven't (skip if you ran bootstrap.ps1):"
Write-Host "       winget install psmux"
Write-Host "       winget install junegunn.fzf"
Write-Host "       winget install JanDeDobbeleer.OhMyPosh"
Write-Host "       winget install GitHub.cli"
Write-Host "       Install-Module PSReadLine -Force -AllowPrerelease"
Write-Host "       Install-Module Terminal-Icons -Force"
Write-Host ""
Write-Host "  2. Authenticate with GitHub:  gh auth login"
Write-Host "       (pick HTTPS, then 'Yes' to authenticate git)"
Write-Host "  3. Edit $regToolDir\config with your jump box + SQLite paths"
Write-Host "  4. Restart PowerShell (or: . `$PROFILE)"
Write-Host "  5. Run: reg-refresh"
Write-Host "  6. Try: reg"
Write-Host ""
