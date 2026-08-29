# Desktop Sentry

Desktop Sentry is a local-first macOS menu-bar app for calendars, todos, reusable
prompts, and local AI Skill indexes. It is written in Swift and SwiftUI and does not
require an Xcode project.

Current source release: **2.0.3 build 23**.

The app displays its exact version, build number, and calendar generation in Settings
and in the calendar footer. Source builds additionally display their Git revision and
preview status so bug reports can identify the exact binary.

## Features

- Native macOS menu-bar prompt and calendar entries
- Calendar and daily todo workbench with drag-to-date scheduling
- Local task descriptions, optional reminders, completion, restore, and deletion
- Reusable prompts and configurable quick-menu entries
- Local `SKILL.md` discovery, search, categories, and favorites
- System, light, and dark calendar appearances
- Optional launch at login and native macOS notification support
- Local JSON persistence with no account or cloud service

## Requirements

- macOS 14 or later
- Xcode Command Line Tools, including `swiftc`
- Git for cloning the repository

Install the command-line tools when needed:

```bash
xcode-select --install
```

## Quick install from source

The public project distributes source code only. Clone it and run the safe local
installer:

```bash
git clone https://github.com/langyougoudaner/desktop-sentry-new.git
cd desktop-sentry-new
bash install-from-source.sh
```

The installer builds the app, verifies its ad-hoc signature, copies it to
`~/Applications/DesktopSentry.app`, and opens it. It refuses to overwrite an existing
copy. To use another destination, set `DESKTOP_SENTRY_INSTALL_DIR` before running it.

Because the app is compiled locally, no Apple Developer certificate or downloaded
prebuilt binary is required.

## Build without installing

```bash
bash build.sh
open build/DesktopSentry.app
```

`build.sh` explicitly lists every production Swift file and invokes `swiftc` directly.
There is no `.xcodeproj`, Swift Package manifest, or workspace. New production Swift
files must also be added to the script's `SOURCES=(...)` list.

## Privacy

Desktop Sentry has no account, analytics, telemetry, or network service. Tasks,
prompts, clipboard history, settings, reminders, and discovered Skill metadata remain
on the Mac. See [PRIVACY.md](PRIVACY.md) for the complete data boundary.

The repository contains no runtime data, screenshots, local paths, credentials,
backups, or compiled application bundles.

## Project structure

```text
Sources/        Application source
Resources/      Reproducible app icon resources
Tests/          Standalone Swift smoke checks
Tools/          Build-time and privacy-check utilities
Info.plist      macOS application metadata
build.sh        Reproducible source build
```

## Source installation notes

- The app is a menu-bar utility (`LSUIElement=true`), so it does not appear in the Dock.
- Source builds use ad-hoc signing and are intended to be compiled on the destination
  Mac.
- Application data is stored outside the repository in the current user's Application
  Support directory.
- Build products, local data, screenshots, logs, archives, and credentials are excluded
  by `.gitignore` and the pre-push privacy check.

## License

Desktop Sentry is available under the [MIT License](LICENSE).
