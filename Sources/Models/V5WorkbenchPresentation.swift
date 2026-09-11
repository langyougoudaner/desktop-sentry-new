import Foundation
import CoreGraphics

enum V5AppearancePreference: String, CaseIterable {
    case system
    case light
    case dark

    var next: Self {
        switch self {
        case .system: return .light
        case .light: return .dark
        case .dark: return .system
        }
    }

    var symbolName: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    var panelAppearance: V5PanelAppearance {
        switch self {
        case .system: return .inherited
        case .light: return .aqua
        case .dark: return .darkAqua
        }
    }
}

enum V5PanelAppearance: Equatable {
    case inherited
    case aqua
    case darkAqua
}

enum CalendarPanelPresentationPolicy {
    /// Re-anchor only when opening a hidden panel. Once visible, its frame is
    /// stable even if another status item's title or width changes.
    static func shouldReposition(isVisible: Bool) -> Bool { !isVisible }
}

enum StatusItemRole { case prompt, calendar }
enum StatusClickKind { case left, right }
enum StatusItemAction: Equatable { case copyPrompt, showPromptMenu, showCalendarPinned }

enum StatusItemRouting {
    static func action(role: StatusItemRole, click: StatusClickKind) -> StatusItemAction {
        switch (role, click) {
        case (.prompt, .left): return .copyPrompt
        case (.prompt, .right): return .showPromptMenu
        case (.calendar, _): return .showCalendarPinned
        }
    }
}

/// Optical geometry for the user-selected pure calendar glyph: one rounded
/// month page, a header divider, and a 3 x 2 date grid. Keeping the geometry
/// pure makes the 16-18pt menu-bar rendering deterministic and testable.
struct CalendarStatusGlyphGeometry {
    let outerRect: CGRect
    let cornerRadius: CGFloat
    let strokeWidth: CGFloat
    let headerDividerY: CGFloat
    let cellCornerRadius: CGFloat
    let cellRects: [CGRect]

    init(size: CGFloat) {
        let scale: CGFloat = size / 18
        let outerOrigin: CGFloat = 2.25 * scale
        let outerLength: CGFloat = 13.5 * scale
        outerRect = CGRect(origin: CGPoint(x: outerOrigin, y: outerOrigin),
                           size: CGSize(width: outerLength, height: outerLength))
        cornerRadius = CGFloat(2.6) * scale
        strokeWidth = CGFloat(1.65) * scale
        headerDividerY = CGFloat(11.35) * scale
        cellCornerRadius = CGFloat(0.45) * scale

        let cellSize: CGFloat = 1.9 * scale
        let xOrigins: [CGFloat] = [5.05, 8.05, 11.05].map { CGFloat($0) * scale }
        let yOrigins: [CGFloat] = [4.55, 7.55].map { CGFloat($0) * scale }
        cellRects = yOrigins.flatMap { y in
            xOrigins.map { x in
                CGRect(origin: CGPoint(x: x, y: y), size: CGSize(width: cellSize, height: cellSize))
            }
        }
    }
}

struct V5FooterPresentation {
    let mode: V5TaskListMode
    let activeCount: Int
    let completedCount: Int

    /// A stable capsule prevents old and new labels from being laid out at
    /// different widths during a rapid mode switch.
    let controlWidth: Double = 112

    var title: String {
        mode == .active ? "已完成 \(completedCount)" : "待办 \(activeCount)"
    }

    var symbolName: String {
        mode == .active ? "checkmark.circle" : "arrow.uturn.backward"
    }
}

struct V5InlineTaskSectionsPresentation {
    static let collapsedCompletedLimit = 3

    let activeCount: Int
    let overdueCount: Int
    let completedCount: Int
    let completedExpanded: Bool

    var visibleCompletedCount: Int {
        completedExpanded ? completedCount : min(completedCount, Self.collapsedCompletedLimit)
    }

    var showsCompletedDisclosure: Bool {
        completedCount > Self.collapsedCompletedLimit
    }

    var completedDisclosureTitle: String {
        completedExpanded ? "收起" : "查看全部 \(completedCount)"
    }

    var footerSummary: String {
        guard overdueCount > 0 else {
            return "待办 \(activeCount) · 已完成 \(completedCount)"
        }
        return "今天 \(activeCount) · 逾期 \(overdueCount) · 已完成 \(completedCount)"
    }
}

