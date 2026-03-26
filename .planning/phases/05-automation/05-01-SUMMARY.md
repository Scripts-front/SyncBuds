---
phase: 05-automation
plan: "01"
subsystem: ios-automation
tags: [auto-switch, widget-state, scene-phase, app-group, multipeer]
dependency_graph:
  requires: [04-ui/04-02, 03-switching/03-02]
  provides: [widget-state-bridge, auto-switch-foreground-hook]
  affects: [SyncBudsApp, iOSContentView, MultipeerService]
tech_stack:
  added: [WidgetKit (iOS-only, conditional import), App Group UserDefaults]
  patterns: [TDD (Red-Green), #if os(iOS) platform guards, @AppStorage for opt-in toggle]
key_files:
  created:
    - SyncBuds/Shared/WidgetStateWriter.swift
    - SyncBudsTests/WidgetStateWriterTests.swift
    - SyncBudsTests/AutoSwitchTests.swift
  modified:
    - SyncBuds/iOS/iOSContentView.swift
    - SyncBuds/SyncBudsApp.swift
    - SyncBuds/Shared/MultipeerService.swift
decisions:
  - "autoSwitchEnabled defaults to false — opt-in is safer than opt-out for automated switching behavior"
  - "scenePhase onChange attached to WindowGroup scene (App level) not to iOSContentView — per RESEARCH.md Pattern 1 and Pitfall 3"
  - "WidgetStateWriter calls in MultipeerService wrapped in #if os(iOS) — macOS target has no App Group for widget sharing"
  - "WidgetCenter.shared.reloadTimelines() guarded by #if os(iOS) — WidgetKit not available on macOS"
  - "widget_ key prefix on all App Group keys — avoids collision with @AppStorage keys used by the main app"
metrics:
  duration: "~3 minutes"
  completed: "2026-03-26"
  tasks: 2
  files_changed: 6
---

# Phase 05 Plan 01: Auto-Switch + Widget State Bridge Summary

**One-liner:** iOS foreground auto-switch with opt-in toggle and App Group UserDefaults bridge for widget state.

## What Was Built

### Task 1: WidgetStateWriter + Unit Tests (TDD)

Created `SyncBuds/Shared/WidgetStateWriter.swift` — a lightweight struct that writes three keys to the App Group suite `group.com.syncbuds.shared`:

- `widget_isConnected` (Bool)
- `widget_peerBTStatus` (String)
- `widget_peerName` (String, empty string when nil)

WidgetKit import and `WidgetCenter.shared.reloadTimelines()` are wrapped in `#if os(iOS)` so the macOS target compiles cleanly without the WidgetKit framework.

Tests:
- `WidgetStateWriterTests.swift`: 6 `@Test` functions verifying UserDefaults write correctness for all three keys and nil-peerName handling
- `AutoSwitchTests.swift`: 5 `@Test` functions verifying the boolean guard chain in isolation (scenePhase is not injectable in unit tests)

### Task 2: UI + App Hook + MultipeerService Integration

**iOSContentView.swift:**
- Added `@AppStorage("autoSwitchEnabled") private var autoSwitchEnabled: Bool = false`
- Added "Automation" GroupBox card below the Switch Action Card with a Toggle and descriptive caption

**SyncBudsApp.swift:**
- Added `@Environment(\.scenePhase) private var scenePhase` at App struct level
- Added `@AppStorage("autoSwitchEnabled") private var autoSwitchEnabled = false` at App struct level
- Attached `.onChange(of: scenePhase)` to the iOS `WindowGroup` with 3-guard chain:
  1. `guard newPhase == .active`
  2. `guard autoSwitchEnabled`
  3. `guard multipeerService.peerBluetoothStatus == "connected"`
  — then calls `Task { @MainActor in switchCoordinator.requestSwitch() }`

**MultipeerService.swift:**
- Added `WidgetStateWriter.update()` at 3 call sites, each wrapped in `#if os(iOS)`:
  1. `.connected` — writes `isConnected: true` with current peerBluetoothStatus + peerName
  2. `.notConnected` — writes `isConnected: false, peerBTStatus: "unknown", peerName: nil`
  3. `handleReceivedSignal(.status)` — writes current connection state + received bluetoothStatus

## Commits

| Hash | Message |
|------|---------|
| 448ed02 | test(05-01): add failing tests for WidgetStateWriter and auto-switch guards |
| c394693 | feat(05-01): add WidgetStateWriter for App Group shared state bridge |
| f11bc2f | feat(05-01): auto-switch toggle, scenePhase hook, and widget state calls |

## Deviations from Plan

None — plan executed exactly as written. All files match the specification in the PLAN.md action blocks.

## Known Stubs

None. WidgetStateWriter writes real values to the App Group. The widget extension (Plan 02) does not exist yet, but the data bridge is fully functional — the write side is wired, the read side is Plan 02's responsibility.

Note: The App Group `group.com.syncbuds.shared` must be configured in the Xcode entitlements for both the main app target and (when created) the widget extension target. This is a provisioning configuration step, not a code stub.

## Self-Check

Files verified to exist:
- SyncBuds/Shared/WidgetStateWriter.swift — FOUND
- SyncBudsTests/WidgetStateWriterTests.swift — FOUND
- SyncBudsTests/AutoSwitchTests.swift — FOUND
- SyncBuds/iOS/iOSContentView.swift (modified) — FOUND
- SyncBuds/SyncBudsApp.swift (modified) — FOUND
- SyncBuds/Shared/MultipeerService.swift (modified) — FOUND

Commits verified: 448ed02, c394693, f11bc2f present in git log.

## Self-Check: PASSED
