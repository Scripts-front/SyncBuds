//
//  AutoSwitchTests.swift
//  SyncBudsTests
//
//  Tests the boolean guard logic for the auto-switch scenePhase hook.
//  scenePhase cannot be injected in unit tests, so these tests verify
//  the guard conditions in isolation as pure logic.
//

import Testing
import Foundation

struct AutoSwitchTests {

    // MARK: - Helper: replicates the guard chain in SyncBudsApp.onChange(of: scenePhase)

    /// Returns true if the auto-switch conditions are satisfied (would call requestSwitch).
    private func shouldAutoSwitch(autoSwitchEnabled: Bool, peerBluetoothStatus: String) -> Bool {
        guard autoSwitchEnabled else { return false }
        guard peerBluetoothStatus == "connected" else { return false }
        return true
    }

    // MARK: - Tests

    @Test func autoSwitchDisabledPreventsSwitch() {
        let result = shouldAutoSwitch(autoSwitchEnabled: false, peerBluetoothStatus: "connected")
        #expect(result == false)
    }

    @Test func peerDisconnectedPreventsSwitch() {
        let result = shouldAutoSwitch(autoSwitchEnabled: true, peerBluetoothStatus: "disconnected")
        #expect(result == false)
    }

    @Test func peerUnknownStatusPreventsSwitch() {
        let result = shouldAutoSwitch(autoSwitchEnabled: true, peerBluetoothStatus: "unknown")
        #expect(result == false)
    }

    @Test func bothConditionsMetAllowsSwitch() {
        let result = shouldAutoSwitch(autoSwitchEnabled: true, peerBluetoothStatus: "connected")
        #expect(result == true)
    }

    @Test func autoSwitchDisabledWithUnknownStatusPreventsSwitch() {
        let result = shouldAutoSwitch(autoSwitchEnabled: false, peerBluetoothStatus: "unknown")
        #expect(result == false)
    }
}
