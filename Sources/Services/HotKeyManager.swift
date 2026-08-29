import Carbon
import Foundation

/// System-wide hotkeys via Carbon RegisterEventHotKey.
/// No Accessibility permission needed. Handlers are injected as closures
/// so this class stays decoupled from the coordinator.
@MainActor
final class HotKeyManager {

    nonisolated(unsafe) private static var shared: HotKeyManager?

    private var handlers: [UInt32: () -> Void] = [:]
    private var nextId: UInt32 = 1
    private var refs: [EventHotKeyRef] = []

    init(onSearch: @escaping () -> Void,
         onQuickAdd: @escaping () -> Void,
         onCyclePinned: @escaping () -> Void) {
        HotKeyManager.shared = self
        installEventHandler()

        register(keyCode: 0x23, modifiers: UInt32(cmdKey | shiftKey), handler: onSearch)      // ⌘⇧P
        register(keyCode: 0x2D, modifiers: UInt32(cmdKey | shiftKey), handler: onCyclePinned) // ⌘⇧N
        register(keyCode: 0x11, modifiers: UInt32(cmdKey | shiftKey), handler: onQuickAdd)    // ⌘⇧T
    }

    private func installEventHandler() {
        var spec = EventTypeSpec(
            eventClass: OSType(0x6B657962),   // 'keyb'
            eventKind: UInt32(7)               // kEventHotKeyPressed
        )

        let callback: @convention(c) (EventHandlerCallRef?, EventRef?, UnsafeMutableRawPointer?) -> OSStatus = { _, event, _ in
            guard let event = event else { return noErr }
            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event,
                0x2D2D2D2D,  // '----'
                0x686B6964,  // 'hkid'
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            let capturedId = hotKeyID.id
            DispatchQueue.main.async {
                HotKeyManager.shared?.handlers[capturedId]?()
            }
            return noErr
        }

        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &spec, nil, nil)
    }

    private func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        let id = nextId
        nextId += 1
        handlers[id] = handler

        let hotKeyID = EventHotKeyID(signature: OSType(0x44535453), id: id) // 'DSTS'
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref = ref {
            refs.append(ref)
        } else {
            NSLog("[HotKeyManager] register failed (keyCode=%d): %d", keyCode, status)
        }
    }
}
