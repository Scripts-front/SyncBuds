# Phase 1: Foundation - Research

**Researched:** 2026-03-25
**Domain:** macOS IOBluetooth, SwiftData device registry, multiplatform project structure, entitlements
**Confidence:** HIGH (IOBluetooth API from Apple official docs + real-world open-source verification; SwiftData from Apple official docs; entitlements from Apple official docs + community verification)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** Apple Developer Account does NOT exist yet — user will create it in parallel. CloudKit entitlements should be configured in code/project but cannot be tested until the account is active.
- **D-02:** Bluetooth entitlement (`com.apple.security.device.bluetooth`) must be added to macOS entitlements file.
- **D-03:** CloudKit container should be defined in entitlements even though it can't be tested yet — this prevents restructuring later.
- **D-04:** App should be set up with App Sandbox enabled (macOS) with Bluetooth entitlement.
- **D-05:** Spike must be comprehensive — not just connect/disconnect, but also: enumerate all paired Bluetooth audio devices, detect connection state in real-time, and verify that `closeConnection()` fully releases the A2DP profile.
- **D-06:** User has a non-Apple Bluetooth headphone available for real device testing.
- **D-07:** Success criteria: after `closeConnection()`, the headphone disappears from macOS System Settings connected list and becomes available for iPhone to connect.
- **D-08:** Device registry data model should include at minimum: name, MAC address, last seen timestamp, last connected platform. Claude can add more fields if useful for switching logic.
- **D-09:** Multiple headphones can be saved, but only one is active for switching at a time.
- **D-10:** Active device selection is Claude's discretion — the currently connected headphone is the natural default.
- **D-11:** Must use `#if os(macOS)` / `#if os(iOS)` for platform-specific code. IOBluetooth code must not leak into iOS target.

### Claude's Discretion

- Device registry data model fields beyond the minimum (name, MAC, last seen, platform)
- Active device selection mechanism (automatic vs manual)
- Project folder structure and module organization
- Whether to use a dedicated BluetoothService class or keep it simpler for the spike

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| INF-01 | Bluetooth entitlement (`com.apple.security.device.bluetooth`) configured for macOS sandbox | Entitlement format, file location, and Info.plist key verified via Apple docs and community tools |
| INF-02 | CloudKit entitlements and container configured in Apple Developer portal | Entitlement keys documented; cannot test until Developer Account exists (D-01 blocker) |
| INF-03 | Platform-gated code via `#if os(macOS)` / `#if os(iOS)` in shared Swift files | Pattern verified; recommended folder structure determined |
| INF-04 | SwiftData models for device registry and switch history | `@Model`, `ModelContainer`, `ModelContext` APIs verified from Apple docs; `BluetoothDevice` schema designed |
| BT-01 | Mac app detects all paired Bluetooth audio devices (A2DP/HFP) via IOBluetooth | `IOBluetoothDevice.pairedDevices()` + `classOfDevice` bitmask filter for audio sinks documented |
| BT-02 | iOS app detects current audio route and connected Bluetooth device via AVAudioSession | `AVAudioSession.routeChangeNotification` + `currentRoute.outputs` filter for `.bluetoothA2DP`; iOS-only, #if-gated |
| BT-03 | App persists known devices across launches (name, MAC address, last seen) | SwiftData `@Model` class `BluetoothDevice` with all required fields |
</phase_requirements>

---

## Summary

Phase 1 delivers the project's load-bearing infrastructure: entitlements, platform-gated project structure, SwiftData device registry, and a comprehensive IOBluetooth spike. Everything downstream depends on the spike result — specifically, whether `closeConnection()` fully releases the A2DP/HFP audio profile so the headphone becomes available to iPhone.

The good news: IOBluetooth's `closeConnection()` is the correct and only public mechanism for programmatic Bluetooth audio device disconnection on macOS. Open-source tools (BluetoothConnector, blueutil) confirm this is the right API. The subtlety is that a single `closeConnection()` call may not immediately succeed — real-world implementations use a retry loop (up to 10 calls, 500ms apart, checking `isConnected()` between calls). The spike must use this retry pattern and confirm via System Settings that the device disappears.

The entitlement situation is clear: `com.apple.security.device.bluetooth` is required for `IOBluetoothDevice.pairedDevices()` to return anything in a sandboxed app. Without it, the method returns an empty array silently. The entitlement file must be created and wired to the target — it does not exist yet in the project.

