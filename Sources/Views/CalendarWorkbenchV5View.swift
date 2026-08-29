import SwiftUI
import AppKit

struct V5DragWorkbenchPoints: Equatable {
    var taskSources: [UUID: CGPoint] = [:]
    var dayIndicators: [Date: CGPoint] = [:]
}

struct V5DragWorkbenchPointsPreferenceKey: PreferenceKey {
    static var defaultValue = V5DragWorkbenchPoints()

    static func reduce(value: inout V5DragWorkbenchPoints,
                       nextValue: () -> V5DragWorkbenchPoints) {
        let next = nextValue()
        value.taskSources.merge(next.taskSources, uniquingKeysWith: { _, new in new })
        value.dayIndicators.merge(next.dayIndicators, uniquingKeysWith: { _, new in new })
    }
}

struct CalendarWorkbenchV5View: View {
    @ObservedObject var model: CalendarWorkbenchV5Model
    let onAppearanceChange: (V5AppearancePreference) -> Void
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("calendarWorkbenchV5Appearance") private var appearanceRaw = V5AppearancePreference.system.rawValue
    @Namespace private var liquidSelection
    @FocusState private var composerFocused: Bool
    @State private var dayFrames: [Date: CGRect] = [:]
    @State private var dragWorkbenchPoints = V5DragWorkbenchPoints()
    @State private var taskDrag: V5TaskDragSession?
    @State private var dropPulseDate: Date?
    @State private var revealedTaskID: UUID?
    @State private var visualAppearance: V5AppearancePreference?
    @State private var appearanceTransitionID = UUID()

    private let columns = Array(repeating: GridItem(.fixed(82), spacing: 4), count: 7)

    var body: some View {
        HStack(spacing: 0) {
            calendarPane.frame(width: 650)
            Rectangle().fill(Color.primary.opacity(0.11)).frame(width: 1)
            taskPane.frame(width: 409)
        }
        .frame(width: 1060, height: 660)
        .background(rootTint)
        .glassBorder(cornerRadius: 18)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .coordinateSpace(name: "v5-workbench")
        .onPreferenceChange(V5DayFramePreferenceKey.self) { dayFrames = $0 }
        .onPreferenceChange(V5DragWorkbenchPointsPreferenceKey.self) { dragWorkbenchPoints = $0 }
        .overlay(alignment: .topLeading) {
            if let taskDrag,
               let position = V5ResolvedTaskDragGeometry.renderedPosition(
                   for: taskDrag.phase,
                   pointer: taskDrag.location,
                   sourceAnchor: taskDrag.sourcePoint,
                   targetAnchor: taskDrag.targetPoint
               ) {
                V5TaskDragOrb(session: taskDrag, position: position, reduceMotion: reduceMotion)
                    .allowsHitTesting(false)
            }
        }
        .preferredColorScheme(appearance.colorScheme)
        .onAppear {
            visualAppearance = appearance
            onAppearanceChange(appearance)
        }
        .onChange(of: appearanceRaw) { onAppearanceChange(appearance) }
        .onKeyPress(.escape) { onClose(); return .handled }
    }

