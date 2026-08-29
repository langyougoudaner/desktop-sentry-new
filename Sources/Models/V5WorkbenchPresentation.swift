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

    static let value = V5TaskRowRevealPresentation(
        cardScale: 1,
        showsInsetStroke: false,
        perimeterGlowRadius: 5
    )
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

enum V5DayCellPresentation {
    static let dateFontSize: CGFloat = 29
    static let lunarTextYOffset: CGFloat = -2
    static let indicatorBottomPadding: CGFloat = 3
}

enum V5AppearanceTransitionTiming {
    static let commitDelay = 0.22
    static let sliderResponse = 0.28
}
