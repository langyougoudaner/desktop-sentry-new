import SwiftUI
import AppKit

private enum CalendarWorkbenchV21ReminderChoice: String, CaseIterable, Identifiable {
    case endOfDay = "当日 24:00"
    case custom = "自定义时间"
    case none = "不提醒"
    var id: String { rawValue }
}

struct CalendarWorkbenchV21View: View {
    @ObservedObject var model: CalendarWorkbenchV21PreviewModel
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var quickEntryText = ""
    @State private var quickEntryDate = Date()
    @State private var quickReminderChoice: CalendarWorkbenchV21ReminderChoice = .endOfDay
    @State private var quickCustomReminder = Date()
    @State private var showsQuickSchedule = ProcessInfo.processInfo.arguments.contains(
        "--calendar-workbench-v2-1-schedule-open"
    )
    @State private var showsCompletedTasks = false
    @State private var editingTaskID: UUID?
    @State private var taskDetailsDraft = ""
    @State private var taskEditDate = Date()
    @State private var taskReminderChoice: CalendarWorkbenchV21ReminderChoice = .endOfDay
    @State private var taskCustomReminder = Date()
    @State private var showsCountdownComposer = false
    @State private var editingCountdownID: UUID?
    @State private var expandedCountdownID: UUID?
    @State private var pendingCountdownDeletionID: UUID?
    @State private var countdownName = ""
    @State private var countdownDate = Date()
    @State private var countdownRepeat: CalendarWorkbenchV21CountdownRepeat = .none
    @State private var countdownIncludesToday = false
    @State private var countdownUsesIcon = false
    @State private var countdownColor = Color.accentColor
    @State private var countdownHex = "#0A7AFF"
    @State private var countdownShowsNameError = false

    private let calendarColumns = Array(repeating: GridItem(.fixed(82), spacing: 4), count: 7)

    var body: some View {
        HStack(spacing: 0) {
            calendarPane
                .frame(width: 650)
            Divider().opacity(0.55)
            taskPane
                .frame(width: 409)
        }
        .frame(width: 1060, height: 660)
        .background(
            colorScheme == .dark
                ? Color(red: 0.035, green: 0.105, blue: 0.18).opacity(0.58)
                : Color.white.opacity(0.44)
        )
        .glassBorder(cornerRadius: 18)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            switchMonth(by: -1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            switchMonth(by: 1)
            return .handled
        }
        .onAppear {
            quickEntryDate = model.selectedDate ?? model.today
            quickCustomReminder = model.endOfDayReminder(for: quickEntryDate)
        }
        .alert("删除这个倒数日？", isPresented: countdownDeleteAlertBinding) {
            Button("取消", role: .cancel) { pendingCountdownDeletionID = nil }
            Button("删除", role: .destructive) { confirmCountdownDeletion() }
        } message: {
            Text("此操作只影响当前隔离预览中的内存样例。")
        }
    }

