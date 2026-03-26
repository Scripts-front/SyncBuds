//
//  MultipeerService.swift
//  SyncBuds
//

import Foundation
import MultipeerConnectivity
#if os(iOS)
import UIKit
#endif

/// Core networking class for cross-device communication between Mac and iPhone.
/// Manages MCSession lifecycle, peer discovery, data sending/receiving, and periodic status broadcasts.
/// Both platforms advertise and browse simultaneously (symmetric discovery — Pitfall 6 mitigation).
/// All MCSessionDelegate UI mutations are dispatched to the main thread (Pitfall 4 mitigation).
/// Peer name is derived from stable device name (Pitfall 7 mitigation).
@Observable final class MultipeerService: NSObject {

    // MARK: - Constants

    /// Bonjour service type. Must match Info.plist NSBonjourServices entries (`_syncbuds-bt._tcp`).
    /// Constraints: max 15 chars, lowercase letters/digits/hyphens only.
    private static let serviceType = "syncbuds-bt"

    // MARK: - MCF Objects

    private let peerID: MCPeerID
    private let session: MCSession
    private let advertiser: MCNearbyServiceAdvertiser
    private let browser: MCNearbyServiceBrowser

    // MARK: - Observable State

    /// True when at least one peer has reached the `.connected` state.
    var isConnectedToPeer: Bool = false

    /// Weak reference to the shared switch coordinator.
    /// Set by the app after instantiating SwitchCoordinator.
    weak var switchCoordinator: SwitchCoordinator?

    /// Display name of the currently connected peer, or nil when no peer is connected.
    var connectedPeerName: String? = nil

    /// Bluetooth audio status reported by the connected peer via the most recent `.status` signal.
    /// Values: "connected" | "disconnected" | "unknown"
    var peerBluetoothStatus: String = "unknown"

    /// Bluetooth audio status on this device. Set by BluetoothManager (macOS) or AudioRouteMonitor (iOS).
    /// Sent to the peer in every periodic status broadcast.
    var localBluetoothStatus: String = "unknown"

    // MARK: - Init