    private var calendarPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.monthTitle).font(.system(size: 21, weight: .semibold)).monospacedDigit()
                    Text("日历与待办").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                monthButton("chevron.left", label: "上个月") { moveMonth(-1) }
                Button("今天") { animate { model.jumpToToday() } }
                    .buttonStyle(.bordered).controlSize(.small).accessibilityIdentifier("v5-today")
                monthButton("chevron.right", label: "下个月") { moveMonth(1) }
            }
            .frame(height: 43)
            .padding(.bottom, 10)

            HStack(spacing: 4) {
                ForEach(model.weekdaySymbols, id: \.self) { symbol in
                    Text(symbol).font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary).frame(width: 82)
                }
            }
            .padding(.bottom, 7)

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(model.monthDays.enumerated()), id: \.offset) { index, date in
                    let taskCounts = model.taskCounts(on: date)
                    V5DayCell(
                        date: date,
                        calendar: model.calendar,
                        today: model.today,
                        isInMonth: model.calendar.isDate(date, equalTo: model.displayedMonth, toGranularity: .month),
                        isSelected: model.calendar.isDate(date, inSameDayAs: model.selectedDate),
                        taskCounts: taskCounts,
                        selectionNamespace: liquidSelection,
                        reduceMotion: reduceMotion,
                        isDropTarget: taskDrag?.targetDate.map {
                            model.calendar.isDate($0, inSameDayAs: date)
                        } == true,
                        isDropArrival: dropPulseDate.map {
                            model.calendar.isDate($0, inSameDayAs: date)
                        } == true
                    ) {
                        animate { model.select(date) }
                    }
                    .accessibilityIdentifier("v5-day-\(index)")
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 14) {
                Label("选中", systemImage: "circle.inset.filled")
                Label("今天", systemImage: "circle")
                Label("未完成", systemImage: "circle")
                Label("全完成", systemImage: "circle.fill")
                Spacer()
                Text("悬停速览 · 点击后保持")
            }
            .font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 15)
    }

    private var taskPane: some View {
        CalendarWorkbenchV5Sidebar(
            model: model,
            appearance: visualAppearance ?? appearance,
            onSelectAppearance: selectAppearance,
            draggingTaskID: taskDrag?.taskID,
            revealedTaskID: revealedTaskID,
            onTaskDragChanged: updateTaskDrag,
            onTaskDragEnded: finishTaskDrag,
            onClose: onClose
        )
    }

    private func selectAppearance(_ option: V5AppearancePreference) {
        guard option != (visualAppearance ?? appearance) else { return }
        let transitionID = UUID()
        appearanceTransitionID = transitionID
        withAnimation(reduceMotion ? .easeOut(duration: 0.08) :
                      .interactiveSpring(response: V5AppearanceTransitionTiming.sliderResponse,
                                         dampingFraction: 0.91)) {
            visualAppearance = option
        }
        DispatchQueue.main.asyncAfter(
            deadline: .now() + (reduceMotion ? 0.03 : V5AppearanceTransitionTiming.commitDelay)
        ) {
            guard appearanceTransitionID == transitionID else { return }
            withAnimation(.easeInOut(duration: reduceMotion ? 0.06 : 0.16)) {
                appearanceRaw = option.rawValue
            }
        }
    }

    private func updateTaskDrag(_ task: CalendarWorkbenchV5Task,
                                location: CGPoint, startLocation _: CGPoint) {
        guard !task.legacy.isCompleted else { return }
        let targetDate = V5TaskDropGeometry.targetDate(at: location, dayFrames: dayFrames)
        let phase: V5TaskDragPhase = targetDate == nil ? .dragging : .targeted

        if taskDrag?.taskID != task.id {
            guard let sourcePoint = dragWorkbenchPoints.taskSources[task.id] else {
                return
            }
            let sessionID = UUID()
            taskDrag = V5TaskDragSession(
                id: sessionID, taskID: task.id,
                sourceDate: task.metadata.dueDate,
                sourcePoint: sourcePoint, location: location,
                targetDate: targetDate, targetPoint: nil, phase: .launching
            )
            model.clearTaskSelection()
            DispatchQueue.main.async {
                guard taskDrag?.id == sessionID else { return }
                withAnimation(catchSpring) {
                    taskDrag?.phase = .catching
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.04 : 0.13)) {
                guard taskDrag?.id == sessionID,
                      taskDrag?.phase == .launching || taskDrag?.phase == .catching else { return }
                withAnimation(reduceMotion ? .easeOut(duration: 0.04) : .easeOut(duration: 0.08)) {
                    taskDrag?.phase = taskDrag?.targetDate == nil ? .dragging : .targeted
                }
            }
            return
        }

        if taskDrag?.phase == .launching || taskDrag?.phase == .catching {
            withAnimation(catchSpring) {
                taskDrag?.location = location
                taskDrag?.targetDate = targetDate
            }
            return
        }

        taskDrag?.location = location
        if taskDrag?.targetDate != targetDate || taskDrag?.phase != phase {
            withAnimation(dragSpring) {
                taskDrag?.targetDate = targetDate
                taskDrag?.phase = phase
            }
        }
    }

    private func finishTaskDrag(_ task: CalendarWorkbenchV5Task, location: CGPoint) {
        guard var session = taskDrag, session.taskID == task.id else { return }
        let targetDate = V5TaskDropGeometry.targetDate(at: location, dayFrames: dayFrames)
            ?? session.targetDate
        let isSameDay = targetDate.flatMap { target in
            session.sourceDate.map { model.calendar.isDate($0, inSameDayAs: target) }
        } == true

        guard let targetDate, dayFrames[targetDate] != nil, !isSameDay,
              let targetPoint = dragWorkbenchPoints.dayIndicators[targetDate] else {
            session.phase = .returning
            session.targetDate = nil
            session.targetPoint = nil
            withAnimation(dragSpring) { taskDrag = session }
            clearDragSession(session.id, after: reduceMotion ? 0.08 : 0.22)
            return
        }

        session.phase = .absorbing
        session.targetDate = targetDate
        session.targetPoint = targetPoint
        withAnimation(absorbAnimation) { taskDrag = session }

        let settleDelay = reduceMotion ? 0.06 : V5TaskDropAnimationTiming.modelCommitDelay
        DispatchQueue.main.asyncAfter(deadline: .now() + settleDelay) {
            guard taskDrag?.id == session.id else { return }
            model.moveTask(id: task.id, to: targetDate)
            taskDrag = nil
            withAnimation(revealSpring) {
                revealedTaskID = task.id
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.18 : 0.72)) {
                withAnimation(.easeOut(duration: 0.16)) {
                    if revealedTaskID == task.id { revealedTaskID = nil }
                }
            }
        }
    }

    private func clearDragSession(_ sessionID: UUID, after delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard taskDrag?.id == sessionID else { return }
            withAnimation(.easeOut(duration: reduceMotion ? 0.05 : 0.12)) { taskDrag = nil }
        }
    }

    private var dragSpring: Animation {
        reduceMotion ? .easeOut(duration: 0.08) : .interactiveSpring(response: 0.24, dampingFraction: 0.88)
    }

    private var catchSpring: Animation {
        reduceMotion ? .easeOut(duration: 0.05) : .interactiveSpring(response: 0.18, dampingFraction: 0.82)
    }

    private var absorbAnimation: Animation {
        .easeOut(duration: reduceMotion ? 0.06 : V5TaskDropAnimationTiming.absorbDuration)
    }

    private var revealSpring: Animation {
        reduceMotion ? .easeOut(duration: 0.1) : .interactiveSpring(response: 0.32, dampingFraction: 0.82)
    }

    private var appearance: V5AppearancePreference {
        V5AppearancePreference(rawValue: appearanceRaw) ?? .system
    }

    private var composer: some View {
        VStack(spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill").font(.system(size: 18)).foregroundStyle(Color.accentColor)
                TextField("添加待办到 \(shortDate(model.draftDate))", text: $model.draftTitle)
                    .textFieldStyle(.plain).focused($composerFocused)
                    .onSubmit { addTask() }.accessibilityIdentifier("v5-add-title")
                Button("添加") { addTask() }.buttonStyle(.borderedProminent).controlSize(.small)
                    .disabled(model.draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("v5-add")
            }
            HStack(spacing: 8) {
                DatePicker("", selection: $model.draftDate, displayedComponents: .date).labelsHidden().controlSize(.small)
                TextField("简短描述（可选）", text: $model.draftDetails).textFieldStyle(.roundedBorder)
                Toggle("提醒", isOn: $model.draftReminderEnabled).toggleStyle(.checkbox).controlSize(.small)
            }
            if model.draftReminderEnabled {
                HStack {
                    Text("提醒时间").font(.caption).foregroundStyle(.secondary)
                    DatePicker("", selection: $model.draftReminder, displayedComponents: [.date, .hourAndMinute]).labelsHidden().controlSize(.small)
                    Spacer()
                }
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(11)
        .background(cardFill, in: RoundedRectangle(cornerRadius: model.draftReminderEnabled ? 15 : 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: model.draftReminderEnabled ? 15 : 12).strokeBorder(Color.accentColor.opacity(0.18)))
        .animation(reduceMotion ? .easeOut(duration: 0.1) : .spring(response: 0.28, dampingFraction: 0.88), value: model.draftReminderEnabled)
    }

    private var emptyState: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 7) {
                Image(systemName: "checkmark.circle").font(.system(size: 24)).foregroundStyle(Color.accentColor)
                Text("这一天很轻松").font(.subheadline.weight(.semibold))
                Text("从上方直接添加，日期已经替你选好；只有主动打开“提醒”才会设置提醒。")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(cardFill, in: RoundedRectangle(cornerRadius: 12))
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder private func taskRow(_ task: CalendarWorkbenchV5Task) -> some View {
        if model.editingTaskID == task.id {
            V5TaskEditor(task: task, model: model, reduceMotion: reduceMotion)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
        } else {
            HStack(alignment: .top, spacing: 10) {
                Button { animate { model.toggleCompletion(id: task.id) } } label: {
                    Image(systemName: task.legacy.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18)).foregroundStyle(task.legacy.isCompleted ? Color.accentColor : Color.secondary)
                        .frame(width: 22, height: 26)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(task.legacy.isCompleted ? "恢复待办" : "完成待办")
                .accessibilityIdentifier("v5-toggle-\(task.id.uuidString)")

                Button { animate { model.beginEditing(task) } } label: {
                    HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(task.legacy.title).font(.subheadline.weight(.medium)).strikethrough(task.legacy.isCompleted)
                            .foregroundStyle(task.legacy.isCompleted ? .secondary : .primary)
                        if !task.metadata.details.isEmpty { Text(task.metadata.details).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                        HStack(spacing: 8) {
                            if let date = task.metadata.dueDate { Label(shortDate(date), systemImage: "calendar") }
                            if task.metadata.reminderAt != nil { Image(systemName: "bell.fill").foregroundStyle(Color.orange) }
                            if !task.legacy.tag.isEmpty { Text(task.legacy.tag) }
                        }.font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("v5-task-\(task.id.uuidString)")
            }
            .padding(10)
            .background(cardFill, in: RoundedRectangle(cornerRadius: 11))
        }
    }

    private func addTask() { animate { model.addDraft() }; composerFocused = true }
    private func moveMonth(_ amount: Int) { animate { model.moveMonth(by: amount) } }
    private func animate(_ body: () -> Void) { withAnimation(reduceMotion ? .easeOut(duration: 0.1) : .interactiveSpring(response: 0.28, dampingFraction: 0.86), body) }
    private func shortDate(_ date: Date) -> String { Self.shortFormatter.string(from: date) }

    private func monthButton(_ image: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: image).frame(width: 34, height: 30) }
            .buttonStyle(.borderless).accessibilityLabel(label)
    }

    private var cardFill: Color { Color.white.opacity(colorScheme == .dark ? 0.075 : 0.48) }
    private var rootTint: Color {
        if reduceTransparency { return Color(nsColor: .windowBackgroundColor) }
        return colorScheme == .dark ? Color(red: 0.025, green: 0.065, blue: 0.11).opacity(0.42) : Color.white.opacity(0.18)
    }

    private static let shortFormatter: DateFormatter = {
        let value = DateFormatter(); value.locale = Locale(identifier: "zh_CN"); value.dateFormat = "M月d日"; return value
    }()
}

private extension V5AppearancePreference {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

private struct V5DayCell: View {
    let date: Date
    let calendar: Calendar
    let today: Date
    let isInMonth: Bool
    let isSelected: Bool
    let taskCounts: V5DayTaskCounts
    let selectionNamespace: Namespace.ID
    let reduceMotion: Bool
    let isDropTarget: Bool
    let isDropArrival: Bool
    let onSelect: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var hovered = false

    private var indicatorStyle: V5DayTaskIndicatorStyle {
        .resolve(activeCount: taskCounts.active, completedCount: taskCounts.completed)
    }

    private var indicatorLayout: V5DayIndicatorLayout {
        .value(total: taskCounts.total, isToday: isToday)
    }

    var body: some View {
        Button(action: onSelect) {
            ZStack {
                if isSelected {
                    let glow = isDropTarget
                        ? V5SelectionGlowPresentation.dropTarget
                        : V5SelectionGlowPresentation.selected
                    RoundedRectangle(cornerRadius: isToday ? 39 : 16, style: .continuous)
                        .fill(Color.accentColor.opacity(isDropTarget ? 0.18 : (colorScheme == .dark ? 0.18 : 0.10)))
                        .overlay(
                            RoundedRectangle(cornerRadius: isToday ? 39 : 16, style: .continuous)
                                .strokeBorder(Color.accentColor.opacity(isDropTarget ? 1 : 0.92),
                                              lineWidth: isDropTarget ? 2.3 : 2)
                        )
                        .frame(width: isToday ? 78 : 82, height: 78)
                        .matchedGeometryEffect(id: "v5-liquid-selection", in: selectionNamespace)
                        .shadow(color: Color.accentColor.opacity(glow.innerOpacity), radius: glow.innerRadius)
                        .shadow(color: Color.accentColor.opacity(glow.outerOpacity), radius: glow.outerRadius)
                        .scaleEffect(glow.scale)
                } else if isDropTarget {
                    let glow = V5SelectionGlowPresentation.dropTarget
                    RoundedRectangle(cornerRadius: isToday ? 39 : 16, style: .continuous)
                        .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.20 : 0.13))
                        .overlay(
                            RoundedRectangle(cornerRadius: isToday ? 39 : 16, style: .continuous)
                                .strokeBorder(Color.accentColor.opacity(0.96), lineWidth: 2.1)
                        )
                        .frame(width: isToday ? 78 : 82, height: 78)
                        .shadow(color: Color.accentColor.opacity(glow.innerOpacity), radius: glow.innerRadius)
                        .shadow(color: Color.accentColor.opacity(glow.outerOpacity), radius: glow.outerRadius)
                        .scaleEffect(glow.scale)
                } else if isToday {
                    Circle().strokeBorder(Color.accentColor.opacity(0.72), lineWidth: 1.7).frame(width: 78, height: 78)
                } else if hovered {
                    RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(0.055))
                }
                VStack(spacing: 3) {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.system(size: V5DayCellPresentation.dateFontSize,
                                      weight: isSelected ? .semibold : .medium))
                        .monospacedDigit()
                    Text(CalendarWorkbenchV21Lunar.label(for: date))
                        .font(.system(size: 12,
                                      weight: CalendarWorkbenchV21Lunar.isFestival(date) ? .semibold : .regular))
                        .lineLimit(1)
                        .foregroundStyle(CalendarWorkbenchV21Lunar.isFestival(date) ? Color.orange : Color.secondary)
                        .offset(y: V5DayCellPresentation.lunarTextYOffset)
                }
                .opacity(isInMonth ? 1 : 0.35)
                if let info = CalendarWorkbenchV21Holiday.info(for: date) {
                    Text(info.type.shortLabel).font(.system(size: 9, weight: .bold)).foregroundStyle(info.type == .rest ? Color.green : Color.orange)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(6)
                }
                HStack(spacing: 3) {
                    Group {
                        switch indicatorStyle {
                        case .none:
                            Circle().fill(Color.clear)
                        case .activeRing:
                            Circle().strokeBorder(Color.accentColor, lineWidth: 1.35)
                        case .completedDot:
                            Circle().fill(Color.accentColor)
                        }
                    }
                    .frame(width: 7, height: 7)
                    .background {
                        GeometryReader { proxy in
                            let frame = proxy.frame(in: .named("v5-workbench"))
                            Color.clear.preference(
                                key: V5DragWorkbenchPointsPreferenceKey.self,
                                value: {
                                    var value = V5DragWorkbenchPoints()
                                    value.dayIndicators[date] = V5TaskDragAnchorGeometry.center(of: frame)
                                    return value
                                }()
                            )
                        }
                    }
                    if let countText = indicatorLayout.countText {
                        Text(countText)
                            .font(.system(size: indicatorLayout.countFontSize, weight: .medium))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                }
                .foregroundStyle(.secondary)
                .opacity(indicatorStyle == .none ? 0 : 1)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, V5DayCellPresentation.indicatorBottomPadding)
                .scaleEffect(isDropArrival ? 1.65 : 1)
                .shadow(color: Color.accentColor.opacity(isDropArrival ? 0.68 : 0),
                        radius: isDropArrival ? 6 : 0)
            }
            .frame(width: 82, height: 78)
            .contentShape(Rectangle())
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: V5DayFramePreferenceKey.self,
                        value: [date: proxy.frame(in: .named("v5-workbench"))]
                    )
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(reduceMotion ? .easeOut(duration: 0.08) :
                    .interactiveSpring(response: 0.24, dampingFraction: 0.84),
                   value: isDropArrival)
        .accessibilityLabel(Self.accessibilityFormatter.string(from: date))
    }

    private var isToday: Bool { calendar.isDate(date, inSameDayAs: today) }

    private static let accessibilityFormatter: DateFormatter = {
        let value = DateFormatter(); value.locale = Locale(identifier: "zh_CN"); value.dateFormat = "yyyy年M月d日"; return value
    }()
}