    private var selectionAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.12)
            : .interactiveSpring(response: 0.21, dampingFraction: 0.91, blendDuration: 0.05)
    }

    private var calendarPane: some View {
        VStack(spacing: 0) {
            monthControls
                .frame(height: 38)
                .padding(.bottom, 13)

            HStack(spacing: 4) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 82)
                }
            }
            .padding(.bottom, 7)

            LazyVGrid(columns: calendarColumns, spacing: 4) {
                ForEach(Array(monthDays.enumerated()), id: \.offset) { _, date in
                    CalendarWorkbenchV21DayCell(
                        date: date,
                        calendar: model.calendar,
                        today: model.today,
                        isInDisplayedMonth: model.calendar.isDate(
                            date,
                            equalTo: model.displayedMonth,
                            toGranularity: .month
                        ),
                        isSelected: model.selectedDate.map {
                            model.calendar.isDate(date, inSameDayAs: $0)
                        } ?? false,
                        itemCount: model.itemCount(on: date),
                        reduceMotion: reduceMotion
                    ) {
                        withAnimation(selectionAnimation) {
                            selectCalendarDate(date)
                        }
                    }
                }
            }
            .id(model.displayedMonth)
            .transition(monthTransition)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 19)
        .padding(.bottom, 17)
    }

    private var monthControls: some View {
        HStack(spacing: 9) {
            Text(model.monthTitle)
                .font(.system(size: 20, weight: .semibold))
                .monospacedDigit()
            CalendarWorkbenchV21WindowDragRegion()
                .frame(minWidth: 96, maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)
            Button {
                switchMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 40, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("上个月")

            Button("今天") {
                withAnimation(selectionAnimation) { model.jumpToToday() }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                switchMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 40, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("下个月")
        }
    }

    private var taskPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.selectedDateTitle)
                        .font(.headline.weight(.semibold))
                    if model.selectedDate != nil {
                        Button("返回全部") {
                            withAnimation(selectionAnimation) { model.showAll() }
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                    } else {
                        Text("内存预览")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Picker("类型", selection: $model.mode) {
                    ForEach(CalendarWorkbenchV21Mode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .tint(Color.accentColor)
                .frame(width: 176)
            }

            if model.mode == .todo {
                todoPaneContent
            } else {
                countdownPaneContent
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 19)
        .padding(.bottom, 18)
    }

    private var todoPaneContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 9) {
                HStack(spacing: 9) {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                    TextField("添加待办，回车确认", text: $quickEntryText)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                        .onSubmit(submitQuickEntry)
                }
                HStack(spacing: 8) {
                    Button {
                        withAnimation(selectionAnimation) { showsQuickSchedule.toggle() }
                    } label: {
                        Label(shortDate(quickEntryDate), systemImage: "calendar")
                    }
                    .buttonStyle(.plain)
                    Button {
                        withAnimation(selectionAnimation) { showsQuickSchedule.toggle() }
                    } label: {
                        Label(reminderChoiceTitle(quickReminderChoice), systemImage: "bell")
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 0)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if showsQuickSchedule {
                    scheduleControls(
                        date: $quickEntryDate,
                        reminderChoice: $quickReminderChoice,
                        customReminder: $quickCustomReminder
                    )
                    .padding(.top, 3)
                }
            }
            .padding(12)
            .background(glassSurfaceFill, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(glassSurfaceBorder(cornerRadius: 11))

            Divider().opacity(0.42)

            if model.activeTasks.isEmpty && model.completedTasks.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("这一天还没有待办")
                        .font(.subheadline.weight(.medium))
                    Text("从上方输入后按回车添加")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(model.activeTasks) { task in
                            taskRow(task)
                        }

                        if showsCompletedTasks, !model.completedTasks.isEmpty {
                            HStack(spacing: 8) {
                                Rectangle().fill(Color.secondary.opacity(0.25)).frame(height: 1)
                                Text("已完成")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Rectangle().fill(Color.secondary.opacity(0.25)).frame(height: 1)
                            }
                            .padding(.vertical, 3)

                            ForEach(model.completedTasks) { task in
                                taskRow(task)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 3)
                }
                .scrollIndicators(.hidden)
            }

            Spacer(minLength: 0)

            Button {
                withAnimation(selectionAnimation) { showsCompletedTasks.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showsCompletedTasks ? "chevron.down" : "chevron.right")
                    Text("已完成")
                    Text("\(model.completedTasks.count)")
                        .monospacedDigit()
                    Spacer()
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(model.completedTasks.isEmpty ? Color.secondary : Color.primary)
                .padding(.horizontal, 10)
                .frame(height: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(model.completedTasks.isEmpty)
        }
    }

    private func taskRow(_ task: CalendarWorkbenchV21Task) -> some View {
        CalendarWorkbenchV21TaskRow(
            task: task,
            relativeDate: task.date.map(relativeDate) ?? "无日期",
            reminderText: taskReminderText(task),
            isSelected: model.selectedTaskID == task.id,
            isExpanded: editingTaskID == task.id,
            detailsDraft: $taskDetailsDraft,
            onSelect: {
                withAnimation(selectionAnimation) {
                    if editingTaskID == task.id {
                        editingTaskID = nil
                    } else {
                        editingTaskID = task.id
                        taskDetailsDraft = task.details
                    }
                    model.selectTask(id: task.id)
                }
            },
            onToggle: {
                withAnimation(selectionAnimation) { model.toggleCompletion(id: task.id) }
            },
            onSaveDetails: {
                model.updateTaskDetails(id: task.id, details: taskDetailsDraft)
                withAnimation(selectionAnimation) { editingTaskID = nil }
            }
        )
    }

    private var countdownPaneContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            countdownComposer

            Divider().opacity(0.42)

            if model.visibleCountdowns.isEmpty {
                Text("这一天还没有倒数日")
                    .font(.subheadline.weight(.medium))
                    .padding(.top, 4)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(model.visibleCountdowns) { countdown in
                            countdownCard(countdown)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 3)
                }
                .scrollIndicators(.hidden)
            }
            Spacer(minLength: 0)
        }
    }

    private var countdownComposer: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                if showsCountdownComposer {
                    resetCountdownComposer()
                } else {
                    beginAddingCountdown()
                }
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: showsCountdownComposer ? "minus.circle" : "plus.circle")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("添加倒数日")
                            .font(.subheadline.weight(.semibold))
                        Text("名称、日期、重复方式与颜色一次完成")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: showsCountdownComposer ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .frame(height: 58)
                .contentShape(Rectangle())
            }
            .buttonStyle(CalendarWorkbenchV21TaskPressStyle())

            if showsCountdownComposer {
                Divider().opacity(0.34)
                    .padding(.horizontal, 12)
                VStack(alignment: .leading, spacing: 13) {
                    countdownFormFields
                    HStack {
                        Button("取消", action: resetCountdownComposer)
                        Spacer()
                        Button("保存", action: saveCountdown)
                            .buttonStyle(.borderedProminent)
                            .keyboardShortcut(.return, modifiers: .command)
                    }
                }
                .padding(14)
                .transition(.opacity)
            }
        }
        .background(glassSurfaceFill, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(glassSurfaceBorder(cornerRadius: 11))
    }

    private func countdownCard(_ countdown: CalendarWorkbenchV21Countdown) -> some View {
        let isExpanded = expandedCountdownID == countdown.id
        let isEditing = editingCountdownID == countdown.id
        let accent = color(from: countdown.color)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(accent.opacity(colorScheme == .dark ? 0.22 : 0.14))
                    Image(systemName: countdown.usesIcon ? "calendar.badge.clock" : "textformat")
                        .foregroundStyle(accent)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 3) {
                    Text(countdown.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(countdown.repeatRule.rawValue + (countdown.includesToday ? " · 含当天" : ""))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(model.countdownText(for: countdown))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
                    .multilineTextAlignment(.trailing)
                Menu {
                    Button("编辑", systemImage: "pencil") { beginEditingCountdown(countdown) }
                    Divider()
                    Button("上移", systemImage: "arrow.up") { model.moveCountdown(id: countdown.id, by: -1) }
                        .disabled(!canMoveCountdown(countdown, by: -1))
                    Button("下移", systemImage: "arrow.down") { model.moveCountdown(id: countdown.id, by: 1) }
                        .disabled(!canMoveCountdown(countdown, by: 1))
                    Divider()
                    Button("删除", systemImage: "trash", role: .destructive) {
                        pendingCountdownDeletionID = countdown.id
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "ellipsis.circle")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 30)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
            .padding(.horizontal, 11)
            .frame(height: 66)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(selectionAnimation) {
                    if isExpanded {
                        expandedCountdownID = nil
                        if isEditing { cancelCountdownEditing() }
                    } else {
                        expandedCountdownID = countdown.id
                    }
                }
            }

            if isExpanded {
                Divider().opacity(0.34)
                    .padding(.horizontal, 11)
                if isEditing {
                    VStack(alignment: .leading, spacing: 13) {
                        countdownFormFields
                        HStack {
                            Button("取消", action: cancelCountdownEditing)
                            Spacer()
                            Button("保存修改", action: saveCountdown)
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(13)
                    .transition(.opacity)
                } else {
                    VStack(alignment: .leading, spacing: 9) {
                        LabeledContent("日期", value: formattedDate(countdown.date))
                        LabeledContent("重复", value: countdown.repeatRule.rawValue)
                        LabeledContent("计数方式", value: countdown.includesToday ? "包含当天" : "不包含当天")
                        HStack {
                            Circle().fill(accent).frame(width: 12, height: 12)
                            Text("当前颜色")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("编辑") { beginEditingCountdown(countdown) }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                    .font(.caption)
                    .padding(13)
                    .transition(.opacity)
                }
            }
        }
        .background(
            Color.white.opacity(colorScheme == .dark ? 0.075 : 0.46),
            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
        )
        .overlay(glassSurfaceBorder(cornerRadius: 11))
    }

    private var countdownFormFields: some View {
        VStack(alignment: .leading, spacing: 13) {
            VStack(alignment: .leading, spacing: 5) {
                Text("名称")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("例如：生日、纪念日、项目交付", text: $countdownName)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .frame(height: 38)
                    .background(fieldSurfaceFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(fieldSurfaceBorder(cornerRadius: 8))
                if countdownShowsNameError {
                    Text("请输入倒数日名称")
                        .font(.caption)
                        .foregroundStyle(Color(nsColor: .systemRed))
                }
            }
            HStack(spacing: 12) {
                Text("样式")
                    .font(.subheadline.weight(.medium))
                    .frame(width: 46, alignment: .leading)
                Picker("样式", selection: $countdownUsesIcon) {
                    Text("文字").tag(false)
                    Text("图标").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            linkedDateControl(title: "日期", date: $countdownDate) { date in
                setCountdownDate(date)
            }

            HStack(spacing: 12) {
                Text("重复")
                    .font(.subheadline.weight(.medium))
                    .frame(width: 46, alignment: .leading)
                Picker("重复", selection: $countdownRepeat) {
                    ForEach(CalendarWorkbenchV21CountdownRepeat.allCases) { rule in
                        Text(rule.rawValue).tag(rule)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                Spacer(minLength: 0)
            }

            Toggle("包含当天", isOn: $countdownIncludesToday)

            VStack(alignment: .leading, spacing: 7) {
                Text("颜色")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    ForEach(Array(CalendarWorkbenchV21Color.presets.enumerated()), id: \.offset) { index, preset in
                        Button {
                            setCountdownColor(preset)
                        } label: {
                            Circle()
                                .fill(color(from: preset))
                                .frame(width: 20, height: 20)
                                .padding(3)
                                .overlay(
                                    Circle().strokeBorder(Color.primary.opacity(0.38), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("颜色 \(index + 1)")
                    }
                    Spacer(minLength: 0)
                    TextField("#0A7AFF", text: $countdownHex)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.caption, design: .monospaced))
                        .frame(width: 82)
                        .onSubmit(applyCountdownHex)
                    Button(action: sampleCountdownColor) {
                        Image(systemName: "eyedropper")
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("从屏幕取色")
                }
            }
        }
    }

    private var glassSurfaceFill: Color {
        Color.white.opacity(colorScheme == .dark ? 0.10 : 0.62)
    }

    private func glassSurfaceBorder(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.19 : 0.82), lineWidth: 1)
    }

    private var fieldSurfaceFill: Color {
        Color.primary.opacity(colorScheme == .dark ? 0.075 : 0.045)
    }

    private func fieldSurfaceBorder(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.18 : 0.12), lineWidth: 1)
    }

    private func color(from value: CalendarWorkbenchV21Color) -> Color {
        Color(red: value.red, green: value.green, blue: value.blue, opacity: value.opacity)
    }

    private func colorValue(from color: Color) -> CalendarWorkbenchV21Color {
        let resolved = NSColor(color).usingColorSpace(.deviceRGB) ?? NSColor.controlAccentColor
        return CalendarWorkbenchV21Color(
            red: Double(resolved.redComponent),
            green: Double(resolved.greenComponent),
            blue: Double(resolved.blueComponent),
            opacity: Double(resolved.alphaComponent)
        )
    }

    private func setCountdownColor(_ value: CalendarWorkbenchV21Color) {
        countdownColor = color(from: value)
        countdownHex = hexString(for: value)
    }

    private func applyCountdownHex() {
        let raw = countdownHex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard raw.count == 6, let rgb = Int(raw, radix: 16) else { return }
        let value = CalendarWorkbenchV21Color(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
        setCountdownColor(value)
    }

    private func sampleCountdownColor() {
        NSColorSampler().show { selectedColor in
            guard let selectedColor,
                  let resolved = selectedColor.usingColorSpace(.deviceRGB) else { return }
            let value = CalendarWorkbenchV21Color(
                red: Double(resolved.redComponent),
                green: Double(resolved.greenComponent),
                blue: Double(resolved.blueComponent)
            )
            setCountdownColor(value)
        }
    }

    private func hexString(for value: CalendarWorkbenchV21Color) -> String {
        let red = Int((min(max(value.red, 0), 1) * 255).rounded())
        let green = Int((min(max(value.green, 0), 1) * 255).rounded())
        let blue = Int((min(max(value.blue, 0), 1) * 255).rounded())
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: date)
    }

    private func saveCountdown() {
        guard !countdownName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            countdownShowsNameError = true
            return
        }
        let value = colorValue(from: countdownColor)
        if let editingCountdownID {
            model.updateCountdown(
                id: editingCountdownID,
                title: countdownName,
                date: countdownDate,
                repeatRule: countdownRepeat,
                includesToday: countdownIncludesToday,
                usesIcon: countdownUsesIcon,
                color: value
            )
            self.editingCountdownID = nil
            countdownShowsNameError = false
        } else {
            model.addCountdown(
                title: countdownName,
                date: countdownDate,
                repeatRule: countdownRepeat,
                includesToday: countdownIncludesToday,
                usesIcon: countdownUsesIcon,
                color: value
            )
            resetCountdownComposer()
        }
    }

    private func resetCountdownComposer() {
        editingCountdownID = nil
        countdownName = ""
        countdownRepeat = .none
        countdownIncludesToday = false
        countdownUsesIcon = false
        setCountdownColor(CalendarWorkbenchV21Color.presets[0])
        countdownShowsNameError = false
        withAnimation(selectionAnimation) { showsCountdownComposer = false }
    }

    private func beginAddingCountdown() {
        editingCountdownID = nil
        countdownName = ""
        countdownDate = model.selectedDate ?? model.today
        countdownRepeat = .none
        countdownIncludesToday = false
        countdownUsesIcon = false
        setCountdownColor(CalendarWorkbenchV21Color.presets[0])
        countdownShowsNameError = false
        model.selectAndReveal(countdownDate)
        withAnimation(selectionAnimation) { showsCountdownComposer = true }
    }

    private func beginEditingCountdown(_ countdown: CalendarWorkbenchV21Countdown) {
        showsCountdownComposer = false
        editingCountdownID = countdown.id
        expandedCountdownID = countdown.id
        countdownName = countdown.title
        countdownDate = countdown.date
        countdownRepeat = countdown.repeatRule
        countdownIncludesToday = countdown.includesToday
        countdownUsesIcon = countdown.usesIcon
        setCountdownColor(countdown.color)
        countdownShowsNameError = false
        model.selectAndReveal(countdown.date)
    }

    private func cancelCountdownEditing() {
        editingCountdownID = nil
        countdownShowsNameError = false
    }

    private func canMoveCountdown(_ countdown: CalendarWorkbenchV21Countdown, by offset: Int) -> Bool {
        guard let index = model.countdowns.firstIndex(where: { $0.id == countdown.id }) else { return false }
        return model.countdowns.indices.contains(index + offset)
    }

    private var countdownDeleteAlertBinding: Binding<Bool> {
        Binding(
            get: { pendingCountdownDeletionID != nil },
            set: { if !$0 { pendingCountdownDeletionID = nil } }
        )
    }

    private func confirmCountdownDeletion() {
        guard let id = pendingCountdownDeletionID else { return }
        model.deleteCountdown(id: id)
        pendingCountdownDeletionID = nil
        if editingCountdownID == id { editingCountdownID = nil }
        if expandedCountdownID == id { expandedCountdownID = nil }
    }

    private func linkedDateControl(
        title: String,
        date: Binding<Date>,
        onSet: @escaping (Date) -> Void
    ) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 62, alignment: .leading)

            Button {
                model.selectAndReveal(date.wrappedValue)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                    Text(formattedDate(date.wrappedValue))
                        .monospacedDigit()
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 9)
                .frame(height: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(fieldSurfaceFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(fieldSurfaceBorder(cornerRadius: 8))
            .help("与左侧大日历联动")

            HStack(spacing: 2) {
                dateStepButton(systemName: "chevron.left", help: "前一天") {
                    if let shifted = model.calendar.date(byAdding: .day, value: -1, to: date.wrappedValue) {
                        onSet(shifted)
                    }
                }
                Button("今天") { onSet(model.today) }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.medium))
                    .frame(height: 28)
                    .padding(.horizontal, 5)
                    .contentShape(Rectangle())
                dateStepButton(systemName: "chevron.right", help: "后一天") {
                    if let shifted = model.calendar.date(byAdding: .day, value: 1, to: date.wrappedValue) {
                        onSet(shifted)
                    }
                }
            }
            .padding(2)
            .background(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.54),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func dateStepButton(
        systemName: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.caption.weight(.semibold))
                .frame(width: 26, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func linkedTimeControl(title: String, date: Binding<Date>) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 62, alignment: .leading)
            Menu {
                ForEach(0..<24, id: \.self) { hour in
                    Button(String(format: "%02d 时", hour)) {
                        date.wrappedValue = settingTime(hour: hour, minute: minute(of: date.wrappedValue), on: date.wrappedValue)
                    }
                }
            } label: {
                timeMenuLabel(String(format: "%02d 时", hour(of: date.wrappedValue)))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)

            Text(":")
                .font(.headline)
                .foregroundStyle(.secondary)

            Menu {
                ForEach(0..<60, id: \.self) { minute in
                    Button(String(format: "%02d 分", minute)) {
                        date.wrappedValue = settingTime(hour: hour(of: date.wrappedValue), minute: minute, on: date.wrappedValue)
                    }
                }
            } label: {
                timeMenuLabel(String(format: "%02d 分", minute(of: date.wrappedValue)))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            Spacer(minLength: 0)
            Text("日期跟随完成日期")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func timeMenuLabel(_ value: String) -> some View {
        HStack(spacing: 5) {
            Text(value).monospacedDigit()
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 8, weight: .semibold))
        }
        .padding(.horizontal, 9)
        .frame(height: 32)
        .background(fieldSurfaceFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(fieldSurfaceBorder(cornerRadius: 8))
    }

    private func selectCalendarDate(_ date: Date) {
        let normalized = model.calendar.startOfDay(for: date)
        model.selectAndReveal(normalized)
        if model.mode == .todo {
            setQuickTaskDate(normalized)
        } else if showsCountdownComposer || editingCountdownID != nil {
            countdownDate = normalized
        }
    }

    private func setQuickTaskDate(_ date: Date) {
        let normalized = model.calendar.startOfDay(for: date)
        quickEntryDate = normalized
        quickCustomReminder = reminderTime(from: quickCustomReminder, movedTo: normalized)
        model.selectAndReveal(normalized)
    }

    private func setCountdownDate(_ date: Date) {
        let normalized = model.calendar.startOfDay(for: date)
        countdownDate = normalized
        model.selectAndReveal(normalized)
    }

    private func reminderTime(from source: Date, movedTo date: Date) -> Date {
        settingTime(hour: hour(of: source), minute: minute(of: source), on: date)
    }

    private func settingTime(hour: Int, minute: Int, on date: Date) -> Date {
        model.calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
    }

    private func hour(of date: Date) -> Int {
        model.calendar.component(.hour, from: date)
    }

    private func minute(of date: Date) -> Int {
        model.calendar.component(.minute, from: date)
    }

    private func scheduleControls(
        date: Binding<Date>,
        reminderChoice: Binding<CalendarWorkbenchV21ReminderChoice>,
        customReminder: Binding<Date>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            linkedDateControl(title: "完成日期", date: date) { newDate in
                let normalized = model.calendar.startOfDay(for: newDate)
                date.wrappedValue = normalized
                customReminder.wrappedValue = reminderTime(
                    from: customReminder.wrappedValue,
                    movedTo: normalized
                )
                model.selectAndReveal(normalized)
            }
            Picker("提醒", selection: reminderChoice) {
                ForEach(CalendarWorkbenchV21ReminderChoice.allCases) { choice in
                    Text(choice.rawValue).tag(choice)
                }
            }
            .pickerStyle(.segmented)
            if reminderChoice.wrappedValue == .custom {
                linkedTimeControl(title: "提醒时间", date: customReminder)
            }
        }
        .font(.caption)
        .padding(10)
        .background(fieldSurfaceFill, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(fieldSurfaceBorder(cornerRadius: 9))
    }

    private func taskScheduleEditor(_ task: CalendarWorkbenchV21Task) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("日期与提醒")
                    .font(.caption.weight(.semibold))
                Spacer()
                Button("收起") {
                    withAnimation(selectionAnimation) { editingTaskID = nil }
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(Color.accentColor)
            }
            scheduleControls(
                date: $taskEditDate,
                reminderChoice: $taskReminderChoice,
                customReminder: $taskCustomReminder
            )
            HStack {
                Spacer()
                Button("保存设置") {
                    model.updateTaskSchedule(
                        id: task.id,
                        date: taskEditDate,
                        reminderAt: reminderDate(
                            choice: taskReminderChoice,
                            dueDate: taskEditDate,
                            customDate: taskCustomReminder
                        )
                    )
                    withAnimation(selectionAnimation) { editingTaskID = nil }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(11)
        .background(glassSurfaceFill, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(glassSurfaceBorder(cornerRadius: 11))
    }

    private func beginTaskEditing(_ task: CalendarWorkbenchV21Task) {
        editingTaskID = task.id
        taskEditDate = task.date ?? model.today
        if let reminder = task.reminderAt {
            if abs(reminder.timeIntervalSince(model.endOfDayReminder(for: taskEditDate))) < 60 {
                taskReminderChoice = .endOfDay
            } else {
                taskReminderChoice = .custom
            }
            taskCustomReminder = reminder
        } else {
            taskReminderChoice = .none
            taskCustomReminder = model.endOfDayReminder(for: taskEditDate)
        }
    }

    private func reminderDate(choice: CalendarWorkbenchV21ReminderChoice,
                              dueDate: Date, customDate: Date) -> Date? {
        switch choice {
        case .endOfDay:
            return model.endOfDayReminder(for: dueDate)
        case .custom:
            return customDate
        case .none:
            return nil
        }
    }

    private func reminderChoiceTitle(_ choice: CalendarWorkbenchV21ReminderChoice) -> String {
        choice.rawValue
    }

    private func shortDate(_ date: Date) -> String {
        if model.calendar.isDateInToday(date) { return "今天" }
        if model.calendar.isDateInTomorrow(date) { return "明天" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }

    private var monthDays: [Date] {
        guard let interval = model.calendar.dateInterval(of: .month, for: model.displayedMonth) else { return [] }
        let firstWeekday = model.calendar.component(.weekday, from: interval.start)
        let leading = (firstWeekday - model.calendar.firstWeekday + 7) % 7
        let gridStart = model.calendar.date(byAdding: .day, value: -leading, to: interval.start)
            ?? interval.start
        return (0..<42).compactMap {
            model.calendar.date(byAdding: .day, value: $0, to: gridStart)
        }
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
        guard !symbols.isEmpty else { return [] }
        let start = max(0, min(symbols.count - 1, model.calendar.firstWeekday - 1))
        return Array(symbols[start...]) + Array(symbols[..<start])
    }

    private var monthTransition: AnyTransition { .opacity }

    private func switchMonth(by value: Int) {
        let animation: Animation = reduceMotion
            ? .easeOut(duration: 0.10)
            : .easeInOut(duration: 0.14)
        withAnimation(animation) { model.moveMonth(by: value) }
    }

    private func submitQuickEntry() {
        let submitted = quickEntryText
        let reminder = reminderDate(
            choice: quickReminderChoice,
            dueDate: quickEntryDate,
            customDate: quickCustomReminder
        )
        model.addTask(
            title: submitted,
            date: quickEntryDate,
            reminderAt: reminder,
            schedulesReminder: quickReminderChoice != .none
        )
        if !submitted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            quickEntryText = ""
        }
    }

    private func taskReminderText(_ task: CalendarWorkbenchV21Task) -> String? {
        guard let reminder = task.reminderAt else { return nil }
        if let date = task.date,
           abs(reminder.timeIntervalSince(model.endOfDayReminder(for: date))) < 60 {
            return "24:00"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: reminder)
    }

    private func relativeDate(_ date: Date) -> String {
        if model.calendar.isDateInToday(date) { return "今天" }
        let difference = model.calendar.dateComponents(
            [.day], from: model.today, to: model.calendar.startOfDay(for: date)
        ).day ?? 0
        if difference == 1 { return "明天" }
        if difference == -1 { return "昨天" }
        if difference > 0 { return "\(difference)天后" }
        return "已逾期\(abs(difference))天"
    }
}

private struct CalendarWorkbenchV21DayCell: View {
    let date: Date
    let calendar: Calendar
    let today: Date
    let isInDisplayedMonth: Bool
    let isSelected: Bool
    let itemCount: Int
    let reduceMotion: Bool
    let onSelect: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    private var isToday: Bool { calendar.isDate(date, inSameDayAs: today) }
    private var isTodaySelected: Bool { isToday && isSelected }
    private var showsHoverPreview: Bool { isHovered && !isSelected && !isToday }
    private var showsContainer: Bool { isToday || isSelected || showsHoverPreview }

    var body: some View {
        Button(action: onSelect) {
            ZStack {
                container

                VStack(spacing: 3) {
                    Text(dayNumber)
                        .font(.system(size: 30, weight: isSelected || isToday ? .semibold : .medium))
                        .monospacedDigit()
                        .foregroundStyle(dayTextColor)
                    Text(lunarLabel)
                        .font(.system(size: 14, weight: isFestival ? .medium : .regular))
                        .lineLimit(1)
                        .minimumScaleFactor(0.92)
                        .foregroundStyle(lunarTextColor)
                }
                .opacity(isInDisplayedMonth ? 1 : (colorScheme == .dark ? 0.38 : 0.32))

                if let holidayInfo {
                    Text(holidayInfo.type.shortLabel)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(
                            holidayInfo.type == .rest
                                ? Color(nsColor: .systemGreen)
                                : Color(nsColor: .systemOrange),
                            in: Circle()
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(.top, 5)
                        .padding(.trailing, 5)
                        .opacity(isInDisplayedMonth ? 1 : 0.58)
                }

                if isTodaySelected {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 9, height: 9)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.leading, 7)
                        .padding(.top, 6)
                        .transition(reduceMotion
                            ? .opacity
                            : .scale(scale: 0.7).combined(with: .opacity))
                }

                if itemCount > 0 && !isTodaySelected {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(isSelected ? Color.accentColor : Color.accentColor.opacity(0.9))
                            .frame(width: 5, height: 5)
                        if itemCount > 1 {
                            Text("\(itemCount)")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 3)
                }
            }
            .frame(width: 82, height: 78)
            .contentShape(Rectangle())
        }
        .buttonStyle(CalendarWorkbenchV21DatePressStyle(reduceMotion: reduceMotion))
        .onHover { hovering in
            let animation: Animation = reduceMotion
                ? .easeOut(duration: 0.12)
                : .easeOut(duration: 0.11)
            withAnimation(animation) { isHovered = hovering }
        }
        .animation(stateAnimation, value: isSelected)
        .animation(stateAnimation, value: isTodaySelected)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var container: some View {
        if reduceMotion {
            ZStack {
                stateShape(
                    cornerRadius: 36,
                    width: 72,
                    height: 72,
                    fill: Color.accentColor.opacity(colorScheme == .dark ? 0.10 : 0.055),
                    stroke: Color.accentColor.opacity(0.55),
                    lineWidth: 1.7
                )
                .opacity(isToday && !isSelected ? 1 : 0)

                stateShape(
                    cornerRadius: 14,
                    width: 82,
                    height: 76,
                    fill: Color.white.opacity(colorScheme == .dark ? 0.13 : 0.64),
                    stroke: Color.accentColor.opacity(0.95),
                    lineWidth: 2.5
                )
                .opacity(isSelected ? 1 : 0)

                stateShape(
                    cornerRadius: 14,
                    width: 82,
                    height: 76,
                    fill: Color.primary.opacity(colorScheme == .dark ? 0.075 : 0.035),
                    stroke: Color.primary.opacity(colorScheme == .dark ? 0.22 : 0.15),
                    lineWidth: 1.25
                )
                .opacity(showsHoverPreview ? 1 : 0)
            }
        } else {
            stateShape(
                cornerRadius: containerCornerRadius,
                width: containerWidth,
                height: containerHeight,
                fill: containerFill,
                stroke: containerStroke,
                lineWidth: containerLineWidth
            )
            .opacity(showsContainer ? 1 : 0)
            .scaleEffect(showsHoverPreview ? 1 : (showsContainer ? 1 : 0.98))
        }
    }

    private func stateShape(cornerRadius: CGFloat,
                            width: CGFloat,
                            height: CGFloat,
                            fill: Color,
                            stroke: Color,
                            lineWidth: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(fill)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(stroke, lineWidth: lineWidth)
            }
            .frame(width: width, height: height)
    }

    private var containerWidth: CGFloat {
        isToday && !isSelected ? 72 : 82
    }

    private var containerHeight: CGFloat {
        isToday && !isSelected ? 72 : 76
    }

    private var containerCornerRadius: CGFloat {
        isToday && !isSelected ? 36 : 14
    }

    private var containerFill: Color {
        if isSelected {
            return Color.white.opacity(colorScheme == .dark ? 0.13 : 0.64)
        }
        if isToday {
            return Color.accentColor.opacity(colorScheme == .dark ? 0.10 : 0.055)
        }
        if showsHoverPreview {
            return Color.primary.opacity(colorScheme == .dark ? 0.075 : 0.035)
        }
        return .clear
    }

    private var containerStroke: Color {
        if isSelected || isToday { return Color.accentColor.opacity(isSelected ? 0.95 : 0.55) }
        if showsHoverPreview { return Color.primary.opacity(colorScheme == .dark ? 0.22 : 0.15) }
        return .clear
    }

    private var containerLineWidth: CGFloat {
        isSelected ? 2.5 : (isToday ? 1.8 : 1.25)
    }

    private var dayTextColor: Color {
        if isFestival { return Color(nsColor: .systemRed) }
        if isToday { return Color.accentColor }
        return Color.primary
    }

    private var lunarTextColor: Color {
        if isFestival { return Color(nsColor: .systemRed) }
        if isToday { return Color.accentColor }
        return isSelected ? Color.primary : Color.primary.opacity(0.86)
    }

    private var stateAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.12)
            : .interactiveSpring(response: 0.21, dampingFraction: 0.91, blendDuration: 0.05)
    }

    private var dayNumber: String {
        String(calendar.component(.day, from: date))
    }

    private var lunarLabel: String {
        CalendarWorkbenchV21Lunar.label(for: date)
    }

    private var isFestival: Bool {
        CalendarWorkbenchV21Lunar.isFestival(date)
    }

    private var holidayInfo: CalendarWorkbenchV21Holiday.Info? {
        CalendarWorkbenchV21Holiday.info(for: date)
    }

    private var accessibilityLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"
        let states = [isToday ? "今天" : nil, isSelected ? "已选中" : nil].compactMap { $0 }
        return "\(formatter.string(from: date))，农历\(lunarLabel)\(states.isEmpty ? "" : "，\(states.joined(separator: "，"))")"
    }
}

