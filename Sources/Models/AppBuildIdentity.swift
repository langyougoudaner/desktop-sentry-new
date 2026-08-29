import Foundation

/// A human-readable identity for the exact app binary that is currently running.
///
/// Release version/build numbers identify a release. Source-built previews also
/// carry the Git revision and dirty state so two different binaries cannot look
/// identical when screenshots or bug reports are compared.
struct AppBuildIdentity: Equatable {
    let version: String
    let build: String
    let workbenchGeneration: String
    let sourceRevision: String?
    let sourceDirty: Bool
    let channel: String

    static var current: AppBuildIdentity {
        AppBuildIdentity(infoDictionary: Bundle.main.infoDictionary ?? [:])
    }

    init(infoDictionary: [String: Any]) {
        version = Self.stringValue(infoDictionary["CFBundleShortVersionString"]) ?? "未知版本"
        build = Self.stringValue(infoDictionary["CFBundleVersion"]) ?? "?"
        workbenchGeneration = Self.stringValue(
            infoDictionary["DesktopSentryWorkbenchGeneration"]
        ) ?? "V5"

        let revision = Self.stringValue(infoDictionary["DesktopSentrySourceRevision"])
        sourceRevision = revision == "unknown" ? nil : revision
        sourceDirty = Self.boolValue(infoDictionary["DesktopSentrySourceDirty"])
        channel = Self.stringValue(infoDictionary["DesktopSentryBuildChannel"]) ?? "release"
    }

    /// Short enough for the calendar footer while still identifying the binary.
    var compactLabel: String {
        var parts = ["\(version) (\(build))", workbenchGeneration]
        if channel == "preview", let sourceRevision {
            parts.append(sourceRevision + (sourceDirty ? "-dirty" : ""))
        }
        return parts.joined(separator: " · ")
    }

    /// Full label for Settings and text copied into bug reports.
    var displayLabel: String {
        var parts = ["\(version) (\(build))", "日历 \(workbenchGeneration)"]
        if channel == "preview", let sourceRevision {
            parts.append(sourceRevision + (sourceDirty ? "-dirty" : ""))
        }
        if channel == "preview" {
            parts.append("隔离预览")
        }
        return parts.joined(separator: " · ")
    }

    private static func stringValue(_ value: Any?) -> String? {
        guard let value else { return nil }
        let result = String(describing: value).trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }

    private static func boolValue(_ value: Any?) -> Bool {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        if let value = value as? String { return value == "true" || value == "1" }
        return false
    }
}