private struct V5TaskDragSession: Equatable {
    let id: UUID
    let taskID: UUID
    let sourceDate: Date?
    let sourcePoint: CGPoint
    var location: CGPoint
    var targetDate: Date?
    var targetPoint: CGPoint?
    var phase: V5TaskDragPhase
}

private struct V5TaskDragOrb: View {
    let session: V5TaskDragSession
    let position: CGPoint
    let reduceMotion: Bool

    private var presentation: V5TaskDragPresentation {
        V5TaskDragPresentation.value(for: session.phase)
    }

    var body: some View {
        orb
        .scaleEffect(presentation.scale)
        .opacity(presentation.opacity)
        .shadow(color: Color.accentColor.opacity(session.phase == .targeted ? 0.62 : 0.36),
                radius: session.phase == .absorbing ? 0 : (session.phase == .targeted ? 10 : 6))
        .position(position)
        .accessibilityHidden(true)
    }

    private var orb: some View {
        Circle()
            .strokeBorder(orbColor, lineWidth: session.phase == .absorbing ? 1.35 : (session.phase == .targeted ? 2.2 : 1.8))
        .frame(width: presentation.diameter, height: presentation.diameter)
    }

    private var orbColor: Color {
        switch session.phase {
        case .targeted, .absorbing:
            return .accentColor
        case .launching, .catching, .dragging, .returning:
            return Color.primary.opacity(0.78)
        }
    }
}

