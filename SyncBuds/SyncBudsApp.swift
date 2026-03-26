//
//  SyncBudsApp.swift
//  SyncBuds
//
//  Created by Jose Gabiel on 2026/03/25.
//

import SwiftUI
import SwiftData

@main
struct SyncBudsApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            BluetoothDevice.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State private var multipeerService = MultipeerService()
    @State private var switchCoordinator = SwitchCoordinator()

    #if os(macOS)
    @State private var bluetoothManager = BluetoothManager()
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    multipeerService.start()

                    // Wire coordinator dependencies
                    switchCoordinator.multipeerService = multipeerService
                    multipeerService.switchCoordinator = switchCoordinator

                    #if os(macOS)
                    switchCoordinator.bluetoothManager = bluetoothManager
                    bluetoothManager.switchCoordinator = switchCoordinator
                    bluetoothManager.multipeerService = multipeerService
                    bluetoothManager.startMonitoringConnections()
                    #endif

                    // Request notification permission once at startup (SW-04)
                    switchCoordinator.requestNotificationPermission()
                }
        }
        .modelContainer(sharedModelContainer)
        .environment(multipeerService)
        .environment(switchCoordinator)
    }
}
