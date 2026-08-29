import Foundation
import UserNotifications

/// Owns only Desktop Sentry's one-shot local notifications.
final class DeadlineNotificationScheduler: NSObject, UNUserNotificationCenterDelegate {
    static let identifierPrefix = "com.desktopsentry.deadline."

    private let center = UNUserNotificationCenter.current()
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    var onOpenDeadline: ((UUID) -> Void)?

    override init() {
        super.init()
        center.delegate = self
        refreshAuthorizationStatus()
    }

    func refreshAuthorizationStatus() {
        center.getNotificationSettings { [weak self] settings in
            self?.authorizationStatus = settings.authorizationStatus
        }
    }

    func sync(deadlines: [DeadlineItem], requestAuthorizationIfNeeded: Bool) {
        let active = deadlines.filter { $0.status == .active && $0.notificationEnabled }
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            let ours = requests.map(\.identifier).filter { $0.hasPrefix(Self.identifierPrefix) }
            self.center.removePendingNotificationRequests(withIdentifiers: ours)
            self.center.getNotificationSettings { settings in
                self.authorizationStatus = settings.authorizationStatus
                if settings.authorizationStatus == .notDetermined && requestAuthorizationIfNeeded {
                    self.center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                        self.authorizationStatus = granted ? .authorized : .denied
                        if granted { self.schedule(active) }
                    }
                } else if settings.authorizationStatus == .authorized {
                    self.schedule(active)
                }
            }
        }
    }

    func cancel(id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier(for: id)])
        center.removeDeliveredNotifications(withIdentifiers: [Self.identifier(for: id)])
    }

    func notificationIdentifier(for id: UUID) -> String {
        Self.identifier(for: id)
    }

    private func schedule(_ deadlines: [DeadlineItem]) {
        let calendar = Calendar.autoupdatingCurrent
        let now = Date()
        for deadline in deadlines {
            guard let hour = deadline.notificationHour,
                  let minute = deadline.notificationMinute else { continue }
            let day = calendar.startOfDay(for: deadline.targetDate)
            guard let fireDate = calendar.date(bySettingHour: hour, minute: minute,
                                               second: 0, of: day),
                  fireDate > now else { continue }
            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = hour
            components.minute = minute
            let content = UNMutableNotificationContent()
            content.title = deadline.title
            content.body = "Deadline 到期：\(shortDate(day))"
            content.sound = .default
            content.userInfo = ["deadlineID": deadline.id.uuidString]
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: Self.identifier(for: deadline.id),
                                                content: content, trigger: trigger)
            center.add(request)
        }
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }

    static func identifier(for id: UUID) -> String {
        identifierPrefix + id.uuidString
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let id = (response.notification.request.content.userInfo["deadlineID"] as? String)
            .flatMap(UUID.init(uuidString:))
        if let id { DispatchQueue.main.async { [weak self] in self?.onOpenDeadline?(id) } }
        completionHandler()
    }
}