private struct CalendarWorkbenchV21TaskRow: View {
    let task: CalendarWorkbenchV21Task
    let relativeDate: String
    let reminderText: String?
    let isSelected: Bool
    let isExpanded: Bool
    @Binding var detailsDraft: String
    let onSelect: () -> Void
    let onToggle: () -> Void
    let onSaveDetails: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Button(action: onToggle) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(task.isCompleted ? Color.accentColor : Color.primary.opacity(0.72))
                }
                .buttonStyle(.plain)
                .help(task.isCompleted ? "恢复为未完成" : "标记为已完成")

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                        .strikethrough(task.isCompleted)
                        .lineLimit(1)
                    HStack(spacing: 7) {
                        Label(relativeDate, systemImage: "calendar")
                        if let reminderText {
                            Label(reminderText, systemImage: "bell.fill")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 6)
                if task.isImportant {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 6, height: 6)
                        .accessibilityLabel("重点")
                }
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected || isHovered ? Color.accentColor : Color.secondary)
                    .frame(width: 18)
            }
            .padding(.horizontal, 11)
            .frame(height: 62)
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)

            if isExpanded {
                Divider().opacity(0.34)
                    .padding(.horizontal, 11)
                VStack(alignment: .leading, spacing: 8) {
                    Text("描述")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ZStack(alignment: .topLeading) {
                        if detailsDraft.isEmpty {
                            Text("补充下载地址、操作步骤或其他说明…")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $detailsDraft)
                            .font(.caption)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 62, maxHeight: 92)
                            .padding(3)
                    }
                    .background(
                        Color.primary.opacity(colorScheme == .dark ? 0.07 : 0.035),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                    HStack {
                        Text(task.details.isEmpty ? "尚未添加描述" : "修改后保存")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("保存描述", action: onSaveDetails)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                    }
                }
                .padding(.horizontal, 11)
                .padding(.top, 10)
                .padding(.bottom, 11)
                .transition(.opacity)
            }
        }
        .background(
            Color.white.opacity(colorScheme == .dark
                ? (isSelected ? 0.15 : (isHovered ? 0.12 : 0.075))
                : (isSelected ? 0.78 : (isHovered ? 0.68 : 0.46))),
            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(
                    isSelected
                        ? Color.accentColor
                        : Color.white.opacity(colorScheme == .dark
                            ? (isHovered ? 0.22 : 0.12)
                            : (isHovered ? 0.88 : 0.62)),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.10)) { isHovered = hovering }
        }
        .help("点击展开描述；点击左侧圆圈切换完成状态")
    }
}

