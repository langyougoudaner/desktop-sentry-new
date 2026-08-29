import Foundation

@main
struct CalendarWorkbenchV21CleanSmoke {
    @MainActor
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        calendar.firstWeekday = 1

        let now = calendar.date(from: DateComponents(
            year: 2026, month: 8, day: 23, hour: 12
        ))!
        let model = CalendarWorkbenchV21CleanModel(now: now, calendar: calendar)

        precondition(model.monthDays.count == 42)
        precondition(model.weekdaySymbols.count == 7)
        precondition(model.visibleItems.count == 4)
        precondition(model.selectedDate == nil)

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        model.select(tomorrow)
        precondition(model.visibleItems.count == 1)
        precondition(model.itemCount(on: tomorrow) == 1)

        model.moveMonth(by: 1)
        precondition(model.selectedDate == nil)
        precondition(calendar.component(.month, from: model.displayedMonth) == 9)

        model.jumpToToday()
        precondition(calendar.isDate(model.selectedDate!, inSameDayAs: now))

        let nextDay = calendar.date(byAdding: .day, value: 1, to: now)!
        model.refreshToday(now: nextDay)
        precondition(calendar.isDate(model.today, inSameDayAs: nextDay))

        print("CalendarWorkbenchV21CleanSmoke passed")
    }
}
