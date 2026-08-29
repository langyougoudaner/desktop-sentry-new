import AppKit

enum V5ScrollViewPolicy {
    /// SwiftUI can recreate or retile its underlying NSScrollView after applying
    /// `showsIndicators: false`. Keep the AppKit owner in overlay mode and remove
    /// both native scrollers so they neither render nor reserve card width.
    @discardableResult
    @MainActor
    static func apply(to scrollView: NSScrollView) -> Bool {
        var changed = false

        if scrollView.scrollerStyle != .overlay {
            scrollView.scrollerStyle = .overlay
            changed = true
        }
        if !scrollView.autohidesScrollers {
            scrollView.autohidesScrollers = true
            changed = true
        }
        if scrollView.hasVerticalScroller {
            scrollView.hasVerticalScroller = false
            changed = true
        }
        if scrollView.hasHorizontalScroller {
            scrollView.hasHorizontalScroller = false
            changed = true
        }
        if scrollView.verticalScroller?.isHidden == false {
            scrollView.verticalScroller?.isHidden = true
            changed = true
        }
        if scrollView.horizontalScroller?.isHidden == false {
            scrollView.horizontalScroller?.isHidden = true
            changed = true
        }

        return changed
    }
}
