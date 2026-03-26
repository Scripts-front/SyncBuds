//
//  WidgetStateWriter.swift
//  SyncBuds
//

import Foundation
#if os(iOS)
import WidgetKit
#endif

/// Writes shared state to the App Group UserDefaults suite so the widget extension can read it.
/// Must be called from the main app process only (not from the widget extension).
/// All keys are prefixed with "widget_" to avoid collision with @AppStorage keys (Pitfall 6 mitigation).
struct WidgetStateWriter {
    static let suiteName = "group.com.syncbuds.shared"
    private static var defaults: UserDefaults? { UserDefaults(suiteName: suiteName) }

    /// Writes current peer connection state to App Group and requests widget timeline reload.
    static func update(isConnected: Bool, peerBTStatus: String, peerName: String?) {
        guard let store = defaults else {
            print("[WidgetStateWriter] App Group unavailable — skipping widget state update")
            return
        }
        store.set(isConnected, forKey: "widget_isConnected")
        store.set(peerBTStatus, forKey: "widget_peerBTStatus")
        store.set(peerName ?? "", forKey: "widget_peerName")
        #if os(iOS)
        WidgetCenter.shared.reloadTimelines(ofKind: "SyncBudsWidget")
        #endif
        print("[WidgetStateWriter] Updated — isConnected: \(isConnected), peerBTStatus: \(peerBTStatus)")
    }
}
