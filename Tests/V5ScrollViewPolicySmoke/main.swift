import AppKit

@main
struct V5ScrollViewPolicySmoke {
    static func main() {
        let width: CGFloat = 373
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: width, height: 420))
        scrollView.scrollerStyle = .legacy
        scrollView.hasVerticalScroller = true
        scrollView.documentView = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 900))
        scrollView.tile()

        V5ScrollViewPolicy.apply(to: scrollView)
        scrollView.tile()

        precondition(scrollView.scrollerStyle == .overlay,
                     "the task list must not use a width-reserving legacy scroller")
        precondition(!scrollView.hasVerticalScroller,
                     "the task list must not expose a native vertical scroller")
        precondition(scrollView.contentSize.width == width,
                     "hiding the scroller must return the complete viewport width to task cards")

        print("v5-scroll-view-policy=passed")
    }
}
