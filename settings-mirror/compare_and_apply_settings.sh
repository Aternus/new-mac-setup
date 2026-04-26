#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$SCRIPT_DIR"
COMMON_FILE="$MODULE_DIR/lib/common.sh"

DUMP_FILE="${1:-$MODULE_DIR/dumps/current_laptop_settings_dump.tsv}"

if [[ ! -f "$COMMON_FILE" ]]; then
  printf 'Common helper file not found: %s\n' "$COMMON_FILE" >&2
  exit 1
fi

# shellcheck source=./lib/common.sh
source "$COMMON_FILE"

symbolic_hotkey_name() {
  local id="$1"
  case "$id" in
  60)
    printf 'Select the previous input source'
    ;;
  61)
    printf 'Select next source in Input menu'
    ;;
  *)
    printf 'Symbolic hotkey'
    ;;
  esac
}

prompt_confirm() {
  local prompt="$1"
  local response

  if [[ -r /dev/tty ]]; then
    read -r -p "$prompt [y/N] " response </dev/tty
  else
    printf '%s [y/N] (non-interactive mode: defaulting to no)\n' "$prompt" >&2
    return 1
  fi

  [[ "$response" == "y" || "$response" == "Y" || "$response" == "yes" || "$response" == "YES" ]]
}

if [[ ! -f "$DUMP_FILE" ]]; then
  printf 'Settings dump file not found: %s\n' "$DUMP_FILE" >&2
  exit 1
fi

total_count=0
diff_count=0
applied_count=0
failed_count=0
applied_defaults=0

while IFS=$'\t' read -r setting_type scope key desired_json_raw; do
  [[ -z "$setting_type" || "$setting_type" == \#* ]] && continue

  total_count=$((total_count + 1))
  desired_json="$(materialize_json_value "$desired_json_raw")"

  current_json=""
  current_label=""

  case "$setting_type" in
  DEFAULTS)
    if current_json="$(read_defaults_json "regular" "$scope" "$key")"; then
      current_label="defaults ${scope} ${key}"
    else
      current_json="<missing>"
      current_label="defaults ${scope} ${key}"
    fi
    ;;
  DEFAULTS_KEYPATH)
    if current_json="$(read_defaults_keypath_json "regular" "$scope" "$key")"; then
      current_label="defaults keypath ${scope} ${key}"
    else
      current_json="<missing>"
      current_label="defaults keypath ${scope} ${key}"
    fi
    ;;
  DEFAULTS_CURRENT_HOST)
    if current_json="$(read_defaults_json "current_host" "$scope" "$key")"; then
      current_label="defaults -currentHost ${scope} ${key}"
    else
      current_json="<missing>"
      current_label="defaults -currentHost ${scope} ${key}"
    fi
    ;;
  DEFAULTS_CURRENT_HOST_KEYPATH)
    if current_json="$(read_defaults_keypath_json "current_host" "$scope" "$key")"; then
      current_label="defaults -currentHost keypath ${scope} ${key}"
    else
      current_json="<missing>"
      current_label="defaults -currentHost keypath ${scope} ${key}"
    fi
    ;;
  SYSTEM)
    if [[ "$scope" == "systemsetup" && "$key" == "timezone" ]]; then
      if current_json="$(read_timezone_json)"; then
        current_label="systemsetup timezone"
      else
        current_json="<unreadable>"
        current_label="systemsetup timezone"
      fi
    else
      printf 'Skipping unknown SYSTEM setting: %s %s\n' "$scope" "$key" >&2
      continue
    fi
    ;;
  *)
    printf 'Skipping unknown setting type: %s\n' "$setting_type" >&2
    continue
    ;;
  esac

  if [[ "$current_json" == "$desired_json" ]]; then
    continue
  fi

  diff_count=$((diff_count + 1))
  printf '\nDifference found: %s\n' "$current_label"
  printf '  current: %s\n' "$current_json"
  printf '  desired: %s\n' "$desired_json"
  if [[ "$setting_type" == "DEFAULTS_KEYPATH" && "$scope" == "com.apple.symbolichotkeys" && "$key" == AppleSymbolicHotKeys.* ]]; then
    shortcut_id="${key#AppleSymbolicHotKeys.}"
    printf '  note: hotkey %s (ID %s).\n' "$(symbolic_hotkey_name "$shortcut_id")" "$shortcut_id"
  fi

  if ! prompt_confirm "Apply this setting on this Mac?"; then
    continue
  fi

  if [[ "$setting_type" == "DEFAULTS" ]]; then
    if apply_defaults_json "regular" "$scope" "$key" "$desired_json"; then
      printf '  updated.\n'
      applied_count=$((applied_count + 1))
      applied_defaults=$((applied_defaults + 1))
    else
      printf '  failed to update.\n' >&2
      failed_count=$((failed_count + 1))
    fi
    continue
  fi

  if [[ "$setting_type" == "DEFAULTS_KEYPATH" ]]; then
    if apply_defaults_keypath_json "regular" "$scope" "$key" "$desired_json"; then
      printf '  updated.\n'
      applied_count=$((applied_count + 1))
      applied_defaults=$((applied_defaults + 1))
    else
      printf '  failed to update.\n' >&2
      failed_count=$((failed_count + 1))
    fi
    continue
  fi

  if [[ "$setting_type" == "DEFAULTS_CURRENT_HOST" ]]; then
    if apply_defaults_json "current_host" "$scope" "$key" "$desired_json"; then
      printf '  updated.\n'
      applied_count=$((applied_count + 1))
      applied_defaults=$((applied_defaults + 1))
    else
      printf '  failed to update.\n' >&2
      failed_count=$((failed_count + 1))
    fi
    continue
  fi

  if [[ "$setting_type" == "DEFAULTS_CURRENT_HOST_KEYPATH" ]]; then
    if apply_defaults_keypath_json "current_host" "$scope" "$key" "$desired_json"; then
      printf '  updated.\n'
      applied_count=$((applied_count + 1))
      applied_defaults=$((applied_defaults + 1))
    else
      printf '  failed to update.\n' >&2
      failed_count=$((failed_count + 1))
    fi
    continue
  fi

  if [[ "$setting_type" == "SYSTEM" ]]; then
    if apply_timezone "$desired_json"; then
      printf '  updated.\n'
      applied_count=$((applied_count + 1))
    else
      printf '  failed to update.\n' >&2
      failed_count=$((failed_count + 1))
    fi
  fi
done <"$DUMP_FILE"

printf '\nSummary\n'
printf '  checked: %d\n' "$total_count"
printf '  differences: %d\n' "$diff_count"
printf '  applied: %d\n' "$applied_count"
printf '  failed: %d\n' "$failed_count"

if ((applied_defaults > 0)); then
  if prompt_confirm "Restart Finder, Dock, SystemUIServer, ControlCenter, and cfprefsd now?"; then
    killall Finder >/dev/null 2>&1 || true
    killall Dock >/dev/null 2>&1 || true
    killall SystemUIServer >/dev/null 2>&1 || true
    killall ControlCenter >/dev/null 2>&1 || true
    killall cfprefsd >/dev/null 2>&1 || true
    printf 'UI processes restarted.\n'
  else
    printf 'UI process restart skipped; some settings may need logout/restart.\n'
  fi
fi
