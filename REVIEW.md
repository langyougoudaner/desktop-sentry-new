# Desktop Sentry - Architecture and adversarial review

Updated: 2026-07-18

> **Historical record:** this review describes the 2026-07 architecture and validation
> state. It is retained as evidence, not maintained as the current issue list. Use
> `HANDOFF.md` for the current runtime boundary and known risks.

## Product boundary

Desktop Sentry has five responsibilities:

1. Keep a short reminder or current prompt visible in the menu bar.
2. Copy one pinned prompt with a left click.
3. Expose tasks and selected prompts through a native contextual menu.
4. Manage tasks, prompts, shortcuts, and preferences in dedicated windows.
5. Index local AI Skills and shorten the path from a task to a usable invocation.

It does not copy closed-source applications. External products are behavioral references only; third-party code may be used only under a compatible license with attribution.

## Current architecture

- `AppCoordinator`: owns stores, services, panels, and action wiring.
- `TaskStore`, `PromptStore`, `SkillStore`, `SettingsStore`: domain state and mutations.
- `SkillScanner`: local `SKILL.md` discovery, metadata parsing, name deduplication, and source tracking.
- `StorageManager`: defensive JSON loading and atomic background writes.
- `ClipboardService`: pasteboard writes, sound, and prompt-copy history.
- `StatusBarController`: status item plus native `NSMenu` hierarchy.
- `PanelFactory`: search, quick-add, and standard settings windows.
- `SettingsView`, `SearchPanelView`: SwiftUI management interfaces.

## 2026-07-17 native menu change

- Removed the custom right-click `NSPanel` and `MenuPopoverView`.
- Replaced manual sizing, anchoring, glass, and outside-click monitors with `NSMenu`.
- Added native task, all-prompt, grouped-prompt, and pinned-prompt submenus.
- Kept the existing left-click action: copy the pinned prompt.
- Removed unnecessary app activation during a clipboard write.
- Settings now opens on the Basic page instead of an empty placeholder.

## Verification

- Optimized arm64 build succeeds with no compiler warnings.
- App bundle passes `codesign --verify --deep --strict`.
- Existing `AppData` fields and JSON migration behavior are unchanged.
- Removed SwiftUI panel symbols have no remaining source or build references.
- Version 1.1.0 bundles a validated multi-resolution `AppIcon.icns`; Finder verification shows the custom icon instead of the generic application placeholder.
- The stale `/Applications/DesktopSentry.app.backup-20260716` bundle was moved to the project backup directory, leaving one registered application copy.

## 2026-07-18 Skill search scrolling

- Search filters and the footer remain fixed; only the middle result list scrolls.
- Pointer hover changes the highlighted row without triggering programmatic scrolling.
- Up/down keyboard selection is the only path that scrolls a selected row into view.
- The native vertical scrollbar remains available and list-edge elasticity is disabled, preventing the window contents from appearing to move as one page.
- Search-panel teardown now orders the native panel out before releasing its content, so repeated open/close cycles do not leave transparent empty windows registered by AppKit.

## 2026-07-18 Superseded glass-object concept

- This intermediate concept removed the checklist clutter but incorrectly made a glass object the icon's subject.
- It was rejected after visual review and is not part of the current application resources.
- The following DS monogram revision supersedes it completely.

## 2026-07-18 DS monogram revision

- Reframed Liquid Glass as a subtle surface finish rather than the icon's literal subject.
- Reduced the composition to three elements: a solid native base, an exact DS monogram, and one amber status dot.
- Replaced raster-dependent lettering with deterministic SF Rounded typography and native AppKit drawing for consistent geometry at every icon size.
- Final color revision enlarges the monogram, uses a white satin base and red lettering, and limits glass treatment to thin highlights on the letters and amber status dot.
- Finder-scale refinement adds a shallow lower layer, upper-surface reflection, and clipped inner rim to the DS glyphs so their glass finish remains visible at 32-128 px without changing the three-element composition.

## 2026-07-19 native status-menu anchoring

- Removed the manually positioned `NSMenu.popUp` call from the status-bar button coordinate space.
- Right-click now temporarily attaches the menu to `NSStatusItem` and uses the button's native click path, allowing AppKit to place it below the menu bar and handle multiple displays, notches, and available-screen constraints.
- The native click is dispatched on the next main-run-loop turn so macOS 26's replicated status-item view observes the attached menu before opening it.
- The temporary menu is detached after `menuDidClose`, preserving the separate left-click copy action.

## 2026-07-17 Skill Sentry MVP

- Added local scanning for configurable Codex, Hermes, agent, workspace, and plugin-cache roots.
- Added name-based deduplication while preserving every source path and user category/favorite overrides.
- Added unified prompt/Skill search with category and favorite filters.
- Added native menu access to favorite Skills, search, rescan, and management.
- Reopening the already-running app now opens unified search as a fallback when a global shortcut conflicts.
- Hidden search panels are released and recreated on demand so the 221-row SwiftUI index does not remain resident after dismissal.
- Added one-Skill-per-task binding and combined invocation copying.
- Kept Skill contents, paths, favorites, and tasks local; no network or conversation-history access was added.

Real-machine smoke test:

- 229 `SKILL.md` files found; 221 unique Skills; 8 duplicates merged; 0 unreadable.
- All 221 Skills had a parsed description.
- Full scan: 0.92-1.02 seconds. Natural-language search over the index: about 0.03 seconds.
- Existing data decoded with 1 task and 12 prompts while missing Skill fields defaulted safely.
- Final runtime footprint: about 21 MB idle; about 35 MB with the Skill search UI loaded; 45 MB observed peak. Closing search no longer causes the earlier re-entrant allocation spike.

## Remaining risks

### Medium

- Global hotkeys are hard-coded. On the verification machine, simulated `Cmd-Shift-P` did not open search, while reopening the app did. A future settings revision should make shortcuts configurable and expose registration conflicts in the UI.
- The project is built by an explicit `swiftc` source list. New files can be silently omitted unless `build.sh` is updated.
- Search recommendation is lexical rather than semantic. It is intentionally local and deterministic for MVP, but vague task descriptions can produce weak rankings.
- `SettingsView.swift` now owns several management screens and is large. Split by domain when the next settings feature is added; doing it now would add migration churn without changing behavior.

### Low

- Prompt copy history is persisted locally. If broader clipboard monitoring is ever added, it must be opt-in and exclude sensitive applications and pasteboard types.
- The app is ad-hoc signed. Public distribution requires a stable Developer ID signature and notarization.
- Indexed Skill metadata includes local source paths in `data.json`. This remains on-device, but public bug reports should not include the file unredacted.
- Synchronous panel dismissal initially produced an AppKit layout-recursion warning during adversarial testing. Both `orderOut` and teardown now run after the key event and layout pass complete.

## Deliberately deferred

- Skill wallpaper, usage history, model-backed recommendation, and direct AI-app automation remain P1/P2.
- Wallpaper is not part of the current codebase, so the requirement's wallpaper acceptance checks do not apply to this MVP build.
