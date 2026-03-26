---
phase: 01-foundation
plan: 03
subsystem: bluetooth
tags: [iobluetooth, avaudiosession, macos, ios, swiftdata, bluetooth, swift]

requires:
  - phase: 01-02
    provides: BluetoothDevice @Model with addressString stable key — used by upsertToRegistry in BluetoothManager

provides:
  - BluetoothManager.swift — macOS IOBluetooth spike: enumerate, connect, disconnect (retry loop), real-time notifications, SwiftData upsert
  - AudioRouteMonitor.swift — iOS A2DP/HFP Bluetooth audio route detection via AVAudioSession

affects: [01-04, 02-cloudkit, 03-switching]

tech-stack:
  added:
    - IOBluetooth.framework (macOS system framework — must be linked in Xcode target)
    - AVFoundation (iOS system framework — already available; used here for audio route monitoring)
  patterns:
    - "#if os(macOS) / #if os(iOS) file-level platform guards — entire file wrapped, not just imports"
    - "closeConnection() retry loop (10 attempts, 500ms usleep intervals) — mirrors lapfelix/BluetoothConnector pattern"
    - "IOBluetoothUserNotification retention in array — prevents ARC from deallocating active notification tokens"
    - "upsertToRegistry via FetchDescriptor<BluetoothDevice> predicate — addressString as stable upsert key"

key-files:
  created:
    - SyncBuds/macOS/BluetoothManager.swift
    - SyncBuds/iOS/AudioRouteMonitor.swift
  modified: []

key-decisions:
  - "usleep() used for retry delay instead of Task.sleep — keeps IOBluetooth retry loop simple; async is on disconnectDevice() caller boundary only"
  - "audioMajorClass bitmask 0x000400 hardcoded as named constant — documents the (classOfDevice & 0x001F00) == 0x000400 filter for Audio/Video devices"
  - "disconnectNotifications array retains IOBluetoothUserNotification tokens — releasing them would silently stop all disconnect callbacks"
  - "AVAudioSessionRouteChangePreviousRouteKey used for oldDeviceUnavailable — disconnected device is in userInfo, not currentRoute"

patterns-established:
  - "Platform folder split: SyncBuds/macOS/ and SyncBuds/iOS/ — each file entirely wrapped in its #if os() guard"
  - "Print-based spike instrumentation — intentional for real-device testing in Plan 04 (D-06)"

requirements-completed: [BT-01, BT-02, BT-03]

duration: 4min
completed: 2026-03-26
---

# Phase 1 Plan 03: IOBluetooth Spike + iOS Audio Route Monitor Summary

**BluetoothManager.swift delivers the four-capability IOBluetooth spike (enumerate/connect/disconnect-with-retry/real-time-notifications + SwiftData upsert); AudioRouteMonitor.swift adds iOS A2DP/HFP route detection — both files entirely platform-gated with no cross-target symbol leakage**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-03-26T03:34:07Z
- **Completed:** 2026-03-26T03:38:11Z
- **Tasks:** 2 completed
- **Files modified:** 0 modified, 2 created

## Accomplishments

- Created BluetoothManager.swift at SyncBuds/macOS/ with all four D-05 spike capabilities: enumerate paired audio devices via classOfDevice bitmask, connect via openConnection(), disconnect via 10-attempt closeConnection() retry loop, real-time state via IOBluetoothDevice connect/disconnect notifications
- Implemented SwiftData upsertToRegistry() that inserts new BluetoothDevice records or updates lastSeen/connectionCount on reconnect — satisfies BT-03
- Created AudioRouteMonitor.swift at SyncBuds/iOS/ with AVAudioSession.routeChangeNotification observer handling both newDeviceAvailable and oldDeviceUnavailable cases, plus initial state capture on startMonitoring()
- Both files are entirely wrapped in their respective #if os() guards — no platform symbol leakage possible

## Task Commits

Each task was committed atomically:

1. **Task 1: BluetoothManager — enumerate, connect, disconnect, notifications, SwiftData upsert** - `b1bdf7f` (feat)
2. **Task 2: AudioRouteMonitor — iOS Bluetooth audio route detection** - `8a1b69c` (feat)

## Files Created

