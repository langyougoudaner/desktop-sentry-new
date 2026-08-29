import AppKit

private final class CalendarWorkbenchBorderlessPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class CalendarWorkbenchHoverContainer: NSView {
    let onPointerEntered: () -> Void
    let onPointerExited: () -> Void

    init(frame: NSRect, onPointerEntered: @escaping () -> Void,
         onPointerExited: @escaping () -> Void) {
        self.onPointerEntered = onPointerEntered
        self.onPointerExited = onPointerExited
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { nil }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) { onPointerEntered() }
    override func mouseExited(with event: NSEvent) { onPointerExited() }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Single source of truth for how windows look.
///
/// Before this, the popover's background, corner radius and shadow were
/// claimed by BOTH the NSPanel and the SwiftUI view — with mismatched values
/// that fought each other. Now: glass panels get an NSVisualEffectView with
/// `.popover` material (real system glass, not the flat `.hudWindow` blur),
/// the container clips the corners, and SwiftUI views stay transparent.
enum PanelFactory {

    /// Floating glass panel for search / quick-add.
    /// Uses `.popover` material — the same glass system popovers use, with
    /// real vibrancy instead of a flat blur.
    static func makeGlassPanel(contentRect: NSRect,
                               contentView: NSView,
                               cornerRadius: CGFloat = 13,
                               movableByWindowBackground: Bool = true) -> NSPanel {
        let panel = NSPanel(
            contentRect: contentRect,
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isMovable = true
        panel.isMovableByWindowBackground = movableByWindowBackground
        panel.animationBehavior = .utilityWindow
        panel.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]

        panel.contentView = makeGlassContainer(frame: contentRect,
                                               contentView: contentView,
                                               cornerRadius: cornerRadius)
        return panel
    }

    /// A key, resizable glass window for the Deadline calendar. It uses normal
    /// window activation so date fields and the editor can receive focus.
    static func makeDeadlinePanel(contentRect: NSRect,
                                  contentView: NSView,
                                  cornerRadius: CGFloat = 16) -> NSPanel {
        let panel = NSPanel(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isMovable = true
        panel.isMovableByWindowBackground = true
        panel.animationBehavior = .utilityWindow
        panel.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
        panel.minSize = NSSize(width: 700, height: 480)
        panel.setFrameAutosaveName("DesktopSentryDeadlinePanel")
        for buttonType in [NSWindow.ButtonType.closeButton,
                           .miniaturizeButton,
                           .zoomButton] {
            panel.standardWindowButton(buttonType)?.isHidden = true
        }
        panel.contentView = makeGlassContainer(frame: contentRect,
                                                contentView: contentView,
                                                cornerRadius: cornerRadius)
        return panel
    }

    /// Familiar titled window for the isolated V2 workbench. Unlike the V1
    /// deadline panel, this keeps the normal macOS traffic lights and titlebar
    /// and does not make the whole content background draggable. The single
    /// native glass layer remains owned by `makeGlassContainer`.
    static func makeCalendarWorkbenchPanel(contentRect: NSRect,
                                           contentView: NSView,
                                           cornerRadius: CGFloat = 14) -> NSPanel {
        let panel = NSPanel(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "日历任务工作台"
        panel.titleVisibility = .visible
        panel.titlebarAppearsTransparent = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovable = true
        panel.isMovableByWindowBackground = false
        panel.animationBehavior = .utilityWindow
        panel.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
        panel.minSize = NSSize(width: 940, height: 650)
        panel.contentView = makeGlassContainer(frame: contentRect,
                                                contentView: contentView,
                                                cornerRadius: cornerRadius)
        return panel
    }

    /// V2.1 menu-bar workbench shell: one continuous native material, no
    /// visible titlebar, and no background dragging that can steal date taps.
    static func makeCalendarWorkbenchV21Panel(contentRect: NSRect,
                                              contentView: NSView,
                                              cornerRadius: CGFloat = 18,
                                              onPointerEntered: @escaping () -> Void = {},
                                              onPointerExited: @escaping () -> Void = {}) -> NSPanel {
        let panel = CalendarWorkbenchBorderlessPanel(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovable = true
        panel.isMovableByWindowBackground = false
        panel.animationBehavior = .utilityWindow
        panel.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
        panel.minSize = NSSize(width: 980, height: 620)
        panel.contentView = makeCalendarHoverGlassContainer(
            frame: contentRect,
            contentView: contentView,
            cornerRadius: cornerRadius,
            onPointerEntered: onPointerEntered,
            onPointerExited: onPointerExited
        )
        return panel
    }

    /// Standard titled window for Settings (no glass — plain system chrome).
    static func makeStandardPanel(contentRect: NSRect,
                                  contentView: NSView,
                                  title: String) -> NSPanel {
        let panel = NSPanel(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = title
        panel.isFloatingPanel = false
        panel.level = .normal
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .utilityWindow
        panel.contentView = contentView
        return panel
    }

    // MARK: - Glass container

    /// Rounded container holding an NSVisualEffectView (behind) + the hosting
    /// view (front, transparent). This is the only place that owns blur,
    /// corner radius and the glass look.
    static func makeGlassContainer(frame: NSRect,
                                   contentView: NSView,
                                   cornerRadius: CGFloat) -> NSView {
        let container = NSView(frame: frame)
        container.wantsLayer = true
        container.layer?.cornerRadius = cornerRadius
        container.layer?.masksToBounds = true

        let effect = NSVisualEffectView(frame: container.bounds)
        effect.autoresizingMask = [.width, .height]
        effect.material = .popover            // real system glass
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true

        contentView.frame = container.bounds
        contentView.autoresizingMask = [.width, .height]
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = .clear

        container.addSubview(effect, positioned: .below, relativeTo: nil)
        container.addSubview(contentView, positioned: .above, relativeTo: effect)
        return container
    }

    private static func makeCalendarHoverGlassContainer(
        frame: NSRect,
        contentView: NSView,
        cornerRadius: CGFloat,
        onPointerEntered: @escaping () -> Void,
        onPointerExited: @escaping () -> Void
    ) -> NSView {
        let container = CalendarWorkbenchHoverContainer(
            frame: frame,
            onPointerEntered: onPointerEntered,
            onPointerExited: onPointerExited
        )
        container.wantsLayer = true
        container.layer?.cornerRadius = cornerRadius
        container.layer?.masksToBounds = true

        let effect = NSVisualEffectView(frame: container.bounds)
        effect.autoresizingMask = [.width, .height]
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active

        contentView.frame = container.bounds
        contentView.autoresizingMask = [.width, .height]
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = .clear

        container.addSubview(effect, positioned: .below, relativeTo: nil)
        container.addSubview(contentView, positioned: .above, relativeTo: effect)
        return container
    }
}
