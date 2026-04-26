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

plist_escape_keypath() {
  local key="$1"
  key="${key//\\/\\\\}"
  key="${key//./\\.}"
  printf '%s' "$key"
}

extract_data_base64_from_json_string() {
  local json_value="$1"
  local decoded_value

  decoded_value="$(json_unquote_string "$json_value")"
  case "$decoded_value" in
  __SM_DATA_BASE64__:*)
    printf '%s' "${decoded_value#__SM_DATA_BASE64__:}"
    return 0
    ;;
  *)
    return 1
    ;;
  esac
}

read_defaults_json() {
  local read_mode="$1"
  local domain="$2"
  local key="$3"
  local type_line
  local type_name
  local raw_value
  local escaped_key
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
  data)
    local tmp
    local value_base64
    escaped_key="$(plist_escape_keypath "$key")"
    tmp="$(mktemp)"
    if ! "${defaults_cmd[@]}" export "$domain" "$tmp" >/dev/null 2>&1; then
      rm -f "$tmp"
      return 1
    fi
    if ! value_base64="$(plutil -extract "$escaped_key" raw -o - "$tmp" 2>/dev/null)"; then
      rm -f "$tmp"
      return 1
    fi
    rm -f "$tmp"
    json_escape_string "__SM_DATA_BASE64__:${value_base64}"
    ;;
  *)
    return 1
    ;;
  esac
}

read_defaults_keypath_json() {
  local read_mode="$1"
  local domain="$2"
  local keypath="$3"
  local defaults_cmd=(defaults)
  local type_name
  local value_json
  local value_base64
  local tmp

  if [[ "$read_mode" == "current_host" ]]; then
    defaults_cmd=(defaults -currentHost)
  fi

  tmp="$(mktemp)"
  if ! "${defaults_cmd[@]}" export "$domain" "$tmp" >/dev/null 2>&1; then
    rm -f "$tmp"
    return 1
  fi

  type_name="$(plutil -type "$keypath" "$tmp" 2>/dev/null || true)"
  if [[ -z "$type_name" ]]; then
    rm -f "$tmp"
    return 1
  fi

  case "$type_name" in
  bool)
    if ! value_json="$(plutil -extract "$keypath" raw -o - "$tmp" 2>/dev/null)"; then
      rm -f "$tmp"
      return 1
    fi
    rm -f "$tmp"
    case "$(printf '%s' "$value_json" | tr '[:upper:]' '[:lower:]')" in
    1 | true | yes)
      printf 'true'
      ;;
    *)
      printf 'false'
      ;;
    esac
    ;;
  integer | real)
    if ! value_json="$(plutil -extract "$keypath" raw -o - "$tmp" 2>/dev/null)"; then
      rm -f "$tmp"
      return 1
    fi
    rm -f "$tmp"
    printf '%s' "$value_json"
    ;;
  string)
    if ! value_json="$(plutil -extract "$keypath" raw -o - "$tmp" 2>/dev/null)"; then
      rm -f "$tmp"
      return 1
    fi
    rm -f "$tmp"
    json_escape_string "$value_json"
    ;;
  array | dictionary)
    if ! value_json="$(plutil -extract "$keypath" json -o - "$tmp" 2>/dev/null)"; then
      rm -f "$tmp"
      return 1
    fi
    rm -f "$tmp"
    printf '%s' "$value_json"
    ;;
  data)
    if ! value_base64="$(plutil -extract "$keypath" raw -o - "$tmp" 2>/dev/null)"; then
      rm -f "$tmp"
      return 1
    fi
    rm -f "$tmp"
    json_escape_string "__SM_DATA_BASE64__:${value_base64}"
    ;;
  *)
    rm -f "$tmp"
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
  local escaped_key
  local data_base64
  local written_json
  local tmp

  if [[ "$write_mode" == "current_host" ]]; then
    defaults_cmd=(defaults -currentHost)
  fi

  escaped_key="$(plist_escape_keypath "$key")"

  tmp="$(mktemp)"
  if ! "${defaults_cmd[@]}" export "$domain" "$tmp" >/dev/null 2>&1; then
    plutil -create xml1 "$tmp" >/dev/null
  fi

  if data_base64="$(extract_data_base64_from_json_string "$desired_json")"; then
    if plutil -type "$escaped_key" "$tmp" >/dev/null 2>&1; then
      plutil -replace "$escaped_key" -data "$data_base64" "$tmp" >/dev/null
    else
      plutil -insert "$escaped_key" -data "$data_base64" "$tmp" >/dev/null
    fi
  else
    if plutil -type "$escaped_key" "$tmp" >/dev/null 2>&1; then
      plutil -replace "$escaped_key" -json "$desired_json" "$tmp" >/dev/null
    else
      plutil -insert "$escaped_key" -json "$desired_json" "$tmp" >/dev/null
    fi
  fi

  "${defaults_cmd[@]}" import "$domain" "$tmp" >/dev/null
  rm -f "$tmp"

  if ! written_json="$(read_defaults_json "$write_mode" "$domain" "$key")"; then
    return 1
  fi

  [[ "$written_json" == "$desired_json" ]]
}

