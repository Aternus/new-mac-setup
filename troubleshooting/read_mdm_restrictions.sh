#!/usr/bin/env bash
set -euo pipefail

section() {
  printf '\n=== %s ===\n' "$1"
}

read_domain() {
  local domain="$1"
  local target="/Library/Managed Preferences/${domain}"
  local plist="${target}.plist"

  section "$domain"

  if [ ! -f "$plist" ]; then
    printf 'Not found: %s\n' "$plist"
    return 0
  fi

  printf '$ sudo defaults read %s\n' "$target"
  if ! sudo /usr/bin/defaults read "$target"; then
    printf 'Failed to read %s\n' "$target"
    return 0
  fi
}

section "Managed Restriction Reads"
read_domain "com.apple.applicationaccess"
read_domain "com.apple.applicationaccess.new"

printf '\nDone.\n'
