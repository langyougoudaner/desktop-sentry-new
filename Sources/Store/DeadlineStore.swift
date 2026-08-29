import Foundation
import Combine

enum DeadlineListFilter: String, CaseIterable, Hashable {
    case upcoming
    case overdue
    case completed
    case archived

    var title: String {
        switch self {
        case .upcoming: return "即将到来"
        case .overdue: return "已到期"
        case .completed: return "已完成"
        case .archived: return "已归档"
        }
    }
}

enum DeadlineValidationError: LocalizedError, Equatable {
    case emptyTitle
    case notificationTimeRequired
    case invalidNotificationTime

    var errorDescription: String? {
        switch self {
        case .emptyTitle: return "请输入截止日标题。"
        case .notificationTimeRequired: return "开启通知时，请明确选择提醒时间。"
        case .invalidNotificationTime: return "提醒时间无效，请重新选择。"
        }
    }
}

/// Deadline state and derived list rules. All mutations run on the main actor;
/// persistence is deliberately delegated to DeadlineStorage.
@MainActor
final class DeadlineStore: ObservableObject {
    @Published private(set) var deadlines: [DeadlineItem] = []
    @Published private(set) var focusedDeadlineID: UUID?
    @Published private(set) var referenceDay: Date

    var onSave: (() -> Void)?
    var onScheduleChanged: (() -> Void)?

    private let calendar: Calendar
    private let nowProvider: () -> Date

    init(calendar: Calendar = Calendar.autoupdatingCurrent, nowProvider: @escaping () -> Date = Date.init) {
        self.calendar = calendar
        self.nowProvider = nowProvider
        self.referenceDay = calendar.startOfDay(for: nowProvider())
    }

    var activeDeadlines: [DeadlineItem] {
        deadlines.filter { $0.status == .active }
    }

