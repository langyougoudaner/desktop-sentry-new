import AppKit

@main
struct CalendarPanelPositioningSmoke {
    static func main() {
        let visible = NSRect(x: 0, y: 25, width: 1512, height: 957)
        let frame = CalendarPanelPositioning.frame(
            panelSize: NSSize(width: 1060, height: 660),
            anchor: NSRect(x: 900, y: 982, width: 90, height: 24),
            visibleFrame: visible,
            menuBarGap: 3
        )

        precondition(frame.maxY == visible.maxY - 3,
                     "hover calendar must sit three points below the menu bar")
        precondition(frame.minX >= visible.minX + 8)
        precondition(frame.maxX <= visible.maxX - 8)
        print("calendar-panel-positioning=passed")
    }
}