    override init() {
        #if os(macOS)
        let name = Host.current().localizedName ?? ProcessInfo.processInfo.hostName ?? "Mac"
        #else
        let name = UIDevice.current.name
        #endif

        self.peerID = MCPeerID(displayName: name)
        self.session = MCSession(
            peer: peerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )
        self.advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: nil,
            serviceType: Self.serviceType
        )
        self.browser = MCNearbyServiceBrowser(
            peer: peerID,
            serviceType: Self.serviceType
        )
        super.init()
        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
    }

    // MARK: - Lifecycle

    /// Starts advertising this device and browsing for peers on the local network.
    /// Call once when the app becomes active. Safe to call multiple times.
    func start() {
        print("[MultipeerService] Starting advertiser and browser for service type: \(Self.serviceType)")
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
        print("[MultipeerService] Peer ID: \(peerID.displayName)")
    }

    /// Stops advertising and browsing, and disconnects the current session.
    /// Call on app termination or when communication is no longer needed.
    func stop() {
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
    }

    // MARK: - Send

    /// Encodes and sends a SyncSignal to all connected peers over the reliable data channel.
    /// Silently returns if no peers are connected.
    /// - Throws: Encoding or MCSession send errors propagated to caller.
    func send(_ signal: SyncSignal) throws {
        guard !session.connectedPeers.isEmpty else { return }
        let data = try JSONEncoder().encode(signal)
        try session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    // MARK: - Status Timer

    private var statusTimer: Timer?

    /// Starts a repeating timer that broadcasts the current `localBluetoothStatus` to the peer every 5 seconds.
    /// Called automatically when a peer connects. Stopped automatically on disconnect.
    private func startStatusTimer() {
        statusTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self, self.isConnectedToPeer else { return }
            #if os(macOS)
            let platform = SyncSignal.Platform.mac
            #else
            let platform = SyncSignal.Platform.ios
            #endif
            let signal = SyncSignal(
                type: .status,
                sender: platform,
                timestamp: Date(),
                bluetoothStatus: self.localBluetoothStatus
            )
            try? self.send(signal)
        }
    }

    /// Invalidates and clears the status timer. Safe to call when no timer is active.
    private func stopStatusTimer() {
        statusTimer?.invalidate()
        statusTimer = nil
    }

    // MARK: - Signal Handling

    /// Processes a freshness-validated signal received from the peer.
    /// Updates `peerBluetoothStatus` for `.status` signals.
    /// `.switchRequest` handling is deferred to Phase 3 (switch coordination).
    private func handleReceivedSignal(_ signal: SyncSignal) {
        switch signal.type {
        case .status:
            peerBluetoothStatus = signal.bluetoothStatus
            print("[MultipeerService] Peer bluetooth status: \(signal.bluetoothStatus) (sender: \(signal.sender.rawValue))")
            switchCoordinator?.handleIncomingStatusConfirmation(bluetoothStatus: signal.bluetoothStatus)
        case .switchRequest:
            print("[MultipeerService] Received switch request from \(signal.sender.rawValue)")
            switchCoordinator?.handleIncomingSwitchRequest(from: signal.sender)
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MultipeerService: MCNearbyServiceBrowserDelegate {

    func browser(_ browser: MCNearbyServiceBrowser,
                 foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String: String]?) {
        // Only invite if not already connected — prevents double-invite race (Pitfall 6 mitigation).
        guard session.connectedPeers.isEmpty else {
            print("[MultipeerService] Found \(peerID.displayName) but already connected — skipping invite")
            return
        }
        print("[MultipeerService] Found peer: \(peerID.displayName) — sending invite")
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("[MultipeerService] Lost peer: \(peerID.displayName)")
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MultipeerService: MCNearbyServiceAdvertiserDelegate {

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        print("[MultipeerService] Received invite from: \(peerID.displayName) — accepting")
        invitationHandler(true, session)
    }
}

// MARK: - MCSessionDelegate

extension MultipeerService: MCSessionDelegate {

    func session(_ session: MCSession,
                 peer peerID: MCPeerID,
                 didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.isConnectedToPeer = true
                self.connectedPeerName = peerID.displayName
                self.startStatusTimer()
                print("[MultipeerService] Connected to: \(peerID.displayName)")
            case .connecting:
                print("[MultipeerService] Connecting to: \(peerID.displayName)")
            case .notConnected:
                self.isConnectedToPeer = false
                self.connectedPeerName = nil
                self.peerBluetoothStatus = "unknown"
                self.stopStatusTimer()
                print("[MultipeerService] Disconnected from: \(peerID.displayName)")
                // Restart browsing to reconnect when peer returns (e.g., app foregrounded on iOS).
                self.browser.startBrowsingForPeers()
            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession,
                 didReceive data: Data,
                 fromPeer peerID: MCPeerID) {
        guard let signal = try? JSONDecoder().decode(SyncSignal.self, from: data) else {
            print("[MultipeerService] Failed to decode signal from \(peerID.displayName) — ignoring")
            return
        }
        guard signal.isFresh else {
            print("[MultipeerService] Discarding stale signal from \(peerID.displayName) (age > 30s)")
            return
        }
        DispatchQueue.main.async {
            self.handleReceivedSignal(signal)
        }
    }

    // Required MCSessionDelegate stubs — stream and resource transfer not used in SyncBuds.

    func session(_ session: MCSession,
                 didReceive stream: InputStream,
                 withName streamName: String,
                 fromPeer peerID: MCPeerID) {}

    func session(_ session: MCSession,
                 didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID,
                 with progress: Progress) {}

    func session(_ session: MCSession,
                 didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID,
                 at localURL: URL?,
                 withError error: Error?) {}
}
