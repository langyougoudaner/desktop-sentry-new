import Foundation

/// Independent atomic persistence for Deadline records.
/// It never reads or rewrites the legacy `data.json` file.
final class DeadlineStorage {
    static let shared = DeadlineStorage()

    private let fileURL: URL
    private let ioQueue = DispatchQueue(label: "com.desktopsentry.deadlines-io", qos: .utility)
    private let writeLock = NSLock()

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let appSupport = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            self.fileURL = appSupport
                .appendingPathComponent("DesktopSentry", isDirectory: true)
                .appendingPathComponent("deadlines.json")
        }
        ensureDirectory()
    }

    var url: URL { fileURL }

    func load(completion: @escaping ([DeadlineItem]) -> Void) {
        ioQueue.async { [weak self] in
            guard let self else { return }
            let result = self.read()
            DispatchQueue.main.async { completion(result) }
        }
    }

    func save(_ deadlines: [DeadlineItem]) {
        ioQueue.async { [weak self] in self?.writeAtomic(deadlines) }
    }

    private func ensureDirectory() {
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    private func read() -> [DeadlineItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([DeadlineItem].self, from: data)
        } catch {
            preserveCorruptFile()
            writeAtomic([])
            return []
        }
    }

    private func writeAtomic(_ deadlines: [DeadlineItem]) {
        writeLock.lock()
        defer { writeLock.unlock() }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(deadlines)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            NSLog("[DeadlineStorage] write failed: %@", error.localizedDescription)
        }
    }

    private func preserveCorruptFile() {
        let stamp = Int(Date().timeIntervalSince1970)
        let backupURL = fileURL.deletingLastPathComponent()
            .appendingPathComponent("deadlines.corrupt.\(stamp).json")
        try? FileManager.default.copyItem(at: fileURL, to: backupURL)
    }
}