SwiftData is the right persistence choice (already scaffolded, modern Swift API, zero overhead for simple device records). The existing `Item.swift` placeholder model is replaced by a `BluetoothDevice` model.

**Primary recommendation:** Build the IOBluetooth spike first, using a retry loop on `closeConnection()`, and confirm A2DP profile release on real hardware before touching any other code. All other Phase 1 tasks are infrastructure and have no unknowns.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| IOBluetooth | macOS 10.2+ (system, macOS only) | Enumerate paired devices, connect, disconnect, state notifications | Only public Apple API for programmatic A2DP/HFP device control on macOS; no alternative |
| SwiftData | iOS 17+ / macOS 14+ (system) | Device registry persistence | Already scaffolded in project; modern Swift API; @Model macro, automatic migration |
| SwiftUI | iOS 17+ / macOS 14+ (system) | Placeholder view while spike runs | Already in project; no changes needed this phase |
| AVAudioSession | iOS 17+ (system, iOS only) | Detect Bluetooth audio route on iOS | Only public iOS API for detecting A2DP headphone connection state |

### No External Dependencies

Per CLAUDE.md: "Tech stack: Swift + SwiftUI + SwiftData, no external dependencies." All frameworks are Apple system frameworks. No `Package.swift` additions needed this phase.

**Xcode framework linking required:**
```
Target: SyncBuds (macOS build)
  Frameworks, Libraries, and Embedded Content:
    + IOBluetooth.framework (macOS only — add via conditional platform filter)
```

---

## Architecture Patterns

### Recommended Project Structure

```
SyncBuds/
├── Shared/
│   └── Models/
│       └── BluetoothDevice.swift    # SwiftData @Model (both platforms)
├── macOS/
│   └── BluetoothManager.swift       # IOBluetooth spike code (#if os(macOS))
└── iOS/
    └── AudioRouteMonitor.swift      # AVAudioSession detection (#if os(iOS))

SyncBuds.xcodeproj/
└── SyncBuds/
    ├── SyncBuds.entitlements        # macOS sandbox + bluetooth entitlement (new file)
    └── (Info.plist additions)       # NSBluetoothAlwaysUsageDescription
```

Note: The project currently uses Xcode file-system synchronization. Subdirectory creation in `SyncBuds/` automatically creates Xcode groups. Create `Shared/Models/`, `macOS/`, and `iOS/` as physical directories.

### Pattern 1: Platform-Gated Bluetooth Code

**What:** Wrap all IOBluetooth imports and usage in `#if os(macOS)` blocks; wrap AVAudioSession in `#if os(iOS)` blocks. Keep the `BluetoothDevice` SwiftData model in a shared file with no platform guards — it compiles identically on both platforms.

**When to use:** Any file that touches IOBluetooth, AVAudioSession, or other platform-exclusive frameworks.

**Example:**
```swift
// macOS/BluetoothManager.swift
#if os(macOS)
import IOBluetooth
import Foundation

final class BluetoothManager {
    // IOBluetooth code here — safe, iOS will never compile this file
}
#endif
```

```swift
// iOS/AudioRouteMonitor.swift
#if os(iOS)
import AVFoundation

final class AudioRouteMonitor {
    // AVAudioSession code here
}
#endif
```

For files that MUST exist on both platforms (e.g., a shared protocol), use inline guards:
```swift
// Shared protocol — no guard needed
protocol BluetoothMonitoring {
    func startMonitoring()
    func stopMonitoring()
}
```

### Pattern 2: IOBluetooth Device Enumeration

**What:** Use `IOBluetoothDevice.pairedDevices()` to get all paired devices, then filter by `classOfDevice` to identify audio sink devices (A2DP class bitmask). Register for connect/disconnect notifications using `register(forConnectNotifications:selector:)` — do not poll.

**When to use:** BluetoothManager initialization and whenever device list needs refresh.

