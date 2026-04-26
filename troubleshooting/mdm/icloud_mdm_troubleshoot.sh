#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="${REPORT_DIR:-$SCRIPT_DIR/reports}"
mkdir -p "$REPORT_DIR"
REPORT_FILE="$REPORT_DIR/icloud_mdm_report_$(date +%Y%m%d_%H%M%S).log"

exec > >(tee -a "$REPORT_FILE") 2>&1

section() {
  printf '\n=== %s ===\n' "$1"
}

run_cmd() {
  local title="$1"
  shift
  section "$title"
  if ! "$@"; then
    printf 'Command failed (non-fatal): %s\n' "$*"
  fi
}

run_shell() {
  local title="$1"
  local cmd="$2"
  section "$title"
  if ! /bin/bash -lc "$cmd"; then
    printf 'Command failed (non-fatal): %s\n' "$cmd"
  fi
}

run_icloud_pending_summary() {
  section "iCloud Pending Status Summary (compact)"

  local status_output
  if ! status_output="$(brctl status | perl -pe 's/\e\[[0-9;]*[A-Za-z]//g')"; then
    printf 'Command failed (non-fatal): brctl status\n'
    return 0
  fi

  printf '%s\n' "Showing all containers."
  printf '%-34s %-24s %-24s %-23s %s\n' "CONTAINER" "CLIENT" "SERVER" "LAST_SYNC" "HEALTH"
  printf '%s\n' "-----------------------------------------------------------------------------------------------------------------------"

  printf '%s\n' "$status_output" | awk '
    function clip(s, n) {
      if (length(s) <= n) return s;
      return substr(s, 1, n - 3) "...";
    }

    /^</ {
      container=$1;
      sub(/^</, "", container);
      sub(/>$/, "", container);

      client="-"; server="-"; last="-"; health="CHECK";

      tmp=$0;
      if (sub(/^.*client:/, "", tmp)) {
        sub(/ .*/, "", tmp);
        client=tmp;
      }

      tmp=$0;
      if (sub(/^.*server:/, "", tmp)) {
        sub(/ .*/, "", tmp);
        server=tmp;
      }

      tmp=$0;
      if (sub(/^.*last-sync:/, "", tmp)) {
        if (tmp ~ /^never([ ,]|$)/) {
          last="never";
        } else {
          sub(/,.*$/, "", tmp);
          last=tmp;
        }
      }

      if (client ~ /(needs-sync|blocked|error)/ || last == "never" || $0 ~ /SYNC DISABLED/) {
        health="ATTN"; attn++;
      } else if (client ~ /idle/ && ($0 ~ /(caught-up|consistent)/)) {
        health="OK"; ok++;
      } else {
        check++;
      }

      printf "%-34s %-24s %-24s %-23s %s\n", clip(container, 34), clip(client, 24), clip(server, 24), clip(last, 23), health;
      next;
    }

    /^>>>/ {
      messages++;
      printf "%-34s %-24s %-24s %-23s %s\n", "(message)", "-", "-", "-", clip($0, 60);
    }

    END {
      printf "\nSummary: OK=%d ATTN=%d CHECK=%d MESSAGES=%d\n", ok, attn, check, messages;
    }
  '
}

section "Report Metadata"
printf 'Generated at: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
printf 'Hostname: %s\n' "$(scutil --get ComputerName 2>/dev/null || hostname)"
printf 'User: %s\n' "$(id -un)"

run_cmd "macOS Version" sw_vers
run_cmd "MDM Enrollment Status" profiles status -type enrollment
run_shell "Configuration Profiles (first 250 lines)" "profiles show -type configuration | sed -n '1,250p'"

run_cmd "iCloud Drive Accounts" brctl accounts -w
run_cmd "iCloud Quota" brctl quota
run_icloud_pending_summary

run_shell "Cloud/Account Managed Pref Files" "ls -1 /Library/Managed\\ Preferences 2>/dev/null | rg -i 'cloud|icloud|applicationaccess|accounts|appleid' || true"
run_shell "Cloud/Account Managed Profile Keys" "profiles show -type configuration | rg -i 'icloud|cloud|appleid|applicationaccess|allow|restrict|managed' || true"

run_shell "Network Reachability to Apple iCloud Endpoints" "for u in https://www.icloud.com https://pong.icloud.com https://metrics.icloud.com https://account.apple.com; do printf '%s -> ' \"\$u\"; curl -I -sS --max-time 10 \"\$u\" | head -n 1 || echo 'FAILED'; done"

section "Optional Manual Recovery (not run automatically)"
printf '%s\n' "If account is allowed but sync appears stuck, run:"
printf '  %s\n' "killall bird cloudd"
printf '  %s\n' "brctl monitor -g -w"

section "Done"
printf 'Troubleshooting report complete.\n'
