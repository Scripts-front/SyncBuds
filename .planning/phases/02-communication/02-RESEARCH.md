# Phase 2: Communication - Research

**Researched:** 2026-03-26
**Domain:** MultipeerConnectivity (MCSession, MCNearbyServiceAdvertiser, MCNearbyServiceBrowser), signal encoding, iOS/macOS peer discovery, entitlements and Info.plist
**Confidence:** HIGH for MCF API shape and constraints; MEDIUM for background behavior specifics on iOS 26.2 (post-cutoff)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** CloudKit is NOT implemented in this phase. User does not have Apple Developer Account. Only Multipeer Connectivity is implemented.
- **D-02:** COM-02 (CloudKit fallback) and COM-04 (silent push wake) are deferred to a future phase when Developer Account exists.
- **D-03:** No SignalRouter abstraction needed yet — direct Multipeer implementation is sufficient. When CloudKit is added later, a router can be introduced.
- **D-04:** Minimal signal format: type (switch/status), direction (mac→iphone or iphone→mac), timestamp. No device-specific data in the signal.
- **D-05:** Signal is encoded as simple Codable struct sent via Multipeer Connectivity data channel.
- **D-06:** Devices exchange connection status periodically via Multipeer Connectivity. Both apps show which device currently has the headphone.
- **D-07:** Status updates only work when devices are on the same network (Multipeer limitation). This is acceptable for now — CloudKit will extend range later.
- **D-08:** Service type string must be consistent across both targets (e.g., "syncbuds-signal").
- **D-09:** Claude's discretion on MCSession configuration, peer discovery, and reconnection handling.

### Claude's Discretion
- MCSession configuration details (encryption, max peers)
- Peer discovery and reconnection strategy
- Status update frequency (polling interval)
- Whether to use MCNearbyServiceAdvertiser/Browser or MCBrowserViewController
- Error handling and retry logic for Multipeer

### Deferred Ideas (OUT OF SCOPE)
- **CloudKit integration** — requires Apple Developer Account ($99/year). Deferred to future phase.
- **COM-02 (CloudKit fallback)** — deferred with CloudKit
- **COM-04 (silent push wake)** — deferred with CloudKit
- **SignalRouter abstraction** — not needed until CloudKit is added as second transport
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| COM-01 | Mac and iPhone communicate via Multipeer Connectivity as primary channel (~50-300ms latency) | MCSession sendData(.reliable) over Bonjour — verified pattern |
| COM-02 | CloudKit fallback when not on same network | **DEFERRED** per D-01/D-02 — no Developer Account |
| COM-03 | SignalRouter automatic transport selection | **SIMPLIFIED** per D-03 — direct Multipeer only, no abstraction |
| COM-04 | Communication survives iOS background (CloudKit silent push wake) | **DEFERRED** per D-02 — no Developer Account; Multipeer is foreground-only |
| BT-04 | App shows real-time connection status (connected/disconnected, which device has it) | Status signal exchanged periodically via Multipeer; both UIs display peer state |
</phase_requirements>

---

## Summary

Phase 2 delivers cross-device signaling between Mac and iPhone using only Multipeer Connectivity (MCF). CloudKit is explicitly deferred. The communication layer is a single class — `MultipeerService` — shared by both platforms, placed in `SyncBuds/Shared/`. Both sides advertise and browse simultaneously (symmetric peer discovery), automatically accept invitations, and exchange `SyncSignal` Codable structs over a reliable MCSession data channel.

The critical practical constraint for this phase: **Multipeer only works when both apps are in the foreground.** iOS suspends the app when backgrounded and tears down MCSession. This is an accepted limitation per D-07 — CloudKit silent push (deferred) will address the background case in a future phase. The planner must NOT design tasks that rely on background delivery.

