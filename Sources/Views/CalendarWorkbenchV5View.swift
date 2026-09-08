import SwiftUI
import AppKit

struct V5DragWorkbenchPoints: Equatable {
    var taskSources: [UUID: CGPoint] = [:]
    var taskFrames: [UUID: CGRect] = [:]
    var dayIndicators: [Date: CGPoint] = [:]
}

struct V5DragWorkbenchPointsPreferenceKey: PreferenceKey {
    static var defaultValue = V5DragWorkbenchPoints()

    static func reduce(value: inout V5DragWorkbenchPoints,
                       nextValue: () -> V5DragWorkbenchPoints) {
        let next = nextValue()
        value.taskSources.merge(next.taskSources, uniquingKeysWith: { _, new in new })
        value.taskFrames.merge(next.taskFrames, uniquingKeysWith: { _, new in new })
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
    @Environment(\.controlActiveState) private var controlActiveState
    @AppStorage("calendarWorkbenchV5Appearance") private var appearanceRaw = V5AppearancePreference.system.rawValue
    @Namespace private var liquidSelection
    @State private var dayFrames: [Date: CGRect] = [:]
    @State private var dragWorkbenchPoints = V5DragWorkbenchPoints()
    @State private var taskDrag: V5TaskDragSession?
    @State private var completionFlights: [UUID: V5TaskCompletionFlightSession] = [:]
    @State private var completionLifecycle = V5TaskCompletionLifecycle()
    @State private var pendingCompletion: V5PendingTaskCompletion?
    @State private var dropPulseDates: Set<Date> = []
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
        .onPreferenceChange(V5DragWorkbenchPointsPreferenceKey.self) { points in
            dragWorkbenchPoints = points
            startPendingCompletionIfPossible(using: points)
        }
        .overlay(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                if let revealedTaskID, let frame = dragWorkbenchPoints.taskFrames[revealedTaskID] {
                    V5TaskLandingOutline(frame: frame)
                        .id(revealedTaskID)
                        .transition(.opacity.animation(.easeOut(
                            duration: reduceMotion
                                ? 0.08
                                : V5TaskRowRevealPresentation.value.landingOutlineDuration
                        )))
                }
                if let taskDrag,
                   let position = V5ResolvedTaskDragGeometry.renderedPosition(
                       for: taskDrag.phase,
                       pointer: taskDrag.location,
                       sourceAnchor: taskDrag.sourcePoint,
                       targetAnchor: taskDrag.targetPoint
                   ) {
                    V5TaskDragOrb(session: taskDrag, position: position, reduceMotion: reduceMotion)
                }
                ForEach(Array(completionFlights.values), id: \.id) { flight in
                    V5TaskCompletionFlightView(session: flight)
                }
            }
            .allowsHitTesting(false)
        }
        .preferredColorScheme(appearance.colorScheme)
        .onAppear {
            visualAppearance = appearance
            onAppearanceChange(appearance)
        }
        .onChange(of: appearanceRaw) { onAppearanceChange(appearance) }
        .onChange(of: model.selectedDate) { _, _ in
            _ = completionLifecycle.navigate()
            completionFlights.removeAll()
            pendingCompletion = nil
            dropPulseDates.removeAll()
            cancelTaskDrag()
        }
        .onChange(of: model.displayedMonth) { _, newMonth in
            // A pending off-screen completion owns this one month change. Any
            // other month change invalidates captured calendar coordinates.
            if let pendingCompletion,
               let dueDate = pendingCompletion.task.metadata.dueDate,
               model.calendar.isDate(newMonth, equalTo: dueDate, toGranularity: .month) {
                return
            }
            pendingCompletion = nil
            _ = completionLifecycle.calendarChanged()
            completionFlights.removeAll()
            dropPulseDates.removeAll()
        }
        .onChange(of: controlActiveState) { _, state in
            if state == .inactive {
                _ = completionLifecycle.cancelAll()
                completionFlights.removeAll()
                pendingCompletion = nil
                dropPulseDates.removeAll()
                cancelTaskDrag()
            }
        }
        .onDisappear {
            _ = completionLifecycle.cancelAll()
            completionFlights.removeAll()
            pendingCompletion = nil
            dropPulseDates.removeAll()
            cancelTaskDrag()
        }
        .onKeyPress(.escape) {
            cancelTaskDrag()
            onClose()
            return .handled
        }
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
                        isDropArrival: dropPulseDates.contains { pulseDate in
                            model.calendar.isDate(pulseDate, inSameDayAs: date)
                        }
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
            completingTaskIDs: Set(completionFlights.values.map(\.taskID)),
            taskInteractionLocked: !canBeginTaskCompletion,
            revealedTaskID: revealedTaskID,
            onToggleTask: beginTaskCompletion,
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

