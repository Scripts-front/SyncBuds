//
//  ContentView.swift
//  SyncBuds
//

import SwiftUI
import SwiftData
#if os(macOS)
import IOBluetooth
#endif

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var devices: [BluetoothDevice]
    @Environment(MultipeerService.self) private var multipeerService

    // MARK: - State

    @State private var statusMessage: String = "Ready"
    @State private var discoveredDeviceNames: [String] = []

    // MARK: - BluetoothManager (macOS only)

#if os(macOS)
    private let bluetoothManager = BluetoothManager()
    private var selectedDevice: IOBluetoothDevice? {
        // Returns the first paired audio device for spike testing.
        bluetoothManager.pairedAudioDevices().first
    }
#endif

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

#if os(macOS)
            Divider()

            Text("IOBluetooth Spike Controls")
                .font(.headline)

            HStack(spacing: 12) {
                Button("Enumerate Devices") {
                    enumerateDevices()
                }

                Button("Disconnect First Device") {
                    disconnectFirst()
                }

                Button("Connect First Device") {
                    connectFirst()
                }

                Button("Start Monitoring") {
                    bluetoothManager.startMonitoringConnections()
                    statusMessage = "Monitoring started — watch Xcode console for connect/disconnect events"
                }
            }
            .buttonStyle(.bordered)

            if !discoveredDeviceNames.isEmpty {
                Divider()
                Text("Discovered Audio Devices:")
                    .font(.subheadline)
                ForEach(discoveredDeviceNames, id: \.self) { name in
                    Text("• \(name)")
                        .font(.caption)
                }
            }
#endif

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

    // MARK: - Actions (macOS only)

#if os(macOS)
    private func enumerateDevices() {
        let found = bluetoothManager.pairedAudioDevices()
        discoveredDeviceNames = found.map { $0.name ?? $0.addressString ?? "unknown" }
        // Upsert each discovered device into SwiftData registry (BT-03)
        found.forEach { bluetoothManager.upsertToRegistry($0, in: modelContext) }
        statusMessage = found.isEmpty
            ? "No audio devices found — check entitlement or pair a headphone"
            : "Found \(found.count) audio device(s): \(discoveredDeviceNames.joined(separator: ", "))"
    }

    private func disconnectFirst() {
        guard let device = selectedDevice else {
            statusMessage = "No paired audio device found to disconnect"
            return
        }
        statusMessage = "Disconnecting \(device.name ?? "device")... (watch System Settings > Bluetooth)"
        Task {
            let success = await bluetoothManager.disconnectDevice(device)
            await MainActor.run {
                statusMessage = success
                    ? "Disconnected! Verify headphone is gone from System Settings > Bluetooth connected list."
                    : "Disconnect FAILED after 10 attempts. Check Xcode console for details."
            }
        }
    }

    private func connectFirst() {
        guard let device = selectedDevice else {
            statusMessage = "No paired audio device found to connect"
            return
        }
        let name = device.name ?? "device"
        let success = bluetoothManager.connectDevice(device)
        statusMessage = success
            ? "openConnection() succeeded for \(name) — verify audio routes to headphone"
            : "openConnection() failed for \(name) — check Xcode console"
    }
#endif
}

#Preview {
    ContentView()
        .modelContainer(for: BluetoothDevice.self, inMemory: true)
        .environment(MultipeerService())
}
