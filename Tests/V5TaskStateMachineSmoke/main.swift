import Foundation

@main
struct V5TaskStateMachineSmoke {
    @MainActor
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let september5 = calendar.date(from: DateComponents(
            year: 2026, month: 9, day: 5, hour: 12
        ))!
        let september6 = calendar.date(byAdding: .day, value: 1, to: september5)!
        let taskID = UUID(uuidString: "00000000-0000-0000-0000-000000000031")!
        let completed = TaskItem(id: taskID, title: "日期归属测试", isCompleted: true)
        let model = CalendarWorkbenchV5Model(
            now: september5,
            tasks: [completed],
            metadata: [
                taskID: V5TaskMetadata(
                    dueDate: calendar.startOfDay(for: september6),
                    completedAt: september5
                )
            ]
        )

        precondition(model.completedTasks.isEmpty,
                     "today must not claim a completed task assigned to another date")
        model.select(september6)
        precondition(model.completedTasks.map(\.id) == [taskID],
                     "a completed task belongs to its assigned date")

        let remindedID = UUID(uuidString: "00000000-0000-0000-0000-000000000032")!
        let reminderOnSeptember5 = calendar.date(from: DateComponents(
            year: 2026, month: 9, day: 5, hour: 9, minute: 30
        ))!
        let remindedModel = CalendarWorkbenchV5Model(
            now: september5,
            tasks: [TaskItem(id: remindedID, title: "带提醒的待办")],
            metadata: [
                remindedID: V5TaskMetadata(
                    dueDate: calendar.startOfDay(for: september5),
                    reminderAt: reminderOnSeptember5
                )
            ]
        )
        remindedModel.moveTask(id: remindedID, to: september6)
        let movedReminder = remindedModel.task(id: remindedID)?.metadata.reminderAt
        precondition(movedReminder.map { calendar.isDate($0, inSameDayAs: september6) } == true,
                     "moving a task must move its reminder to the assigned date")
        precondition(movedReminder.map { calendar.component(.hour, from: $0) } == 9)
        precondition(movedReminder.map { calendar.component(.minute, from: $0) } == 30)

        let externallyRestored = TaskItem(id: taskID, title: "日期归属测试")
        let reconciled = V5TaskMetadataMigration.merge(
            tasks: [externallyRestored],
            existing: [
                taskID: V5TaskMetadata(
                    dueDate: calendar.startOfDay(for: september6),
                    completedAt: september5
                )
            ],
            defaultDate: september5,
            calendar: calendar
        )
        precondition(reconciled[taskID]?.completedAt == nil,
                     "restoring a task outside V5 must clear its stale completion timestamp")

        let removedID = UUID(uuidString: "00000000-0000-0000-0000-000000000033")!
        let withoutRemovedTask = V5TaskMetadataMigration.merge(
            tasks: [externallyRestored],
            existing: [
                taskID: V5TaskMetadata(dueDate: calendar.startOfDay(for: september6)),
                removedID: V5TaskMetadata(dueDate: calendar.startOfDay(for: september5))
            ],
            defaultDate: september5,
            calendar: calendar
        )
        precondition(withoutRemovedTask[removedID] == nil,
                     "metadata for a permanently removed task must not survive synchronization")

        let undatedID = UUID(uuidString: "00000000-0000-0000-0000-000000000034")!
        let undatedModel = CalendarWorkbenchV5Model(
            now: september5,
            tasks: [TaskItem(id: undatedID, title: "缺少日期的旧待办")],
            metadata: [undatedID: V5TaskMetadata()]
        )
        precondition(undatedModel.activeTasks.map(\.id) == [undatedID])
        undatedModel.select(september6)
        precondition(undatedModel.activeTasks.isEmpty,
                     "an undated legacy task must receive one date instead of appearing every day")

        let forwardOnlyID = UUID(uuidString: "00000000-0000-0000-0000-000000000035")!
        let forwardOnlyModel = CalendarWorkbenchV5Model(
            now: september5,
            tasks: [TaskItem(id: forwardOnlyID, title: "只能往未来拖")],
            metadata: [
                forwardOnlyID: V5TaskMetadata(dueDate: calendar.startOfDay(for: september5))
            ]
        )
        precondition(!forwardOnlyModel.canMoveTask(id: forwardOnlyID, to: september5),
                     "dragging to the same day is not a move")
        let september4 = calendar.date(byAdding: .day, value: -1, to: september5)!
        precondition(forwardOnlyModel.canMoveTask(id: forwardOnlyID, to: september4),
                     "dragging may correct a task back to a historical date")
        precondition(forwardOnlyModel.canMoveTask(id: forwardOnlyID, to: september6),
                     "dragging to a future date must remain available")

