//
//  SyncSignal.swift
//  SyncBuds
//

import Foundation

/// Wire format for all cross-device messages sent via Multipeer Connectivity.
/// Deliberately minimal per D-04: type + sender + timestamp + bluetoothStatus.
/// No device-specific data (MAC addresses, device names) in the signal — those stay in the SwiftData registry.
///
/// COM-02 (CloudKit fallback), COM-03 (SignalRouter), COM-04 (silent push) are deferred — no Developer Account.
/// When a Developer Account exists, add a CloudKit transport that encodes/decodes this same struct.
struct SyncSignal: Codable {

    // MARK: - Types

    /// Discriminates the signal purpose. Extend here when Phase 3 adds switch coordination.
    enum SignalType: String, Codable {
        /// Periodic heartbeat: "I currently have the headphone connected (or not)"
        case status
        /// Imperative request sent by the device that wants to receive the headphone.
        case switchRequest
    }

    /// The platform that sent this signal. Raw values match BluetoothDevice.lastConnectedPlatform convention.
    enum Platform: String, Codable {
        case mac
        case ios
    }

    // MARK: - Fields

    /// What this message communicates.
    let type: SignalType

    /// Which platform sent this signal.
    let sender: Platform

    /// When this signal was created. Signals older than 30 seconds are rejected on receive
    /// to prevent stale delivery after reconnect (Pitfall 6 mitigation).
    let timestamp: Date

    /// Current Bluetooth audio connection state on the sender.
    /// Values: "connected" | "disconnected" | "unknown"
    let bluetoothStatus: String
}

// MARK: - Staleness Check

extension SyncSignal {

    /// Returns true if this signal is fresh enough to act on.
    /// Signals older than 30 seconds are considered stale and must be discarded.
    var isFresh: Bool {
        Date().timeIntervalSince(timestamp) < 30
    }
}