    private func beginTaskCompletion(_ task: CalendarWorkbenchV5Task) {
        // Calendar coordinates belong to one spatial transaction at a time.
        // Starting another completion while a flight is active could move the
        // visible month underneath the first flight and invalidate its target.
        guard canBeginTaskCompletion else { return }
        if task.legacy.isCompleted {
            withAnimation(rowMutationAnimation) {
                model.setCompletion(id: task.id, completed: false)
            }
            return
        }
        let transition = V5TaskCompletionTransition.resolve(
            dueDate: task.metadata.dueDate,
            selectedDate: model.selectedDate,
            today: model.today,
            calendar: model.calendar
        )
        if transition == .inline {
            withAnimation(rowMutationAnimation) {
                model.setCompletion(id: task.id, completed: true)
            }
            return
        }
        guard pendingCompletion?.task.id != task.id else { return }
        guard let sourceFrame = dragWorkbenchPoints.taskFrames[task.id],
              let dueDate = task.metadata.dueDate else { return }
        let sourceRing = dragWorkbenchPoints.taskSources[task.id]
            ?? CGPoint(x: sourceFrame.minX + 22, y: sourceFrame.midY)
        let pending = V5PendingTaskCompletion(
            task: task,
            sourceFrame: sourceFrame,
            sourceRingPoint: sourceRing
        )
        if let targetPoint = indicatorPoint(for: dueDate, in: dragWorkbenchPoints) {
            startTaskCompletion(pending, targetPoint: targetPoint)
            return
        }

        // The real calendar cell is the only legal destination. Reveal its
        // month and let the next geometry preference update start the flight.
        pendingCompletion = pending
        withAnimation(reduceMotion ? .easeOut(duration: 0.08) : .easeInOut(duration: 0.16)) {
            model.revealMonth(containing: dueDate)
        }
    }

    private func startPendingCompletionIfPossible(using points: V5DragWorkbenchPoints) {
        guard let pending = pendingCompletion,
              let dueDate = pending.task.metadata.dueDate,
              let targetPoint = indicatorPoint(for: dueDate, in: points) else { return }
        pendingCompletion = nil
        startTaskCompletion(pending, targetPoint: targetPoint)
    }

    private func indicatorPoint(for date: Date, in points: V5DragWorkbenchPoints) -> CGPoint? {
        points.dayIndicators.first { candidate, _ in
            model.calendar.isDate(candidate, inSameDayAs: date)
        }?.value
    }