        let september1 = calendar.date(byAdding: .day, value: -4, to: september5)!
        let september3 = calendar.date(byAdding: .day, value: -2, to: september5)!
        let overdueID = UUID(uuidString: "00000000-0000-0000-0000-000000000036")!
        let overdueModel = CalendarWorkbenchV5Model(
            now: september5,
            tasks: [TaskItem(id: overdueID, title: "逾期待办")],
            metadata: [overdueID: V5TaskMetadata(dueDate: september1)]
        )
        precondition(overdueModel.canMoveTask(id: overdueID, to: september3),
                     "an overdue task may be reassigned to another historical day")
        precondition(overdueModel.canMoveTask(id: overdueID, to: september5),
                     "an overdue task may be postponed to today")
        precondition(overdueModel.canMoveTask(id: overdueID, to: september6),
                     "an overdue task may be postponed to a future day")

        forwardOnlyModel.moveTask(id: forwardOnlyID, to: september6)
        forwardOnlyModel.moveTask(id: forwardOnlyID, to: september5)
        precondition(forwardOnlyModel.task(id: forwardOnlyID)?.metadata.dueDate.map {
            calendar.isDate($0, inSameDayAs: september5)
        } == true, "a task accidentally moved forward must be draggable back to today")

        forwardOnlyModel.moveTask(id: forwardOnlyID, to: september4)
        precondition(forwardOnlyModel.overdueTasks.map(\.id).contains(forwardOnlyID),
                     "moving a task before today must immediately classify it as overdue")
        precondition(forwardOnlyModel.isTodaySelected,
                     "after backdating, the today overview must reveal the overdue task immediately")

        forwardOnlyModel.update(
            id: forwardOnlyID,
            title: "允许编辑回填",
            details: "",
            date: september4,
            reminderEnabled: false,
            reminder: september4
        )
        precondition(forwardOnlyModel.task(id: forwardOnlyID)?.metadata.dueDate.map {
            calendar.isDate($0, inSameDayAs: september4)
        } == true, "explicit editing must continue to support historical dates")

        let draftTask = forwardOnlyModel.task(id: forwardOnlyID)!
        forwardOnlyModel.beginEditing(draftTask)
        var editDraft = forwardOnlyModel.editDraft(for: draftTask)
        editDraft.title = "尚未保存但必须保留"
        forwardOnlyModel.storeEditDraft(editDraft, for: forwardOnlyID)
        forwardOnlyModel.select(september5)
        precondition(forwardOnlyModel.editDraft(for: draftTask).title == "尚未保存但必须保留",
                     "switching dates must preserve an unfinished editor draft")
        forwardOnlyModel.discardEditDraft(for: forwardOnlyID)
        precondition(forwardOnlyModel.editDraft(for: draftTask).title == draftTask.legacy.title,
                     "Cancel must explicitly discard the preserved draft")

        let invalidReminder = calendar.date(byAdding: .minute, value: -30, to: september5)!
        let originalTitle = forwardOnlyModel.task(id: forwardOnlyID)!.legacy.title
        let acceptedPastReminder = forwardOnlyModel.update(
            id: forwardOnlyID,
            title: "不应保存",
            details: "",
            date: september5,
            reminderEnabled: true,
            reminder: invalidReminder,
            now: september5
        )
        precondition(!acceptedPastReminder)
        precondition(forwardOnlyModel.task(id: forwardOnlyID)?.legacy.title == originalTitle,
                     "an invalid past reminder must reject the whole edit instead of silently disappearing")

        for offset in 1...100 {
            let target = calendar.date(byAdding: .day, value: offset, to: september4)!
            forwardOnlyModel.moveTask(id: forwardOnlyID, to: target)
            forwardOnlyModel.toggleCompletion(id: forwardOnlyID)
            forwardOnlyModel.toggleCompletion(id: forwardOnlyID)
            let task = forwardOnlyModel.task(id: forwardOnlyID)
            precondition(task?.legacy.isCompleted == false)
            precondition(task?.metadata.dueDate.map {
                calendar.isDate($0, inSameDayAs: target)
            } == true, "repeated forward moves and completion cycles must preserve one assigned date")
        }

        print("v5-task-state-machine=passed")
    }
}
