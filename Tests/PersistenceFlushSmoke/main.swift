import Foundation

@main
struct PersistenceFlushSmoke {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("DesktopSentryManagedPersistenceSmoke", isDirectory: true)
        try? FileManager.default.removeItem(at: root)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let appURL = root.appendingPathComponent("data.json")
        let storage = StorageManager(fileURL: appURL)
        for index in 0..<50 {
            var snapshot = AppData.default
            snapshot.titleCustomText = "旧快照-\(index)"
            storage.save(snapshot)
        }
        var finalSnapshot = AppData.default
        finalSnapshot.titleCustomText = "退出时最终快照"
        storage.saveAndWait(finalSnapshot)

        let saved = try JSONDecoder().decode(AppData.self, from: Data(contentsOf: appURL))
        precondition(saved.titleCustomText == "退出时最终快照",
                     "saveAndWait must drain queued writes and persist the final snapshot last")

        let deadlineURL = root.appendingPathComponent("deadlines.json")
        let deadlineStorage = DeadlineStorage(fileURL: deadlineURL)
        let old = DeadlineItem(title: "旧倒数日", targetDate: Date(timeIntervalSince1970: 2_000_000_000))
        let final = DeadlineItem(title: "最终倒数日", targetDate: Date(timeIntervalSince1970: 2_100_000_000))
        deadlineStorage.save([old])
        deadlineStorage.saveAndWait([final])
        let savedDeadlines = try JSONDecoder().decode(
            [DeadlineItem].self,
            from: Data(contentsOf: deadlineURL)
        )
        precondition(savedDeadlines.map(\.title) == ["最终倒数日"],
                     "deadline final save must also drain older queued writes")

        try FileManager.default.removeItem(at: root)
        print("persistence-flush=passed")
    }
}
