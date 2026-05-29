#!/usr/bin/env bash
# macos-defaults.sh — apply sensible macOS preferences for a new Mac.
# Safe to re-run. Reboots / app restarts are noted at the end.
#
# Each setting has a one-line comment explaining what it does so you can
# comment out anything you don't want.

set -e

if [ "$(uname -s)" != "Darwin" ]; then
    echo "This script only applies to macOS."
    exit 1
fi

echo "Applying macOS defaults..."

# ─────────────────────────────────────────────────────────────
#  General UI / UX
# ─────────────────────────────────────────────────────────────

# Show scrollbars only when scrolling
defaults write NSGlobalDomain AppleShowScrollBars -string "WhenScrolling"

# Disable the "Are you sure you want to open this application?" dialog
defaults write com.apple.LaunchServices LSQuarantine -bool false

# Disable shake-to-find-cursor (annoying when working with multiple monitors)
defaults write -g CGDisableCursorLocationMagnification -bool true

# Show battery percentage in menu bar
defaults write com.apple.menuextra.battery ShowPercent -string "YES"

# ─────────────────────────────────────────────────────────────
#  Keyboard
# ─────────────────────────────────────────────────────────────

# Fast key repeat (essential for terminal work)
defaults write NSGlobalDomain KeyRepeat -int 2          # default 6
defaults write NSGlobalDomain InitialKeyRepeat -int 15  # default 25

# Disable press-and-hold for accent characters — enables key repeat
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Disable autocorrect (annoying when typing code, commands, paths)
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Disable smart quotes/dashes (they break copy-pasted code)
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

# Enable full keyboard access for all controls (Tab through buttons in dialogs)
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

# ─────────────────────────────────────────────────────────────
#  Trackpad / Mouse
# ─────────────────────────────────────────────────────────────

# Tap to click
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Three-finger drag (great for moving windows by their title bars)
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadThreeFingerDrag -bool true
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true

# Faster trackpad tracking
defaults write NSGlobalDomain com.apple.trackpad.scaling -float 2.0

# ─────────────────────────────────────────────────────────────
#  Finder
# ─────────────────────────────────────────────────────────────

# Show hidden files
defaults write com.apple.finder AppleShowAllFiles -bool true

# Show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Show status bar + path bar
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder ShowPathbar -bool true

# Display full POSIX path as Finder window title
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# When performing a search, search the current folder by default
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# Disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Avoid creating .DS_Store files on network or USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Use list view in all Finder windows by default
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Show the ~/Library folder
chflags nohidden ~/Library 2>/dev/null || true

# ─────────────────────────────────────────────────────────────
#  Dock
# ─────────────────────────────────────────────────────────────

# Faster Dock animations
defaults write com.apple.dock autohide-time-modifier -float 0.3
defaults write com.apple.dock autohide-delay -float 0

# Auto-hide the Dock
defaults write com.apple.dock autohide -bool true

# Don't show recent applications in the Dock
defaults write com.apple.dock show-recents -bool false

# Smaller default icon size
defaults write com.apple.dock tilesize -int 48

# ─────────────────────────────────────────────────────────────
#  Screenshots
# ─────────────────────────────────────────────────────────────

# Save screenshots to a dedicated folder (instead of cluttering Desktop)
mkdir -p "$HOME/Pictures/Screenshots"
defaults write com.apple.screencapture location -string "$HOME/Pictures/Screenshots"

# Save screenshots as PNG (default — but explicit is good)
defaults write com.apple.screencapture type -string "png"

# Disable the shadow on screenshots of windows
defaults write com.apple.screencapture disable-shadow -bool true

# ─────────────────────────────────────────────────────────────
#  Safari / Webkit (lightweight; mostly dev-friendly)
# ─────────────────────────────────────────────────────────────

# Show full URL in address bar
defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true

# Enable Develop menu and Web Inspector
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
defaults write com.apple.Safari "com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled" -bool true

# ─────────────────────────────────────────────────────────────
#  Terminal-related
# ─────────────────────────────────────────────────────────────

# Only use UTF-8 in Terminal.app
defaults write com.apple.terminal StringEncodings -array 4

# ─────────────────────────────────────────────────────────────
#  Mac App Store
# ─────────────────────────────────────────────────────────────

# Enable automatic update checks
defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true

# Download newly available updates in background
defaults write com.apple.SoftwareUpdate AutomaticDownload -int 1

# Install System data files & security updates automatically
defaults write com.apple.SoftwareUpdate CriticalUpdateInstall -int 1

# ─────────────────────────────────────────────────────────────
#  Restart affected apps
# ─────────────────────────────────────────────────────────────

echo "Restarting affected apps..."
for app in "Dock" "Finder" "SystemUIServer" "cfprefsd"; do
    killall "$app" 2>/dev/null || true
done

echo ""
echo "✓ macOS defaults applied."
echo "  Some changes (keyboard, trackpad) take effect on next login."
echo "  Reboot or log out and back in to make sure all changes apply."
