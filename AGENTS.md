# Desktop Sentry agent rules

## Source and safety

This directory is the only active source tree. Before changing code, read
`SOURCE_OF_TRUTH.md` and only the relevant parts of `HANDOFF.md`. Preserve unrelated
working-tree changes and do not develop in old copies. Only one task may change product
code at a time.

Never delete, trash, prune, or permanently replace files, caches, backups, Git history,
untracked material, installed apps, or historical artifacts without the user's prior
approval naming the exact targets. General requests to organize, optimize, migrate, or
implement are not deletion approval.

Do not replace `/Applications/DesktopSentry.app`, alter login items, publish remotely,
or touch real user data unless the user explicitly requests that action. Any real-data
migration or app replacement must first have a verified backup and rollback path.

## Mandatory privacy gate before every remote push

Every GitHub push must run `Tools/PrePushPrivacyCheck.sh` and pass before any network
write. Never bypass the check with `--no-verify`. Inspect the exact outgoing commit,
not only the working tree. A push is blocked if it contains credentials, tokens,
private keys, machine-local absolute paths, real tasks, prompts, calendar metadata,
clipboard history, scanned Skill data or source paths, runtime JSON, build products,
backups, screenshots, recordings, or other user-derived artifacts.

Only source, sanitized documentation, tests, and reproducible resources may be pushed.
Fresh-install defaults must remain empty of tasks, prompts, quick-menu references,
clipboard history, scanned Skills, and personal menu-bar text. GitHub privacy settings
do not weaken this rule: private repositories require the same sanitization as public
ones. If the privacy check fails or the target/audience is uncertain, do not push.

## One mainline: discuss, then execute

The same task owns both product conversation and implementation. Do not redirect the
user to another task and do not require a product specification for normal work.

For each new product idea, change, or bug report, unless the user explicitly says
“直接做，不用先讨论”:

1. **First response — discuss only.** Talk naturally with the user. Explain what you
   think they mean, give your own product or technical judgment, surface only material
   concerns or alternatives, and propose a concrete direction. Do not edit files,
   create a specification, build, test, delegate, or begin implementation. End the
   response and wait for the user.
2. **After the user replies — execute.** Incorporate their reply and implement in this
   same task. Do not add another approval cycle unless a new ambiguity would materially
   change the result, architecture, data safety, cost, or irreversible risk.

This is one useful conversation turn, not a chain of gates. Use ordinary language;
avoid formal labels such as candidate, phase, approval, or acceptance criteria unless
they genuinely help the user. During execution, give concise progress updates without
repeating the discussion or these rules.

If implementation reveals a genuinely new product decision, pause once, explain it,
and wait for the user's answer. Questions and status requests that do not ask for a
change should simply be answered.

## Implementation and validation

After the discussion turn is complete, inspect the relevant code and current Git state,
then make the requested change. For visual work, show the earliest useful real preview
so the user can correct the direction before extensive polishing. Record material
deviations instead of silently changing the agreed direction.

Validate in proportion to risk: use focused checks for small changes and broader build,
smoke, signing, migration, or installation checks only when those boundaries are
actually involved. Record commands and results once.

## Project invariants

- There is no Xcode project or Swift Package manifest.
- Add each new production `.swift` file to `build.sh`'s explicit `SOURCES=(...)`.
- Synchronize `Info.plist`, `README.md`, `HANDOFF.md`, and `CHANGELOG.md` only for
  an actual release.
- Never commit builds, app/zip bundles, user data, credentials, clipboard history, or
  machine-local paths.
- GitHub, public release, notarization, or remote creation requires explicit approval.
- Preserve the stable core, optional-module boundaries, and data invariants in
  `HANDOFF.md`.
- Keep a visible binary identity: release version/build plus workbench generation; source
  previews additionally show Git revision and dirty state. Do not ship or compare distinct
  binaries under an indistinguishable visible identity.
