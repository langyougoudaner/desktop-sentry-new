import Foundation
import AppKit

/// Clipboard write + sound + copy history. Depends on the prompt/settings
/// stores but owns the history list itself.
@MainActor
final class ClipboardService: ObservableObject {

    private let promptStore: PromptStore
    private let settings: SettingsStore
    private let feedback: FeedbackStore

    @Published private(set) var copyHistory: [CopyHistoryEntry] = []

    var onSave: (() -> Void)?

    init(promptStore: PromptStore, settings: SettingsStore, feedback: FeedbackStore) {
        self.promptStore = promptStore
        self.settings = settings
        self.feedback = feedback
    }

    func setHistory(_ history: [CopyHistoryEntry]) {
        copyHistory = history
    }

    // MARK: - Copy

    func copyPrompt(_ prompt: PromptItem) {
        write(prompt.content, label: prompt.title)

        if settings.autoSwitchOnCopy {
            promptStore.setPinnedPrompt(id: prompt.id)
        }

        record(title: prompt.title, content: prompt.content)
    }

    func copyPinned() {
        guard let pinned = promptStore.pinnedPrompt else { return }
        copyPrompt(pinned)
    }

    func copyFromHistory(_ entry: CopyHistoryEntry) {
        write(entry.promptContent, label: entry.promptTitle)
    }

    func clearHistory() {
        copyHistory = []; onSave?()
    }

    func copySkillName(_ skill: SkillItem) {
        write(skill.callToken, label: skill.callToken)
        record(title: skill.callToken, content: skill.callToken)
    }

    func copySkillInvocation(_ skill: SkillItem, task: String? = nil) {
        let invocation = skill.invocation(task: task)
        write(invocation, label: skill.callToken)
        record(title: skill.callToken, content: invocation)
    }

    // MARK: - Core write

    private func write(_ text: String, label: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)

        if settings.soundEnabled {
            let name = settings.soundEffectName
            DispatchQueue.global(qos: .userInitiated).async {
                if let s = NSSound(named: name) { s.play() }
                else if let s = NSSound(named: "Pop") { s.play() }
                else { NSSound.beep() }
            }
        }
        feedback.show("「\(label)」已就绪")
    }

    private func record(title: String, content: String) {
        copyHistory.insert(CopyHistoryEntry(promptTitle: title, promptContent: content), at: 0)
        if copyHistory.count > 10 { copyHistory = Array(copyHistory.prefix(10)) }
        onSave?()
    }
}
