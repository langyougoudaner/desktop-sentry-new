import Foundation
import Combine

enum CalendarWorkbenchMode: String, CaseIterable, Identifiable {
    case countdown
    case todo

    var id: String { rawValue }

    var title: String {
        switch self {
        case .countdown: return "倒数日"
        case .todo: return "待办"
        }
    }
}

struct CalendarWorkbenchTask: Identifiable, Hashable {
    let id: UUID
    var title: String
    var date: Date?
    var isCompleted: Bool
    var isImportant: Bool
    var notificationEnabled: Bool
    var notificationTime: String?
    var isCountdown: Bool
    var sortOrder: Int

    init(id: UUID = UUID(), title: String, date: Date? = nil,
         isCompleted: Bool = false, isImportant: Bool = false,
         notificationEnabled: Bool = false, notificationTime: String? = nil,
         isCountdown: Bool = false, sortOrder: Int = 0) {
        self.id = id
        self.title = title
        self.date = date
        self.isCompleted = isCompleted
        self.isImportant = isImportant
        self.notificationEnabled = notificationEnabled
        self.notificationTime = notificationTime
        self.isCountdown = isCountdown
        self.sortOrder = sortOrder
    }
}

@MainActor
final class CalendarWorkbenchV2Model: ObservableObject {
    @Published var displayedMonth: Date
    @Published var selectedDate: Date?
    @Published var mode: CalendarWorkbenchMode = .todo
    @Published private(set) var tasks: [CalendarWorkbenchTask]
    @Published var todoDraft = ""
    @Published var countdownDraft = ""
    @Published var countdownDate: Date
    @Published var countdownNotificationEnabled = false
    @Published var countdownNotificationTime = Date()
    @Published var isAddingCountdown = false
    @Published private(set) var lastCompletedTask: CalendarWorkbenchTask?

    let calendar: Calendar
    let today: Date

    init(now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
        let day = calendar.startOfDay(for: now)
        today = day
        displayedMonth = day
        selectedDate = nil
        countdownDate = calendar.date(byAdding: .day, value: 7, to: day) ?? day
        countdownNotificationTime = calendar.date(bySettingHour: 9, minute: 30, second: 0, of: day) ?? day
        tasks = Self.samples(today: day, calendar: calendar)
    }