**Example:**
```swift
// Source: Apple IOBluetooth docs + verified via BluetoothAudioReceiver open source
#if os(macOS)
import IOBluetooth

final class BluetoothManager: NSObject {

    // Audio sink class of device bitmask — identifies A2DP speakers and headphones
    // Major class 0x04 (Audio/Video), minor class varies; check major class only
    private let audioMajorClass: UInt32 = 0x000400

    func pairedAudioDevices() -> [IOBluetoothDevice] {
        guard let allPaired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            return []
        }
        return allPaired.filter { device in
            (device.classOfDevice & 0x001F00) == audioMajorClass
        }
    }

    func startMonitoringConnections() {
        IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(deviceConnected(_:device:))
        )
    }

    @objc private func deviceConnected(
        _ notification: IOBluetoothUserNotification,
        device: IOBluetoothDevice
    ) {
        // Register for this specific device's disconnect notification
        device.register(
            forDisconnectNotification: self,
            selector: #selector(deviceDisconnected(_:fromDevice:))
        )
        // Update DeviceRegistry
    }

    @objc private func deviceDisconnected(
        _ notification: IOBluetoothUserNotification,
        fromDevice device: IOBluetoothDevice
    ) {
        // Update state
    }
}
#endif
```

### Pattern 3: IOBluetooth closeConnection() with Retry Loop

**What:** `closeConnection()` may not immediately succeed on the first call. Production-quality open-source tools (BluetoothConnector) use a retry loop: call `closeConnection()` up to 10 times with 500ms delays, checking `isConnected()` between each attempt.

**When to use:** Every programmatic Bluetooth disconnect in this project.

**Critical:** This is the spike's primary test. Call this, then verify in System Settings that the device disappears.

**Example:**
```swift
// Source: Verified against lapfelix/BluetoothConnector open-source implementation
#if os(macOS)
func disconnectDevice(_ device: IOBluetoothDevice) async -> Bool {
    var attempts = 0
    let maxAttempts = 10
    let delayMicroseconds: UInt32 = 500_000  // 500ms

    while attempts < maxAttempts && device.isConnected() {
        let result = device.closeConnection()
        if result != kIOReturnSuccess {
            // Log result but continue retrying — closeConnection can return
            // non-success even when the disconnect eventually completes
        }
        usleep(delayMicroseconds)
        attempts += 1
    }

    return !device.isConnected()
}
#endif
```

### Pattern 4: SwiftData BluetoothDevice Model

**What:** Replace the placeholder `Item.swift` with a `BluetoothDevice` model using `@Model`. Include minimum fields from D-08 plus recommended additions for switching logic.

**When to use:** Single model for device registry; persists across launches.

**Example:**
```swift
// Source: Apple SwiftData docs (verified)
import Foundation
import SwiftData

@Model
final class BluetoothDevice {
    // Required minimum (D-08)
    var name: String
    var addressString: String        // IOBluetoothDevice.addressString — "XX:XX:XX:XX:XX:XX"
    var lastSeen: Date
    var lastConnectedPlatform: String  // "mac" | "ios" | "unknown"

    // Recommended additions for switching logic
    var isActiveDevice: Bool         // D-09/D-10: only one is true at a time
    var firstSeenDate: Date
    var connectionCount: Int         // useful for "most used" heuristic

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
```

**ModelContainer update in SyncBudsApp.swift:**
```swift
let schema = Schema([
    BluetoothDevice.self,  // replaces Item.self
])
```

### Pattern 5: iOS Audio Route Detection (BT-02)

**What:** Use `AVAudioSession.routeChangeNotification` to detect when a Bluetooth A2DP device connects or disconnects. Check `currentRoute.outputs` for `.bluetoothA2DP` port type.

**When to use:** iOS-only `AudioRouteMonitor` class. Wrapped in `#if os(iOS)`.

**Example:**
```swift
// Source: Apple AVAudioSession docs (well-established pattern, HIGH confidence)
#if os(iOS)
import AVFoundation

final class AudioRouteMonitor {

    func startMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(routeChanged(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    @objc private func routeChanged(_ notification: Notification) {
        guard let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        let route = AVAudioSession.sharedInstance().currentRoute
        let hasBluetoothAudio = route.outputs.contains {
            $0.portType == .bluetoothA2DP || $0.portType == .bluetoothHFP
        }

        switch reason {
        case .newDeviceAvailable:
            if hasBluetoothAudio { /* headphone connected */ }
        case .oldDeviceUnavailable:
            /* headphone disconnected — check userInfo for previous route */
            break
        default:
            break
        }
    }
}
#endif
```

