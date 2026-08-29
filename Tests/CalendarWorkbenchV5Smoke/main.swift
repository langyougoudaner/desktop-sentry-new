import Foundation
import Combine

@main
struct CalendarWorkbenchV5Smoke {
    @MainActor
    static func main() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 23, hour: 12))!
        let legacyID = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
        let legacy = TaskItem(id: legacyID, title: "第一代任务", priority: .high, tag: "旧数据")
        let detail = V5TaskMetadata(dueDate: calendar.startOfDay(for: now), details: "V5 扩展字段", reminderAt: nil)
        let model = CalendarWorkbenchV5Model(now: now, tasks: [legacy], metadata: [legacyID: detail])
        precondition(!model.isPreviewData)
        precondition(CalendarWorkbenchV5Model(now: now).isPreviewData)

        let nextDay = calendar.date(byAdding: .day, value: 1, to: now)!
        let residentModel = CalendarWorkbenchV5Model(now: now, tasks: [], metadata: [:])
        residentModel.refreshToday(now: nextDay)
        precondition(residentModel.calendar.isDate(residentModel.today, inSameDayAs: nextDay),
                     "a resident calendar must refresh today after midnight")
        precondition(residentModel.calendar.isDate(residentModel.selectedDate, inSameDayAs: nextDay),
                     "a selection that followed yesterday must advance to the new today")
        precondition(residentModel.calendar.isDate(residentModel.displayedMonth, inSameDayAs: nextDay),
                     "the displayed calendar must follow the refreshed today selection")
        precondition(residentModel.calendar.isDate(residentModel.draftDate, inSameDayAs: nextDay),
                     "the empty composer date must follow the refreshed today selection")

        let manualSelectionModel = CalendarWorkbenchV5Model(now: now, tasks: [], metadata: [:])
        let manualDay = calendar.date(byAdding: .day, value: -2, to: now)!
        manualSelectionModel.select(manualDay)
        var publishedTodayRefresh = false
        let todayRefreshObservation = manualSelectionModel.objectWillChange.sink {
            publishedTodayRefresh = true
        }
        manualSelectionModel.refreshToday(now: nextDay)
        precondition(publishedTodayRefresh,
                     "refreshing today must publish a redraw even when another date stays selected")
        precondition(manualSelectionModel.calendar.isDate(manualSelectionModel.selectedDate,
                                                          inSameDayAs: manualDay),
                     "midnight refresh must not replace a manually selected date")
        _ = todayRefreshObservation

        let draggableID = UUID(uuidString: "00000000-0000-0000-0000-000000000009")!
        let draggable = TaskItem(id: draggableID, title: "拖到目标日期", priority: .medium)
        let completedID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let completed = TaskItem(id: completedID, title: "已完成任务", isCompleted: true)
        let dragModel = CalendarWorkbenchV5Model(
            now: now,
            tasks: [draggable, completed],
            metadata: [
                draggableID: V5TaskMetadata(dueDate: calendar.startOfDay(for: now)),
                completedID: V5TaskMetadata(dueDate: calendar.startOfDay(for: now))
            ]
        )
        precondition(dragModel.taskCounts(on: now) == V5DayTaskCounts(active: 1, completed: 1),
                     "day indicators must distinguish unfinished and completed tasks")
        let dropDate = calendar.date(byAdding: .day, value: 3, to: now)!
        var dragMutationCount = 0
        dragModel.onMutation = { _, _ in dragMutationCount += 1 }
        dragModel.moveTask(id: draggableID, to: dropDate)
        precondition(dragModel.tasks.count == 2 && dragModel.tasks.contains(where: { $0.id == draggableID }),
                     "dragging must move the existing task instead of copying it")
        precondition(dragModel.task(id: draggableID)?.metadata.dueDate.map {
            dragModel.calendar.isDate($0, inSameDayAs: dropDate)
        } == true, "dropping must update the task date")
        precondition(dragModel.calendar.isDate(dragModel.selectedDate, inSameDayAs: dropDate),
                     "a successful drop must reveal the task on its target date")
        precondition(dragMutationCount == 1, "a successful drop must persist exactly once")

        let completionID = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
        let completionTask = TaskItem(id: completionID, title: "快速连点测试")
        let completionModel = CalendarWorkbenchV5Model(
            now: now,
            tasks: [completionTask],
            metadata: [completionID: V5TaskMetadata(dueDate: calendar.startOfDay(for: now))]
        )
        var completionMutationCount = 0
        completionModel.onMutation = { _, _ in completionMutationCount += 1 }
        completionModel.setCompletion(id: completionID, completed: true)
        completionModel.setCompletion(id: completionID, completed: true)
        precondition(completionModel.task(id: completionID)?.legacy.isCompleted == true,
                     "repeated completion input must never restore a departing row")
        precondition(completionMutationCount == 1,
                     "repeated completion input must persist exactly once")

        let migrated = V5TaskMetadataMigration.merge(
            tasks: [legacy],
            existing: [:],
            defaultDate: now,
            calendar: calendar
        )
        precondition(migrated[legacyID]?.dueDate.map { calendar.isDate($0, inSameDayAs: now) } == true,
                     "legacy task identity must receive a default V5 date without changing the task")

        precondition(model.activeTasks.count == 1)
        precondition(model.activeTasks[0].id == legacyID)
        precondition(model.activeTasks[0].metadata.details == "V5 扩展字段")
        precondition(model.activeTasks[0].metadata.reminderAt == nil)

        model.draftTitle = "当天新任务"
        model.draftDetails = "默认跟随选中日期"
        var mutationSnapshots: [([TaskItem], [UUID: V5TaskMetadata])] = []
        model.onMutation = { mutationSnapshots.append(($0, $1)) }
        model.addDraft()
        precondition(model.tasks.count == 2)
        precondition(model.activeTasks.first?.legacy.title == "当天新任务",
                     "new tasks must enter at the top of the selected day")
        precondition(model.tasks[0].metadata.dueDate.map { model.calendar.isDate($0, inSameDayAs: model.selectedDate) } == true)
        precondition(model.tasks[0].metadata.reminderAt == nil)
        precondition(mutationSnapshots.last?.0.first?.title == "当天新任务")
        precondition(mutationSnapshots.last?.1[model.tasks[0].id]?.details == "默认跟随选中日期")

        precondition(model.listMode == .active)
        model.toggleListMode()
        precondition(model.listMode == .completed)
        model.toggleListMode()
        precondition(model.listMode == .active)

        let external = TaskItem(title: "第一版菜单新增")
        model.replaceLegacyTasks(
            [external],
            metadata: [external.id: V5TaskMetadata(dueDate: calendar.startOfDay(for: now))]
        )
        precondition(model.tasks.count == 1)
        precondition(model.tasks[0].id == external.id,
                     "V5 must follow first-generation task mutations without inventing a new identity")

        model.replaceLegacyTasks(
            mutationSnapshots.last!.0,
            metadata: mutationSnapshots.last!.1
        )

        let newID = model.tasks[0].id
        let tomorrow = model.calendar.date(byAdding: .day, value: 1, to: now)!
        let reminder = model.calendar.date(bySettingHour: 9, minute: 30, second: 0, of: tomorrow)!
        model.update(id: newID, title: "已编辑任务", details: "日期和说明已修改", date: tomorrow,
                     reminderEnabled: true, reminder: reminder)
        precondition(model.tasks[0].legacy.title == "已编辑任务")
        precondition(model.tasks[0].metadata.reminderAt == reminder)

        model.selectTask(id: newID)
        precondition(model.selectedTaskID == newID)
        model.beginComposing()
        precondition(model.selectedTaskID == nil, "composer focus must clear task selection")
        model.selectTask(id: newID)
        model.clearTaskSelection()
        precondition(model.selectedTaskID == nil, "background click must clear task selection")

        model.toggleCompletion(id: newID)
        precondition(model.tasks[0].legacy.isCompleted)
        model.toggleCompletion(id: newID)
        precondition(!model.tasks[0].legacy.isCompleted)

        let countBeforeProtectedDelete = model.tasks.count
        model.permanentlyDeleteCompleted(id: newID)
        precondition(model.tasks.count == countBeforeProtectedDelete)
        model.toggleCompletion(id: newID)
        model.permanentlyDeleteCompleted(id: newID)
        precondition(!model.tasks.contains(where: { $0.id == newID }))

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DesktopSentryV5Smoke-\(UUID().uuidString)", isDirectory: true)
        let store = V5TaskMetadataStore(fileURL: directory.appendingPathComponent("metadata.json"))
        try store.save(model.metadataSnapshot())
        let roundTrip = try store.load()
        precondition(roundTrip[legacyID]?.details == "V5 扩展字段")
        precondition(roundTrip[newID] == nil)
        precondition(model.legacySnapshot().contains(where: { $0.id == legacyID }))

        let corruptURL = directory.appendingPathComponent("corrupt-metadata.json")
        try Data("not-json".utf8).write(to: corruptURL)
        let corruptStore = V5TaskMetadataStore(fileURL: corruptURL)
        precondition(corruptStore.loadRecoveringCorruption().isEmpty)
        let recoveryCopies = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.hasPrefix("corrupt-metadata.corrupt.") }
        precondition(recoveryCopies.count == 1,
                     "corrupt V5 metadata must be copied before a clean companion file can replace it")

        print("V5 smoke passed: identity, date linkage, add/edit, optional reminder, complete/recover, completed-only permanent delete, metadata round-trip")
        print("Isolated metadata fixture: \(store.fileURL.path)")
    }
}