**Primary recommendation:** Implement `MultipeerService` as an `@Observable final class` shared by both platforms, using `MCNearbyServiceAdvertiser` + `MCNearbyServiceBrowser` (not `MCBrowserViewController` — no user-facing UI needed), with automatic invitation acceptance. Both Mac and iPhone advertise and browse simultaneously. Signals encoded with `JSONEncoder` into `Data`, decoded with `JSONDecoder` on receive. Status updates sent on a 5-second timer when a peer is connected.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| MultipeerConnectivity | iOS 7+ / macOS 10.10+ (system framework) | Peer-to-peer local network messaging over Wi-Fi, Bluetooth, or Ethernet | Only Apple framework for sub-second local cross-device messaging without internet |
| Foundation (JSONEncoder/JSONDecoder) | System | Codable signal encoding to Data | Trivial, no third-party dependency, aligns with project constraint (no external deps) |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Combine / `@Observable` | System (Swift 5.9+) | Reactive UI updates when peer state changes | Use `@Observable` (not Combine) — project is SwiftUI/SwiftData native |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| MCNearbyServiceAdvertiser/Browser | MCBrowserViewController / MCAdvertiserAssistant | MCBrowserViewController shows a picker UI — not needed; automatic acceptance is correct for a trusted two-device personal tool |
| JSONEncoder | PropertyListEncoder, custom binary | JSON is human-readable for debugging, well-supported; no performance concern at this message frequency |

**Installation:**
No installation needed — MultipeerConnectivity is a system framework.

```swift
import MultipeerConnectivity
```

**Version verification:** System framework — version is tied to OS. Project targets iOS 26.2 / macOS 26.2, both of which include MultipeerConnectivity.

---

## Architecture Patterns

### Recommended Project Structure
```
SyncBuds/
├── Shared/
│   ├── Models/
│   │   ├── BluetoothDevice.swift   (existing)
│   │   └── SyncSignal.swift        (NEW — Codable signal struct)
│   └── MultipeerService.swift      (NEW — MCSession + advertiser + browser)
├── macOS/
│   └── BluetoothManager.swift      (existing — wire in status sends)
├── iOS/
│   └── AudioRouteMonitor.swift     (existing — wire in status sends)
└── ContentView.swift               (existing — add peer status display)
```

### Pattern 1: Symmetric Advertiser + Browser (Both Sides Advertise and Browse)

**What:** Both Mac and iPhone run an `MCNearbyServiceAdvertiser` and an `MCNearbyServiceBrowser` simultaneously. Both automatically accept invitations. The first device to discover the other sends an invitation; the other accepts.

**When to use:** When there are exactly two trusted devices. No user-facing discovery UI needed. Avoids the asymmetric host/client model that would require knowing which device starts first.

**Why not MCBrowserViewController:** That class shows a sheet with peer names and a connect button. For SyncBuds, connection is automatic — no user interaction needed at the networking layer.

**Example:**
```swift
// Source: Apple MultipeerConnectivity docs + createwithswift.com verified pattern
import MultipeerConnectivity

@Observable
final class MultipeerService: NSObject {

    // MARK: - Constants
    private static let serviceType = "syncbuds-bt"  // max 15 chars, lowercase/digits/hyphens only

    // MARK: - MCF Objects
    private let peerID: MCPeerID
    private let session: MCSession
    private let advertiser: MCNearbyServiceAdvertiser
    private let browser: MCNearbyServiceBrowser

    // MARK: - Observable State (BT-04)
    var connectedPeerName: String? = nil
    var peerBluetoothStatus: String = "unknown"  // "mac" | "ios" | "unknown"
    var isConnectedToPeer: Bool = false

    init() {
        // Use device name for human-readable peer identity in logs
        #if os(macOS)
        let name = Host.current().localizedName ?? "Mac"
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

    func start() {
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
    }

    func stop() {
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
    }
}
```

### Pattern 2: Signal Struct with Codable

**What:** A minimal `SyncSignal` struct encodes all cross-device messages. `type` discriminates switch requests from status updates.

