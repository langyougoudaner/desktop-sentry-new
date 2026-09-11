import Foundation

@main
struct V5TaskRowInteractionSmoke {
    static func main() {
        let previouslyHoveredDate = Date(timeIntervalSince1970: 200)
        precondition(V5TaskDropCommitPolicy.resolvedTarget(atRelease: previouslyHoveredDate) == previouslyHoveredDate)
        precondition(V5TaskDropCommitPolicy.resolvedTarget(atRelease: nil) == nil,
                     "releasing outside a legal day must cancel instead of committing the last hover")

        let firstTask = UUID()
        let secondTask = UUID()
        let firstSession = UUID()
        let secondSession = UUID()
        var lifecycle = V5TaskCompletionLifecycle()
        precondition(lifecycle.begin(sessionID: firstSession, taskID: firstTask)?.taskID == firstTask,
                     "the completion command must be returned at interaction start")
        precondition(lifecycle.begin(sessionID: secondSession, taskID: secondTask)?.taskID == secondTask)
        precondition(lifecycle.arrive(sessionID: secondSession) == secondTask,
                     "one flight arriving must not force another flight to complete")
        precondition(lifecycle.arrive(sessionID: firstSession) == firstTask)
        precondition(lifecycle.arrive(sessionID: firstSession) == nil,
                     "the same completion flight must not commit twice")

        let rowReveal = V5TaskRowRevealPresentation.value
        precondition(!rowReveal.showsInsetStroke,
                     "selection and landing feedback must not draw an inner blue frame")
        precondition(rowReveal.cardScale == 1,
                     "glow feedback must not alter the card layout or hit target")

        precondition(V5TaskDragGesturePolicy.minimumDistance == 8,
                     "small pointer movement remains a click before drag begins")
        precondition(!V5TaskDragGesturePolicy.excludesCompletionControl,
                     "the completion circle must remain a valid drag origin")

        print("v5-task-row-interaction=passed")
    }
}
