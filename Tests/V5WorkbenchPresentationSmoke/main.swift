import Foundation
import CoreGraphics

@main
struct V5WorkbenchPresentationSmoke {
    static func main() {
        precondition(V5AppearancePreference.system.next == .light)
        precondition(V5AppearancePreference.light.next == .dark)
        precondition(V5AppearancePreference.dark.next == .system)
        precondition(V5AppearancePreference.system.symbolName == "circle.lefthalf.filled")
        precondition(V5AppearancePreference.light.symbolName == "sun.max")
        precondition(V5AppearancePreference.dark.symbolName == "moon")
        precondition(V5AppearancePreference.system.panelAppearance == .inherited)
        precondition(V5AppearancePreference.light.panelAppearance == .aqua)
        precondition(V5AppearancePreference.dark.panelAppearance == .darkAqua)

        precondition(CalendarPanelPresentationPolicy.shouldReposition(isVisible: false))
        precondition(!CalendarPanelPresentationPolicy.shouldReposition(isVisible: true),
                     "an already-visible calendar must keep its current position")

        precondition(StatusItemRouting.action(role: .prompt, click: .left) == .copyPrompt)
        precondition(StatusItemRouting.action(role: .prompt, click: .right) == .showPromptMenu)
        precondition(StatusItemRouting.action(role: .calendar, click: .left) == .showCalendarPinned)
        precondition(StatusItemRouting.action(role: .calendar, click: .right) == .showCalendarPinned)

        let glyph = CalendarStatusGlyphGeometry(size: 18)
        precondition(glyph.cellRects.count == 6, "selected calendar glyph must contain six date cells")
        precondition(Set(glyph.cellRects.map(\.midX)).count == 3,
                     "selected calendar glyph must use three date columns")
        precondition(Set(glyph.cellRects.map(\.midY)).count == 2,
                     "selected calendar glyph must use two date rows")
        precondition(glyph.headerDividerY > glyph.cellRects.map(\.maxY).max()!,
                     "calendar header must remain visually separate from the date grid")
        precondition(glyph.outerRect.contains(glyph.cellRects[0]))

        let active = V5FooterPresentation(mode: .active, activeCount: 12, completedCount: 8)
        let completed = V5FooterPresentation(mode: .completed, activeCount: 12, completedCount: 8)
        precondition(active.title == "已完成 8")
        precondition(completed.title == "待办 12")
        precondition(active.controlWidth == completed.controlWidth,
                     "footer capsule width must stay stable while modes switch")
        precondition(active.controlWidth >= 104)

        let selectedGlow = V5SelectionGlowPresentation.selected
        let dropGlow = V5SelectionGlowPresentation.dropTarget
        precondition(selectedGlow.outerRadius <= 14,
                     "a selected date glow must stay inside neighboring calendar cells")
        precondition(selectedGlow.outerOpacity <= 0.18,
                     "persistent selection glow must remain restrained")
        precondition(dropGlow.outerRadius > selectedGlow.outerRadius,
                     "an active drop target must be more legible than a persistent selection")
        precondition(dropGlow.scale > selectedGlow.scale)
        precondition(dropGlow.animationResponse <= 0.3)

        let sourceDay = Date(timeIntervalSince1970: 100)
        let targetDay = Date(timeIntervalSince1970: 200)
        let dayFrames = [
            sourceDay: CGRect(x: 12, y: 20, width: 82, height: 78),
            targetDay: CGRect(x: 98, y: 20, width: 82, height: 78)
        ]
        precondition(V5TaskDropGeometry.targetDate(at: CGPoint(x: 120, y: 50),
                                                   dayFrames: dayFrames) == targetDay)
        precondition(V5TaskDropGeometry.targetDate(at: CGPoint(x: 400, y: 400),
                                                   dayFrames: dayFrames) == nil)
        let sourceAnchor = CGPoint(x: 720, y: 180)
        let pointer = CGPoint(x: 420, y: 330)
        let targetAnchor = CGPoint(x: 139, y: 91)
        let renderedMarkerFrame = CGRect(x: 135.5, y: 87.5, width: 7, height: 7)
        precondition(V5TaskDragAnchorGeometry.center(of: renderedMarkerFrame) == targetAnchor,
                     "the drop endpoint must be the rendered marker center in the workbench coordinate space")
        precondition(V5ResolvedTaskDragGeometry.position(
            for: .launching, pointer: pointer, sourceAnchor: sourceAnchor,
            targetAnchor: targetAnchor
        ) == sourceAnchor, "a drag must be born at the task's own completion ring")
        precondition(V5ResolvedTaskDragGeometry.position(
            for: .catching, pointer: pointer, sourceAnchor: sourceAnchor,
            targetAnchor: targetAnchor
        ) == pointer, "the launch spring must chase the live pointer")
        precondition(V5ResolvedTaskDragGeometry.position(
            for: .returning, pointer: pointer, sourceAnchor: sourceAnchor,
            targetAnchor: targetAnchor
        ) == sourceAnchor, "a cancelled drag must return to the same task ring")
        precondition(V5ResolvedTaskDragGeometry.position(
            for: .absorbing, pointer: pointer, sourceAnchor: sourceAnchor,
            targetAnchor: targetAnchor
        ) == targetAnchor, "a successful drag must resolve directly to the rendered day indicator")
        precondition(V5ResolvedTaskDragGeometry.renderedPosition(
            for: .targeted, pointer: pointer, sourceAnchor: sourceAnchor,
            targetAnchor: targetAnchor
        ) == CGPoint(x: pointer.x, y: pointer.y - 22),
        "the live orb must keep its optical pointer offset while dragging")
        precondition(V5ResolvedTaskDragGeometry.renderedPosition(
            for: .absorbing, pointer: pointer, sourceAnchor: sourceAnchor,
            targetAnchor: targetAnchor
        ) == targetAnchor,
        "release must have one exact rendered endpoint with no residual pointer offset")
        precondition(V5ResolvedTaskDragGeometry.position(
            for: .absorbing, pointer: pointer, sourceAnchor: sourceAnchor,
            targetAnchor: nil
        ) == nil, "a missing indicator must never fall back to the release pointer")

        precondition(V5TaskDragPresentation.dragging.diameter <= 16,
                     "a moving task must collapse to a small date-sized orb")
        precondition(V5TaskDragPresentation.dragging.pointerYOffset < 0,
                     "the orb must stay above the pointer so the target date remains readable")
        precondition(V5TaskDragPresentation.targeted.scale > V5TaskDragPresentation.dragging.scale)
        precondition(V5TaskDragPresentation.absorbing.diameter == 7)
        precondition(V5TaskDragPresentation.absorbing.scale == 1)
        precondition(V5TaskDragPresentation.absorbing.opacity == 1,
                     "the landing orb must be visually identical to the real calendar marker")
        precondition(V5TaskDropAnimationTiming.absorbDuration ==
                     V5TaskDropAnimationTiming.modelCommitDelay,
                     "the real marker must replace the drag orb on the landing frame")
        precondition(!V5TaskDragPresentation.returning.showsTitle,
                     "a cancelled drop must stay the same ring instead of turning into a task capsule")

        precondition(!V5TaskListOverflowPresentation.disablesScrollClipping,
                     "task rows must never render across the composer or footer")
        precondition(!V5TaskListOverflowPresentation.showsNativeScrollIndicator,
                     "the task list must never expose a native vertical scroller")
        precondition(V5TaskListOverflowPresentation.contentVerticalInset >=
                     V5TaskListOverflowPresentation.edgeFadeHeight,
                     "the first and last cards need internal clearance before the fade zone")
        let listCanvas = V5TaskListCanvasGeometry(contentWidth: 746)
        precondition(listCanvas.viewportWidth == 746,
                     "the scroll viewport must use the same width as the shared content guide")
        precondition(listCanvas.viewportOffsetX == 0,
                     "the scroll viewport must not shift left to manufacture animation room")
        precondition(listCanvas.contentMinX == 0,
                     "task cards must begin on the same guide as the composer")
        precondition(listCanvas.contentMaxX == 746,
                     "task cards must end on the same guide as the composer and footer")

        let rowReveal = V5TaskRowRevealPresentation.value
        precondition(rowReveal.cardScale == 1,
                     "drop feedback must not enlarge the card beyond the scroll viewport")
        precondition(!rowReveal.showsInsetStroke,
                     "drop feedback must not draw a second blue frame inside the card")
        precondition(rowReveal.perimeterGlowRadius > 0,
                     "drop feedback must retain a soft glow at the card perimeter")

        precondition(V5DayTaskIndicatorStyle.resolve(activeCount: 0, completedCount: 0) == .none)
        precondition(V5DayTaskIndicatorStyle.resolve(activeCount: 2, completedCount: 3) == .activeRing,
                     "any unfinished task must keep the day indicator hollow")
        precondition(V5DayTaskIndicatorStyle.resolve(activeCount: 0, completedCount: 3) == .completedDot,
                     "a day with only completed tasks must use a solid indicator")

        let compactCount = V5DayIndicatorLayout.value(total: 13, isToday: true)
        precondition(compactCount.countText == "13")
        precondition(V5DayCellPresentation.dateFontSize == 29,
                     "the accepted production date number must not move or resize")
        precondition(V5DayCellPresentation.lunarTextYOffset == -2,
                     "only the lunar label moves upward by two points")
        precondition(V5DayCellPresentation.indicatorBottomPadding == 3,
                     "the accepted production task marker position must stay unchanged")
        precondition(V5DayIndicatorLayout.value(total: 128, isToday: true).countText == "99+",
                     "large task totals must stay inside the calendar cell")

        precondition(V5AppearanceTransitionTiming.commitDelay >=
                     V5AppearanceTransitionTiming.sliderResponse * 0.75,
                     "the panel appearance must not interrupt the capsule while it is still sliding")
        precondition(V5AppearanceTransitionTiming.commitDelay <= 0.3)

        print("v5-workbench-presentation=passed")
    }
}
