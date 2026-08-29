import Foundation

@main
struct AppBuildIdentitySmoke {
    static func main() {
        let release = AppBuildIdentity(infoDictionary: [
            "CFBundleShortVersionString": "2.0.2",
            "CFBundleVersion": "22"
        ])
        precondition(release.displayLabel == "2.0.2 (22) · 日历 V5")
        precondition(release.compactLabel == "2.0.2 (22) · V5")

        let tracedRelease = AppBuildIdentity(infoDictionary: [
            "CFBundleShortVersionString": "2.0.3",
            "CFBundleVersion": "23",
            "DesktopSentryWorkbenchGeneration": "V5",
            "DesktopSentrySourceRevision": "30efa05",
            "DesktopSentrySourceDirty": true,
            "DesktopSentryBuildChannel": "release"
        ])
        precondition(tracedRelease.displayLabel == "2.0.3 (23) · 日历 V5")
        precondition(tracedRelease.compactLabel == "2.0.3 (23) · V5")

        let preview = AppBuildIdentity(infoDictionary: [
            "CFBundleShortVersionString": "2.0.2",
            "CFBundleVersion": "22",
            "DesktopSentryWorkbenchGeneration": "V5",
            "DesktopSentrySourceRevision": "30efa05",
            "DesktopSentrySourceDirty": true,
            "DesktopSentryBuildChannel": "preview"
        ])
        precondition(
            preview.displayLabel == "2.0.2 (22) · 日历 V5 · 30efa05-dirty · 隔离预览"
        )
        precondition(preview.compactLabel == "2.0.2 (22) · V5 · 30efa05-dirty")

        print("AppBuildIdentity smoke test passed")
    }
}