enum V5TaskListOverflowPresentation {
    static let disablesScrollClipping = false
    static let showsNativeScrollIndicator = false
    static let edgeFadeHeight: CGFloat = 16
    static let contentVerticalInset: CGFloat = 16
}

struct V5TaskListCanvasGeometry {
    let contentWidth: CGFloat

    var viewportWidth: CGFloat { contentWidth }
    var viewportOffsetX: CGFloat { 0 }
    var contentMinX: CGFloat { 0 }
    var contentMaxX: CGFloat { contentMinX + contentWidth }
}

struct V5TaskRowStatusPresentation: Equatable {
    let dateText: String
    let isOverdue: Bool

    static func resolve(
        task: CalendarWorkbenchV5Task,
        today: Date,
        calendar: Calendar
    ) -> Self {
        guard let dueDate = task.metadata.dueDate else {
            return Self(dateText: "未排期", isOverdue: false)
        }
        let components = calendar.dateComponents([.month, .day], from: dueDate)
        let dateText = "\(components.month ?? 0)月\(components.day ?? 0)日"
        return Self(
            dateText: dateText,
            isOverdue: !task.legacy.isCompleted
                && calendar.startOfDay(for: dueDate) < calendar.startOfDay(for: today)
        )
    }
}

struct V5TaskRowRevealPresentation {
    let cardScale: CGFloat
    let showsInsetStroke: Bool
    let perimeterGlowRadius: CGFloat
    let innerBloomDuration: Double
    let landingOutlineDuration: Double
    let landingOutlineOutset: CGFloat
    let landingOutlineCornerRadius: CGFloat

    static let value = V5TaskRowRevealPresentation(
        cardScale: 1,
        showsInsetStroke: false,
        perimeterGlowRadius: 5,
        innerBloomDuration: 0.36,
        landingOutlineDuration: 0.28,
        landingOutlineOutset: 2,
        landingOutlineCornerRadius: 13
    )
}

struct V5TaskSelectionPresentation {
    let darkFillOpacity: Double
    let lightFillOpacity: Double
    let borderOpacity: Double
    let borderWidth: CGFloat
    let primaryGlowOpacity: Double
    let primaryGlowRadius: CGFloat
    let secondaryGlowOpacity: Double
    let secondaryGlowRadius: CGFloat

    static let value = V5TaskSelectionPresentation(
        darkFillOpacity: 0.11,
        lightFillOpacity: 0.07,
        borderOpacity: 0.9,
        borderWidth: 1.5,
        primaryGlowOpacity: 0.18,
        primaryGlowRadius: 7,
        secondaryGlowOpacity: 0.08,
        secondaryGlowRadius: 12
    )
}

enum V5TaskRowIdentity {
    static func value(taskID: UUID, isCompleted: Bool) -> String {
        "\(taskID.uuidString)-\(isCompleted ? "completed" : "active")"
    }
}

enum V5TaskListMutationCause {
    case selectedDateChanged
    case taskDateMoved
    case taskCompletionChanged
    case completedDisclosureChanged
}

/// Date navigation and date reassignment replace the rendered task snapshot in
/// one transaction. Animating the entire stack for those events lets SwiftUI
/// retain outgoing rows while inserting the new sections, which creates stale
/// badges, overlapping headers, and apparent vertical jumps.
enum V5TaskListAnimationPolicy {
    static func animatesWholeList(for cause: V5TaskListMutationCause) -> Bool {
        switch cause {
        case .selectedDateChanged, .taskDateMoved:
            return false
        case .taskCompletionChanged:
            return false
        case .completedDisclosureChanged:
            return true
        }
    }
}

enum V5CalendarDirectionalKey {
    case up
    case down
    case left
    case right
}

enum V5CalendarKeyboardAction: Equatable {
    case moveSelectionByDays(Int)
    case moveSelectionByMonths(Int)
    case jumpToToday
    case escapeChooser
}

struct V5CalendarKeyboardContext: Equatable {
    let isTextInputFocused: Bool
    let isEditingTask: Bool
    let isDraggingTask: Bool
    let isChoosingYear: Bool

    var allowsCalendarNavigation: Bool {
        !isTextInputFocused && !isEditingTask && !isDraggingTask && !isChoosingYear
    }
}