### Pattern 6: Entitlements File Structure

**What:** macOS sandboxed app requires a `.entitlements` file wired to the build target. The file must include `com.apple.security.device.bluetooth` (INF-01) and CloudKit container identifiers (INF-02, stub only — cannot test until Developer Account exists per D-01).

**Required entitlements file: `SyncBuds/SyncBuds.entitlements`**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Required: App Sandbox (D-04) -->
    <key>com.apple.security.app-sandbox</key>
    <true/>

    <!-- Required: Bluetooth access for IOBluetooth (D-02, INF-01) -->
    <key>com.apple.security.device.bluetooth</key>
    <true/>

    <!-- CloudKit — configured now, cannot test until Developer Account exists (D-01, D-03, INF-02) -->
    <key>com.apple.developer.icloud-containers-environment</key>
    <string>Production</string>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    </array>
    <key>com.apple.developer.ubiquity-kvstore-identifier</key>
    <string>$(TeamIdentifierPrefix)$(CFBundleIdentifier)</string>
</dict>
</plist>
```

**Info.plist addition (macOS):**
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>SyncBuds needs Bluetooth to detect and manage headphone connections.</string>
```

### Anti-Patterns to Avoid

- **Calling `closeConnection()` once and assuming success:** Real-world behavior requires a retry loop. A single call often does not complete the disconnect, especially with audio playing.
- **Importing IOBluetooth in shared files:** Even a single `import IOBluetooth` outside a `#if os(macOS)` guard causes the iOS build to fail. Keep IOBluetooth code in dedicated macOS-only files.
- **Polling `IOBluetoothDevice.pairedDevices()` on a timer:** Use `register(forConnectNotifications:selector:)` for event-driven monitoring. Polling wastes CPU and misses events between intervals.
- **Relying on `isConnected()` for immediate disconnect confirmation:** The state flag updates asynchronously. Use the retry loop that polls `isConnected()` between `closeConnection()` calls.
- **Using CoreBluetooth (CBCentralManager) to find audio headphones:** CoreBluetooth is BLE-only. Classic Bluetooth audio devices (A2DP/HFP) do not appear in BLE scans.
- **Skipping entitlement on sandboxed builds:** `pairedDevices()` returns an empty array silently on sandboxed macOS without `com.apple.security.device.bluetooth`. This looks like a bug in the device enumeration code.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Device connection state tracking | Custom state machine polling `isConnected()` | `IOBluetoothDevice.register(forDisconnectNotification:selector:)` | Notification-driven; no polling; provided by framework |
| Bluetooth device enumeration | Custom scan loop | `IOBluetoothDevice.pairedDevices()` | Retrieves OS-managed paired device list without radio scanning |
| Data persistence across launches | Manual file I/O or UserDefaults for complex records | SwiftData `@Model` | Already scaffolded; handles migrations, concurrency, thread safety |
| Audio route detection on iOS | Custom polling of audio state | `AVAudioSession.routeChangeNotification` | System-level notification; zero overhead; standard Apple pattern |
| Bluetooth permission prompt | Custom UI or entitlement workaround | `NSBluetoothAlwaysUsageDescription` + `com.apple.security.device.bluetooth` | macOS TCC handles the prompt automatically on first use |

**Key insight:** IOBluetooth's disconnect behavior has edge cases (timing, retry loops) that are well-understood by the community. Follow existing open-source implementations (BluetoothConnector) rather than improvising disconnect logic.

---

## Runtime State Inventory

Step 2.5: SKIPPED — This is a greenfield phase. No rename/refactor/migration in scope. The existing `Item.swift` placeholder model will be replaced (not renamed), so no stored data migration is needed — there are no existing SwiftData records to preserve.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode | All iOS/macOS development | Assumed present | 26.3 (per STACK.md) | None — required |
| macOS real device | IOBluetooth spike (D-06) | Assumed present | macOS 26.2 (per STACK.md) | None — simulator cannot test IOBluetooth |
| Non-Apple Bluetooth headphone | IOBluetooth spike (D-06) | Confirmed (D-06) | Any | None — required for spike verification |
| Apple Developer Account | CloudKit testing (INF-02) | NOT YET (D-01) | — | Code/entitlements configured, tests deferred |
| IOBluetooth.framework | BT-01 | System framework on macOS | macOS 10.2+ | None — only public API for A2DP control |
| AVAudioSession | BT-02 | System framework on iOS | iOS 3.0+ | None — only API for audio route detection |

