//
//  WidgetStateWriterTests.swift
//  SyncBudsTests
//

import Testing
import Foundation
@testable import SyncBuds

struct WidgetStateWriterTests {

    private let suiteName = WidgetStateWriter.suiteName

    /// Clean up the App Group suite between tests to avoid state bleed.
    private func cleanDefaults() {
        if let store = UserDefaults(suiteName: suiteName) {
            store.removeObject(forKey: "widget_isConnected")
            store.removeObject(forKey: "widget_peerBTStatus")
            store.removeObject(forKey: "widget_peerName")
        }
    }

    @Test func updateWritesIsConnectedTrue() {
        cleanDefaults()
        WidgetStateWriter.update(isConnected: true, peerBTStatus: "connected", peerName: "Mac")

        let store = UserDefaults(suiteName: suiteName)
        #expect(store?.bool(forKey: "widget_isConnected") == true)
    }

    @Test func updateWritesPeerBTStatusConnected() {
        cleanDefaults()
        WidgetStateWriter.update(isConnected: true, peerBTStatus: "connected", peerName: "Mac")

        let store = UserDefaults(suiteName: suiteName)
        #expect(store?.string(forKey: "widget_peerBTStatus") == "connected")
    }

    @Test func updateWritesPeerName() {
        cleanDefaults()
        WidgetStateWriter.update(isConnected: true, peerBTStatus: "connected", peerName: "Mac")

        let store = UserDefaults(suiteName: suiteName)
        #expect(store?.string(forKey: "widget_peerName") == "Mac")
    }

    @Test func updateIsConnectedFalseWritesFalse() {
        cleanDefaults()
        WidgetStateWriter.update(isConnected: false, peerBTStatus: "disconnected", peerName: nil)

        let store = UserDefaults(suiteName: suiteName)
        #expect(store?.bool(forKey: "widget_isConnected") == false)
    }

    @Test func updateNilPeerNameWritesEmptyString() {
        cleanDefaults()
        WidgetStateWriter.update(isConnected: false, peerBTStatus: "disconnected", peerName: nil)

        let store = UserDefaults(suiteName: suiteName)
        #expect(store?.string(forKey: "widget_peerName") == "")
    }

    @Test func updateWritesPeerBTStatusUnknown() {
        cleanDefaults()
        WidgetStateWriter.update(isConnected: false, peerBTStatus: "unknown", peerName: nil)

        let store = UserDefaults(suiteName: suiteName)
        #expect(store?.string(forKey: "widget_peerBTStatus") == "unknown")
    }
}
