import Foundation

@main
struct TaskReminderSmoke {
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let now = calendar.date(from: DateComponents(
            year: 2026,
            month: 9,
            day: 4,
            hour: 10
        ))!
        let future = calendar.date(byAdding: .hour, value: 2, to: now)!
        let past = calendar.date(byAdding: .hour, value: -2, to: now)!

        let activeID = UUID(uuidString: "00000000-0000-0000-0000-000000000021")!
        let completedID = UUID(uuidString: "00000000-0000-0000-0000-000000000022")!
        let pastID = UUID(uuidString: "00000000-0000-0000-0000-000000000023")!
        let deletedID = UUID(uuidString: "00000000-0000-0000-0000-000000000024")!
        let tasks = [
            TaskItem(id: activeID, title: "未来提醒"),
            TaskItem(id: completedID, title: "已完成", isCompleted: true),
            TaskItem(id: pastID, title: "过期提醒"),
            TaskItem(id: deletedID, title: "已删除", deletedAt: now)
        ]
        let metadata: [UUID: V5TaskMetadata] = [
            activeID: V5TaskMetadata(reminderAt: future),
            completedID: V5TaskMetadata(reminderAt: future),
            pastID: V5TaskMetadata(reminderAt: past),
            deletedID: V5TaskMetadata(reminderAt: future)
        ]

        let planned = V5TaskReminderPlanner.pendingRequests(
            tasks: tasks,
            metadata: metadata,
            now: now,
            calendar: calendar
        )
        precondition(planned.count == 1,
                     "only future reminders for unfinished, non-deleted tasks are scheduled")
        precondition(planned[0].id == activeID)
        precondition(planned[0].title == "未来提醒")
        precondition(planned[0].fireDate == future)
        precondition(V5TaskReminderPlanner.identifier(for: activeID) ==
                     "com.desktopsentry.task.\(activeID.uuidString)")

        let nextHalfHour = V5TaskReminderPlanner.defaultReminder(
            forDueDate: now,
            now: now,
            calendar: calendar
        )
        precondition(nextHalfHour > now)
        precondition(calendar.component(.minute, from: nextHalfHour) == 30,
                     "enabling a reminder late in the day must choose the next future half-hour")
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        let tomorrowDefault = V5TaskReminderPlanner.defaultReminder(
            forDueDate: tomorrow,
            now: now,
            calendar: calendar
        )
        precondition(calendar.component(.hour, from: tomorrowDefault) == 9)
        precondition(calendar.component(.minute, from: tomorrowDefault) == 0)
        precondition(V5TaskReminderPlanner.isSchedulable(future, now: now))
        precondition(!V5TaskReminderPlanner.isSchedulable(past, now: now))

        print("Task reminder smoke passed")
    }
}
