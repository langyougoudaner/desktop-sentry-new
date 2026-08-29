import Foundation
import Combine

struct V5TaskMetadata: Codable, Hashable {
    var dueDate: Date?
    var details: String
    var reminderAt: Date?

    init(dueDate: Date? = nil, details: String = "", reminderAt: Date? = nil) {
        self.dueDate = dueDate
        self.details = details
        self.reminderAt = reminderAt
    }
}

struct CalendarWorkbenchV5Task: Identifiable, Hashable {
    var legacy: TaskItem
    var metadata: V5TaskMetadata
    var id: UUID { legacy.id }
}

enum V5TaskListMode {
    case active
    case completed
}

@MainActor
final class CalendarWorkbenchV5Model: ObservableObject {
    @Published private(set) var tasks: [CalendarWorkbenchV5Task]
    @Published var displayedMonth: Date
    @Published var selectedDate: Date
    @Published var editingTaskID: UUID?
    @Published var selectedTaskID: UUID?
    @Published var listMode: V5TaskListMode = .active
    @Published var draftTitle = ""
    @Published var draftDetails = ""
    @Published var draftDate: Date
    @Published var draftReminderEnabled = false
    @Published var draftReminder: Date

    /// Production wiring receives complete legacy and companion snapshots.
    /// Preview routes leave this nil and remain memory-only.
    var onMutation: (([TaskItem], [UUID: V5TaskMetadata]) -> Void)?

    let calendar: Calendar
    @Published private(set) var today: Date
    let isPreviewData: Bool

    init(now: Date = Date(), tasks: [TaskItem]? = nil,
         metadata: [UUID: V5TaskMetadata] = [:], longList: Bool = false) {
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 2
        self.calendar = calendar
        let day = calendar.startOfDay(for: now)
        today = day
        displayedMonth = day
        selectedDate = day
        draftDate = day
        draftReminder = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
        isPreviewData = tasks == nil
        let legacyTasks = tasks ?? Self.previewTasks(today: day, calendar: calendar, longList: longList)
        self.tasks = legacyTasks.map { task in
            CalendarWorkbenchV5Task(
                legacy: task,
                metadata: metadata[task.id] ?? Self.previewMetadata(for: task, today: day, calendar: calendar)
            )
        }
    }

    var monthTitle: String { Self.monthFormatter.string(from: displayedMonth) }
    var selectionTitle: String { Self.selectionFormatter.string(from: selectedDate) }
    var weekdaySymbols: [String] { ["一", "二", "三", "四", "五", "六", "日"] }

    var monthDays: [Date] {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let leading = (calendar.component(.weekday, from: interval.start) - calendar.firstWeekday + 7) % 7
        let start = calendar.date(byAdding: .day, value: -leading, to: interval.start) ?? interval.start
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    var activeTasks: [CalendarWorkbenchV5Task] {
        tasks.filter { !$0.legacy.isCompleted && $0.legacy.deletedAt == nil && matchesSelection($0) }
            .sorted { $0.legacy.createdAt > $1.legacy.createdAt }
    }

    var completedTasks: [CalendarWorkbenchV5Task] {
        tasks.filter { $0.legacy.isCompleted && $0.legacy.deletedAt == nil && matchesSelection($0) }
            .sorted { $0.legacy.createdAt > $1.legacy.createdAt }
    }

    var visibleTasks: [CalendarWorkbenchV5Task] {
        listMode == .active ? activeTasks : completedTasks
    }

    func select(_ date: Date) {
        let day = calendar.startOfDay(for: date)
        selectedDate = day
        draftDate = day
        selectedTaskID = nil
        editingTaskID = nil
        listMode = .active
        if !calendar.isDate(day, equalTo: displayedMonth, toGranularity: .month) {
            displayedMonth = day
        }
    }

    func moveMonth(by value: Int) {
        displayedMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) ?? displayedMonth
    }

    func jumpToToday() { select(today) }

    func refreshToday(now: Date = Date()) {
        let previousToday = today
        let newToday = calendar.startOfDay(for: now)
        guard !calendar.isDate(previousToday, inSameDayAs: newToday) else { return }

        let selectionFollowedToday = calendar.isDate(selectedDate, inSameDayAs: previousToday)
        let draftFollowedToday = calendar.isDate(draftDate, inSameDayAs: previousToday)
        today = newToday

        if selectionFollowedToday {
            selectedDate = newToday
            displayedMonth = newToday
        }
        if draftFollowedToday {
            draftDate = newToday
        }
    }

    func itemCount(on date: Date) -> Int {
        taskCounts(on: date).total
    }

    func taskCounts(on date: Date) -> V5DayTaskCounts {
        var active = 0
        var completed = 0
        for task in tasks where task.legacy.deletedAt == nil {
            guard task.metadata.dueDate.map({ calendar.isDate($0, inSameDayAs: date) }) == true else { continue }
            if task.legacy.isCompleted {
                completed += 1
            } else {
                active += 1
            }
        }
        return V5DayTaskCounts(active: active, completed: completed)
    }

    func addDraft() {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let reminder = draftReminderEnabled ? draftReminder : nil
        let item = TaskItem(title: title, createdAt: Date())
        tasks.insert(CalendarWorkbenchV5Task(
            legacy: item,
            metadata: V5TaskMetadata(dueDate: calendar.startOfDay(for: draftDate),
                                     details: draftDetails.trimmingCharacters(in: .whitespacesAndNewlines),
                                     reminderAt: reminder)
        ), at: 0)
        draftTitle = ""
        draftDetails = ""
        draftReminderEnabled = false
        notifyMutation()
    }

