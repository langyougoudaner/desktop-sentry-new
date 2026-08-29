import Foundation

/// Prompt domain: state + CRUD + pin management.
@MainActor
final class PromptStore: ObservableObject {

    @Published private(set) var prompts: [PromptItem] = []
    @Published private(set) var quickMenuPromptIDs: [UUID] = []

    var onSave: (() -> Void)?

    var pinnedPrompt: PromptItem? { prompts.first { $0.isMenuPinned } }

    var quickMenuPrompts: [PromptItem] {
        quickMenuPromptIDs.compactMap { id in prompts.first { $0.id == id } }
    }

    // MARK: - Load

    func setPrompts(_ prompts: [PromptItem], quickMenuPromptIDs: [UUID]) {
        self.prompts = prompts.sorted(by: { $0.sortOrder < $1.sortOrder })
        let validIDs = Set(prompts.map(\.id))
        var seenIDs = Set<UUID>()
        self.quickMenuPromptIDs = Array(
            quickMenuPromptIDs
                .filter { validIDs.contains($0) && seenIDs.insert($0).inserted }
                .prefix(6)
        )
    }

    // MARK: - Mutations

    func addPrompt() {
        let nextOrder = (prompts.map(\.sortOrder).max() ?? -1) + 1
        prompts.append(PromptItem(title: "新提示词", content: "", abbreviation: "",
                                  isMenuPinned: false, group: "", sortOrder: nextOrder))
        onSave?()
    }

    func updateTitle(id: UUID, title: String) {
        guard let i = prompts.firstIndex(where: { $0.id == id }) else { return }
        prompts[i].title = title; onSave?()
    }

    func updateAbbreviation(id: UUID, abbreviation: String) {
        guard let i = prompts.firstIndex(where: { $0.id == id }) else { return }
        prompts[i].abbreviation = abbreviation; onSave?()
    }

    func updateContent(id: UUID, content: String) {
        guard let i = prompts.firstIndex(where: { $0.id == id }) else { return }
        prompts[i].content = content; onSave?()
    }

    func updateGroup(id: UUID, group: String) {
        guard let i = prompts.firstIndex(where: { $0.id == id }) else { return }
        prompts[i].group = group; onSave?()
    }

    func deletePrompt(_ prompt: PromptItem) {
        prompts.removeAll { $0.id == prompt.id }
        quickMenuPromptIDs.removeAll { $0 == prompt.id }
        onSave?()
    }

    func movePrompt(from source: IndexSet, to destination: Int) {
        prompts.move(fromOffsets: source, toOffset: destination)
        for i in prompts.indices { prompts[i].sortOrder = i }
        onSave?()
    }

    // MARK: - Pin

    func setPinnedPrompt(id: UUID) {
        for i in prompts.indices { prompts[i].isMenuPinned = (prompts[i].id == id) }
        onSave?()
    }

    func clearPinnedPrompt() {
        for i in prompts.indices { prompts[i].isMenuPinned = false }
        onSave?()
    }

    func togglePinPrompt(_ prompt: PromptItem) {
        for i in prompts.indices {
            prompts[i].isMenuPinned = (prompts[i].id == prompt.id) ? !prompts[i].isMenuPinned : false
        }
        onSave?()
    }

    func cyclePinnedPrompt() {
        guard !prompts.isEmpty else { return }
        if let idx = prompts.firstIndex(where: { $0.isMenuPinned }) {
            prompts[idx].isMenuPinned = false
            prompts[(idx + 1) % prompts.count].isMenuPinned = true
        } else {
            prompts[0].isMenuPinned = true
        }
        onSave?()
    }

    // MARK: - Right-click quick menu

    func isQuickMenuPrompt(_ prompt: PromptItem) -> Bool {
        quickMenuPromptIDs.contains(prompt.id)
    }

    func setQuickMenuPrompt(id: UUID, enabled: Bool) {
        if enabled {
            guard quickMenuPromptIDs.count < 6,
                  prompts.contains(where: { $0.id == id }),
                  !quickMenuPromptIDs.contains(id) else { return }
            quickMenuPromptIDs.append(id)
        } else {
            quickMenuPromptIDs.removeAll { $0 == id }
        }
        onSave?()
    }

    func moveQuickMenuPrompt(id: UUID, offset: Int) {
        guard let source = quickMenuPromptIDs.firstIndex(of: id) else { return }
        let destination = source + offset
        guard quickMenuPromptIDs.indices.contains(destination) else { return }
        quickMenuPromptIDs.swapAt(source, destination)
        onSave?()
    }
}
