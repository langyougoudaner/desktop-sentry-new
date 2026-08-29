import Foundation

/// Transient HUD feedback. Self-clearing after ~1.8s.
@MainActor
final class FeedbackStore: ObservableObject {

    @Published private(set) var hudMessage: String?
    private var clearWorkItem: DispatchWorkItem?

    func show(_ message: String) {
        clearWorkItem?.cancel()
        hudMessage = message
        let work = DispatchWorkItem { [weak self] in self?.hudMessage = nil }
        clearWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: work)
    }

    func clear() {
        clearWorkItem?.cancel()
        hudMessage = nil
    }
}