- `SyncBuds/macOS/BluetoothManager.swift` — IOBluetooth spike: pairedAudioDevices(), connectDevice(), disconnectDevice() async with retry loop, startMonitoringConnections(), upsertToRegistry(_:in:)
- `SyncBuds/iOS/AudioRouteMonitor.swift` — AVAudioSession route monitor: startMonitoring(), stopMonitoring(), isBluetoothAudioActive (Bool), connectedPortName (String?)

## BluetoothManager Public API

| Method | Signature | Purpose |
|--------|-----------|---------|
| pairedAudioDevices | `() -> [IOBluetoothDevice]` | Enumerate paired audio devices (classOfDevice filter) |
| upsertToRegistry | `(_ device: IOBluetoothDevice, in context: ModelContext)` | Insert or update BluetoothDevice in SwiftData |
| connectDevice | `(_ device: IOBluetoothDevice) -> Bool` | openConnection() with success logging |
| disconnectDevice | `(_ device: IOBluetoothDevice) async -> Bool` | 10-attempt retry loop with 500ms delays |
| startMonitoringConnections | `()` | Register global connect notification + per-device disconnect notification |

## AudioRouteMonitor Public API

| Property/Method | Type | Purpose |
|----------------|------|---------|
| isBluetoothAudioActive | `private(set) Bool` | True when A2DP or HFP device is on current output route |
| connectedPortName | `private(set) String?` | Human-readable port name of connected Bluetooth audio device |
| startMonitoring() | `func` | Register for routeChangeNotification + capture current state |
| stopMonitoring() | `func` | Remove observer from NotificationCenter |

## IOBluetooth Framework Linking

IOBluetooth.framework must be linked in the Xcode target:

1. Select the SyncBuds project in the navigator
2. Select the SyncBuds target
3. Go to "Frameworks, Libraries, and Embedded Content" (General tab)
4. Click "+" and search for "IOBluetooth"
5. Add IOBluetooth.framework

**Without this step**, `import IOBluetooth` will cause "No such module 'IOBluetooth'" at build time even though the framework ships with macOS. This step requires Xcode on the developer machine and cannot be performed via CLI.

## Build Verification Note

Build cannot be verified via CLI — no Xcode toolchain present in this environment. Content verification was performed via grep:

- `#if os(macOS)` guard present at file start in BluetoothManager.swift
- `#if os(iOS)` guard present at file start in AudioRouteMonitor.swift
- `closeConnection()` appears 7 times in BluetoothManager.swift (loop body, retry, success logging)
- `openConnection()`, `pairedDevices()`, `forConnectNotifications`, `forDisconnectNotification` all confirmed
- `upsertToRegistry`, `ModelContext`, `FetchDescriptor<BluetoothDevice>` all confirmed
- `routeChangeNotification`, `bluetoothA2DP`, `bluetoothHFP`, `oldDeviceUnavailable`, `newDeviceAvailable` all confirmed
- `IOBluetooth` NOT present in AudioRouteMonitor.swift (correct)
- `CoreBluetooth` NOT present as import in BluetoothManager.swift (comment only, no import)

## Decisions Made

- `usleep()` for retry delay — simpler than `Task.sleep` at the IOBluetooth layer; `disconnectDevice()` is marked `async` to allow callers to await without blocking main thread
- Print-based instrumentation is intentional — surfaces spike results in Xcode console during Plan 04 real-device testing (D-06)
- `disconnectNotifications` array retained as instance variable — IOBluetoothUserNotification tokens must be retained or callbacks stop firing

## Deviations from Plan

None — plan executed exactly as written. Both files match the exact content specified in the plan's `<action>` blocks.

## Known Stubs

None — both files are complete implementations with no placeholder data, hardcoded empty values, or TODO markers.

## Next Phase Readiness

- BluetoothManager.swift is ready for Plan 04 real-device testing: connect a non-Apple headphone, call pairedAudioDevices(), call disconnectDevice(), verify device disappears from System Settings (D-07)
- upsertToRegistry() is ready to consume a real ModelContext once the app launches on a test Mac
- AudioRouteMonitor.swift is ready for Plan 04 iOS testing: connect headphone to iPhone, verify isBluetoothAudioActive == true

---
*Phase: 01-foundation*
*Completed: 2026-03-26*
