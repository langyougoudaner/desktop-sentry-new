import SwiftUI

/// The first visible Deadline surface: a compact calendar on the left and a
/// state-aware list on the right. It stays independent from SettingsView.
struct DeadlinePanelView: View {
    @ObservedObject var store: DeadlineStore
    let onClose: () -> Void

    @State private var displayedMonth = Date()
    @State private var selectedDate: Date?
    @State private var filter: DeadlineListFilter = .upcoming
    @State private var showingAll = false
    @State private var editor: DeadlineEditorItem?
    @State private var deleteCandidate: DeadlineItem?

    private var displayedItems: [DeadlineItem] {
        if let selectedDate {
            return store.list(for: filter, selectedDate: selectedDate)
        }
        if showingAll {
            return store.deadlines.sorted { DeadlineCalendar.sortKey($0) < DeadlineCalendar.sortKey($1) }
        }
        return store.list(for: filter)
    }

    var body: some View {
        HStack(spacing: 0) {
            calendarColumn
                .frame(width: 300)
            Divider()
            listColumn
                .frame(minWidth: 500)
        }
        .padding(18)
        .frame(minWidth: 820, minHeight: 560)
        .onAppear {
            store.refreshReferenceDay()
            displayedMonth = store.referenceDay
        }
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
        .sheet(item: $editor) { item in
            DeadlineEditorView(store: store, item: item) {
                editor = nil
            }
            .frame(width: 430, height: 410)
        }
        .confirmationDialog(
            "永久删除截止日？",
            isPresented: Binding(
                get: { deleteCandidate != nil },
                set: { if !$0 { deleteCandidate = nil } }
            ),
            presenting: deleteCandidate
        ) { item in
            Button("永久删除", role: .destructive) {
                store.permanentlyDelete(id: item.id)
                deleteCandidate = nil
            }
            Button("取消", role: .cancel) { deleteCandidate = nil }
        } message: { item in
            Text("“\(item.title)”删除后无法恢复。")
        }
    }

    // MARK: - Calendar

    private var calendarColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("日历与提醒")
                        .font(.title2.weight(.semibold))
                    Text(monthTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("关闭日历与提醒")
            }

            HStack(spacing: 6) {
                Button { shiftMonth(by: -1) } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("上个月")
                Button("今天") {
                    displayedMonth = store.referenceDay
                    selectedDate = store.referenceDay
                    showingAll = false
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button { shiftMonth(by: 1) } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("下个月")
                Spacer()
            }

            calendarGrid

            Divider()

            VStack(alignment: .leading, spacing: 7) {
                Text("菜单栏重点")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let focused = store.focusedDeadline {
                    HStack(spacing: 8) {
                        Image(systemName: "flag.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(focused.title)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(2)
                            Text(store.state(for: focused).label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("暂无进行中的项目")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 0)

        }
        .padding(.trailing, 18)
    }

    private var calendarGrid: some View {
        let days = monthDays
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        return VStack(spacing: 7) {
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        calendarDayButton(day)
                    } else {
                        Color.clear.frame(height: 30)
                    }
                }
            }
        }
    }

