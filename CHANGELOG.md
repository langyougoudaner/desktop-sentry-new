# Changelog

## 2.0.5 build 25 — continuous calendar motion and clear completion feedback

- Replaced month-view swapping with a shared chronological week rail that scrolls vertically between adjacent months.
- Preserved the preferred day across repeated month changes and queued rapid keyboard or button navigation in order.
- Kept year, Today, month-navigation, and appearance controls visually active while the calendar is moving.
- Unified the 12-year and 12-month chooser layouts and retained date-style hover and selection feedback.
- Added an in-place checkmark, strike-through, blue acknowledgement, and stable fold-away animation for same-day completion and restore.
- Preserved the orange return-to-date flight for overdue tasks surfaced on Today while preventing premature list reflow.
- Hid the global overdue section outside Today so historical and future date pages show only their own tasks.

## 2.0.4 build 24 — overdue workflow and stable calendar interactions

- Surfaced overdue tasks on today's page and recent completed tasks inline on each day.
- Kept task identity and due dates stable across repeated moves, including moves back into the past.
- Made past-date moves immediately overdue while preserving reminders and completion ownership.
- Limited return-to-date completion flights to overdue tasks shown away from their historical date.
- Replaced whole-card date flips with a slower date-badge-only page turn.
- Restored the V5 deep-blue card selection treatment and reduced landing glow to a fixed two-point perimeter.
- Added focused state-machine, date-movement, reminder, interaction, persistence, and presentation checks.

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
