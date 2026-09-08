import Foundation
import UserNotifications

enum V5NotificationAuthorizationStatus {
    case notDetermined
    case authorized
    case denied
}

protocol V5TaskNotificationCenter: AnyObject {
    func pendingIdentifiers(completion: @escaping ([String]) -> Void)
    func removePending(identifiers: [String])
    func authorizationStatus(completion: @escaping (V5NotificationAuthorizationStatus) -> Void)
    func requestAuthorization(completion: @escaping (Bool) -> Void)
    func schedule(_ reminders: [V5TaskReminderRequest])
}

private final class SystemV5TaskNotificationCenter: V5TaskNotificationCenter {
    private let center = UNUserNotificationCenter.current()

    func pendingIdentifiers(completion: @escaping ([String]) -> Void) {
        center.getPendingNotificationRequests { requests in
            completion(requests.map(\.identifier))
        }
    }

    func removePending(identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func authorizationStatus(completion: @escaping (V5NotificationAuthorizationStatus) -> Void) {
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined: completion(.notDetermined)
            case .authorized, .provisional, .ephemeral: completion(.authorized)
            default: completion(.denied)
            }
        }
    }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            completion(granted)
        }
    }

    func schedule(_ reminders: [V5TaskReminderRequest]) {
        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = "待办时间到了"
            content.sound = .default
            content.userInfo = ["taskID": reminder.id.uuidString]
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: reminder.dateComponents,
                repeats: false
            )
            center.add(UNNotificationRequest(
                identifier: V5TaskReminderPlanner.identifier(for: reminder.id),
                content: content,
                trigger: trigger
            ))
        }
    }
}

/// Every asynchronous callback carries the generation that created it. Once a
/// newer sync begins, older callbacks cannot remove or recreate notifications.
final class V5TaskNotificationScheduler {
    private let center: V5TaskNotificationCenter
    private let generationLock = NSLock()
    private var generation: UInt64 = 0

    init(center: V5TaskNotificationCenter = SystemV5TaskNotificationCenter()) {
        self.center = center
    }

    func sync(
        _ reminders: [V5TaskReminderRequest],
        requestAuthorizationIfNeeded: Bool
    ) {
        let ticket = nextGeneration()
        center.pendingIdentifiers { [weak self] identifiers in
            guard let self, self.isCurrent(ticket) else { return }
            let ours = identifiers.filter {
                $0.hasPrefix(V5TaskReminderPlanner.identifierPrefix)
            }
            self.center.removePending(identifiers: ours)
            self.center.authorizationStatus { [weak self] status in
                guard let self, self.isCurrent(ticket) else { return }
                switch status {
                case .notDetermined where requestAuthorizationIfNeeded:
                    self.center.requestAuthorization { [weak self] granted in
                        guard let self, granted, self.isCurrent(ticket) else { return }
                        self.center.schedule(reminders)
                    }
                case .authorized:
                    self.center.schedule(reminders)
                case .notDetermined, .denied:
                    break
                }
            }
        }
    }

    private func nextGeneration() -> UInt64 {
        generationLock.lock()
        defer { generationLock.unlock() }
        generation &+= 1
        return generation
    }

    private func isCurrent(_ ticket: UInt64) -> Bool {
        generationLock.lock()
        defer { generationLock.unlock() }
        return generation == ticket
    }
}
