#!/usr/bin/env bash

json_escape_string() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '"%s"' "$value"
}

sanitize_json_value() {
  local value="$1"
  value="${value//${HOME}/\{\{HOME\}\}}"
  value="${value//\/Users\/${USER}/\/Users\/\{\{USER\}\}}"
  printf '%s' "$value"
}

materialize_json_value() {
  local value="$1"
  value="${value//\{\{HOME\}\}/${HOME}}"
  value="${value//\{\{USER\}\}/${USER}}"
  printf '%s' "$value"
}

json_unquote_string() {
  local value="$1"
  value="${value#\"}"
  value="${value%\"}"
  value="${value//\\\"/\"}"
  value="${value//\\\\/\\}"
  printf '%s' "$value"
}

read_defaults_json() {
  local read_mode="$1"
  local domain="$2"
  local key="$3"
  local type_line
  local type_name
  local raw_value
  local defaults_cmd=(defaults)

  if [[ "$read_mode" == "current_host" ]]; then
    defaults_cmd=(defaults -currentHost)
  fi

  type_line="$("${defaults_cmd[@]}" read-type "$domain" "$key" 2>/dev/null || true)"
  type_name="$(printf '%s' "$type_line" | sed -n 's/^Type is //p' | head -n 1)"
  if [[ -z "$type_name" ]]; then
    return 1
  fi

  if ! raw_value="$("${defaults_cmd[@]}" read "$domain" "$key" 2>/dev/null)"; then
    return 1
  fi

  case "$type_name" in
  boolean)
    case "$(printf '%s' "$raw_value" | tr '[:upper:]' '[:lower:]')" in
    1 | true | yes)
      printf 'true'
      ;;
    *)
      printf 'false'
      ;;
    esac
    ;;
  integer | float)
    printf '%s' "$raw_value"
    ;;
  string)
    json_escape_string "$raw_value"
    ;;
  array | dictionary)
    local tmp
    local value_json
    tmp="$(mktemp)"
    printf '%s\n' "$raw_value" >"$tmp"
    if ! value_json="$(plutil -convert json -o - "$tmp" 2>/dev/null)"; then
      rm -f "$tmp"
      return 1
    fi
    rm -f "$tmp"
    printf '%s' "$value_json"
    ;;
  *)
    return 1
    ;;
  esac
}

read_timezone_name() {
  local timezone
  timezone="$(systemsetup -gettimezone 2>/dev/null | sed -n 's/^Time Zone: //p' | head -n 1)"

  if [[ -z "$timezone" ]]; then
    local timezone_link
    timezone_link="$(readlink /etc/localtime 2>/dev/null || true)"
    timezone="${timezone_link#*/zoneinfo/}"
    if [[ "$timezone" == "$timezone_link" ]]; then
      timezone=""
    fi
  fi

  [[ -n "$timezone" ]] || return 1
  printf '%s' "$timezone"
}

read_timezone_json() {
  local timezone
  timezone="$(read_timezone_name)" || return 1
  json_escape_string "$timezone"
}

apply_defaults_json() {
  local write_mode="$1"
  local domain="$2"
  local key="$3"
  local desired_json="$4"
  local defaults_cmd=(defaults)
  local tmp

  if [[ "$write_mode" == "current_host" ]]; then
    defaults_cmd=(defaults -currentHost)
  fi

  tmp="$(mktemp)"
  if ! "${defaults_cmd[@]}" export "$domain" "$tmp" >/dev/null 2>&1; then
    plutil -create xml1 "$tmp" >/dev/null
  fi

  if plutil -type "$key" "$tmp" >/dev/null 2>&1; then
    plutil -replace "$key" -json "$desired_json" "$tmp" >/dev/null
  else
    plutil -insert "$key" -json "$desired_json" "$tmp" >/dev/null
  fi

  "${defaults_cmd[@]}" import "$domain" "$tmp" >/dev/null
  rm -f "$tmp"
}

apply_timezone() {
  local desired_timezone_json="$1"
  local desired_timezone

  desired_timezone="$(json_unquote_string "$desired_timezone_json")"
  sudo systemsetup -settimezone "$desired_timezone" >/dev/null
}
