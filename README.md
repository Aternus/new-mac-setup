# New Mac Setup Kit

This setup kit was generated on 2026-04-25.
It automates the safe, repeatable parts of the current Mac setup while avoiding
personal secrets and account-specific state.

Requires Apple Silicon: paths to Homebrew (`/opt/homebrew`) and miniforge are
hardcoded.

## Expected Coverage

Roughly 70-80% of the practical setup can be automated:

| Area                                         | Automation level | Notes                                                                                                                                                 |
|----------------------------------------------|------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------|
| Homebrew CLI tools and GUI apps              | High             | `Brewfile` installs work-appropriate defaults plus a personal/entertainment block; comment out anything that doesn't belong on an employer-owned Mac. |
| Shell and prompt                             | High             | Installs Oh My Zsh, plugins, `.zprofile`, `.zshrc`, Starship.                                                                                         |
| Node tooling                                 | Manual           | Installs `nvm` through Homebrew only; Node versions and global packages are manual.                                                                   |
| VS Code                                      | High             | Restores settings and extensions.                                                                                                                     |
| Ghostty config                               | High             | Copies the current terminal config exactly.                                                                                                           |
| macOS defaults                               | Medium-high      | Applies Finder, Dock, keyboard, screenshot, language, region, and timezone defaults.                                                                  |
| Dock layout                                  | Medium           | Uses `dockutil`; only adds apps already installed. JetBrains IDEs are not pinned automatically; pin them manually after Toolbox installs them.        |
| Login items                                  | Manual           | Let each app create its own login/background item during first run or from its settings.                                                              |
| JetBrains IDEs                               | Medium-low       | Toolbox install is automated; IDE installs and account sync are usually interactive.                                                                  |
| Docker                                       | Medium-low       | App install is automated; first launch, permissions, image/volume state are manual.                                                                   |
| Raycast, Rectangle Pro, LuLu                 | Medium-low       | App install is automated; permissions, licenses, rules, and tokens need review.                                                                       |
| Cloud storage                                | Low              | Apps install automatically; account sign-in and folder hydration are manual.                                                                          |
| SSH, npm, browser profiles, Keychain secrets | Manual           | Do not copy personal secrets blindly to an employer-owned Mac.                                                                                        |
| App Store apps                               | Manual           | `mas` was not present in the source analysis, so App Store app restore is not scripted.                                                               |

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

## Manual Checklist

The canonical manual checklist (GitHub auth, SSH key, Node tooling, app
permissions, JetBrains setup, etc.) is printed by `bootstrap.sh` at the end of
phase 5. That output is the source of truth — rerun `./bootstrap.sh` once all
phases are complete to print it again.

## Explicitly Not Automated

These are intentionally excluded:

- `~/.ssh/id_ed25519`
- `~/.npmrc`
- `~/.config/raycast/config.json`
- Personal Git identity from the old machine
- Browser profiles and saved sessions
- MacPass database location or passwords
- Docker images, containers, and volumes
- Personal Dropbox/Nextcloud state
- LuLu allow/block rules
- LinearMouse config
- Printer setup
