# Desktop Sentry source of truth

## Canonical project

This directory is the only active source of truth for Desktop Sentry from 2026-08-20
forward. Future product discussion documents, implementation, tests, version changes,
and Git history belong here.

Current release declaration: Desktop Sentry `2.0.7` build `27`.

Historical migration baseline: Desktop Sentry `1.1.0` build `11`.

The baseline was copied, not moved, from a retained local recovery tree outside this
repository. Its machine-specific path is intentionally not recorded in publishable
source.

The old source tree, dated Codex chat workspace, source archives, backup directory, and
installed application remain historical recovery material. They must not receive new
product development after this project is activated.

## What is authoritative

- Active application source: `Sources/`, `Resources/`, `Tools/`, `Tests/`, `build.sh`,
  and `Info.plist`
- Current operating and collaboration rules: `AGENTS.md`
- Runtime constraints, active product boundary, and maintenance knowledge: `HANDOFF.md`
- Status-labelled design history and rationale: `docs/product/`; historical approval or
  handoff text does not override the current rules above
- Version history after migration: Git commits, tags, and `CHANGELOG.md`

Generated `build/` content, `.app` bundles, zip archives, Finder metadata, user data,
and local backups are not source of truth.

## Version authority

For a release, these declarations must agree:

- `Info.plist` (`CFBundleShortVersionString` and `CFBundleVersion`)
- `README.md`
- `HANDOFF.md`
- `CHANGELOG.md`

The 2026-08-20 migration audit confirmed that the then-current source bundle and
installed app both reported `1.1.0` build `11`. That statement is historical evidence,
not the current release declaration.

The running app must expose the release version/build and current workbench generation.
Source-built previews must additionally expose their Git revision, dirty state, and
preview channel so distinct binaries do not share an indistinguishable visible identity.

## Retention rule

Do not delete or repurpose the former source tree or backup directory before
2026-09-20. That is only the earliest review date, not an automatic deletion date.
Review cleanup only after this canonical project has completed at least one verified
iteration and the user explicitly approves deletion.

## Remote status

As of 2026-08-29 this repository has a configured GitHub `origin`. Its presence does not
authorize a push. Every network write still requires explicit user approval and the
mandatory pre-push privacy gate in `AGENTS.md`; publishing, repository visibility,
licensing, notarization, and release uploads remain separate decisions.
