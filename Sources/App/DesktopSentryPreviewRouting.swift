import Foundation

enum DesktopSentryPreviewTarget: String, CaseIterable {
    case calendarV5
    case calendarV21
    case calendarV2
    case skillManagement
}

enum DesktopSentryPreviewRouting {
    static func target(arguments: [String]) -> DesktopSentryPreviewTarget? {
        if arguments.contains("--calendar-workbench-v5-preview") { return .calendarV5 }
        if arguments.contains("--calendar-workbench-v2-1-preview") { return .calendarV21 }
        if arguments.contains("--calendar-workbench-v2-preview") { return .calendarV2 }
        if arguments.contains("--skill-management-preview") { return .skillManagement }
        return nil
    }

    static func reopenDestination(
        for target: DesktopSentryPreviewTarget
    ) -> DesktopSentryPreviewTarget {
        target
    }
}

enum DesktopSentryPreviewWindowPolicy {
    static func dismissesOnOutsideClick(
        target: DesktopSentryPreviewTarget?
    ) -> Bool {
        target == nil
    }
}

enum DesktopSentryPreviewSurfacePolicy {
    static func createsStatusBar(isIsolatedPreview: Bool) -> Bool {
        !isIsolatedPreview
    }
}