    func selectTask(id: UUID?) { selectedTaskID = id }

    func beginComposing() {
        selectedTaskID = nil
        editingTaskID = nil
    }

    func clearTaskSelection() {
        selectedTaskID = nil
    }

    func toggleListMode() {
        listMode = listMode == .active ? .completed : .active
        selectedTaskID = nil
    }

    func beginEditing(_ task: CalendarWorkbenchV5Task) {
        selectedTaskID = task.id
        editingTaskID = task.id
    }
    func endEditing() { editingTaskID = nil }

    func task(id: UUID) -> CalendarWorkbenchV5Task? {
        tasks.first(where: { $0.id == id })
    }

    /// Mirrors mutations made through the first-generation task menus while
    /// retaining any V5 companion fields already associated with each UUID.
    func replaceLegacyTasks(_ legacyTasks: [TaskItem], metadata: [UUID: V5TaskMetadata]) {
        let currentMetadata = metadataSnapshot()
        tasks = legacyTasks.map { task in
            CalendarWorkbenchV5Task(
                legacy: task,
                metadata: metadata[task.id] ?? currentMetadata[task.id] ?? V5TaskMetadata()
            )
        }
        if let selectedTaskID, !tasks.contains(where: { $0.id == selectedTaskID }) {
            self.selectedTaskID = nil
        }
        if let editingTaskID, !tasks.contains(where: { $0.id == editingTaskID }) {
            self.editingTaskID = nil
        }
    }

    func update(id: UUID, title: String, details: String, date: Date,
                reminderEnabled: Bool, reminder: Date) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        tasks[index].legacy.title = trimmed
        tasks[index].metadata.details = details.trimmingCharacters(in: .whitespacesAndNewlines)
        tasks[index].metadata.dueDate = calendar.startOfDay(for: date)
        tasks[index].metadata.reminderAt = reminderEnabled ? reminder : nil
        editingTaskID = nil
        notifyMutation()
    }

    func toggleCompletion(id: UUID) {
        guard let task = task(id: id) else { return }
        setCompletion(id: id, completed: !task.legacy.isCompleted)
    }

    func setCompletion(id: UUID, completed: Bool) {
        guard let index = tasks.firstIndex(where: { $0.id == id }),
              tasks[index].legacy.isCompleted != completed else { return }
        tasks[index].legacy.isCompleted = completed
        selectedTaskID = nil
        if editingTaskID == id { editingTaskID = nil }
        notifyMutation()
    }

    func moveTask(id: UUID, to date: Date) {
        guard let index = tasks.firstIndex(where: { $0.id == id }),
              !tasks[index].legacy.isCompleted,
              tasks[index].legacy.deletedAt == nil else { return }
        let targetDate = calendar.startOfDay(for: date)
        if tasks[index].metadata.dueDate.map({ calendar.isDate($0, inSameDayAs: targetDate) }) == true {
            return
        }
        tasks[index].metadata.dueDate = targetDate
        select(targetDate)
        notifyMutation()
    }

    /// The UI exposes this only inside the completed list's context menu.
    /// It removes exactly one completed task and its V5 metadata in one step.
    func permanentlyDeleteCompleted(id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }),
              tasks[index].legacy.isCompleted else { return }
        tasks.remove(at: index)
        if selectedTaskID == id { selectedTaskID = nil }
        if editingTaskID == id { editingTaskID = nil }
        notifyMutation()
    }

    func legacySnapshot() -> [TaskItem] { tasks.map(\.legacy) }
    func metadataSnapshot() -> [UUID: V5TaskMetadata] {
        Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0.metadata) })
    }

    private func notifyMutation() {
        onMutation?(legacySnapshot(), metadataSnapshot())
    }

    private func matchesSelection(_ task: CalendarWorkbenchV5Task) -> Bool {
        guard let dueDate = task.metadata.dueDate else { return true }
        return calendar.isDate(dueDate, inSameDayAs: selectedDate)
    }

    private static func previewTasks(today: Date, calendar: Calendar, longList: Bool) -> [TaskItem] {
        let base = [
            TaskItem(title: "确认 V5 月历交互", priority: .high, tag: "产品"),
            TaskItem(title: "整理本周开发重点", priority: .medium, tag: "工作"),
            TaskItem(title: "晚上散步 30 分钟", priority: .low, tag: "生活"),
            TaskItem(title: "复核浅色与深色效果", isCompleted: true, priority: .medium, tag: "检查")
        ]
        guard longList else { return base }
        return base + (1...18).map { TaskItem(title: "长列表测试任务 \($0)", priority: $0 % 3 == 0 ? .high : .medium, tag: "测试") }
    }

    private static func previewMetadata(for task: TaskItem, today: Date, calendar: Calendar) -> V5TaskMetadata {
        let offset = abs(task.id.hashValue) % 3
        let date = calendar.date(byAdding: .day, value: offset == 2 ? 1 : 0, to: today) ?? today
        let details = task.title.contains("散步") ? "不带手机，沿河走一圈。" : (task.title.contains("V5") ? "走完悬停、选择、新增、编辑与完成恢复。" : "")
        return V5TaskMetadata(dueDate: date, details: details, reminderAt: nil)
    }

    private static let monthFormatter: DateFormatter = {
        let value = DateFormatter(); value.locale = Locale(identifier: "zh_CN"); value.dateFormat = "yyyy年 M月"; return value
    }()
    private static let selectionFormatter: DateFormatter = {
        let value = DateFormatter(); value.locale = Locale(identifier: "zh_CN"); value.dateFormat = "M月d日 EEEE"; return value
    }()
}
