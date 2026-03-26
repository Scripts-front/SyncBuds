//
//  GlobalHotkeyManager.swift
//  SyncBuds
//

#if os(macOS)
import Carbon
import Foundation

/// Wraps Carbon RegisterEventHotKey for sandbox-compatible global keyboard shortcuts.
/// NSEvent.addGlobalMonitorForEvents is NOT used — it requires Accessibility permission
/// which cannot be granted to sandboxed apps.
final class GlobalHotkeyManager {

    // Static storage for the action — needed for @convention(c) C function bridge
    private static var storedAction: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    init() {}

    deinit {
        unregister()
    }

    /// Register a global hotkey. Call whenever keyCode or modifiers change.
    /// - Parameters:
    ///   - keyCode: Virtual key code (e.g. 49 for Space)
    ///   - modifiers: Carbon modifier flags (e.g. cmdKey | shiftKey)
    ///   - action: Closure invoked when hotkey is pressed
    func register(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        unregister()
        GlobalHotkeyManager.storedAction = action

        // Install event handler with @convention(c) bridging function
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyEventBridge,
            1,
            &eventType,
            nil,
            &eventHandler
        )

        // Register the hotkey
        var hotKeyID = EventHotKeyID(signature: OSType(0x53594E42), id: 1) // 'SYNB'
        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    /// Unregister the current hotkey. Called automatically on re-registration and deinit.
    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }
}

// Top-level @convention(c) bridge — required because Swift closures cannot be passed
// directly as EventHandlerProcPtr (must be a C function pointer).
private let hotkeyEventBridge: EventHandlerProcPtr = { _, _, _ -> OSStatus in
    GlobalHotkeyManager.storedAction?()
    return noErr
}

// MARK: - Notification Name

extension Notification.Name {
    static let hotkeyChanged = Notification.Name("SyncBudsHotkeyChanged")
}

// MARK: - Int Helper

extension Int {
    func nonZeroOr(_ fallback: Int) -> Int { self != 0 ? self : fallback }
}
#endif
