# Full Windows bootstrap — installs all prerequisite tools, then runs install.ps1.
# Run from an ELEVATED PowerShell window the first time (admin rights needed
# for symlinks and some installs, unless Developer Mode is on).
#
# Idempotent: safe to re-run.

$ErrorActionPreference = "Stop"
$Dotfiles = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " dotfiles bootstrap (Windows)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ----------------------------------------
# Step 1: Verify winget is available
# ----------------------------------------

Write-Host "[1/6] Verifying winget" -ForegroundColor Green
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "  winget not found!" -ForegroundColor Red
    Write-Host "  Install 'App Installer' from the Microsoft Store, then re-run."
    exit 1
}
Write-Host "  winget OK"
Write-Host ""

# ----------------------------------------
# Step 2: Core CLI tools via winget
# ----------------------------------------

Write-Host "[2/6] Installing core tools" -ForegroundColor Green

$packages = @(
    @{id="Microsoft.PowerShell";       name="PowerShell 7"},
    @{id="Microsoft.WindowsTerminal";  name="Windows Terminal"},
    @{id="Git.Git";                    name="Git"},
    @{id="GitHub.cli";                 name="GitHub CLI (gh)"},
    @{id="psmux";                      name="psmux (tmux for Windows)"},
    @{id="junegunn.fzf";               name="fzf (fuzzy finder)"},
    @{id="Starship.Starship";          name="Starship (cross-shell prompt)"},
    @{id="sharkdp.bat";                name="bat (cat replacement)"},
    @{id="sharkdp.fd";                 name="fd (find replacement)"},
    @{id="BurntSushi.ripgrep.MSVC";    name="ripgrep"},
    @{id="jqlang.jq";                  name="jq (JSON processor)"},
    @{id="ajeetdsouza.zoxide";         name="zoxide (smart cd)"},
    @{id="Python.Python.3.12";         name="Python 3.12"},
    @{id="Microsoft.VisualStudioCode"; name="VS Code"}
)

foreach ($pkg in $packages) {
    Write-Host "  Installing $($pkg.name)..." -NoNewline
    $result = winget install --id $pkg.id --silent --accept-source-agreements --accept-package-agreements 2>&1
    if ($LASTEXITCODE -eq 0 -or $result -match "already installed") {
        Write-Host " ok" -ForegroundColor Green
    } else {
        Write-Host " (skipped / already installed)" -ForegroundColor Yellow
    }
}
Write-Host ""

# Refresh PATH for this session so new tools are usable immediately
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path","User")

# ----------------------------------------
# Step 3: Nerd Font
# ----------------------------------------

Write-Host "[3/6] Nerd Font (FiraCode)" -ForegroundColor Green
$fontInstalled = Get-ChildItem "$env:WINDIR\Fonts" -Filter "FiraCode*Nerd*" -ErrorAction SilentlyContinue
if (-not $fontInstalled) {
    Write-Host "  Installing FiraCode Nerd Font via Oh My Posh..."
    if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
        oh-my-posh font install FiraCode 2>&1 | Out-Null
        Write-Host "  Font installed."
    } else {
        Write-Host "  Oh My Posh not in PATH yet — install font manually:"
        Write-Host "    oh-my-posh font install FiraCode"
        Write-Host "  Or download from https://www.nerdfonts.com/"
    }
} else {
    Write-Host "  FiraCode Nerd Font already installed."
}
Write-Host ""

# ----------------------------------------
# Step 4: PowerShell modules
# ----------------------------------------

Write-Host "[4/6] PowerShell modules" -ForegroundColor Green

# Trust PSGallery so installs don't prompt
if ((Get-PSRepository -Name PSGallery).InstallationPolicy -ne "Trusted") {
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
}

$modules = @("PSReadLine", "Terminal-Icons", "posh-git")
foreach ($mod in $modules) {
    if (-not (Get-Module -ListAvailable -Name $mod)) {
        Write-Host "  Installing $mod..."
        Install-Module -Name $mod -Force -Scope CurrentUser -AllowPrerelease -ErrorAction SilentlyContinue
    } else {
        Write-Host "  $mod already installed."
    }
}
Write-Host ""

# ----------------------------------------
# Step 5: VS Code extensions + settings
# ----------------------------------------

Write-Host "[5/6] VS Code extensions + settings" -ForegroundColor Green

