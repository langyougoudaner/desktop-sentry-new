import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
    exit(1)
}

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fail(message) }
}

func waitOnMain(_ semaphore: DispatchSemaphore, timeout: TimeInterval = 3) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if semaphore.wait(timeout: .now()) == .success { return true }
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
    }
    return false
}

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(secondsFromGMT: 0)!
let now = calendar.date(from: DateComponents(calendar: calendar, year: 2026, month: 8, day: 21, hour: 15))!
let today = calendar.startOfDay(for: now)
let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

require(DeadlineCalendar.dayState(for: today, now: now, calendar: calendar) == .today, "今天计算错误")
require(DeadlineCalendar.dayState(for: tomorrow, now: now, calendar: calendar) == .upcoming(1), "未来一天计算错误")
require(DeadlineCalendar.dayState(for: yesterday, now: now, calendar: calendar) == .overdue(1), "逾期一天计算错误")

let firstID = UUID()
let secondID = UUID()
let thirdID = UUID()
let first = DeadlineItem(id: firstID, title: "明日交付", targetDate: tomorrow,
                         notificationEnabled: true, notificationHour: 9, notificationMinute: 30,
                         createdAt: now, updatedAt: now)
let second = DeadlineItem(id: secondID, title: "今日评审", targetDate: today,
                          createdAt: now.addingTimeInterval(10), updatedAt: now.addingTimeInterval(10))
let third = DeadlineItem(id: thirdID, title: "昨日复盘", targetDate: yesterday,
                         createdAt: now.addingTimeInterval(20), updatedAt: now.addingTimeInterval(20))

let encoded = try! JSONEncoder().encode([first, second, third])
let decoded = try! JSONDecoder().decode([DeadlineItem].self, from: encoded)
require(decoded == [first, second, third], "Deadline JSON round-trip 失败")

let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("DesktopSentryDeadlineSmoke-\(UUID().uuidString)", isDirectory: true)
try! FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: root) }
let storageURL = root.appendingPathComponent("deadlines.json")
let storage = DeadlineStorage(fileURL: storageURL)
storage.save([first, second, third])
Thread.sleep(forTimeInterval: 0.15)
let loadedSemaphore = DispatchSemaphore(value: 0)
var loaded: [DeadlineItem] = []
storage.load { values in
    loaded = values
    loadedSemaphore.signal()
}
require(waitOnMain(loadedSemaphore), "DeadlineStorage load 超时")
require(loaded == [first, second, third], "DeadlineStorage round-trip 失败")

try! Data("{ definitely-not-json".utf8).write(to: storageURL)
let corruptSemaphore = DispatchSemaphore(value: 0)
var recovered: [DeadlineItem] = []
storage.load { values in
    recovered = values
    corruptSemaphore.signal()
}
require(waitOnMain(corruptSemaphore), "损坏文件恢复超时")
require(recovered.isEmpty, "损坏文件没有安全回退为空集合")
let backups = try! FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)
    .filter { $0.lastPathComponent.hasPrefix("deadlines.corrupt.") }
require(!backups.isEmpty, "损坏 Deadline 文件未保留恢复副本")

let main = DispatchSemaphore(value: 0)
Task { @MainActor in
    let store = DeadlineStore(calendar: calendar, nowProvider: { now })
    store.setDeadlines([first, second, third])
    require(store.upcomingDeadlines.map(\.id) == [secondID, firstID], "即将到来排序错误")
    require(store.overdueDeadlines.map(\.id) == [thirdID], "已到期排序错误")
    require(store.focusedDeadlineID == thirdID, "首次重点选择错误")
    store.markCompleted(id: thirdID)
    require(store.focusedDeadlineID == secondID, "重点项完成后未自动接续")
    let invalid = store.add(title: "", targetDate: today, notificationEnabled: false)
    require(invalid == .failure(.emptyTitle), "空标题没有被拒绝")
    let missingTime = store.add(title: "需要时间", targetDate: today, notificationEnabled: true)
    require(missingTime == .failure(.notificationTimeRequired), "通知缺少明确时间时没有被拒绝")
    let accepted = store.add(title: "有时间提醒", targetDate: tomorrow, notificationEnabled: true,
                             notificationHour: 18, notificationMinute: 0)
    require({ if case .success = accepted { return true }; return false }(), "有效 Deadline 未创建")
    main.signal()
}
require(waitOnMain(main), "DeadlineStore 测试超时")
let notificationID = DeadlineNotificationScheduler.identifier(for: firstID)
require(notificationID == DeadlineNotificationScheduler.identifierPrefix + firstID.uuidString,
        "通知 ID 不稳定或未使用 Desktop Sentry 命名空间")
print("deadline-model=passed")
print("deadline-storage=passed")
print("deadline-store=passed")
print("deadline-notification-id=passed")