**Missing dependencies with no fallback:**
- Apple Developer Account: CloudKit cannot be tested until account exists. Entitlements are configured in code but CloudKit container will not be provisioned. Phase 1 success criteria do not include CloudKit testing — this is correct per D-01.

**Missing dependencies with fallback:**
- None for Phase 1 scope (CloudKit testing is deferred by design, not a gap).

---

## Common Pitfalls

### Pitfall 1: Empty pairedDevices() in Sandboxed Build
**What goes wrong:** `IOBluetoothDevice.pairedDevices()` returns `nil` or empty array even though devices are paired.
**Why it happens:** Sandboxed macOS app is missing the `com.apple.security.device.bluetooth` entitlement. The failure is silent — no crash, no error, just an empty list.
**How to avoid:** Create `SyncBuds.entitlements` with the Bluetooth entitlement before writing any IOBluetooth code. Test as a signed app bundle — Xcode-launched apps have elevated permissions that hide this bug in development.
**Warning signs:** Works in Xcode debug, empty list when run as signed `.app` bundle.

### Pitfall 2: closeConnection() Appears to Succeed but Audio Profile Remains
**What goes wrong:** `closeConnection()` returns `kIOReturnSuccess` but the headphone still appears in System Settings connected list and audio continues routing through it.
**Why it happens:** The ACL connection closure and audio profile (A2DP) release are not atomic. `closeConnection()` closes the baseband link, but the macOS CoreAudio HAL may still hold the audio route briefly. Additionally, the first call may not complete the full disconnect.
**How to avoid:** Use the retry loop (up to 10 calls, 500ms apart, checking `isConnected()`). The spike MUST verify by checking System Settings, not just by checking the return code. D-07 explicitly requires this verification.
**Warning signs:** `isConnected()` returns false but audio is still routing; headphone still visible in System Settings.

### Pitfall 3: IOBluetooth Code Leaks into iOS Build
**What goes wrong:** iOS build fails with "No such module 'IOBluetooth'" or "Cannot find type 'IOBluetoothDevice' in scope."
**Why it happens:** `import IOBluetooth` or any IOBluetooth type reference in a file compiled for both platforms without a `#if os(macOS)` guard.
**How to avoid:** Keep all IOBluetooth code in `SyncBuds/macOS/` subdirectory files that are wrapped with `#if os(macOS)`. Never put `import IOBluetooth` in a shared file.
**Warning signs:** Build error on iOS scheme immediately after adding any Bluetooth code.

### Pitfall 4: Headphone Classifier Misses Devices
**What goes wrong:** `pairedDevices()` returns devices but the audio filter (`classOfDevice` bitmask) excludes the user's headphone, returning an empty audio device list.
**Why it happens:** The `classOfDevice` bitmask for audio devices covers many minor classes. A too-narrow filter (e.g., only checking for specific headphone minor class) may miss some devices.
**How to avoid:** Filter on major device class only (bits 8-12, value 0x04 for Audio/Video). Do not filter on minor class during Phase 1 spike. Log ALL paired devices with their `classOfDevice` values before filtering — this data is essential for debugging.
**Warning signs:** User's headphone paired but not appearing in enumeration result.

### Pitfall 5: Entitlement Added but Not Wired to Build Target
**What goes wrong:** `SyncBuds.entitlements` file exists but Xcode doesn't use it — `CODE_SIGN_ENTITLEMENTS` build setting is not set.
**Why it happens:** Creating the file in the filesystem doesn't automatically register it with Xcode's code signing. The build setting must be set manually or via Xcode's target Signing & Capabilities panel.
**How to avoid:** After creating the entitlements file, verify in `project.pbxproj` that `CODE_SIGN_ENTITLEMENTS = SyncBuds/SyncBuds.entitlements;` appears in the target's build settings. Or add it via Xcode > Target > Signing & Capabilities > + (add capability).
**Warning signs:** Entitlements file exists, Bluetooth entitlement is in it, but `pairedDevices()` still returns empty array.