    var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: displayedMonth)
    }

    var filteredTasks: [CalendarWorkbenchTask] {
        let source = tasks.filter { $0.isCountdown == (mode == .countdown) }
        let filtered: [CalendarWorkbenchTask]
        if let selectedDate {
            let day = calendar.startOfDay(for: selectedDate)
            filtered = source.filter { task in
                guard let date = task.date else { return false }
                return calendar.isDate(date, inSameDayAs: day)
            }
        } else {
            filtered = source
        }
        return filtered.sorted { lhs, rhs in
            if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
            if lhs.isImportant != rhs.isImportant { return lhs.isImportant }
            if let leftDate = lhs.date, let rightDate = rhs.date, leftDate != rightDate {
                return leftDate < rightDate
            }
            if lhs.date != nil { return true }
            if rhs.date != nil { return false }
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    var activeTaskCount: Int {
        filteredTasks.filter { !$0.isCompleted }.count
    }

    func select(date: Date?) {
        selectedDate = date.map { calendar.startOfDay(for: $0) }
    }

    func showAll() {
        selectedDate = nil
    }

    func moveMonth(by value: Int) {
        displayedMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) ?? displayedMonth
        selectedDate = nil
    }

    func jumpToToday() {
        displayedMonth = today
        selectedDate = today
    }

    func addTodo() {
        let title = todoDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let maxOrder = tasks.map(\.sortOrder).max() ?? 0
        tasks.append(CalendarWorkbenchTask(title: title,
                                           date: selectedDate,
                                           isImportant: false,
                                           isCountdown: false,
                                           sortOrder: maxOrder + 1))
        todoDraft = ""
    }

    func startCountdown() {
        isAddingCountdown = true
        if countdownDate < today {
            countdownDate = calendar.date(byAdding: .day, value: 7, to: today) ?? today
        }
    }

    func addCountdown() {
        let title = countdownDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let components = calendar.dateComponents([.hour, .minute], from: countdownNotificationTime)
        let time = countdownNotificationEnabled
            ? String(format: "%02d:%02d", components.hour ?? 9, components.minute ?? 30)
            : nil
        let maxOrder = tasks.map(\.sortOrder).max() ?? 0
        tasks.append(CalendarWorkbenchTask(title: title,
                                           date: calendar.startOfDay(for: countdownDate),
                                           isImportant: false,
                                           notificationEnabled: countdownNotificationEnabled,
                                           notificationTime: time,
                                           isCountdown: true,
                                           sortOrder: maxOrder + 1))
        countdownDraft = ""
        countdownNotificationEnabled = false
        isAddingCountdown = false
    }

    func cancelCountdown() {
        countdownDraft = ""
        countdownNotificationEnabled = false
        isAddingCountdown = false
    }

    func toggleCompleted(id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        let wasCompleted = tasks[index].isCompleted
        tasks[index].isCompleted.toggle()
        if !wasCompleted { lastCompletedTask = tasks[index] }
    }

    func undoLastCompletion() {
        guard let lastCompletedTask,
              let index = tasks.firstIndex(where: { $0.id == lastCompletedTask.id }) else { return }
        tasks[index].isCompleted = false
        self.lastCompletedTask = nil
    }

    func clearUndo() {
        lastCompletedTask = nil
    }

    func toggleImportant(id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].isImportant.toggle()
    }

    func rename(id: UUID, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].title = trimmed
    }

    func move(id: UUID, before targetID: UUID) {
        guard id != targetID,
              let sourceIndex = tasks.firstIndex(where: { $0.id == id }),
              let targetIndex = tasks.firstIndex(where: { $0.id == targetID }),
              tasks[sourceIndex].isCountdown == tasks[targetIndex].isCountdown else { return }
        let item = tasks.remove(at: sourceIndex)
        let adjustedTarget = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
        tasks.insert(item, at: max(0, min(adjustedTarget, tasks.count)))
        for index in tasks.indices { tasks[index].sortOrder = index }
    }

    func taskCount(on date: Date) -> Int {
        tasks.filter { task in
            guard let taskDate = task.date else { return false }
            return calendar.isDate(taskDate, inSameDayAs: date)
        }.count
    }

    func task(on date: Date) -> CalendarWorkbenchTask? {
        tasks.first { task in
            guard let taskDate = task.date else { return false }
            return calendar.isDate(taskDate, inSameDayAs: date)
        }
    }

    private static func samples(today: Date, calendar: Calendar) -> [CalendarWorkbenchTask] {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let inThreeDays = calendar.date(byAdding: .day, value: 3, to: today) ?? today
        let inFiveDays = calendar.date(byAdding: .day, value: 5, to: today) ?? today
        let inTenDays = calendar.date(byAdding: .day, value: 10, to: today) ?? today
        return [
            CalendarWorkbenchTask(title: "今天提交演示稿", date: today, isImportant: true, sortOrder: 0),
            CalendarWorkbenchTask(title: "整理客户评审要点", date: today, sortOrder: 1),
            CalendarWorkbenchTask(title: "已逾期的预算确认", date: yesterday, sortOrder: 2),
            CalendarWorkbenchTask(title: "明日客户评审", date: tomorrow, notificationEnabled: true,
                                 notificationTime: "09:30", sortOrder: 3),
            CalendarWorkbenchTask(title: "周会材料已完成", date: inThreeDays, isCompleted: true, sortOrder: 4),
            CalendarWorkbenchTask(title: "下周发布窗口", date: inFiveDays, isImportant: true, sortOrder: 5),
            CalendarWorkbenchTask(title: "季度复盘", date: inTenDays, notificationEnabled: true,
                                 notificationTime: "18:00", isCountdown: true, sortOrder: 6),
            CalendarWorkbenchTask(title: "朋友生日", date: calendar.date(byAdding: .day, value: 18, to: today),
                                 notificationEnabled: true, notificationTime: "08:00", isCountdown: true, sortOrder: 7)
        ]
    }
}

enum CalendarWorkbenchLunar {
    private static var chineseCalendar: Calendar = {
        var calendar = Calendar(identifier: .chinese)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }()

    static func shortLabel(for date: Date) -> String {
        let components = chineseCalendar.dateComponents([.month, .day, .isLeapMonth], from: date)
        guard let month = components.month, let day = components.day else { return "" }
        let prefix = components.isLeapMonth == true ? "闰" : ""
        if day == 1 { return "\(prefix)\(monthName(month))月" }
        return dayName(day)
    }

    static func festival(for date: Date) -> String? {
        let components = chineseCalendar.dateComponents([.month, .day], from: date)
        guard let month = components.month, let day = components.day else { return nil }
        switch (month, day) {
        case (1, 1): return "春节"
        case (1, 15): return "元宵节"
        case (5, 5): return "端午节"
        case (7, 7): return "七夕"
        case (7, 15): return "中元节"
        case (8, 15): return "中秋节"
        case (9, 9): return "重阳节"
        case (12, 8): return "腊八节"
        default: return nil
        }
    }

    private static func monthName(_ month: Int) -> String {
        ["", "正", "二", "三", "四", "五", "六", "七", "八", "九", "十", "冬", "腊"][safe: month] ?? ""
    }

    private static func dayName(_ day: Int) -> String {
        let names = ["", "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
                     "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
                     "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"]
        return names[safe: day] ?? ""
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
