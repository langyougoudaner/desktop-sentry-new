import SwiftUI
import AppKit

/// An isolated, in-memory V2 workbench. The view intentionally owns no
/// persistence or notification services; it is only reachable from the
/// explicit `--calendar-workbench-v2-preview` launch argument.
struct CalendarWorkbenchV2View: View {
    @ObservedObject var model: CalendarWorkbenchV2Model
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var editingID: UUID?
    @State private var editingDraft = ""
    @State private var showingUndo = false

    private let calendarColumns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider().opacity(0.55)
            HStack(spacing: 0) {
                calendarColumn
                    .frame(minWidth: 430, idealWidth: 450, maxWidth: 470)
                Divider().opacity(0.5)
                taskColumn
                    .frame(minWidth: 470, idealWidth: 520, maxWidth: .infinity)
            }
        }
        .foregroundStyle(.primary)
        .frame(minWidth: 940, minHeight: 650)
        .animation(animation, value: model.mode)
        .animation(animation, value: model.selectedDate)
        .onChange(of: model.lastCompletedTask) { _, task in
            guard task != nil else { return }
            withAnimation(animation) { showingUndo = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if model.lastCompletedTask?.id == task?.id {
                    withAnimation(animation) { showingUndo = false }
                    model.clearUndo()
                }
            }
        }
        .onKeyPress(.escape) {
            if model.isAddingCountdown {
                model.cancelCountdown()
            } else if editingID != nil {
                editingID = nil
            } else {
                onClose()
            }
            return .handled
        }
    }

    private var animation: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .snappy(duration: 0.24, extraBounce: 0.08)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("日历任务工作台")
                    .font(.headline.weight(.semibold))
                Text("预览数据 · 退出后不保存")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("Desktop Sentry")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(Color.primary.opacity(0.025))
    }

    private var calendarColumn: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("日历")
                        .font(.title2.weight(.semibold))
                    Text(model.monthTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { shiftMonth(by: -1) } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("上个月")
                Button("今天") { model.jumpToToday() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button { shiftMonth(by: 1) } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("下个月")
            }

            calendarGrid

            Divider().opacity(0.6)
            focusSection
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
    }

    private var calendarGrid: some View {
        VStack(spacing: 8) {
            HStack(spacing: 5) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: calendarColumns, spacing: 6) {
                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayCell(date)
                    } else {
                        Color.clear.frame(height: 56)
                    }
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let selected = isSameDay(date, model.selectedDate)
        let today = isSameDay(date, model.today)
        let count = model.taskCount(on: date)
        let lunar = CalendarWorkbenchLunar.shortLabel(for: date)
        let festival = CalendarWorkbenchLunar.festival(for: date)
        return Button {
            withAnimation(animation) { model.select(date: date) }
        } label: {
            VStack(spacing: 2) {
                Text(dayNumber(date))
                    .font(.system(size: 17, weight: selected || today ? .semibold : .regular,
                                  design: .rounded))
                    .foregroundStyle(selected ? Color.white : Color.primary)
                    .frame(width: 34, height: 31)
                    .background {
                        if selected {
                            Circle().fill(Color.accentColor)
                        } else if today {
                            Circle().stroke(Color.accentColor, lineWidth: 1.5)
                        }
                    }
                    .overlay {
                        if selected && today {
                            Circle().stroke(Color.white.opacity(0.86), lineWidth: 1.2)
                                .padding(3)
                        }
                    }
                Text(festival ?? lunar)
                    .font(.system(size: 9, weight: festival == nil ? .regular : .medium))
                    .foregroundStyle(selected ? Color.white.opacity(0.86) :
                        (festival == nil ? Color.secondary : Color.red.opacity(0.82)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                HStack(spacing: 2) {
                    Circle()
                        .fill(count > 0 ? (selected ? Color.white : Color.accentColor) : Color.clear)
                        .frame(width: 4, height: 4)
                    if count > 1 {
                        Text("\(count)")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(selected ? Color.white.opacity(0.9) : Color.secondary)
                    }
                }
                .frame(height: 9)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(fullDate(date))，农历\(lunar)\(festival.map { "，\($0)" } ?? "")")
    }

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("菜单栏重点")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "flag.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if let task = model.tasks.first(where: { $0.isImportant && !$0.isCompleted }) {
                HStack(alignment: .top, spacing: 9) {
                    Circle()
                        .fill(Color.orange.opacity(0.16))
                        .frame(width: 26, height: 26)
                        .overlay {
                            Image(systemName: "flag.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(task.title)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(2)
                        Text(task.date.map(relativeDateLabel) ?? "无日期")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("还没有标记重点的待办")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.055), in: RoundedRectangle(cornerRadius: 11))
    }

    private var taskColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            taskHeader
            if model.mode == .todo {
                todoInput
            } else if model.isAddingCountdown {
                countdownComposer
            } else {
                Button {
                    withAnimation(animation) { model.startCountdown() }
                } label: {
                    Label("添加倒数日", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            if let selectedDate = model.selectedDate {
                HStack(spacing: 6) {
                    Text("筛选：\(shortDate(selectedDate))")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Button("显示全部") { withAnimation(animation) { model.showAll() } }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
            }

            Divider().opacity(0.55)
            if model.filteredTasks.isEmpty {
                emptyTaskState
            } else {
                taskList
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .overlay(alignment: .bottom) {
            if showingUndo, model.lastCompletedTask != nil {
                undoToast
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var taskHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(model.mode == .todo ? "待办" : "倒数日")
                    .font(.title2.weight(.semibold))
                Text(model.selectedDate.map { "\(shortDate($0)) · \(model.activeTaskCount) 项未完成" }
                     ?? "全部项目 · \(model.activeTaskCount) 项未完成")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Picker("任务类型", selection: $model.mode) {
                ForEach(CalendarWorkbenchMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .tint(Color.accentColor)
            .frame(width: 142)
            .labelsHidden()
            .accessibilityLabel("任务类型")
        }
    }

    private var todoInput: some View {
        HStack(spacing: 9) {
            Image(systemName: "plus.circle")
                .foregroundStyle(Color.accentColor)
            TextField("添加待办，回车确认", text: $model.todoDraft)
                .textFieldStyle(.plain)
                .onSubmit { withAnimation(animation) { model.addTodo() } }
            if model.selectedDate != nil {
                Text("\(shortDate(model.selectedDate!))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.06), in: Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.accentColor.opacity(0.065), in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.accentColor.opacity(0.2), lineWidth: 1))
    }

    private var countdownComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(Color.accentColor)
                TextField("倒数日名称", text: $model.countdownDraft)
                    .textFieldStyle(.plain)
                    .onSubmit { withAnimation(animation) { model.addCountdown() } }
                Button("取消") { withAnimation(animation) { model.cancelCountdown() } }
                    .buttonStyle(.borderless)
            }
            HStack(spacing: 12) {
                DatePicker("日期", selection: $model.countdownDate, displayedComponents: .date)
                    .labelsHidden()
                Toggle("提醒", isOn: $model.countdownNotificationEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                if model.countdownNotificationEnabled {
                    DatePicker("时间", selection: $model.countdownNotificationTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                Spacer()
                Button("添加") { withAnimation(animation) { model.addCountdown() } }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(model.countdownDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(12)
        .background(Color.accentColor.opacity(0.065), in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.accentColor.opacity(0.2), lineWidth: 1))
    }

    private var taskList: some View {
        ScrollView {
            LazyVStack(spacing: 7) {
                ForEach(model.filteredTasks) { task in
                    taskRow(task)
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.visible)
    }

    private func taskRow(_ task: CalendarWorkbenchTask) -> some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(animation) { model.toggleCompleted(id: task.id) }
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? "标记为未完成" : "标记完成")

            VStack(alignment: .leading, spacing: 5) {
                if editingID == task.id {
                    TextField("任务名称", text: $editingDraft)
                        .textFieldStyle(.plain)
                        .onSubmit { finishEditing(task) }
                } else {
                    Text(task.title)
                        .font(.subheadline.weight(.medium))
                        .strikethrough(task.isCompleted, color: .secondary)
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                        .lineLimit(2)
                }
                HStack(spacing: 8) {
                    if let date = task.date {
                        Label(relativeDateLabel(date), systemImage: "calendar")
                    } else {
                        Text("无日期")
                    }
                    if let notificationTime = task.notificationTime {
                        Label(notificationTime, systemImage: "bell.fill")
                    }
                    if task.isCompleted {
                        Text("已完成")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)
            Button {
                withAnimation(animation) { model.toggleImportant(id: task.id) }
            } label: {
                Image(systemName: task.isImportant ? "flag.fill" : "flag")
                    .foregroundStyle(task.isImportant ? Color.orange : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isImportant ? "取消重点" : "标记重点")

            Menu {
                Button("编辑") { beginEditing(task) }
                Button(task.isCompleted ? "标记未完成" : "标记完成") {
                    withAnimation(animation) { model.toggleCompleted(id: task.id) }
                }
                Button(task.isImportant ? "取消重点" : "设为重点") {
                    withAnimation(animation) { model.toggleImportant(id: task.id) }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 28)
            }
            .menuStyle(.borderlessButton)
            .accessibilityLabel("更多操作")

            Image(systemName: "line.3.horizontal")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 22, height: 28)
                .contentShape(Rectangle())
                .onDrag {
                    NSItemProvider(object: task.id.uuidString as NSString)
                }
                .accessibilityLabel("拖动排序")
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(Color.primary.opacity(task.isImportant ? 0.08 : 0.045),
                    in: RoundedRectangle(cornerRadius: 11))
        .overlay {
            if task.isImportant && !task.isCompleted {
                RoundedRectangle(cornerRadius: 11)
                    .stroke(Color.orange.opacity(0.28), lineWidth: 1)
            }
        }
        .onDrop(of: [.text], delegate: CalendarWorkbenchDropDelegate(targetID: task.id, model: model))
    }

    private var emptyTaskState: some View {
        VStack(spacing: 8) {
            Image(systemName: model.mode == .todo ? "checklist" : "calendar.badge.clock")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text(model.selectedDate == nil ? "还没有\(model.mode.title)" : "这一天还没有项目")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(model.mode == .todo ? "在上方输入框中添加第一项" : "点击上方“添加倒数日”开始记录")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 50)
    }

    private var undoToast: some View {
        HStack(spacing: 10) {
            Text("已标记完成")
                .font(.caption.weight(.medium))
            Button("撤销") {
                withAnimation(animation) {
                    model.undoLastCompletion()
                    showingUndo = false
                }
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.accentColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.09), in: Capsule())
    }

    private var monthDays: [Date?] {
        guard let interval = model.calendar.dateInterval(of: .month, for: model.displayedMonth) else { return [] }
        let firstWeekday = model.calendar.component(.weekday, from: interval.start)
        let leading = (firstWeekday - model.calendar.firstWeekday + 7) % 7
        let count = model.calendar.range(of: .day, in: .month, for: interval.start)?.count ?? 0
        var days = Array<Date?>(repeating: nil, count: leading)
        days += (0..<count).compactMap { model.calendar.date(byAdding: .day, value: $0, to: interval.start) }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        let raw = formatter.shortStandaloneWeekdaySymbols ?? []
        let symbols = raw.map { value -> String in
            if value.hasPrefix("星期") { return String(value.dropFirst(2)) }
            if value.hasPrefix("周") { return String(value.dropFirst()) }
            return value
        }
        let start = max(0, min(symbols.count - 1, model.calendar.firstWeekday - 1))
        return Array(symbols[start...]) + Array(symbols[..<start])
    }

    private func shiftMonth(by value: Int) {
        withAnimation(animation) { model.moveMonth(by: value) }
    }

    private func beginEditing(_ task: CalendarWorkbenchTask) {
        editingID = task.id
        editingDraft = task.title
    }

    private func finishEditing(_ task: CalendarWorkbenchTask) {
        withAnimation(animation) {
            model.rename(id: task.id, title: editingDraft)
            editingID = nil
        }
    }

    private func isSameDay(_ lhs: Date, _ rhs: Date?) -> Bool {
        guard let rhs else { return false }
        return model.calendar.isDate(lhs, inSameDayAs: rhs)
    }

    private func dayNumber(_ date: Date) -> String {
        String(model.calendar.component(.day, from: date))
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }

    private func fullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: date)
    }

    private func relativeDateLabel(_ date: Date) -> String {
        if model.calendar.isDateInToday(date) { return "今天" }
        let difference = model.calendar.dateComponents([.day], from: model.today, to: model.calendar.startOfDay(for: date)).day ?? 0
        if difference == 1 { return "明天" }
        if difference == -1 { return "昨天" }
        if difference > 0 { return "\(difference)天后" }
        return "已逾期\(abs(difference))天"
    }
}

private struct CalendarWorkbenchDropDelegate: DropDelegate {
    let targetID: UUID
    let model: CalendarWorkbenchV2Model

    func dropEntered(info: DropInfo) {
        guard let provider = info.itemProviders(for: [.text]).first else { return }
        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let raw = object as? String, let sourceID = UUID(uuidString: raw) else { return }
            DispatchQueue.main.async {
                model.move(id: sourceID, before: targetID)
            }
        }
    }

    func performDrop(info: DropInfo) -> Bool { true }
}