### Pitfall 6: Model Container Crashes at Launch After Schema Change
**What goes wrong:** App crashes with fatalError at `ModelContainer` initialization after `Item` is replaced by `BluetoothDevice`.
**Why it happens:** If the device has an existing SwiftData store from the old schema (e.g., from running the app previously), the new schema is incompatible and migration fails.
**How to avoid:** Since `Item` was only a placeholder and no real data was stored, delete the app from the test device/simulator before launching with the new schema. For development-phase schema changes, `isStoredInMemoryOnly: true` can also be used to bypass migration.
**Warning signs:** `fatalError("Could not create ModelContainer: ...")` at launch, particularly on devices that previously ran the app.

---

## Code Examples

Verified patterns from official sources and open-source tools:

### IOBluetooth: Enumerate Paired Audio Devices
```swift
// Source: Apple IOBluetooth docs (pairedDevices()) + classOfDevice filter pattern
#if os(macOS)
import IOBluetooth

func pairedAudioDevices() -> [IOBluetoothDevice] {
    // Requires com.apple.security.device.bluetooth entitlement
    guard let all = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
        return []
    }
    // Major device class 0x04 = Audio/Video (bits 8-12 of classOfDevice)
    return all.filter { ($0.classOfDevice & 0x001F00) == 0x000400 }
}
#endif
```

### IOBluetooth: Disconnect with Retry Loop
```swift
// Source: Verified against lapfelix/BluetoothConnector open-source implementation
#if os(macOS)
import IOBluetooth

func disconnectDevice(_ device: IOBluetoothDevice) -> Bool {
    guard device.isConnected() else { return true }

    var attempts = 0
    while attempts < 10 && device.isConnected() {
        _ = device.closeConnection()
        usleep(500_000)  // 500ms
        attempts += 1
    }
    return !device.isConnected()
}
#endif
```

### IOBluetooth: Connect
```swift
// Source: Apple IOBluetooth docs (openConnection())
#if os(macOS)
import IOBluetooth

func connectDevice(_ device: IOBluetoothDevice) -> Bool {
    guard !device.isConnected() else { return true }
    let result = device.openConnection()
    return result == kIOReturnSuccess
}
#endif
```

### IOBluetooth: Register for Connect Notifications (Global)
```swift
// Source: Apple IOBluetooth docs (register(forConnectNotifications:selector:))
#if os(macOS)
import IOBluetooth

class BluetoothManager: NSObject {
    private var connectNotification: IOBluetoothUserNotification?

    func startMonitoring() {
        connectNotification = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(handleConnectNotification(_:device:))
        )
    }

    @objc func handleConnectNotification(
        _ notification: IOBluetoothUserNotification,
        device: IOBluetoothDevice
    ) {
        // Also register for this device's disconnect
        device.register(
            forDisconnectNotification: self,
            selector: #selector(handleDisconnectNotification(_:fromDevice:))
        )
    }

    @objc func handleDisconnectNotification(
        _ notification: IOBluetoothUserNotification,
        fromDevice device: IOBluetoothDevice
    ) {
        // device disconnected
    }
}
#endif
```

### SwiftData: BluetoothDevice Model
```swift
// Source: Apple SwiftData docs (@Model, ModelContainer, ModelContext)
import Foundation
import SwiftData

@Model
final class BluetoothDevice {
    var name: String
    var addressString: String        // e.g. "aa:bb:cc:dd:ee:ff"
    var lastSeen: Date
    var lastConnectedPlatform: String  // "mac" | "ios" | "unknown"
    var isActiveDevice: Bool
    var firstSeenDate: Date
    var connectionCount: Int

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
```