**Example:**
```swift
// Source: D-04, D-05 from CONTEXT.md; Codable pattern from Apple docs
struct SyncSignal: Codable {
    enum SignalType: String, Codable {
        case status     // periodic: "I currently have the headphone"
        case switchRequest  // imperative: "please release the headphone"
    }

    enum Platform: String, Codable {
        case mac, ios
    }

    let type: SignalType
    let sender: Platform
    let timestamp: Date     // reject signals older than 30s to prevent stale delivery
    let bluetoothStatus: String  // "connected" | "disconnected" | "unknown"
}
```

### Pattern 3: Automatic Invitation Acceptance

**What:** In `MCNearbyServiceBrowserDelegate.browser(_:foundPeer:withDiscoveryInfo:)`, immediately invite the found peer. In `MCNearbyServiceAdvertiserDelegate.advertiser(_:didReceiveInvitationFromPeer:withContext:invitationHandler:)`, immediately call `invitationHandler(true, session)`.

**Why:** SyncBuds is a personal two-device tool. No adversarial peers. Auto-accept eliminates UI flow and makes connection transparent.

**Example:**
```swift
// MCNearbyServiceBrowserDelegate
func browser(_ browser: MCNearbyServiceBrowser,
             foundPeer peerID: MCPeerID,
             withDiscoveryInfo info: [String: String]?) {
    // Invite immediately — only one trusted peer expected
    browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
}

// MCNearbyServiceAdvertiserDelegate
func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                didReceiveInvitationFromPeer peerID: MCPeerID,
                withContext context: Data?,
                invitationHandler: @escaping (Bool, MCSession?) -> Void) {
    invitationHandler(true, session)
}
```

### Pattern 4: Sending and Receiving Data

**Example:**
```swift
// Sending
func send(_ signal: SyncSignal) throws {
    guard !session.connectedPeers.isEmpty else { return }
    let data = try JSONEncoder().encode(signal)
    try session.send(data, toPeers: session.connectedPeers, with: .reliable)
}

// Receiving (MCSessionDelegate)
func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
    guard let signal = try? JSONDecoder().decode(SyncSignal.self, from: data) else { return }
    // Reject stale signals
    guard Date().timeIntervalSince(signal.timestamp) < 30 else { return }
    DispatchQueue.main.async {
        self.handleReceivedSignal(signal)
    }
}
```

### Pattern 5: Periodic Status Updates (BT-04)

**What:** A `Timer` fires every 5 seconds when a peer is connected and sends a `.status` signal with the current Bluetooth state.

**Why 5 seconds:** Responsive enough to show "live" status. Not so frequent that it causes CPU/radio wake overhead on battery.

**Example:**
```swift
private var statusTimer: Timer?

private func startStatusTimer() {
    statusTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
        guard let self, self.isConnectedToPeer else { return }
        let signal = SyncSignal(
            type: .status,
            sender: .mac,  // platform-specific
            timestamp: Date(),
            bluetoothStatus: self.localBluetoothStatus
        )
        try? self.send(signal)
    }
}

private func stopStatusTimer() {
    statusTimer?.invalidate()
    statusTimer = nil
}
```

### Anti-Patterns to Avoid

- **Using MCBrowserViewController:** It shows a picker sheet. Not appropriate for an automatic, background service. Use `MCNearbyServiceAdvertiser`/`MCNearbyServiceBrowser` directly.
- **Single-sided advertising (host/client model):** If only one side advertises and the other only browses, startup order determines who can connect. Both-sides-symmetric removes the race.
- **Sending signals from a background thread without main-thread dispatch for UI updates:** MCSessionDelegate callbacks arrive on an arbitrary queue. Always dispatch UI mutations to `@MainActor` or `DispatchQueue.main`.
- **Storing signals in SwiftData:** Per existing architecture guidance (PITFALLS.md, Anti-Pattern 2) — signals are ephemeral. Do not persist them. They belong in memory only.
- **Ignoring timestamp validation:** Without staleness check, a reconnecting device could re-deliver an old signal and trigger an unintended switch.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Peer discovery on local network | Custom Bonjour / TCP socket listener | MCNearbyServiceAdvertiser + MCNearbyServiceBrowser | MCF handles Bonjour service registration, peer negotiation, and transport selection (Wi-Fi/BT/Ethernet) automatically |
| Reliable message delivery | Custom ACK loop | `MCSessionSendDataMode.reliable` | MCF's reliable mode handles retransmission and ordering |
| Peer authentication | Custom challenge-response | `MCSession(encryptionPreference: .required)` | MCF uses TLS-based encryption; sufficient for a trusted personal device pair |
| Codable → Data | Custom binary serialization | `JSONEncoder` / `JSONDecoder` | Trivial, debuggable, zero dependencies |

