//
//  SyncBudsWidgetProvider.swift
//  SyncBudsWidget
//

import WidgetKit

struct SyncBudsWidgetProvider: TimelineProvider {
    private static let suiteName = "group.com.syncbuds.shared"

    func placeholder(in context: Context) -> SyncBudsWidgetEntry {
        SyncBudsWidgetEntry(date: Date(), isConnected: false, peerBTStatus: "unknown", peerName: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SyncBudsWidgetEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SyncBudsWidgetEntry>) -> Void) {
        let store = UserDefaults(suiteName: Self.suiteName)
        let isConnected = store?.bool(forKey: "widget_isConnected") ?? false
        let btStatus = store?.string(forKey: "widget_peerBTStatus") ?? "unknown"
        let peerName = store?.string(forKey: "widget_peerName")
        let entry = SyncBudsWidgetEntry(
            date: Date(),
            isConnected: isConnected,
            peerBTStatus: btStatus,
            peerName: peerName.flatMap { $0.isEmpty ? nil : $0 }
        )
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}
