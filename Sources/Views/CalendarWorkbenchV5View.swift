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
    @State private var dayFrames: [Date: CGRect] = [:]
    @State private var dragWorkbenchPoints = V5DragWorkbenchPoints()
    @State private var taskDrag: V5TaskDragSession?
    @State private var completionFlights: [UUID: V5TaskCompletionFlightSession] = [:]
    @State private var completionLifecycle = V5TaskCompletionLifecycle()
    @State private var departingCompletionTasks: [UUID: UUID] = [:]
    @State private var pendingCompletion: V5PendingTaskCompletion?
    @State private var dropPulseDates: Set<Date> = []
    @State private var revealedTaskID: UUID?
    @State private var visualAppearance: V5AppearancePreference?
    @State private var appearanceTransitionID = UUID()
    @State private var sidebarTextInputFocused = false
    @State private var isChoosingYear = false
    @State private var yearPageAnchor: Int?
    @State private var chooserStage = V5YearMonthChooserStage.years
    @State private var chooserSelectedYear: Int?
    @State private var chooserSelectedMonth: Int?
    @State private var chooserActivatedYear: Int?
    @State private var chooserActivatedMonth: Int?
    @State private var chooserSelectionToken = UUID()
    @State private var isMonthTransitioning = false
    @State private var queuedCalendarTarget: Date?
    @State private var preferredMonthDay: Int?
    @State private var monthRailPlan: V5CalendarMonthRailPlan?
    @State private var monthRailOffsetY: CGFloat = 0
    @State private var monthTransitionToken = UUID()

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
        .background {
            V5CalendarKeyboardMonitor(
                context: calendarKeyboardContext,
                onAction: performCalendarKeyboardAction
            )
            .frame(width: 0, height: 0)
        }
        .onPreferenceChange(V5DayFramePreferenceKey.self) { frames in
            guard acceptsMotionGeometryFeedback else { return }
            dayFrames = frames
        }
        .onPreferenceChange(V5DragWorkbenchPointsPreferenceKey.self) { points in
            guard acceptsMotionGeometryFeedback else { return }
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
            if taskDrag?.phase != .absorbing {
                cancelTaskDrag()
            }
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
            if isChoosingYear {
                handleChooserEscape()
                return .handled
            }
            cancelTaskDrag()
            onClose()
            return .handled
        }
    }

    private var calendarPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Button {
                            toggleYearChooser()
                        } label: {
                            Text(yearHeaderTitle)
                                .font(.system(size: 21, weight: .semibold))
                                .monospacedDigit()
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(
                                    Color.accentColor.opacity(isChoosingYear ? 0.13 : 0),
                                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .accessibilityLabel(yearHeaderAccessibilityLabel)
                        .accessibilityIdentifier("v5-year-chooser-toggle")

                        Text(monthHeaderTitle)
                            .font(.system(size: 21, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(isChoosingYear ? .secondary : .primary)
                    }
                    Text("日历与待办").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if !isChoosingYear {
                    monthButton("chevron.up", label: "上个月") { moveMonth(-1) }
                }
                Button("今天") { jumpToToday() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityIdentifier("v5-today")
                if !isChoosingYear {
                    monthButton("chevron.down", label: "下个月") { moveMonth(1) }
                }
            }
            .frame(height: 43)
            .padding(.bottom, 10)
            .contentShape(Rectangle())
            .zIndex(2)

            ZStack(alignment: .top) {
                if isChoosingYear {
                    yearChooser
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .scale(scale: 0.94, anchor: .topLeading)
                                    .combined(with: .opacity)
                        )
                } else {
                    VStack(spacing: 0) {
                        HStack(spacing: 4) {
                            ForEach(model.weekdaySymbols, id: \.self) { symbol in
                                Text(symbol)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 82)
                            }
                        }
                        .padding(.bottom, 7)

                        monthGrid

                        Spacer(minLength: 0)
                        HStack(spacing: 14) {
                            Label("选中", systemImage: "circle.inset.filled")
                            Label("今天", systemImage: "circle")
                            Label("未完成", systemImage: "circle")
                            Label("全完成", systemImage: "circle.fill")
                            Spacer()
                            Text("悬停速览 · 点击后保持")
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    }
                    .transition(.opacity)
                }
            }
            .animation(yearChooserAnimation, value: isChoosingYear)
        }
        .padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 15)
    }

    private var monthGrid: some View {
        let days = monthRailPlan?.days ?? model.monthDays
        return ZStack(alignment: .top) {
            LazyVGrid(columns: columns, spacing: V5CalendarMonthRailPresentation.rowSpacing) {
                ForEach(Array(days.enumerated()), id: \.element) { index, date in
                    let taskCounts = model.taskCounts(on: date)
                    V5DayCell(
                        date: date,
                        calendar: model.calendar,
                        today: model.today,
                        isInMonth: isDateInEmphasizedMonth(date),
                        isSelected: isDateVisuallySelected(date),
                        taskCounts: taskCounts,
                        reduceMotion: reduceMotion,
                        isDraggingTask: taskDrag != nil,
                        isDropTarget: taskDrag?.targetDate.map {
                            model.calendar.isDate($0, inSameDayAs: date)
                        } == true,
                        isDropArrival: dropPulseDates.contains { pulseDate in
                            model.calendar.isDate(pulseDate, inSameDayAs: date)
                        },
                        reportsGeometry: monthRailPlan == nil
                            || V5CalendarMonthRailPresentation.reportsLiveGeometryDuringTransition
                    ) {
                        selectDate(date)
                    }
                    .equatable()
                    .accessibilityIdentifier("v5-day-\(index)")
                }
            }
            .compositingGroup()
            .offset(y: monthRailOffsetY)
        }
        .frame(height: V5CalendarMonthRailPresentation.viewportHeight, alignment: .top)
        .clipped()
        .allowsHitTesting(!isMonthTransitioning && !isChoosingYear)
    }

    private var yearChooser: some View {
        ZStack {
            if chooserStage == .years {
                yearGrid
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .move(edge: .leading).combined(with: .opacity)
                    )
            } else {
                monthChooserGrid
                    .transition(
                        reduceMotion
                            ? .opacity
                            : .move(edge: .trailing).combined(with: .opacity)
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()
        .animation(chooserDrillAnimation, value: chooserStage)
    }

    private var yearGrid: some View {
        let displayedYear = model.calendar.component(.year, from: model.displayedMonth)
        let currentYear = model.calendar.component(.year, from: model.today)
        let anchor = yearPageAnchor ?? displayedYear
        let years = V5YearChooserPresentation.years(containing: anchor)

        return VStack(spacing: 12) {
            HStack {
                Button("更早") { shiftYearPage(by: -1) }
                    .buttonStyle(.borderless)
                Spacer()
                Text("\(years.first ?? displayedYear) – \(years.last ?? displayedYear)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer()
                Button("更晚") { shiftYearPage(by: 1) }
                    .buttonStyle(.borderless)
            }
            .frame(height: 32)

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 12),
                    count: V5YearChooserPresentation.yearColumns
                ),
                spacing: 10
            ) {
                ForEach(years, id: \.self) { year in
                    V5CalendarChoiceCell(
                        title: String(year),
                        badge: year == currentYear ? "今年" : nil,
                        isSelected: year == (chooserSelectedYear ?? displayedYear),
                        isActivated: year == chooserActivatedYear,
                        height: 105,
                        reduceMotion: reduceMotion,
                        accessibilityLabel: "\(year)年",
                        accessibilityIdentifier: "v5-year-\(year)"
                    ) { chooseYear(year) }
                }
            }
            .padding(.horizontal, V5YearChooserPresentation.selectionCanvasInset)
            .padding(.vertical, V5YearChooserPresentation.selectionCanvasInset)

            Spacer(minLength: 0)
            Text("选择年份后继续选择月份 · Esc 关闭")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 2)
    }

    private var monthChooserGrid: some View {
        let selectedYear = chooserSelectedYear
            ?? model.calendar.component(.year, from: model.selectedDate)
        let displayedMonth = model.calendar.component(.month, from: model.selectedDate)

        return VStack(spacing: 12) {
            HStack {
                Button {
                    chooserSelectionToken = UUID()
                    chooserActivatedMonth = nil
                    withAnimation(chooserDrillAnimation) { chooserStage = .years }
                } label: {
                    Label("\(selectedYear)年", systemImage: "chevron.left")
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("v5-month-chooser-back")
                Spacer()
                Text("选择月份")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(selectedYear)年")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .hidden()
            }
            .frame(height: 32)

            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 12),
                    count: V5YearChooserPresentation.monthColumns
                ),
                spacing: 12
            ) {
                ForEach(V5YearChooserPresentation.months, id: \.self) { month in
                    V5CalendarChoiceCell(
                        title: "\(month)",
                        badge: "月",
                        isSelected: month == (chooserSelectedMonth ?? displayedMonth),
                        isActivated: month == chooserActivatedMonth,
                        height: 105,
                        reduceMotion: reduceMotion,
                        accessibilityLabel: "\(month)月",
                        accessibilityIdentifier: "v5-month-\(month)"
                    ) { chooseMonth(month) }
                }
            }
            .padding(.horizontal, V5YearChooserPresentation.selectionCanvasInset)
            .padding(.vertical, V5YearChooserPresentation.selectionCanvasInset)

            Spacer(minLength: 0)
            Text("选择月份后返回日历 · Esc 返回年份")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 2)
    }

    private var taskPane: some View {
        CalendarWorkbenchV5Sidebar(
            model: model,
            appearance: visualAppearance ?? appearance,
            onSelectAppearance: selectAppearance,
            completionPhases: completionSourcePhases,
            taskInteractionLocked: !canBeginTaskCompletion,
            revealedTaskID: revealedTaskID,
            onToggleTask: beginTaskCompletion,
            onTaskDragChanged: updateTaskDrag,
            onTaskDragEnded: finishTaskDrag,
            onTextInputFocusChange: { sidebarTextInputFocused = $0 },
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

    private func beginTaskCompletion(_ taskID: UUID) {
        // Calendar coordinates belong to one spatial transaction at a time.
        // Starting another completion while a flight is active could move the
        // visible month underneath the first flight and invalidate its target.
        guard canBeginTaskCompletion, let task = model.task(id: taskID) else { return }
        if task.legacy.isCompleted {
            departingCompletionTasks.removeValue(forKey: task.id)
            withAnimation(rowMutationAnimation) {
                _ = model.setCompletion(id: task.id, completed: false)
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
                _ = model.setCompletion(id: task.id, completed: true)
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
        // Keep the departing source collapsed while SwiftUI removes its row.
        departingCompletionTasks[taskID] = sessionID
        withAnimation(.easeOut(duration: 0.12)) {
            _ = dropPulseDates.insert(flight.targetDate)
        }
        withAnimation(rowMutationAnimation) {
            _ = model.setCompletion(id: taskID, completed: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            if departingCompletionTasks[taskID] == sessionID {
                departingCompletionTasks.removeValue(forKey: taskID)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.easeOut(duration: 0.12)) { _ = dropPulseDates.remove(flight.targetDate) }
        }
    }

    private var completionSourcePhases: [UUID: V5TaskCompletionFlightPhase] {
        var phases = departingCompletionTasks.mapValues { _ in V5TaskCompletionFlightPhase.arrived }
        for flight in completionFlights.values { phases[flight.taskID] = flight.phase }
        return phases
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

    private func updateTaskDrag(_ taskID: UUID,
                                location: CGPoint, startLocation _: CGPoint) {
        guard let task = model.task(id: taskID) else { return }
        let targetDate = permittedDropDate(for: taskID, at: location)
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

    private func finishTaskDrag(_ taskID: UUID, location: CGPoint) {
        guard var session = taskDrag, session.taskID == taskID else { return }
        let targetDate = V5TaskDropCommitPolicy.resolvedTarget(
            atRelease: permittedDropDate(for: taskID, at: location)
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
            performTaskListMutation(for: .taskDateMoved) {
                taskDrag = nil
                _ = model.moveTask(id: taskID, to: targetDate)
            }
            // Let the authoritative task snapshot render before applying the
            // local landing bloom, so that animation cannot retain the source row.
            DispatchQueue.main.async {
                withAnimation(revealSpring) {
                    revealedTaskID = taskID
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.18 : 0.72)) {
                    withAnimation(.easeOut(duration: 0.16)) {
                        if revealedTaskID == taskID { revealedTaskID = nil }
                    }
                }
            }
        }
    }

    private func permittedDropDate(for taskID: UUID, at location: CGPoint) -> Date? {
        guard let candidate = V5TaskDropGeometry.targetDate(at: location, dayFrames: dayFrames) else {
            return nil
        }
        return model.canMoveTask(id: taskID, to: candidate) ? candidate : nil
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

    private func performTaskListMutation(
        for cause: V5TaskListMutationCause,
        _ mutation: () -> Void
    ) {
        var transaction = Transaction()
        if !V5TaskListAnimationPolicy.animatesWholeList(for: cause) {
            transaction.animation = nil
            transaction.disablesAnimations = true
        }
        withTransaction(transaction, mutation)
    }

    private var acceptsMotionGeometryFeedback: Bool {
        V5MotionGeometryFeedbackPolicy.acceptsUpdate(
            isMonthTransitioning: isMonthTransitioning,
            isTaskDragging: taskDrag != nil,
            hasCompletionMotion: !completionFlights.isEmpty
        )
    }

    private var appearance: V5AppearancePreference {
        V5AppearancePreference(rawValue: appearanceRaw) ?? .system
    }

    private var yearHeaderTitle: String {
        guard isChoosingYear, let chooserSelectedYear else { return model.yearTitle }
        return "\(chooserSelectedYear)年"
    }

    private var monthHeaderTitle: String {
        guard isChoosingYear,
              chooserStage == .months,
              let chooserSelectedMonth else { return model.monthTitle }
        return "\(chooserSelectedMonth)月"
    }

    private var yearHeaderAccessibilityLabel: String {
        if !isChoosingYear { return "选择年份和月份" }
        return chooserStage == .months ? "返回年份选择" : "关闭年份和月份选择"
    }

    private func moveMonth(_ amount: Int) {
        guard amount != 0 else { return }
        requestCalendarNavigation(.moveSelectionByMonths(amount))
    }

    private func selectDate(_ date: Date) {
        preferredMonthDay = model.calendar.component(.day, from: date)
        requestCalendarSelection(date)
    }

    private func jumpToToday() {
        if isChoosingYear {
            closeYearChooser()
        }
        preferredMonthDay = model.calendar.component(.day, from: model.today)
        requestCalendarSelection(model.today, animatesAdjacentMonth: false)
    }

    private func toggleYearChooser() {
        if isMonthTransitioning {
            settleMonthTransitionImmediately()
        }
        if isChoosingYear {
            if chooserStage == .months {
                chooserSelectionToken = UUID()
                chooserActivatedMonth = nil
                withAnimation(chooserDrillAnimation) { chooserStage = .years }
            } else {
                closeYearChooser()
            }
            return
        }
        openYearChooser()
    }

    private func openYearChooser() {
        let displayedYear = model.calendar.component(.year, from: model.displayedMonth)
        let currentYear = model.calendar.component(.year, from: model.today)
        let centeredCurrentYears = V5YearChooserPresentation.years(containing: currentYear)
        yearPageAnchor = centeredCurrentYears.contains(displayedYear) ? currentYear : displayedYear
        chooserSelectedYear = displayedYear
        chooserSelectedMonth = model.calendar.component(.month, from: model.displayedMonth)
        chooserActivatedYear = nil
        chooserActivatedMonth = nil
        chooserSelectionToken = UUID()
        chooserStage = .years
        cancelTaskDrag()
        withAnimation(yearChooserAnimation) { isChoosingYear = true }
    }

    private func closeYearChooser() {
        chooserSelectionToken = UUID()
        chooserActivatedYear = nil
        chooserActivatedMonth = nil
        withAnimation(yearChooserAnimation) { isChoosingYear = false }
    }

    private func chooseYear(_ year: Int) {
        let token = UUID()
        chooserSelectionToken = token
        withAnimation(chooserSelectionAnimation) {
            chooserSelectedYear = year
            chooserActivatedYear = year
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + chooserSelectionFeedbackDuration) {
            guard isChoosingYear,
                  chooserStage == .years,
                  chooserSelectionToken == token else { return }
            chooserActivatedYear = nil
            withAnimation(chooserDrillAnimation) { chooserStage = .months }
        }
    }

    private func chooseMonth(_ month: Int) {
        let token = UUID()
        chooserSelectionToken = token
        withAnimation(chooserSelectionAnimation) {
            chooserSelectedMonth = month
            chooserActivatedMonth = month
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + chooserSelectionFeedbackDuration) {
            guard isChoosingYear,
                  chooserStage == .months,
                  chooserSelectionToken == token,
                  let year = chooserSelectedYear,
                  let target = V5CalendarDateNavigation.replacingYearAndMonth(
                    year: year,
                    month: month,
                    in: model.selectedDate,
                    calendar: model.calendar
                  ) else { return }
            var transaction = Transaction()
            transaction.animation = nil
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                model.select(target)
            }
            DispatchQueue.main.async {
                guard chooserSelectionToken == token else { return }
                closeYearChooser()
            }
        }
    }

    private func shiftYearPage(by amount: Int) {
        let anchor = yearPageAnchor ?? model.calendar.component(.year, from: model.displayedMonth)
        chooserActivatedYear = nil
        withAnimation(chooserDrillAnimation) {
            yearPageAnchor = anchor + amount * V5YearChooserPresentation.yearsPerPage
        }
    }

    private var calendarKeyboardContext: V5CalendarKeyboardContext {
        V5CalendarKeyboardContext(
            isTextInputFocused: sidebarTextInputFocused,
            isEditingTask: model.editingTaskID != nil,
            isDraggingTask: taskDrag != nil,
            isChoosingYear: isChoosingYear
        )
    }

    private func performCalendarKeyboardAction(_ action: V5CalendarKeyboardAction) {
        if action == .escapeChooser {
            handleChooserEscape()
        } else {
            requestCalendarNavigation(action)
        }
    }

    private func requestCalendarNavigation(_ action: V5CalendarKeyboardAction) {
        let base = queuedCalendarTarget ?? monthRailPlan?.targetSelection ?? model.selectedDate
        let target: Date?
        switch action {
        case let .moveSelectionByDays(amount):
            target = V5CalendarDateNavigation.movingDays(amount, from: base, calendar: model.calendar)
            if let target {
                preferredMonthDay = model.calendar.component(.day, from: target)
            }
        case let .moveSelectionByMonths(amount):
            let preferredDay = preferredMonthDay
                ?? model.calendar.component(.day, from: base)
            preferredMonthDay = preferredDay
            target = V5CalendarDateNavigation.movingMonths(
                amount,
                from: base,
                preferredDay: preferredDay,
                calendar: model.calendar
            )
        case .jumpToToday:
            target = model.today
            preferredMonthDay = model.calendar.component(.day, from: model.today)
        case .escapeChooser:
            target = nil
        }
        guard let target else { return }
        requestCalendarSelection(
            target,
            animatesAdjacentMonth: action != .jumpToToday
        )
    }

    private func requestCalendarSelection(
        _ date: Date,
        animatesAdjacentMonth: Bool = true
    ) {
        let target = model.calendar.startOfDay(for: date)
        if isMonthTransitioning {
            queuedCalendarTarget = target
            return
        }
        guard !model.calendar.isDate(target, inSameDayAs: model.selectedDate) else { return }

        let oldMonth = model.calendar.dateInterval(of: .month, for: model.displayedMonth)?.start
            ?? model.displayedMonth
        let newMonth = model.calendar.dateInterval(of: .month, for: target)?.start ?? target
        let changesMonth = !model.calendar.isDate(oldMonth, equalTo: newMonth, toGranularity: .month)
        let monthDistance = model.calendar.dateComponents(
            [.month], from: oldMonth, to: newMonth
        ).month ?? 0
        if changesMonth, animatesAdjacentMonth {
            if abs(monthDistance) > 1 {
                queuedCalendarTarget = target
                guard let intermediate = V5CalendarDateNavigation.movingMonths(
                    monthDistance < 0 ? -1 : 1,
                    from: model.selectedDate,
                    preferredDay: preferredMonthDay,
                    calendar: model.calendar
                ) else { return }
                beginMonthTransition(to: intermediate)
            } else {
                beginMonthTransition(to: target)
            }
            return
        }
        performTaskListMutation(for: .selectedDateChanged) {
            model.select(target)
        }
    }

    private func beginMonthTransition(to target: Date) {
        guard let plan = V5CalendarMonthRailPlan.make(
            sourceMonth: model.displayedMonth,
            targetMonth: target,
            sourceSelection: model.selectedDate,
            targetSelection: target,
            calendar: model.calendar
        ) else {
            performTaskListMutation(for: .selectedDateChanged) {
                model.select(target)
            }
            return
        }
        let token = UUID()
        monthTransitionToken = token
        var setupTransaction = Transaction()
        setupTransaction.animation = nil
        setupTransaction.disablesAnimations = true
        withTransaction(setupTransaction) {
            isMonthTransitioning = true
            monthRailPlan = plan
            monthRailOffsetY = plan.sourceOffsetY
        }
        let duration = reduceMotion
            ? 0.12
            : V5CalendarMonthRailPresentation.duration(forWeekDistance: plan.weekDistance)
        DispatchQueue.main.async {
            guard monthTransitionToken == token else { return }
            withAnimation(monthRailAnimation(forWeekDistance: plan.weekDistance)) {
                monthRailOffsetY = plan.targetOffsetY
            }
        }
        DispatchQueue.main.asyncAfter(
            deadline: .now() + V5CalendarMonthRailPresentation.installationDelay + duration
        ) {
            guard monthTransitionToken == token else { return }
            var settleTransaction = Transaction()
            settleTransaction.animation = nil
            settleTransaction.disablesAnimations = true
            withTransaction(settleTransaction) {
                model.select(plan.targetSelection)
                monthRailPlan = nil
                monthRailOffsetY = 0
                isMonthTransitioning = false
            }
            continueQueuedCalendarNavigation()
        }
    }

    private func continueQueuedCalendarNavigation() {
        guard let queuedTarget = queuedCalendarTarget else { return }
        self.queuedCalendarTarget = nil
        guard !model.calendar.isDate(
            queuedTarget, inSameDayAs: model.selectedDate
        ) else { return }
        DispatchQueue.main.async {
            requestCalendarSelection(queuedTarget)
        }
    }

    private func settleMonthTransitionImmediately() {
        guard let plan = monthRailPlan else { return }
        monthTransitionToken = UUID()
        var transaction = Transaction()
        transaction.animation = nil
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            model.select(plan.targetSelection)
            monthRailPlan = nil
            monthRailOffsetY = 0
            isMonthTransitioning = false
        }
    }

    private func handleChooserEscape() {
        guard isChoosingYear else { return }
        if let destination = V5YearMonthChooserNavigation.escapeDestination(from: chooserStage) {
            chooserSelectionToken = UUID()
            chooserActivatedMonth = nil
            withAnimation(chooserDrillAnimation) { chooserStage = destination }
        } else {
            closeYearChooser()
        }
    }

    private func isDateInEmphasizedMonth(_ date: Date) -> Bool {
        guard let plan = monthRailPlan else {
            return model.calendar.isDate(
                date, equalTo: model.displayedMonth, toGranularity: .month
            )
        }
        return model.calendar.isDate(
            date, equalTo: plan.sourceMonth, toGranularity: .month
        ) || model.calendar.isDate(
            date, equalTo: plan.targetMonth, toGranularity: .month
        )
    }

    private func isDateVisuallySelected(_ date: Date) -> Bool {
        guard let plan = monthRailPlan else {
            return model.calendar.isDate(date, inSameDayAs: model.selectedDate)
        }
        return model.calendar.isDate(date, inSameDayAs: plan.sourceSelection)
            || model.calendar.isDate(date, inSameDayAs: plan.targetSelection)
    }

    private func monthRailAnimation(forWeekDistance distance: Int) -> Animation {
        if reduceMotion { return .easeOut(duration: 0.12) }
        return .timingCurve(
            0.32, 0.72, 0, 1,
            duration: V5CalendarMonthRailPresentation.duration(forWeekDistance: distance)
        )
    }

    private var yearChooserAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.10)
            : .interactiveSpring(response: 0.34, dampingFraction: 0.90)
    }

    private var chooserSelectionAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.08)
            : .interactiveSpring(
                response: V5SelectionGlowPresentation.selected.animationResponse,
                dampingFraction: 0.88
            )
    }

    private var chooserDrillAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.12)
            : .interactiveSpring(response: 0.38, dampingFraction: 0.92)
    }

    private var chooserSelectionFeedbackDuration: Double {
        reduceMotion ? 0.08 : V5YearChooserPresentation.selectionFeedbackDuration
    }

    private func shortDate(_ date: Date) -> String { Self.shortFormatter.string(from: date) }

    private func monthButton(_ image: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: image).frame(width: 34, height: 30) }
            .buttonStyle(.borderless)
            .accessibilityLabel(label)
    }

    private var rootTint: Color {
        if reduceTransparency { return Color(nsColor: .windowBackgroundColor) }
        return colorScheme == .dark ? Color(red: 0.025, green: 0.065, blue: 0.11).opacity(0.42) : Color.white.opacity(0.18)
    }

    private static let shortFormatter: DateFormatter = {
        let value = DateFormatter(); value.locale = Locale(identifier: "zh_CN"); value.dateFormat = "M月d日"; return value
    }()
}

