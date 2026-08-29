# Privacy

Desktop Sentry is a local-first macOS application.

## Network boundary

The application does not include an account system, analytics, telemetry, advertising,
cloud synchronization, or application-owned network service. It does not upload tasks,
prompts, clipboard history, calendar metadata, settings, or Skill metadata.

## Local data

The application may store the following data in the current user's Application Support
directory:

- tasks and task calendar metadata;
- reusable prompts and quick-menu selections;
- settings and optional reminder configuration;
- a short clipboard history created by explicit copy actions;
- local Skill index metadata and configured directory paths.

These runtime files are excluded from this repository and must never be attached to a
public issue without manual review and redaction.

## Local file access

Desktop Sentry can inspect detected or user-configured local Skill directories for
`SKILL.md` files. The resulting index remains local. Removing a directory from the app
stops it from being included in future scans; the app does not upload directory contents.

## System integration

- Clipboard writes happen after an explicit copy action.
- Notifications are scheduled through macOS only when the user enables a reminder.
- Launch at login is controlled by the user through the app's Settings interface.

## Repository boundary

The public repository contains source code, tests, reproducible resources, and
documentation only. It excludes compiled apps, archives, screenshots, recordings,
credentials, backups, logs, runtime JSON, and machine-local absolute paths.
