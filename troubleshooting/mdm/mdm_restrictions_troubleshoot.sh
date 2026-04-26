#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="${REPORT_DIR:-$SCRIPT_DIR/reports}"
mkdir -p "$REPORT_DIR"
REPORT_FILE="$REPORT_DIR/mdm_restrictions_report_$(date +%Y%m%d_%H%M%S).log"

exec > >(tee -a "$REPORT_FILE") 2>&1

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
