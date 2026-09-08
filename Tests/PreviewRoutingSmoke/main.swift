import Foundation

@main
struct PreviewRoutingSmoke {
    static func main() {
        precondition(
            DesktopSentryPreviewRouting.target(arguments: [
                "DesktopSentry", "--calendar-workbench-v5-preview"
            ]) == .calendarV5
        )
        precondition(
            DesktopSentryPreviewRouting.target(arguments: [
                "DesktopSentry", "--calendar-workbench-v2-1-preview"
            ]) == .calendarV21
        )
        precondition(
            DesktopSentryPreviewRouting.target(arguments: [
                "DesktopSentry", "--calendar-workbench-v2-preview"
            ]) == .calendarV2
        )
        precondition(
            DesktopSentryPreviewRouting.target(arguments: [
                "DesktopSentry", "--skill-management-preview"
            ]) == .skillManagement
        )
        precondition(
            DesktopSentryPreviewRouting.target(arguments: ["DesktopSentry"]) == nil
        )

        for target in DesktopSentryPreviewTarget.allCases {
            precondition(
                DesktopSentryPreviewWindowPolicy.dismissesOnOutsideClick(target: target) == false,
                "an isolated feature preview must remain available for interaction"
            )
            precondition(
                DesktopSentryPreviewRouting.reopenDestination(for: target) == target,
                "reactivating a preview must reopen the feature being reviewed"
            )
        }
        precondition(
            DesktopSentryPreviewWindowPolicy.dismissesOnOutsideClick(target: nil),
            "the normal menu-bar product may retain its transient outside-click behavior"
        )
        precondition(!DesktopSentryPreviewSurfacePolicy.createsStatusBar(isIsolatedPreview: true),
                     "an isolated preview must expose no prompt, Skill, settings, login, or data menu")
        precondition(DesktopSentryPreviewSurfacePolicy.createsStatusBar(isIsolatedPreview: false))

        print("preview-routing=passed")
    }
}