private struct V5CalendarKeyboardMonitor: NSViewRepresentable {
    let context: V5CalendarKeyboardContext
    let onAction: (V5CalendarKeyboardAction) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(context: context, onAction: onAction)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.update(context: self.context, onAction: onAction)
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator {
        private weak var hostView: NSView?
        private var context: V5CalendarKeyboardContext
        private var onAction: (V5CalendarKeyboardAction) -> Void
        private var monitor: Any?

        init(
            context: V5CalendarKeyboardContext,
            onAction: @escaping (V5CalendarKeyboardAction) -> Void
        ) {
            self.context = context
            self.onAction = onAction
        }

        func attach(to view: NSView) {
            hostView = view
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                self?.route(event) ?? event
            }
        }

        func update(
            context: V5CalendarKeyboardContext,
            onAction: @escaping (V5CalendarKeyboardAction) -> Void
        ) {
            self.context = context
            self.onAction = onAction
        }

        func detach() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        deinit {
            detach()
        }

        private func route(_ event: NSEvent) -> NSEvent? {
            guard let window = hostView?.window, event.window === window else { return event }
            let modifiers = event.modifierFlags
            let isCommandPressed = modifiers.contains(.command)
            let hasDisallowedModifiers = !modifiers.intersection([.option, .control, .shift]).isEmpty
            let proposedAction = V5CalendarKeyboardEventRouting.action(
                forKeyCode: event.keyCode,
                isCommandPressed: isCommandPressed,
                hasDisallowedModifiers: hasDisallowedModifiers,
                context: context
            )
            if proposedAction == .escapeChooser {
                DispatchQueue.main.async { [weak self] in self?.onAction(.escapeChooser) }
                return nil
            }
            if let responder = window.firstResponder,
               responder is NSTextView || responder is NSTextField {
                return event
            }
            guard let action = proposedAction else { return event }
            DispatchQueue.main.async { [weak self] in self?.onAction(action) }
            return nil
        }
    }
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

