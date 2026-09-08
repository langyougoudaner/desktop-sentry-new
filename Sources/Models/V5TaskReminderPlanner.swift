import Foundation

struct V5TaskReminderRequest: Equatable {
    let id: UUID
    let title: String
    let fireDate: Date
    let dateComponents: DateComponents
}

enum V5TaskReminderPlanner {
    static let identifierPrefix = "com.desktopsentry.task."

    static func pendingRequests(
        tasks: [TaskItem],
        metadata: [UUID: V5TaskMetadata],
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> [V5TaskReminderRequest] {
        tasks.compactMap { task in
            guard !task.isCompleted,
                  task.deletedAt == nil,
                  let fireDate = metadata[task.id]?.reminderAt,
                  fireDate > now else { return nil }
            return V5TaskReminderRequest(
                id: task.id,
                title: task.title,
                fireDate: fireDate,
                dateComponents: calendar.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: fireDate
                )
            )
        }
        .sorted { lhs, rhs in
            if lhs.fireDate != rhs.fireDate { return lhs.fireDate < rhs.fireDate }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    static func identifier(for id: UUID) -> String {
        identifierPrefix + id.uuidString
    }

    static func isSchedulable(_ reminder: Date, now: Date = Date()) -> Bool {
        reminder > now
    }

    /// A future due day starts at 09:00. For today or an overdue date whose
    /// 09:00 has passed, choose the next half-hour boundary instead of 00:00.
    static func defaultReminder(
        forDueDate dueDate: Date,
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> Date {
        let nineAM = calendar.date(
            bySettingHour: 9,
            minute: 0,
            second: 0,
            of: dueDate
        ) ?? dueDate
        if nineAM > now { return nineAM }

        let minute = calendar.component(.minute, from: now)
        let minutesToAdd = minute < 30 ? 30 - minute : 60 - minute
        let rounded = calendar.date(byAdding: .minute, value: minutesToAdd, to: now)
            ?? now.addingTimeInterval(Double(minutesToAdd * 60))
        return calendar.date(
            bySettingHour: calendar.component(.hour, from: rounded),
            minute: calendar.component(.minute, from: rounded),
            second: 0,
            of: rounded
        ) ?? rounded
    }
}
