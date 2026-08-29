import SwiftUI
import AppKit

// MARK: - Settings root (single entry point — no more Settings{} scene)

struct SettingsView: View {
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var promptStore: PromptStore
    @ObservedObject var skillStore: SkillStore
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var clipboard: ClipboardService
    let actions: AppActions
    @State private var selected: SettingCategory?

    init(taskStore: TaskStore, promptStore: PromptStore, skillStore: SkillStore,
         settingsStore: SettingsStore, clipboard: ClipboardService,
         actions: AppActions, initialCategory: SettingCategory? = nil) {
        self.taskStore = taskStore
        self.promptStore = promptStore
        self.skillStore = skillStore
        self.settingsStore = settingsStore
        self.clipboard = clipboard
        self.actions = actions
        _selected = State(initialValue: initialCategory ?? .general(.basic))
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selected) {
                Section("通用") {
                    ForEach(GeneralItem.allCases, id: \.self) { item in
                        Label(item.title, systemImage: item.icon).tag(SettingCategory.general(item))
                    }
                }
                Section("任务") {
                    ForEach(TaskNavCategory.allCases, id: \.self) { item in
                        Label(item.title, systemImage: item.icon).tag(SettingCategory.task(item))
                    }
                }
                Section("提示词") {
                    ForEach(PromptNavCategory.allCases, id: \.self) { item in
                        Label(item.title, systemImage: item.icon).tag(SettingCategory.prompt(item))
                    }
                }
                Section("Skill") {
                    ForEach(SkillNavCategory.allCases, id: \.self) { item in
                        Label(item.title, systemImage: item.icon).tag(SettingCategory.skill(item))
                    }
                }
            }
            .navigationTitle("设置")
            .frame(minWidth: 160, idealWidth: 180)
        } detail: {
            detailView
        }
        .frame(minWidth: 600, minHeight: 440)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selected {
        case .general(let item): generalDetail(item)
        case .task(let item):    taskDetail(item)
        case .prompt(let item):  promptDetail(item)
        case .skill(let item):   skillDetail(item)
        case .none:
            ContentUnavailableView("选择一个设置项", systemImage: "gearshape",
                                   description: Text("在左侧列表中选择"))
        }
    }

    // MARK: - General

    @ViewBuilder
    private func generalDetail(_ item: GeneralItem) -> some View {
        Form {
            switch item {
            case .basic:
                Section {
                    Toggle("开机自动启动", isOn: Binding(
                        get: { settingsStore.launchAtLogin },
                        set: { settingsStore.setLaunchAtLogin($0) }
                    ))
                    HStack {
                        Label(settingsStore.loginItemState.title,
                              systemImage: settingsStore.loginItemState.symbolName)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("重新检查") { settingsStore.refreshLoginItemStatus() }
                            .buttonStyle(.link)
                    }
                    if let message = settingsStore.loginItemMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                    Button("打开系统登录项设置") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                } header: {
                    Text("启动")
                } footer: {
                    Text("这里显示的是 macOS 的真实登录项状态；系统未允许时，开关不会假装已经开启。")
                }
                .onAppear { settingsStore.refreshLoginItemStatus() }

                Section {
                    Toggle("点击提示词时自动切换常驻", isOn: Binding(
                        get: { settingsStore.autoSwitchOnCopy },
                        set: { settingsStore.setAutoSwitchOnCopy($0) }
                    ))
                } header: {
                    Text("行为")
                }

                Section("版本") {
                    LabeledContent("当前程序") {
                        Text(AppBuildIdentity.current.displayLabel)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

            case .menuBarTitle:
                Toggle("显示 Emoji 前缀", isOn: Binding(get: { settingsStore.titleEmojiEnabled }, set: { settingsStore.setTitleEmojiEnabled($0) }))
                Toggle("显示任务计数", isOn: Binding(get: { settingsStore.titleShowTaskCount }, set: { settingsStore.setTitleShowTaskCount($0) }))
                TextField("自定义文字（留空则显示常驻提示词）",
                    text: Binding(get: { settingsStore.titleCustomText }, set: { settingsStore.setTitleCustomText($0) }))
                HStack(spacing: 4) {
                    Text("预览:").foregroundStyle(.secondary).font(.caption)
                    Text(coordinatorPreviewTitle)
                        .font(.caption)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }

            case .appearance:
                HStack {
                    Text("菜单栏字数上限")
                    Spacer()
                    Text("\(settingsStore.maxMenuBarChars) 字").foregroundStyle(.secondary).font(.caption)
                }
                Slider(value: Binding(get: { Double(settingsStore.maxMenuBarChars) },
                                       set: { settingsStore.setMaxMenuBarChars(Int($0)) }),
                       in: 10...25, step: 1)
                Picker("默认常驻提示词", selection: Binding(
                    get: { promptStore.pinnedPrompt?.id },
                    set: { id in if let id = id { promptStore.setPinnedPrompt(id: id) } else { promptStore.clearPinnedPrompt() } }
                )) {
                    Text("无").tag(nil as UUID?)
                    ForEach(promptStore.prompts) { p in Text(p.title).tag(p.id as UUID?) }
                }

            case .storage:
                HStack {
                    Text("数据目录").foregroundStyle(.secondary)
                    Text(StorageManager.shared.displayPath)
                        .font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button("在 Finder 中打开") {
                        let path = StorageManager.shared.dataDirectoryPath
                        let fm = FileManager.default
                        if !fm.fileExists(atPath: path) {
                            try? fm.createDirectory(atPath: path, withIntermediateDirectories: true)
                        }
                        NSWorkspace.shared.open(URL(fileURLWithPath: path))
                    }
                }
            case .sound:
                soundSettingsView
            }
        }
        .formStyle(.grouped)
        .navigationTitle(item.title)
    }

    /// Build the title preview from current stores via the pure TitleBuilder.
    private var coordinatorPreviewTitle: String {
        TitleBuilder.build(
            tasks: taskStore.tasks, prompts: promptStore.prompts,
            maxChars: settingsStore.maxMenuBarChars,
            emojiEnabled: settingsStore.titleEmojiEnabled,
            customText: settingsStore.titleCustomText,
            showTaskCount: settingsStore.titleShowTaskCount
        )
    }

    // MARK: - Sound settings

    @ViewBuilder
    private var soundSettingsView: some View {
        Section {
            Toggle("复制时播放提示音", isOn: Binding(
                get: { settingsStore.soundEnabled },
                set: { settingsStore.setSoundEnabled($0) }
            ))
            Picker("提示音", selection: Binding(
                get: { settingsStore.soundEffectName },
                set: { settingsStore.setSoundEffectName($0) }
            )) {
                ForEach(SettingsStore.systemSoundNames, id: \.self) { name in
                    Text(name)
                }
            }
            .onChange(of: settingsStore.soundEffectName) { _, _ in playPreview() }
        } header: {
            Text("音效设置")
        } footer: {
            Text("使用 macOS 系统提示音，选择后即时试听。")
        }
    }

    /// Audition the currently selected system sound.
    private func playPreview() {
        let name = settingsStore.soundEffectName
        DispatchQueue.global(qos: .userInitiated).async {
            if let s = NSSound(named: name) { s.play() }
            else { NSSound.beep() }
        }
    }

    // MARK: - Task

    @ViewBuilder
    private func taskDetail(_ item: TaskNavCategory) -> some View {
        switch item {
        case .todo: TaskTodoView(taskStore: taskStore, skillStore: skillStore, clipboard: clipboard)
        case .done: TaskDoneView(taskStore: taskStore)
        }
    }

    // MARK: - Prompt

    @ViewBuilder
    private func promptDetail(_ item: PromptNavCategory) -> some View {
        switch item {
        case .manage: PromptManageView(promptStore: promptStore)
        case .pin:    PromptPinView(promptStore: promptStore)
        case .quickMenu: PromptQuickMenuView(promptStore: promptStore)
        case .history: PromptHistoryView(clipboard: clipboard)
        }
    }

    // MARK: - Skill

    @ViewBuilder
    private func skillDetail(_ item: SkillNavCategory) -> some View {
        switch item {
        case .catalog: SkillCatalogSettingsView(skillStore: skillStore, clipboard: clipboard)
        case .sources: SkillSourcesView(skillStore: skillStore)
        }
    }
}

// MARK: - Category enums

enum SettingCategory: Hashable {
    case general(GeneralItem)
    case task(TaskNavCategory)
    case prompt(PromptNavCategory)
    case skill(SkillNavCategory)
}

enum GeneralItem: String, CaseIterable {
    case basic, menuBarTitle, appearance, storage, sound
    var title: String { switch self { case .basic: return "基础"; case .menuBarTitle: return "菜单栏标题"; case .appearance: return "外观"; case .storage: return "存储"; case .sound: return "音效设置" } }
    var icon: String { switch self { case .basic: return "gearshape"; case .menuBarTitle: return "textformat"; case .appearance: return "paintbrush"; case .storage: return "internaldrive"; case .sound: return "speaker.wave.2" } }
}

enum TaskNavCategory: String, CaseIterable {
    case todo, done
    var title: String { switch self { case .todo: return "待办"; case .done: return "已完成" } }
    var icon: String { switch self { case .todo: return "checklist"; case .done: return "checkmark.circle" } }
}

enum PromptNavCategory: String, CaseIterable {
    case manage, pin, quickMenu, history
    var title: String {
        switch self {
        case .manage: return "管理提示词"
        case .pin: return "菜单栏常驻"
        case .quickMenu: return "右键快捷提示词"
        case .history: return "复制历史"
        }
    }
    var icon: String {
        switch self {
        case .manage: return "text.bubble"
        case .pin: return "pin"
        case .quickMenu: return "list.number"
        case .history: return "clock.arrow.circlepath"
        }
    }
}

enum SkillNavCategory: String, CaseIterable {
    case catalog, sources

    var title: String {
        switch self {
        case .catalog: return "Skill 目录"
        case .sources: return "扫描目录"
        }
    }

    var icon: String {
        switch self {
        case .catalog: return "sparkles"
        case .sources: return "folder.badge.gearshape"
        }
    }
}

// MARK: - Task views

private struct TaskTodoView: View {
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var skillStore: SkillStore
    @ObservedObject var clipboard: ClipboardService
    @State private var text = ""
    @State private var bindingTask: TaskItem?

    var body: some View {
        Form {
            Section("添加任务") {
                HStack(spacing: 10) {
                    TextField("输入任务标题…", text: $text)
                        .onSubmit { submit() }
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))

                    Button("添加") { submit() }
                        .font(.system(size: 12))
                        .fixedSize()
                        .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.vertical, -4)
            }
            Section("待办 (\(taskStore.incompleteCount))") {
                ForEach(taskStore.incompleteTasks) { task in
                    HStack(spacing: 8) {
                        Button { taskStore.toggleTask(task) } label: { Image(systemName: "circle").foregroundStyle(.secondary) }.buttonStyle(.plain)
                        Text(task.priority.symbol).font(.caption)
                        Text(task.title)
                        if !task.tag.isEmpty {
                            Text(task.tag).font(.caption2).padding(.horizontal, 4).padding(.vertical, 1).background(.blue.opacity(0.15), in: Capsule())
                        }
                        if let skillName = task.skillName {
                            Text("$\(skillName)")
                                .font(.caption2)
                                .lineLimit(1)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.purple.opacity(0.13), in: Capsule())
                        }
                        Spacer()
                        Button {
                            bindingTask = task
                        } label: {
                            Image(systemName: task.skillName == nil ? "sparkles" : "sparkles.rectangle.stack.fill")
                        }
                        .buttonStyle(.borderless)
                        .help(task.skillName == nil ? "关联 Skill" : "更换关联 Skill")
                        Picker("", selection: Binding(get: { task.priority }, set: { taskStore.setTaskPriority(id: task.id, priority: $0) })) {
                            ForEach(TaskPriority.allCases, id: \.self) { p in Text(p.rawValue).tag(p) }
                        }.labelsHidden().frame(width: 50)
                    }
                    .contextMenu {
                        if let skillName = task.skillName,
                           let skill = skillStore.skills.first(where: { $0.id == skillName }) {
                            Button("复制 Skill 调用语") {
                                clipboard.copySkillInvocation(skill, task: task.title)
                            }
                        }
                        Button("删除", role: .destructive) { taskStore.deleteTask(task) }
                    }
                    .padding(.vertical, -4)
                }
                if taskStore.incompleteTasks.isEmpty { Text("暂无待办任务").foregroundStyle(.secondary) }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("待办")
        .sheet(item: $bindingTask) { task in
            TaskSkillBindingView(task: task, taskStore: taskStore,
                                 skillStore: skillStore, clipboard: clipboard)
        }
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        taskStore.addTask(trimmed)
        text = ""
    }
}

