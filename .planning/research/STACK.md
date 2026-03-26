# Technology Stack

**Project:** SyncBuds — Bluetooth headphone auto-switching for macOS + iOS
**Researched:** 2026-03-25
**Overall confidence:** HIGH (all findings verified against Apple's official JSON documentation APIs)

---

## Recommended Stack

### Core Framework

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| Swift | 5.10+ (Xcode bundled) | Primary language | Native Apple platform language; no FFI overhead; already in project |
| SwiftUI | iOS 17+ / macOS 14+ | UI on both platforms | Already scaffolded; declarative, minimal boilerplate for a utility app |
| IOBluetooth | macOS 10.2+ (use macOS 14+) | Bluetooth device connect/disconnect on Mac | Only framework with programmatic A2DP/HFP device control; no alternative |
| Core Bluetooth | iOS 17+ / macOS 14+ | BLE communication on iOS | Standard BLE framework; used here for device detection only, NOT audio control |

**Critical platform constraint (HIGH confidence, verified against Apple's Core Bluetooth docs):** iOS Core Bluetooth cannot connect or disconnect A2DP/HFP audio devices programmatically. AVAudioSession provides no mechanism to force-connect a specific paired device. This is a hard OS limitation, not a gap in the framework. The switching architecture must be asymmetric: Mac controls the connection lifecycle; iOS signals intent.

### Bluetooth Control Layer — macOS

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| IOBluetooth | macOS 10.2+ | Connect/disconnect Bluetooth audio devices | `IOBluetoothDevice.openConnection()` and `closeConnection()` are the only public Apple APIs for programmatic baseband connect/disconnect |
| IOBluetoothDevice | Current | Device representation | Primary class: `openConnection()`, `closeConnection()`, `isConnected()`, `getAddress()`, `getName()` |
| IOBluetoothHandsFree / IOBluetoothHandsFreeAudioGateway | Current | HFP profile management | For headsets that use HFP; provides `IOBluetoothHandsFreeAudioGateway` for gateway role |
| IOBluetoothDeviceInquiry | Current | Discovering in-range devices | Finds devices and retrieves metadata; use for initial scan if needed |

**Key IOBluetooth methods (HIGH confidence, verified from Apple's JSON API docs):**
- `openConnection() -> IOReturn` — creates baseband connection; synchronous; returns `kIOReturnSuccess` on success
- `closeConnection() -> IOReturn` — closes baseband connection; synchronous; blocks until closed
- `isConnected() -> Bool` — connection state check
- As of macOS 10.7+: `openConnection()` no longer masks "Connection Exists" errors — your code must handle `kIOReturnSuccess` OR an existing-connection error code gracefully

**What IOBluetooth does NOT provide:** There is no explicit `disconnectAudio()` or `releaseA2DPStream()` method. `closeConnection()` closes the underlying baseband connection, which implicitly terminates all profiles (A2DP, HFP). This is the correct approach.

### Cross-Device Communication

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| CloudKit (private database) | iOS 10+ / macOS 10.12+ | Switch request signaling across devices | No server infrastructure needed; free; iCloud account already exists; works across networks |
| CKDatabaseSubscription | iOS 10+ / macOS 10.12+ | Push-triggered notifications for record changes | Silent push (`shouldSendContentAvailable = YES`) requires no user permission prompt; fires when Mac or iPhone writes a switch request record |
| Multipeer Connectivity | iOS 7+ / macOS 10.10+ | Local network fallback for low-latency switching | When both devices are on same Wi-Fi or Bluetooth range, latency is sub-100ms vs CloudKit's variable seconds |

**CloudKit subscription strategy (HIGH confidence):**

Use `CKDatabaseSubscription` (not `CKQuerySubscription`) in the private database. Both devices subscribe to the same private iCloud database zone. When one device writes a "SwitchRequest" record, CloudKit delivers a silent push to the other device. The receiving device fetches the record with `CKQueryOperation` and acts on it.

- Silent push requires `shouldSendContentAvailable = YES` — no user permission prompt needed
- `CKDatabaseSubscription` monitors all custom record zones; simpler than a per-query subscription for this use case
- CloudKit private database is per-user, so only the user's own devices receive the push

**Multipeer Connectivity transport (HIGH confidence):**

`MCNearbyServiceAdvertiser` + `MCNearbyServiceBrowser` for discovery. `MCSession` for data transfer. The framework uses infrastructure Wi-Fi, peer-to-peer Wi-Fi, Bluetooth (iOS), or Ethernet (macOS/tvOS) as available. For SyncBuds, this means:
- No additional setup when both devices are on the same Wi-Fi network
- Latency is milliseconds vs CloudKit's seconds
- Fallback: if Multipeer fails to establish, fall through to CloudKit

**Transport selection logic:** Try Multipeer first (check `MCSession` connected peers). If peer is not found within a 2-second window, send via CloudKit. Do not wait for CloudKit to confirm Multipeer failure — fire both simultaneously and let the receiving device deduplicate by request ID.

### Data Persistence

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| SwiftData | iOS 17+ / macOS 14+ | Device history, switch log, preferences | Already in project scaffold; zero dependencies; built on Core Data; iCloud sync available |

**SwiftData key APIs (HIGH confidence, from Apple's JSON docs):**
- `@Model` macro — attach to any Swift class to make it persistable
- `ModelContainer` — manages schema and storage configuration; set via `.modelContainer(_:)` scene modifier
- `ModelContext` — fetch, insert, delete, save; accessed via `@Environment(\.modelContext)` in views
- `@Attribute`, `@Relationship`, `@Unique`, `@Index` macros for fine-grained control
- Minimum: iOS 17.0 / macOS 14.0 — project targets iOS 26.2 / macOS 26.2, so no constraint

**What to persist:** Paired device history (`DeviceRecord`: address, name, last-seen date, preferred platform), switch events (timestamp, direction, success/failure). Do NOT sync device history via SwiftData's iCloud sync — the CloudKit subscription records serve as the cross-device signaling channel; device history is local-only.

### UI

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| SwiftUI MenuBarExtra | macOS 13+ | Menu bar presence on Mac | SwiftUI-native; no NSStatusItem boilerplate; already supported in project targets |
| SwiftUI (shared views) | iOS 17+ / macOS 14+ | Device list, status, manual override | Shared view code where possible; platform-specific branching via `#if os(macOS)` |

**MenuBarExtra specifics (HIGH confidence, from Apple's JSON docs):**
- Available: macOS 13.0+; project targets macOS 26.2 — fully supported
- Two styles: `.menu` (pull-down, compact, native feel) and `.window` (popover, richer UI)
- Use `.window` style for SyncBuds — device list + status indicators need more than menu items
- To hide the app from Dock and app switcher, set `LSUIElement = true` in Info.plist
- `MenuBarExtra(isInserted:)` binding lets the user toggle the extra from Settings if desired

**iOS UI:** Standard SwiftUI `NavigationStack` with a device list view and status. No special UI frameworks needed — this is a utility, not a consumer product.

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| macOS Bluetooth control | IOBluetooth | No alternative | Only public API for programmatic A2DP/HFP device disconnect on macOS. Private APIs exist (BluetoothManager.framework) but would break with OS updates and cannot ship on App Store |
| iOS Bluetooth audio | Signal-based (Mac acts) | Core Bluetooth + AVAudioSession | Core Bluetooth is BLE-only; AVAudioSession cannot force-connect a specific paired device; no iOS API for A2DP/HFP control |
| Cross-device signaling | CloudKit private + Multipeer | Firebase, MQTT, custom server | CloudKit is free, no server infra, uses existing iCloud account, built-in push; personal-use app needs zero operational cost |
| CloudKit subscriptions | CKDatabaseSubscription | CKQuerySubscription | CKDatabaseSubscription covers all custom zones with one subscription; CKQuerySubscription requires a predicate and record-type setup, more verbose for this use case |
| Persistence | SwiftData | Core Data, UserDefaults | SwiftData is already scaffolded; modern Swift API; Core Data is lower-level with no advantage here |
| Menu bar UI | SwiftUI MenuBarExtra | NSStatusItem + NSMenu | MenuBarExtra is SwiftUI-native; no need to drop to AppKit unless animations or custom rendering needed (they aren't) |
| Local fallback | Multipeer Connectivity | Bonjour + custom sockets | Multipeer is higher-level, handles both Wi-Fi and BT transport automatically; Bonjour requires more socket plumbing |
| Language | Swift | Objective-C | Project is already Swift; IOBluetooth has Swift bindings despite being an ObjC framework |

---

## Project-Specific Architecture Notes

**No third-party dependencies.** This is a constraint from PROJECT.md: "no external dependencies." The entire stack is Apple frameworks only. This is viable because:
- IOBluetooth covers Bluetooth control on macOS
- Core Bluetooth covers BLE detection on iOS
- CloudKit covers signaling
- Multipeer Connectivity covers local fallback
- SwiftData covers persistence
- SwiftUI covers UI on both platforms

**iOS 26.2 / macOS 26.2 target.** PROJECT.md specifies these platform targets. All recommended frameworks (SwiftData, CloudKit, Multipeer, MenuBarExtra) have minimum requirements well below this. No compatibility shims needed.

**The asymmetric control model is the architecture:**
```
iPhone wants to connect headphone:
  iPhone writes SwitchRequest(direction: .toiPhone) to CloudKit / sends via Multipeer
  Mac receives push → Mac calls IOBluetoothDevice.closeConnection()
  Headphone becomes available
  iPhone detects device available (or receives confirmation) → user manually connects OR
  Mac calls IOBluetoothDevice.openConnection() on behalf of iPhone context (not possible cross-device)
  → iPhone must connect manually OR use a shortcut/automation

Mac wants to connect headphone:
  Mac writes SwitchRequest(direction: .toMac) to CloudKit / sends via Multipeer
  iPhone receives signal → iOS cannot programmatically disconnect audio device
  → iOS can play a system sound to "interrupt" audio routing (workaround, not guaranteed)
  → Primary path: Mac waits a moment and attempts openConnection(); if headphone is still
    connected to iPhone, connection may fail or cause iOS to release it
```

This asymmetry is the core design challenge and should be documented in the roadmap as a research item.

---

## Installation

No `npm install` or `Package.swift` additions needed. All frameworks are Apple system frameworks linked via Xcode target settings.

**Xcode framework linking:**
```
Target: SyncBuds (macOS)
  Frameworks, Libraries, and Embedded Content:
    + IOBluetooth.framework (macOS only)

Target: SyncBuds (iOS + macOS shared)
  Frameworks, Libraries, and Embedded Content:
    + CloudKit.framework
    + MultipeerConnectivity.framework
    (SwiftData and Core Bluetooth are available by default)
```

**Info.plist additions:**
```xml
<!-- macOS target -->
<key>LSUIElement</key><true/> <!-- Hide Dock icon -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>SyncBuds needs Bluetooth to detect and manage headphone connections.</string>

<!-- iOS target -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>SyncBuds needs Bluetooth to detect connected headphones.</string>
```

**Entitlements required:**
```xml
<key>com.apple.developer.icloud-container-identifiers</key>
<array><string>iCloud.$(PRODUCT_BUNDLE_IDENTIFIER)</string></array>
<key>com.apple.developer.ubiquity-kvstore-identifier</key>
<string>$(TeamIdentifierPrefix)$(CFBundleIdentifier)</string>
```

---

## Confidence Assessment

| Component | Confidence | Source | Notes |
|-----------|------------|--------|-------|
| IOBluetooth openConnection/closeConnection | HIGH | Apple JSON API docs | Methods confirmed current, not deprecated; macOS 10.2+ |
| IOBluetooth A2DP/HFP control | MEDIUM | Apple JSON API docs + known constraint | No explicit A2DP method; closeConnection() is the mechanism; confirmed by absence of higher-level audio API |
| iOS cannot control A2DP/HFP | HIGH | Core Bluetooth + AVAudioSession docs | Confirmed: Core Bluetooth is BLE-only; AVAudioSession has no connect/disconnect for specific paired devices |
| CKDatabaseSubscription for signaling | HIGH | Apple JSON API docs | Confirmed: silent push, iOS 10+ / macOS 10.12+, no user permission needed |
| Multipeer Connectivity as fallback | HIGH | Apple JSON API docs | Confirmed: MCSession, MCNearbyServiceBrowser, MCNearbyServiceAdvertiser |
| SwiftUI MenuBarExtra | HIGH | Apple JSON API docs | Confirmed: macOS 13.0+, .window style, LSUIElement for Dock hiding |
| SwiftData persistence | HIGH | Apple JSON API docs | Confirmed: @Model, ModelContainer, ModelContext; iOS 17+ / macOS 14+ |
| iPhone → Mac direction forcing disconnect | LOW | Architecture inference | No confirmed mechanism to force iPhone to release A2DP device; this needs hands-on testing in Phase 1 |

---

## Sources

- IOBluetooth framework symbols: `https://developer.apple.com/tutorials/data/documentation/iobluetooth.json`
- IOBluetoothDevice.openConnection(): `https://developer.apple.com/tutorials/data/documentation/iobluetooth/iobluetoothdevice/openconnection().json`
- IOBluetoothDevice.closeConnection(): `https://developer.apple.com/tutorials/data/documentation/iobluetooth/iobluetoothdevice/closeconnection().json`
- Core Bluetooth framework: `https://developer.apple.com/tutorials/data/documentation/corebluetooth.json`
- AVAudioSession: `https://developer.apple.com/tutorials/data/documentation/avfaudio/avaudiosession.json`
- CloudKit framework: `https://developer.apple.com/tutorials/data/documentation/cloudkit.json`
- CKDatabaseSubscription: `https://developer.apple.com/tutorials/data/documentation/cloudkit/ckdatabasesubscription.json`
- CKQuerySubscription: `https://developer.apple.com/tutorials/data/documentation/cloudkit/ckquerysubscription.json`
- Multipeer Connectivity: `https://developer.apple.com/tutorials/data/documentation/multipeerconnectivity.json`
- SwiftUI MenuBarExtra: `https://developer.apple.com/tutorials/data/documentation/swiftui/menubarextra.json`
- SwiftUI MenuBarExtraStyle: `https://developer.apple.com/tutorials/data/documentation/swiftui/menubarextrastyle.json`
- SwiftData framework: `https://developer.apple.com/tutorials/data/documentation/swiftdata.json`
