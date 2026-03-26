//
//  BluetoothDevice.swift
//  SyncBuds
//

import Foundation
import SwiftData

/// Persisted record of a known Bluetooth audio headphone.
/// One record per device (keyed by addressString). Only one device has isActiveDevice == true at a time.
@Model
final class BluetoothDevice {

    // MARK: - Required fields (D-08)

    /// Human-readable device name from IOBluetoothDevice.name / AVAudioSession route port name
    var name: String

    /// MAC address string in "XX:XX:XX:XX:XX:XX" format — stable unique identifier across renames
    var addressString: String

    /// Most recent time this device was seen connected on any platform
    var lastSeen: Date

    /// Platform that last had this device connected: "mac" | "ios" | "unknown"
    var lastConnectedPlatform: String

    // MARK: - Switching logic fields (Claude's Discretion per CONTEXT.md)

    /// True for the one device currently designated for switching. Only one BluetoothDevice has this true at a time. (D-09, D-10)
    var isActiveDevice: Bool

    /// Time this device was first discovered — useful for display ordering
    var firstSeenDate: Date

    /// Total number of times this device has been seen connected — supports "most used" selection heuristic
    var connectionCount: Int

    // MARK: - Init

    init(name: String, addressString: String) {
        self.name = name
        self.addressString = addressString
        self.lastSeen = Date()
        self.lastConnectedPlatform = "unknown"
        self.isActiveDevice = false
        self.firstSeenDate = Date()
        self.connectionCount = 0
    }
}
