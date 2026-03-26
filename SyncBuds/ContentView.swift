//
//  ContentView.swift
//  SyncBuds
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var devices: [BluetoothDevice]

    var body: some View {
        VStack(spacing: 16) {
            Text("SyncBuds")
                .font(.largeTitle)
                .fontWeight(.bold)

            if devices.isEmpty {
                Text("No Bluetooth devices registered yet.")
                    .foregroundStyle(.secondary)
            } else {
                List(devices) { device in
                    VStack(alignment: .leading) {
                        Text(device.name)
                            .font(.headline)
                        Text(device.addressString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Last seen: \(device.lastSeen.formatted())")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: BluetoothDevice.self, inMemory: true)
}
