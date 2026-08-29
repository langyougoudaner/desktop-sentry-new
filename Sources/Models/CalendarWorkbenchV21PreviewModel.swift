import Foundation
import Combine

enum CalendarWorkbenchV21Mode: String, CaseIterable, Identifiable {
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

enum CalendarWorkbenchV21CountdownRepeat: String, CaseIterable, Identifiable {
    case none = "不重复"
    case weekly = "每周"
    case yearly = "每年"

    var id: String { rawValue }
}

struct CalendarWorkbenchV21Color: Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double = 1

    static let presets: [CalendarWorkbenchV21Color] = [
        .init(red: 0.05, green: 0.48, blue: 1.00),
        .init(red: 1.00, green: 0.48, blue: 0.16),
        .init(red: 1.00, green: 0.20, blue: 0.38),
        .init(red: 0.69, green: 0.22, blue: 0.93),
        .init(red: 0.18, green: 0.78, blue: 0.38)
    ]
}

struct CalendarWorkbenchV21Countdown: Identifiable, Hashable {
    let id: UUID
    var title: String
    var date: Date
    var repeatRule: CalendarWorkbenchV21CountdownRepeat
    var includesToday: Bool
    var usesIcon: Bool
    var color: CalendarWorkbenchV21Color

    init(id: UUID = UUID(), title: String, date: Date,
         repeatRule: CalendarWorkbenchV21CountdownRepeat = .none,
         includesToday: Bool = false, usesIcon: Bool = false,
         color: CalendarWorkbenchV21Color = CalendarWorkbenchV21Color.presets[0]) {
        self.id = id
        self.title = title
        self.date = date
        self.repeatRule = repeatRule
        self.includesToday = includesToday
        self.usesIcon = usesIcon
        self.color = color
    }
}

struct CalendarWorkbenchV21Task: Identifiable, Hashable {
    let id: UUID
    var title: String
    var date: Date?
    var isCompleted: Bool
    let isImportant: Bool
    var reminderAt: Date?
    var details: String

    var hasReminder: Bool { reminderAt != nil }

    init(id: UUID = UUID(), title: String, date: Date?, isCompleted: Bool = false,
         isImportant: Bool = false, reminderAt: Date? = nil, details: String = "") {
        self.id = id
        self.title = title
        self.date = date
        self.isCompleted = isCompleted
        self.isImportant = isImportant
        self.reminderAt = reminderAt
        self.details = details
    }
}

@MainActor
final class CalendarWorkbenchV21PreviewModel: ObservableObject {
    @Published var displayedMonth: Date
    @Published var selectedDate: Date?
    @Published var mode: CalendarWorkbenchV21Mode = .todo
    @Published var selectedTaskID: UUID?

    let calendar: Calendar
    let today: Date
    @Published private(set) var tasks: [CalendarWorkbenchV21Task]
    @Published private(set) var countdowns: [CalendarWorkbenchV21Countdown]

    init(now: Date = Date(), calendar: Calendar = .autoupdatingCurrent,
         initialSelectionOffset: Int? = nil) {
        self.calendar = calendar
        let start = calendar.startOfDay(for: now)
        today = start
        displayedMonth = start
        if let initialSelectionOffset {
            selectedDate = calendar.date(byAdding: .day, value: initialSelectionOffset, to: start)
        } else {
            selectedDate = nil
        }
        tasks = Self.makeSamples(today: start, calendar: calendar)
        countdowns = Self.makeCountdownSamples(today: start, calendar: calendar)
    }