private struct V5DayFramePreferenceKey: PreferenceKey {
    static var defaultValue: [Date: CGRect] = [:]

    static func reduce(value: inout [Date: CGRect], nextValue: () -> [Date: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

private struct V5TaskEditor: View {
    let task: CalendarWorkbenchV5Task
    @ObservedObject var model: CalendarWorkbenchV5Model
    let reduceMotion: Bool
    @State private var title: String
    @State private var details: String
    @State private var date: Date
    @State private var reminderEnabled: Bool
    @State private var reminder: Date

    init(task: CalendarWorkbenchV5Task, model: CalendarWorkbenchV5Model, reduceMotion: Bool) {
        self.task = task; self.model = model; self.reduceMotion = reduceMotion
        _title = State(initialValue: task.legacy.title)
        _details = State(initialValue: task.metadata.details)
        _date = State(initialValue: task.metadata.dueDate ?? model.selectedDate)
        _reminderEnabled = State(initialValue: task.metadata.reminderAt != nil)
        _reminder = State(initialValue: task.metadata.reminderAt ?? model.selectedDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("待办标题", text: $title).textFieldStyle(.roundedBorder)
            TextField("简短描述", text: $details).textFieldStyle(.roundedBorder)
            HStack {
                DatePicker("", selection: $date, displayedComponents: .date).labelsHidden().controlSize(.small)
                Toggle("提醒", isOn: $reminderEnabled).toggleStyle(.checkbox).controlSize(.small)
                Spacer()
            }
            if reminderEnabled { DatePicker("提醒时间", selection: $reminder, displayedComponents: [.date, .hourAndMinute]).controlSize(.small) }
            HStack {
                Button("取消") { model.endEditing() }.buttonStyle(.bordered).controlSize(.small)
                Spacer()
                Button("保存") { model.update(id: task.id, title: title, details: details, date: date, reminderEnabled: reminderEnabled, reminder: reminder) }
                    .buttonStyle(.borderedProminent).controlSize(.small).disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("v5-save-edit")
            }
        }
        .padding(11).background(Color.accentColor.opacity(0.075), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.accentColor.opacity(0.34)))
        .animation(reduceMotion ? .easeOut(duration: 0.1) : .spring(response: 0.26, dampingFraction: 0.9), value: reminderEnabled)
    }
}
