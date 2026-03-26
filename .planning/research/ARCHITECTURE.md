# Architecture Patterns

**Domain:** macOS + iOS cross-device Bluetooth audio switching
**Researched:** 2026-03-25
**Confidence:** MEDIUM — Apple framework behaviors drawn from training data (knowledge cutoff Aug 2025); official docs require JavaScript and could not be live-fetched. Core claims are well-established; flag IOBluetooth sandbox escape and background execution limits for phase-specific verification.

---

## Recommended Architecture

### Overview

SyncBuds is a single Xcode target compiled for both iOS and macOS (confirmed from project.pbxproj: `SUPPORTED_PLATFORMS = "iphoneos iphonesimulator macosx"`). The Mac side acts as the **control center** because IOBluetooth grants full audio-device connection control. The iPhone side acts as a **signal emitter and audio initiator** — it cannot disconnect A2DP/HFP devices but can connect to a headphone once the Mac releases it.

The architecture has four distinct layers:

```
┌─────────────────────────────────────────────────────────┐
│  PRESENTATION LAYER                                     │
│  macOS: NSStatusItem menu bar popover (SwiftUI)         │
│  iOS:   Minimal foreground view + notifications         │
└────────────────────┬────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────┐
│  DOMAIN LAYER (shared Swift code, platform-gated)       │
│  SwitchCoordinator  │  DeviceRegistry  │  SignalRouter  │
└──────┬──────────────┴────────┬──────────┴───────┬───────┘
       │                       │                  │
┌──────▼──────┐   ┌────────────▼────────┐  ┌─────▼──────────────┐
│  BLUETOOTH  │   │   PERSISTENCE       │  │  COMMUNICATION     │
│  LAYER      │   │   LAYER             │  │  LAYER             │
│             │   │                     │  │                    │
│ macOS:      │   │  SwiftData          │  │  Primary:          │
│  IOBluetooth│   │  ModelContainer     │  │   CloudKit         │
│             │   │  (device history,   │  │   CKRecord +       │
│ iOS:        │   │   last-seen state)  │  │   CKSubscription   │
│  CBCentral  │   │                     │  │                    │
│  (BLE only) │   │  CloudKit sync      │  │  Fallback:         │
│  + AVAudio  │   │  (cross-device      │  │   Multipeer        │
│  Session    │   │   history)          │  │   Connectivity     │
│  (detect    │   │                     │  │   (MCSession)      │
│  A2DP conn) │   └─────────────────────┘  └────────────────────┘
└─────────────┘
```

---

## Component Boundaries

| Component | Platform | Responsibility | Communicates With |
|-----------|----------|---------------|-------------------|
| `MenuBarController` | macOS only | Owns `NSStatusItem`, renders SwiftUI popover showing current device and switch controls | `SwitchCoordinator`, `DeviceRegistry` |
| `BluetoothMonitor` (macOS) | macOS only | Uses `IOBluetoothDevice` notifications to detect connect/disconnect events for A2DP/HFP devices | `SwitchCoordinator`, `DeviceRegistry` |
| `BluetoothActuator` | macOS only | Executes `IOBluetoothDevice.openConnection()` and `closeConnection()` on command | `SwitchCoordinator` |
| `AudioSessionMonitor` | iOS only | Monitors `AVAudioSession` route change notifications to detect when A2DP headphone connects or disconnects | `SwitchCoordinator`, `DeviceRegistry` |
| `SwitchCoordinator` | shared (platform-gated logic) | Orchestrates the switching state machine; decides when to send signals and when to act on received signals | `SignalRouter`, `BluetoothActuator` (mac), `DeviceRegistry` |
| `DeviceRegistry` | shared | SwiftData-backed store of known headphones (name, MAC address, last-seen device, last-used timestamp) | `SwitchCoordinator`, UI layers |
| `SignalRouter` | shared | Abstracts communication transport; tries Multipeer first, falls back to CloudKit | `CloudKitTransport`, `MultipeerTransport` |
| `CloudKitTransport` | shared | Writes `SwitchSignal` CKRecords to private CloudKit database; subscribes for push delivery | `SignalRouter` |
| `MultipeerTransport` | shared | Advertises and browses via `MCNearbyServiceBrowser`/`MCNearbyServiceAdvertiser`; sends `SwitchSignal` data over `MCSession` | `SignalRouter` |
| `NotificationPresenter` | shared | Posts `UNUserNotification` for connection-status feedback on both platforms | `SwitchCoordinator` |

---

## Data Flow

### Flow 1: iPhone wants headphone (iPhone → Mac transfer)

