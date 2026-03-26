---
phase: 04-ui
plan: "01"
subsystem: ui-macos
tags: [menu-bar, macos, LSUIElement, MenuBarExtra, SwiftUI]
dependency_graph:
  requires:
    - Phase 03 SwitchCoordinator (switchState, requestSwitch)
    - Phase 02 MultipeerService (isConnectedToPeer, connectedPeerName, peerBluetoothStatus)
  provides:
    - MacMenuView struct (macOS dropdown menu content)
    - MenuBarExtra scene entry point (macOS)
    - LSUIElement config (no Dock icon on macOS)
  affects:
    - SyncBudsApp.swift (scene structure changed for macOS)
    - Info.plist (new LSUIElement key)
tech_stack:
  added:
    - MenuBarExtra (SwiftUI, macOS 13+)
    - menuBarExtraStyle(.menu)
    - Settings scene (macOS)
    - NSApp.terminate / NSApp.sendAction (AppKit)
  patterns:
    - "#if os(macOS) file-level guard for AppKit-only views"
    - "Environment injection inside MenuBarExtra content closure (not on scene modifier chain)"
    - "Dynamic SF Symbol icon bound to @Observable state"
key_files:
  created:
    - SyncBuds/macOS/MacMenuView.swift
  modified:
    - SyncBuds/SyncBudsApp.swift
    - SyncBuds/Info.plist
decisions:
  - "Settings scene contains placeholder Text — replaced by HotkeySettingsView in Plan 02"
  - "menuBarIconName uses == .switching (works because SwitchState has custom Equatable)"
  - "Environment injected on MacMenuView() inside MenuBarExtra closure — not on MenuBarExtra scene modifier (pitfall avoidance)"
  - "modelContainer also injected inside closure to satisfy SwiftData environment requirement"
metrics:
  duration: "69s"
  completed: "2026-03-26"
  tasks_completed: 3
  files_changed: 3
---

# Phase 04 Plan 01: macOS Menu Bar App Summary

**One-liner:** MenuBarExtra with dynamic headphones SF Symbol icon and native dropdown menu (peer status, headphone status, Switch button, Settings, Quit) — no Dock icon via LSUIElement.

## What Was Built

The macOS app now lives exclusively in the menu bar with no Dock icon or app switcher entry. Clicking the menu bar icon (headphones.circle / headphones.circle.fill / arrow.2.circlepath based on state) opens a native macOS dropdown menu via `MenuBarExtra` + `.menuBarExtraStyle(.menu)`.

The menu contains:
- Peer connection status line (greyed-out Text, non-interactive)
- Headphone ownership status line
- Switch Headphone button (disabled during switching/cooldown/error)
- Settings... (opens Settings window via NSApp.sendAction)
- Quit SyncBuds (mandatory — only quit path when LSUIElement = true)

iOS target is unchanged: `WindowGroup` + `ContentView()` in the `#else` branch.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add LSUIElement to Info.plist | 3feb729 | SyncBuds/Info.plist |
| 2 | Create MacMenuView — dropdown menu content | 8775896 | SyncBuds/macOS/MacMenuView.swift |
| 3 | Update SyncBudsApp — WindowGroup to MenuBarExtra on macOS | 43aea3f | SyncBuds/SyncBudsApp.swift |

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

- `Settings { Text("Settings").padding() }` in `SyncBudsApp.swift` (line 83-85) — placeholder Settings scene; replaced by `HotkeySettingsView()` in Plan 02 as noted in the plan.

## Self-Check: PASSED
