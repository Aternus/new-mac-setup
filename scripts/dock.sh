#!/usr/bin/env bash
set -euo pipefail

if ! command -v dockutil >/dev/null 2>&1; then
  printf 'dockutil is not installed; skipping Dock layout.\n'
  exit 0
fi

dockutil --remove all --no-restart

apps=(
  "/Applications/Firefox.app"
  "/Applications/Comet.app"
  "/Applications/Microsoft Edge.app"
  "/Applications/Safari.app"
  "/Applications/Google Chrome.app"
  "/Applications/Ghostty.app"
  "/Applications/Visual Studio Code.app"
  "/Applications/Cursor.app"
  "/Applications/Lens.app"
  "/Applications/Postman.app"
  "/Applications/MacPass.app"
  "/Applications/Microsoft Teams.app"
  "/Applications/Slack.app"
  "/Applications/Discord.app"
)

for app in "${apps[@]}"; do
  if [ -d "$app" ]; then
    dockutil --add "$app" --no-restart
  fi
done

killall Dock >/dev/null 2>&1 || true
