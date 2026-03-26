//
//  SwitchCoordinator.swift
//  SyncBuds
//

import Foundation
import UserNotifications

/// Orchestrates bidirectional Bluetooth headphone switching between Mac and iPhone.
/// Owns the switch state machine and coordinates BluetoothManager (macOS) and MultipeerService (both).
///
/// State machine:
///   idle → switching → cooldown → idle        (Mac→iPhone success path)
///   idle → switching → idle                    (iPhone→Mac success path, after confirmation)
///   any → error → idle                         (any failure path)
///
/// Thread safety: all state mutations run on the main thread (callers must ensure this).
@Observable final class SwitchCoordinator {

    // MARK: - State

    enum SwitchState: Equatable {
        case idle
        case switching
        case cooldown
        case error(String)

        static func == (lhs: SwitchState, rhs: SwitchState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.switching, .switching), (.cooldown, .cooldown):
                return true
            case (.error(let a), .error(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    // MARK: - Observable State

    private(set) var switchState: SwitchState = .idle

    // MARK: - Cooldown

    private static let cooldownSeconds: TimeInterval = 10
    private static let connectTimeoutSeconds: TimeInterval = 10
    private static let iOSTimeoutSeconds: TimeInterval = 15
    private static let connectLeadDelaySeconds: TimeInterval = 0.5

    private var cooldownTimer: Timer?
    private var timeoutTimer: Timer?
    /// MAC address of the device currently in the cooldown window (used by BluetoothManager reconnect guard).
    private var cooldownDeviceAddress: String?

    // MARK: - Dependencies (set by app wiring after init)

    weak var multipeerService: MultipeerService?

    #if os(macOS)
    weak var bluetoothManager: BluetoothManager?
    #endif

    // MARK: - Public API

    /// Initiates a switch. Rejected silently if a switch is already in progress (SW-05).
    /// Call from ContentView button action via Task { coordinator.requestSwitch() }.
    func requestSwitch() {
        guard case .idle = switchState else {
            print("[SwitchCoordinator] Switch already in progress (\(switchState)) — ignoring duplicate request")
            return
        }

        guard multipeerService?.isConnectedToPeer == true else {
            postNotification(title: "Switch Failed", body: "Not connected to peer device")
            return
        }

        switchState = .switching
        print("[SwitchCoordinator] Switch started — state: .switching")

        #if os(macOS)
        performMacToiPhoneSwitch()
        #else
        performiPhoneToMacSwitch()
        #endif
    }

    /// Called by MultipeerService when a .switchRequest signal arrives from the peer.
    /// On macOS: connect the headphone (iPhone→Mac path).
    /// On iOS: iOS has nothing to actuate; headphone will auto-connect once Mac calls openConnection().
    func handleIncomingSwitchRequest(from sender: SyncSignal.Platform) {
        #if os(macOS)
        guard sender == .ios else { return }
        print("[SwitchCoordinator] Mac received switch request from iOS — will connect headphone")
        performMacConnectForIncomingRequest()
        #else
        guard sender == .mac else { return }
        // iOS receives this only in the Mac→iPhone flow: headphone is on its way.
        // No action needed on iOS — headphone will auto-connect to iPhone shortly.
        print("[SwitchCoordinator] iOS received switch request from Mac — awaiting headphone connection")
        #endif
    }

    /// Called by MultipeerService when a .status signal arrives confirming headphone connection.
    /// On iOS: used to confirm Mac connected the headphone (iPhone→Mac path success).
    func handleIncomingStatusConfirmation(bluetoothStatus: String) {
        #if os(iOS)
        guard case .switching = switchState, bluetoothStatus == "connected" else { return }
        // Mac confirmed it connected the headphone — switch succeeded.
        cancelTimeoutTimer()
        switchState = .idle
        postNotification(title: "Headphone Switched", body: "Now connected to Mac")
        print("[SwitchCoordinator] iOS confirmed Mac connection — switch complete")
        #endif
    }

    /// Returns true if the device identified by addressString is in the reconnect suppression window.
    /// Called by BluetoothManager.deviceDidConnect to suppress auto-reconnect during cooldown (SW-05).
    func isInCooldown(for addressString: String?) -> Bool {
        guard case .cooldown = switchState else { return false }
        return cooldownDeviceAddress == addressString
    }

    // MARK: - Notification Permission

    /// Request UNUserNotificationCenter authorization. Call once at app startup (SW-04).
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            print("[SwitchCoordinator] Notification permission granted: \(granted)")
        }
    }

    // MARK: - Notification Helper

