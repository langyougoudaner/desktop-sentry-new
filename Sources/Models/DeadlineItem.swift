import Foundation

// MARK: - DeadlineStatus

enum DeadlineStatus: String, Codable, CaseIterable, Hashable {
    case active
    case completed
    case archived
}

// MARK: - DeadlineItem

/// A local-date deadline independent from the legacy TaskItem data model.
/// `targetDate` is normalized to the start of the day in the current calendar.
struct DeadlineItem: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String
    var targetDate: Date
    var notificationEnabled: Bool
    var notificationHour: Int?
    var notificationMinute: Int?
    var status: DeadlineStatus
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), title: String, targetDate: Date,
         notificationEnabled: Bool = false, notificationHour: Int? = nil,
         notificationMinute: Int? = nil, status: DeadlineStatus = .active,
         createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.targetDate = targetDate
        self.notificationEnabled = notificationEnabled
        self.notificationHour = notificationHour
        self.notificationMinute = notificationMinute
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var hasNotificationTime: Bool {
        notificationHour != nil && notificationMinute != nil
    }

    var notificationDateComponents: DateComponents? {
        guard let hour = notificationHour, let minute = notificationMinute else { return nil }
        return DateComponents(hour: hour, minute: minute)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        targetDate = try c.decode(Date.self, forKey: .targetDate)
        notificationEnabled = try c.decodeIfPresent(Bool.self, forKey: .notificationEnabled) ?? false
        notificationHour = try c.decodeIfPresent(Int.self, forKey: .notificationHour)
        notificationMinute = try c.decodeIfPresent(Int.self, forKey: .notificationMinute)
        status = try c.decodeIfPresent(DeadlineStatus.self, forKey: .status) ?? .active
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? targetDate
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }
}

// MARK: - Natural-day calculations

enum DeadlineDayState: Equatable, Hashable {
    case today
    case upcoming(Int)
    case overdue(Int)

    var label: String {
        switch self {
        case .today: return "今天"
        case .upcoming(let days): return "\(days)天"
        case .overdue(let days): return "已到期\(days)天"
        }
    }
}

enum DeadlineCalendar {
    static func localCalendar() -> Calendar { Calendar.autoupdatingCurrent }

    static func dayStart(_ date: Date, calendar: Calendar = localCalendar()) -> Date {
        calendar.startOfDay(for: date)
    }

    static func normalize(_ deadline: DeadlineItem,
                          calendar: Calendar = localCalendar()) -> DeadlineItem {
        var result = deadline
        result.targetDate = dayStart(deadline.targetDate, calendar: calendar)
        if let hour = result.notificationHour, !(0...23).contains(hour) { result.notificationHour = nil }
        if let minute = result.notificationMinute, !(0...59).contains(minute) { result.notificationMinute = nil }
        if result.notificationHour == nil || result.notificationMinute == nil {
            result.notificationHour = nil
            result.notificationMinute = nil
        }
        return result
    }

    static func dayState(for targetDate: Date, now: Date = Date(),
                         calendar: Calendar = localCalendar()) -> DeadlineDayState {
        let target = dayStart(targetDate, calendar: calendar)
        let today = dayStart(now, calendar: calendar)
        let difference = calendar.dateComponents([.day], from: today, to: target).day ?? 0
        if difference == 0 { return .today }
        if difference > 0 { return .upcoming(difference) }
        return .overdue(abs(difference))
    }

    static func sortKey(_ deadline: DeadlineItem, calendar: Calendar = localCalendar()) -> Date {
        guard let hour = deadline.notificationHour,
              let minute = deadline.notificationMinute else {
            return dayStart(deadline.targetDate, calendar: calendar)
        }
        return calendar.date(bySettingHour: hour, minute: minute, second: 0,
                             of: dayStart(deadline.targetDate, calendar: calendar))
            ?? dayStart(deadline.targetDate, calendar: calendar)
    }
}

/// In-memory-only fixtures used by the visual correction checkpoint. The
/// application loads these only when launched with `--deadline-preview` and
/// disables all Deadline persistence and notification scheduling in that mode.
enum DeadlinePreviewSamples {
    static func make(now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> [DeadlineItem] {
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let inThreeDays = calendar.date(byAdding: .day, value: 3, to: today) ?? today
        let inFiveDays = calendar.date(byAdding: .day, value: 5, to: today) ?? today
        return [
            DeadlineItem(title: "今天提交演示稿", targetDate: today),
            DeadlineItem(title: "明日客户评审", targetDate: tomorrow,
                         notificationEnabled: true, notificationHour: 9, notificationMinute: 30),
            DeadlineItem(title: "已逾期的预算确认", targetDate: yesterday),
            DeadlineItem(title: "周会材料已完成", targetDate: inThreeDays,
                         status: .completed),
            DeadlineItem(title: "下周发布窗口", targetDate: inFiveDays)
        ]
    }
}