private enum V5CalendarSelectionSurfaceState: Equatable {
    case none
    case hover
    case selected
    case dropTarget
}

/// Dates, years and months share this single focus treatment so their hover,
/// border and restrained glow cannot drift into three different visual styles.
private struct V5CalendarSelectionSurface: View {
    let state: V5CalendarSelectionSurfaceState
    let cornerRadius: CGFloat
    let reduceMotion: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            switch state {
            case .none:
                Color.clear
            case .hover:
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.primary.opacity(0.055))
            case .selected, .dropTarget:
                let isDropTarget = state == .dropTarget
                let glow = isDropTarget
                    ? V5SelectionGlowPresentation.dropTarget
                    : V5SelectionGlowPresentation.selected
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        Color.accentColor.opacity(
                            colorScheme == .dark
                                ? (isDropTarget ? 0.20 : 0.18)
                                : (isDropTarget ? 0.13 : 0.10)
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                Color.accentColor.opacity(isDropTarget ? 0.96 : 0.92),
                                lineWidth: isDropTarget ? 2.1 : 2
                            )
                    }
                    .shadow(
                        color: Color.accentColor.opacity(glow.innerOpacity),
                        radius: glow.innerRadius
                    )
                    .shadow(
                        color: Color.accentColor.opacity(glow.outerOpacity),
                        radius: glow.outerRadius
                    )
                    .scaleEffect(glow.scale)
            }
        }
        .animation(
            reduceMotion
                ? .easeOut(duration: 0.08)
                : .interactiveSpring(
                    response: V5SelectionGlowPresentation.selected.animationResponse,
                    dampingFraction: 0.90
                ),
            value: state
        )
    }
}

