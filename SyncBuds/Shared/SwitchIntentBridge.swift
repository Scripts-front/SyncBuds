//
//  SwitchIntentBridge.swift
//  SyncBuds
//

import Foundation

extension Notification.Name {
    static let widgetSwitchRequested = Notification.Name("widgetSwitchRequested")
}

/// NotificationCenter bridge from SwitchHeadphoneIntent (runs in app process via ForegroundContinuableIntent)
/// to SwitchCoordinator (owned by SyncBudsApp). Mirrors the existing hotkeyChanged notification pattern.
enum SwitchIntentBridge {
    static func requestSwitch() {
        NotificationCenter.default.post(name: .widgetSwitchRequested, object: nil)
        print("[SwitchIntentBridge] Posted widgetSwitchRequested notification")
    }
}
