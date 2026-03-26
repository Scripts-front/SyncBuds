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
        #if os(macOS)
        MenuBarExtra {
            MacMenuView()
                .environment(multipeerService)
                .environment(switchCoordinator)
                .modelContainer(sharedModelContainer)
        } label: {
            Image(systemName: menuBarIconName)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            Text("Settings")  // Placeholder — replaced in Plan 02 (HotkeySettingsView)
                .padding()
        }
        #else
        WindowGroup {
            ContentView()
                .environment(multipeerService)
                .environment(switchCoordinator)
        }
        .modelContainer(sharedModelContainer)
        #endif
    }

    // MARK: - macOS Menu Bar Icon (per D-04)

    #if os(macOS)
    private var menuBarIconName: String {
        if switchCoordinator.switchState == .switching {
            return "arrow.2.circlepath"
        }
        return multipeerService.isConnectedToPeer ? "headphones.circle.fill" : "headphones.circle"
    }
    #endif
}
