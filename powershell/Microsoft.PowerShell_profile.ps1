# Microsoft.PowerShell_profile.ps1 — managed by dotfiles repo

# ---------- PSReadLine (bash-like editing + predictions) ----------
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine
    Set-PSReadLineOption -EditMode Emacs
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineOption -HistoryNoDuplicates
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Ctrl+r    -Function ReverseSearchHistory
    Set-PSReadLineKeyHandler -Key Ctrl+w    -Function BackwardKillWord
    Set-PSReadLineKeyHandler -Key Ctrl+u    -Function BackwardKillLine
}

# ---------- Terminal-Icons ----------
if (Get-Module -ListAvailable -Name Terminal-Icons) {
    Import-Module Terminal-Icons
}

# ---------- posh-git ----------
if (Get-Module -ListAvailable -Name posh-git) {
    Import-Module posh-git
}

# ---------- Starship prompt ----------
# (Replaces Oh My Posh — same prompt config used on Mac/WSL/Linux)
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
}

# ---------- Aliases ----------
Set-Alias -Name ll    -Value Get-ChildItem
Set-Alias -Name grep  -Value Select-String
Set-Alias -Name which -Value Get-Command
Set-Alias -Name touch -Value New-Item

# ---------- Navigation functions ----------
function .. { Set-Location .. }
function ... { Set-Location ../.. }
function .... { Set-Location ../../.. }

# ---------- Git shortcuts ----------
function gs { git status }
function gd { git diff }
function gl { git log --oneline --graph --decorate -20 }
function gp { git pull }
function gpu { git push }
function gco { git checkout $args }
function gcm { git commit -m $args }
function gb { git branch }

# ---------- gh CLI shortcuts ----------
function ghs { gh pr status }
function ghl { gh pr list }
function ghv { gh pr view --web }
function ghc { gh pr create --fill --web }
function ghi { gh issue list --assignee @me }

# ---------- tmux/psmux shortcuts ----------
function t   { tmux $args }
function ta  { tmux attach -t $args }
function tls { tmux ls }
function tn  { tmux new -s $args }
function tk  { tmux kill-session -t $args }

# ---------- Quick edits ----------
function Edit-Profile  { code $PROFILE }
function Edit-Tmux     { code "$env:USERPROFILE\.tmux.conf" }
function Edit-Ssh      { code "$env:USERPROFILE\.ssh\config" }
function Reload-Profile { . $PROFILE }

# ---------- reg-tool ----------
$regToolScript = "$env:USERPROFILE\.config\reg-tool\reg.ps1"
if (Test-Path $regToolScript) {
    . $regToolScript
}

# ---------- Machine-local overrides (not in repo) ----------
$localProfile = "$env:USERPROFILE\.powershell_profile.local.ps1"
if (Test-Path $localProfile) {
    . $localProfile
}