enum V5CalendarKeyboardNavigation {
    static func action(
        for key: V5CalendarDirectionalKey,
        isCommandPressed: Bool,
        context: V5CalendarKeyboardContext
    ) -> V5CalendarKeyboardAction? {
        guard context.allowsCalendarNavigation else { return nil }
        if isCommandPressed {
            switch key {
            case .left:
                return .moveSelectionByMonths(-1)
            case .right:
                return .moveSelectionByMonths(1)
            case .up, .down:
                return nil
            }
        }
        switch key {
        case .up:
            return .moveSelectionByDays(-7)
        case .down:
            return .moveSelectionByDays(7)
        case .left:
            return .moveSelectionByDays(-1)
        case .right:
            return .moveSelectionByDays(1)
        }
    }
}

enum V5CalendarKeyboardEventRouting {
    static func direction(forKeyCode keyCode: UInt16) -> V5CalendarDirectionalKey? {
        switch keyCode {
        case 123:
            return .left
        case 124:
            return .right
        case 126:
            return .up
        case 125:
            return .down
        default:
            return nil
        }
    }

    static func action(
        forKeyCode keyCode: UInt16,
        isCommandPressed: Bool,
        hasDisallowedModifiers: Bool,
        context: V5CalendarKeyboardContext
    ) -> V5CalendarKeyboardAction? {
        guard !hasDisallowedModifiers else { return nil }
        if keyCode == 53, !isCommandPressed, context.isChoosingYear {
            return .escapeChooser
        }
        guard context.allowsCalendarNavigation else { return nil }
        if keyCode == 17 {
            return isCommandPressed ? .jumpToToday : nil
        }
        guard let direction = direction(forKeyCode: keyCode) else { return nil }
        return V5CalendarKeyboardNavigation.action(
            for: direction,
            isCommandPressed: isCommandPressed,
            context: context
        )
    }
}

enum V5CalendarDateNavigation {
    static func movingDays(_ value: Int, from date: Date, calendar: Calendar) -> Date? {
        calendar.date(byAdding: .day, value: value, to: calendar.startOfDay(for: date))
            .map(calendar.startOfDay(for:))
    }

    static func movingMonths(
        _ value: Int,
        from date: Date,
        preferredDay: Int? = nil,
        calendar: Calendar
    ) -> Date? {
        let source = calendar.startOfDay(for: date)
        let sourceDay = preferredDay ?? calendar.component(.day, from: source)
        var firstDayComponents = calendar.dateComponents([.era, .year, .month], from: source)
        firstDayComponents.day = 1
        guard let sourceMonth = calendar.date(from: firstDayComponents),
              let targetMonth = calendar.date(byAdding: .month, value: value, to: sourceMonth),
              let validDays = calendar.range(of: .day, in: .month, for: targetMonth) else {
            return nil
        }
        var targetComponents = calendar.dateComponents([.era, .year, .month], from: targetMonth)
        targetComponents.day = min(max(1, sourceDay), validDays.count)
        return calendar.date(from: targetComponents).map(calendar.startOfDay(for:))
    }

    static func replacingYear(_ year: Int, in date: Date, calendar: Calendar) -> Date? {
        replacingYearAndMonth(
            year: year,
            month: calendar.component(.month, from: date),
            in: date,
            calendar: calendar
        )
    }

    static func replacingYearAndMonth(
        year: Int,
        month: Int,
        in date: Date,
        calendar: Calendar
    ) -> Date? {
        guard (1...12).contains(month) else { return nil }
        let source = calendar.startOfDay(for: date)
        let sourceDay = calendar.component(.day, from: source)
        var firstDayComponents = calendar.dateComponents([.era], from: source)
        firstDayComponents.year = year
        firstDayComponents.month = month
        firstDayComponents.day = 1
        guard let targetMonth = calendar.date(from: firstDayComponents),
              let validDays = calendar.range(of: .day, in: .month, for: targetMonth) else {
            return nil
        }
        var targetComponents = calendar.dateComponents([.era, .year, .month], from: targetMonth)
        targetComponents.day = min(sourceDay, validDays.count)
        return calendar.date(from: targetComponents).map(calendar.startOfDay(for:))
    }
}

