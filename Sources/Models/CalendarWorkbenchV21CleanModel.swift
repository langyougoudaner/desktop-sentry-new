import Foundation
import Combine

struct CalendarWorkbenchV21CleanItem: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let date: Date
    let isImportant: Bool
}

@MainActor
final class CalendarWorkbenchV21CleanModel: ObservableObject {
    @Published private(set) var today: Date
    @Published var displayedMonth: Date
    @Published var selectedDate: Date?

    let calendar: Calendar
    private(set) var items: [CalendarWorkbenchV21CleanItem]

    init(now: Date = Date(), calendar: Calendar = .autoupdatingCurrent,
         initialSelectionOffset: Int? = nil) {
        self.calendar = calendar
        let start = calendar.startOfDay(for: now)
        today = start
        displayedMonth = start
        selectedDate = initialSelectionOffset.flatMap {
            calendar.date(byAdding: .day, value: $0, to: start)
        }
        items = Self.makeItems(today: start, calendar: calendar)
    }

    var monthTitle: String {
        Self.monthFormatter.string(from: displayedMonth)
    }

    var selectionTitle: String {
        guard let selectedDate else { return "本月安排" }
        return Self.selectionFormatter.string(from: selectedDate)
    }

    var visibleItems: [CalendarWorkbenchV21CleanItem] {
        guard let selectedDate else { return items }
        return items.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    var monthDays: [Date] {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        let start = calendar.date(byAdding: .day, value: -leading, to: interval.start)
            ?? interval.start
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    var weekdaySymbols: [String] {
        let raw = Self.weekdayFormatter.shortStandaloneWeekdaySymbols ?? []
        let compact = raw.map { value -> String in
            if value.hasPrefix("星期") { return String(value.dropFirst(2)) }
            if value.hasPrefix("周") { return String(value.dropFirst()) }
            return value
        }
        guard !compact.isEmpty else { return [] }
        let start = max(0, min(compact.count - 1, calendar.firstWeekday - 1))
        return Array(compact[start...]) + Array(compact[..<start])
    }

    func select(_ date: Date) {
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
        displayedMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth)
            ?? displayedMonth
        selectedDate = nil
    }

    func jumpToToday() {
        displayedMonth = today
        selectedDate = today
    }

    func refreshToday(now: Date = Date()) {
        let newToday = calendar.startOfDay(for: now)
        guard newToday != today else { return }
        today = newToday
    }

    func itemCount(on date: Date) -> Int {
        items.filter { calendar.isDate($0.date, inSameDayAs: date) }.count
    }

    private static func makeItems(today: Date, calendar: Calendar) -> [CalendarWorkbenchV21CleanItem] {
        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: today) ?? today
        }
        return [
            .init(title: "确认月历视觉与比例", date: today, isImportant: true),
            .init(title: "整理下一轮开发重点", date: today, isImportant: false),
            .init(title: "检查浅色与深色表现", date: day(1), isImportant: false),
            .init(title: "复核日期五种状态", date: day(4), isImportant: false)
        ]
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年 M月"
        return formatter
    }()

    private static let selectionFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
}
