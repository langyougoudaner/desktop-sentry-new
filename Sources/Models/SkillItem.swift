import Foundation

struct SkillItem: Codable, Identifiable, Hashable, Sendable {
    var name: String
    var summary: String
    var category: String
    var sourcePaths: [String]
    var isFavorite: Bool

    var id: String { normalizedName }

    var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "$"))
            .lowercased()
    }

    var callToken: String { "$\(normalizedName)" }

    var displaySummary: String {
        let compact = summary
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard compact.count > 150 else { return compact }
        return String(compact.prefix(147)) + "..."
    }

    func invocation(task: String? = nil) -> String {
        let trimmed = task?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            return "使用 \(callToken) 帮我完成以下任务："
        }
        return "使用 \(callToken) 完成以下任务：\(trimmed)"
    }
}

enum SkillCategories {
    static let all = [
        "思考与决策", "调研与网页", "内容与写作", "编程与调试", "图片与设计",
        "视频与音频", "文档与办公", "笔记与学习", "设备与自动化", "财经与市场", "未分类"
    ]

    static func inferred(for name: String, summary: String) -> String {
        let text = "\(name) \(summary)".lowercased()
        let rules: [(String, [String])] = [
            ("财经与市场", ["finance", "financial", "market", "stock", "crypto", "bitcoin", "财经", "金融", "投资", "黄金"]),
            ("视频与音频", ["video", "audio", "music", "speech", "tts", "whisper", "视频", "音频", "音乐", "配音", "转录"]),
            ("图片与设计", ["image", "design", "diagram", "visual", "svg", "photo", "图片", "图像", "设计", "绘图", "海报"]),
            ("文档与办公", ["document", "pdf", "spreadsheet", "excel", "powerpoint", "slide", "office", "文档", "表格", "幻灯片", "办公"]),
            ("笔记与学习", ["note", "learning", "study", "obsidian", "knowledge", "笔记", "学习", "课程", "知识"]),
            ("设备与自动化", ["apple", "device", "automation", "smart-home", "homekit", "macos", "设备", "自动化", "提醒事项"]),
            ("编程与调试", ["code", "coding", "github", "debug", "test", "developer", "api", "代码", "编程", "调试", "测试", "开发"]),
            ("调研与网页", ["research", "search", "browser", "web", "crawl", "scrape", "网页", "搜索", "调研", "检索", "浏览器"]),
            ("内容与写作", ["writing", "copywriting", "content", "blog", "humanizer", "write", "写作", "文案", "内容", "文章", "公众号"]),
            ("思考与决策", ["decision", "think", "analysis", "analyze", "strategy", "plan", "决策", "思考", "分析", "诊断", "规划"])
        ]
        return rules.first(where: { _, keywords in keywords.contains(where: text.contains) })?.0 ?? "未分类"
    }
}

enum SkillDefaults {
    static var directories: [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/.codex/skills",
            "\(home)/.hermes/skills",
            "\(home)/.agents/skills",
            "\(home)/.hermes/workspace/.agents/skills",
            "\(home)/.codex/plugins/cache"
        ].filter { FileManager.default.fileExists(atPath: $0) }
    }
}
