import Combine
import Foundation

@main
struct V5TaskDateMovementAdversarial {
    @MainActor
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let today = calendar.date(from: DateComponents(
            year: 2026, month: 9, day: 7, hour: 12
        ))!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let future = calendar.date(byAdding: .day, value: 6, to: today)!
        let taskID = UUID(uuidString: "00000000-0000-0000-0000-000000000071")!
        let reminder = calendar.date(from: DateComponents(
            year: 2026, month: 9, day: 7, hour: 18
        ))!
        let model = CalendarWorkbenchV5Model(
            now: today,
            tasks: [TaskItem(id: taskID, title: "日期对抗测试")],
            metadata: [taskID: V5TaskMetadata(dueDate: today, reminderAt: reminder)]
        )
        let staleRowSnapshot = model.task(id: taskID)!
        var mutations = 0
        model.onMutation = { _, _ in mutations += 1 }

        precondition(!model.canMoveTask(id: taskID, to: today),
                     "same-day release is a no-op")
        guard let futureMove = model.moveTask(id: taskID, to: future) else {
            preconditionFailure("a legal drop must commit exactly one date transaction")
        }
        precondition(calendar.isDate(futureMove.sourceDate, inSameDayAs: today))
        precondition(calendar.isDate(futureMove.targetDate, inSameDayAs: future))
        precondition(model.task(id: taskID)?.metadata.dueDate.map {
            calendar.isDate($0, inSameDayAs: future)
        } == true)
        precondition(model.activeTasks.map(\.id) == [taskID])

        guard let todayMove = model.moveTask(id: taskID, to: today) else {
            preconditionFailure("a task moved forward must be movable back to today")
        }
        precondition(calendar.isDate(todayMove.sourceDate, inSameDayAs: future))
        precondition(calendar.isDate(todayMove.targetDate, inSameDayAs: today))
        precondition(model.isTodaySelected)
        precondition(model.activeTasks.map(\.id) == [taskID],
                     "7 -> 13 -> 7 must restore today's task")

        guard let overdueMove = model.moveTask(id: taskID, to: yesterday) else {
            preconditionFailure("moving a current task to a historical date must commit")
        }
        precondition(calendar.isDate(overdueMove.sourceDate, inSameDayAs: today))
        precondition(calendar.isDate(overdueMove.targetDate, inSameDayAs: yesterday))
        precondition(model.isTodaySelected)
        precondition(model.shouldShowOverdueSection)
        precondition(model.overdueTasks.map(\.id) == [taskID],
                     "7 -> 13 -> 6 must become overdue immediately")
        precondition(model.activeTasks.isEmpty,
                     "the same overdue task must not also appear in today's section")
        precondition(model.taskCounts(on: yesterday).active == 1)
        let movedRow = V5TaskRowStatusPresentation.resolve(
            task: model.task(id: taskID)!,
            today: model.today,
            calendar: model.calendar
        )
        precondition(movedRow.dateText == "9月6日",
                     "the visible badge must read the reassigned date in the same transaction")
        precondition(movedRow.isOverdue,
                     "the badge accent and section status must derive from the same live task snapshot")

        // A SwiftUI row can retain the value snapshot from before the first
        // move. The next drop must use the model's live date, never that stale
        // row value, or yesterday -> today is misclassified as a same-day drop.
        precondition(staleRowSnapshot.metadata.dueDate.map {
            calendar.isDate($0, inSameDayAs: today)
        } == true)
        guard let recoveredTodayMove = model.moveTask(id: taskID, to: today) else {
            preconditionFailure("a stale rendered row must not block overdue -> today")
        }
        precondition(calendar.isDate(recoveredTodayMove.sourceDate, inSameDayAs: yesterday))
        precondition(calendar.isDate(recoveredTodayMove.targetDate, inSameDayAs: today))
        precondition(model.activeTasks.map(\.id) == [taskID])
        guard model.moveTask(id: taskID, to: yesterday) != nil else {
            preconditionFailure("the same live task must remain movable after returning to today")
        }

        let movedReminder = model.task(id: taskID)?.metadata.reminderAt
        precondition(movedReminder.map { calendar.isDate($0, inSameDayAs: yesterday) } == true)
        let requests = V5TaskReminderPlanner.pendingRequests(
            tasks: model.legacySnapshot(),
            metadata: model.metadataSnapshot(),
            now: today,
            calendar: calendar
        )
        precondition(requests.isEmpty,
                     "a reminder moved into the past must not silently schedule")

        let offscreenDate = calendar.date(byAdding: .month, value: -2, to: today)!
        let selectedBeforeReveal = model.selectedDate
        model.revealMonth(containing: offscreenDate)
        precondition(calendar.isDate(model.displayedMonth, equalTo: offscreenDate, toGranularity: .month))
        precondition(model.selectedDate == selectedBeforeReveal,
                     "revealing an animation target month must not rewrite task selection early")

        let mutationCountBeforeSameDay = mutations
        let duplicateMove = model.moveTask(id: taskID, to: yesterday)
        precondition(duplicateMove == nil)
        precondition(mutations == mutationCountBeforeSameDay,
                     "same-day move must not emit a duplicate persistence mutation")

        let deletedID = UUID(uuidString: "00000000-0000-0000-0000-000000000072")!
        let deletedModel = CalendarWorkbenchV5Model(
            now: today,
            tasks: [TaskItem(id: deletedID, title: "已删除", deletedAt: today)],
            metadata: [deletedID: V5TaskMetadata(dueDate: today)]
        )
        precondition(!deletedModel.canMoveTask(id: deletedID, to: future))

        let completedID = UUID(uuidString: "00000000-0000-0000-0000-000000000073")!
        let completedModel = CalendarWorkbenchV5Model(
            now: today,
            tasks: [TaskItem(id: completedID, title: "已完成", isCompleted: true)],
            metadata: [completedID: V5TaskMetadata(dueDate: future, completedAt: today)]
        )
        completedModel.moveTask(id: completedID, to: yesterday)
        precondition(completedModel.task(id: completedID)?.legacy.isCompleted == true)
        precondition(completedModel.overdueTasks.isEmpty,
                     "a completed item never becomes an overdue active task")
        precondition(calendar.isDate(completedModel.selectedDate, inSameDayAs: yesterday),
                     "a moved completed item must reveal its destination instead of jumping to today's overdue overview")

        let december31 = calendar.date(from: DateComponents(
            year: 2026, month: 12, day: 31, hour: 12
        ))!
        let january2 = calendar.date(from: DateComponents(
            year: 2027, month: 1, day: 2, hour: 12
        ))!
        let december30 = calendar.date(byAdding: .day, value: -1, to: december31)!
        let boundaryID = UUID(uuidString: "00000000-0000-0000-0000-000000000074")!
        let boundaryModel = CalendarWorkbenchV5Model(
            now: december31,
            tasks: [TaskItem(id: boundaryID, title: "跨年日期")],
            metadata: [boundaryID: V5TaskMetadata(dueDate: december31)]
        )
        boundaryModel.moveTask(id: boundaryID, to: january2)
        boundaryModel.moveTask(id: boundaryID, to: december30)
        precondition(boundaryModel.overdueTasks.map(\.id) == [boundaryID])
        precondition(boundaryModel.isTodaySelected,
                     "cross-month and cross-year backdating must use the same overdue rule")

        print("v5-task-date-movement-adversarial=passed")
    }
}
