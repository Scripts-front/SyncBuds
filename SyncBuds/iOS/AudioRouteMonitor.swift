//
//  AudioRouteMonitor.swift
//  SyncBuds
//

#if os(iOS)
import AVFoundation
import Foundation

/// Monitors the iOS audio route for Bluetooth A2DP/HFP device connections and disconnections.
/// Uses AVAudioSession.routeChangeNotification — the standard Apple pattern for audio route detection.
/// This class detects WHEN a Bluetooth headphone is connected or disconnected on iOS.
/// It cannot programmatically connect or disconnect devices (iOS has no public API for that).
final class AudioRouteMonitor {

    // MARK: - State

    /// True when a Bluetooth audio device (A2DP or HFP) is on the current output route.
    private(set) var isBluetoothAudioActive: Bool = false

    /// Name of the currently connected Bluetooth audio port, if any.
    private(set) var connectedPortName: String? = nil

    /// Weak reference to the shared Multipeer signaling service.
    /// Set by the app after instantiating MultipeerService.
    weak var multipeerService: MultipeerService?

    // MARK: - Monitoring

    /// Start observing audio route changes. Call once at app startup.
    func startMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(routeChanged(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        // Capture current state immediately in case a device is already connected.
        updateStateFromCurrentRoute()
        print("[AudioRouteMonitor] Monitoring started — current Bluetooth audio active: \(isBluetoothAudioActive)")
    }

    /// Stop observing audio route changes.
    func stopMonitoring() {
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
        print("[AudioRouteMonitor] Monitoring stopped")
    }

    // MARK: - Route Change Handler

    @objc private func routeChanged(_ notification: Notification) {
        guard let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        switch reason {
        case .newDeviceAvailable:
            updateStateFromCurrentRoute()
            if isBluetoothAudioActive {
                print("[AudioRouteMonitor] Bluetooth audio device connected: \(connectedPortName ?? "unknown")")
            }
            notifyPeerOfRouteChange()

        case .oldDeviceUnavailable:
            // The disconnected device is in userInfo, not in currentRoute.
            if let previousRoute = notification.userInfo?[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
                let hadBluetooth = previousRoute.outputs.contains {
                    $0.portType == .bluetoothA2DP || $0.portType == .bluetoothHFP
                }
                if hadBluetooth {
                    print("[AudioRouteMonitor] Bluetooth audio device disconnected")
                }
            }
            updateStateFromCurrentRoute()
            notifyPeerOfRouteChange()

        default:
            updateStateFromCurrentRoute()
            notifyPeerOfRouteChange()
        }
    }

    // MARK: - Peer Notification

    private func notifyPeerOfRouteChange() {
        let status = isBluetoothAudioActive ? "connected" : "disconnected"
        multipeerService?.localBluetoothStatus = status
        let signal = SyncSignal(type: .status, sender: .ios, timestamp: Date(), bluetoothStatus: status)
        try? multipeerService?.send(signal)
    }

    // MARK: - State Update

    private func updateStateFromCurrentRoute() {
        let route = AVAudioSession.sharedInstance().currentRoute
        if let bluetoothPort = route.outputs.first(where: {
            $0.portType == .bluetoothA2DP || $0.portType == .bluetoothHFP
        }) {
            isBluetoothAudioActive = true
            connectedPortName = bluetoothPort.portName
        } else {
            isBluetoothAudioActive = false
            connectedPortName = nil
        }
    }
}
#endif