### SwiftUI: Updated ModelContainer Registration
```swift
// Replaces Item.self with BluetoothDevice.self in SyncBudsApp.swift
let schema = Schema([BluetoothDevice.self])
let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| NSStatusItem + NSMenu for menu bar | SwiftUI `MenuBarExtra` | macOS 13 (2022) | Simpler code; Phase 4 will use this — no impact on Phase 1 |
| Core Data | SwiftData | iOS 17 / macOS 14 (2023) | Already scaffolded; use SwiftData `@Model` |
| Single `closeConnection()` call | Retry loop (10x, 500ms delay) | macOS Monterey (2021) timing issue confirmed | Required pattern for reliable disconnect |
| `IOBluetoothDevice -disconnect` (Obj-C) | `closeConnection()` (Swift) | N/A — `disconnect` is not in the Swift API surface | Use `closeConnection()` only; no Swift-accessible `disconnect` method |

**Deprecated/outdated:**
- `NSBluetoothPeripheralUsageDescription`: Deprecated in iOS 13 / macOS — use `NSBluetoothAlwaysUsageDescription` only.
- `IOBluetoothDevice.favoriteDevices()`: Do not use — returns user's "favorites" list, not all paired audio devices. Use `pairedDevices()`.

---

## Project Constraints (from CLAUDE.md)

| Directive | Impact on Phase 1 |
|-----------|-------------------|
| No external dependencies | All Bluetooth, persistence, and UI via Apple system frameworks only. No Swift packages to add. |
| Swift + SwiftUI + SwiftData only | No Objective-C files; IOBluetooth is an ObjC framework but has Swift bindings — use Swift syntax throughout. |
| iOS cannot programmatically disconnect audio (A2DP/HFP) | Architecture constraint: iOS code in this phase is detection-only (AVAudioSession). No connect/disconnect on iOS side. |
| Use `#if os(macOS)` / `#if os(iOS)` | IOBluetooth must be in macOS-only guarded files. AVAudioSession in iOS-only files. SwiftData models are unguarded (shared). |
| Personal use: functional > polished | Spike implementation doesn't need UI polish. A test view or console output confirming device enumeration is sufficient. |
| Entry points: GSD commands only | Not a coding convention — this is a workflow constraint for the developer, not the code itself. |

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (existing in `SyncBudsTests/SyncBudsTests.swift`) |
| Config file | None — Xcode test target configuration in `project.pbxproj` |
| Quick run command | `xcodebuild test -scheme SyncBuds -destination 'platform=macOS' -only-testing:SyncBudsTests` |
| Full suite command | `xcodebuild test -scheme SyncBuds -destination 'platform=macOS'` |

**Note:** IOBluetooth calls require real Bluetooth hardware and a signed, sandboxed app bundle. They cannot be unit-tested via `xcodebuild test` without real device access. Spike verification (D-07) is a manual step — run the app, check System Settings. Unit tests cover the data layer (SwiftData model) and compilation (platform guards).

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| INF-01 | Bluetooth entitlement present in signed build | Manual (Bluetooth prompt appears on first launch) | N/A | Wave 0 creates entitlements file |
| INF-02 | CloudKit entitlement keys present in code | Build verification | Build succeeds with CloudKit keys in entitlements | Wave 0 creates entitlements file |
| INF-03 | iOS build compiles with no IOBluetooth symbols | Build test | `xcodebuild build -scheme SyncBuds -destination 'platform=iOS Simulator,name=iPhone 16'` | ✅ existing target |
| INF-04 | BluetoothDevice model persists across launches | Unit test | `xcodebuild test -scheme SyncBuds -destination 'platform=macOS' -only-testing:SyncBudsTests/BluetoothDeviceTests` | Wave 0 |
| BT-01 | pairedDevices() returns audio devices (non-empty) | Manual (requires real hardware + signed bundle) | N/A — hardware dependent | N/A |
| BT-02 | AVAudioSession detects A2DP route on iOS | Manual (requires real iPhone + headphone) | N/A — hardware dependent | N/A |
| BT-03 | BluetoothDevice persists name, MAC, lastSeen | Unit test | `xcodebuild test -scheme SyncBuds -destination 'platform=macOS' -only-testing:SyncBudsTests/BluetoothDeviceTests` | Wave 0 |

### Sampling Rate

- **Per task commit:** `xcodebuild build -scheme SyncBuds -destination 'platform=macOS'` (macOS build green) AND `xcodebuild build -scheme SyncBuds -destination 'platform=iOS Simulator,name=iPhone 16'` (iOS build green — no IOBluetooth leakage)
- **Per wave merge:** `xcodebuild test -scheme SyncBuds -destination 'platform=macOS'` (full test suite)
- **Phase gate:** Both platform builds green + manual IOBluetooth spike verification on real hardware before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `SyncBudsTests/BluetoothDeviceTests.swift` — covers INF-04, BT-03 (SwiftData model round-trip: create, persist, reload)
- [ ] No test framework install needed — Swift Testing already in `SyncBudsTests/SyncBudsTests.swift`

