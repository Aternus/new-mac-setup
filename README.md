# New Mac Setup Kit

This setup kit was generated on 2026-04-25.
It automates the safe, repeatable parts of the current Mac setup while avoiding
personal secrets and account-specific state.

## Expected Coverage

Roughly 70-80% of the practical setup can be automated:

| Area                                         | Automation level | Notes                                                                                                 |
|----------------------------------------------|------------------|-------------------------------------------------------------------------------------------------------|
| Homebrew CLI tools and GUI apps              | High             | `Brewfile` installs work-appropriate defaults. Personal apps are commented out.                       |
| Shell and prompt                             | High             | Installs Oh My Zsh, plugins, `.zprofile`, `.zshrc`, Starship.                                         |
| Node tooling                                 | Manual           | Installs `nvm` through Homebrew only; Node versions and global packages are manual.                   |
| VS Code                                      | High             | Restores settings and extensions.                                                                     |
| Ghostty config                               | High             | Copies the current terminal config exactly.                                                           |
| macOS defaults                               | Medium-high      | Applies Finder, Dock, keyboard, screenshot, language, region, and timezone defaults.                  |
| Dock layout                                  | Medium           | Uses `dockutil`; only adds apps already installed. JetBrains IDEs appear after Toolbox installs them. |
| Login items                                  | Manual           | Let each app create its own login/background item during first run or from its settings.              |
| JetBrains IDEs                               | Medium-low       | Toolbox install is automated; IDE installs and account sync are usually interactive.                  |
| Docker                                       | Medium-low       | App install is automated; first launch, permissions, image/volume state are manual.                   |
| Raycast, Rectangle Pro, LuLu                 | Medium-low       | App install is automated; permissions, licenses, rules, and tokens need review.                       |
| Cloud storage                                | Low              | Apps install automatically; account sign-in and folder hydration are manual.                          |
| SSH, npm, browser profiles, Keychain secrets | Manual           | Do not copy personal secrets blindly to an employer-owned Mac.                                        |
| App Store apps                               | Manual           | `mas` was not present in the source analysis, so App Store app restore is not scripted.               |

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

The bootstrap runs in five phases:

- Phase 1 sets the hostname and stops at a restart checkpoint. Restart the Mac,
  then rerun `./bootstrap.sh`.
- Phase 2 checks for Xcode Command Line Tools and then stops at a restart
  checkpoint. If Xcode Command Line Tools are missing, the script opens Apple's
  installer and exits; finish that installer, then rerun `./bootstrap.sh`.
- Phase 3 runs after the second restart, installs Oh My Zsh and plugins, shell
  config, Starship, Ghostty config, and Homebrew, then stops at another restart
  checkpoint.
- Phase 4 runs after the third restart, installs Homebrew bundle packages, Git
  basics, and macOS defaults, then stops at another restart checkpoint.
- Phase 5 runs after the fourth restart and finishes VS Code settings and
  extensions, Dock layout, and the remaining manual checklist.

After phase 4, the script stops at another restart checkpoint. Before
restarting, open the apps that need first-run permissions where possible:

- Docker Desktop
- Raycast
- Rectangle Pro
- LinearMouse
- LuLu
- Loopback
- Google Drive
- Nextcloud
- JetBrains Toolbox
- VS Code and Cursor

Useful state commands:

```sh
./bootstrap.sh --status
./bootstrap.sh --reset
```

## What The Bootstrap Does

- Sets the Mac `ComputerName` and `LocalHostName` from `MAC_HOSTNAME`,
  defaulting to `mac-work`.
- Stops at a restart checkpoint after hostname setup.
- Installs Xcode Command Line Tools if needed.
- Stops at a restart checkpoint after the Xcode Command Line Tools step.
- Installs Oh My Zsh and custom plugins.
- Installs safe shell, Starship, and Ghostty configs.
- Installs Homebrew if needed.
- Stops at a restart checkpoint after Homebrew setup.
- Runs `brew bundle` against `Brewfile`.
- Configures Git LFS and line endings.
- Applies macOS defaults.
- Stops at a restart checkpoint after the core install.
- Installs VS Code settings and extensions after restart.
- Applies a Dock layout after restart.

Existing config files are moved aside with a `.backup.YYYYMMDDHHMMSS` suffix.

## Optional Steps

Install personal apps by uncommenting entries at the bottom of `Brewfile`, then:

```sh
brew bundle --file Brewfile
```

## Manual Checklist

Do these after the bootstrap:

- Sign into your work Apple ID or managed account, if applicable.
- Sign into GitHub:

```sh
gh auth login
gh auth setup-git --hostname github.com
```

- Generate a new work SSH key:

```sh
ssh-keygen -t ed25519 -C "you@example.com"
```

- Decide whether a work npm token is needed; do not copy the personal `.npmrc`.
- Install Node versions and global JavaScript tooling:

```sh
nvm install 22.22.2
nvm install 18.20.8
nvm alias default 22.22.2
nvm use default
corepack enable
corepack prepare pnpm@10.33.0 --activate
corepack prepare yarn@1.22.22 --activate
```

- Open Docker Desktop once and approve its helper/permission prompts.
- Open Raycast, Rectangle Pro, LinearMouse, LuLu, Google Drive, JetBrains
  Toolbox, VS Code, and Cursor once.
- Enable launch-at-login inside each app where needed; avoid adding generic
  login items manually unless the app lacks
  its own setting.
- Grant Accessibility, Full Disk Access, Input Monitoring, Screen Recording, and
  network-filter permissions where macOS
  asks.
- Install required JetBrains IDEs from Toolbox and sign into the appropriate
  JetBrains account.
- Clone only work-relevant repos into `~/Dev`.
- Run `mkcert -install` only if local HTTPS development needs it.

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