**Key insight:** Multipeer Connectivity already handles the hardest parts of local peer-to-peer networking — Bonjour registration, transport negotiation (Wi-Fi vs Bluetooth), retry, and encryption. The app only needs to manage session lifecycle and encode/decode messages.

---

## Common Pitfalls

### Pitfall 1: Service Type String Too Long or Invalid Characters
**What goes wrong:** `MCNearbyServiceAdvertiser` will throw or silently fail if the service type string exceeds 15 characters, contains uppercase letters, or includes characters other than lowercase letters, digits, and hyphens.
**Why it happens:** MCF maps the service type to a Bonjour service registration; Bonjour has strict name constraints.
**How to avoid:** Use exactly `"syncbuds-bt"` (11 chars, all valid). Verify: no uppercase, no underscores, no dots, no spaces.
**Warning signs:** Advertiser starts but no peers are discovered; no error is logged.

### Pitfall 2: Missing Info.plist Keys for Local Network Permission (iOS 14+)
**What goes wrong:** On iOS 14+, the first time the app uses MCF, iOS prompts for local network permission. Without `NSLocalNetworkUsageDescription` and `NSBonjourServices` in Info.plist, the app either crashes, shows a generic prompt, or silently fails to discover peers.
**Why it happens:** Apple added local network privacy controls in iOS 14. The existing `Info.plist` in SyncBuds only has `NSBluetoothAlwaysUsageDescription` — it does NOT yet contain the MCF keys.
**How to avoid:** Add to `Info.plist`:
```xml
<key>NSLocalNetworkUsageDescription</key>
<string>SyncBuds uses your local network to communicate between your Mac and iPhone for headphone switching.</string>
<key>NSBonjourServices</key>
<array>
    <string>_syncbuds-bt._tcp</string>
    <string>_syncbuds-bt._udp</string>
</array>
```
**Warning signs:** Peers not discovered. No permission prompt appears. Console shows Bonjour errors.

### Pitfall 3: macOS Sandbox — Network Client/Server Entitlements
**What goes wrong:** The macOS target has App Sandbox enabled (`com.apple.security.app-sandbox = true`). MCF requires network access. Without the `com.apple.security.network.client` entitlement (and possibly `com.apple.security.network.server`), Bonjour browsing and advertising are silently blocked.
**Why it happens:** Sandboxed macOS apps cannot use the network without explicit entitlements.
**How to avoid:** Add to `SyncBuds.entitlements`:
```xml
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.network.server</key>
<true/>
```
**Warning signs:** MCF starts without error but no peers are found on macOS side; iOS side discovers nothing.

### Pitfall 4: MCSession Delegate Callbacks on Arbitrary Queue
**What goes wrong:** `session(_:peer:didChange:)` and `session(_:didReceive:fromPeer:)` are called on a private MCF internal queue, not the main queue. Writing to `@Observable` properties or SwiftUI state from this queue causes data races and crashes (Swift 6 strict concurrency).
**Why it happens:** MCF predates Swift concurrency and dispatches on its own queue.
**How to avoid:** Always dispatch to `@MainActor` (or `DispatchQueue.main.async`) when updating any observable state from these callbacks.

