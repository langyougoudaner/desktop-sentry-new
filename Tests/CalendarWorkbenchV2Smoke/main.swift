import Foundation

@main
@MainActor
struct CalendarWorkbenchV2Smoke {
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError(message) }
    }

    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(calendar: calendar, year: 2026, month: 8, day: 21, hour: 10))!
        let model = CalendarWorkbenchV2Model(now: now, calendar: calendar)

        require(model.mode == .todo, "V2 首次模式不是待办")
        require(model.tasks.contains { $0.notificationEnabled }, "样例没有通知开启项目")
        require(model.tasks.contains { $0.isCompleted }, "样例没有已完成项目")
        require(model.tasks.contains { $0.isImportant }, "样例没有重点项目")

        model.select(date: now)
        model.todoDraft = "临时待办"
        model.addTodo()
        require(model.filteredTasks.contains {
            $0.title == "临时待办" && $0.date.map { calendar.isDate($0, inSameDayAs: now) } == true
        }, "待办没有预填选择日期")

        model.mode = .countdown
        model.startCountdown()
        model.countdownDraft = "临时倒数日"
        model.countdownDate = calendar.date(byAdding: .day, value: 4, to: now)!
        model.countdownNotificationEnabled = true
        model.addCountdown()
        require(model.tasks.contains { $0.title == "临时倒数日" && $0.isCountdown && $0.notificationEnabled }, "倒数日原位新增失败")

        let taskID = model.tasks.first { $0.title == "临时倒数日" }!.id
        model.toggleCompleted(id: taskID)
        require(model.tasks.first { $0.id == taskID }!.isCompleted, "完成状态没有更新")
        model.undoLastCompletion()
        require(!(model.tasks.first { $0.id == taskID }!.isCompleted), "完成撤销失败")
        model.rename(id: taskID, title: "改名后的倒数日")
        require(model.tasks.first { $0.id == taskID }!.title == "改名后的倒数日", "栏内编辑失败")

        model.showAll()
        require(model.selectedDate == nil, "显示全部没有清除日期过滤")
        print("calendar-workbench-v2-model=passed")
        print("calendar-workbench-v2-isolation=memory-only")
    }
}