private struct CalendarWorkbenchV21CountdownRow: View {
    let countdown: CalendarWorkbenchV21Countdown
    let countdownText: String
    let color: Color
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onEdit: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(color.opacity(colorScheme == .dark ? 0.22 : 0.14))
                Image(systemName: countdown.usesIcon ? "calendar.badge.clock" : "textformat")
                    .foregroundStyle(color)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(countdown.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(countdown.repeatRule.rawValue)
                    if countdown.includesToday { Text("含当天") }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(countdownText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .multilineTextAlignment(.trailing)
            Menu {
                Button("编辑", systemImage: "pencil", action: onEdit)
                Divider()
                Button("上移", systemImage: "arrow.up", action: onMoveUp)
                    .disabled(!canMoveUp)
                Button("下移", systemImage: "arrow.down", action: onMoveDown)
                    .disabled(!canMoveDown)
                Divider()
                Button("删除", systemImage: "trash", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 28)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.horizontal, 11)
        .frame(height: 66)
        .background(
            Color.white.opacity(colorScheme == .dark ? 0.075 : 0.46),
            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.16 : 0.72), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
    }
}

private struct CalendarWorkbenchV21TaskPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.easeOut(duration: 0.07), value: configuration.isPressed)
    }
}

private struct CalendarWorkbenchV21WindowDragRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}

private struct CalendarWorkbenchV21DatePressStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.98 : 1))
            .opacity(reduceMotion && configuration.isPressed ? 0.78 : 1)
            .animation(
                reduceMotion ? .easeOut(duration: 0.1) : .easeOut(duration: 0.07),
                value: configuration.isPressed
            )
    }
}
