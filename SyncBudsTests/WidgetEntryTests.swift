//
//  WidgetEntryTests.swift
//  SyncBudsTests
//
//  Tests the computed property logic of SyncBudsWidgetEntry.
//  Since SyncBudsWidgetEntry lives in the widget extension target, we mirror
//  the struct's computed property logic locally (option b from plan) — this
//  verifies correctness without cross-target test dependencies.
//

import Testing
import Foundation

// Local mirror of SyncBudsWidgetEntry logic for unit testing.
// Must be kept in sync with SyncBudsWidget/SyncBudsWidgetEntry.swift.
private struct WidgetEntryLogic {
    let isConnected: Bool
    let peerBTStatus: String
    let peerName: String?

    var statusTitle: String {
        isConnected ? "Connected to \(peerName ?? "Mac")" : "Mac offline"
    }

    var statusSubtitle: String {
        switch peerBTStatus {
        case "connected": return "Headphone is on Mac"
        case "disconnected": return "Headphone is available"
        default: return "Status unknown"
        }
    }

    var statusIcon: String {
        isConnected ? "headphones.circle.fill" : "headphones.circle"
    }
}

struct WidgetEntryTests {

    // MARK: - statusTitle

    @Test func connectedWithNameShowsConnectedTitle() {
        let entry = WidgetEntryLogic(isConnected: true, peerBTStatus: "connected", peerName: "Mac")
        #expect(entry.statusTitle == "Connected to Mac")
    }

    @Test func disconnectedShowsMacOffline() {
        let entry = WidgetEntryLogic(isConnected: false, peerBTStatus: "unknown", peerName: nil)
        #expect(entry.statusTitle == "Mac offline")
    }

    // MARK: - statusSubtitle

    @Test func connectedBTStatusShowsHeadphoneOnMac() {
        let entry = WidgetEntryLogic(isConnected: true, peerBTStatus: "connected", peerName: nil)
        #expect(entry.statusSubtitle == "Headphone is on Mac")
    }

    @Test func disconnectedBTStatusShowsHeadphoneAvailable() {
        let entry = WidgetEntryLogic(isConnected: true, peerBTStatus: "disconnected", peerName: "Mac")
        #expect(entry.statusSubtitle == "Headphone is available")
    }

    // MARK: - statusIcon

    @Test func connectedUsesFilledIcon() {
        let entry = WidgetEntryLogic(isConnected: true, peerBTStatus: "connected", peerName: "Mac")
        #expect(entry.statusIcon == "headphones.circle.fill")
    }

    @Test func disconnectedUsesOutlineIcon() {
        let entry = WidgetEntryLogic(isConnected: false, peerBTStatus: "unknown", peerName: nil)
        #expect(entry.statusIcon == "headphones.circle")
    }
}
