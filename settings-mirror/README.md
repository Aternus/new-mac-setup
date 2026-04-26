# Settings Mirror (Personal Mac -> Work Mac)

This module captures a sanitized dump of macOS settings from your personal Mac and compares/applies those settings on another Mac with interactive prompts.

## Layout

- `settings-mirror/dump_current_settings.sh`: Generate a settings dump.
- `settings-mirror/compare_and_apply_settings.sh`: Compare/apply differences.
- `settings-mirror/manifest/settings_manifest.tsv`: Comprehensive non-PII settings manifest.
- `settings-mirror/dumps/current_laptop_settings_dump.tsv`: Default dump file.
- `settings-mirror/lib/common.sh`: Shared helper functions.

## Create or refresh the baseline dump

```sh
./settings-mirror/dump_current_settings.sh
```

Optional custom output file:

```sh
./settings-mirror/dump_current_settings.sh /path/to/my_dump.tsv
```

Optional verbose missing-key output:

```sh
VERBOSE_MISSING=1 ./settings-mirror/dump_current_settings.sh
```

## Compare and apply on the target Mac

```sh
./settings-mirror/compare_and_apply_settings.sh
```

Optional custom dump file:

```sh
./settings-mirror/compare_and_apply_settings.sh /path/to/my_dump.tsv
```

Notes:
- The compare script prompts before each change and reads confirmations from `/dev/tty` (run it in an interactive terminal).
- Timezone updates use `systemsetup` and may prompt for `sudo`.
- Both regular defaults and `defaults -currentHost` keys are supported.

Widget and desktop composition coverage:
- Included: Stage Manager widget visibility, desktop widget visibility toggles, and Finder desktop/icon composition dictionaries.
- Excluded on purpose: `com.apple.notificationcenterui.widgets` (binary widget instance payloads that may include personalized content).
