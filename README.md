# Mac Env Manager

Native SwiftUI macOS app for safely managing zsh/bash environment variables.

## What v1 Does

- Manages shell variables through `~/.mac-env-manager/env.sh`.
- Installs tool-owned source blocks in zsh/bash dotfiles.
- Supports import/takeover of simple `export NAME=value` assignments.
- Provides a structured PATH editor with duplicate and missing-path diagnostics.
- Shows diff previews before apply and creates timestamped backups first.
- Shows plaintext values by default, including likely secret variables.

Deferred by design: `launchctl`, project `.env`, multi-profile switching, App Store sandboxing, and automatic Terminal/iTerm refresh.

## Development

```sh
swift test
swift build
swift run MacEnvManager
```

For a Finder/Dock-style local app bundle:

```sh
chmod +x scripts/build-app.sh
scripts/build-app.sh
open ".build/Mac Env Manager.app"
```

For a zip package that can be sent to another Mac:

```sh
chmod +x scripts/package-app.sh
scripts/package-app.sh
```

The package is written to `dist/Mac Env Manager.zip`. Because this local build is not Apple Developer ID notarized, another Mac may show "Mac Env Manager.app is damaged and can't be opened". The zip includes `修复已损坏.command`, which runs:

```sh
sudo xattr -rd com.apple.quarantine "/Applications/Mac Env Manager.app"
```

The core tests use temporary fake home directories and do not write to the real home directory.