    private func startTaskCompletion(
        _ pending: V5PendingTaskCompletion,
        targetPoint: CGPoint
    ) {
        let task = pending.task
        guard let dueDate = task.metadata.dueDate else { return }

        let flight = V5TaskCompletionFlightSession(
            id: UUID(), taskID: task.id, title: task.legacy.title,
            dateText: shortDate(dueDate),
            sourceFrame: pending.sourceFrame,
            sourceRingPoint: pending.sourceRingPoint,
            targetPoint: targetPoint,
            targetDate: dueDate,
            accent: .resolve(
                isOverdue: model.calendar.startOfDay(for: dueDate) < model.today
            ),
            phase: .card
        )
        model.clearTaskSelection()
        completionLifecycle.begin(sessionID: flight.id, taskID: task.id)
        completionFlights[flight.id] = flight

        if reduceMotion {
            withAnimation(.easeOut(duration: V5TaskCompletionFlightTiming.reducedMotionCommitDelay)) {
                completionFlights[flight.id]?.phase = .orb
            }
            DispatchQueue.main.asyncAfter(
                deadline: .now() + V5TaskCompletionFlightTiming.reducedMotionCommitDelay
            ) { finishTaskCompletion(flight.id) }
            return
        }

        DispatchQueue.main.async {
            guard completionFlights[flight.id] != nil else { return }
            withAnimation(.easeInOut(duration: V5TaskCompletionFlightTiming.collapseDuration)) {
                completionFlights[flight.id]?.phase = .orb
            }
        }
        DispatchQueue.main.asyncAfter(
            deadline: .now() + V5TaskCompletionFlightTiming.collapseDuration
        ) {
            guard completionFlights[flight.id] != nil else { return }
            withAnimation(.timingCurve(
                0.22, 0.61, 0.36, 1,
                duration: V5TaskCompletionFlightTiming.travelDuration
            )) {
                completionFlights[flight.id]?.phase = .arrived
            }
        }
        DispatchQueue.main.asyncAfter(
            deadline: .now() + V5TaskCompletionFlightTiming.modelCommitDelay
        ) { finishTaskCompletion(flight.id) }
    }

    private func finishTaskCompletion(_ sessionID: UUID) {
        guard let taskID = completionLifecycle.arrive(sessionID: sessionID),
              let flight = completionFlights.removeValue(forKey: sessionID),
              taskID == flight.taskID else { return }
        withAnimation(.easeOut(duration: 0.12)) {
            _ = dropPulseDates.insert(flight.targetDate)
        }
        withAnimation(rowMutationAnimation) {
            model.setCompletion(id: taskID, completed: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeOut(duration: 0.12)) { _ = dropPulseDates.remove(flight.targetDate) }
        }
    }

