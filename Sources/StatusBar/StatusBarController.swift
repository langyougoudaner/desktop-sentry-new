import AppKit
import Combine

/// Manages the menu-bar status item and its native contextual menu.
@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {

    private weak var coordinator: AppCoordinator?
    private var promptStatusItem: NSStatusItem!
    private var calendarStatusItem: NSStatusItem!
    private var activeContextMenu: NSMenu?
    private var hoverPollTimer: Timer?
    private var pointerInsideCalendarRegion = false
    private var hoverOpenWorkItem: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()

    /// The calendar owns a fixed-width anchor, independent from the prompt
    /// item's dynamic title and its short-lived copied feedback.
    var calendarAnchorRect: NSRect? {
        guard let button = calendarStatusItem?.button, let window = button.window else { return nil }
        let rectInWindow = button.convert(button.bounds, to: nil)
        return window.convertToScreen(rectInWindow)
    }

    /// Historical callers use this name; it now intentionally resolves to the
    /// dedicated calendar item instead of the variable-width prompt item.
    var deadlineAnchorRect: NSRect? { calendarAnchorRect }

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        super.init()
        setupStatusItem()
        observeStores()
    }

    // MARK: - Status item

    private func setupStatusItem() {
        promptStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = promptStatusItem.button {
            button.target = self
            button.action = #selector(handlePromptClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.setAccessibilityLabel("Desktop Sentry 提示词与菜单")
        }

        calendarStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = calendarStatusItem.button {
            let imageSize = NSSize(width: 18, height: 18)
            let geometry = CalendarStatusGlyphGeometry(size: imageSize.width)
            let calendarImage = NSImage(size: imageSize, flipped: false) { _ in
                NSColor.black.setStroke()
                NSColor.black.setFill()

                let outline = NSBezierPath(
                    roundedRect: geometry.outerRect,
                    xRadius: geometry.cornerRadius,
                    yRadius: geometry.cornerRadius
                )
                outline.lineWidth = geometry.strokeWidth
                outline.stroke()

                let divider = NSBezierPath()
                divider.move(to: NSPoint(x: geometry.outerRect.minX,
                                         y: geometry.headerDividerY))
                divider.line(to: NSPoint(x: geometry.outerRect.maxX,
                                         y: geometry.headerDividerY))
                divider.lineWidth = geometry.strokeWidth
                divider.stroke()

                for cell in geometry.cellRects {
                    NSBezierPath(
                        roundedRect: cell,
                        xRadius: geometry.cellCornerRadius,
                        yRadius: geometry.cellCornerRadius
                    ).fill()
                }
                return true
            }
            calendarImage.isTemplate = true
            button.target = self
            button.action = #selector(handleCalendarClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.image = calendarImage
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.toolTip = "日历与待办"
            button.setAccessibilityLabel("Desktop Sentry 日历与待办")
        }
        startHoverPolling()
        updateTitle()
    }

    private func startHoverPolling() {
        let timer = Timer(timeInterval: 0.08, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.pollStatusHover() }
        }
        RunLoop.main.add(timer, forMode: .common)
        hoverPollTimer = timer
    }

    private func pollStatusHover() {
        guard activeContextMenu == nil, let anchor = calendarAnchorRect else { return }
        let pointer = NSEvent.mouseLocation
        let isInsideStatusItem = anchor.insetBy(dx: -2, dy: -2).contains(pointer)
        let isInsidePanel = coordinator?.calendarPanelContainsScreenPoint(pointer) == true
        let isInsideCalendarRegion = isInsideStatusItem || isInsidePanel
        guard isInsideCalendarRegion != pointerInsideCalendarRegion else { return }
        pointerInsideCalendarRegion = isInsideCalendarRegion
        if isInsideCalendarRegion {
            guard isInsideStatusItem else {
                coordinator?.calendarPointerEntered()
                return
            }
            beginHoverOpen()
        } else {
            endHoverOpen()
        }
    }

    private func beginHoverOpen() {
        hoverOpenWorkItem?.cancel()
        coordinator?.calendarStatusPointerEntered()
        let work = DispatchWorkItem { [weak self] in
            self?.coordinator?.openDeadlines()
        }
        hoverOpenWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    private func endHoverOpen() {
        hoverOpenWorkItem?.cancel()
        hoverOpenWorkItem = nil
        coordinator?.calendarPointerExited()
    }

    private func updateTitle() {
        guard let coord = coordinator else { return }
        if coord.feedback.hudMessage != nil {
            promptStatusItem.button?.title = "✓ 已复制"
        } else {
            promptStatusItem.button?.title = coord.menuBarTitle
        }
        promptStatusItem.button?.toolTip = "左键复制常驻提示词·右键打开菜单"
    }

    /// Any relevant store change refreshes the title.
    private func observeStores() {
        guard let coord = coordinator else { return }
        Publishers.MergeMany([
            coord.taskStore.objectWillChange,
            coord.promptStore.objectWillChange,
            coord.skillStore.objectWillChange,
            coord.settingsStore.objectWillChange,
            coord.feedback.objectWillChange,
            coord.deadlineStore.objectWillChange
        ])
        .sink { [weak self] _ in DispatchQueue.main.async { self?.updateTitle() } }
        .store(in: &cancellables)
    }

    // MARK: - Click handling

    @objc private func handlePromptClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        hoverOpenWorkItem?.cancel()
        let click: StatusClickKind = event.type == .rightMouseUp ? .right : .left
        switch StatusItemRouting.action(role: .prompt, click: click) {
        case .showPromptMenu:
            coordinator?.prepareForStatusMenu()
            showContextMenu(from: sender)
        case .copyPrompt:
            coordinator?.actions.copyPinned()
            updateTitle()
        case .showCalendarPinned:
            break
        }
    }

    @objc private func handleCalendarClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        hoverOpenWorkItem?.cancel()
        let click: StatusClickKind = event.type == .rightMouseUp ? .right : .left
        guard StatusItemRouting.action(role: .calendar, click: click) == .showCalendarPinned else { return }
        coordinator?.toggleCalendarFromStatusItem()
    }

    // MARK: - Native contextual menu

    private func showContextMenu(from button: NSStatusBarButton) {
        guard activeContextMenu == nil else { return }
        let menu = makeContextMenu()
        menu.delegate = self
        activeContextMenu = menu
        // Attach the menu to NSStatusItem exactly as the stable first version
        // did. AppKit then owns the menu-bar anchor and multi-display placement.
        promptStatusItem.menu = menu
        DispatchQueue.main.async { [weak self, weak button, weak menu] in
            guard let self,
                  let button,
                  let menu,
                  self.activeContextMenu === menu else { return }
            button.performClick(nil)
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        guard menu === activeContextMenu else { return }
        DispatchQueue.main.async { [weak self, weak menu] in
            guard let self, self.activeContextMenu === menu else { return }
            self.promptStatusItem.menu = nil
            self.activeContextMenu = nil
        }
    }

    private func makeContextMenu() -> NSMenu {
        guard let coord = coordinator else { return NSMenu() }

        let menu = NSMenu()
        menu.autoenablesItems = false

        let tasks = item("待办任务", symbol: "checklist")
        tasks.submenu = makeTaskMenu(coord)
        menu.addItem(tasks)

        let skills = item("Skill 哨兵", symbol: "sparkles")
        skills.submenu = makeSkillMenu(coord)
        menu.addItem(skills)

        menu.addItem(.separator())

        let quickPrompts = coord.promptStore.quickMenuPrompts
        if quickPrompts.isEmpty {
            menu.addItem(disabledItem("尚未选择快捷提示词"))
        } else {
            for prompt in quickPrompts {
                let promptItem = actionItem(
                    prompt.title,
                    action: #selector(copyPrompt(_:)),
                    representedID: prompt.id,
                    symbol: prompt.isMenuPinned ? "pin.fill" : nil
                )
                menu.addItem(promptItem)
            }
        }

        let allPrompts = item("全部提示词", symbol: "text.bubble")
        allPrompts.submenu = makeAllPromptsMenu(coord)
        menu.addItem(allPrompts)

        let pinned = item("菜单栏常驻", symbol: "pin")
        pinned.submenu = makePinnedPromptMenu(coord)
        menu.addItem(pinned)

        menu.addItem(.separator())
        menu.addItem(actionItem("添加任务…", action: #selector(openQuickAdd), symbol: "plus"))
        menu.addItem(actionItem("管理右键提示词…", action: #selector(openQuickMenuSettings), symbol: "slider.horizontal.3"))
        menu.addItem(actionItem("偏好设置…", action: #selector(openSettings), symbol: "gearshape"))
        menu.addItem(.separator())
        menu.addItem(actionItem("退出 Desktop Sentry", action: #selector(quit)))

        return menu
    }

    private func makeTaskMenu(_ coord: AppCoordinator) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let tasks = coord.taskStore.incompleteTasks
        if tasks.isEmpty {
            menu.addItem(disabledItem("暂无待办任务"))
        } else {
            let boundTasks = tasks.filter { $0.skillName != nil }
            if !boundTasks.isEmpty {
                menu.addItem(disabledItem("使用绑定 Skill"))
                for task in boundTasks.prefix(8) {
                    menu.addItem(actionItem(
                        task.title,
                        action: #selector(copyTaskSkillInvocation(_:)),
                        representedID: task.id,
                        symbol: "sparkles"
                    ))
                }
                menu.addItem(.separator())
                menu.addItem(disabledItem("标记完成"))
            }
            for task in tasks.prefix(12) {
                let title = task.tag.isEmpty ? task.title : "\(task.title)  ·  \(task.tag)"
                menu.addItem(actionItem(
                    title,
                    action: #selector(toggleTask(_:)),
                    representedID: task.id,
                    symbol: "circle"
                ))
            }
            if tasks.count > 12 {
                menu.addItem(disabledItem("另有 \(tasks.count - 12) 项，请在设置中查看"))
            }
        }

        menu.addItem(.separator())
        menu.addItem(actionItem("添加任务…", action: #selector(openQuickAdd), symbol: "plus"))
        menu.addItem(actionItem("管理任务…", action: #selector(openTaskSettings), symbol: "list.bullet"))
        return menu
    }

    private func makeSkillMenu(_ coord: AppCoordinator) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        if coord.skillStore.isScanning {
            menu.addItem(disabledItem("正在扫描 Skill..."))
        } else if coord.skillStore.favoriteSkills.isEmpty {
            menu.addItem(disabledItem("尚未收藏 Skill"))
        } else {
            menu.addItem(disabledItem("收藏"))
            for skill in coord.skillStore.favoriteSkills.prefix(8) {
                menu.addItem(actionItem(
                    skill.callToken,
                    action: #selector(copySkillInvocation(_:)),
                    representedValue: skill.id,
                    symbol: "star.fill"
                ))
            }
        }
        menu.addItem(.separator())
        menu.addItem(actionItem("查找 Skill...", action: #selector(openSearch), symbol: "magnifyingglass"))
        menu.addItem(actionItem("重新扫描", action: #selector(rescanSkills), symbol: "arrow.clockwise"))
        menu.addItem(actionItem("管理 Skill...", action: #selector(openSkillSettings), symbol: "square.grid.2x2"))
        return menu
    }

    private func makeAllPromptsMenu(_ coord: AppCoordinator) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let validPrompts = coord.promptStore.prompts.filter {
            !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if validPrompts.isEmpty {
            menu.addItem(disabledItem("暂无提示词"))
            return menu
        }

        let grouped = Dictionary(grouping: validPrompts) {
            let group = $0.group.trimmingCharacters(in: .whitespacesAndNewlines)
            return group.isEmpty ? "未分组" : group
        }
        for groupName in grouped.keys.sorted() {
            let groupItem = item(groupName, symbol: "folder")
            let submenu = NSMenu()
            submenu.autoenablesItems = false
            for prompt in grouped[groupName, default: []].sorted(by: { $0.sortOrder < $1.sortOrder }) {
                submenu.addItem(actionItem(
                    prompt.title,
                    action: #selector(copyPrompt(_:)),
                    representedID: prompt.id,
                    symbol: prompt.isMenuPinned ? "pin.fill" : nil
                ))
            }
            groupItem.submenu = submenu
            menu.addItem(groupItem)
        }
        return menu
    }

    private func makePinnedPromptMenu(_ coord: AppCoordinator) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let none = actionItem("不设置常驻", action: #selector(clearPinnedPrompt))
        none.state = coord.promptStore.pinnedPrompt == nil ? .on : .off
        menu.addItem(none)
        menu.addItem(.separator())

        for prompt in coord.promptStore.prompts where !prompt.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let promptItem = actionItem(
                prompt.title,
                action: #selector(setPinnedPrompt(_:)),
                representedID: prompt.id
            )
            promptItem.state = prompt.isMenuPinned ? .on : .off
            menu.addItem(promptItem)
        }
        return menu
    }

    private func item(_ title: String, symbol: String? = nil) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        if let symbol { menuItem.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
        return menuItem
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let menuItem = item(title)
        menuItem.isEnabled = false
        return menuItem
    }

    private func actionItem(_ title: String,
                            action: Selector,
                            representedID: UUID? = nil,
                            representedValue: String? = nil,
                            symbol: String? = nil) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: "")
        menuItem.target = self
        if let representedID { menuItem.representedObject = representedID.uuidString }
        if let representedValue { menuItem.representedObject = representedValue }
        if let symbol { menuItem.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
        return menuItem
    }

    private func representedID(from sender: NSMenuItem) -> UUID? {
        guard let raw = sender.representedObject as? String else { return nil }
        return UUID(uuidString: raw)
    }

    @objc private func toggleTask(_ sender: NSMenuItem) {
        guard let id = representedID(from: sender),
              let task = coordinator?.taskStore.tasks.first(where: { $0.id == id }) else { return }
        coordinator?.taskStore.toggleTask(task)
    }

    @objc private func copyPrompt(_ sender: NSMenuItem) {
        guard let id = representedID(from: sender),
              let prompt = coordinator?.promptStore.prompts.first(where: { $0.id == id }) else { return }
        coordinator?.clipboard.copyPrompt(prompt)
    }

    @objc private func copySkillInvocation(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let skill = coordinator?.skillStore.skills.first(where: { $0.id == id }) else { return }
        coordinator?.clipboard.copySkillInvocation(skill)
    }

    @objc private func copyTaskSkillInvocation(_ sender: NSMenuItem) {
        guard let id = representedID(from: sender),
              let coord = coordinator,
              let task = coord.taskStore.tasks.first(where: { $0.id == id }),
              let skillName = task.skillName,
              let skill = coord.skillStore.skills.first(where: { $0.id == skillName.lowercased() }) else { return }
        coord.clipboard.copySkillInvocation(skill, task: task.title)
    }

    @objc private func setPinnedPrompt(_ sender: NSMenuItem) {
        guard let id = representedID(from: sender) else { return }
        coordinator?.promptStore.setPinnedPrompt(id: id)
    }

    @objc private func clearPinnedPrompt() { coordinator?.promptStore.clearPinnedPrompt() }
    @objc private func openQuickAdd() { coordinator?.openQuickAdd() }
    @objc private func openDeadlines() { coordinator?.openDeadlines() }
    @objc private func openSearch() { coordinator?.openSearch() }
    @objc private func rescanSkills() { coordinator?.skillStore.scan() }
    @objc private func openTaskSettings() { coordinator?.openSettings(initialCategory: .task(.todo)) }
    @objc private func openQuickMenuSettings() { coordinator?.openSettings(initialCategory: .prompt(.quickMenu)) }
    @objc private func openSkillSettings() { coordinator?.openSettings(initialCategory: .skill(.catalog)) }
    @objc private func openSettings() { coordinator?.openSettings() }
    @objc private func quit() { NSApp.terminate(nil) }
}
