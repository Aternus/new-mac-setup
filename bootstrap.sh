#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${SETUP_STATE_DIR:-$ROOT/.state}"

# Apps that need to be opened once to grant macOS permissions, sign in, or
# create their own login items. Keep this as the single source of truth.
FIRST_RUN_APPS=(
  "Docker Desktop"
  "Raycast"
  "Rectangle Pro"
  "LinearMouse"
  "LuLu"
  "Loopback"
  "Google Drive"
  "Nextcloud"
  "JetBrains Toolbox"
  "VS Code"
  "Cursor"
)

print_first_run_apps() {
  local app
  for app in "${FIRST_RUN_APPS[@]}"; do
    printf -- '- %s\n' "$app"
  done
}

log() {
  printf '\n==> %s\n' "$*"
}

state_path() {
  printf '%s/%s.done' "$STATE_DIR" "$1"
}

is_done() {
  [ -f "$(state_path "$1")" ]
}

mark_done() {
  mkdir -p "$STATE_DIR"
  date -u '+%Y-%m-%dT%H:%M:%SZ' > "$(state_path "$1")"
}

run_step() {
  local step="$1"
  local function_name="$2"

  if is_done "$step"; then
    printf 'Skipping %s; already completed.\n' "$step"
    return
  fi

  "$function_name"
  mark_done "$step"
}

# Single source of truth for the bootstrap pipeline. Each entry is
# "kind:name[:function]" where kind is "step" or "checkpoint". Both main() and
# show_status() iterate this list.
STEPS=(
  "step:hostname:configure_hostname"
  "checkpoint:restart_after_hostname"
  "step:command_line_tools:ensure_command_line_tools"
  "checkpoint:restart_after_command_line_tools"
  "step:oh_my_zsh:install_oh_my_zsh"
  "step:shell_configs:install_shell_configs"
  "step:homebrew:ensure_homebrew"
  "checkpoint:restart_after_homebrew"
  "step:brew_bundle:install_brew_bundle"
  "step:git_basics:configure_git_basics"
  "step:macos_defaults:apply_macos_defaults"
  "checkpoint:restart_after_install"
  "step:vscode:install_vscode"
  "step:dock:apply_dock_layout"
)

show_status() {
  mkdir -p "$STATE_DIR"
  printf 'State directory: %s\n\n' "$STATE_DIR"
  local entry kind name _fn
  for entry in "${STEPS[@]}"; do
    IFS=: read -r kind name _fn <<< "$entry"
    if is_done "$name"; then
      printf '[done] %s (%s)\n' "$name" "$(cat "$(state_path "$name")")"
    else
      printf '[todo] %s\n' "$name"
    fi
  done
}

reset_state() {
  rm -rf "$STATE_DIR"
  printf 'Removed setup state directory: %s\n' "$STATE_DIR"
}

backup_if_exists() {
  local path="$1"
  if [ -e "$path" ] || [ -L "$path" ]; then
    local backup="${path}.backup.$(date +%Y%m%d%H%M%S)"
    mv "$path" "$backup"
    printf 'Backed up %s to %s\n' "$path" "$backup"
  fi
}

copy_file() {
  local source="$1"
  local target="$2"
  mkdir -p "$(dirname "$target")"
  if [ -f "$target" ] && cmp -s "$source" "$target"; then
    return
  fi
  backup_if_exists "$target"
  install -m 0644 "$source" "$target"
}

ensure_command_line_tools() {
  log "Checking Xcode Command Line Tools"

  local install_marker="$STATE_DIR/command_line_tools.installed_this_run"

  if xcode-select -p >/dev/null 2>&1; then
    if [ -f "$install_marker" ]; then
      # CLT was installed by a previous run of this script; honor the restart.
      rm -f "$install_marker"
    else
      # CLT was already present before this kit ran; skip the post-CLT restart.
      mark_done restart_after_command_line_tools
    fi
    return
  fi

  date -u '+%Y-%m-%dT%H:%M:%SZ' > "$install_marker"
  xcode-select --install || true
  cat <<'EOF'

The Xcode Command Line Tools installer was opened. Finish that installer, then
rerun this script.
EOF
  exit 1
}

ensure_homebrew() {
  log "Installing Homebrew if needed"

  if command -v brew >/dev/null 2>&1; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    return
  fi

  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
}

install_brew_bundle() {
  log "Installing Homebrew formulae and casks"
  brew bundle --file "$ROOT/Brewfile"
}

install_oh_my_zsh() {
  log "Installing Oh My Zsh and custom plugins"

  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
  fi

  local custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  mkdir -p "$custom/plugins"

  if [ ! -d "$custom/plugins/fast-syntax-highlighting" ]; then
    git clone --depth=1 https://github.com/zdharma-continuum/fast-syntax-highlighting.git "$custom/plugins/fast-syntax-highlighting"
  fi

  if [ ! -d "$custom/plugins/conda-zsh-completion" ]; then
    git clone --depth=1 https://github.com/conda-incubator/conda-zsh-completion.git "$custom/plugins/conda-zsh-completion"
  fi
}

