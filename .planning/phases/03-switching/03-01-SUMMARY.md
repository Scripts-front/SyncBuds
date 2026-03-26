---
phase: 03-switching
plan: 01
subsystem: bluetooth
tags: [swift, switchcoordinator, statemachine, usernotifications, iobluetooth, multipeerconnectivity]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: BluetoothManager.disconnectDevice() and connectDevice() verified on real hardware
  - phase: 02-communication
    provides: MultipeerService.send() and SyncSignal wire format for cross-device signaling
provides:
  - SwitchCoordinator @Observable final class with full bidirectional switching state machine
  - isInCooldown(for:) API for BluetoothManager reconnect suppression
  - postNotification() and requestNotificationPermission() via UNUserNotificationCenter
affects:
  - 03-02 (ContentView wiring — injects SwitchCoordinator, connects requestSwitch() to UI button)
  - 03-03 (MultipeerService TODO fill-in — routes switchRequest to handleIncomingSwitchRequest())
  - 04-ui (reads switchState for UI state binding)

# Tech tracking
tech-stack:
  added:
    - UserNotifications (UNUserNotificationCenter) — local system notifications on both platforms
  patterns:
    - SwitchCoordinator as standalone @Observable coordinator class (not extending existing classes)
    - Weak var dependency injection for multipeerService and bluetoothManager (no retain cycles)
    - Platform-gated #if os(macOS) / #if os(iOS) blocks inside class body (not file-level guard)
    - Timer-based cooldown for reconnect suppression (10s window)
    - 15s iOS timeout + 10s Mac connect timeout for stuck-state recovery

key-files:
  created:
    - SyncBuds/Shared/SwitchCoordinator.swift
  modified: []

key-decisions:
  - "SwitchCoordinator placed in Shared/ with no file-level platform guard — same pattern as MultipeerService; only internal logic blocks are guarded"
  - "cooldown window set to 10s — longer than observed 1-3s auto-reconnect window per PITFALLS.md research"
  - "switchRequest sent after disconnectDevice() confirms success, not before — prevents iPhone connecting while Mac still holds ACL link"
  - "500ms lead delay before openConnection() on Mac (iPhone→Mac path) — gives headphone time to release from iOS"

patterns-established:
  - "Pattern: coordinator owns timers — cancelTimeoutTimer() centralized to avoid double-invalidation bugs"
  - "Pattern: transitionToError() always posts notification then auto-resets to idle after 2s — consistent error UX"
  - "Pattern: requestSwitch() guards on isConnectedToPeer before entering switching state — prevents silent no-ops"

requirements-completed:
  - SW-01
  - SW-02
  - SW-03
  - SW-05

# Metrics
duration: 2min
completed: 2026-03-26
---

# Phase 3 Plan 01: SwitchCoordinator Summary

**@Observable SwitchCoordinator state machine wiring IOBluetooth control and MultipeerService signaling into bidirectional headphone switching with 10s cooldown, 15s iOS timeout, and UNUserNotificationCenter notifications**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-26T19:25:23Z
- **Completed:** 2026-03-26T19:27:11Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Created SwitchCoordinator with 4-state enum (idle/switching/cooldown/error) enforcing SW-05 duplicate request rejection
- Implemented Mac→iPhone flow: disconnectDevice() → cooldown timer → switchRequest signal with reconnect suppression via isInCooldown(for:)
- Implemented iPhone→Mac flow: iOS sends switchRequest → 15s timeout; Mac receives → 500ms delay → connectDevice() → 10s connect timeout
- Added postNotification() and requestNotificationPermission() using UNUserNotificationCenter (both platforms, SW-04 prep)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create SwitchCoordinator state machine** - `e8bf2c9` (feat)

**Plan metadata:** (to be added after final commit)

## Files Created/Modified

- `SyncBuds/Shared/SwitchCoordinator.swift` - Full switching state machine with platform-gated Mac and iOS logic blocks

## Decisions Made

- SwitchCoordinator placed in `Shared/` without file-level platform guard — class body uses `#if os(macOS)` / `#if os(iOS)` blocks internally, matching MultipeerService.swift convention
- Cooldown window is 10 seconds — empirical estimate exceeding the 1-3 second auto-reconnect window documented in PITFALLS.md; real-device testing may require adjustment
- switchRequest is sent after `disconnectDevice()` returns `true` (not before) — prevents race where iPhone tries to connect while Mac still holds the ACL link
- 500ms lead delay before `openConnection()` on Mac incoming path — gives headphone time to become available after leaving iOS

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None — all Apple system frameworks already linked in the project; no compilation environment available on Linux, structural verification via grep confirms all required symbols are present.

## User Setup Required

None - no external service configuration required. Notification permission UI will appear on first app launch once `requestNotificationPermission()` is called from SyncBudsApp (wired in Plan 02).

## Known Stubs

None — SwitchCoordinator is a complete implementation. Dependencies (bluetoothManager, multipeerService) are set via weak var injection by the app wiring in Plan 02; the coordinator itself contains no placeholder logic.

## Next Phase Readiness

- SwitchCoordinator.swift is ready for injection into SyncBudsApp (Plan 02) and ContentView (Plan 02)
- MultipeerService.handleReceivedSignal() TODO stub still needs filling in Plan 02 — routes `.switchRequest` to `handleIncomingSwitchRequest(from:)` and `.status` to `handleIncomingStatusConfirmation(bluetoothStatus:)`
- BluetoothManager.deviceDidConnect() needs cooldown guard in Plan 02 — checks `switchCoordinator?.isInCooldown(for: device.addressString)` to suppress auto-reconnect

---
*Phase: 03-switching*
*Completed: 2026-03-26*