```
iOS AudioSessionMonitor
  detects headphone NOT connected (route changed away)
    → user initiates switch (or auto-trigger)
      → SwitchCoordinator (iOS) creates SwitchSignal{action: .requestRelease, deviceMAC: "XX:XX"}
        → SignalRouter tries MultipeerTransport first
          (success, ~50-200ms) OR CloudKitTransport fallback (~2-30s)
            → Mac receives SwitchSignal
              → SwitchCoordinator (Mac) validates: is that device currently connected?
                → BluetoothActuator calls IOBluetoothDevice.closeConnection()
                  → headphone becomes available (Bluetooth radio idle)
                    → iOS: user's iPhone connects headphone natively
                      (user presses connect in iOS Settings, or app uses ExternalAccessory
                       if device supports it, or simply headphone auto-connects to phone)
                        → AudioSessionMonitor detects connection
                          → DeviceRegistry updated, notification shown
```

### Flow 2: Mac wants headphone (Mac ← iPhone transfer)

```
Mac user clicks "Switch to Mac" in menu bar
  → SwitchCoordinator (Mac) creates SwitchSignal{action: .requestRelease, deviceMAC: "XX:XX"}
    → SignalRouter sends signal to iOS
      → iOS SwitchCoordinator receives: iOS cannot force-disconnect A2DP
        → iOS shows notification: "SyncBuds: tap to release [HeadphoneName]"
          → User taps notification → app opens briefly → user manually disconnects
            OR: if headphone supports BLE control channel (e.g. Sony WH-1000XM series),
                app sends BLE disconnect command via CoreBluetooth
              → headphone disconnects from iPhone
                → Mac BluetoothActuator calls IOBluetoothDevice.openConnection()
                  → headphone connects to Mac
                    → BluetoothMonitor detects connection, notification shown
```

### Flow 3: State synchronization (background sync)

```
DeviceRegistry (SwiftData) ← CloudKit sync (automatic via ModelConfiguration.cloudKitDatabase)
  Both devices share: known device list, last-used-on-device state
    → No manual CloudKit record management needed for history
    → CloudKit transport for SwitchSignal uses separate CKRecordZone (ephemeral, not SwiftData)
```

---

## Key Architectural Decisions

### Decision 1: Single target, platform-gated code

The Xcode project is already a single multi-platform target. Use `#if os(macOS)` / `#if os(iOS)` guards to separate IOBluetooth (macOS) from AVAudioSession (iOS). Shared business logic lives in files compiled on both platforms. This avoids duplicating the SwiftData models and SignalRouter.

**What this means for file structure:**
```
SyncBuds/
  Shared/
    Models/          (SwiftData: BluetoothDevice, SwitchSignal)
    SwitchCoordinator.swift
    SignalRouter.swift
    DeviceRegistry.swift
    NotificationPresenter.swift
  macOS/
    MenuBarController.swift
    BluetoothMonitor.swift      (IOBluetooth)
    BluetoothActuator.swift     (IOBluetooth)
  iOS/
    AudioSessionMonitor.swift   (AVAudioSession)
    iOSSwitchCoordinator.swift  (platform extensions)
```

### Decision 2: Mac as Bluetooth control center

IOBluetooth provides `IOBluetoothDevice.openConnection()` and `closeConnection()` — these work for A2DP/HFP profiles on macOS. iOS has no equivalent public API for classic Bluetooth audio profiles. This is the core asymmetry that drives the entire architecture.

**Confidence: HIGH** — This asymmetry is well-documented and is why Apple AirPods use a proprietary iCloud-side protocol for their own switching.

### Decision 3: Multipeer Connectivity as primary transport, CloudKit as fallback

Multipeer Connectivity (Bluetooth + WiFi) achieves 50-300ms round-trip latency when devices are nearby — acceptable for a "feels instant" switch. CloudKit push delivery can take 2-30+ seconds and requires internet. For a headphone switch, latency matters: user notices if they have to wait.

The `SignalRouter` should:
1. Attempt Multipeer first (both devices advertising/browsing simultaneously when app is active)
2. Fall back to CloudKit CKSubscription push if Multipeer session is not established within ~500ms
3. Always write a CloudKit record as a durable signal (handles the case where Mac app is closed and reopens)

**Confidence: MEDIUM** — Latency figures from training data; verify with real device testing.

### Decision 4: CloudKit for device history, NOT for switch signals

