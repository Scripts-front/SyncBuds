//
//  ContentView.swift
//  SyncBuds
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var devices: [BluetoothDevice]
    @Environment(MultipeerService.self) private var multipeerService
    @Environment(SwitchCoordinator.self) private var switchCoordinator

    // MARK: - State

    @State private var statusMessage: String = "Ready"

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SyncBuds")
                .font(.title2)
                .fontWeight(.bold)

            Text(statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            Text("Peer Status")
                .font(.headline)

            if multipeerService.isConnectedToPeer {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text("Connected to \(multipeerService.connectedPeerName ?? "peer")")
                            .font(.caption)
                    }
                    let ownerText: String = {
                        switch multipeerService.peerBluetoothStatus {
                        case "connected":
                            return "Headphone is on \(multipeerService.connectedPeerName ?? "peer")"
                        case "disconnected":
                            return "Headphone is available"
                        default:
                            return "Headphone status unknown"
                        }
                    }()
                    Text(ownerText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack {
                    Image(systemName: "circle.fill")
                        .foregroundStyle(.gray)
                        .font(.caption)
                    Text("Peer offline (open app on other device)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            Text("Switching")
                .font(.headline)

            let switchLabel: String = {
                switch switchCoordinator.switchState {
                case .idle:
                    return "Switch Headphone"
                case .switching:
                    return "Switching..."
                case .cooldown:
                    return "Cooldown (reconnect suppressed)"
                case .error(let msg):
                    return "Error: \(msg)"
                }
            }()

            let switchDisabled: Bool = {
                if case .idle = switchCoordinator.switchState { return false }
                return true
            }()

            Button(switchLabel) {
                Task { switchCoordinator.requestSwitch() }
            }
            .buttonStyle(.bordered)
            .disabled(switchDisabled)

            Text(switchLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Text("SwiftData Device Registry (\(devices.count) saved)")
                .font(.subheadline)

            if devices.isEmpty {
                Text("No devices saved yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(devices) { device in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(device.name).font(.caption).bold()
                            Text(device.addressString).font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if device.isActiveDevice {
                            Text("ACTIVE").font(.caption2).foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 480)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: BluetoothDevice.self, inMemory: true)
        .environment(MultipeerService())
        .environment(SwitchCoordinator())
}
