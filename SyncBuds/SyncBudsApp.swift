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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    multipeerService.start()
                }
        }
        .modelContainer(sharedModelContainer)
        .environment(multipeerService)
    }
}
