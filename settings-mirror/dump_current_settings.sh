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

capture_setting() {
  local setting_type="$1"
  local scope="$2"
  local key="$3"
  local on_missing_message="$4"
  local value_json=""
  case "$setting_type" in
  DEFAULTS)
    if ! value_json="$(read_defaults_json "regular" "$scope" "$key")"; then
      if [[ "$VERBOSE_MISSING" == "1" ]]; then
        printf '%s\n' "$on_missing_message" >&2
      fi
      missing_count=$((missing_count + 1))
      return 1
    fi
    ;;
  DEFAULTS_CURRENT_HOST)
    if ! value_json="$(read_defaults_json "current_host" "$scope" "$key")"; then
      if [[ "$VERBOSE_MISSING" == "1" ]]; then
        printf '%s\n' "$on_missing_message" >&2
      fi
      missing_count=$((missing_count + 1))
      return 1
    fi
    ;;
  SYSTEM)
    if [[ "$scope" == "systemsetup" && "$key" == "timezone" ]]; then
      if ! value_json="$(read_timezone_json)"; then
        if [[ "$VERBOSE_MISSING" == "1" ]]; then
          printf '%s\n' "$on_missing_message" >&2
        fi
        missing_count=$((missing_count + 1))
        return 1
      fi
    else
      if [[ "$VERBOSE_MISSING" == "1" ]]; then
        printf 'Skipping unknown SYSTEM setting: %s %s\n' "$scope" "$key" >&2
      fi
      missing_count=$((missing_count + 1))
      return 1
    fi
    ;;
  *)
    if [[ "$VERBOSE_MISSING" == "1" ]]; then
      printf 'Skipping unknown setting type: %s\n' "$setting_type" >&2
    fi
    missing_count=$((missing_count + 1))
    return 1
    ;;
  esac

  if grep -Fq "$(printf '%s\t%s\t%s\t' "$setting_type" "$scope" "$key")" "$OUTPUT_FILE"; then
    return 0
  fi

  value_json="$(sanitize_json_value "$value_json")"
  printf '%s\t%s\t%s\t%s\n' "$setting_type" "$scope" "$key" "$value_json" >>"$OUTPUT_FILE"
  captured_count=$((captured_count + 1))
  return 0
}

list_domain_keys() {
  local read_mode="$1"
  local domain="$2"
  local defaults_cmd=(defaults)
  local tmp

  if [[ "$read_mode" == "current_host" ]]; then
    defaults_cmd=(defaults -currentHost)
  fi

  tmp="$(mktemp)"
  if ! "${defaults_cmd[@]}" export "$domain" "$tmp" >/dev/null 2>&1; then
    rm -f "$tmp"
    return 0
  fi

  plutil -p "$tmp" 2>/dev/null | sed -n 's/^  "\([^"]*\)" =>.*/\1/p'
  rm -f "$tmp"
}

