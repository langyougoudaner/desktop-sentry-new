import Foundation

/// Pure function: builds the menu-bar title from current domain state.
/// Extracted from the old god-object AppStore so title logic is testable
/// and has a single home.
enum TitleBuilder {

    static func build(tasks: [TaskItem],
                      prompts: [PromptItem],
                      maxChars: Int,
                      emojiEnabled: Bool,
                      customText: String,
                      showTaskCount: Bool) -> String {
        let incomplete = tasks.filter { !$0.isCompleted && $0.deletedAt == nil }
        let completed = tasks.filter { $0.isCompleted && $0.deletedAt == nil }
        let active = tasks.filter { $0.deletedAt == nil }
        let hasTasks = !incomplete.isEmpty

        let baseText: String
        if !customText.isEmpty {
            baseText = customText
        } else if let pinned = prompts.first(where: { $0.isMenuPinned }) {
            baseText = pinned.abbreviation.isEmpty ? pinned.title : pinned.abbreviation
        } else {
            baseText = ""
        }

        var title = ""
        if emojiEnabled {
            if hasTasks { title = "📋 " }
            else if !baseText.isEmpty { title = "🤖 " }
        }

        if !baseText.isEmpty {
            if baseText.count > maxChars {
                title += String(baseText.prefix(maxChars - 3)) + "…"
            } else {
                title += baseText
            }
        }

        if showTaskCount && hasTasks {
            let countStr = "\(completed.count)/\(active.count)"
            title += baseText.isEmpty ? countStr : " " + countStr
        }

        return title.isEmpty ? "📋" : title
    }
}
