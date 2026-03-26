//
//  MacMenuView.swift
//  SyncBuds
//

#if os(macOS)
import SwiftUI

struct MacMenuView: View {
    @Environment(MultipeerService.self) private var multipeerService
    @Environment(SwitchCoordinator.self) private var switchCoordinator

    var body: some View {
        // Peer status (Text renders as greyed-out, non-interactive label)
        if multipeerService.isConnectedToPeer {
            Text("Connected to \(multipeerService.connectedPeerName ?? "peer")")
        } else {
            Text("Peer offline")
        }

        // Headphone ownership status
        Text(headphoneStatusText)

        Divider()

        // Switch action — only interactive element (per D-03)
        Button(switchLabel) {
            Task { switchCoordinator.requestSwitch() }
        }
        .disabled(switchDisabled)

        Divider()

        // Settings opener — required for keyboard shortcut configuration (UI-03)
        Button("Settings...") {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }

        // Quit — MANDATORY because LSUIElement removes Dock icon (no other quit path)
        Button("Quit SyncBuds") {
            NSApp.terminate(nil)
        }
    }

    // MARK: - Computed labels

    private var headphoneStatusText: String {
        switch multipeerService.peerBluetoothStatus {
        case "connected":
            return "Headphone: on \(multipeerService.connectedPeerName ?? "peer")"
        case "disconnected":
            return "Headphone: available"
        default:
            return "Headphone: unknown"
        }
    }

    private var switchLabel: String {
        switch switchCoordinator.switchState {
        case .idle:
            return "Switch Headphone"
        case .switching:
            return "Switching..."
        case .cooldown:
            return "Cooldown active"
        case .error(let msg):
            return "Error: \(msg)"
        }
    }

    private var switchDisabled: Bool {
        if case .idle = switchCoordinator.switchState { return false }
        return true
    }
}
#endif
