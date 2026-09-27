# Desktop Sentry product principles

## Product direction

Desktop Sentry is a quiet, local-first macOS menu-bar tool that shortens the path from
a reminder or task to an explicit user action. It should reduce friction without
becoming a second operating system, background surveillance tool, or mandatory AI layer.

## Stable core

- Predictable native macOS menu-bar behavior
- User-owned local tasks, prompts, categories, favorites, and settings
- Explicit clipboard actions with visible, reversible outcomes
- Local Skill metadata indexing with safe failure and clear source visibility
- Durable data loading, atomic saving, and compatible migration

## Optional modules

- Model-backed or semantic Skill recommendations
- Wallpaper, usage analytics, and richer history
- External AI-app automation and third-party integrations
- Broad clipboard monitoring or content capture

Optional modules must be independently enabled, disabled, replaced, or removed. Their
failure must not break the stable core.

## Product-decision rules

- A new idea starts as a candidate, not a command.
- Prefer the smallest reversible experiment that answers the important uncertainty.
- Record the user problem, beneficiaries, non-goals, maintenance cost, privacy impact,
  failure behavior, and acceptance criteria at a level proportional to the change. Routine
  work does not require a separate specification; follow the conversation rule in `AGENTS.md`.
- Reject features whose recurring complexity exceeds demonstrated user value.
- Prefer native macOS behavior over custom replicas when it reduces positioning,
  accessibility, focus, or lifecycle risk.
- Never claim a runtime or visual result that was not independently observed.

## Privacy rules

- No network access or conversation-history access is added without explicit scope and consent.
- Local Skill paths, tasks, prompts, clipboard history, and settings stay on-device by default.
- Public bug reports, logs, screenshots, and repositories must remove local paths and user data.
- Broader clipboard monitoring must be opt-in, narrow, visible, and easy to disable.

## Evidence standard

Important outcomes require evidence outside model self-assessment: compiler results,
tests, strict signature checks, runtime behavior, screenshots, or explicit human acceptance.