SwiftData + CloudKit sync (via `ModelConfiguration(cloudKitContainerIdentifier:)`) handles shared device history automatically. Switch signals are ephemeral coordination messages — use a separate private `CKRecordZone` with `CKQuerySubscription` and delete records after delivery. Do not use SwiftData for signals.

### Decision 5: iOS background constraints require push-wake architecture

iOS will suspend the app. To receive switch signals in background:
- `CKSubscription` triggers a silent push notification (APNs) that wakes the app for ~30 seconds
- Multipeer session is only active while app is in foreground (iOS suspends network sockets)
- Therefore: Multipeer is the fast path when iOS app is in foreground; CloudKit silent push is the always-works path

Require the **Background Modes** capability on iOS: `remote-notification` (for CloudKit push wake).

**Confidence: MEDIUM** — iOS background networking restrictions are well-known; specific behavior of Multipeer with suspended apps should be verified during implementation.

### Decision 6: IOBluetooth sandbox entitlement on macOS

macOS App Sandbox is enabled (`ENABLE_APP_SANDBOX = YES` in project.pbxproj). IOBluetooth access requires the `com.apple.security.device.bluetooth` entitlement. Without it, `IOBluetoothDevice` calls will silently fail or be denied.

**Confidence: HIGH** — This is a required entitlement, not optional.

---

## Patterns to Follow

### Pattern 1: Observer-based Bluetooth state (macOS)

```swift
// macOS BluetoothMonitor
IOBluetoothDevice.register(
    forConnectNotifications: self,
    selector: #selector(deviceConnected(_:device:))
)
// Iterate IOBluetoothDevice.pairedDevices() on startup
// Filter by device.classOfDevice to identify audio devices (A2DP class: 0x240404)
```

The `classOfDevice` bitmask identifies audio sink devices without inspecting profile UUIDs at scan time.

### Pattern 2: AVAudioSession route monitoring (iOS)

```swift
// iOS AudioSessionMonitor
NotificationCenter.default.addObserver(
    forName: AVAudioSession.routeChangeNotification,
    object: nil,
    queue: .main
) { notification in
    // Check reason: .newDeviceAvailable / .oldDeviceUnavailable
    // Check currentRoute.outputs for .bluetoothA2DP port type
}
```

This is the only reliable iOS mechanism to detect A2DP device connection without private APIs.

### Pattern 3: SignalRouter with async/await and transport fallback

```swift
actor SignalRouter {
    func send(_ signal: SwitchSignal) async throws {
        if multipeerTransport.hasActivePeer {
            try await multipeerTransport.send(signal)
            try await cloudKitTransport.write(signal) // durable backup
        } else {
            try await cloudKitTransport.write(signal) // triggers push
        }
    }
}
```

Using `actor` isolates transport state and prevents concurrent send races.

### Pattern 4: SwitchCoordinator state machine

States: `.idle` → `.requestingSend` → `.awaitingRelease` → `.connecting` → `.connected` → `.idle`

Keep the state machine explicit and small. Side effects (notifications, UI updates) happen on state transitions only, not scattered through event handlers. Use `@Observable` for UI reactivity.

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Polling IOBluetooth device state

**What:** Calling `IOBluetoothDevice.pairedDevices()` on a timer to detect changes.
**Why bad:** Wastes CPU, introduces latency, misses events between polls.
**Instead:** Use `IOBluetoothDevice.register(forConnectNotifications:selector:)` — callback-driven, no polling.

### Anti-Pattern 2: Using SwiftData for switch signals

**What:** Storing ephemeral `SwitchSignal` records in SwiftData / CloudKit sync store.
**Why bad:** CloudKit sync has no delivery guarantee timing — a stale signal from hours ago could trigger an unwanted switch after a device comes online.
**Instead:** Use a separate `CKRecordZone` for signals. Include a `timestamp` field and reject signals older than 30 seconds on the receiving end.

### Anti-Pattern 3: Assuming Multipeer is always available on iOS

**What:** Only implementing Multipeer transport, skipping CloudKit fallback.
**Why bad:** Multipeer requires iOS app to be in foreground. If Mac initiates while iOS app is backgrounded/suspended, the signal is lost.
**Instead:** Always write signal to CloudKit as the durable path. Use Multipeer as the speed optimization.

### Anti-Pattern 4: Blocking the main thread for IOBluetooth calls

**What:** Calling `IOBluetoothDevice.openConnection()` on the main/UI thread.
**Why bad:** Connection is asynchronous and can stall the menu bar UI for 2-10 seconds.
**Instead:** Call from a background Task; update UI state through `@Observable` or `@Published` after callback fires.

### Anti-Pattern 5: Single Xcode target with no platform guards

