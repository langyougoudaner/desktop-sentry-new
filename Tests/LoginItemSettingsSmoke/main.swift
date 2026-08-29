import Foundation

private enum FixtureError: Error {
    case registrationRejected
}

@MainActor
private final class FakeLoginItemService: LoginItemServicing {
    var status: LoginItemSystemStatus
    var registerError: Error?
    var unregisterError: Error?
    private(set) var registerCallCount = 0
    private(set) var unregisterCallCount = 0

    init(status: LoginItemSystemStatus) {
        self.status = status
    }

    func register() throws {
        registerCallCount += 1
        if let registerError { throw registerError }
        status = .enabled
    }

    func unregister() throws {
        unregisterCallCount += 1
        if let unregisterError { throw unregisterError }
        status = .notRegistered
    }
}

@main
struct LoginItemSettingsSmoke {
    @MainActor
    static func main() {
        let service = FakeLoginItemService(status: .notRegistered)
        let store = SettingsStore(loginItemService: service)

        precondition(!store.launchAtLogin)
        precondition(store.loginItemState == .disabled)
        precondition(store.loginItemState.title == "未启用")
        precondition(store.loginItemState.symbolName == "circle")
        precondition(!store.loginItemState.shouldOfferSystemSettings)

        store.setLaunchAtLogin(true)
        precondition(service.registerCallCount == 1)
        precondition(store.launchAtLogin)
        precondition(store.loginItemState == .enabled)
        precondition(store.loginItemMessage == nil)

        service.status = .requiresApproval
        store.refreshLoginItemStatus()
        precondition(!store.launchAtLogin)
        precondition(store.loginItemState == .requiresApproval)
        precondition(store.loginItemState.title == "等待系统允许")
        precondition(store.loginItemState.shouldOfferSystemSettings)

        service.status = .notRegistered
        service.registerError = FixtureError.registrationRejected
        store.setLaunchAtLogin(true)
        precondition(!store.launchAtLogin, "failed registration must not show a false enabled state")
        precondition(store.loginItemState == .disabled)
        precondition(store.loginItemMessage?.contains("无法开启") == true)

        service.registerError = nil
        service.status = .enabled
        store.refreshLoginItemStatus()
        store.setLaunchAtLogin(false)
        precondition(service.unregisterCallCount == 1)
        precondition(!store.launchAtLogin)
        precondition(store.loginItemState == .disabled)

        print("login-item-settings=passed")
        print("login-item-real-status=passed")
        print("login-item-error-feedback=passed")
    }
}