private struct TaskSkillBindingView: View {
    let task: TaskItem
    @ObservedObject var taskStore: TaskStore
    @ObservedObject var skillStore: SkillStore
    @ObservedObject var clipboard: ClipboardService
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var results: [SkillItem] {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let recommendations = skillStore.recommendations(for: task.title, limit: 8)
            return recommendations.isEmpty ? Array(skillStore.skills.prefix(30)) : recommendations
        }
        return skillStore.matching(query: query, limit: 50)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("关联 Skill").font(.headline)
                    Text(task.title).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                if task.skillName != nil {
                    Button("取消关联") {
                        taskStore.setTaskSkill(id: task.id, skillName: nil)
                        dismiss()
                    }
                }
                Button("完成") { dismiss() }
            }
            .padding()

            TextField("搜索名称、用途或任务描述", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.bottom, 10)

            Divider()
            List(results) { skill in
                Button {
                    taskStore.setTaskSkill(id: task.id, skillName: skill.id)
                    dismiss()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: task.skillName == skill.id ? "checkmark.circle.fill" : "sparkles")
                            .foregroundStyle(task.skillName == skill.id ? Color.accentColor : Color.secondary)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(skill.callToken).foregroundStyle(.primary)
                            Text(skill.displaySummary.isEmpty ? skill.category : skill.displaySummary)
                                .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                        Spacer()
                        Button {
                            clipboard.copySkillInvocation(skill, task: task.title)
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .help("复制并保留当前关联")
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .overlay {
                if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
        }
        .frame(minWidth: 520, minHeight: 420)
    }
}