enum V5CalendarMonthRailPresentation {
    static let rowHeight: CGFloat = 78
    static let rowSpacing: CGFloat = 4
    static let rowPitch = rowHeight + rowSpacing
    static let viewportHeight: CGFloat = rowHeight * 6 + rowSpacing * 5
    /// Give SwiftUI one display pass to install the shared rail at its source
    /// offset before animating it. Without this separation both state writes
    /// can be coalesced and the month appears to replace in place.
    static let installationDelay: TimeInterval = 0.035
    static let usesOpacityReplacement = false
    static let headerControlOpacity = 1.0

    static func duration(forWeekDistance distance: Int) -> Double {
        let boundedDistance = min(max(abs(distance), 1), 6)
        return 0.38 + Double(boundedDistance) * 0.025
    }
}

/// A chronological, duplicate-free strip of calendar weeks shared by the
/// outgoing and incoming months. Moving its offset preserves the weeks already
/// visible in both month windows instead of replacing one 42-day grid with a
/// second copy of the same boundary dates.
struct V5CalendarMonthRailPlan: Equatable {
    let sourceMonth: Date
    let targetMonth: Date
    let sourceSelection: Date
    let targetSelection: Date
    let days: [Date]
    let sourceWeekIndex: Int
    let targetWeekIndex: Int

    var sourceOffsetY: CGFloat {
        -CGFloat(sourceWeekIndex) * V5CalendarMonthRailPresentation.rowPitch
    }

    var targetOffsetY: CGFloat {
        -CGFloat(targetWeekIndex) * V5CalendarMonthRailPresentation.rowPitch
    }

    var weekDistance: Int { targetWeekIndex - sourceWeekIndex }

    static func make(
        sourceMonth: Date,
        targetMonth: Date,
        sourceSelection: Date,
        targetSelection: Date,
        calendar: Calendar
    ) -> Self? {
        guard let sourceMonthStart = calendar.dateInterval(of: .month, for: sourceMonth)?.start,
              let targetMonthStart = calendar.dateInterval(of: .month, for: targetMonth)?.start,
              let sourceGridStart = gridStart(for: sourceMonthStart, calendar: calendar),
              let targetGridStart = gridStart(for: targetMonthStart, calendar: calendar),
              !calendar.isDate(sourceMonthStart, equalTo: targetMonthStart, toGranularity: .month)
        else { return nil }

        let railStart = min(sourceGridStart, targetGridStart)
        guard let sourceDayDistance = calendar.dateComponents(
            [.day], from: railStart, to: sourceGridStart
        ).day,
        let targetDayDistance = calendar.dateComponents(
            [.day], from: railStart, to: targetGridStart
        ).day,
        sourceDayDistance.isMultiple(of: 7),
        targetDayDistance.isMultiple(of: 7),
        let sourceEnd = calendar.date(byAdding: .day, value: 41, to: sourceGridStart),
        let targetEnd = calendar.date(byAdding: .day, value: 41, to: targetGridStart)
        else { return nil }

        let railEnd = max(sourceEnd, targetEnd)
        guard let totalDays = calendar.dateComponents([.day], from: railStart, to: railEnd).day
        else { return nil }
        let days = (0...totalDays).compactMap {
            calendar.date(byAdding: .day, value: $0, to: railStart).map(calendar.startOfDay(for:))
        }

        return Self(
            sourceMonth: calendar.startOfDay(for: sourceMonthStart),
            targetMonth: calendar.startOfDay(for: targetMonthStart),
            sourceSelection: calendar.startOfDay(for: sourceSelection),
            targetSelection: calendar.startOfDay(for: targetSelection),
            days: days,
            sourceWeekIndex: sourceDayDistance / 7,
            targetWeekIndex: targetDayDistance / 7
        )
    }

    private static func gridStart(for monthStart: Date, calendar: Calendar) -> Date? {
        let leading = (
            calendar.component(.weekday, from: monthStart) - calendar.firstWeekday + 7
        ) % 7
        return calendar.date(byAdding: .day, value: -leading, to: monthStart)
            .map(calendar.startOfDay(for:))
    }
}

enum V5YearChooserPresentation {
    static let yearsPerPage = 12
    static let leadingYears = 4
    static let yearColumns = 3
    static let yearRows = 4
    static let months = Array(1...12)
    static let monthColumns = 3
    static let monthRows = 4
    static let choiceNumberFontSize: CGFloat = 60
    static let selectionCanvasInset: CGFloat = 14
    static let selectionFeedbackDuration = 0.20

    static func years(containing anchorYear: Int) -> [Int] {
        let start = anchorYear - leadingYears
        return Array(start..<(start + yearsPerPage))
    }

