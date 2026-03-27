//
//  SwitchIntentTests.swift
//  SyncBudsTests
//
//  Tests that SwitchIntentBridge.requestSwitch() posts the widgetSwitchRequested
//  notification to NotificationCenter.default.
//

import Testing
import Foundation

struct SwitchIntentTests {

    @Test func intentBridgePostsNotification() async {
        var received = false
        let token = NotificationCenter.default.addObserver(
            forName: .widgetSwitchRequested,
            object: nil,
            queue: nil
        ) { _ in received = true }
        SwitchIntentBridge.requestSwitch()
        NotificationCenter.default.removeObserver(token)
        #expect(received)
    }
}
