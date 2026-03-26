//
//  HotkeySettingsView.swift
//  SyncBuds
//

#if os(macOS)
import SwiftUI
import Carbon

struct HotkeySettingsView: View {
    @AppStorage("hotkeyKeyCode") private var hotkeyKeyCode: Int = 49       // Space
    @AppStorage("hotkeyModifiers") private var hotkeyModifiers: Int = 768   // ⌘⇧

    @State private var isRecording: Bool = false

    var body: some View {
        Form {
            Section("Global Keyboard Shortcut") {
                HStack {
                    Text("Switch Headphone")
                    Spacer()
                    KeyRecorderButton(
                        label: isRecording ? "Press any key..." : shortcutDisplayString,
                        isRecording: isRecording
                    ) { keyCode, modifiers in
                        hotkeyKeyCode = keyCode
                        hotkeyModifiers = modifiers
                        isRecording = false
                        postHotkeyChangedNotification()
                    } onActivate: {
                        isRecording = true
                    }
                }
                Text("Click the button above, then press your desired shortcut.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Default: \u{2318}\u{21E7}Space")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Reset to Default") {
                    hotkeyKeyCode = 49    // Space
                    hotkeyModifiers = 768 // ⌘⇧
                    postHotkeyChangedNotification()
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 380, minHeight: 160)
        .padding()
        .onChange(of: hotkeyKeyCode) { _, _ in postHotkeyChangedNotification() }
        .onChange(of: hotkeyModifiers) { _, _ in postHotkeyChangedNotification() }
    }

    private var shortcutDisplayString: String {
        var parts: [String] = []
        let mods = UInt32(hotkeyModifiers)
        if mods & UInt32(cmdKey) != 0 { parts.append("\u{2318}") }
        if mods & UInt32(shiftKey) != 0 { parts.append("\u{21E7}") }
        if mods & UInt32(optionKey) != 0 { parts.append("\u{2325}") }
        if mods & UInt32(controlKey) != 0 { parts.append("\u{2303}") }
        switch hotkeyKeyCode {
        case 49: parts.append("Space")
        case 36: parts.append("Return")
        case 53: parts.append("Escape")
        default: parts.append("Key(\(hotkeyKeyCode))")
        }
        return parts.joined()
    }

    private func postHotkeyChangedNotification() {
        NotificationCenter.default.post(name: .hotkeyChanged, object: nil)
    }
}

// MARK: - Key Recorder Button

/// NSViewRepresentable wrapping an NSTextField subclass that overrides keyDown(with:)
/// to capture the next key press. Used when the user clicks "Press any key...".
private struct KeyRecorderButton: NSViewRepresentable {
    let label: String
    let isRecording: Bool
    let onRecord: (_ keyCode: Int, _ modifiers: Int) -> Void
    let onActivate: () -> Void

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(title: label, target: context.coordinator, action: #selector(Coordinator.buttonTapped(_:)))
        button.bezelStyle = .rounded
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        nsView.title = label
        context.coordinator.onRecord = onRecord
        context.coordinator.onActivate = onActivate
        context.coordinator.isRecording = isRecording
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onRecord: onRecord, onActivate: onActivate, isRecording: isRecording)
    }

    final class Coordinator: NSObject {
        var onRecord: (_ keyCode: Int, _ modifiers: Int) -> Void
        var onActivate: () -> Void
        var isRecording: Bool
        private var monitor: Any?

        init(onRecord: @escaping (_ keyCode: Int, _ modifiers: Int) -> Void,
             onActivate: @escaping () -> Void,
             isRecording: Bool) {
            self.onRecord = onRecord
            self.onActivate = onActivate
            self.isRecording = isRecording
        }

        @objc func buttonTapped(_ sender: NSButton) {
            guard !isRecording else { return }
            onActivate()

            // Install a local key monitor to capture the next key press
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.isRecording else { return event }
                let keyCode = Int(event.keyCode)
                let carbonMods = event.modifierFlags.carbonFlags
                self.onRecord(keyCode, Int(carbonMods))
                if let monitor = self.monitor {
                    NSEvent.removeMonitor(monitor)
                    self.monitor = nil
                }
                return nil // consume the event
            }
        }
    }
}

// MARK: - NSEvent.ModifierFlags → Carbon conversion

private extension NSEvent.ModifierFlags {
    var carbonFlags: UInt32 {
        var flags: UInt32 = 0
        if contains(.command) { flags |= UInt32(cmdKey) }
        if contains(.shift)   { flags |= UInt32(shiftKey) }
        if contains(.option)  { flags |= UInt32(optionKey) }
        if contains(.control) { flags |= UInt32(controlKey) }
        return flags
    }
}
#endif