    static func previousPageStart(containing anchorYear: Int) -> Int {
        anchorYear - leadingYears - yearsPerPage
    }

    static func nextPageStart(containing anchorYear: Int) -> Int {
        anchorYear - leadingYears + yearsPerPage
    }
}

enum V5YearMonthChooserStage: Equatable {
    case years
    case months
}

enum V5YearMonthChooserNavigation {
    static func escapeDestination(from stage: V5YearMonthChooserStage) -> V5YearMonthChooserStage? {
        stage == .months ? .years : nil
    }
}

enum V5TaskDateFlipPresentation {
    static let duration = 0.48
    static let reducedMotionDuration = 0.10
    static let cardScale: CGFloat = 1
    static let usesOutgoingTextLayer = false
    static let tiltDegrees = 78.0
    static let perspective: CGFloat = 0.58
}

struct V5SelectionGlowPresentation {
    let innerRadius: CGFloat
    let innerOpacity: Double
    let outerRadius: CGFloat
    let outerOpacity: Double
    let scale: CGFloat
    let animationResponse: Double

    static let selected = V5SelectionGlowPresentation(
        innerRadius: 4,
        innerOpacity: 0.24,
        outerRadius: 12,
        outerOpacity: 0.15,
        scale: 1,
        animationResponse: 0.26
    )

    static let dropTarget = V5SelectionGlowPresentation(
        innerRadius: 6,
        innerOpacity: 0.32,
        outerRadius: 18,
        outerOpacity: 0.24,
        scale: 1.025,
        animationResponse: 0.24
    )
}

enum V5TaskDragPhase: Equatable {
    case launching
    case catching
    case dragging
    case targeted
    case absorbing
    case returning
}

struct V5TaskDragPresentation {
    let diameter: CGFloat
    let scale: CGFloat
    let opacity: Double
    let pointerYOffset: CGFloat
    let showsTitle: Bool

    static let dragging = V5TaskDragPresentation(
        diameter: 14, scale: 1, opacity: 0.96, pointerYOffset: -22, showsTitle: false
    )
    static let targeted = V5TaskDragPresentation(
        diameter: 14, scale: 1.28, opacity: 1, pointerYOffset: -22, showsTitle: false
    )
    static let absorbing = V5TaskDragPresentation(
        diameter: 7, scale: 1, opacity: 1, pointerYOffset: 0, showsTitle: false
    )
    static let returning = V5TaskDragPresentation(
        diameter: 14, scale: 1, opacity: 0.88, pointerYOffset: 0, showsTitle: false
    )

    static func value(for phase: V5TaskDragPhase) -> Self {
        switch phase {
        case .launching:
            return V5TaskDragPresentation(
                diameter: 18, scale: 1, opacity: 0.82, pointerYOffset: 0, showsTitle: false
            )
        case .catching:
            return V5TaskDragPresentation(
                diameter: 16, scale: 1, opacity: 0.92, pointerYOffset: -22, showsTitle: false
            )
        case .dragging: return .dragging
        case .targeted: return .targeted
        case .absorbing: return .absorbing
        case .returning: return .returning
        }
    }
}

enum V5TaskDropGeometry {
    static func targetDate(at point: CGPoint, dayFrames: [Date: CGRect]) -> Date? {
        dayFrames.first(where: { $0.value.contains(point) })?.key
    }

}

enum V5TaskDropCommitPolicy {
    /// Only the pointer's actual release location may commit. A previously
    /// hovered legal day cannot be reused after the pointer leaves it.
    static func resolvedTarget(atRelease candidate: Date?) -> Date? { candidate }
}

enum V5TaskDragGesturePolicy {
    static let minimumDistance: CGFloat = 8
    static let excludesCompletionControl = false
}

enum V5TaskDragAnchorGeometry {
    /// Source circles, drag locations and day indicators are all measured in
    /// the named workbench coordinate space. The rendered frame center is the
    /// final animation endpoint; no window-level conversion is applied.
    static func center(of frame: CGRect) -> CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }
}

enum V5ResolvedTaskDragGeometry {
    static func position(for phase: V5TaskDragPhase, pointer: CGPoint,
                         sourceAnchor: CGPoint?, targetAnchor: CGPoint?) -> CGPoint? {
        switch phase {
        case .launching, .returning:
            return sourceAnchor
        case .absorbing:
            return targetAnchor
        case .catching, .dragging, .targeted:
            return pointer
        }
    }