**What:** Writing IOBluetooth imports without `#if os(macOS)` guards.
**Why bad:** The project targets iOS — IOBluetooth does not exist on iOS and will fail to compile.
**Instead:** All IOBluetooth code in `macOS/` folder or wrapped in `#if os(macOS)`.

---

## Scalability Considerations

| Concern | At 1 device pair | At 2 device pairs | At N devices (future) |
|---------|-----------------|-------------------|-----------------------|
| Device registry | 1 SwiftData record | 2 records | Linear, no concern |
| Signal routing | 1 CloudKit zone | Same zone, filter by deviceMAC | Add device identifier to signal schema |
| IOBluetooth connections | 1 openConnection call | Sequential calls OK | Parallel calls untested, likely fine |
| Multipeer peers | 1 peer (iPhone) | Same | MCSession supports up to 8 peers |

Scalability is not a concern for personal use (2 devices, 1-3 headphones).

---

## Build Order Implications

Components have clear dependencies. Build in this order to avoid blocked work:

```
Phase 1 (Foundation):
  BluetoothDevice model (SwiftData)
  DeviceRegistry
  → No dependencies, all other components read from these

Phase 2 (Detection):
  macOS BluetoothMonitor (IOBluetooth read-only)
  iOS AudioSessionMonitor (AVAudioSession)
  → Depends on: BluetoothDevice model
  → Gate: Prove detection works before building actuation

Phase 3 (Communication):
  MultipeerTransport
  CloudKitTransport
  SignalRouter
  → Depends on: nothing from Phase 2 (pure messaging)
  → Can build in parallel with Phase 2

Phase 4 (Actuation):
  BluetoothActuator (IOBluetooth write — openConnection/closeConnection)
  → Depends on: BluetoothMonitor (to know current state)
  → This is highest-risk component; verify entitlements and sandbox first

Phase 5 (Coordination):
  SwitchCoordinator (ties Detection + Communication + Actuation together)
  → Depends on: all prior phases complete

Phase 6 (UI):
  MenuBarController + SwiftUI popover (macOS)
  iOS minimal view + notifications
  → Depends on: SwitchCoordinator (@Observable state to bind)
```

**Critical path:** Phase 4 (BluetoothActuator) is highest risk. IOBluetooth sandbox entitlements and the behavior of `openConnection`/`closeConnection` for A2DP profile should be validated as early as possible — ideally a spike during Phase 2, even before Phase 4 is formally started.

---

## Open Questions Requiring Phase-Specific Research

| Question | When to Investigate | Risk Level |
|----------|--------------------|-----------:|
| Does `IOBluetoothDevice.closeConnection()` fully release the audio profile, or does macOS hold the profile even after closing the HCI connection? | Phase 4 spike | HIGH |
| Can the iOS app reliably wake from a CloudKit silent push within 10 seconds while in deep background/locked screen? | Phase 3 | MEDIUM |
| Does `MCSession` between iOS (suspended) and macOS work, or does iOS suspension kill the transport? | Phase 3 | MEDIUM |
| Does the macOS App Sandbox allow IOBluetooth with just `com.apple.security.device.bluetooth`, or are additional entitlements needed for A2DP? | Phase 4 spike | HIGH |
| iOS 26 changes to background execution — any new capabilities or restrictions relevant to this use case? | Phase 2 | LOW |

---

## Sources

- Project context: `/root/SyncBuds/.planning/PROJECT.md` (HIGH confidence — first-party)
- Xcode project config: `/root/SyncBuds/SyncBuds.xcodeproj/project.pbxproj` (HIGH confidence — first-party)
- IOBluetooth `openConnection`/`closeConnection` behavior: training data (MEDIUM confidence — verify during Phase 4 spike)
- AVAudioSession `routeChangeNotification` for A2DP detection: training data (HIGH confidence — well-established pattern)
- Multipeer Connectivity cross-platform (iOS/macOS) support: training data (HIGH confidence — documented since iOS 7 / macOS 10.10)
- CloudKit `CKSubscription` silent push latency: training data (MEDIUM confidence — highly variable in practice)
- SwiftData + CloudKit sync via `ModelConfiguration(cloudKitContainerIdentifier:)`: training data (HIGH confidence — available since SwiftData introduction in iOS 17 / macOS 14)
- iOS background networking (Multipeer suspended): training data (MEDIUM confidence — verify with real device testing)
- `com.apple.security.device.bluetooth` entitlement for sandboxed macOS IOBluetooth: training data (HIGH confidence — required entitlement)