private struct TaskDoneView: View {
    @ObservedObject var taskStore: TaskStore

    var body: some View {
        Form {
            Section("已完成 (\(taskStore.completedCount))") {
                ForEach(taskStore.completedTasks) { task in
                    HStack(spacing: 8) {
                        Button { taskStore.toggleTask(task) } label: { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }.buttonStyle(.plain)
                        Text(task.priority.symbol).font(.caption)
                        Text(task.title).strikethrough().foregroundStyle(.secondary)
                        if !task.tag.isEmpty {
                            Text(task.tag).font(.caption2).padding(.horizontal, 4).padding(.vertical, 1).background(.blue.opacity(0.15), in: Capsule())
                        }
                        Spacer()
                        Picker("", selection: Binding(get: { task.priority }, set: { taskStore.setTaskPriority(id: task.id, priority: $0) })) {
                            ForEach(TaskPriority.allCases, id: \.self) { p in Text(p.rawValue).tag(p) }
                        }.labelsHidden().frame(width: 50)
                    }
                    .contextMenu { Button("删除", role: .destructive) { taskStore.deleteTask(task) } }
                }
                if taskStore.completedTasks.isEmpty { Text("暂无已完成任务").foregroundStyle(.secondary) }
            }
            if !taskStore.completedTasks.isEmpty {
                Section { Button("清除已完成", role: .destructive) { taskStore.clearCompletedTasks() } }
            }
            Section("垃圾桶 (\(taskStore.trashedTasks.count)) · 30天后自动清除") {
                ForEach(taskStore.trashedTasks) { task in
                    HStack(spacing: 8) {
                        Text(task.priority.symbol).font(.caption)
                        Text(task.title).foregroundStyle(.secondary).strikethrough()
                        Spacer()
                        Button("恢复") { taskStore.restoreTask(task) }.font(.caption)
                    }
                }
                if taskStore.trashedTasks.isEmpty { Text("垃圾桶为空").foregroundStyle(.secondary) }
            }
            if !taskStore.trashedTasks.isEmpty {
                Section { Button("清空垃圾桶", role: .destructive) { taskStore.emptyTrash() } }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("已完成")
    }
}

// MARK: - Skill views

private struct SkillCatalogSettingsView: View {
    @ObservedObject var skillStore: SkillStore
    @ObservedObject var clipboard: ClipboardService
    @State private var query = ""
    @State private var category = "全部"
    @State private var favoritesOnly = false

    private var results: [SkillItem] {
        skillStore.matching(
            query: query,
            category: category == "全部" ? nil : category,
            favoritesOnly: favoritesOnly,
            limit: 500
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                TextField("搜索 Skill 名称或用途", text: $query)
                    .textFieldStyle(.roundedBorder)
                Picker("分类", selection: $category) {
                    Text("全部").tag("全部")
                    ForEach(SkillCategories.all, id: \.self) { Text($0).tag($0) }
                }
                .frame(width: 150)
                Toggle("仅收藏", isOn: $favoritesOnly).toggleStyle(.checkbox)
                Button {
                    skillStore.scan()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("重新扫描")
                .disabled(skillStore.isScanning)
            }
            .padding()

            HStack {
                Text(skillStore.scanSummary).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("显示 \(results.count)").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider()
            List(results) { skill in
                HStack(spacing: 10) {
                    Button {
                        skillStore.toggleFavorite(skill)
                    } label: {
                        Image(systemName: skill.isFavorite ? "star.fill" : "star")
                            .foregroundStyle(skill.isFavorite ? Color.yellow : Color.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help(skill.isFavorite ? "取消收藏" : "收藏")

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(skill.callToken).fontWeight(.medium)
                            Text(skill.sourcePaths.count > 1 ? "\(skill.sourcePaths.count) 个来源" : skill.category)
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Text(skill.displaySummary.isEmpty ? "未提供说明" : skill.displaySummary)
                            .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                    Spacer(minLength: 8)
                    Picker("", selection: Binding(
                        get: { skill.category },
                        set: { skillStore.setCategory(skillID: skill.id, category: $0) }
                    )) {
                        ForEach(SkillCategories.all, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 130)
                    Button {
                        clipboard.copySkillName(skill)
                    } label: {
                        Image(systemName: "dollarsign")
                    }
                    .buttonStyle(.borderless)
                    .help("复制 Skill 名称")
                    Button {
                        clipboard.copySkillInvocation(skill)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .help("复制完整调用语")
                }
                .padding(.vertical, 3)
            }
            .overlay {
                if results.isEmpty && !skillStore.isScanning {
                    ContentUnavailableView.search(text: query)
                }
            }
        }
        .navigationTitle("Skill 目录")
        .onAppear {
            if skillStore.skills.isEmpty { skillStore.scan() }
        }
    }
}

private struct SkillSourcesView: View {
    @ObservedObject var skillStore: SkillStore

    var body: some View {
        Form {
            Section("本地目录") {
                ForEach(skillStore.directories, id: \.self) { path in
                    HStack {
                        Image(systemName: "folder")
                        Text(path).font(.caption).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Button {
                            skillStore.removeDirectory(path)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("移除目录")
                    }
                }
                Button {
                    chooseDirectories()
                } label: {
                    Label("添加目录", systemImage: "plus")
                }
            }
            Section("索引") {
                LabeledContent("状态", value: skillStore.scanSummary)
                Button {
                    skillStore.scan()
                } label: {
                    Label(skillStore.isScanning ? "正在扫描" : "重新扫描", systemImage: "arrow.clockwise")
                }
                .disabled(skillStore.isScanning)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("扫描目录")
    }

    private func chooseDirectories() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.prompt = "添加"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls { skillStore.addDirectory(url.path) }
        skillStore.scan()
    }
}

// MARK: - Prompt views

private struct PromptManageView: View {
    @ObservedObject var promptStore: PromptStore
    @State private var selectedId: UUID?
    @State private var editTitle = ""
    @State private var editAbbreviation = ""
    @State private var editGroup = ""
    @State private var editContent = ""

    private var selected: PromptItem? { promptStore.prompts.first { $0.id == selectedId } }

    var body: some View {
        Form {
            // ── 提示词列表（点击选中编辑，右键更多操作）──
            Section {
                ForEach(promptStore.prompts) { prompt in
                    promptRow(for: prompt)
                }
                .onMove { promptStore.movePrompt(from: $0, to: $1) }

                // ── 内嵌新增行（像 Notes.app 的 "+ 新建"）──
                Button {
                    promptStore.addPrompt()
                    if let last = promptStore.prompts.last {
                        selectPrompt(last)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                        Text("新增提示词…")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
            } header: {
                HStack {
                    Text("提示词列表")
                    Spacer()
                    Text("\(promptStore.prompts.count)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            // ── 编辑区（选中后才显示，实时保存）──
            if selectedId != nil, let sel = selected {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("标题").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text("自动保存")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.1), in: Capsule())
                        }
                        TextField("输入提示词标题", text: $editTitle).textFieldStyle(.roundedBorder)
                            .onChange(of: editTitle) { _, v in
                                promptStore.updateTitle(id: sel.id, title: v)
                            }
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("缩写").font(.caption).foregroundStyle(.secondary)
                                TextField("菜单栏显示用", text: $editAbbreviation).textFieldStyle(.roundedBorder)
                                    .onChange(of: editAbbreviation) { _, v in
                                        promptStore.updateAbbreviation(id: sel.id, abbreviation: v)
                                    }
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("分组").font(.caption).foregroundStyle(.secondary)
                                TextField("如：写作、开发", text: $editGroup).textFieldStyle(.roundedBorder)
                                    .onChange(of: editGroup) { _, v in
                                        promptStore.updateGroup(id: sel.id, group: v)
                                    }
                            }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("内容").font(.caption).foregroundStyle(.secondary)
                            TextEditor(text: $editContent).font(.body).frame(minHeight: 120)
                                .scrollContentBackground(.hidden).padding(8)
                                .background(Color(nsColor: .textBackgroundColor))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
                                .onChange(of: editContent) { _, v in
                                    promptStore.updateContent(id: sel.id, content: v)
                                }
                        }
                    }
                } header: {
                    HStack {
                        Text("编辑")
                        Spacer()
                        // ── 行内操作按钮：只对当前选中项生效 ──
                        Button(sel.isMenuPinned ? "取消常驻" : "设为常驻") {
                            promptStore.togglePinPrompt(sel)
                        }
                        .font(.system(size: 12))
                        Button("删除") {
                            selectedId = nil
                            promptStore.deletePrompt(sel)
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 1.0, green: 0.373, blue: 0.341))
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .formStyle(.grouped)
        .animation(.easeInOut(duration: 0.22), value: selectedId)
        .navigationTitle("管理提示词")
    }

    // MARK: - 单行提示词

    @ViewBuilder
    private func promptRow(for prompt: PromptItem) -> some View {
        Button {
            selectPrompt(prompt)
        } label: {
            HStack(spacing: 8) {
                // 选中指示器
                RoundedRectangle(cornerRadius: 3)
                    .fill(selectedId == prompt.id ? Color.accentColor : Color.clear)
                    .frame(width: 4, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(prompt.title).foregroundStyle(.primary).lineLimit(1)
                    if !prompt.content.isEmpty {
                        Text(prompt.content).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer()
                // 右侧标签
                if !prompt.abbreviation.isEmpty {
                    Text(prompt.abbreviation)
                        .font(.system(size: 10))
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(.quaternary, in: Capsule())
                }
                if prompt.isMenuPinned {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.blue)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(
            selectedId == prompt.id
                ? Color.accentColor.opacity(0.06)
                : Color.clear
        )
        .contextMenu {
            Button(prompt.isMenuPinned ? "取消常驻" : "设为常驻") {
                promptStore.togglePinPrompt(prompt)
            }
            Button("删除", role: .destructive) {
                if selectedId == prompt.id { selectedId = nil }
                promptStore.deletePrompt(prompt)
            }
        }
    }

    private func selectPrompt(_ prompt: PromptItem) {
        if selectedId == prompt.id {
            selectedId = nil
        } else {
            selectedId = prompt.id
            editTitle = prompt.title
            editAbbreviation = prompt.abbreviation
            editGroup = prompt.group
            editContent = prompt.content
        }
    }
}

private struct PromptPinView: View {
    @ObservedObject var promptStore: PromptStore
    var body: some View {
        Form {
            Section("当前常驻提示词") {
                if let pinned = promptStore.pinnedPrompt {
                    HStack { Text(pinned.title); Spacer(); Image(systemName: "eye.fill").foregroundStyle(.blue) }
                    Button("取消常驻", role: .destructive) { promptStore.clearPinnedPrompt() }
                } else { Text("未设置").foregroundStyle(.secondary) }
            }
            Section("选择常驻提示词") {
                ForEach(promptStore.prompts) { prompt in
                    Button { promptStore.setPinnedPrompt(id: prompt.id) } label: {
                        HStack { Text(prompt.title); Spacer(); if prompt.isMenuPinned { Image(systemName: "checkmark").foregroundStyle(.blue) } }
                    }.buttonStyle(.plain)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("菜单栏常驻")
    }
}

private struct PromptQuickMenuView: View {
    @ObservedObject var promptStore: PromptStore

    var body: some View {
        Form {
            Section {
                if promptStore.quickMenuPrompts.isEmpty {
                    Text("尚未选择提示词").foregroundStyle(.secondary)
                } else {
                    ForEach(Array(promptStore.quickMenuPrompts.enumerated()), id: \.element.id) { index, prompt in
                        HStack(spacing: 10) {
                            Text("\(index + 1)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 18, alignment: .trailing)
                            Text(prompt.title).lineLimit(1)
                            Spacer()
                            Button {
                                promptStore.moveQuickMenuPrompt(id: prompt.id, offset: -1)
                            } label: {
                                Image(systemName: "chevron.up")
                            }
                            .buttonStyle(.borderless)
                            .disabled(index == 0)
                            .help("向上移动")

                            Button {
                                promptStore.moveQuickMenuPrompt(id: prompt.id, offset: 1)
                            } label: {
                                Image(systemName: "chevron.down")
                            }
                            .buttonStyle(.borderless)
                            .disabled(index == promptStore.quickMenuPrompts.count - 1)
                            .help("向下移动")
                        }
                    }
                }
            } header: {
                HStack {
                    Text("右键菜单显示顺序")
                    Spacer()
                    Text("\(promptStore.quickMenuPromptIDs.count)/6")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            } footer: {
                Text("右键点击菜单栏按钮时，这些提示词会按照上面的顺序展示。")
            }

            Section("选择提示词") {
                ForEach(promptStore.prompts) { prompt in
                    let isSelected = promptStore.isQuickMenuPrompt(prompt)
                    Toggle(prompt.title, isOn: Binding(
                        get: { isSelected },
                        set: { promptStore.setQuickMenuPrompt(id: prompt.id, enabled: $0) }
                    ))
                    .disabled(!isSelected && promptStore.quickMenuPromptIDs.count >= 6)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("右键快捷提示词")
    }
}

private struct PromptHistoryView: View {
    @ObservedObject var clipboard: ClipboardService

    var body: some View {
        Form {
            if clipboard.copyHistory.isEmpty {
                ContentUnavailableView("暂无复制记录", systemImage: "clock.arrow.circlepath",
                                       description: Text("复制提示词后会显示在这里"))
            } else {
                Section("最近复制") {
                    ForEach(clipboard.copyHistory) { entry in
                        Button { clipboard.copyFromHistory(entry) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.promptTitle).font(.body)
                                    Text(entry.promptContent).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                }
                                Spacer()
                            }
                        }.buttonStyle(.plain)
                    }
                }
                Section { Button("清除历史", role: .destructive) { clipboard.clearHistory() } }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("复制历史")
    }
}
