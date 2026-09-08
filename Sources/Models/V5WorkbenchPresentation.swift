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

enum V5TaskDateFlipPresentation {
    static let duration = 0.48
    static let reducedMotionDuration = 0.10
    static let cardScale: CGFloat = 1
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
    static let modelCommitDelay = absorbDuration
}

enum V5TaskCompletionFlightPhase: Equatable {
    case card
    case orb
    case arrived
}

struct V5TaskCompletionFlightGeometry: Equatable {
    let cardCenter: CGPoint
    let cardScale: CGFloat
    let cardOpacity: Double
    let ringCenter: CGPoint
    let ringDiameter: CGFloat
    let ringOpacity: Double

    static func value(for phase: V5TaskCompletionFlightPhase,
                      sourceFrame: CGRect, sourceRing: CGPoint,
                      target: CGPoint) -> Self {
        let cardCenter = CGPoint(x: sourceFrame.midX, y: sourceFrame.midY)
        switch phase {
        case .card:
            return Self(cardCenter: cardCenter, cardScale: 1, cardOpacity: 1,
                        ringCenter: sourceRing, ringDiameter: 20, ringOpacity: 0)
        case .orb:
            return Self(cardCenter: cardCenter, cardScale: 0.08, cardOpacity: 0,
                        ringCenter: sourceRing, ringDiameter: 14, ringOpacity: 1)
        case .arrived:
            return Self(cardCenter: cardCenter, cardScale: 0.08, cardOpacity: 0,
                        ringCenter: target, ringDiameter: 7, ringOpacity: 1)
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
    static let collapseDuration = 0.18
    static let travelDuration = 0.42
    static let modelCommitDelay = collapseDuration + travelDuration
    static let reducedMotionCommitDelay = 0.10
}

enum V5TaskCompletionAdmission {
    static func canBegin(hasActiveFlight: Bool, hasPendingTarget: Bool) -> Bool {
        !hasActiveFlight && !hasPendingTarget
    }
}

/// The completion mutation belongs to the arrival event, never to an unrelated
/// navigation, focus, or window-lifecycle interruption.
struct V5TaskCompletionLifecycle {
    private var tasksBySession: [UUID: UUID] = [:]

    mutating func begin(sessionID: UUID, taskID: UUID) {
        tasksBySession[sessionID] = taskID
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

enum V5AppearanceTransitionTiming {
    static let commitDelay = 0.22
    static let sliderResponse = 0.28
}
