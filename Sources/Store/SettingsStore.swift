import Foundation
import Combine
import ServiceManagement

enum LoginItemSystemStatus: Equatable {
    case notRegistered
    case enabled
    case requiresApproval
    case unavailable
}

enum LoginItemState: Equatable {
    case disabled
    case enabled
    case requiresApproval
    case unavailable

    var title: String {
        switch self {
        case .disabled: return "未启用"
        case .enabled: return "已启用"
        case .requiresApproval: return "等待系统允许"
        case .unavailable: return "当前不可用"
        }
    }

    var symbolName: String {
        switch self {
        case .disabled: return "circle"
        case .enabled: return "checkmark.circle.fill"
        case .requiresApproval: return "exclamationmark.circle.fill"
        case .unavailable: return "xmark.circle.fill"
        }
    }

    var shouldOfferSystemSettings: Bool {
        self == .requiresApproval || self == .unavailable
    }
}

@MainActor
protocol LoginItemServicing {
    var status: LoginItemSystemStatus { get }
    func register() throws
    func unregister() throws
}

@MainActor
private struct SystemLoginItemService: LoginItemServicing {
    var status: LoginItemSystemStatus {
        switch SMAppService.mainApp.status {
        case .notRegistered: return .notRegistered
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        case .notFound: return .unavailable
        @unknown default: return .unavailable
        }
    }

    func register() throws { try SMAppService.mainApp.register() }
    func unregister() throws { try SMAppService.mainApp.unregister() }
}

/// App-level preferences. Each setter clamps/validates and triggers save.
@MainActor
final class SettingsStore: ObservableObject {

    @Published var maxMenuBarChars: Int = 15
    @Published var soundEnabled: Bool = true
    @Published var soundEffectName: String = "Pop"
    @Published private(set) var launchAtLogin: Bool = false
    @Published private(set) var loginItemState: LoginItemState = .disabled
    @Published private(set) var loginItemMessage: String?
    @Published var autoSwitchOnCopy: Bool = true
    @Published var titleEmojiEnabled: Bool = true
    @Published var titleCustomText: String = ""
    @Published var titleShowTaskCount: Bool = true

    var onSave: (() -> Void)?

    private let loginItemService: any LoginItemServicing

    init() {
        self.loginItemService = SystemLoginItemService()
        refreshLoginItemStatus()
    }

    init(loginItemService: any LoginItemServicing) {
        self.loginItemService = loginItemService
        refreshLoginItemStatus()
    }

    // MARK: - Load

    func apply(_ data: AppData) {
        maxMenuBarChars = data.clampedMaxChars
        soundEnabled = data.soundEnabled
        soundEffectName = data.soundEffectName
        // The persisted value is only legacy intent. macOS is authoritative:
        // a stale JSON flag must never make the UI claim that startup is on.
        refreshLoginItemStatus()
        autoSwitchOnCopy = data.autoSwitchOnCopy
        titleEmojiEnabled = data.titleEmojiEnabled
        titleCustomText = data.titleCustomText
        titleShowTaskCount = data.titleShowTaskCount
    }

    // MARK: - Setters

    func setMaxMenuBarChars(_ value: Int) {
        maxMenuBarChars = min(25, max(10, value)); onSave?()
    }

    func setSoundEnabled(_ value: Bool) { soundEnabled = value; onSave?() }
    func setSoundEffectName(_ value: String) { soundEffectName = value; onSave?() }

    func setLaunchAtLogin(_ value: Bool) {
        do {
            if value { try loginItemService.register() }
            else { try loginItemService.unregister() }
            refreshLoginItemStatus()
            if value, loginItemState == .requiresApproval {
                loginItemMessage = "macOS 需要你在系统设置的登录项中允许 Desktop Sentry。"
            } else if launchAtLogin != value {
                loginItemMessage = value
                    ? "系统尚未启用开机自动启动，请打开登录项设置确认。"
                    : "系统尚未关闭开机自动启动，请打开登录项设置确认。"
            }
        } catch {
            refreshLoginItemStatus()
            loginItemMessage = value
                ? "无法开启开机自动启动：\(error.localizedDescription)"
                : "无法关闭开机自动启动：\(error.localizedDescription)"
        }
        onSave?()
    }

    func refreshLoginItemStatus() {
        switch loginItemService.status {
        case .notRegistered:
            launchAtLogin = false
            loginItemState = .disabled
        case .enabled:
            launchAtLogin = true
            loginItemState = .enabled
        case .requiresApproval:
            launchAtLogin = false
            loginItemState = .requiresApproval
        case .unavailable:
            launchAtLogin = false
            loginItemState = .unavailable
        }
        loginItemMessage = nil
    }

    func setAutoSwitchOnCopy(_ value: Bool) { autoSwitchOnCopy = value; onSave?() }
    func setTitleEmojiEnabled(_ value: Bool) { titleEmojiEnabled = value; onSave?() }
    func setTitleCustomText(_ value: String) { titleCustomText = value; onSave?() }
    func setTitleShowTaskCount(_ value: Bool) { titleShowTaskCount = value; onSave?() }
}

// MARK: - System sound library

extension SettingsStore {
    /// macOS system alert sounds available in /System/Library/Sounds.
    static let systemSoundNames: [String] = {
        let dir = URL(fileURLWithPath: "/System/Library/Sounds")
        let urls = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        let scanned = urls
            .map { $0.deletingPathExtension().lastPathComponent }
            .filter { !$0.isEmpty }
            .sorted()
        return scanned.isEmpty
            ? ["Pop", "Glass", "Heroine", "Submarine", "Tink", "Ping", "Blow", "Bottle", "Frog", "Funk", "Morse", "Purr", "Sosumi", "Basso"]
            : scanned
    }()
}