### Pitfall 5: Multipeer Does Not Work When iOS App is Backgrounded
**What goes wrong:** As documented in PITFALLS.md (Pitfall 11), iOS suspends the app when backgrounded. MCSession tears down. The Mac will see the peer disconnect. There is no background mode that keeps MCF alive for a non-audio, non-navigation app.
**Why it happens:** iOS background execution policy. MCF is not a background-capable transport by itself.
**How to avoid:** Design the status display to show "Peer offline" when the iOS app is backgrounded (peer disconnects from Mac's perspective). This is the accepted limitation per D-07. Document clearly in UI. Do NOT attempt workarounds (VoIP push, BGTask) in this phase — that belongs to the CloudKit phase.
**Warning signs:** Switch works when iOS app is in foreground but fails immediately when iOS app is sent to background.

### Pitfall 6: Double Invitation Race (Both Sides Browse and Invite)
**What goes wrong:** Because both sides advertise and browse, each side may discover the other at approximately the same time and both send invitations simultaneously. The result is two sessions being created, both connections failing due to conflict.
**Why it happens:** Symmetric discovery is the right pattern, but without de-duplication, both sides invite each other.
**How to avoid:** In `browser(_:foundPeer:withDiscoveryInfo:)`, only invite if `session.connectedPeers.isEmpty` (don't invite if already connected or already have an outgoing invite). The advertiser side accepts if invited. Since one side will always receive the invitation slightly later, this natural timing prevents the double-invite loop in practice. Additionally, check `session.connectedPeers` before sending any data.
**Warning signs:** Both apps log "session changed to connected" and then immediately "disconnected"; loop of connects/disconnects in console.

### Pitfall 7: MCPeerID Display Name Must Not Change Between Sessions
**What goes wrong:** If `MCPeerID(displayName:)` uses a dynamic value (e.g., UUID), the same physical device appears as a different peer each time. MCF doesn't correlate peer identity across sessions by displayName — it uses it only for human display.
**Why it happens:** Developers use `UUID().uuidString` as a unique ID thinking it will be stable.
**How to avoid:** Use a stable display name: `Host.current().localizedName ?? "Mac"` on macOS, `UIDevice.current.name` on iOS. The MCPeerID doesn't need to be globally unique — within a Bonjour service, discovery is scoped to the local network segment.

---

## Code Examples

Verified patterns from official and community-verified sources:

### Complete MCSessionDelegate Minimum Implementation
```swift
// Source: Apple MultipeerConnectivity docs (MCSessionDelegate protocol)
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
                // Restart browsing to reconnect when peer comes back online
                self.browser.startBrowsingForPeers()
            @unknown default:
                break
            }
        }
    }

    // Required protocol stubs (not used for data-only channel)
    func session(_ session: MCSession, didReceive stream: InputStream,
                 withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
```

### BluetoothManager Integration Point (macOS)
```swift
// In BluetoothManager.swift — wire connection events to MultipeerService
// Called from deviceDidConnect / deviceDidDisconnect observer callbacks
func notifyPeerOfStatusChange(via multipeerService: MultipeerService, connected: Bool) {
    let signal = SyncSignal(
        type: .status,
        sender: .mac,
        timestamp: Date(),
        bluetoothStatus: connected ? "connected" : "disconnected"
    )
    try? multipeerService.send(signal)
}
```

### AudioRouteMonitor Integration Point (iOS)
```swift
// In AudioRouteMonitor.swift — wire route changes to MultipeerService
// Called from routeChanged(_:) after updateStateFromCurrentRoute()
func notifyPeerOfRouteChange(via multipeerService: MultipeerService) {
    let signal = SyncSignal(
        type: .status,
        sender: .ios,
        timestamp: Date(),
        bluetoothStatus: isBluetoothAudioActive ? "connected" : "disconnected"
    )
    try? multipeerService.send(signal)
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `@Published` + `ObservableObject` | `@Observable` macro | Swift 5.9 / iOS 17 / macOS 14 | Use `@Observable final class MultipeerService: NSObject` — no `@Published` needed; property access is automatic |
| `DispatchQueue.main.async` for UI updates | `@MainActor` / `MainActor.run { }` | Swift 5.5+ | Prefer `@MainActor` annotation on observable state update methods; `DispatchQueue.main.async` still works as fallback |
| MCBrowserViewController for peer discovery | Programmatic MCNearbyServiceAdvertiser + Browser | Long-standing best practice | MCBrowserViewController is for user-facing peer picking UIs; programmatic is correct for app-controlled connections |

**Deprecated/outdated:**
- `MCAdvertiserAssistant`: Shows system-provided prompts for invitation acceptance. For SyncBuds, use `MCNearbyServiceAdvertiser` directly with programmatic acceptance via the delegate.

---

## Open Questions

1. **Does iOS 26.2 change any MCF background behavior?**
   - What we know: MCF has been foreground-only since iOS 7. PITFALLS.md confirms this. iOS 26.2 post-dates knowledge cutoff.
   - What's unclear: Whether iOS 26 introduced any new background capability for peer-to-peer sessions.
   - Recommendation: Test on real device during implementation. If behavior has changed, it would be a positive surprise (background delivery), not a blocker. Design for foreground-only to be safe.

2. **Does the macOS sandbox allow MCF without explicit entitlements beyond network.client/server?**
   - What we know: `com.apple.security.network.client` and `.server` are the documented requirements.
   - What's unclear: Whether Bonjour specifically needs additional entitlements in newer macOS versions (26.x).
   - Recommendation: Add both entitlements in Wave 1. If discovery still fails, check System Settings > Privacy & Security for any new local network permission prompt on macOS.

3. **What is the correct displayName for `MCPeerID` when UIDevice is unavailable on macOS?**
   - What we know: `UIDevice` is iOS-only. `Host.current().localizedName` is the macOS equivalent.
   - What's unclear: Whether `Host.current().localizedName` is always non-nil on macOS.
   - Recommendation: Use `Host.current().localizedName ?? ProcessInfo.processInfo.hostName ?? "Mac"` as the fallback chain.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| MultipeerConnectivity.framework | COM-01 signal channel | System | iOS 26.2 / macOS 26.2 (system) | None needed — system framework |
| Two physical devices (Mac + iPhone) | Real-device verification | Developer-dependent | — | Cannot simulate cross-device MCF reliably in Simulator |
| Same Wi-Fi network | MCF peer discovery | Developer-dependent | — | Bluetooth fallback within MCF is automatic |

**Missing dependencies with no fallback:**
- Real device testing on both Mac + iPhone simultaneously is required to verify peer discovery and signal delivery. The Simulator cannot test MCF between platforms.

**Missing dependencies with fallback:**
- None identified.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Swift Testing (import Testing) |
| Config file | None — Xcode discovers tests automatically |
| Quick run command | `xcodebuild test -scheme SyncBuds -destination 'platform=macOS'` (unit tests only) |
| Full suite command | `xcodebuild test -scheme SyncBuds -destination 'platform=macOS'` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| COM-01 | SyncSignal encodes/decodes correctly via JSONEncoder/Decoder | unit | Swift Testing in SyncBudsTests | ✅ (add test case) |
| COM-01 | SyncSignal with timestamp older than 30s is rejected | unit | Swift Testing in SyncBudsTests | ✅ (add test case) |
| COM-01 | MultipeerService.send() skips when no peers connected | unit | Swift Testing in SyncBudsTests | ✅ (add test case) |
| COM-01 | Peer discovery and data delivery end-to-end | manual | Run on Mac + iPhone simultaneously | ❌ Wave 0 manual |
| BT-04 | Status signal updates peerBluetoothStatus on receive | unit | Swift Testing in SyncBudsTests | ✅ (add test case) |
| BT-04 | UI shows "Mac has headphone" / "iPhone has headphone" correctly | manual | Visual inspection on both devices | ❌ Wave 0 manual |
| COM-02 | CloudKit fallback | DEFERRED | — | — |
| COM-03 | SignalRouter selection | DEFERRED (simplified to direct Multipeer) | — | — |
| COM-04 | iOS background wake | DEFERRED | — | — |

### Sampling Rate
- **Per task commit:** Run `xcodebuild build -scheme SyncBuds -destination 'platform=macOS'` to verify both targets compile
- **Per wave merge:** Run full Swift Testing suite to verify unit tests pass
- **Phase gate:** Manual real-device verification: Mac discovers iPhone, signal sent, both UIs update — before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `SyncBudsTests/SyncSignalTests.swift` — unit tests for Codable encoding, staleness rejection, send guard
- [ ] Real-device test plan (manual checklist in PLAN.md or SUMMARY.md) covering: peer discovery within 10s, signal delivery latency, status display update, foreground-only reconnection

*(Existing `SyncBudsTests/SyncBudsTests.swift` infrastructure can receive new `@Test` functions — no new test file infrastructure required, though a dedicated file is preferred for organization)*

---

## Project Constraints (from CLAUDE.md)

| Directive | Applies To |
|-----------|------------|
| No external dependencies — system frameworks only | MultipeerConnectivity is system; JSONEncoder is Foundation — compliant |
| Swift + SwiftUI + SwiftData only | MultipeerService class is pure Swift; no third-party wrappers |
| iOS 26.2+ and macOS 26.2+ deployment targets | MCF available on both; `@Observable` available since iOS 17/macOS 14 — compliant |
| `#if os(macOS)` / `#if os(iOS)` platform guards | `MCPeerID` display name source differs per platform; guard required |
| `final class` with `NSObject` inheritance for delegate classes | `MultipeerService` must be `final class MultipeerService: NSObject` |
| 4-space indentation, PascalCase filenames | Follow in all new files |
| Files in `Shared/` for cross-platform code | `MultipeerService.swift` and `SyncSignal.swift` go in `SyncBuds/Shared/` |
| No Apple Developer Account (no CloudKit, no push entitlements) | Do NOT add CloudKit or push notification entitlements in this phase |
| Commit format: emoji conventional commits, no Co-Authored-By | Apply to all commits in this phase |

---

## Sources

### Primary (HIGH confidence)
- Apple MultipeerConnectivity documentation — MCSession, MCNearbyServiceAdvertiser, MCNearbyServiceBrowser, MCSessionDelegate protocol shape
- Existing project files (first-party): `BluetoothManager.swift`, `AudioRouteMonitor.swift`, `SyncBuds.entitlements`, `Info.plist`, `CONTEXT.md`
- PITFALLS.md — Pitfall 11 (MCF foreground-only), confirmed by WebSearch results
- ARCHITECTURE.md — component boundaries, Shared/ file structure

### Secondary (MEDIUM confidence)
- [createwithswift.com — Getting Started with Multipeer Connectivity](https://www.createwithswift.com/getting-started-with-multipeer-connectivity-in-swift/) — service type constraints (max 15 chars, lowercase/digits/hyphens), `encryptionPreference: .required`, Info.plist key requirements
- [createwithswift.com — Building P2P Sessions](https://www.createwithswift.com/building-peer-to-peer-sessions-sending-and-receiving-data-with-multipeer-connectivity/) — sendData reliable mode, Codable encoding pattern
- [Apple Developer Forums — MultiPeerConnectivity under iOS 14](https://developer.apple.com/forums/thread/651842) — NSLocalNetworkUsageDescription + NSBonjourServices requirement confirmed
- [WebSearch consensus across multiple results] — Background limitation confirmed by multiple community sources

### Tertiary (LOW confidence)
- [WebSearch] — iOS 26.2 MCF background behavior: no specific changes found; assumes same foreground-only policy. Flag for real-device verification.

---

## Metadata

**Confidence breakdown:**
- Standard stack (MCF framework): HIGH — system framework, well-documented, project-established
- Architecture (MultipeerService class design): HIGH — standard MCF delegate pattern
- Pitfalls: HIGH for service type/Info.plist/entitlements; MEDIUM for iOS 26.2-specific behavior
- Validation: MEDIUM — unit-testable portion (Codable) is well-defined; real-device testing cannot be automated

**Research date:** 2026-03-26
**Valid until:** 2026-06-26 (stable Apple framework; MCF API has not changed meaningfully since iOS 7)
