import AppKit
import Combine
import SwiftUI

/// Lightweight actions passed into views — replaces the old NotificationCenter
/// event bus. Every cross-object call is now a direct method invocation you can
/// grep for, instead of a magic string posted into the void.
struct AppActions {
    let openSearch: () -> Void
    let closeSearch: () -> Void
    let openQuickAdd: () -> Void
    let closeQuickAdd: () -> Void
    let openDeadlines: () -> Void
    let openSettings: () -> Void
    let copyPinned: () -> Void
    let quit: () -> Void
}

/// Central coordinator. Owns the three domain stores, the services, and the
/// window controllers. This is the single place that wires everything together
/// — replacing the old scattered NotificationCenter observers.
@MainActor
final class AppCoordinator {

    /// Validation-only in-memory previews. They are never enabled for normal
    /// app launches and deliberately bypass persistence and notifications.
    private let deadlinePreviewMode = ProcessInfo.processInfo.arguments.contains("--deadline-preview")
    private let calendarWorkbenchV2PreviewMode = ProcessInfo.processInfo.arguments.contains("--calendar-workbench-v2-preview")
    private let calendarWorkbenchV2LightAppearance = ProcessInfo.processInfo.arguments.contains("--calendar-workbench-v2-light")
    private let calendarWorkbenchV2DarkAppearance = ProcessInfo.processInfo.arguments.contains("--calendar-workbench-v2-dark")
    private let calendarWorkbenchV21PreviewMode = ProcessInfo.processInfo.arguments.contains("--calendar-workbench-v2-1-preview")
    private let calendarWorkbenchV21LightAppearance = ProcessInfo.processInfo.arguments.contains("--calendar-workbench-v2-1-light")
    private let calendarWorkbenchV21DarkAppearance = ProcessInfo.processInfo.arguments.contains("--calendar-workbench-v2-1-dark")
    private let calendarWorkbenchV21TodaySelected = ProcessInfo.processInfo.arguments.contains("--calendar-workbench-v2-1-today-selected")
    private let calendarWorkbenchV21NextSelected = ProcessInfo.processInfo.arguments.contains("--calendar-workbench-v2-1-next-selected")
    private let calendarWorkbenchV5PreviewMode = ProcessInfo.processInfo.arguments.contains("--calendar-workbench-v5-preview")
    private let calendarWorkbenchV5OpenAtLaunch = ProcessInfo.processInfo.arguments.contains("--calendar-workbench-v5-open")
    private let calendarWorkbenchV5LightAppearance = ProcessInfo.processInfo.arguments.contains("--calendar-workbench-v5-light")
    private let calendarWorkbenchV5DarkAppearance = ProcessInfo.processInfo.arguments.contains("--calendar-workbench-v5-dark")
    private let calendarWorkbenchV5LongList = ProcessInfo.processInfo.arguments.contains("--calendar-workbench-v5-long-list")

    private var isolatedPreviewMode: Bool {
        deadlinePreviewMode || calendarWorkbenchV2PreviewMode || calendarWorkbenchV21PreviewMode || calendarWorkbenchV5PreviewMode
    }

    // MARK: - Domain stores
    let taskStore = TaskStore()
    let promptStore = PromptStore()
    let skillStore = SkillStore()
    let settingsStore = SettingsStore()
    let deadlineStore = DeadlineStore()

    // MARK: - Services
    let feedback = FeedbackStore()
    /// Lazy so the isolated V2 preview does not even create the real
    /// Application Support directory while it is running.
    lazy var storage = StorageManager.shared
    lazy var deadlineStorage = DeadlineStorage.shared
    private let v5MetadataStore = V5TaskMetadataStore(fileURL: V5TaskMetadataStore.defaultFileURL)
    lazy var notificationScheduler: DeadlineNotificationScheduler = {
        let scheduler = DeadlineNotificationScheduler()
        scheduler.onOpenDeadline = { [weak self] id in
            self?.deadlineStore.setFocus(id: id)
            self?.openDeadlines()
        }
        return scheduler
    }()
    lazy var clipboard: ClipboardService =
        ClipboardService(promptStore: promptStore, settings: settingsStore, feedback: feedback)

