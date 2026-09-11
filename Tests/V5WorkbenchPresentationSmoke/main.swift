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

        let collapsedSections = V5InlineTaskSectionsPresentation(
            activeCount: 2,
            overdueCount: 4,
            completedCount: 5,
            completedExpanded: false
        )
        precondition(collapsedSections.visibleCompletedCount == 3,
                     "the default list keeps completed work visible without flooding the sidebar")
        precondition(collapsedSections.completedDisclosureTitle == "查看全部 5")
        precondition(collapsedSections.footerSummary == "今天 2 · 逾期 4 · 已完成 5")
        let expandedSections = V5InlineTaskSectionsPresentation(
            activeCount: 2,
            overdueCount: 0,
            completedCount: 5,
            completedExpanded: true
        )
        precondition(expandedSections.visibleCompletedCount == 5)
        precondition(expandedSections.completedDisclosureTitle == "收起")
        precondition(expandedSections.footerSummary == "待办 2 · 已完成 5")

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
        precondition(V5TaskDropAnimationTiming.modelCommitDelay <
                     V5TaskDropAnimationTiming.absorbDuration,
                     "the date must commit before the independent drag orb finishes absorbing")
        precondition(!V5TaskDragPresentation.returning.showsTitle,
                     "a cancelled drop must stay the same ring instead of turning into a task capsule")

        let completionSource = CGRect(x: 700, y: 250, width: 360, height: 52)
        let completionSourceRing = CGPoint(x: 722, y: 276)
        let completionTarget = CGPoint(x: 176, y: 410)
        let completionCard = V5TaskCompletionFlightGeometry.value(
            for: .card, sourceFrame: completionSource,
            sourceRing: completionSourceRing, target: completionTarget
        )
        precondition(completionCard.shellCenter == CGPoint(x: 880, y: 276))
        precondition(completionCard.shellSize == completionSource.size)
        precondition(completionCard.shellCornerRadius == 11)
        precondition(completionCard.contentScale == 1 && completionCard.contentOpacity == 1,
                     "completion must begin from one complete rendered card shell")
        let completionOrb = V5TaskCompletionFlightGeometry.value(
            for: .collapsing, sourceFrame: completionSource,
            sourceRing: completionSourceRing, target: completionTarget
        )
        precondition(completionOrb.shellCenter == completionSourceRing,
                     "the same shell must collapse onto the card's own completion circle")
        precondition(completionOrb.shellSize == CGSize(width: 18, height: 18))
        precondition(completionOrb.shellCornerRadius == 9)
        precondition(completionOrb.contentOpacity == 0,
                     "text and date must be absorbed into the single orange shell")
        let completionArrival = V5TaskCompletionFlightGeometry.value(
            for: .traveling, sourceFrame: completionSource,
            sourceRing: completionSourceRing, target: completionTarget
        )
        precondition(completionArrival.shellCenter == completionTarget)
        precondition(completionArrival.shellSize == CGSize(width: 7, height: 7),
                     "the same orange shell must finish at calendar-indicator size")
        precondition(V5TaskCompletionSourceSlotPolicy.holdsSlot(during: .card))
        precondition(V5TaskCompletionSourceSlotPolicy.holdsSlot(during: .collapsing),
                     "the next row must not move through a card that is still collapsing")
        precondition(!V5TaskCompletionSourceSlotPolicy.holdsSlot(during: .traveling),
                     "the source slot may close only after the orb has formed")
        precondition(V5TaskCompletionFlightTiming.collapseStartDelay > 0,
                     "the complete source card must render before its morph begins")
        precondition(V5TaskCompletionFlightTiming.collapseDuration >= 0.28,
                     "the card-to-ring morph must remain perceptible at 60 fps")
        precondition(V5TaskCompletionFlightTiming.totalDuration ==
                     V5TaskCompletionFlightTiming.collapseStartDelay +
                     V5TaskCompletionFlightTiming.collapseDuration +
                     V5TaskCompletionFlightTiming.travelDuration,
                     "the visual flight must have one continuous collapse-and-travel duration")
        precondition(V5TaskCompletionFlightTiming.reducedMotionCommitDelay <
                     V5TaskCompletionFlightTiming.totalDuration)
        precondition(V5TaskCompletionAccent.resolve(isOverdue: true) == .overdue)
        precondition(V5TaskCompletionAccent.resolve(isOverdue: false) == .standard)

        let localCard = V5TaskLocalCompletionPresentation.value(for: .card)
        let localAcknowledged = V5TaskLocalCompletionPresentation.value(for: .acknowledged)
        let localCollapsing = V5TaskLocalCompletionPresentation.value(for: .collapsing)
        precondition(localCard.sourceSlotHeightScale == 1)
        precondition(!localCard.showsCompletedState)
        precondition(localAcknowledged.sourceSlotHeightScale == 1,
                     "an inline completion must stay in its original slot long enough to be understood")
        precondition(localAcknowledged.showsCompletedState)
        precondition(localAcknowledged.cardOpacity == 1,
                     "the completed checkmark and strike-through must be fully visible before collapse")
        precondition(localCollapsing.sourceSlotHeightScale == 0)
        precondition(localCollapsing.cardOpacity == 0)
        precondition(V5TaskLocalCompletionTiming.acknowledgementDuration > 0)
        precondition(V5TaskLocalCompletionTiming.holdDuration >= 0.12,
                     "today's completed state needs a perceptible hold instead of disappearing instantly")
        precondition(V5TaskLocalCompletionTiming.totalDuration >= 0.5)

        var completionCalendar = Calendar(identifier: .gregorian)
        completionCalendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let completionToday = completionCalendar.date(from: DateComponents(
            year: 2026, month: 9, day: 7, hour: 12
        ))!
        let completionYesterday = completionCalendar.date(
            byAdding: .day, value: -1, to: completionToday
        )!
        let completionTomorrow = completionCalendar.date(
            byAdding: .day, value: 1, to: completionToday
        )!
        precondition(V5TaskCompletionTransition.resolve(
            dueDate: completionToday, selectedDate: completionToday,
            today: completionToday, calendar: completionCalendar
        ) == .inline, "a task already on today's page must complete in place")
        precondition(V5TaskCompletionTransition.resolve(
            dueDate: completionYesterday, selectedDate: completionYesterday,
            today: completionToday, calendar: completionCalendar
        ) == .inline, "a task viewed on its own historical date is already home")
        precondition(V5TaskCompletionTransition.resolve(
            dueDate: completionYesterday, selectedDate: completionToday,
            today: completionToday, calendar: completionCalendar
        ) == .returnToDueDate,
        "only an overdue task surfaced away from its due date should fly home")
        precondition(V5TaskCompletionTransition.resolve(
            dueDate: completionTomorrow, selectedDate: completionToday,
            today: completionToday, calendar: completionCalendar
        ) == .inline, "a defensive future-date mismatch must not imply overdue return")

        let arrivalFeedback = V5DayIndicatorArrivalPresentation.value(isArriving: true)
        precondition(arrivalFeedback.markerScale == 1,
                     "arrival feedback must never enlarge or displace the real day marker")
        precondition(arrivalFeedback.glowRadius > 0,
                     "arrival may acknowledge completion with a stationary glow")
        precondition(V5TaskCompletionAdmission.canBegin(
            hasActiveFlight: false, hasPendingTarget: false
        ))
        precondition(!V5TaskCompletionAdmission.canBegin(
            hasActiveFlight: true, hasPendingTarget: false
        ), "a second action must not reuse coordinates while a flight is active")
        precondition(!V5TaskCompletionAdmission.canBegin(
            hasActiveFlight: false, hasPendingTarget: true
        ), "a second action must not replace an unresolved cross-month target")

        let completionTask = UUID()
        let completionSession = UUID()
        var lifecycle = V5TaskCompletionLifecycle()
        precondition(lifecycle.begin(
            sessionID: completionSession,
            taskID: completionTask
        )?.taskID == completionTask,
        "starting the visual flight must return the task command for immediate commit")
        precondition(lifecycle.navigate() == [],
                     "navigation cancels only visual coordinates; task data was already committed")
        precondition(lifecycle.arrive(sessionID: completionSession) == nil,
                     "navigation must cancel stale flight coordinates")
        precondition(lifecycle.begin(
            sessionID: completionSession,
            taskID: completionTask
        )?.taskID == completionTask)
        precondition(lifecycle.calendarChanged() == [],
                     "changing the visible month cancels stale geometry without undoing completion")
        precondition(lifecycle.arrive(sessionID: completionSession) == nil,
                     "a cancelled visual flight must not finish at its old coordinate")
        precondition(lifecycle.begin(
            sessionID: completionSession,
            taskID: completionTask
        )?.taskID == completionTask)
        precondition(lifecycle.arrive(sessionID: completionSession) == completionTask,
                     "arrival closes only its own visual flight without a second data mutation")
        let cancelledTask = UUID()
        precondition(lifecycle.begin(
            sessionID: UUID(),
            taskID: cancelledTask
        )?.taskID == cancelledTask)
        precondition(lifecycle.cancelAll().isEmpty,
                     "closing the preview cancels visuals without rolling completed data back")

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
        precondition(rowReveal.innerBloomDuration > 0)
        precondition(rowReveal.landingOutlineOutset == 2,
                     "the landing outline may sit only two points beyond the original card")
        precondition(rowReveal.landingOutlineCornerRadius == 13,
                     "the expanded outline must keep its curve parallel to the 11-point card")
        precondition(rowReveal.landingOutlineDuration > 0,
                     "the fixed landing outline should still fade smoothly")

        let selection = V5TaskSelectionPresentation.value
        precondition(selection.darkFillOpacity == 0.11)
        precondition(selection.lightFillOpacity == 0.07)
        precondition(selection.borderOpacity == 0.9)
        precondition(selection.borderWidth == 1.5)
        precondition(selection.primaryGlowRadius == 7)
        precondition(selection.secondaryGlowRadius == 12)

        let stableTaskID = UUID()
        let activeRowIdentity = V5TaskRowIdentity.value(
            taskID: stableTaskID, isCompleted: false
        )
        precondition(activeRowIdentity == V5TaskRowIdentity.value(
            taskID: stableTaskID, isCompleted: false
        ), "changing only the due date must not recreate the whole task card")
        precondition(activeRowIdentity != V5TaskRowIdentity.value(
            taskID: stableTaskID, isCompleted: true
        ), "completion must refresh the row's controls while the list transaction suppresses outgoing animation")
        precondition(V5TaskDateFlipPresentation.duration >= 0.45,
                     "the date-only page turn must be slow enough to read")
        precondition(V5TaskDateFlipPresentation.duration <= 0.60,
                     "the date-only page turn must remain responsive")
        precondition(V5TaskDateFlipPresentation.cardScale == 1,
                     "date changes must never flip or scale the containing task card")
        precondition(!V5TaskDateFlipPresentation.usesOutgoingTextLayer,
                     "a date turn must animate one authoritative label instead of overlapping old and new glyphs")
        precondition(V5TaskDateFlipPresentation.reducedMotionDuration <
                     V5TaskDateFlipPresentation.duration,
                     "reduced motion must replace the page turn with a short cross-fade")

        precondition(!V5TaskListAnimationPolicy.animatesWholeList(for: .selectedDateChanged),
                     "switching days must replace the list atomically without old/new rows overlapping")
        precondition(!V5TaskListAnimationPolicy.animatesWholeList(for: .taskDateMoved),
                     "moving a task between date sections must not animate the whole stack")
        precondition(!V5TaskListAnimationPolicy.animatesWholeList(for: .taskCompletionChanged),
                     "completion must update section membership atomically without old/new rows overlapping")
        precondition(V5TaskListAnimationPolicy.animatesWholeList(for: .completedDisclosureChanged),
                     "expanding completed work may keep the deliberate list transition")
        precondition(V5TaskDropAnimationTiming.modelCommitDelay == 0,
                     "the reassigned date must become authoritative on release, before visual absorption finishes")

        precondition(V5DayCellEmphasis.resolve(
            isDraggingTask: true,
            isDropTarget: true,
            isSelected: true,
            isToday: true,
            isHovered: true
        ) == .dropTarget,
        "during a drag, the legal destination must be the only strong blue calendar emphasis")
        precondition(V5DayCellEmphasis.resolve(
            isDraggingTask: true,
            isDropTarget: false,
            isSelected: true,
            isToday: false,
            isHovered: true
        ) == .none,
        "the old selection and stale hover must disappear while a task is being dragged")
        precondition(V5DayCellEmphasis.resolve(
            isDraggingTask: true,
            isDropTarget: false,
            isSelected: false,
            isToday: true,
            isHovered: true
        ) == .today,
        "today may keep its passive reference ring during a drag")

        let navigationReady = V5CalendarKeyboardContext(
            isTextInputFocused: false,
            isEditingTask: false,
            isDraggingTask: false,
            isChoosingYear: false
        )
        precondition(V5CalendarKeyboardNavigation.action(
            for: .up,
            isCommandPressed: false,
            context: navigationReady
        ) == .moveSelectionByDays(-7))
        precondition(V5CalendarKeyboardNavigation.action(
            for: .down,
            isCommandPressed: false,
            context: navigationReady
        ) == .moveSelectionByDays(7))
        precondition(V5CalendarKeyboardNavigation.action(
            for: .left,
            isCommandPressed: false,
            context: navigationReady
        ) == .moveSelectionByDays(-1))
        precondition(V5CalendarKeyboardNavigation.action(
            for: .right,
            isCommandPressed: false,
            context: navigationReady
        ) == .moveSelectionByDays(1))
        precondition(V5CalendarKeyboardNavigation.action(
            for: .left,
            isCommandPressed: true,
            context: navigationReady
        ) == .moveSelectionByMonths(-1))
        precondition(V5CalendarKeyboardNavigation.action(
            for: .right,
            isCommandPressed: true,
            context: navigationReady
        ) == .moveSelectionByMonths(1))
        precondition(V5CalendarKeyboardNavigation.action(
            for: .up,
            isCommandPressed: true,
            context: navigationReady
        ) == nil)
        precondition(V5CalendarKeyboardEventRouting.direction(forKeyCode: 126) == .up)
        precondition(V5CalendarKeyboardEventRouting.direction(forKeyCode: 125) == .down)
        precondition(V5CalendarKeyboardEventRouting.direction(forKeyCode: 123) == .left)
        precondition(V5CalendarKeyboardEventRouting.direction(forKeyCode: 124) == .right)
        precondition(V5CalendarKeyboardEventRouting.action(
            forKeyCode: 17,
            isCommandPressed: true,
            hasDisallowedModifiers: false,
            context: navigationReady
        ) == .jumpToToday, "Command-T must share the same Today action as the visible button")
        precondition(V5CalendarKeyboardEventRouting.action(
            forKeyCode: 17,
            isCommandPressed: false,
            hasDisallowedModifiers: false,
            context: navigationReady
        ) == nil, "plain text input must never be consumed as a calendar shortcut")
        precondition(V5CalendarKeyboardEventRouting.action(
            forKeyCode: 124,
            isCommandPressed: true,
            hasDisallowedModifiers: true,
            context: navigationReady
        ) == nil, "mixed modifiers must remain available to the system")
        precondition(V5CalendarKeyboardEventRouting.action(
            forKeyCode: 53,
            isCommandPressed: false,
            hasDisallowedModifiers: false,
            context: V5CalendarKeyboardContext(
                isTextInputFocused: true,
                isEditingTask: false,
                isDraggingTask: false,
                isChoosingYear: true
            )
        ) == .escapeChooser,
        "the chooser must receive Escape even when the composer retained first responder")
        precondition(V5CalendarKeyboardNavigation.action(
            for: .down,
            isCommandPressed: false,
            context: V5CalendarKeyboardContext(
                isTextInputFocused: true,
                isEditingTask: false,
                isDraggingTask: false,
                isChoosingYear: false
            )
        ) == nil, "calendar navigation must not steal cursor keys from task input")
        precondition(V5CalendarKeyboardNavigation.action(
            for: .down,
            isCommandPressed: false,
            context: V5CalendarKeyboardContext(
                isTextInputFocused: false,
                isEditingTask: false,
                isDraggingTask: true,
                isChoosingYear: false
            )
        ) == nil, "month navigation must not invalidate an active drag target")
        precondition(V5CalendarKeyboardNavigation.action(
            for: .down,
            isCommandPressed: false,
            context: V5CalendarKeyboardContext(
                isTextInputFocused: false,
                isEditingTask: false,
                isDraggingTask: false,
                isChoosingYear: true
            )
        ) == nil, "the year chooser is intentionally mouse-driven")

        let centeredYears = V5YearChooserPresentation.years(containing: 2026)
        precondition(centeredYears == Array(2022...2033))
        precondition(centeredYears.firstIndex(of: 2026) == 4,
                     "this year belongs in the second row's center cell")
        precondition(V5YearChooserPresentation.yearsPerPage == 12)
        precondition(V5YearChooserPresentation.yearColumns == 3)
        precondition(V5YearChooserPresentation.yearRows == 4)
        precondition(V5YearChooserPresentation.months == Array(1...12))
        precondition(V5YearChooserPresentation.monthColumns == V5YearChooserPresentation.yearColumns)
        precondition(V5YearChooserPresentation.monthRows == V5YearChooserPresentation.yearRows,
                     "year and month levels must keep one stable 3-by-4 spatial skeleton")
        precondition(V5YearChooserPresentation.choiceNumberFontSize >= 60,
                     "year and month numbers must occupy the large selection cells confidently")
        precondition(V5YearChooserPresentation.selectionCanvasInset >= selectedGlow.outerRadius,
                     "outer year and month cells need enough breathing room for the shared glow")
        precondition(V5YearChooserPresentation.previousPageStart(containing: 2026) == 2010)
        precondition(V5YearChooserPresentation.nextPageStart(containing: 2026) == 2034)
        precondition(V5YearMonthChooserNavigation.escapeDestination(from: .months) == .years)
        precondition(V5YearMonthChooserNavigation.escapeDestination(from: .years) == nil,
                     "Escape closes the chooser only after returning to the year level")
        precondition(V5YearChooserPresentation.selectionFeedbackDuration >= 0.16)
        precondition(V5YearChooserPresentation.selectionFeedbackDuration <= 0.28,
                     "selection feedback must be visible without making the picker feel delayed")

        var railCalendar = Calendar(identifier: .gregorian)
        railCalendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        railCalendar.firstWeekday = 2
        let september10 = railCalendar.date(from: DateComponents(
            year: 2026, month: 9, day: 10, hour: 12
        ))!
        let october10 = railCalendar.date(from: DateComponents(
            year: 2026, month: 10, day: 10, hour: 12
        ))!
        guard let forwardRail = V5CalendarMonthRailPlan.make(
            sourceMonth: september10,
            targetMonth: october10,
            sourceSelection: september10,
            targetSelection: october10,
            calendar: railCalendar
        ) else {
            preconditionFailure("adjacent months must produce a continuous week rail")
        }
        precondition(forwardRail.sourceWeekIndex == 0)
        precondition(forwardRail.targetWeekIndex == 4,
                     "September 2026 advances to October by four shared calendar weeks")
        precondition(forwardRail.sourceOffsetY == 0)
        precondition(forwardRail.targetOffsetY == -4 * V5CalendarMonthRailPresentation.rowPitch)
        precondition(Set(forwardRail.days).count == forwardRail.days.count,
                     "the rolling rail must render every real date once instead of stacking duplicate month pages")
        precondition(forwardRail.days.count == 70,
                     "two six-week month windows with four shared weeks need ten unique weeks")

        guard let backwardRail = V5CalendarMonthRailPlan.make(
            sourceMonth: october10,
            targetMonth: september10,
            sourceSelection: october10,
            targetSelection: september10,
            calendar: railCalendar
        ) else {
            preconditionFailure("reverse navigation must use the same chronological rail")
        }
        precondition(backwardRail.sourceWeekIndex == 4)
        precondition(backwardRail.targetWeekIndex == 0)
        precondition(backwardRail.sourceOffsetY == -4 * V5CalendarMonthRailPresentation.rowPitch)
        precondition(backwardRail.targetOffsetY == 0)
        precondition(!V5CalendarMonthRailPresentation.usesOpacityReplacement)
        precondition(V5CalendarMonthRailPresentation.installationDelay >= 1.0 / 60.0,
                     "the source rail needs at least one display pass before motion starts")
        precondition(V5CalendarMonthRailPresentation.headerControlOpacity == 1,
                     "month motion must never dim the year or Today controls")

        let january31 = railCalendar.date(from: DateComponents(
            year: 2025, month: 1, day: 31, hour: 12
        ))!
        let preferredFebruary = V5CalendarDateNavigation.movingMonths(
            1,
            from: january31,
            preferredDay: 31,
            calendar: railCalendar
        )!
        let restoredMarch = V5CalendarDateNavigation.movingMonths(
            1,
            from: preferredFebruary,
            preferredDay: 31,
            calendar: railCalendar
        )!
        precondition(railCalendar.component(.day, from: preferredFebruary) == 28)
        precondition(railCalendar.component(.day, from: restoredMarch) == 31,
                     "a clamped February must not permanently erase the user's preferred day")

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
