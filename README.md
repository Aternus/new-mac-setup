# New Mac Setup Kit

|              |                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
|-------------:|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Platform** | [![macOS](https://img.shields.io/badge/macOS-Sequoia%2B-000000?logo=apple&logoColor=white)](https://www.apple.com/macos/) [![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-M1%2FM2%2FM3%2FM4%2FM5-555555?logo=apple&logoColor=white)](https://support.apple.com/en-us/HT211814)                                                                                                                                                                                                                                                                                              |
|    **Stack** | [![Shell](https://img.shields.io/badge/shell-zsh-1A1A1A?logo=gnubash&logoColor=white)](https://www.zsh.org/) [![Homebrew](https://img.shields.io/badge/Homebrew-Brewfile-FBB040?logo=homebrew&logoColor=white)](https://brew.sh/) [![Starship](https://img.shields.io/badge/prompt-Starship-DD0B78?logo=starship&logoColor=white)](https://starship.rs/) [![Ghostty](https://img.shields.io/badge/terminal-Ghostty-7B68EE)](https://ghostty.org/) [![VS Code](https://img.shields.io/badge/VS%20Code-synced-007ACC?logo=visualstudiocode&logoColor=white)](https://code.visualstudio.com/) |
|  **Quality** | [![CI](https://github.com/Aternus/new-mac-setup/actions/workflows/validate-bootstrap.yml/badge.svg?branch=main)](https://github.com/Aternus/new-mac-setup/actions/workflows/validate-bootstrap.yml) [![Idempotent](https://img.shields.io/badge/safe%20to%20rerun-idempotent-2EA44F)](#getting-started) [![ShellCheck](https://img.shields.io/badge/linted-shellcheck-4EAA25?logo=gnubash&logoColor=white)](https://www.shellcheck.net/)                                                                                                                                                   |
|     **Meta** | [![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |

> **From boxed Mac to working dev machine in one command.**
> A phased, idempotent bootstrap script that installs your CLI tools, GUI apps,
> shell, prompt, terminal, editor, and macOS defaults — without leaking
> personal secrets or account state onto an employer-owned machine.

⭐ **If this saved you a day, please star the repo** — it helps other devs find
it.

**Why this kit?**

- 🚀 **One command, repeatable.** Run `./bootstrap.sh`, restart when prompted,
  rerun. Done.
- 🧱 **Phased & idempotent.** Five clearly numbered phases with checkpoints;
  completed steps are skipped on rerun.
- 🔒 **Secret-safe by default.** SSH keys, npm tokens, browser profiles, and
  Keychain entries are explicitly *not* copied.
- 🧰 **Curated, not bloated.** A practical Brewfile of CLI + GUI tools real
  developers use, with personal apps cleanly separated.
- 🍎 **Apple Silicon native.** Built and tested on M-series Macs (M1 → M5); paths
  to Homebrew (`/opt/homebrew`) and miniforge are hardcoded.

## Getting Started

On the new Mac, run the bootstrap once:

```sh
cd ~/new-mac-setup
./bootstrap.sh
```

The bootstrap keeps step state in `./.state`, so it is safe to rerun.
Completed steps are skipped.

Optionally override the hostname and Git identity when you run bootstrap:

```sh
MAC_HOSTNAME="your-mac-name" GIT_USER_NAME="Your Name" GIT_USER_EMAIL="you@example.com" ./bootstrap.sh
```

The default hostname is `mac-work`. Git identity can also be set later:

```sh
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

### Personal bin directory

The shell config honors an optional `PERSONAL_MACOS_LIB` environment variable.
If set to the absolute path of a directory containing personal executables,
that directory is prepended to `PATH`. Set it in `~/.zshenv` or elsewhere in
your shell environment; leave it unset to no-op.

```sh
export PERSONAL_MACOS_LIB="$HOME/Dev/bin"
```

### Phases

The bootstrap runs in five phases. After each restart checkpoint, restart the
Mac and rerun `./bootstrap.sh`. Completed steps are skipped.

**Phase 1 — Hostname**

- Sets the Mac `ComputerName` and `LocalHostName` from `MAC_HOSTNAME`,
  defaulting to `mac-work`.
- Restart checkpoint.

**Phase 2 — Xcode Command Line Tools**

- Installs Xcode Command Line Tools if missing. If the installer is launched,
  the script exits; finish the installer, then rerun `./bootstrap.sh`.
- Restart checkpoint.

**Phase 3 — Shell and Homebrew**

- Installs Oh My Zsh and custom plugins.
- Installs shell, Starship, and Ghostty configs.
- Installs Homebrew if missing.
- Restart checkpoint.

**Phase 4 — Packages and system defaults**

- Runs `brew bundle` against `Brewfile`.
- Configures Git LFS and line endings (and Git identity if `GIT_USER_NAME` /
  `GIT_USER_EMAIL` are set).
- Applies macOS defaults.
- Restart checkpoint.

**Phase 5 — Apps and finish**

- Installs VS Code settings and extensions.
- Applies the Dock layout.
- Prints the manual checklist, including the canonical list of apps to open for
  first-run permissions and sign-in.

Existing config files are moved aside with a `.backup.YYYYMMDDHHMMSS` suffix
when their contents differ.

Useful state commands:

```sh
./bootstrap.sh --status
./bootstrap.sh --reset
```

## Optional Steps

Install personal apps by uncommenting entries at the bottom of `Brewfile`, then:

```sh
brew bundle --file Brewfile
```

Mirror additional macOS settings from an existing machine:

```sh
./settings-mirror/dump_current_settings.sh
./settings-mirror/compare_and_apply_settings.sh
```

## Manual Checklist

The canonical manual checklist (GitHub auth, SSH key, Node tooling, app
permissions, JetBrains setup, etc.) is printed by `bootstrap.sh` at the end of
phase 5. That output is the source of truth — rerun `./bootstrap.sh` once all
phases are complete to print it again.

## Scope

What this kit covers, and what it deliberately leaves to you.

### What's Automated

Around 70–80% of a fresh Mac setup. Coverage by area:

| Area                                         | Automation level | Notes                                                                                                                                          |
|----------------------------------------------|------------------|------------------------------------------------------------------------------------------------------------------------------------------------|
| CLI tools and GUI apps                       | High             | `Brewfile` installs work-appropriate defaults plus a personal/entertainment block; comment out anything that doesn't belong.                   |
| Shell and prompt                             | High             | Installs Oh My Zsh, plugins, `.zprofile`, `.zshrc`, Starship and required fonts.                                                               |
| Ghostty config                               | High             | Copies the current terminal config exactly.                                                                                                    |
| Docker                                       | Medium           | App install and shell integration is automated; first launch, permissions, image/volume state are manual.                                      |
| Node tooling                                 | Low              | Installs `nvm` through Homebrew only and provides the required defaults in `.zshrc`; Node versions and global packages are manual.             |
| macOS defaults                               | Medium           | Applies Finder, Dock, keyboard, screenshot, language, region, and timezone defaults.                                                           |
| Dock layout                                  | Medium           | Uses `dockutil`; only adds apps already installed. JetBrains IDEs are not pinned automatically; pin them manually after Toolbox installs them. |
| VS Code                                      | High             | Restores settings and extensions.                                                                                                              |
| JetBrains IDEs                               | Low              | Toolbox install is automated; IDE installs and account sync are usually interactive.                                                           |
| Raycast, Rectangle Pro, LuLu                 | Low              | App install is automated; permissions, licenses, rules, and tokens need review.                                                                |
| Cloud storage                                | Low              | Apps install automatically; account sign-in and folder hydration are manual.                                                                   |
| Login items                                  | Manual           | Let each app create its own login/background item during first run or from its settings.                                                       |
| SSH, npm, browser profiles, Keychain secrets | Manual           | Do not copy personal secrets blindly to an employer-owned Mac.                                                                                 |
| App Store apps                               | Manual           | App Store app restore is not scripted. Install from AppStore after logging-in.                                                                 |

### What's Not Automated

Personal secrets and account-bound state — left to you on purpose:

- `~/.ssh/id_ed25519`
- `~/.npmrc`
- `~/.config/raycast/config.json`
- Personal Git identity from the old machine
- Browser profiles and saved sessions
- MacPass database location or passwords
- Docker images, containers, and volumes
- Personal Dropbox/Google Drive/Nextcloud state
- LuLu allow/block rules
- LinearMouse config
- Printer setup 😜
