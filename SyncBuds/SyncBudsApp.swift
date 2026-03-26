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

    @State private var multipeerService: MultipeerService
    @State private var switchCoordinator: SwitchCoordinator

    #if os(macOS)
    @State private var bluetoothManager: BluetoothManager
    #endif

    init() {
        print("[SyncBudsApp] init — setting up services")

        let multipeer = MultipeerService()
        let coordinator = SwitchCoordinator()

        #if os(macOS)
        let bluetooth = BluetoothManager()

        // Wire coordinator dependencies
        coordinator.bluetoothManager = bluetooth
        coordinator.multipeerService = multipeer
        bluetooth.switchCoordinator = coordinator
        bluetooth.multipeerService = multipeer
        multipeer.switchCoordinator = coordinator

        _bluetoothManager = State(initialValue: bluetooth)
        #else
        coordinator.multipeerService = multipeer
        multipeer.switchCoordinator = coordinator
        #endif

        _multipeerService = State(initialValue: multipeer)
        _switchCoordinator = State(initialValue: coordinator)

        // Start Multipeer discovery
        multipeer.start()

        #if os(macOS)
        bluetooth.startMonitoringConnections()
        #endif

        // Request notification permission
        coordinator.requestNotificationPermission()

        print("[SyncBudsApp] init complete — MultipeerService started")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .environment(multipeerService)
        .environment(switchCoordinator)
    }
}
