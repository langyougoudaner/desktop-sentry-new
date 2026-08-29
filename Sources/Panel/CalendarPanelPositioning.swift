import AppKit

enum CalendarPanelPositioning {
    static func frame(panelSize: NSSize,
                      anchor: NSRect,
                      visibleFrame: NSRect,
                      menuBarGap: CGFloat = 3) -> NSRect {
        let x = min(
            max(anchor.midX - panelSize.width / 2, visibleFrame.minX + 8),
            visibleFrame.maxX - panelSize.width - 8
        )
        let y = max(
            visibleFrame.maxY - panelSize.height - menuBarGap,
            visibleFrame.minY + 8
        )
        return NSRect(origin: NSPoint(x: x, y: y), size: panelSize)
    }
}
