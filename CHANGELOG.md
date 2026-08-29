# Changelog

## 2.0.3 build 23 — aligned task list and perimeter-only drop glow

- Removed the native task-list scroller and its reserved right-side gutter.
- Aligned task cards with the composer while preserving both rounded edges during scrolling.
- Moved dropped-task feedback to the card perimeter and removed the inset blue frame.
- Added visible version/build/workbench identity so screenshots identify the exact binary.
- Kept release labels clean while source previews retain revision, dirty-state, and preview markers.

## 2.0.2 build 22 — custom calendar menu-bar glyph

- Replaced the generic SF Symbols calendar with the selected pure month-calendar design.
- Redrew the concept as a native 18pt template image with a header and six date cells.
- Preserved automatic light/dark menu-bar tinting and the fixed-width calendar status item.

## 2.0.1 build 21 — independent calendar status item

- Split the menu bar into an original prompt/menu item and a dedicated fixed-width calendar item.
- Kept calendar hover and direct left/right click opening off the prompt-copy interaction path.
- Froze an already-visible calendar panel so dynamic prompt-title feedback cannot move it.
- Synchronized system/light/dark selection across both SwiftUI content and the AppKit glass panel.

## 2.0.0 build 20 — calendar and todo workbench

- Promoted the fifth-generation calendar and todo workbench to the normal menu-bar hover route.
- Preserved first-generation task UUIDs and the complete legacy `data.json` envelope.
- Added an independent `task-calendar-v5.json` companion store for dates, descriptions, and reminders.
- Added a persistent system/light/dark appearance control inside the workbench.
- Fixed footer label overlap during rapid active/completed switching with a stable non-animated capsule.
- Preserved the native AppKit right-click menu, menu-bar hover behavior, and a reversible installed-app backup path.

## 1.1.0 build 11 — migration baseline

- Imported the verified Desktop Sentry source as the first local Git baseline.
- Preserved the native status-item menu anchoring fix and current DS icon resources.
- Added project governance, product discussion, validation, and source-of-truth documents.
- No application behavior or installed bundle was changed by the migration.

Pre-migration implementation history remains documented in `REVIEW.md` and historical
source archives. Git history begins at the verified build 11 baseline; older commits
are not fabricated.