    var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年 M月"
        return formatter.string(from: displayedMonth)
    }

    var selectedDateTitle: String {
        guard let selectedDate else { return mode == .todo ? "全部待办" : "全部倒数日" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: selectedDate)
    }

    var visibleTasks: [CalendarWorkbenchV21Task] {
        guard let selectedDate else { return tasks }
        return tasks.filter { task in
            guard let date = task.date else { return false }
            return calendar.isDate(date, inSameDayAs: selectedDate)
        }
    }

    var visibleCountdowns: [CalendarWorkbenchV21Countdown] {
        guard let selectedDate else { return countdowns }
        return countdowns.filter { countdown in
            calendar.isDate(nextOccurrence(for: countdown), inSameDayAs: selectedDate)
        }
    }

    var activeTasks: [CalendarWorkbenchV21Task] {
        visibleTasks.filter { !$0.isCompleted }
    }

    var completedTasks: [CalendarWorkbenchV21Task] {
        visibleTasks.filter(\.isCompleted)
    }

    var quickAddDateTitle: String {
        let date = selectedDate ?? today
        if calendar.isDateInToday(date) { return "今天" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }

    func select(_ date: Date) {
        selectedDate = calendar.startOfDay(for: date)
    }

    func selectAndReveal(_ date: Date) {
        let normalized = calendar.startOfDay(for: date)
        selectedDate = normalized
        if !calendar.isDate(normalized, equalTo: displayedMonth, toGranularity: .month) {
            displayedMonth = normalized
        }
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

    func addTask(title: String, date: Date? = nil, reminderAt: Date? = nil,
                 schedulesReminder: Bool = true) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let dueDate = date ?? selectedDate ?? today
        let task = CalendarWorkbenchV21Task(
            title: trimmed,
            date: dueDate,
            reminderAt: schedulesReminder ? (reminderAt ?? endOfDayReminder(for: dueDate)) : nil
        )
        tasks.insert(task, at: 0)
        selectedTaskID = task.id
    }

    func selectTask(id: UUID) {
        selectedTaskID = id
    }

    func addCountdown(title: String, date: Date,
                      repeatRule: CalendarWorkbenchV21CountdownRepeat,
                      includesToday: Bool, usesIcon: Bool,
                      color: CalendarWorkbenchV21Color) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        countdowns.insert(
            CalendarWorkbenchV21Countdown(
                title: trimmed,
                date: calendar.startOfDay(for: date),
                repeatRule: repeatRule,
                includesToday: includesToday,
                usesIcon: usesIcon,
                color: color
            ),
            at: 0
        )
    }

    func updateCountdown(id: UUID, title: String, date: Date,
                         repeatRule: CalendarWorkbenchV21CountdownRepeat,
                         includesToday: Bool, usesIcon: Bool,
                         color: CalendarWorkbenchV21Color) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = countdowns.firstIndex(where: { $0.id == id }) else { return }
        countdowns[index].title = trimmed
        countdowns[index].date = calendar.startOfDay(for: date)
        countdowns[index].repeatRule = repeatRule
        countdowns[index].includesToday = includesToday
        countdowns[index].usesIcon = usesIcon
        countdowns[index].color = color
    }

    func deleteCountdown(id: UUID) {
        countdowns.removeAll { $0.id == id }
    }

    func moveCountdown(id: UUID, by offset: Int) {
        guard let source = countdowns.firstIndex(where: { $0.id == id }) else { return }
        let target = min(max(source + offset, 0), countdowns.count - 1)
        guard source != target else { return }
        let item = countdowns.remove(at: source)
        countdowns.insert(item, at: target)
    }

    func updateTaskSchedule(id: UUID, date: Date?, reminderAt: Date?) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].date = date.map { calendar.startOfDay(for: $0) }
        tasks[index].reminderAt = reminderAt
    }

    func updateTaskDetails(id: UUID, details: String) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].details = details.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func countdownText(for countdown: CalendarWorkbenchV21Countdown) -> String {
        let occurrence = nextOccurrence(for: countdown)
        let days = calendar.dateComponents(
            [.day], from: today, to: calendar.startOfDay(for: occurrence)
        ).day ?? 0
        if days < 0 { return "已过 \(abs(days)) 天" }
        if days == 0 { return countdown.includesToday ? "倒计时 1 天" : "今天" }
        return "倒计时 \(days + (countdown.includesToday ? 1 : 0)) 天"
    }

    func nextOccurrence(for countdown: CalendarWorkbenchV21Countdown) -> Date {
        let target = calendar.startOfDay(for: countdown.date)
        guard target < today else { return target }
        switch countdown.repeatRule {
        case .none:
            return target
        case .weekly:
            let elapsed = calendar.dateComponents([.day], from: target, to: today).day ?? 0
            let weeks = max(1, Int(ceil(Double(elapsed) / 7.0)))
            return calendar.date(byAdding: .day, value: weeks * 7, to: target) ?? target
        case .yearly:
            let targetParts = calendar.dateComponents([.month, .day], from: target)
            let year = calendar.component(.year, from: today)
            var parts = DateComponents(year: year, month: targetParts.month, day: targetParts.day)
            var occurrence = calendar.date(from: parts) ?? target
            if occurrence < today {
                parts.year = year + 1
                occurrence = calendar.date(from: parts) ?? occurrence
            }
            return occurrence
        }
    }

    func toggleCompletion(id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].isCompleted.toggle()
    }

    func endOfDayReminder(for date: Date) -> Date {
        calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))
            ?? date.addingTimeInterval(24 * 3600)
    }

    func itemCount(on date: Date) -> Int {
        let taskCount = tasks.filter { task in
            guard let taskDate = task.date else { return false }
            return calendar.isDate(taskDate, inSameDayAs: date)
        }.count
        let countdownCount = countdowns.filter {
            calendar.isDate(nextOccurrence(for: $0), inSameDayAs: date)
        }.count
        return taskCount + countdownCount
    }

    private static func makeSamples(today: Date, calendar: Calendar) -> [CalendarWorkbenchV21Task] {
        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: today) ?? today
        }
        return [
            CalendarWorkbenchV21Task(
                title: "提交视觉重置方案",
                date: today,
                isImportant: true,
                details: "核对浅色、深色、日期五状态与菜单栏呼出路径。"
            ),
            CalendarWorkbenchV21Task(
                title: "整理客户评审要点",
                date: today,
                details: "归纳客户反馈，并把需要确认的项目整理成一页清单。"
            ),
            CalendarWorkbenchV21Task(
                title: "明日产品评审",
                date: day(1),
                reminderAt: calendar.date(byAdding: .day, value: 2, to: today)
            ),
            CalendarWorkbenchV21Task(title: "准备发布清单", date: day(4)),
            CalendarWorkbenchV21Task(title: "周会材料已完成", date: day(6), isCompleted: true),
        ]
    }

    private static func makeCountdownSamples(today: Date, calendar: Calendar) -> [CalendarWorkbenchV21Countdown] {
        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: today) ?? today
        }
        return [
            CalendarWorkbenchV21Countdown(
                title: "季度复盘",
                date: day(10),
                includesToday: true,
                usesIcon: true,
                color: CalendarWorkbenchV21Color.presets[0]
            ),
            CalendarWorkbenchV21Countdown(
                title: "朋友生日",
                date: day(18),
                repeatRule: .yearly,
                color: CalendarWorkbenchV21Color.presets[2]
            )
        ]
    }
}

