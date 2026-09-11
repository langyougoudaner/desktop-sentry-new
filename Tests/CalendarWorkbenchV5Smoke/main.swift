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
        let previewModel = CalendarWorkbenchV5Model(now: now)
        precondition(previewModel.isPreviewData)
        precondition(previewModel.shouldShowOverdueSection,
                     "the isolated preview must visibly demonstrate the overdue section")

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

        let completedDropDate = calendar.date(byAdding: .day, value: 4, to: now)!
        dragModel.moveTask(id: completedID, to: completedDropDate)
        precondition(dragModel.task(id: completedID)?.legacy.isCompleted == true,
                     "moving a completed task must preserve its completion state")
        precondition(dragModel.task(id: completedID)?.metadata.dueDate.map {
            dragModel.calendar.isDate($0, inSameDayAs: completedDropDate)
        } == true, "a completed task must remain draggable to another date")
        precondition(dragMutationCount == 2,
                     "moving a completed task must persist exactly once")

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

        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let overdueID = UUID(uuidString: "00000000-0000-0000-0000-000000000012")!
        let finishedYesterdayID = UUID(uuidString: "00000000-0000-0000-0000-000000000013")!
        let todayID = UUID(uuidString: "00000000-0000-0000-0000-000000000014")!
        let overdueTask = TaskItem(id: overdueID, title: "昨天未完成")
        let finishedYesterdayTask = TaskItem(
            id: finishedYesterdayID,
            title: "昨天已完成",
            isCompleted: true
        )
        let todayTask = TaskItem(id: todayID, title: "今天待办")
        let overviewModel = CalendarWorkbenchV5Model(
            now: now,
            tasks: [overdueTask, finishedYesterdayTask, todayTask],
            metadata: [
                overdueID: V5TaskMetadata(dueDate: calendar.startOfDay(for: yesterday)),
                finishedYesterdayID: V5TaskMetadata(dueDate: calendar.startOfDay(for: yesterday)),
                todayID: V5TaskMetadata(dueDate: calendar.startOfDay(for: now))
            ]
        )
        precondition(overviewModel.shouldShowOverdueSection,
                     "today must surface unfinished work from earlier dates")
        precondition(overviewModel.overdueTasks.map(\.id) == [overdueID],
                     "overdue excludes completed work and keeps the original due date")
        precondition(overviewModel.activeTasks.map(\.id) == [todayID],
                     "today's normal section must not duplicate overdue work")
        overviewModel.setCompletion(id: overdueID, completed: true, at: now)
        precondition(!overviewModel.completedTasks.contains(where: { $0.id == overdueID }),
                     "completion time must not move an overdue task into today's assigned work")
        precondition(overviewModel.task(id: overdueID)?.metadata.dueDate.map {
            calendar.isDate($0, inSameDayAs: yesterday)
        } == true, "completion must preserve the task's original due date")
        precondition(overviewModel.task(id: overdueID)?.metadata.completedAt == now)
        overviewModel.select(yesterday)
        precondition(Set(overviewModel.completedTasks.map(\.id)) == Set([overdueID, finishedYesterdayID]),
                     "completed work remains on its assigned date")
        overviewModel.select(now)
        overviewModel.setCompletion(id: overdueID, completed: false, at: now)
        precondition(overviewModel.task(id: overdueID)?.metadata.completedAt == nil,
                     "restoring a task must clear its completion timestamp")
        precondition(overviewModel.overdueTasks.map(\.id) == [overdueID])
        overviewModel.select(yesterday)
        precondition(!overviewModel.shouldShowOverdueSection,
                     "a historical date must not duplicate its tasks in an overdue section")

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

        precondition(model.yearTitle == "2026年")
        precondition(model.monthTitle == "8月")
        model.showYear(2028)
        precondition(model.calendar.component(.year, from: model.displayedMonth) == 2028)
        precondition(model.calendar.component(.month, from: model.displayedMonth) == 8,
                     "choosing a year must preserve the displayed month")
        precondition(model.calendar.component(.year, from: model.selectedDate) == 2028)
        precondition(model.calendar.component(.month, from: model.selectedDate) == 8)
        precondition(model.calendar.component(.day, from: model.selectedDate) == 23,
                     "choosing a year must preserve the selected month and day")
        model.showYear(2026)

        let january31 = calendar.date(from: DateComponents(year: 2025, month: 1, day: 31, hour: 12))!
        let clampedMonthModel = CalendarWorkbenchV5Model(now: january31, tasks: [], metadata: [:])
        clampedMonthModel.moveMonth(by: 1)
        precondition(clampedMonthModel.calendar.component(.year, from: clampedMonthModel.selectedDate) == 2025)
        precondition(clampedMonthModel.calendar.component(.month, from: clampedMonthModel.selectedDate) == 2)
        precondition(clampedMonthModel.calendar.component(.day, from: clampedMonthModel.selectedDate) == 28,
                     "month navigation must clamp January 31 to February's last valid day")
        precondition(clampedMonthModel.calendar.isDate(
            clampedMonthModel.selectedDate,
            equalTo: clampedMonthModel.displayedMonth,
            toGranularity: .month
        ), "the selected date and visible month must remain one authoritative state")

        let leapDay = calendar.date(from: DateComponents(year: 2024, month: 2, day: 29, hour: 12))!
        let clampedYearModel = CalendarWorkbenchV5Model(now: leapDay, tasks: [], metadata: [:])
        clampedYearModel.showYear(2025)
        precondition(clampedYearModel.calendar.component(.year, from: clampedYearModel.selectedDate) == 2025)
        precondition(clampedYearModel.calendar.component(.month, from: clampedYearModel.selectedDate) == 2)
        precondition(clampedYearModel.calendar.component(.day, from: clampedYearModel.selectedDate) == 28,
                     "year selection must clamp leap day without spilling into March")

        let leapFebruary = V5CalendarDateNavigation.replacingYearAndMonth(
            year: 2028,
            month: 2,
            in: january31,
            calendar: clampedMonthModel.calendar
        )!
        precondition(clampedMonthModel.calendar.component(.year, from: leapFebruary) == 2028)
        precondition(clampedMonthModel.calendar.component(.month, from: leapFebruary) == 2)
        precondition(clampedMonthModel.calendar.component(.day, from: leapFebruary) == 29,
                     "choosing a year and month must preserve the day and clamp it once")

        let monthBoundaryModel = CalendarWorkbenchV5Model(now: january31, tasks: [], metadata: [:])
        monthBoundaryModel.moveSelection(byDays: 1)
        precondition(monthBoundaryModel.calendar.component(.month, from: monthBoundaryModel.selectedDate) == 2)
        precondition(monthBoundaryModel.calendar.component(.day, from: monthBoundaryModel.selectedDate) == 1)
        precondition(monthBoundaryModel.calendar.isDate(
            monthBoundaryModel.selectedDate,
            equalTo: monthBoundaryModel.displayedMonth,
            toGranularity: .month
        ), "day and week navigation must reveal the selected date's month immediately")

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
                     reminderEnabled: true, reminder: reminder, now: now)
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
        defer { try? FileManager.default.removeItem(at: directory) }
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
        print("Isolated metadata fixture cleaned")
    }
}
