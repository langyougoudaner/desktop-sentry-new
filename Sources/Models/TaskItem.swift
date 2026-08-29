import Foundation

// MARK: - TaskPriority

enum TaskPriority: String, Codable, CaseIterable {
    case low = "低"
    case medium = "中"
    case high = "高"

    var symbol: String {
        switch self {
        case .high: return "🔴"
        case .medium: return "🟡"
        case .low: return "🟢"
        }
    }
}

// MARK: - TaskItem

struct TaskItem: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var createdAt: Date
    var priority: TaskPriority
    var tag: String
    var skillName: String?
    var deletedAt: Date?

    init(id: UUID = UUID(), title: String, isCompleted: Bool = false,
         createdAt: Date = Date(), priority: TaskPriority = .medium,
         tag: String = "", skillName: String? = nil, deletedAt: Date? = nil) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.priority = priority
        self.tag = tag
        self.skillName = skillName
        self.deletedAt = deletedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        isCompleted = try c.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        priority = try c.decodeIfPresent(TaskPriority.self, forKey: .priority) ?? .medium
        tag = try c.decodeIfPresent(String.self, forKey: .tag) ?? ""
        skillName = try c.decodeIfPresent(String.self, forKey: .skillName)
        deletedAt = try c.decodeIfPresent(Date.self, forKey: .deletedAt)
    }
}

// MARK: - PromptItem

struct PromptItem: Codable, Identifiable, Hashable {
    var id: UUID
    var title: String
    var content: String
    var abbreviation: String
    var isMenuPinned: Bool
    var group: String
    var sortOrder: Int

    init(id: UUID = UUID(), title: String, content: String,
         abbreviation: String = "", isMenuPinned: Bool = false,
         group: String = "", sortOrder: Int = 0) {
        self.id = id
        self.title = title
        self.content = content
        self.abbreviation = abbreviation
        self.isMenuPinned = isMenuPinned
        self.group = group
        self.sortOrder = sortOrder
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        content = try c.decode(String.self, forKey: .content)
        abbreviation = try c.decodeIfPresent(String.self, forKey: .abbreviation) ?? ""
        isMenuPinned = try c.decodeIfPresent(Bool.self, forKey: .isMenuPinned) ?? false
        group = try c.decodeIfPresent(String.self, forKey: .group) ?? ""
        sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
    }
}

// MARK: - CopyHistoryEntry

struct CopyHistoryEntry: Codable, Identifiable, Hashable {
    var id: UUID
    var promptTitle: String
    var promptContent: String
    var copiedAt: Date

    init(id: UUID = UUID(), promptTitle: String, promptContent: String, copiedAt: Date = Date()) {
        self.id = id
        self.promptTitle = promptTitle
        self.promptContent = promptContent
        self.copiedAt = copiedAt
    }
}
