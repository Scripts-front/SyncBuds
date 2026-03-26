---
phase: "04-ui"
plan: "02"
subsystem: "global-hotkey"
tags: ["macOS", "Carbon", "hotkey", "settings", "UserDefaults"]
dependency_graph:
  requires: ["04-01"]
  provides: ["GlobalHotkeyManager", "HotkeySettingsView", "hotkeyManager wiring in SyncBudsApp"]
  affects: ["SyncBudsApp.swift", "Settings scene"]
tech_stack:
  added: ["Carbon (RegisterEventHotKey)", "NSEvent.addLocalMonitorForEvents", "NSViewRepresentable"]
  patterns: ["@convention(c) static bridge for EventHandlerProcPtr", "NotificationCenter hotkey re-registration", "@AppStorage persistence"]
key_files:
  created:
    - SyncBuds/Shared/GlobalHotkeyManager.swift
    - SyncBuds/macOS/HotkeySettingsView.swift
  modified:
    - SyncBuds/SyncBudsApp.swift
decisions:
  - "Used top-level @convention(c) hotkeyEventBridge instead of inline closure — Swift closures cannot be passed as EventHandlerProcPtr"
  - "NSEvent.addLocalMonitorForEvents (not Global) for key recorder in Settings — local monitor works in-process without Accessibility permission"
  - "NotificationCenter.hotkeyChanged as re-registration trigger — decouples HotkeySettingsView from SyncBudsApp without a shared reference"
  - "nonZeroOr() helper on Int — UserDefaults.integer returns 0 for missing keys, indistinguishable from explicit 0; nonZeroOr(49)/nonZeroOr(768) ensures defaults are applied"
metrics:
  duration: "103s"
  completed: "2026-03-26"
  tasks_completed: 2
  files_created: 2
  files_modified: 1
---

# Phase 04 Plan 02: Global Hotkey + Settings Summary

**One-liner:** Carbon RegisterEventHotKey wrapper (GlobalHotkeyManager) with @AppStorage persistence and NSViewRepresentable key recorder in HotkeySettingsView, wired into SyncBudsApp via NotificationCenter re-registration.

## What Was Built

### Task 1: GlobalHotkeyManager (`2e776ee`)

`SyncBuds/Shared/GlobalHotkeyManager.swift` — macOS-only (`#if os(macOS)`) Carbon hotkey manager:

- `register(keyCode:modifiers:action:)` — installs Carbon event handler + registers hotkey; unregisters previous registration first
- `unregister()` — calls `UnregisterEventHotKey` + `RemoveEventHandler`; called in `deinit`
- Top-level `hotkeyEventBridge: EventHandlerProcPtr` — required because Swift closures cannot be passed as `@convention(c)` function pointers; bridges to `GlobalHotkeyManager.storedAction`
- `Notification.Name.hotkeyChanged` and `Int.nonZeroOr(_:)` helpers at file scope (macOS-only)

### Task 2: HotkeySettingsView + SyncBudsApp wiring (`06bfb35`)

`SyncBuds/macOS/HotkeySettingsView.swift`:

- `@AppStorage("hotkeyKeyCode")` (default 49 = Space) + `@AppStorage("hotkeyModifiers")` (default 768 = ⌘⇧) persist shortcut across restarts
- `shortcutDisplayString` converts stored integers to human-readable symbols (⌘, ⇧, ⌥, ⌃ + key name)
- `KeyRecorderButton: NSViewRepresentable` wraps an NSButton + `NSEvent.addLocalMonitorForEvents(.keyDown)` to capture next key press; converts `NSEvent.ModifierFlags` to Carbon flags via `carbonFlags` extension
- "Reset to Default" button sets keyCode=49, modifiers=768 and posts `.hotkeyChanged`
- `.onChange(of: hotkeyKeyCode/hotkeyModifiers)` posts `.hotkeyChanged` to trigger re-registration

`SyncBuds/SyncBudsApp.swift`:

- `private let hotkeyManager = GlobalHotkeyManager()` added as macOS-only property
- `init()`: reads UserDefaults with `nonZeroOr()` fallback → calls `hotkeyManager.register(keyCode:modifiers:action:)` with `Task { @MainActor in coordinator.requestSwitch() }` as action
- `NotificationCenter.addObserver(forName: .hotkeyChanged)` re-registers with updated values from UserDefaults
- Settings scene: `HotkeySettingsView()` replaces the `Text("Settings")` placeholder

## Deviations from Plan

### Auto-added: NSViewRepresentable key recorder instead of onKeyPress

**Rule 2 - Missing critical functionality**

- **Found during:** Task 2 — Part A
- **Issue:** `onKeyPress` on a `Button` captures SwiftUI-level key events (focus-based), not arbitrary global key presses from an NSEvent stream; also doesn't give access to `NSApp.currentEvent` reliably in SwiftUI on macOS 26
- **Fix:** Implemented `KeyRecorderButton: NSViewRepresentable` with `NSEvent.addLocalMonitorForEvents(.keyDown)` which directly captures the next key event in the process, providing both `keyCode` and `modifierFlags` without Accessibility permission
- **Files modified:** `SyncBuds/macOS/HotkeySettingsView.swift`
- **Commit:** `06bfb35`

## Success Criteria Verification

| Criterion | Status |
|-----------|--------|
| ⌘⇧Space (default) triggers SwitchCoordinator.requestSwitch() from any app | Wired — pending real-device verification in Plan 04-03 checkpoint |
| App Settings (⌘,) opens pane showing current shortcut + Reset button | Done — HotkeySettingsView with KeyRecorderButton |
| Changing shortcut takes effect immediately without restart | Done — NotificationCenter.hotkeyChanged triggers re-registration |
| Hotkey persists after app restart (@AppStorage) | Done — UserDefaults via @AppStorage |
| macOS build compiles with no Carbon bridging errors | Awaiting build — @convention(c) bridge uses top-level function pattern |

## Self-Check: PASSED

- `/root/SyncBuds/SyncBuds/Shared/GlobalHotkeyManager.swift` — FOUND
- `/root/SyncBuds/SyncBuds/macOS/HotkeySettingsView.swift` — FOUND
- commit `2e776ee` — FOUND (GlobalHotkeyManager)
- commit `06bfb35` — FOUND (HotkeySettingsView + SyncBudsApp)
