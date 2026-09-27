# Migration baseline validation

> **Historical evidence:** the results below apply only to the 2026-08-20 migration
> baseline (`1.1.0` build `11`). They do not describe or validate the current release.

Date: 2026-08-20  
Baseline: Desktop Sentry `1.1.0` build `11`

## Pre-migration evidence

- The former active source matches the latest 2026-07-19 source backup except for
  generated `build/` content and Finder `.DS_Store` files.
- The former source build bundle and `/Applications/DesktopSentry.app` are byte-for-byte
  identical by recursive comparison.
- Both bundles passed strict deep code-signature verification.

## New-project verification

- Clean-source production build with `bash build.sh`: passed.
- The explicit `SOURCES=(...)` list contains the same 21 production Swift files found
  under `Sources/`: passed.
- Built bundle version: `1.1.0` build `11`.
- Built bundle size: approximately `2.4 MB`.
- Strict deep code-signature verification: passed.
- Recursive comparison against `/Applications/DesktopSentry.app`: no differences.
- Built executable SHA-256:
  `1fad148aa443b20e193e81ed28df5360c591f089982b94fd6a367daef4cb80b0`.
- Skill scan smoke test: passed.
  - `299` `SKILL.md` files found
  - `266` unique Skills
  - `33` duplicates merged
  - `0` unreadable
  - full scan `1.281s`
  - natural-language query returned `20` matches in `0.034s`

Smoke-test compile inputs included `TaskItem.swift`, `SkillItem.swift`, `AppData.swift`,
`SkillScanner.swift`, `SkillStore.swift`, and `Tests/SkillScanSmoke/main.swift`.

## Scope limitations

- Migration validation must not overwrite or relaunch `/Applications/DesktopSentry.app`.
- Visual menu placement, global hotkey conflicts, login-item behavior, and user-data
  migration require separate runtime or human acceptance checks.