private struct V5CalendarChoiceCell: View {
    let title: String
    let badge: String?
    let isSelected: Bool
    let isActivated: Bool
    let height: CGFloat
    let reduceMotion: Bool
    let accessibilityLabel: String
    let accessibilityIdentifier: String
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                V5CalendarSelectionSurface(
                    state: isSelected ? .selected : (hovered ? .hover : .none),
                    cornerRadius: 16,
                    reduceMotion: reduceMotion
                )

                VStack(spacing: 1) {
                    Spacer(minLength: 0)
                    Text(title)
                        .font(.system(
                            size: V5YearChooserPresentation.choiceNumberFontSize,
                            weight: isSelected ? .semibold : .medium,
                            design: .rounded
                        ))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Group {
                        if let badge {
                            Text(badge)
                        } else {
                            Text(" ").accessibilityHidden(true)
                        }
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(height: 17)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(isActivated ? 1.018 : (hovered ? 1.008 : 1))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(
            reduceMotion
                ? .easeOut(duration: 0.08)
                : .interactiveSpring(
                    response: V5SelectionGlowPresentation.selected.animationResponse,
                    dampingFraction: 0.88
                ),
            value: isActivated
        )
        .animation(
            reduceMotion
                ? .easeOut(duration: 0.08)
                : .interactiveSpring(response: 0.24, dampingFraction: 0.92),
            value: hovered
        )
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct V5DayCell: View, Equatable {
    let date: Date
    let calendar: Calendar
    let today: Date
    let isInMonth: Bool
    let isSelected: Bool
    let taskCounts: V5DayTaskCounts
    let reduceMotion: Bool
    let isDraggingTask: Bool
    let isDropTarget: Bool
    let isDropArrival: Bool
    let reportsGeometry: Bool
    let onSelect: () -> Void
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

    private var emphasis: V5DayCellEmphasis {
        .resolve(
            isDraggingTask: isDraggingTask,
            isDropTarget: isDropTarget,
            isSelected: isSelected,
            isToday: isToday,
            isHovered: hovered
        )
    }

    private var selectionSurfaceState: V5CalendarSelectionSurfaceState {
        switch emphasis {
        case .selected:
            return .selected
        case .dropTarget:
            return .dropTarget
        case .hover:
            return .hover
        case .none, .today:
            return .none
        }
    }

    var body: some View {
        Button(action: onSelect) {
            ZStack {
                V5CalendarSelectionSurface(
                    state: selectionSurfaceState,
                    cornerRadius: isToday ? 39 : 16,
                    reduceMotion: reduceMotion
                )
                .frame(width: isToday ? 78 : 82, height: 78)

                if emphasis == .today {
                    Circle().strokeBorder(Color.accentColor.opacity(0.72), lineWidth: 1.7).frame(width: 78, height: 78)
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
                        if reportsGeometry {
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
                if reportsGeometry {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: V5DayFramePreferenceKey.self,
                            value: [date: proxy.frame(in: .named("v5-workbench"))]
                        )
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .onChange(of: isDraggingTask) { _, dragging in
            if dragging { hovered = false }
        }
        .animation(reduceMotion ? .easeOut(duration: 0.08) : .easeOut(duration: 0.18),
                   value: isDropArrival)
        .accessibilityLabel(Self.accessibilityFormatter.string(from: date))
    }

    private var isToday: Bool { calendar.isDate(date, inSameDayAs: today) }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.date == rhs.date
            && lhs.calendar == rhs.calendar
            && lhs.today == rhs.today
            && lhs.isInMonth == rhs.isInMonth
            && lhs.isSelected == rhs.isSelected
            && lhs.taskCounts == rhs.taskCounts
            && lhs.reduceMotion == rhs.reduceMotion
            && lhs.isDraggingTask == rhs.isDraggingTask
            && lhs.isDropTarget == rhs.isDropTarget
            && lhs.isDropArrival == rhs.isDropArrival
            && lhs.reportsGeometry == rhs.reportsGeometry
    }

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

    var body: some View {
        ZStack {
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
