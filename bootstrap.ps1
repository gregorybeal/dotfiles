# Bootstrap dotfiles on Windows using chezmoi.
# Run from PowerShell (elevated for winget installs, optional otherwise).
# Idempotent — safe to re-run.

$ErrorActionPreference = "Stop"
$Dotfiles = Split-Path -Parent $MyInvocation.MyCommand.Path
$Repo = "github.com/gregorybeal/dotfiles"

Write-Host "Bootstrapping dotfiles (Windows + chezmoi)..." -ForegroundColor Cyan
Write-Host ""

# --- Install chezmoi ---
if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
    Write-Host "Installing chezmoi..."
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install --id twpayne.chezmoi -e --source winget
    } elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop install chezmoi
    } else {
        $env:TEMP = [System.IO.Path]::GetTempPath()
        Invoke-WebRequest -UseBasicParsing -Uri "https://get.chezmoi.io/ps1" | Invoke-Expression
    }
}

# --- Apply dotfiles ---
if (Test-Path "$Dotfiles\.chezmoi.toml.tmpl") {
    Write-Host "Applying dotfiles from $Dotfiles..."
    chezmoi init --source $Dotfiles --apply
} else {
    Write-Host "Cloning and applying dotfiles from $Repo..."
    chezmoi init --apply $Repo
}

# --- Copy PowerShell profile to the Windows Documents path ($PROFILE) ---
$PsProfileSrc = "$env:USERPROFILE\.config\powershell\Microsoft.PowerShell_profile.ps1"
$PsProfileDst = "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
if (Test-Path $PsProfileSrc) {
    $null = New-Item -ItemType Directory -Force -Path (Split-Path $PsProfileDst)
    Copy-Item -Force $PsProfileSrc $PsProfileDst
    Write-Host "PowerShell profile copied to $PsProfileDst"
}

Write-Host ""
Write-Host "Done! Next steps:" -ForegroundColor Green
Write-Host "  1. Restart PowerShell"
Write-Host "  2. gh auth login"
Write-Host "  3. Edit `$HOME\.config\reg-tool\config with your jumpbox and SQLite paths"
