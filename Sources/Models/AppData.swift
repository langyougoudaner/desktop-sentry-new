import Foundation

/// On-disk persistence shape. Decoded defensively so a missing or partial
/// JSON key never crashes the app — every field falls back to a default.
struct AppData: Codable {
    var tasks: [TaskItem]
    var prompts: [PromptItem]
    var maxMenuBarChars: Int
    var soundEnabled: Bool
    var soundEffectName: String
    var launchAtLogin: Bool
    var autoSwitchOnCopy: Bool
    var titleEmojiEnabled: Bool
    var titleCustomText: String
    var titleShowTaskCount: Bool
    var quickMenuPromptIDs: [UUID]
    var copyHistory: [CopyHistoryEntry]
    var skills: [SkillItem]
    var skillDirectories: [String]
    var skillLastScanDate: Date?

    var clampedMaxChars: Int { min(25, max(10, maxMenuBarChars)) }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tasks = try c.decodeIfPresent([TaskItem].self, forKey: .tasks) ?? []
        prompts = try c.decodeIfPresent([PromptItem].self, forKey: .prompts) ?? []
        maxMenuBarChars = try c.decodeIfPresent(Int.self, forKey: .maxMenuBarChars) ?? 15
        soundEnabled = try c.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? true
        soundEffectName = try c.decodeIfPresent(String.self, forKey: .soundEffectName) ?? "Pop"
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        autoSwitchOnCopy = try c.decodeIfPresent(Bool.self, forKey: .autoSwitchOnCopy) ?? true
        titleEmojiEnabled = try c.decodeIfPresent(Bool.self, forKey: .titleEmojiEnabled) ?? true
        titleCustomText = try c.decodeIfPresent(String.self, forKey: .titleCustomText) ?? ""
        titleShowTaskCount = try c.decodeIfPresent(Bool.self, forKey: .titleShowTaskCount) ?? true
        quickMenuPromptIDs = try c.decodeIfPresent([UUID].self, forKey: .quickMenuPromptIDs)
            ?? Array(prompts.prefix(6).map(\.id))
        copyHistory = try c.decodeIfPresent([CopyHistoryEntry].self, forKey: .copyHistory) ?? []
        skills = try c.decodeIfPresent([SkillItem].self, forKey: .skills) ?? []
        skillDirectories = try c.decodeIfPresent([String].self, forKey: .skillDirectories) ?? SkillDefaults.directories
        skillLastScanDate = try c.decodeIfPresent(Date.self, forKey: .skillLastScanDate)
    }

    init(tasks: [TaskItem], prompts: [PromptItem], maxMenuBarChars: Int,
         soundEnabled: Bool, soundEffectName: String = "Pop", launchAtLogin: Bool, autoSwitchOnCopy: Bool,
         titleEmojiEnabled: Bool = true, titleCustomText: String = "",
         titleShowTaskCount: Bool = true, quickMenuPromptIDs: [UUID] = [],
         copyHistory: [CopyHistoryEntry] = [], skills: [SkillItem] = [],
         skillDirectories: [String] = SkillDefaults.directories,
         skillLastScanDate: Date? = nil) {
        self.tasks = tasks
        self.prompts = prompts
        self.maxMenuBarChars = maxMenuBarChars
        self.soundEnabled = soundEnabled
        self.soundEffectName = soundEffectName
        self.launchAtLogin = launchAtLogin
        self.autoSwitchOnCopy = autoSwitchOnCopy
        self.titleEmojiEnabled = titleEmojiEnabled
        self.titleCustomText = titleCustomText
        self.titleShowTaskCount = titleShowTaskCount
        self.quickMenuPromptIDs = quickMenuPromptIDs
        self.copyHistory = copyHistory
        self.skills = skills
        self.skillDirectories = skillDirectories
        self.skillLastScanDate = skillLastScanDate
    }

    static var `default`: AppData {
        AppData(
            tasks: [], prompts: [],
            maxMenuBarChars: 15, soundEnabled: true, soundEffectName: "Pop",
            launchAtLogin: false, autoSwitchOnCopy: true,
            titleEmojiEnabled: true, titleCustomText: "",
            titleShowTaskCount: true,
            quickMenuPromptIDs: [],
            copyHistory: [], skills: [],
            skillDirectories: SkillDefaults.directories,
            skillLastScanDate: nil
        )
    }
}