    // MARK: - Controllers (created on start)
    private var statusBar: StatusBarController?
    private var hotKeys: HotKeyManager?
    private var searchPanel: NSPanel?
    private var searchPanelDismissObserver: NSObjectProtocol?
    private var quickAddPanel: NSPanel?
    private var deadlinePanel: NSPanel?
    private var calendarWorkbenchV2Panel: NSPanel?
    private var calendarWorkbenchV2Model: CalendarWorkbenchV2Model?
    private var calendarWorkbenchV21Panel: NSPanel?
    private var calendarWorkbenchV21Model: CalendarWorkbenchV21PreviewModel?
    private var calendarWorkbenchV21CleanPanel: NSPanel?
    private var calendarWorkbenchV21CleanModel: CalendarWorkbenchV21CleanModel?
    private var calendarWorkbenchV21CleanOutsideClickMonitor: Any?
    private var calendarWorkbenchV21CleanLocalClickMonitor: Any?
    private var calendarWorkbenchV5Panel: NSPanel?
    private var calendarWorkbenchV5Model: CalendarWorkbenchV5Model?
    private var calendarWorkbenchV5OutsideClickMonitor: Any?
    private var calendarWorkbenchV5LocalClickMonitor: Any?
    private var calendarWorkbenchV5AppearancePreference = V5AppearancePreference(
        rawValue: UserDefaults.standard.string(forKey: "calendarWorkbenchV5Appearance") ?? ""
    ) ?? .system
    private var calendarWorkbenchV21OutsideClickMonitor: Any?
    private var calendarWorkbenchV21LocalClickMonitor: Any?
    private var calendarHoverCloseWorkItem: DispatchWorkItem?
    private var calendarHoverDismissArmed = false
    private var calendarInteractionEngaged = false
    private var settingsPanel: NSPanel?

    private var saveWorkItem: DispatchWorkItem?
    private var deadlineSaveWorkItem: DispatchWorkItem?
    private var deadlineMidnightWorkItem: DispatchWorkItem?
    private var v5MetadataSaveWorkItem: DispatchWorkItem?
    private var v5TaskSubscription: AnyCancellable?
    private var v5Metadata: [UUID: V5TaskMetadata] = [:]
    private var appDataLoaded = false
    private var calendarWorkbenchV5OpenPending = false
    private let v5MetadataQueue = DispatchQueue(label: "com.desktopsentry.v5-metadata", qos: .utility)

    init() {
        wireSaves()
        load()
    }

    // MARK: - Save wiring

    private func wireSaves() {
        guard !isolatedPreviewMode else { return }
        taskStore.onSave = { [weak self] in self?.requestSave() }
        promptStore.onSave = { [weak self] in self?.requestSave() }
        skillStore.onSave = { [weak self] in self?.requestSave() }
        settingsStore.onSave = { [weak self] in self?.requestSave() }
        clipboard.onSave = { [weak self] in self?.requestSave() }
        if !isolatedPreviewMode {
            deadlineStore.onSave = { [weak self] in self?.requestDeadlineSave() }
            deadlineStore.onScheduleChanged = { [weak self] in
                guard let self else { return }
                self.notificationScheduler.sync(deadlines: self.deadlineStore.deadlines,
                                                requestAuthorizationIfNeeded: true)
            }
        }
    }

    // MARK: - Load / Save

    private func load() {
        if isolatedPreviewMode {
            if deadlinePreviewMode {
                deadlineStore.setDeadlines(DeadlinePreviewSamples.make())
            }
            return
        }
        storage.load { [weak self] data in
            guard let self else { return }
            self.taskStore.setTasks(data.tasks)
            self.promptStore.setPrompts(data.prompts, quickMenuPromptIDs: data.quickMenuPromptIDs)
            self.skillStore.setState(skills: data.skills,
                                     directories: data.skillDirectories,
                                     lastScanDate: data.skillLastScanDate)
            self.settingsStore.apply(data)
            self.clipboard.setHistory(data.copyHistory)
            self.skillStore.scan()
            let loadedMetadata = self.v5MetadataStore.loadRecoveringCorruption()
            let mergedMetadata = V5TaskMetadataMigration.merge(
                tasks: data.tasks,
                existing: loadedMetadata,
                defaultDate: Date(),
                calendar: .autoupdatingCurrent
            )
            self.v5Metadata = mergedMetadata
            if mergedMetadata != loadedMetadata {
                self.requestV5MetadataSave(mergedMetadata)
            }
            self.appDataLoaded = true
            self.wireV5TaskSynchronization()
            if self.calendarWorkbenchV5OpenPending {
                self.calendarWorkbenchV5OpenPending = false
                self.openCalendarWorkbenchV5()
            }
            self.deadlineStorage.load { [weak self] deadlines in
                guard let self else { return }
                self.deadlineStore.setDeadlines(deadlines)
                self.notificationScheduler.sync(deadlines: deadlines,
                                                requestAuthorizationIfNeeded: false)
            }
        }
    }