---

## Open Questions

1. **Does `closeConnection()` fully release the A2DP audio profile on the user's specific headphone?**
   - What we know: `closeConnection()` closes the ACL baseband link. Open-source tools confirm a retry loop is needed. The PITFALLS.md notes that audio profile release is not guaranteed.
   - What's unclear: Whether the profile releases fully on the user's non-Apple headphone model, and whether a single `closeConnection()` attempt (with retries) is sufficient or if additional HFP disconnect logic is needed.
   - Recommendation: The spike (D-05) must test this on the actual headphone (D-06) and confirm via System Settings (D-07). If `closeConnection()` with the retry loop is insufficient, the fallback is to explore sending an HFP disconnect command via `IOBluetoothRFCOMMChannel` — but do not commit to this until the simpler path is proven to fail.

2. **Does macOS 26.2 introduce any new IOBluetooth restrictions or permission changes?**
   - What we know: macOS Sequoia tightened runtime security protections (per WebSearch). The project targets macOS 26.2, which post-dates the knowledge cutoff (August 2025).
   - What's unclear: Whether additional entitlements or TCC permissions beyond `com.apple.security.device.bluetooth` are required on macOS 26.2.
   - Recommendation: On first signed app launch, check System Settings > Privacy & Security > Bluetooth to confirm the app appears. If `pairedDevices()` returns empty despite the entitlement, file a Feedback report and try running unsandboxed temporarily to isolate the issue.

3. **Is `isActiveDevice` the right mechanism for single-active-device selection (D-09/D-10)?**
   - What we know: D-10 says currently-connected headphone is the natural default; D-09 says only one is active for switching at a time.
   - What's unclear: Whether to compute "active" dynamically from IOBluetooth connection state or persist it via the `isActiveDevice` flag.
   - Recommendation: Store `isActiveDevice` as a persisted flag (simplest for Phase 1); update it when the connected device changes. Dynamic computation from IOBluetooth is more accurate but adds complexity — defer to Phase 2.

---

## Sources

### Primary (HIGH confidence)
- Apple IOBluetooth docs: `closeConnection()`, `openConnection()`, `pairedDevices()`, `register(forConnectNotifications:selector:)` — verified via Apple Developer Documentation site
- Apple SwiftData docs: `@Model`, `ModelContainer`, `ModelContext`, `@Attribute` — verified via Apple JSON API docs
- Apple `com.apple.security.device.bluetooth` entitlement doc: verified via Apple Developer Documentation site

### Secondary (MEDIUM confidence)
- [lapfelix/BluetoothConnector](https://github.com/lapfelix/BluetoothConnector) — open-source Swift CLI using `closeConnection()` with 10-attempt retry loop; confirms production pattern
- [imnotbink/BluetoothAudioReceiver](https://github.com/imnotbink/BluetoothAudioReceiver) — open-source Swift app using `openConnection()` / `closeConnection()` + Bluetooth entitlement requirement
- [toy/blueutil issue #58](https://github.com/toy/blueutil/issues/58) — confirms macOS Monterey timing issue requiring retry/wait-for-disconnect pattern
- Multiple WebSearch results confirming `com.apple.security.device.bluetooth` is required for sandboxed `pairedDevices()` to return non-empty array

### Tertiary (LOW confidence)
- `classOfDevice` bitmask value `0x000400` for Audio/Video major class — from training data; verify by logging actual device values during spike

---

## Metadata

**Confidence breakdown:**
- IOBluetooth API (pairedDevices, openConnection, closeConnection, notifications): HIGH — Apple docs + open-source verification
- Entitlements structure: HIGH — Apple docs + community confirmation
- closeConnection() retry loop requirement: HIGH — confirmed by multiple open-source implementations
- classOfDevice bitmask for audio filter: MEDIUM — training data; verify in spike
- macOS 26.2 specific behavior: LOW — post-dates knowledge cutoff; verify on first run
- SwiftData @Model, ModelContainer: HIGH — Apple JSON API docs verified
- AVAudioSession route monitoring: HIGH — well-established pattern, Apple docs

**Research date:** 2026-03-25
**Valid until:** 2026-04-25 (30-day estimate; stable APIs, but macOS 26.2-specific behavior should be re-verified if any IOBluetooth calls fail unexpectedly)
