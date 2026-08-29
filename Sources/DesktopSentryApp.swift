import SwiftUI
import AppKit

@main
struct DesktopSentryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Empty Settings scene. The real settings UI is the custom panel owned
        // by AppCoordinator — this avoids the old double-entry bug where both
        // a Settings{} scene and a custom panel could show SettingsView.
        Settings { EmptyView() }
    }
}

// MARK: - AppDelegate (thin shell — all work delegated to AppCoordinator)

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let coordinator = AppCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        coordinator.start()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        coordinator.openSearch()
        return true
    }
}