    func requestSave() {
        saveWorkItem?.cancel()
        let snapshot = makeSnapshot()
        let work = DispatchWorkItem { [weak self] in self?.storage.save(snapshot) }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    func saveImmediately() {
        guard !isolatedPreviewMode else { return }
        saveWorkItem?.cancel(); saveWorkItem = nil
        storage.save(makeSnapshot())
        deadlineSaveWorkItem?.cancel(); deadlineSaveWorkItem = nil
        deadlineStorage.save(deadlineStore.deadlines)
        v5MetadataSaveWorkItem?.cancel(); v5MetadataSaveWorkItem = nil
        try? v5MetadataStore.save(v5Metadata)
    }

    private func requestDeadlineSave() {
        guard !deadlinePreviewMode else { return }
        deadlineSaveWorkItem?.cancel()
        let snapshot = deadlineStore.deadlines
        let work = DispatchWorkItem { [weak self] in self?.deadlineStorage.save(snapshot) }
        deadlineSaveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    private func requestV5MetadataSave(_ metadata: [UUID: V5TaskMetadata]) {
        guard !isolatedPreviewMode else { return }
        v5MetadataSaveWorkItem?.cancel()
        let store = v5MetadataStore
        let queue = v5MetadataQueue
        let work = DispatchWorkItem {
            queue.async {
                do { try store.save(metadata) }
                catch { NSLog("[AppCoordinator] V5 metadata save failed: %@", error.localizedDescription) }
            }
        }
        v5MetadataSaveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    private func wireV5TaskSynchronization() {
        guard v5TaskSubscription == nil else { return }
        v5TaskSubscription = taskStore.$tasks.sink { [weak self] tasks in
            guard let self, self.appDataLoaded else { return }
            let merged = V5TaskMetadataMigration.merge(
                tasks: tasks,
                existing: self.v5Metadata,
                defaultDate: Date(),
                calendar: .autoupdatingCurrent
            )
            if merged != self.v5Metadata {
                self.v5Metadata = merged
                self.requestV5MetadataSave(merged)
            }
            self.calendarWorkbenchV5Model?.replaceLegacyTasks(tasks, metadata: merged)
        }
    }

    private func makeSnapshot() -> AppData {
        AppData(
            tasks: taskStore.tasks,
            prompts: promptStore.prompts,
            maxMenuBarChars: settingsStore.maxMenuBarChars,
            soundEnabled: settingsStore.soundEnabled,
            soundEffectName: settingsStore.soundEffectName,
            launchAtLogin: settingsStore.launchAtLogin,
            autoSwitchOnCopy: settingsStore.autoSwitchOnCopy,
            titleEmojiEnabled: settingsStore.titleEmojiEnabled,
            titleCustomText: settingsStore.titleCustomText,
            titleShowTaskCount: settingsStore.titleShowTaskCount,
            quickMenuPromptIDs: promptStore.quickMenuPromptIDs,
            copyHistory: clipboard.copyHistory,
            skills: skillStore.skills,
            skillDirectories: skillStore.directories,
            skillLastScanDate: skillStore.lastScanDate
        )
    }

    // MARK: - Menu-bar title (delegated to pure TitleBuilder)

    var menuBarTitle: String {
        TitleBuilder.build(
            tasks: taskStore.tasks,
            prompts: promptStore.prompts,
            maxChars: settingsStore.maxMenuBarChars,
            emojiEnabled: settingsStore.titleEmojiEnabled,
            customText: settingsStore.titleCustomText,
            showTaskCount: settingsStore.titleShowTaskCount
        )
    }

    var menuBarDeadlineTitle: String? {
        guard let deadline = deadlineStore.focusedDeadline else { return nil }
        let state = deadlineStore.state(for: deadline).label
        let title = deadline.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return state }
        let shortened = title.count > 12 ? String(title.prefix(12)) + "…" : title
        return "\(state) \(shortened)"
    }

    // MARK: - Start

    func start() {
        statusBar = StatusBarController(coordinator: self)
        if !isolatedPreviewMode {
            _ = notificationScheduler
            scheduleDeadlineMidnightRefresh()
        }
        if calendarWorkbenchV2PreviewMode {
            DispatchQueue.main.async { [weak self] in self?.openCalendarWorkbenchV2() }
        }
        if calendarWorkbenchV21PreviewMode {
            DispatchQueue.main.async { [weak self] in self?.openCalendarWorkbenchV21Clean() }
        }
        if calendarWorkbenchV5PreviewMode && calendarWorkbenchV5OpenAtLaunch {
            DispatchQueue.main.async { [weak self] in
                self?.calendarInteractionEngaged = true
                self?.openCalendarWorkbenchV5()
            }
        }
        if !isolatedPreviewMode {
            hotKeys = HotKeyManager(
                onSearch: { [weak self] in self?.openSearch() },
                onQuickAdd: { [weak self] in self?.openQuickAdd() },
                onCyclePinned: { [weak self] in self?.promptStore.cyclePinnedPrompt() }
            )
        }
        // Never mutate the system login item during launch. The settings store
        // reads macOS as the source of truth and only changes it after an
        // explicit user toggle.
        if !isolatedPreviewMode { settingsStore.refreshLoginItemStatus() }
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.saveImmediately() }
        }
    }