apply_defaults_keypath_json() {
  local write_mode="$1"
  local domain="$2"
  local keypath="$3"
  local desired_json="$4"
  local defaults_cmd=(defaults)
  local data_base64
  local written_json
  local tmp

  if [[ "$write_mode" == "current_host" ]]; then
    defaults_cmd=(defaults -currentHost)
  fi

  ensure_keypath_parent_dicts() {
    local plist_file="$1"
    local nested_keypath="$2"
    local parent_path=""
    local segment
    local parent_type
    IFS='.' read -r -a _keypath_segments <<<"$nested_keypath"

    if ((${#_keypath_segments[@]} < 2)); then
      return 0
    fi

    for ((i = 0; i < ${#_keypath_segments[@]} - 1; i++)); do
      segment="${_keypath_segments[$i]}"
      if [[ -z "$parent_path" ]]; then
        parent_path="$segment"
      else
        parent_path="${parent_path}.${segment}"
      fi

      parent_type="$(plutil -type "$parent_path" "$plist_file" 2>/dev/null || true)"
      if [[ -z "$parent_type" ]]; then
        if ! plutil -insert "$parent_path" -json '{}' "$plist_file" >/dev/null 2>&1; then
          return 1
        fi
        continue
      fi

      if [[ "$parent_type" != "dictionary" ]]; then
        return 1
      fi
    done
  }

  tmp="$(mktemp)"
  if ! "${defaults_cmd[@]}" export "$domain" "$tmp" >/dev/null 2>&1; then
    plutil -create xml1 "$tmp" >/dev/null
  fi

  if ! ensure_keypath_parent_dicts "$tmp" "$keypath"; then
    rm -f "$tmp"
    return 1
  fi

  if data_base64="$(extract_data_base64_from_json_string "$desired_json")"; then
    if plutil -type "$keypath" "$tmp" >/dev/null 2>&1; then
      plutil -replace "$keypath" -data "$data_base64" "$tmp" >/dev/null
    else
      plutil -insert "$keypath" -data "$data_base64" "$tmp" >/dev/null
    fi
  else
    if plutil -type "$keypath" "$tmp" >/dev/null 2>&1; then
      plutil -replace "$keypath" -json "$desired_json" "$tmp" >/dev/null
    else
      plutil -insert "$keypath" -json "$desired_json" "$tmp" >/dev/null
    fi
  fi

  "${defaults_cmd[@]}" import "$domain" "$tmp" >/dev/null
  rm -f "$tmp"

  if ! written_json="$(read_defaults_keypath_json "$write_mode" "$domain" "$keypath")"; then
    return 1
  fi

  [[ "$written_json" == "$desired_json" ]]
}

apply_timezone() {
  local desired_timezone_json="$1"
  local desired_timezone

  desired_timezone="$(json_unquote_string "$desired_timezone_json")"
  sudo systemsetup -settimezone "$desired_timezone" >/dev/null
}
