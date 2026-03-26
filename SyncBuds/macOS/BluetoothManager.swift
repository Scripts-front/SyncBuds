//
//  BluetoothManager.swift
//  SyncBuds
//

#if os(macOS)
import IOBluetooth
import Foundation
import SwiftData

/// Manages Bluetooth audio device enumeration, connection, and disconnection on macOS.
/// Uses IOBluetooth (Classic Bluetooth) — required for A2DP/HFP audio profiles.
/// CoreBluetooth is BLE-only and does NOT enumerate audio headphones.
final class BluetoothManager: NSObject {

    // MARK: - Constants

    /// Audio/Video device major class bitmask (IOBluetooth class of device).
    /// Major class 0x04 maps to 0x000400 in the full CoD bitmask.
    /// Filter: (device.classOfDevice & 0x001F00) == audioMajorClass
    private let audioMajorClass: UInt32 = 0x000400

    /// Maximum number of closeConnection() attempts before giving up.
    private let maxDisconnectAttempts = 10

    /// Delay between closeConnection() retry attempts (500ms).
    private let disconnectRetryDelayMicroseconds: UInt32 = 500_000

    // MARK: - Notifications

    /// Active per-device disconnect notification registrations (retained to stay alive).
    private var disconnectNotifications: [IOBluetoothUserNotification] = []

    /// Weak reference to the shared Multipeer signaling service.
    /// Set by the app after instantiating MultipeerService.
    weak var multipeerService: MultipeerService?

    // MARK: - Enumeration

    /// Returns all paired Bluetooth audio devices (A2DP/HFP headphones and speakers).
    /// Filters by Audio/Video major class — excludes keyboards, mice, phones, etc.
    /// Returns empty array (not nil) if entitlement is missing or no devices are paired.
    func pairedAudioDevices() -> [IOBluetoothDevice] {
        guard let allPaired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            print("[BluetoothManager] pairedDevices() returned nil — check com.apple.security.device.bluetooth entitlement")
            return []
        }
        return allPaired.filter { device in
            (device.classOfDevice & 0x001F00) == audioMajorClass
        }
    }

    // MARK: - SwiftData Registry (BT-03)

    /// Upserts a discovered IOBluetoothDevice into the persistent BluetoothDevice registry.
    /// If a record with the same addressString already exists, updates lastSeen and connectionCount.
    /// If no record exists, inserts a new BluetoothDevice. Call after pairedAudioDevices() or on connect.
    func upsertToRegistry(_ device: IOBluetoothDevice, in context: ModelContext) {
        let address = device.addressString ?? ""
        guard !address.isEmpty else { return }
        let descriptor = FetchDescriptor<BluetoothDevice>(
            predicate: #Predicate { $0.addressString == address }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.lastSeen = Date()
            existing.lastConnectedPlatform = "mac"
            existing.connectionCount += 1
            print("[BluetoothManager] Updated registry for \(existing.name) (connectionCount: \(existing.connectionCount))")
        } else {
            let record = BluetoothDevice(
                name: device.name ?? address,
                addressString: address
            )
            record.lastConnectedPlatform = "mac"
            context.insert(record)
            print("[BluetoothManager] Inserted new registry entry for \(record.name)")
        }
    }

    // MARK: - Connection

    /// Attempts to connect a known Bluetooth device.
    /// openConnection() is a best-effort call — success does not guarantee immediate audio routing.
    /// - Returns: true if openConnection() returned kIOReturnSuccess
    func connectDevice(_ device: IOBluetoothDevice) -> Bool {
        let result = device.openConnection()
        if result == kIOReturnSuccess {
            print("[BluetoothManager] openConnection() succeeded for \(device.name ?? device.addressString ?? "unknown")")
            return true
        } else {
            print("[BluetoothManager] openConnection() failed with IOReturn: \(result)")
            return false
        }
    }

    // MARK: - Disconnection

    /// Disconnects a Bluetooth device using a retry loop.
    ///
    /// A single closeConnection() call often does not complete the disconnect immediately.
    /// This implementation retries up to 10 times with 500ms delays — matching the pattern
    /// used by production tools (lapfelix/BluetoothConnector).
    ///
    /// After closeConnection() succeeds, verify in macOS System Settings > Bluetooth that
    /// the device disappears from the connected list (D-07 acceptance criterion).
    ///
    /// - Returns: true if device.isConnected() returns false after the retry loop
    func disconnectDevice(_ device: IOBluetoothDevice) async -> Bool {
        var attempts = 0

        while attempts < maxDisconnectAttempts && device.isConnected() {
            let result = device.closeConnection()
            if result != kIOReturnSuccess {
                // Non-success return is common even when disconnect eventually completes.
                // Log but continue retrying.
                print("[BluetoothManager] closeConnection() attempt \(attempts + 1) returned IOReturn: \(result) — retrying")
            } else {
                print("[BluetoothManager] closeConnection() attempt \(attempts + 1) returned success")
            }
            usleep(disconnectRetryDelayMicroseconds)
            attempts += 1
        }

        let disconnected = !device.isConnected()
        if disconnected {
            print("[BluetoothManager] Disconnect confirmed after \(attempts) attempt(s): \(device.name ?? device.addressString ?? "unknown")")
        } else {
            print("[BluetoothManager] Disconnect FAILED after \(maxDisconnectAttempts) attempts: \(device.name ?? device.addressString ?? "unknown")")
        }
        return disconnected
    }

    // MARK: - Real-Time State Monitoring

    /// Registers for global Bluetooth connect notifications.
    /// When any device connects, registers for that device's disconnect notification.
    /// Must be called once at app startup. Uses Objective-C selector bridge.
    func startMonitoringConnections() {
        IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(deviceDidConnect(_:device:))
        )
        print("[BluetoothManager] Monitoring started — registered for connect notifications")
    }

    @objc private func deviceDidConnect(
        _ notification: IOBluetoothUserNotification,
        device: IOBluetoothDevice
    ) {
        let name = device.name ?? device.addressString ?? "unknown"
        print("[BluetoothManager] Device connected: \(name)")

        multipeerService?.localBluetoothStatus = "connected"
        let signal = SyncSignal(type: .status, sender: .mac, timestamp: Date(), bluetoothStatus: "connected")
        try? multipeerService?.send(signal)

        // Register for this specific device's disconnect notification.
        // Retain the notification token — releasing it stops the notification.
        if let disconnectToken = device.register(
            forDisconnectNotification: self,
            selector: #selector(deviceDidDisconnect(_:fromDevice:))
        ) {
            disconnectNotifications.append(disconnectToken)
        }
    }

    @objc private func deviceDidDisconnect(
        _ notification: IOBluetoothUserNotification,
        fromDevice device: IOBluetoothDevice
    ) {
        let name = device.name ?? device.addressString ?? "unknown"
        print("[BluetoothManager] Device disconnected: \(name)")

        multipeerService?.localBluetoothStatus = "disconnected"
        let signal = SyncSignal(type: .status, sender: .mac, timestamp: Date(), bluetoothStatus: "disconnected")
        try? multipeerService?.send(signal)

        // Remove the now-fired notification token.
        disconnectNotifications.removeAll { $0 === notification }
    }
}
#endif
