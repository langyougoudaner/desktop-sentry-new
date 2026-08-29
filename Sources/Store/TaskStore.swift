import Foundation

/// Task domain: state + CRUD + derived data.
///
/// Derived collections (incompleteTasks, completedTasks, …) live HERE and
/// only here — views read them directly instead of re-filtering `tasks` in
/// every view, which was the old single-source-of-truth violation.
@MainActor
final class TaskStore: ObservableObject {

    @Published private(set) var tasks: [TaskItem] = []

    /// Set by AppCoordinator; called after any mutation so saves are debounced
    /// centrally. Weak-style closure avoids a retain cycle.
    var onSave: (() -> Void)?

    // MARK: - Derived data (single source of truth)

    var incompleteTasks: [TaskItem] { tasks.filter { !$0.isCompleted && $0.deletedAt == nil } }
    var completedTasks: [TaskItem] { tasks.filter { $0.isCompleted && $0.deletedAt == nil } }
    var activeTasks: [TaskItem] { tasks.filter { $0.deletedAt == nil } }
    var trashedTasks: [TaskItem] { tasks.filter { $0.deletedAt != nil } }

    var incompleteCount: Int { incompleteTasks.count }
    var completedCount: Int { completedTasks.count }
    var activeCount: Int { activeTasks.count }

    // MARK: - Load

    func setTasks(_ tasks: [TaskItem]) {
        self.tasks = tasks
        autoClearOldTrash()
    }

    // MARK: - Mutations

    func addTask(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        tasks.append(TaskItem(title: trimmed))
        onSave?()
    }

    func toggleTask(_ task: TaskItem) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].isCompleted.toggle()
        onSave?()
    }

    func deleteTask(_ task: TaskItem) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        if tasks[idx].deletedAt != nil {
            tasks.remove(at: idx)          // already trashed → permanent delete
        } else {
            tasks[idx].deletedAt = Date()  // soft delete
        }
        onSave?()
    }

    func clearCompletedTasks() {
        let now = Date()
        for i in tasks.indices where tasks[i].isCompleted && tasks[i].deletedAt == nil {
            tasks[i].deletedAt = now
        }
        onSave?()
    }

    func restoreTask(_ task: TaskItem) {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[idx].deletedAt = nil
        onSave?()
    }

    func emptyTrash() {
        tasks.removeAll { $0.deletedAt != nil }
        onSave?()
    }

    func setTaskPriority(id: UUID, priority: TaskPriority) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[idx].priority = priority
        onSave?()
    }

    func setTaskSkill(id: UUID, skillName: String?) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[idx].skillName = skillName
        onSave?()
    }

    /// Permanently delete tasks trashed more than 30 days ago.
    private func autoClearOldTrash() {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 3600)
        let before = tasks.count
        tasks.removeAll { $0.deletedAt != nil && $0.deletedAt! < cutoff }
        if tasks.count != before { onSave?() }
    }
}