if (Get-Command code -ErrorAction SilentlyContinue) {
    $extFile = "$Dotfiles\vscode\extensions.txt"
    if (Test-Path $extFile) {
        Get-Content $extFile | Where-Object { $_ -notmatch '^\s*(#|$)' } | ForEach-Object {
            Write-Host "  + $_" -NoNewline
            code --install-extension $_ --force 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host " ok" -ForegroundColor Green
            } else {
                Write-Host " failed" -ForegroundColor Yellow
            }
        }
    }

    $vscodeDir = "$env:APPDATA\Code\User"
    if (-not (Test-Path $vscodeDir)) {
        New-Item -ItemType Directory -Path $vscodeDir -Force | Out-Null
    }

    # Link settings.json
    $settingsTarget = "$vscodeDir\settings.json"
    if ((Test-Path $settingsTarget) -and -not ((Get-Item $settingsTarget -Force).LinkType -eq "SymbolicLink")) {
        Move-Item $settingsTarget "$settingsTarget.backup" -Force
    }
    New-Item -ItemType SymbolicLink -Path $settingsTarget -Target "$Dotfiles\vscode\settings.json" -Force | Out-Null
    Write-Host "  Linked: $settingsTarget"

    # Link keybindings.json
    $keysTarget = "$vscodeDir\keybindings.json"
    if ((Test-Path $keysTarget) -and -not ((Get-Item $keysTarget -Force).LinkType -eq "SymbolicLink")) {
        Move-Item $keysTarget "$keysTarget.backup" -Force
    }
    New-Item -ItemType SymbolicLink -Path $keysTarget -Target "$Dotfiles\vscode\keybindings.json" -Force | Out-Null
    Write-Host "  Linked: $keysTarget"
} else {
    Write-Host "  VS Code not in PATH yet — skipping. Restart shell and re-run if needed."
}
Write-Host ""

# ----------------------------------------
# Step 6: Windows Terminal settings
# ----------------------------------------

Write-Host "[6/6] Windows Terminal settings" -ForegroundColor Green

$wtSettings = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

if (Test-Path (Split-Path $wtSettings -Parent)) {
    if ((Test-Path $wtSettings) -and -not ((Get-Item $wtSettings -Force).LinkType -eq "SymbolicLink")) {
        Move-Item $wtSettings "$wtSettings.backup" -Force
        Write-Host "  Backed up existing settings to settings.json.backup"
    }
    try {
        New-Item -ItemType SymbolicLink -Path $wtSettings -Target "$Dotfiles\windows-terminal\settings.json" -Force | Out-Null
        Write-Host "  Linked: $wtSettings" -ForegroundColor Green
    } catch {
        Write-Host "  Symlink failed (needs admin or Developer Mode)." -ForegroundColor Yellow
        Write-Host "  Falling back to copy..."
        Copy-Item "$Dotfiles\windows-terminal\settings.json" $wtSettings -Force
        Write-Host "  Copied (won't auto-update with git pull, but works)."
    }
} else {
    Write-Host "  Windows Terminal not installed yet — open it once after install, then re-run."
}
Write-Host ""

# ----------------------------------------
# Enable ssh-agent if it's not already running
# ----------------------------------------

Write-Host "Configuring ssh-agent service" -ForegroundColor Green
try {
    $svc = Get-Service ssh-agent -ErrorAction Stop
    if ($svc.StartType -ne "Automatic") {
        Set-Service ssh-agent -StartupType Automatic
        Write-Host "  Set ssh-agent to start automatically."
    }
    if ($svc.Status -ne "Running") {
        Start-Service ssh-agent
        Write-Host "  Started ssh-agent."
    }
    Write-Host "  ssh-agent OK"
} catch {
    Write-Host "  ssh-agent service not available — install OpenSSH Client via Windows Features." -ForegroundColor Yellow
}
Write-Host ""

# ----------------------------------------
# Final: run the linker
# ----------------------------------------

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Running install.ps1 to link configs" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
& "$Dotfiles\install.ps1"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Bootstrap complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Next:"
Write-Host "  1. Close this PowerShell and open a NEW window (so PATH refreshes)"
Write-Host "  2. Set Windows Terminal font to 'FiraCode Nerd Font' if it didn't auto-apply"
Write-Host "  3. Authenticate with GitHub:  gh auth login"
Write-Host "       (pick HTTPS, then 'Yes' to authenticate git)"
Write-Host "  4. Edit $env:USERPROFILE\.config\reg-tool\config"
Write-Host "  5. Add SSH key for jump box: ssh-add `$env:USERPROFILE\.ssh\id_ed25519"
Write-Host "  6. Run: reg-refresh"
Write-Host "  7. Try: tmux  (psmux will start)"
Write-Host ""