    static func renderedPosition(for phase: V5TaskDragPhase, pointer: CGPoint,
                                 sourceAnchor: CGPoint?, targetAnchor: CGPoint?) -> CGPoint? {
        guard let base = position(for: phase, pointer: pointer,
                                  sourceAnchor: sourceAnchor, targetAnchor: targetAnchor) else {
            return nil
        }
        let offset = V5TaskDragPresentation.value(for: phase).pointerYOffset
        return CGPoint(x: base.x, y: base.y + offset)
    }
}

enum V5TaskDropAnimationTiming {
    static let absorbDuration = 0.16
    static let modelCommitDelay = 0.0
}

enum V5TaskCompletionFlightPhase: Equatable {
    case card
    case collapsing
    case traveling
}

enum V5TaskLocalCompletionPhase: Equatable {
    case card
    case acknowledged
    case collapsing
}

struct V5TaskLocalCompletionPresentation: Equatable {
    let sourceSlotHeightScale: CGFloat
    let cardScaleY: CGFloat
    let cardOpacity: Double
    let blueBloomOpacity: Double
    let showsCompletedState: Bool

    static func value(for phase: V5TaskLocalCompletionPhase) -> Self {
        switch phase {
        case .card:
            return Self(
                sourceSlotHeightScale: 1,
                cardScaleY: 1,
                cardOpacity: 1,
                blueBloomOpacity: 0,
                showsCompletedState: false
            )
        case .acknowledged:
            return Self(
                sourceSlotHeightScale: 1,
                cardScaleY: 1,
                cardOpacity: 1,
                blueBloomOpacity: 0.24,
                showsCompletedState: true
            )
        case .collapsing:
            return Self(
                sourceSlotHeightScale: 0,
                cardScaleY: 0.18,
                cardOpacity: 0,
                blueBloomOpacity: 0,
                showsCompletedState: true
            )
        }
    }
}

enum V5TaskLocalCompletionTiming {
    static let acknowledgementDuration = 0.16
    static let holdDuration = 0.18
    static let collapseDuration = 0.26
    static let totalDuration = acknowledgementDuration + holdDuration + collapseDuration
    static let reducedMotionDuration = 0.16
}

struct V5TaskCompletionFlightGeometry: Equatable {
    let shellCenter: CGPoint
    let shellSize: CGSize
    let shellCornerRadius: CGFloat
    let shellFillOpacity: Double
    let shellStrokeWidth: CGFloat
    let contentScale: CGFloat
    let contentOpacity: Double

    static func value(for phase: V5TaskCompletionFlightPhase,
                      sourceFrame: CGRect, sourceRing: CGPoint,
                      target: CGPoint) -> Self {
        switch phase {
        case .card:
            return Self(
                shellCenter: CGPoint(x: sourceFrame.midX, y: sourceFrame.midY),
                shellSize: sourceFrame.size,
                shellCornerRadius: 11,
                shellFillOpacity: 1,
                shellStrokeWidth: 1,
                contentScale: 1,
                contentOpacity: 1
            )
        case .collapsing:
            return Self(
                shellCenter: sourceRing,
                shellSize: CGSize(width: 18, height: 18),
                shellCornerRadius: 9,
                shellFillOpacity: 0,
                shellStrokeWidth: 2,
                contentScale: 0.05,
                contentOpacity: 0
            )
        case .traveling:
            return Self(
                shellCenter: target,
                shellSize: CGSize(width: 7, height: 7),
                shellCornerRadius: 3.5,
                shellFillOpacity: 0,
                shellStrokeWidth: 1.35,
                contentScale: 0.05,
                contentOpacity: 0
            )
        }
    }
}

enum V5TaskCompletionSourceSlotPolicy {
    static func holdsSlot(during phase: V5TaskCompletionFlightPhase) -> Bool {
        switch phase {
        case .card, .collapsing:
            return true
        case .traveling:
            return false
        }
    }
}

enum V5TaskCompletionAccent: Equatable {
    case overdue
    case standard

    static func resolve(isOverdue: Bool) -> Self {
        isOverdue ? .overdue : .standard
    }
}

enum V5TaskCompletionTransition: Equatable {
    case inline
    case returnToDueDate

