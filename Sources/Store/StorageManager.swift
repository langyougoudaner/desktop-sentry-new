import Foundation

/// Thread-safe JSON persistence manager.
///
/// All disk I/O executes on a dedicated serial dispatch queue (`.utility` QoS).
/// Completion callbacks are always dispatched back to the main thread.
/// Writes use `Data.write(to:options:.atomic)` for atomic temp-file-then-rename semantics.
/// Corrupt JSON is backed up and replaced with defaults — the app never crashes on bad data.
final class StorageManager {

    static let shared = StorageManager()

    // MARK: - Private state

    private let ioQueue = DispatchQueue(label: "com.desktopsentry.io", qos: .utility)
    private let writeLock = NSLock()   // guards the actual write critical section

    // MARK: - Path

    /// `~/Library/Application Support/DesktopSentry/data.json`
    private var dataURL: URL {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!   // .applicationSupportDirectory is always present on macOS
        let dir = appSupport
            .appendingPathComponent("DesktopSentry", isDirectory: true)
        return dir.appendingPathComponent("data.json")
    }

    /// Full filesystem path to the data directory (for `NSWorkspace.open`).
    var dataDirectoryPath: String {
        dataURL.deletingLastPathComponent().path
    }

    /// Tilde-abbreviated path for display in Settings.
    var displayPath: String {
        let full = dataDirectoryPath
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if full.hasPrefix(home) {
            return "~" + String(full.dropFirst(home.count))
        }
        return full
    }

    // MARK: - Init

    private init() {
        ensureDirectory()
    }

    private func ensureDirectory() {
        let dir = dataURL.deletingLastPathComponent()
        // Does not throw if directory already exists (withIntermediateDirectories)
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true
        )
    }

    // MARK: - Load (background → main)

    func load(completion: @escaping (AppData) -> Void) {
        ioQueue.async { [weak self] in
            guard let self else { return }
            let url = self.dataURL
            var data: AppData

            if !FileManager.default.fileExists(atPath: url.path) {
                // First launch — seed defaults immediately.
                data = .default
                self.writeAtomic(data)
            } else {
                do {
                    let raw = try Data(contentsOf: url)
                    data = try JSONDecoder().decode(AppData.self, from: raw)
                    // Clamp maxMenuBarChars on load (defensive)
                    data.maxMenuBarChars = data.clampedMaxChars
                } catch {
                    // Corrupt or unreadable — back up, then fall back.
                    self.backupCorruptFile(at: url)
                    data = .default
                    self.writeAtomic(data)
                }
            }

            DispatchQueue.main.async { completion(data) }
        }
    }

    // MARK: - Save (background, fire-and-forget)

    func save(_ appData: AppData) {
        ioQueue.async { [weak self] in
            self?.writeAtomic(appData)
        }
    }

    // MARK: - Core write (atomic)

    private func writeAtomic(_ appData: AppData) {
        writeLock.lock()
        defer { writeLock.unlock() }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(appData)
            // .atomic: writes to temp file then renames — crash-safe.
            try data.write(to: dataURL, options: [.atomic])
        } catch {
            // In production you'd route this to os_log / unified logging.
            NSLog("[StorageManager] write failed: %@", error.localizedDescription)
        }
    }

    // MARK: - Corruption recovery

    private func backupCorruptFile(at url: URL) {
        let stamp = Int(Date().timeIntervalSince1970)
        let backup = url.deletingLastPathComponent()
            .appendingPathComponent("data.corrupt.\(stamp).json")
        // Move (not copy) so the original path is free for a fresh default.
        try? FileManager.default.moveItem(at: url, to: backup)
    }
}
