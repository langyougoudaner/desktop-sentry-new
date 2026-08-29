import Foundation

/// Companion storage for V5-only fields. It never rewrites the legacy AppData
/// envelope, so running an older Desktop Sentry cannot silently erase dates,
/// notes, or reminders that it does not understand.
struct V5TaskMetadataStore {
    struct Envelope: Codable {
        var schemaVersion = 1
        var tasks: [UUID: V5TaskMetadata]
    }

    let fileURL: URL

    static var defaultFileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DesktopSentry", isDirectory: true)
            .appendingPathComponent("task-calendar-v5.json")
    }

    func load() throws -> [UUID: V5TaskMetadata] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [:] }
        return try JSONDecoder.desktopSentryV5.decode(Envelope.self, from: Data(contentsOf: fileURL)).tasks
    }

    func loadRecoveringCorruption() -> [UUID: V5TaskMetadata] {
        do {
            return try load()
        } catch {
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return [:] }
            let stem = fileURL.deletingPathExtension().lastPathComponent
            let backup = fileURL.deletingLastPathComponent().appendingPathComponent(
                "\(stem).corrupt.\(Int(Date().timeIntervalSince1970)).\(UUID().uuidString).json"
            )
            do {
                try FileManager.default.copyItem(at: fileURL, to: backup)
            } catch {
                NSLog("[V5TaskMetadataStore] corrupt backup failed: %@", error.localizedDescription)
            }
            return [:]
        }
    }

    func save(_ values: [UUID: V5TaskMetadata]) throws {
        let data = try JSONEncoder.desktopSentryV5.encode(Envelope(tasks: values))
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }
}

enum V5TaskMetadataMigration {
    /// Adds companion records for first-generation tasks without modifying
    /// their UUIDs or any field in the legacy AppData envelope.
    static func merge(tasks: [TaskItem], existing: [UUID: V5TaskMetadata],
                      defaultDate: Date, calendar: Calendar) -> [UUID: V5TaskMetadata] {
        var result = existing
        let migrationDay = calendar.startOfDay(for: defaultDate)
        for task in tasks where result[task.id] == nil {
            result[task.id] = V5TaskMetadata(dueDate: migrationDay)
        }
        return result
    }
}

private extension JSONEncoder {
    static var desktopSentryV5: JSONEncoder {
        let value = JSONEncoder(); value.dateEncodingStrategy = .iso8601; value.outputFormatting = [.prettyPrinted, .sortedKeys]; return value
    }
}

private extension JSONDecoder {
    static var desktopSentryV5: JSONDecoder {
        let value = JSONDecoder(); value.dateDecodingStrategy = .iso8601; return value
    }
}
