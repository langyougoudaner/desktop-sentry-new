import Foundation

private final class FakeNotificationCenter: V5TaskNotificationCenter {
    var pendingCallbacks: [([String]) -> Void] = []
    var settingsCallbacks: [(V5NotificationAuthorizationStatus) -> Void] = []
    var removed: [[String]] = []
    var scheduled: [[V5TaskReminderRequest]] = []

    func pendingIdentifiers(completion: @escaping ([String]) -> Void) {
        pendingCallbacks.append(completion)
    }

    func removePending(identifiers: [String]) { removed.append(identifiers) }

    func authorizationStatus(
        completion: @escaping (V5NotificationAuthorizationStatus) -> Void
    ) {
        settingsCallbacks.append(completion)
    }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        completion(true)
    }

    func schedule(_ reminders: [V5TaskReminderRequest]) { scheduled.append(reminders) }
}

@main
struct V5TaskNotificationSchedulerSmoke {
    static func main() {
        let center = FakeNotificationCenter()
        let scheduler = V5TaskNotificationScheduler(center: center)
        let oldID = UUID(uuidString: "00000000-0000-0000-0000-000000000071")!
        let oldReminder = V5TaskReminderRequest(
            id: oldID,
            title: "不应复活",
            fireDate: Date(timeIntervalSince1970: 2_000_000_000),
            dateComponents: DateComponents(year: 2033, month: 5, day: 18, hour: 3)
        )

        scheduler.sync([oldReminder], requestAuthorizationIfNeeded: false)
        scheduler.sync([], requestAuthorizationIfNeeded: false)
        precondition(center.pendingCallbacks.count == 2)

        center.pendingCallbacks[1]([V5TaskReminderPlanner.identifier(for: oldID)])
        precondition(center.settingsCallbacks.count == 1)
        center.settingsCallbacks[0](.authorized)
        precondition(center.scheduled == [[]],
                     "the latest cancel-all request must be the only committed schedule")

        center.pendingCallbacks[0]([])
        precondition(center.settingsCallbacks.count == 1,
                     "a late callback from an older sync must stop before reading settings")
        precondition(center.scheduled == [[]],
                     "a late callback must never resurrect an old reminder")

        print("v5-task-notification-scheduler=passed")
    }
}