capture_menu_bar_settings() {
  local key

  while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    case "$key" in
    NSStatusItem\ Visible\ * | NSStatusItem\ Preferred\ Position\ * | NSStatusItem\ VisibleCC\ *)
      capture_setting \
        "DEFAULTS" \
        "com.apple.controlcenter" \
        "$key" \
        "Skipping missing menu bar key: com.apple.controlcenter $key" || true
      ;;
    esac
  done < <(list_domain_keys "regular" "com.apple.controlcenter")

  while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    case "$key" in
    IRServiceToken)
      continue
      ;;
    *)
      capture_setting \
        "DEFAULTS_CURRENT_HOST" \
        "com.apple.controlcenter" \
        "$key" \
        "Skipping missing currentHost menu bar key: com.apple.controlcenter $key" || true
      ;;
    esac
  done < <(list_domain_keys "current_host" "com.apple.controlcenter")

  while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    capture_setting \
      "DEFAULTS_CURRENT_HOST" \
      "com.apple.controlcenter.displayablemenuextras" \
      "$key" \
      "Skipping missing currentHost menu bar key: com.apple.controlcenter.displayablemenuextras $key" || true
  done < <(list_domain_keys "current_host" "com.apple.controlcenter.displayablemenuextras")

  while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    capture_setting \
      "DEFAULTS_CURRENT_HOST" \
      "com.apple.controlcenter.bentoboxes" \
      "$key" \
      "Skipping missing currentHost menu bar key: com.apple.controlcenter.bentoboxes $key" || true
  done < <(list_domain_keys "current_host" "com.apple.controlcenter.bentoboxes")

  while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    capture_setting \
      "DEFAULTS_CURRENT_HOST" \
      "com.apple.Spotlight" \
      "$key" \
      "Skipping missing currentHost menu bar key: com.apple.Spotlight $key" || true
  done < <(list_domain_keys "current_host" "com.apple.Spotlight")

  while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    capture_setting \
      "DEFAULTS" \
      "com.apple.menuextra.clock" \
      "$key" \
      "Skipping missing menu bar key: com.apple.menuextra.clock $key" || true
  done < <(list_domain_keys "regular" "com.apple.menuextra.clock")

  while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    case "$key" in
    menuExtras | NSStatusItem\ Visible\ *)
      capture_setting \
        "DEFAULTS" \
        "com.apple.systemuiserver" \
        "$key" \
        "Skipping missing menu bar key: com.apple.systemuiserver $key" || true
      ;;
    esac
  done < <(list_domain_keys "regular" "com.apple.systemuiserver")
}

capture_finder_settings() {
  local key

  while IFS= read -r key; do
    [[ -z "$key" ]] && continue

    case "$key" in
    FXRecentFolders | GoToFieldHistory | RecentMoveAndCopyDestinations | SGTRecentFileSearches | NSOSPLastRootDirectory | FXConnectToLastURL | GoToField | NSWindow\ Frame\ * | *ProgressWindowLocation | FXPreferencesWindow.Location | DataSeparatedDisplayNameCache | LastTrashState | TagsCloudSerialNumber)
      continue
      ;;
    esac

    case "$key" in
    Sidebar* | SidebariCloudDriveSectionDisclosedState | SidebarShowingiCloudDesktop | SidebarShowingSignedIntoiCloud | ShowSidebar | ShowRecentTags | FavoriteTagNames | FK_*Sidebar* | FK_SidebarWidth | FK_SidebarWidth2 | FXSidebar* | FX*ViewSettings* | *ViewSettings | StandardViewSettings | DesktopViewSettings | ComputerViewSettings | NetworkViewSettings | ICloudViewSettings | SmartSharedSearchViewSettings | SearchViewSettings | SearchRecentsViewSettings | RecentsArrangeGroupViewBy | ShowHardDrivesOnDesktop | ShowExternalHardDrivesOnDesktop | ShowMountedServersOnDesktop | ShowRemovableMediaOnDesktop | ShowPathbar | ShowStatusBar | _FXSortFoldersFirst | FXPreferredViewStyle | FXPreferredSearchViewStyle | FXDefaultSearchScope | AppleShowAllFiles | AppleShowAllExtensions | CreateDesktop | WarnOnEmptyTrash | FXEnableExtensionChangeWarning)
      capture_setting \
        "DEFAULTS" \
        "com.apple.finder" \
        "$key" \
        "Skipping missing Finder key: com.apple.finder $key" || true
      ;;
    esac
  done < <(list_domain_keys "regular" "com.apple.finder")
}

while IFS=$'\t' read -r setting_type scope key _description; do
  [[ -z "$setting_type" || "$setting_type" == \#* ]] && continue
  capture_setting "$setting_type" "$scope" "$key" "Skipping missing defaults key: $scope $key" || true
done <"$MANIFEST_FILE"

capture_finder_settings
capture_menu_bar_settings

printf 'Wrote sanitized settings dump: %s\n' "$OUTPUT_FILE"
printf 'Captured: %d\n' "$captured_count"
printf 'Skipped: %d\n' "$missing_count"
if [[ "$VERBOSE_MISSING" != "1" ]]; then
  printf 'Tip: run with VERBOSE_MISSING=1 to print every skipped key.\n'
fi
printf 'PII guardrails: username/home paths are tokenized as {{USER}} and {{HOME}}.\n'