install_shell_configs() {
  log "Installing shell, prompt, and terminal configs"

  copy_file "$ROOT/config/zsh/zprofile" "$HOME/.zprofile"
  copy_file "$ROOT/config/zsh/zshrc" "$HOME/.zshrc"
  copy_file "$ROOT/config/starship/starship.toml" "$HOME/.config/starship.toml"
  copy_file "$ROOT/config/ghostty/config" "$HOME/.config/ghostty/config"
  mkdir -p "$HOME/Dev" "$HOME/.nvm"
}

configure_git_basics() {
  log "Configuring Git basics"

  if command -v git-lfs >/dev/null 2>&1; then
    git lfs install
  else
    printf 'git-lfs not installed; skipping git lfs install.\n'
  fi
  git config --global core.autocrlf input

  if [ -n "${GIT_USER_NAME:-}" ]; then
    git config --global user.name "$GIT_USER_NAME"
  fi

  if [ -n "${GIT_USER_EMAIL:-}" ]; then
    git config --global user.email "$GIT_USER_EMAIL"
  fi
}

configure_hostname() {
  log "Setting Mac hostname"

  local hostname="${MAC_HOSTNAME:-mac-work}"

  if [[ ! "$hostname" =~ ^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$ ]]; then
    printf 'Skipping hostname setup: MAC_HOSTNAME must contain only letters, numbers, and hyphens, and may not start or end with a hyphen.\n'
    return
  fi

  if [ "${#hostname}" -gt 63 ]; then
    printf 'Skipping hostname setup: MAC_HOSTNAME must be 63 characters or fewer.\n'
    return
  fi

  sudo scutil --set ComputerName "$hostname"
  sudo scutil --set LocalHostName "$hostname"
  sudo dscacheutil -flushcache
}

install_vscode() {
  log "Installing VS Code settings and extensions"

  local code_settings="$HOME/Library/Application Support/Code/User/settings.json"
  copy_file "$ROOT/vscode/settings.json" "$code_settings"

  if command -v code >/dev/null 2>&1; then
    while IFS= read -r extension; do
      [ -n "$extension" ] && code --install-extension "$extension" --force
    done < "$ROOT/vscode/extensions.txt"
  else
    printf 'VS Code CLI "code" is not available yet. Install it from VS Code and rerun this script.\n'
  fi
}

apply_macos_defaults() {
  log "Applying macOS defaults"
  "$ROOT/scripts/macos-defaults.sh"
}

apply_dock_layout() {
  log "Applying Dock layout"
  "$ROOT/scripts/dock.sh"
}

restart_checkpoint() {
  local checkpoint="$1"
  local requested_file="$STATE_DIR/${checkpoint}.requested"

  is_done "$checkpoint" && return

  if [ -f "$requested_file" ]; then
    mark_done "$checkpoint"
    rm -f "$requested_file"
    return
  fi

  date -u '+%Y-%m-%dT%H:%M:%SZ' > "$requested_file"
  printf '\nRestart the Mac, then rerun:\n  cd "%s"\n  ./bootstrap.sh\n' "$ROOT"
  exit 0
}

manual_checklist() {
  cat <<'EOF'

Bootstrap complete.

Remaining manual steps:

- Sign into your work Apple ID or managed Apple account, if applicable.

- Sign into GitHub:
    gh auth login
    gh auth setup-git --hostname github.com

- Generate a new work SSH key (do not copy the personal one):
    ssh-keygen -t ed25519 -C "you@example.com"

- Decide whether a work npm token is needed; do not copy the personal ~/.npmrc.

- Install Node versions and global JavaScript tooling:
    nvm install 22.22.2
    nvm install 18.20.8
    nvm alias default 22.22.2
    nvm use default
    corepack enable
    corepack prepare pnpm@10.33.0 --activate
    corepack prepare yarn@1.22.22 --activate

- Set Git identity if it was not provided during bootstrap:
    git config --global user.name "Your Name"
    git config --global user.email "you@example.com"

- Open each app from the first-run list below to approve helper/permission
  prompts and sign in.

- Enable launch-at-login inside each app where needed; avoid generic login
  items unless the app lacks its own setting.

- Grant Accessibility, Full Disk Access, Input Monitoring, Screen Recording,
  and network-filter permissions where macOS asks.

- Install required JetBrains IDEs from Toolbox and sign into the appropriate
  JetBrains account.

- Clone only work-relevant repos into ~/Dev.

- Run "mkcert -install" only if local HTTPS development needs it.

First-run apps to reopen:
EOF
  print_first_run_apps
}

main() {
  case "${1:-}" in
    --status)
      show_status
      exit 0
      ;;
    --reset)
      reset_state
      exit 0
      ;;
  esac

  mkdir -p "$STATE_DIR"

  local entry kind name fn
  for entry in "${STEPS[@]}"; do
    IFS=: read -r kind name fn <<< "$entry"
    case "$kind" in
      step)       run_step "$name" "$fn" ;;
      checkpoint) restart_checkpoint "$name" ;;
      *)          printf 'Unknown step kind: %s\n' "$kind" >&2; exit 1 ;;
    esac
  done

  manual_checklist
}

main "$@"