    private func scheduleDeadlineMidnightRefresh() {
        deadlineMidnightWorkItem?.cancel()
        let calendar = Calendar.autoupdatingCurrent
        let now = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
            ?? now.addingTimeInterval(24 * 3600)
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.deadlineStore.refreshReferenceDay()
            self.calendarWorkbenchV5Model?.refreshToday()
            self.scheduleDeadlineMidnightRefresh()
        }
        deadlineMidnightWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + max(1, tomorrow.timeIntervalSince(now) + 1), execute: work)
    }

    // MARK: - Actions facade

    var actions: AppActions {
        AppActions(
            openSearch:   { [weak self] in self?.openSearch() },
            closeSearch:  { [weak self] in self?.closeSearch() },
            openQuickAdd: { [weak self] in self?.openQuickAdd() },
            closeQuickAdd:{ [weak self] in self?.closeQuickAdd() },
            openDeadlines:{ [weak self] in self?.openDeadlines() },
            openSettings: { [weak self] in self?.openSettings() },
            copyPinned:   { [weak self] in self?.clipboard.copyPinned() },
            quit:         { NSApp.terminate(nil) }
        )
    }

    // MARK: - Panels

    func openSearch() {
        if searchPanel == nil {
            let view = SearchPanelView(promptStore: promptStore, skillStore: skillStore, clipboard: clipboard,
                                       feedback: feedback, actions: actions)
            let panel = PanelFactory.makeGlassPanel(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 430),
                contentView: NSHostingView(rootView: view),
                movableByWindowBackground: false
            )
            searchPanel = panel
            searchPanelDismissObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
            ) { [weak self, weak panel] _ in
                DispatchQueue.main.async {
                    guard let self, self.searchPanel === panel else { return }
                    self.releaseSearchPanel()
                }
            }
        }
        searchPanel?.center()
        searchPanel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeSearch() {
        guard let panel = searchPanel else { return }
        DispatchQueue.main.async { [weak self, weak panel] in
            guard let self, self.searchPanel === panel else { return }
            panel?.orderOut(nil)
            DispatchQueue.main.async { [weak self, weak panel] in
                guard let self, self.searchPanel === panel else { return }
                self.releaseSearchPanel()
            }
        }
    }

    private func releaseSearchPanel() {
        if let observer = searchPanelDismissObserver {
            NotificationCenter.default.removeObserver(observer)
            searchPanelDismissObserver = nil
        }
        let panel = searchPanel
        searchPanel = nil
        panel?.orderOut(nil)
        panel?.contentView = nil
    }

    func openQuickAdd() {
        if quickAddPanel == nil {
            let view = QuickAddTaskView(taskStore: taskStore, actions: actions)
            quickAddPanel = PanelFactory.makeGlassPanel(
                contentRect: NSRect(x: 0, y: 0, width: 320, height: 56),
                contentView: NSHostingView(rootView: view)
            )
        }
        if let screen = NSScreen.main {
            let x = (screen.frame.width - 320) / 2
            let y = screen.frame.height - 120
            quickAddPanel?.setFrameOrigin(NSPoint(x: x, y: y))
        }
        quickAddPanel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeQuickAdd() { quickAddPanel?.orderOut(nil) }

    func calendarPointerEntered() {
        calendarHoverCloseWorkItem?.cancel()
        calendarHoverCloseWorkItem = nil
    }

    func calendarPanelContainsScreenPoint(_ point: NSPoint) -> Bool {
        if calendarWorkbenchV5Panel?.isVisible == true {
            return calendarWorkbenchV5Panel?.isVisible == true
                && calendarWorkbenchV5Panel?.frame.contains(point) == true
        }
        if calendarWorkbenchV21PreviewMode {
            return (calendarWorkbenchV21CleanPanel?.isVisible == true
                    && calendarWorkbenchV21CleanPanel?.frame.contains(point) == true)
                || (calendarWorkbenchV21Panel?.isVisible == true
                    && calendarWorkbenchV21Panel?.frame.contains(point) == true)
        }
        return deadlinePanel?.isVisible == true
            && deadlinePanel?.frame.contains(point) == true
    }

    func calendarStatusPointerEntered() {
        calendarHoverDismissArmed = true
        calendarPointerEntered()
    }

    func calendarPointerExited() {
        guard calendarHoverDismissArmed, !calendarInteractionEngaged else { return }
        calendarHoverCloseWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.calendarInteractionEngaged else { return }
            self.calendarHoverDismissArmed = false
            self.dismissCalendarWorkbench(animated: true)
        }
        calendarHoverCloseWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    func openDeadlines() {
        calendarPointerEntered()
        if calendarWorkbenchV5PreviewMode {
            openCalendarWorkbenchV5()
            return
        }
        if calendarWorkbenchV21PreviewMode {
            openCalendarWorkbenchV21Clean()
            return
        }
        if calendarWorkbenchV2PreviewMode {
            openCalendarWorkbenchV2()
            return
        }
        openCalendarWorkbenchV5()
        return
        /* Historical Deadline workbench retained for recovery; V5 is the
           active product route from this point forward.
        if deadlinePanel == nil {
            let view = DeadlinePanelView(store: deadlineStore) { [weak self] in
                self?.deadlinePanel?.orderOut(nil)
            }
            deadlinePanel = PanelFactory.makeDeadlinePanel(
                contentRect: NSRect(x: 0, y: 0, width: 820, height: 560),
                contentView: NSHostingView(rootView: view)
            )
        }

        guard let panel = deadlinePanel else { return }
        let hasSavedFrame = UserDefaults.standard.string(forKey: "NSWindow Frame DesktopSentryDeadlinePanel") != nil
        if !hasSavedFrame {
            if let anchor = statusBar?.deadlineAnchorRect,
               let screen = NSScreen.screens.first(where: { $0.frame.intersects(anchor) }) ?? NSScreen.main {
                let visible = screen.visibleFrame
                let x = min(max(anchor.midX - panel.frame.width / 2, visible.minX + 8),
                            visible.maxX - panel.frame.width - 8)
                let y = max(anchor.minY - panel.frame.height - 8, visible.minY + 8)
                panel.setFrameOrigin(NSPoint(x: x, y: y))
            } else {
                panel.center()
            }
        }
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        NSApp.activate(ignoringOtherApps: true)
        */
    }

    /// A direct click on the dedicated calendar status item upgrades a hover
    /// preview into a pinned interaction without changing the panel frame.
    func toggleCalendarFromStatusItem() {
        calendarPointerEntered()
        calendarHoverDismissArmed = false
        calendarInteractionEngaged = true
        openDeadlines()
    }

    func closeDeadlines() {
        deadlinePanel?.orderOut(nil)
        calendarWorkbenchV2Panel?.orderOut(nil)
        calendarWorkbenchV21CleanPanel?.orderOut(nil)
        dismissCalendarWorkbench(animated: true)
    }

    func prepareForStatusMenu() {
        calendarHoverCloseWorkItem?.cancel()
        calendarHoverCloseWorkItem = nil
        calendarHoverDismissArmed = false
        calendarInteractionEngaged = false
        deadlinePanel?.orderOut(nil)
        calendarWorkbenchV2Panel?.orderOut(nil)
        calendarWorkbenchV21CleanPanel?.orderOut(nil)
        dismissCalendarWorkbench(animated: false)
    }

    private func engageCalendarWorkbenchV21() {
        calendarInteractionEngaged = true
        calendarHoverCloseWorkItem?.cancel()
        calendarHoverCloseWorkItem = nil
    }

    private func dismissCalendarWorkbenchV21(animated: Bool) {
        guard let panel = calendarWorkbenchV21Panel, panel.isVisible else {
            calendarInteractionEngaged = false
            calendarHoverDismissArmed = false
            return
        }
        calendarHoverCloseWorkItem?.cancel()
        let finish = { [weak self, weak panel] in
            panel?.orderOut(nil)
            panel?.alphaValue = 1
            self?.calendarInteractionEngaged = false
            self?.calendarHoverDismissArmed = false
        }
        guard animated else {
            finish()
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 0
        } completionHandler: {
            DispatchQueue.main.async(execute: finish)
        }
    }

    private func dismissCalendarWorkbench(animated: Bool) {
        if calendarWorkbenchV5Panel != nil {
            dismissCalendarWorkbenchV5(animated: animated)
        } else {
            dismissCalendarWorkbenchV21(animated: animated)
        }
    }

    private func dismissCalendarWorkbenchV5(animated: Bool) {
        guard let panel = calendarWorkbenchV5Panel, panel.isVisible else {
            calendarInteractionEngaged = false
            calendarHoverDismissArmed = false
            return
        }
        calendarHoverCloseWorkItem?.cancel()
        let finish = { [weak self, weak panel] in
            panel?.orderOut(nil)
            panel?.alphaValue = 1
            self?.calendarInteractionEngaged = false
            self?.calendarHoverDismissArmed = false
        }
        guard animated else { finish(); return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 0
        } completionHandler: { DispatchQueue.main.async(execute: finish) }
    }

    private func openCalendarWorkbenchV5() {
        if !isolatedPreviewMode, !appDataLoaded {
            calendarWorkbenchV5OpenPending = true
            return
        }
        if calendarWorkbenchV5Panel == nil {
            let model: CalendarWorkbenchV5Model
            if calendarWorkbenchV5PreviewMode {
                model = CalendarWorkbenchV5Model(longList: calendarWorkbenchV5LongList)
            } else {
                model = CalendarWorkbenchV5Model(tasks: taskStore.tasks, metadata: v5Metadata)
                model.onMutation = { [weak self] tasks, metadata in
                    guard let self else { return }
                    self.v5Metadata = metadata
                    self.taskStore.setTasks(tasks)
                    self.requestSave()
                    self.requestV5MetadataSave(metadata)
                }
            }
            calendarWorkbenchV5Model = model
            let view = CalendarWorkbenchV5View(
                model: model,
                onAppearanceChange: { [weak self] preference in
                    self?.applyCalendarWorkbenchV5Appearance(preference)
                },
                onClose: { [weak self] in self?.dismissCalendarWorkbenchV5(animated: true) }
            )
            let panel = PanelFactory.makeCalendarWorkbenchV21Panel(
                contentRect: NSRect(x: 0, y: 0, width: 1060, height: 660),
                contentView: NSHostingView(rootView: view),
                onPointerEntered: { [weak self] in self?.calendarPointerEntered() },
                onPointerExited: { [weak self] in self?.calendarPointerExited() }
            )
            calendarWorkbenchV5Panel = panel
            applyCalendarWorkbenchV5Appearance(calendarWorkbenchV5AppearancePreference)

            calendarWorkbenchV5OutsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self, weak panel] _ in
                DispatchQueue.main.async {
                    guard let self, self.calendarWorkbenchV5Panel === panel,
                          let panel, panel.isVisible,
                          !panel.frame.contains(NSEvent.mouseLocation) else { return }
                    self.dismissCalendarWorkbenchV5(animated: true)
                }
            }
            calendarWorkbenchV5LocalClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self, weak panel] event in
                guard let self, self.calendarWorkbenchV5Panel === panel, panel?.isVisible == true else { return event }
                if let anchor = self.statusBar?.calendarAnchorRect,
                   anchor.insetBy(dx: -2, dy: -2).contains(NSEvent.mouseLocation) { return event }
                if event.window != nil {
                    self.engageCalendarWorkbenchV21()
                }
                return event
            }
        }

        calendarWorkbenchV5Model?.refreshToday()
        guard let panel = calendarWorkbenchV5Panel else { return }
        let shouldReposition = CalendarPanelPresentationPolicy.shouldReposition(isVisible: panel.isVisible)
        if shouldReposition {
            panel.alphaValue = 1
            if let anchor = statusBar?.calendarAnchorRect,
               let screen = NSScreen.screens.first(where: { $0.frame.intersects(anchor) }) ?? NSScreen.main {
                let frame = CalendarPanelPositioning.frame(
                    panelSize: panel.frame.size,
                    anchor: anchor,
                    visibleFrame: screen.visibleFrame,
                    menuBarGap: 3
                )
                panel.setFrameOrigin(frame.origin)
            } else if let screen = NSScreen.main {
                let visible = screen.visibleFrame
                let fallbackAnchor = NSRect(x: visible.midX, y: visible.maxY, width: 0, height: 0)
                panel.setFrameOrigin(CalendarPanelPositioning.frame(
                    panelSize: panel.frame.size,
                    anchor: fallbackAnchor,
                    visibleFrame: visible,
                    menuBarGap: 3
                ).origin)
            }
        }
        panel.makeKeyAndOrderFront(nil)
        panel.orderFront(nil)
    }

    private func applyCalendarWorkbenchV5Appearance(_ preference: V5AppearancePreference) {
        calendarWorkbenchV5AppearancePreference = preference
        guard let panel = calendarWorkbenchV5Panel else { return }

        let effectiveAppearance: V5PanelAppearance
        if calendarWorkbenchV5LightAppearance { effectiveAppearance = .aqua }
        else if calendarWorkbenchV5DarkAppearance { effectiveAppearance = .darkAqua }
        else { effectiveAppearance = preference.panelAppearance }

        switch effectiveAppearance {
        case .inherited: panel.appearance = nil
        case .aqua: panel.appearance = NSAppearance(named: .aqua)
        case .darkAqua: panel.appearance = NSAppearance(named: .darkAqua)
        }
        panel.contentView?.needsDisplay = true
    }

    /// Presents the V2 workbench using only an in-memory model. No shared
    /// DeadlineStore, storage, notification scheduler, or user settings are
    /// consulted by this route.
    private func openCalendarWorkbenchV2() {
        if calendarWorkbenchV2Panel == nil {
            let model = CalendarWorkbenchV2Model()
            calendarWorkbenchV2Model = model
            let view = CalendarWorkbenchV2View(model: model) { [weak self] in
                self?.calendarWorkbenchV2Panel?.orderOut(nil)
            }
            let panel = PanelFactory.makeCalendarWorkbenchPanel(
                contentRect: NSRect(x: 0, y: 0, width: 1040, height: 700),
                contentView: NSHostingView(rootView: view)
            )
            if calendarWorkbenchV2LightAppearance {
                panel.appearance = NSAppearance(named: .aqua)
            } else if calendarWorkbenchV2DarkAppearance {
                panel.appearance = NSAppearance(named: .darkAqua)
            }
            calendarWorkbenchV2Panel = panel
        }

        guard let panel = calendarWorkbenchV2Panel else { return }
        if let anchor = statusBar?.deadlineAnchorRect,
           let screen = NSScreen.screens.first(where: { $0.frame.intersects(anchor) }) ?? NSScreen.main {
            let visible = screen.visibleFrame
            let x = min(max(anchor.midX - panel.frame.width / 2, visible.minX + 8),
                        visible.maxX - panel.frame.width - 8)
            let y = max(anchor.minY - panel.frame.height - 8, visible.minY + 8)
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            panel.center()
        }
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Isolated Phase 1 route for SPEC-003. It uses a fresh V2.1 model and
    /// view so the rejected V2 implementation remains intact as evidence.
    private func openCalendarWorkbenchV21() {
        if calendarWorkbenchV21Panel == nil {
            let initialSelectionOffset: Int?
            if calendarWorkbenchV21TodaySelected {
                initialSelectionOffset = 0
            } else if ProcessInfo.processInfo.arguments.contains(
                "--calendar-workbench-v2-1-festival-selected"
            ) {
                initialSelectionOffset = 5
            } else if calendarWorkbenchV21NextSelected {
                initialSelectionOffset = 1
            } else {
                initialSelectionOffset = nil
            }
            let previewNow: Date
            if ProcessInfo.processInfo.arguments.contains("--calendar-workbench-v2-1-september-preview") {
                previewNow = Calendar.autoupdatingCurrent.date(
                    from: DateComponents(year: 2026, month: 9, day: 20, hour: 12)
                ) ?? Date()
            } else {
                previewNow = Date()
            }
            let model = CalendarWorkbenchV21PreviewModel(
                now: previewNow,
                initialSelectionOffset: initialSelectionOffset
            )
            calendarWorkbenchV21Model = model
            let view = CalendarWorkbenchV21View(model: model) { [weak self] in
                self?.dismissCalendarWorkbenchV21(animated: true)
            }
            let panel = PanelFactory.makeCalendarWorkbenchV21Panel(
                contentRect: NSRect(x: 0, y: 0, width: 1060, height: 660),
                contentView: NSHostingView(rootView: view),
                onPointerEntered: { [weak self] in self?.calendarPointerEntered() },
                onPointerExited: { [weak self] in self?.calendarPointerExited() }
            )
            if calendarWorkbenchV21LightAppearance {
                panel.appearance = NSAppearance(named: .aqua)
            } else if calendarWorkbenchV21DarkAppearance {
                panel.appearance = NSAppearance(named: .darkAqua)
            }
            calendarWorkbenchV21Panel = panel
            // Dismiss only for a real pointer click outside the panel. Key-window
            // changes also happen during launch and app switching, and treating
            // those as clicks made the isolated preview close itself at startup.
            calendarWorkbenchV21OutsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self, weak panel] _ in
                DispatchQueue.main.async {
                    guard let self,
                          self.calendarWorkbenchV21Panel === panel,
                          let panel,
                          panel.isVisible,
                          !panel.frame.contains(NSEvent.mouseLocation) else { return }
                    self.dismissCalendarWorkbenchV21(animated: true)
                }
            }
            calendarWorkbenchV21LocalClickMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self, weak panel] event in
                guard let self,
                      self.calendarWorkbenchV21Panel === panel,
                      let panel,
                      panel.isVisible else { return event }
                if event.window === panel || event.window?.parent === panel {
                    self.engageCalendarWorkbenchV21()
                    return event
                }
                // The status-item click that opens the panel is delivered through
                // a different AppKit window. Treating it as an outside click makes
                // the panel appear and disappear during the same mouse gesture.
                if let anchor = self.statusBar?.deadlineAnchorRect,
                   anchor.insetBy(dx: -2, dy: -2).contains(NSEvent.mouseLocation) {
                    return event
                }
                self.dismissCalendarWorkbenchV21(animated: true)
                return event
            }
        }

        guard let panel = calendarWorkbenchV21Panel else { return }
        if !panel.isVisible {
            calendarInteractionEngaged = false
            panel.alphaValue = 1
        }
        if let anchor = statusBar?.deadlineAnchorRect,
           let screen = NSScreen.screens.first(where: { $0.frame.intersects(anchor) }) ?? NSScreen.main {
            let visible = screen.visibleFrame
            let x = min(max(anchor.midX - panel.frame.width / 2, visible.minX + 8),
                        visible.maxX - panel.frame.width - 8)
            let y = visible.maxY - panel.frame.height
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        } else if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            let x = min(max(panel.frame.minX, visible.minX + 8),
                        visible.maxX - panel.frame.width - 8)
            panel.setFrameOrigin(NSPoint(x: x, y: visible.maxY - panel.frame.height))
        }
        panel.makeKeyAndOrderFront(nil)
        panel.orderFront(nil)
    }

    /// Clean SPEC-003 restart. This route intentionally contains only the
    /// window shell, large calendar, date-state interactions and an in-memory
    /// sidebar. The earlier V2/V2.1 implementations remain compiled and
    /// preserved, but are not selected by the current preview entry.
    private func openCalendarWorkbenchV21Clean() {
        if calendarWorkbenchV21CleanPanel == nil {
            let initialSelectionOffset: Int?
            if calendarWorkbenchV21TodaySelected {
                initialSelectionOffset = 0
            } else if calendarWorkbenchV21NextSelected {
                initialSelectionOffset = 1
            } else {
                initialSelectionOffset = nil
            }

            let previewNow: Date
            if ProcessInfo.processInfo.arguments.contains("--calendar-workbench-v2-1-september-preview") {
                previewNow = Calendar.autoupdatingCurrent.date(
                    from: DateComponents(year: 2026, month: 9, day: 20, hour: 12)
                ) ?? Date()
            } else {
                previewNow = Date()
            }

            let model = CalendarWorkbenchV21CleanModel(
                now: previewNow,
                initialSelectionOffset: initialSelectionOffset
            )
            calendarWorkbenchV21CleanModel = model
            let view = CalendarWorkbenchV21CleanView(model: model) { [weak self] in
                self?.calendarWorkbenchV21CleanPanel?.orderOut(nil)
            }
            let panel = PanelFactory.makeCalendarWorkbenchV21Panel(
                contentRect: NSRect(x: 0, y: 0, width: 1060, height: 660),
                contentView: NSHostingView(rootView: view)
            )
            if calendarWorkbenchV21LightAppearance {
                panel.appearance = NSAppearance(named: .aqua)
            } else if calendarWorkbenchV21DarkAppearance {
                panel.appearance = NSAppearance(named: .darkAqua)
            }
            calendarWorkbenchV21CleanPanel = panel

            calendarWorkbenchV21CleanOutsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self, weak panel] _ in
                DispatchQueue.main.async {
                    guard let self,
                          self.calendarWorkbenchV21CleanPanel === panel,
                          let panel,
                          panel.isVisible,
                          !panel.frame.contains(NSEvent.mouseLocation) else { return }
                    panel.orderOut(nil)
                }
            }
            calendarWorkbenchV21CleanLocalClickMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self, weak panel] event in
                guard let self,
                      self.calendarWorkbenchV21CleanPanel === panel,
                      let panel,
                      panel.isVisible else { return event }
                if event.window !== panel && event.window?.parent !== panel {
                    panel.orderOut(nil)
                }
                return event
            }
        }

        guard let panel = calendarWorkbenchV21CleanPanel else { return }
        if let anchor = statusBar?.deadlineAnchorRect,
           let screen = NSScreen.screens.first(where: { $0.frame.intersects(anchor) }) ?? NSScreen.main {
            let visible = screen.visibleFrame
            let x = min(max(anchor.midX - panel.frame.width / 2, visible.minX + 8),
                        visible.maxX - panel.frame.width - 8)
            let y = visible.maxY - panel.frame.height
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        } else if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(
                x: max(visible.minX + 8, visible.midX - panel.frame.width / 2),
                y: visible.maxY - panel.frame.height
            ))
        }
        panel.alphaValue = 1
        panel.makeKeyAndOrderFront(nil)
        panel.orderFront(nil)
        NSRunningApplication.current.activate(options: [.activateAllWindows])
        NSApp.activate(ignoringOtherApps: true)
    }

    func openSettings(initialCategory: SettingCategory? = nil) {
        settingsPanel?.close()
        let view = SettingsView(taskStore: taskStore, promptStore: promptStore, skillStore: skillStore,
                                settingsStore: settingsStore, clipboard: clipboard,
                                actions: actions, initialCategory: initialCategory)
        settingsPanel = PanelFactory.makeStandardPanel(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 460),
            contentView: NSHostingView(rootView: view),
            title: "Desktop Sentry 偏好设置"
        )
        settingsPanel?.center()
        settingsPanel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Storage path helpers

    var dataDirectoryDisplayPath: String { storage.displayPath }
    var dataDirectoryFullPath: String { storage.dataDirectoryPath }
}