    private var rowMutationAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.08) : .interactiveSpring(response: 0.30, dampingFraction: 0.88)
    }

    private var canBeginTaskCompletion: Bool {
        V5TaskCompletionAdmission.canBegin(
            hasActiveFlight: !completionFlights.isEmpty,
            hasPendingTarget: pendingCompletion != nil
        )
    }

    private func updateTaskDrag(_ task: CalendarWorkbenchV5Task,
                                location: CGPoint, startLocation _: CGPoint) {
        let targetDate = permittedDropDate(for: task, at: location)
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
        let targetDate = V5TaskDropCommitPolicy.resolvedTarget(
            atRelease: permittedDropDate(for: task, at: location)
        )
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
            taskDrag = nil
            model.moveTask(id: task.id, to: targetDate)
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

    private func permittedDropDate(for task: CalendarWorkbenchV5Task, at location: CGPoint) -> Date? {
        guard let candidate = V5TaskDropGeometry.targetDate(at: location, dayFrames: dayFrames) else {
            return nil
        }
        return model.canMoveTask(id: task.id, to: candidate) ? candidate : nil
    }

    private func clearDragSession(_ sessionID: UUID, after delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard taskDrag?.id == sessionID else { return }
            withAnimation(.easeOut(duration: reduceMotion ? 0.05 : 0.12)) { taskDrag = nil }
        }
    }

    private func cancelTaskDrag() {
        taskDrag = nil
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

    private func moveMonth(_ amount: Int) { animate { model.moveMonth(by: amount) } }
    private func animate(_ body: () -> Void) { withAnimation(reduceMotion ? .easeOut(duration: 0.1) : .interactiveSpring(response: 0.28, dampingFraction: 0.86), body) }
    private func shortDate(_ date: Date) -> String { Self.shortFormatter.string(from: date) }

    private func monthButton(_ image: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: image).frame(width: 34, height: 30) }
            .buttonStyle(.borderless).accessibilityLabel(label)
    }

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

    private var arrivalPresentation: V5DayIndicatorArrivalPresentation {
        .value(isArriving: isDropArrival)
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
                    .scaleEffect(arrivalPresentation.markerScale)
                    .shadow(
                        color: Color.accentColor.opacity(arrivalPresentation.glowOpacity),
                        radius: arrivalPresentation.glowRadius
                    )
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
        .animation(reduceMotion ? .easeOut(duration: 0.08) : .easeOut(duration: 0.18),
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

private struct V5TaskCompletionFlightSession: Equatable {
    let id: UUID
    let taskID: UUID
    let title: String
    let dateText: String
    let sourceFrame: CGRect
    let sourceRingPoint: CGPoint
    let targetPoint: CGPoint
    let targetDate: Date
    let accent: V5TaskCompletionAccent
    var phase: V5TaskCompletionFlightPhase
}

private struct V5PendingTaskCompletion: Equatable {
    let task: CalendarWorkbenchV5Task
    let sourceFrame: CGRect
    let sourceRingPoint: CGPoint
}

private struct V5TaskCompletionFlightView: View {
    let session: V5TaskCompletionFlightSession

    private var geometry: V5TaskCompletionFlightGeometry {
        V5TaskCompletionFlightGeometry.value(
            for: session.phase,
            sourceFrame: session.sourceFrame,
            sourceRing: session.sourceRingPoint,
            target: session.targetPoint
        )
    }

    private var ringColor: Color {
        session.accent == .overdue ? .orange : Color.primary.opacity(0.86)
    }

    private var cardScaleAnchor: UnitPoint {
        let width = max(session.sourceFrame.width, 1)
        let height = max(session.sourceFrame.height, 1)
        return UnitPoint(
            x: min(1, max(0, (session.sourceRingPoint.x - session.sourceFrame.minX) / width)),
            y: min(1, max(0, (session.sourceRingPoint.y - session.sourceFrame.minY) / height))
        )
    }

    var body: some View {
        ZStack {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor).opacity(0.94))
                    .overlay {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    }
                HStack(spacing: 10) {
                    Circle().strokeBorder(ringColor, lineWidth: 1.7)
                        .frame(width: 20, height: 20)
                    Text(session.dateText)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(session.accent == .overdue ? Color.orange : Color.secondary)
                    Text(session.title)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
            }
            .frame(width: session.sourceFrame.width, height: session.sourceFrame.height)
            .scaleEffect(geometry.cardScale, anchor: cardScaleAnchor)
            .opacity(geometry.cardOpacity)
            .blur(radius: session.phase == .card ? 0 : 1.2)
            .position(geometry.cardCenter)

            Circle()
                .strokeBorder(ringColor, lineWidth: session.phase == .arrived ? 1.35 : 2)
                .frame(width: geometry.ringDiameter, height: geometry.ringDiameter)
                .opacity(geometry.ringOpacity)
                .shadow(color: ringColor.opacity(session.phase == .arrived ? 0.36 : 0.58),
                        radius: session.phase == .arrived ? 3 : 7)
                .position(geometry.ringCenter)
        }
        .accessibilityHidden(true)
    }
}

private struct V5TaskLandingOutline: View {
    let frame: CGRect

    private let presentation = V5TaskRowRevealPresentation.value

    var body: some View {
        RoundedRectangle(cornerRadius: presentation.landingOutlineCornerRadius,
                         style: .continuous)
            .stroke(
                Color.accentColor.opacity(0.88),
                lineWidth: 1.5
            )
            .frame(
                width: frame.width + presentation.landingOutlineOutset * 2,
                height: frame.height + presentation.landingOutlineOutset * 2
            )
            .shadow(
                color: Color.accentColor.opacity(0.34),
                radius: presentation.perimeterGlowRadius
            )
            .position(x: frame.midX, y: frame.midY)
            .accessibilityHidden(true)
    }
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