    static func resolve(dueDate: Date?, selectedDate: Date,
                        today: Date, calendar: Calendar) -> Self {
        guard let dueDate else { return .inline }
        let dueDay = calendar.startOfDay(for: dueDate)
        let selectedDay = calendar.startOfDay(for: selectedDate)
        let todayDay = calendar.startOfDay(for: today)

        // Flight communicates that today's overdue overview is returning work
        // to a different historical home. A task already viewed on its own day
        // has no spatial journey to make.
        guard dueDay < todayDay,
              selectedDay == todayDay,
              dueDay != selectedDay else { return .inline }
        return .returnToDueDate
    }
}

enum V5TaskCompletionFlightTiming {
    static let collapseStartDelay = 0.03
    static let collapseDuration = 0.30
    static let travelDuration = 0.46
    static let totalDuration = collapseStartDelay + collapseDuration + travelDuration
    static let reducedMotionCommitDelay = 0.10
}

enum V5TaskCompletionAdmission {
    static func canBegin(hasActiveFlight: Bool, hasPendingTarget: Bool) -> Bool {
        !hasActiveFlight && !hasPendingTarget
    }
}

struct V5TaskCompletionStart: Equatable {
    let taskID: UUID
}

/// Completion is a data command issued at interaction start. The lifecycle
/// tracks only the independent visual flight so navigation or window teardown
/// cannot undo, duplicate, or postpone the user's completed action.
struct V5TaskCompletionLifecycle {
    private var tasksBySession: [UUID: UUID] = [:]

    mutating func begin(sessionID: UUID, taskID: UUID) -> V5TaskCompletionStart? {
        guard tasksBySession[sessionID] == nil else { return nil }
        tasksBySession[sessionID] = taskID
        return V5TaskCompletionStart(taskID: taskID)
    }

    mutating func arrive(sessionID: UUID) -> UUID? {
        tasksBySession.removeValue(forKey: sessionID)
    }

    mutating func navigate() -> [UUID] {
        tasksBySession.removeAll()
        return []
    }

    mutating func calendarChanged() -> [UUID] {
        tasksBySession.removeAll()
        return []
    }

    mutating func cancelAll() -> [UUID] {
        tasksBySession.removeAll()
        return []
    }
}

struct V5DayTaskCounts: Equatable {
    let active: Int
    let completed: Int
    var total: Int { active + completed }
}

enum V5DayTaskIndicatorStyle: Equatable {
    case none
    case activeRing
    case completedDot

    static func resolve(activeCount: Int, completedCount: Int) -> Self {
        if activeCount > 0 { return .activeRing }
        if completedCount > 0 { return .completedDot }
        return .none
    }
}

struct V5DayIndicatorLayout: Equatable {
    let countText: String?
    let countFontSize: CGFloat

    static func value(total: Int, isToday: Bool) -> Self {
        _ = isToday
        let countText: String?
        if total <= 1 {
            countText = nil
        } else if total > 99 {
            countText = "99+"
        } else {
            countText = String(total)
        }

        return V5DayIndicatorLayout(
            countText: countText,
            countFontSize: total >= 10 ? 8 : 9
        )
    }
}

struct V5DayIndicatorArrivalPresentation: Equatable {
    let markerScale: CGFloat
    let glowRadius: CGFloat
    let glowOpacity: Double

    static func value(isArriving: Bool) -> Self {
        Self(
            markerScale: 1,
            glowRadius: isArriving ? 6 : 0,
            glowOpacity: isArriving ? 0.68 : 0
        )
    }
}

enum V5DayCellPresentation {
    static let dateFontSize: CGFloat = 29
    static let lunarTextYOffset: CGFloat = -2
    static let indicatorBottomPadding: CGFloat = 3
}

enum V5DayCellEmphasis: Equatable {
    case none
    case hover
    case today
    case selected
    case dropTarget

    static func resolve(
        isDraggingTask: Bool,
        isDropTarget: Bool,
        isSelected: Bool,
        isToday: Bool,
        isHovered: Bool
    ) -> Self {
        if isDraggingTask {
            if isDropTarget { return .dropTarget }
            return isToday ? .today : .none
        }
        if isSelected { return .selected }
        if isToday { return .today }
        if isHovered { return .hover }
        return .none
    }
}

enum V5AppearanceTransitionTiming {
    static let commitDelay = 0.22
    static let sliderResponse = 0.28
}
