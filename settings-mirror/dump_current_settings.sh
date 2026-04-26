#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$SCRIPT_DIR"
COMMON_FILE="$MODULE_DIR/lib/common.sh"

MANIFEST_FILE="${MANIFEST_FILE:-$MODULE_DIR/manifest/settings_manifest.tsv}"
OUTPUT_FILE="${1:-$MODULE_DIR/dumps/current_laptop_settings_dump.tsv}"
VERBOSE_MISSING="${VERBOSE_MISSING:-0}"

if [[ ! -f "$COMMON_FILE" ]]; then
  printf 'Common helper file not found: %s\n' "$COMMON_FILE" >&2
  exit 1
fi

# shellcheck source=./lib/common.sh
source "$COMMON_FILE"

if [[ ! -f "$MANIFEST_FILE" ]]; then
  printf 'Manifest file not found: %s\n' "$MANIFEST_FILE" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"

{
  printf '# mac-settings-dump-v1\n'
  printf '# generated_at_utc=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf '# host_os=%s\n' "$(sw_vers -productVersion 2>/dev/null || echo unknown)"
  printf '# format=TYPE<TAB>SCOPE<TAB>KEY<TAB>VALUE_JSON\n'
} >"$OUTPUT_FILE"

captured_count=0
missing_count=0

while IFS=$'\t' read -r setting_type scope key _description; do
  [[ -z "$setting_type" || "$setting_type" == \#* ]] && continue

  value_json=""
  case "$setting_type" in
  DEFAULTS)
    if ! value_json="$(read_defaults_json "regular" "$scope" "$key")"; then
      if [[ "$VERBOSE_MISSING" == "1" ]]; then
        printf 'Skipping missing defaults key: %s %s\n' "$scope" "$key" >&2
      fi
      missing_count=$((missing_count + 1))
      continue
    fi
    ;;
  DEFAULTS_CURRENT_HOST)
    if ! value_json="$(read_defaults_json "current_host" "$scope" "$key")"; then
      if [[ "$VERBOSE_MISSING" == "1" ]]; then
        printf 'Skipping missing currentHost defaults key: %s %s\n' "$scope" "$key" >&2
      fi
      missing_count=$((missing_count + 1))
      continue
    fi
    ;;
  SYSTEM)
    if [[ "$scope" == "systemsetup" && "$key" == "timezone" ]]; then
      if ! value_json="$(read_timezone_json)"; then
        if [[ "$VERBOSE_MISSING" == "1" ]]; then
          printf 'Skipping timezone: failed to read current timezone\n' >&2
        fi
        missing_count=$((missing_count + 1))
        continue
      fi
    else
      if [[ "$VERBOSE_MISSING" == "1" ]]; then
        printf 'Skipping unknown SYSTEM setting: %s %s\n' "$scope" "$key" >&2
      fi
      missing_count=$((missing_count + 1))
      continue
    fi
    ;;
  *)
    if [[ "$VERBOSE_MISSING" == "1" ]]; then
      printf 'Skipping unknown setting type: %s\n' "$setting_type" >&2
    fi
    missing_count=$((missing_count + 1))
    continue
    ;;
  esac

  value_json="$(sanitize_json_value "$value_json")"
  printf '%s\t%s\t%s\t%s\n' "$setting_type" "$scope" "$key" "$value_json" >>"$OUTPUT_FILE"
  captured_count=$((captured_count + 1))
done <"$MANIFEST_FILE"

printf 'Wrote sanitized settings dump: %s\n' "$OUTPUT_FILE"
printf 'Captured: %d\n' "$captured_count"
printf 'Skipped: %d\n' "$missing_count"
if [[ "$VERBOSE_MISSING" != "1" ]]; then
  printf 'Tip: run with VERBOSE_MISSING=1 to print every skipped key.\n'
fi
printf 'PII guardrails: username/home paths are tokenized as {{USER}} and {{HOME}}.\n'