    private func calendarDayButton(_ day: Date) -> some View {
        let isToday = sameDay(day, store.referenceDay)
        let isSelected = selectedDate.map { sameDay(day, $0) } ?? false
        let count = store.count(on: day)
        return Button {
            selectedDate = day
            showingAll = false
        } label: {
            VStack(spacing: 2) {
                Text(dayNumber(day))
                    .font(.caption.weight(isToday || isSelected ? .semibold : .regular))
                    .frame(width: 27, height: 24)
                    .background {
                        if isSelected {
                            Circle().fill(Color.accentColor)
                        } else if isToday {
                            Circle().stroke(Color.accentColor, lineWidth: 1.5)
                        }
                    }
                    .foregroundStyle(isSelected ? .white : .primary)
                Circle()
                    .fill(count > 0 ? Color.accentColor : Color.clear)
                    .frame(width: count > 0 ? 4 : 2, height: count > 0 ? 4 : 2)
            }
            .frame(maxWidth: .infinity, minHeight: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(monthDayAccessibility(day))，\(count) 个截止日")
    }

    // MARK: - List

    private var listColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedDate.map { "\(monthDayTitle($0))" } ?? (showingAll ? "全部" : filter.title))
                        .font(.title3.weight(.semibold))
                    Text(selectedDate == nil ? "\(displayedItems.count) 个项目" : "该日期的进行中项目")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    editor = DeadlineEditorItem(item: nil, defaultDate: selectedDate ?? store.referenceDay)
                } label: {
                    Label("添加截止日", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            HStack(spacing: 6) {
                if selectedDate == nil && showingAll {
                    Button("全部") { selectedDate = nil; showingAll = true }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                } else {
                    Button("全部") { selectedDate = nil; showingAll = true }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                ForEach(DeadlineListFilter.allCases, id: \.self) { item in
                    filterButton(item)
                }
            }

            Divider()

            if displayedItems.isEmpty {
                emptyState
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(displayedItems) { item in
                            deadlineRow(item)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.visible)
            }
        }
        .padding(.leading, 18)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: selectedDate == nil ? "calendar.badge.clock" : "calendar")
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text(selectedDate == nil ? (showingAll ? "暂无截止日" : filter.title) : "这一天没有项目")
                .font(.headline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(emptyDescription)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .multilineTextAlignment(.center)
    }

    private func deadlineRow(_ item: DeadlineItem) -> some View {
        HStack(spacing: 10) {
            Button {
                store.setFocus(id: item.id)
            } label: {
                Image(systemName: store.focusedDeadlineID == item.id ? "flag.fill" : "flag")
                    .foregroundStyle(store.focusedDeadlineID == item.id ? .orange : .secondary)
                    .frame(width: 18)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(store.focusedDeadlineID == item.id ? "已是重点" : "设为重点")

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Label(shortDate(item.targetDate), systemImage: "calendar")
                    if let time = item.notificationDateComponents {
                        Label(shortTime(time), systemImage: "bell")
                    }
                    Text(statusLabel(for: item))
                        .foregroundStyle(statusColor(for: item))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if item.notificationEnabled {
                Image(systemName: "bell.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("已开启通知")
            }

            Menu {
                Button("编辑") {
                    editor = DeadlineEditorItem(item: item, defaultDate: item.targetDate)
                }
                if item.status == .active {
                    Button("标记完成") { store.markCompleted(id: item.id) }
                    Button("归档") { store.archive(id: item.id) }
                } else if item.status == .completed {
                    Button("归档") { store.archive(id: item.id) }
                } else {
                    Button("恢复") { store.restore(id: item.id) }
                }
                Divider()
                Button("永久删除", role: .destructive) { deleteCandidate = item }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .accessibilityLabel("更多操作")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 11))
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .strokeBorder(store.focusedDeadlineID == item.id ? .orange.opacity(0.55) : .clear, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func filterButton(_ item: DeadlineListFilter) -> some View {
        if selectedDate == nil && !showingAll && filter == item {
            Button(item.title) {
                selectedDate = nil
                showingAll = false
                filter = item
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        } else {
            Button(item.title) {
                selectedDate = nil
                showingAll = false
                filter = item
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Date helpers

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年 M月"
        return formatter.string(from: displayedMonth)
    }

    private var monthDays: [Date?] {
        let calendar = DeadlineCalendar.localCalendar()
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        let count = calendar.range(of: .day, in: .month, for: interval.start)?.count ?? 0
        var days = Array<Date?>(repeating: nil, count: leading)
        days += (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        let symbols = formatter.shortStandaloneWeekdaySymbols.map { symbol in
            if symbol.hasPrefix("星期") { return String(symbol.dropFirst(2)) }
            if symbol.hasPrefix("周") { return String(symbol.dropFirst()) }
            return symbol
        }
        let calendar = DeadlineCalendar.localCalendar()
        let offset = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
        return Array(symbols[offset...]) + Array(symbols[..<offset])
    }

    private func shiftMonth(by value: Int) {
        let calendar = DeadlineCalendar.localCalendar()
        displayedMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) ?? displayedMonth
        selectedDate = nil
        showingAll = false
    }

    private func sameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        let calendar = DeadlineCalendar.localCalendar()
        return calendar.isDate(lhs, inSameDayAs: rhs)
    }

    private func dayNumber(_ date: Date) -> String {
        String(DeadlineCalendar.localCalendar().component(.day, from: date))
    }

    private func monthDayTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }

    private func monthDayAccessibility(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: date)
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }

    private func shortTime(_ components: DateComponents) -> String {
        String(format: "%02d:%02d", components.hour ?? 0, components.minute ?? 0)
    }

    private var emptyDescription: String {
        switch filter {
        case .upcoming: return "点击左侧日期或添加一个新的截止日"
        case .overdue: return "目前没有逾期项目"
        case .completed: return "完成的项目会保留在这里"
        case .archived: return "归档项目会保留在这里"
        }
    }

    private func stateColor(_ state: DeadlineDayState) -> Color {
        switch state {
        case .today: return .orange
        case .upcoming: return .secondary
        case .overdue: return .red
        }
    }

    private func statusLabel(for item: DeadlineItem) -> String {
        switch item.status {
        case .active: return store.state(for: item).label
        case .completed: return "已完成"
        case .archived: return "已归档"
        }
    }

    private func statusColor(for item: DeadlineItem) -> Color {
        switch item.status {
        case .active: return stateColor(store.state(for: item))
        case .completed, .archived: return .secondary
        }
    }
}

// MARK: - Editor

private struct DeadlineEditorItem: Identifiable {
    let id = UUID()
    let item: DeadlineItem?
    let defaultDate: Date
}

private struct DeadlineEditorView: View {
    @ObservedObject var store: DeadlineStore
    let item: DeadlineEditorItem
    let onFinished: () -> Void

    @State private var title: String
    @State private var targetDate: Date
    @State private var notificationEnabled: Bool
    @State private var reminderTime: Date
    @State private var didChooseTime: Bool
    @State private var errorMessage: String?

    init(store: DeadlineStore, item: DeadlineEditorItem, onFinished: @escaping () -> Void) {
        self.store = store
        self.item = item
        self.onFinished = onFinished
        let source = item.item
        _title = State(initialValue: source?.title ?? "")
        _targetDate = State(initialValue: source?.targetDate ?? item.defaultDate)
        _notificationEnabled = State(initialValue: source?.notificationEnabled ?? false)
        let components = source?.notificationDateComponents
        _reminderTime = State(initialValue: Calendar.autoupdatingCurrent.date(
            bySettingHour: components?.hour ?? 9,
            minute: components?.minute ?? 0,
            second: 0,
            of: Date()
        ) ?? Date())
        _didChooseTime = State(initialValue: components != nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(item.item == nil ? "添加截止日" : "编辑截止日")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("取消", action: onFinished)
                    .buttonStyle(.borderless)
            }

            TextField("标题", text: $title)
                .textFieldStyle(.roundedBorder)

            DatePicker("目标日期", selection: $targetDate, displayedComponents: .date)

            Toggle("开启一次性通知", isOn: $notificationEnabled)
                .onChange(of: notificationEnabled) { _, enabled in
                    if !enabled { didChooseTime = false }
                }

            if notificationEnabled {
                DatePicker("提醒时间", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    .onChange(of: reminderTime) { _, _ in didChooseTime = true }
                if !didChooseTime {
                    Label("请明确选择提醒时间后再保存", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()

            HStack {
                Spacer()
                Button("保存") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || (notificationEnabled && !didChooseTime))
            }
        }
        .padding(22)
    }

    private func save() {
        let components = notificationEnabled
            ? Calendar.autoupdatingCurrent.dateComponents([.hour, .minute], from: reminderTime)
            : nil
        let hour = notificationEnabled ? components?.hour : nil
        let minute = notificationEnabled ? components?.minute : nil
        let result: Result<DeadlineItem, DeadlineValidationError>
        if let existing = item.item {
            result = store.update(id: existing.id, title: title, targetDate: targetDate,
                                  notificationEnabled: notificationEnabled,
                                  notificationHour: hour, notificationMinute: minute)
        } else {
            result = store.add(title: title, targetDate: targetDate,
                               notificationEnabled: notificationEnabled,
                               notificationHour: hour, notificationMinute: minute)
        }
        switch result {
        case .success:
            onFinished()
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
}