enum CalendarWorkbenchV21Lunar {
    private static var chineseCalendar: Calendar = {
        var calendar = Calendar(identifier: .chinese)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }()

    static func label(for date: Date) -> String {
        if let festival = festival(for: date) { return festival }
        if let holiday = CalendarWorkbenchV21Holiday.info(for: date)?.name { return holiday }
        let components = chineseCalendar.dateComponents([.month, .day, .isLeapMonth], from: date)
        guard let month = components.month, let day = components.day else { return "" }
        if day == 1 {
            let prefix = components.isLeapMonth == true ? "闰" : ""
            return "\(prefix)\(monthName(month))月"
        }
        return dayName(day)
    }

    static func isFestival(_ date: Date) -> Bool {
        festival(for: date) != nil || CalendarWorkbenchV21Holiday.info(for: date)?.name != nil
    }

    private static func festival(for date: Date) -> String? {
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
        let names = ["", "正", "二", "三", "四", "五", "六", "七", "八", "九", "十", "冬", "腊"]
        return names.indices.contains(month) ? names[month] : ""
    }

    private static func dayName(_ day: Int) -> String {
        let names = ["", "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
                     "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
                     "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"]
        return names.indices.contains(day) ? names[day] : ""
    }
}

enum CalendarWorkbenchV21Holiday {
    enum DayType {
        case rest
        case work

        var shortLabel: String { self == .rest ? "休" : "班" }
    }

    struct Info {
        let type: DayType
        let name: String?
    }

    /// Official 2026 holiday/workday arrangement published by the General
    /// Office of the State Council (2025-11-04). Years without an official
    /// table intentionally show no guessed rest/work marker.
    private static let official2026: [String: Info] = {
        var values: [String: Info] = [:]
        func rest(_ dates: [String], _ name: String) {
            dates.forEach { values[$0] = Info(type: .rest, name: name) }
        }
        func work(_ dates: [String]) {
            dates.forEach { values[$0] = Info(type: .work, name: nil) }
        }
        rest(["2026-01-01", "2026-01-02", "2026-01-03"], "元旦")
        work(["2026-01-04"])
        rest((15...23).map { String(format: "2026-02-%02d", $0) }, "春节")
        work(["2026-02-14", "2026-02-28"])
        rest((4...6).map { String(format: "2026-04-%02d", $0) }, "清明节")
        rest((1...5).map { String(format: "2026-05-%02d", $0) }, "劳动节")
        work(["2026-05-09"])
        rest((19...21).map { String(format: "2026-06-%02d", $0) }, "端午节")
        rest((25...27).map { String(format: "2026-09-%02d", $0) }, "中秋节")
        work(["2026-09-20"])
        rest((1...7).map { String(format: "2026-10-%02d", $0) }, "国庆节")
        work(["2026-10-10"])
        return values
    }()

    static func info(for date: Date) -> Info? {
        official2026[dateKey(date)]
    }

    private static func dateKey(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
