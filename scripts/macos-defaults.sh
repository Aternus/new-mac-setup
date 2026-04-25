#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$HOME/Documents"

defaults write NSGlobalDomain AppleInterfaceStyle -string Dark
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 25
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain AppleMeasurementUnits -string Centimeters
defaults write NSGlobalDomain AppleMetricUnits -bool true
defaults write NSGlobalDomain AppleTemperatureUnit -string Celsius
defaults write NSGlobalDomain AppleLanguages -array "en-US" "he-US" "ru-US"
defaults write NSGlobalDomain AppleLocale -string "en_US"

defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder FXPreferredViewStyle -string Nlsv
defaults write com.apple.finder FXDefaultSearchScope -string SCcf

defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock tilesize -int 56
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock minimize-to-application -bool true
defaults write com.apple.dock mru-spaces -bool false

defaults write com.apple.screencapture location -string "$HOME/Documents"

if command -v sudo >/dev/null 2>&1; then
  sudo systemsetup -settimezone "Asia/Jerusalem" >/dev/null 2>&1 || true
fi

killall Finder >/dev/null 2>&1 || true
killall Dock >/dev/null 2>&1 || true
killall SystemUIServer >/dev/null 2>&1 || true