    var completedDeadlines: [DeadlineItem] {
        deadlines.filter { $0.status == .completed }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var archivedDeadlines: [DeadlineItem] {
        deadlines.filter { $0.status == .archived }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var upcomingDeadlines: [DeadlineItem] {
        activeDeadlines.filter { DeadlineCalendar.dayState(for: $0.targetDate, now: nowProvider(), calendar: calendar) != .overdue(0) }
            .filter { DeadlineCalendar.dayStart($0.targetDate, calendar: calendar) >= referenceDay }
            .sorted { DeadlineCalendar.sortKey($0, calendar: calendar) < DeadlineCalendar.sortKey($1, calendar: calendar) }
    }

    var overdueDeadlines: [DeadlineItem] {
        activeDeadlines.filter { DeadlineCalendar.dayStart($0.targetDate, calendar: calendar) < referenceDay }
            .sorted { DeadlineCalendar.sortKey($0, calendar: calendar) < DeadlineCalendar.sortKey($1, calendar: calendar) }
    }

    var focusedDeadline: DeadlineItem? {
        guard let focusedDeadlineID else { return nil }
        return activeDeadlines.first { $0.id == focusedDeadlineID }
    }

    func setDeadlines(_ values: [DeadlineItem], focusedID: UUID? = nil) {
        deadlines = values.map { DeadlineCalendar.normalize($0, calendar: calendar) }
        if let focusedID, activeDeadlines.contains(where: { $0.id == focusedID }) {
            focusedDeadlineID = focusedID
        } else {
            focusedDeadlineID = nil
            ensureFocus()
        }
    }

    func refreshReferenceDay() {
        let newDay = calendar.startOfDay(for: nowProvider())
        guard newDay != referenceDay else { return }
        referenceDay = newDay
        ensureFocus()
    }

    func state(for deadline: DeadlineItem) -> DeadlineDayState {
        DeadlineCalendar.dayState(for: deadline.targetDate, now: nowProvider(), calendar: calendar)
    }

    func list(for filter: DeadlineListFilter, selectedDate: Date? = nil) -> [DeadlineItem] {
        if let selectedDate {
            let day = calendar.startOfDay(for: selectedDate)
            return deadlines.filter {
                $0.status == .active && calendar.startOfDay(for: $0.targetDate) == day
            }.sorted { DeadlineCalendar.sortKey($0, calendar: calendar) < DeadlineCalendar.sortKey($1, calendar: calendar) }
        }
        switch filter {
        case .upcoming: return upcomingDeadlines
        case .overdue: return overdueDeadlines
        case .completed: return completedDeadlines
        case .archived: return archivedDeadlines
        }
    }

    func count(on date: Date) -> Int {
        let day = calendar.startOfDay(for: date)
        return deadlines.filter { $0.status == .active && calendar.startOfDay(for: $0.targetDate) == day }.count
    }

    @discardableResult
    func add(title: String, targetDate: Date, notificationEnabled: Bool,
             notificationHour: Int? = nil, notificationMinute: Int? = nil) -> Result<DeadlineItem, DeadlineValidationError> {
        let now = nowProvider()
        let validation = validate(title: title, notificationEnabled: notificationEnabled,
                                  notificationHour: notificationHour, notificationMinute: notificationMinute)
        guard validation == nil else { return .failure(validation!) }
        let item = DeadlineItem(title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                                targetDate: calendar.startOfDay(for: targetDate),
                                notificationEnabled: notificationEnabled,
                                notificationHour: notificationHour,
                                notificationMinute: notificationMinute,
                                createdAt: now, updatedAt: now)
        deadlines.append(item)
        ensureFocus()
        onSave?()
        onScheduleChanged?()
        return .success(item)
    }

    @discardableResult
    func update(id: UUID, title: String, targetDate: Date, notificationEnabled: Bool,
                notificationHour: Int? = nil, notificationMinute: Int? = nil) -> Result<DeadlineItem, DeadlineValidationError> {
        let validation = validate(title: title, notificationEnabled: notificationEnabled,
                                  notificationHour: notificationHour, notificationMinute: notificationMinute)
        guard validation == nil else { return .failure(validation!) }
        guard let index = deadlines.firstIndex(where: { $0.id == id }) else { return .failure(.emptyTitle) }
        deadlines[index].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        deadlines[index].targetDate = calendar.startOfDay(for: targetDate)
        deadlines[index].notificationEnabled = notificationEnabled
        deadlines[index].notificationHour = notificationHour
        deadlines[index].notificationMinute = notificationMinute
        deadlines[index].updatedAt = nowProvider()
        let item = deadlines[index]
        onSave?()
        onScheduleChanged?()
        return .success(item)
    }

    func setFocus(id: UUID?) {
        guard let id else {
            focusedDeadlineID = nil
            ensureFocus()
            onSave?()
            return
        }
        guard activeDeadlines.contains(where: { $0.id == id }) else { return }
        focusedDeadlineID = id
        onSave?()
    }

    func markCompleted(id: UUID) {
        guard let index = deadlines.firstIndex(where: { $0.id == id }), deadlines[index].status == .active else { return }
        deadlines[index].status = .completed
        deadlines[index].updatedAt = nowProvider()
        ensureFocus()
        onSave?()
        onScheduleChanged?()
    }

    func archive(id: UUID) {
        guard let index = deadlines.firstIndex(where: { $0.id == id }), deadlines[index].status != .archived else { return }
        deadlines[index].status = .archived
        deadlines[index].updatedAt = nowProvider()
        ensureFocus()
        onSave?()
        onScheduleChanged?()
    }

    func restore(id: UUID) {
        guard let index = deadlines.firstIndex(where: { $0.id == id }), deadlines[index].status == .archived else { return }
        deadlines[index].status = .active
        deadlines[index].updatedAt = nowProvider()
        ensureFocus()
        onSave?()
        onScheduleChanged?()
    }

    /// The caller owns confirmation UI; this method is intentionally irreversible.
    func permanentlyDelete(id: UUID) {
        guard let index = deadlines.firstIndex(where: { $0.id == id }) else { return }
        deadlines.remove(at: index)
        if focusedDeadlineID == id { focusedDeadlineID = nil; ensureFocus() }
        onSave?()
        onScheduleChanged?()
    }

    private func validate(title: String, notificationEnabled: Bool,
                          notificationHour: Int?, notificationMinute: Int?) -> DeadlineValidationError? {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .emptyTitle }
        guard notificationEnabled else { return nil }
        guard let hour = notificationHour, let minute = notificationMinute else { return .notificationTimeRequired }
        guard (0...23).contains(hour), (0...59).contains(minute) else { return .invalidNotificationTime }
        return nil
    }

    private func ensureFocus() {
        if let focusedDeadlineID, activeDeadlines.contains(where: { $0.id == focusedDeadlineID }) { return }
        let candidates = activeDeadlines.sorted {
            DeadlineCalendar.sortKey($0, calendar: calendar) < DeadlineCalendar.sortKey($1, calendar: calendar)
        }
        focusedDeadlineID = candidates.first?.id
    }
}