    /// Posts a local system notification immediately (trigger: nil = deliver now).
    func postNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[SwitchCoordinator] Notification post failed: \(error)")
            }
        }
    }

    // MARK: - Mac→iPhone Flow (macOS only)

    #if os(macOS)
    private func performMacToiPhoneSwitch() {
        guard let manager = bluetoothManager,
              let device = manager.pairedAudioDevices().first else {
            transitionToError("No paired audio device found")
            return
        }

        print("[SwitchCoordinator] Mac→iPhone: disconnecting \(device.name ?? device.addressString ?? "device")")

        Task { @MainActor in
            let success = await manager.disconnectDevice(device)
            if success {
                // Disconnect confirmed — enter cooldown to suppress auto-reconnect (Pitfall 1 / SW-05)
                startCooldown(for: device.addressString)
                // Send switch request to iPhone so it knows to connect (or auto-connects)
                let signal = SyncSignal(type: .switchRequest, sender: .mac, timestamp: Date(), bluetoothStatus: "disconnected")
                try? self.multipeerService?.send(signal)
                self.multipeerService?.localBluetoothStatus = "disconnected"
                print("[SwitchCoordinator] Mac→iPhone: disconnect confirmed, switch request sent, cooldown started")
                // Notification fires when cooldown ends (state → .idle) — success is implicit
                // Post immediately: headphone is released for iPhone
                self.postNotification(title: "Headphone Switched", body: "Now available for iPhone")
            } else {
                transitionToError("Could not disconnect headphone")
            }
        }
    }

    /// Called when Mac receives a .switchRequest from iOS (iPhone→Mac path).
    /// Mac calls openConnection() with a 500ms lead delay (Pitfall 3 mitigation).
    private func performMacConnectForIncomingRequest() {
        guard let manager = bluetoothManager,
              let device = manager.pairedAudioDevices().first else {
            print("[SwitchCoordinator] Mac received switch request but no paired device found — ignoring")
            return
        }

        // Check if already connected — openConnection() when already connected is a no-op.
        if device.isConnected() {
            print("[SwitchCoordinator] Mac: device already connected — nothing to do")
            return
        }

        // 500ms delay before connect — headphone may still be releasing from iOS (Pitfall 3)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.connectLeadDelaySeconds) {
            print("[SwitchCoordinator] Mac connecting headphone (iPhone→Mac request): \(device.name ?? "device")")
            _ = manager.connectDevice(device)
            // deviceDidConnect callback in BluetoothManager will send .status("connected") signal to iOS.
            // Start a 10-second timeout in case deviceDidConnect never fires.
            self.startConnectTimeout(for: device.addressString)
        }
    }

    private func startConnectTimeout(for address: String?) {
        cancelTimeoutTimer()
        timeoutTimer = Timer.scheduledTimer(
            withTimeInterval: Self.connectTimeoutSeconds,
            repeats: false
        ) { [weak self] _ in
            guard let self else { return }
            print("[SwitchCoordinator] Mac connect timeout for \(address ?? "device") — no deviceDidConnect within 10s")
            self.postNotification(title: "Switch Failed", body: "Headphone did not connect within 10s")
        }
    }
    #endif

    // MARK: - iPhone→Mac Flow (iOS only)

    #if os(iOS)
    private func performiPhoneToMacSwitch() {
        // iOS sends the switch request — Mac is the actuator.
        let signal = SyncSignal(type: .switchRequest, sender: .ios, timestamp: Date(), bluetoothStatus: "unknown")
        do {
            try multipeerService?.send(signal)
            print("[SwitchCoordinator] iPhone→Mac: switchRequest sent — waiting for Mac confirmation (15s timeout)")
            // Start 15-second timeout. If Mac doesn't confirm, reset to idle (Pitfall 6 / SW-05).
            startIOSTimeout()
        } catch {
            transitionToError("Failed to send switch request: \(error.localizedDescription)")
        }
    }

    private func startIOSTimeout() {
        cancelTimeoutTimer()
        timeoutTimer = Timer.scheduledTimer(
            withTimeInterval: Self.iOSTimeoutSeconds,
            repeats: false
        ) { [weak self] _ in
            guard let self, case .switching = self.switchState else { return }
            print("[SwitchCoordinator] iOS switch timeout — no confirmation from Mac within 15s")
            self.transitionToError("Switch timeout — Mac did not respond")
        }
    }
    #endif

    // MARK: - Cooldown (macOS only)

    #if os(macOS)
    private func startCooldown(for address: String?) {
        cooldownDeviceAddress = address
        switchState = .cooldown
        print("[SwitchCoordinator] Cooldown started for \(address ?? "device") — \(Int(Self.cooldownSeconds))s reconnect suppression active")
        cooldownTimer = Timer.scheduledTimer(
            withTimeInterval: Self.cooldownSeconds,
            repeats: false
        ) { [weak self] _ in
            self?.endCooldown()
        }
    }

    private func endCooldown() {
        cooldownTimer?.invalidate()
        cooldownTimer = nil
        cooldownDeviceAddress = nil
        switchState = .idle
        print("[SwitchCoordinator] Cooldown ended — ready for next switch")
    }
    #endif

    // MARK: - Error + Cleanup

    private func transitionToError(_ message: String) {
        print("[SwitchCoordinator] Error: \(message)")
        switchState = .error(message)
        postNotification(title: "Switch Failed", body: message)
        // Reset to idle after brief display window
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self, case .error = self.switchState else { return }
            self.switchState = .idle
            print("[SwitchCoordinator] Reset to idle after error")
        }
    }

    private func cancelTimeoutTimer() {
        timeoutTimer?.invalidate()
        timeoutTimer = nil
    }
}
