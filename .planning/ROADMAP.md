# Roadmap: SyncBuds

## Overview

SyncBuds delivers automatic Bluetooth headphone switching between Mac and iPhone for any third-party device. The build order is driven by a hard dependency chain: the Mac-side IOBluetooth disconnect behavior must be proven before anything else is built on top of it, cross-device signaling must be verified end-to-end before a switching coordinator can use it, and UI is always the last layer. Five phases take the project from an empty Xcode scaffold to a fully functional menu bar app with automatic switching.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Foundation** - Entitlements, project structure, and verified Mac Bluetooth control (the load-bearing prototype)
- [ ] **Phase 2: Communication** - Cross-device signaling via Multipeer Connectivity (CloudKit deferred), with live connection status
- [ ] **Phase 3: Switching** - Bidirectional switching state machine with race condition handling and notifications
- [ ] **Phase 4: UI** - Mac menu bar app, iOS interface, and keyboard shortcut
- [ ] **Phase 5: Automation** - Automatic switching heuristics, iOS home screen widget, and battery display

## Phase Details

### Phase 1: Foundation
**Goal**: The Mac can reliably discover, connect, and disconnect a Bluetooth audio device, and this is proven before any other code depends on it
**Depends on**: Nothing (first phase)
**Requirements**: INF-01, INF-02, INF-03, INF-04, BT-01, BT-02, BT-03
**Success Criteria** (what must be TRUE):
  1. Mac app (signed bundle) enumerates all paired Bluetooth audio devices without returning an empty list
  2. Mac can programmatically disconnect a headphone and the audio profile fully releases (verified via System Settings — device disappears from connected list)
  3. Mac can reconnect the same headphone via code and audio resumes routing to it
  4. SwiftData device registry persists known headphones (name, MAC address, last-seen platform) across app launches
  5. iOS build compiles and runs with platform-gated code in place; no IOBluetooth symbols leak into iOS target
**Plans**: 4 plans

Plans:
- [x] 01-01-PLAN.md — Entitlements + platform-gate directory structure (INF-01, INF-02, INF-03)
- [x] 01-02-PLAN.md — BluetoothDevice SwiftData model, schema swap, remove Item placeholder (INF-04, BT-03)
- [x] 01-03-PLAN.md — BluetoothManager IOBluetooth spike + iOS AudioRouteMonitor (BT-01, BT-02)
- [ ] 01-04-PLAN.md — Test harness wiring + real-device human verification checkpoint

### Phase 2: Communication
**Goal**: Mac and iPhone can reliably signal each other via Multipeer Connectivity, and that signal delivery is verified on real devices on the same local network
**Depends on**: Phase 1
**Requirements**: COM-01, COM-02 (deferred), COM-03 (deferred), COM-04 (deferred), BT-04
**Notes**: COM-02/COM-03/COM-04 are deferred — no Apple Developer Account. Only Multipeer (COM-01) is implemented. No SignalRouter abstraction needed yet (D-03).
**Success Criteria** (what must be TRUE):
  1. A signal sent from Mac arrives on iPhone within 500ms when both are on the same Wi-Fi network (Multipeer path)
  2. Both Mac and iOS apps display live connection status showing which device currently has the headphone (BT-04)
  3. When iOS app is backgrounded, Mac shows "Peer offline" — foreground-only limitation is accepted
**Plans**: 5 plans

Plans:
- [x] 02-01-PLAN.md — SyncSignal Codable struct + unit tests (COM-01, COM-02/03/04 deferred stubs)
- [x] 02-02-PLAN.md — Entitlements + Info.plist for Multipeer permissions (COM-01)
- [x] 02-03-PLAN.md — MultipeerService implementation (COM-01)
- [x] 02-04-PLAN.md — Wire BluetoothManager + AudioRouteMonitor + ContentView status display (COM-01, BT-04)
- [ ] 02-05-PLAN.md — Real-device verification checkpoint (COM-01, BT-04)

### Phase 3: Switching
**Goal**: The headphone switches between Mac and iPhone bidirectionally when the user requests it, including full race condition handling
**Depends on**: Phase 2
**Requirements**: SW-01, SW-02, SW-03, SW-04, SW-05
**Success Criteria** (what must be TRUE):
  1. Tapping switch on Mac causes the headphone to disconnect from Mac and become available for iPhone to connect (Mac→iPhone direction works end-to-end)
  2. Tapping switch on iPhone causes Mac to connect the headphone (iPhone→Mac direction works end-to-end)
  3. After a switch, the headphone does not auto-reconnect to the releasing device during the cooldown window
  4. A system notification appears on both devices indicating switch success or failure
  5. A second switch request while one is in progress does not corrupt state (switches remain serialized)
**Plans**: 3 plans

Plans:
- [x] 03-01-PLAN.md — SwitchCoordinator state machine (SW-01, SW-02, SW-03, SW-05)
- [x] 03-02-PLAN.md — Wire coordinator into MultipeerService, BluetoothManager, SyncBudsApp, ContentView (SW-03, SW-04, SW-05)
- [ ] 03-03-PLAN.md — Real-device verification checkpoint (SW-03, SW-04, SW-05)

### Phase 4: UI
**Goal**: The app has a native, minimal interface on both platforms that makes switching accessible without opening a full window
**Depends on**: Phase 3
**Requirements**: UI-01, UI-02, UI-03, UI-04
**Success Criteria** (what must be TRUE):
  1. Mac app appears only in the menu bar (no Dock icon); clicking the menu bar icon opens a dropdown showing connected device, status, and a switch button
  2. A configurable global keyboard shortcut on Mac triggers a switch without touching the mouse
  3. iOS app shows connection status and a switch button in a clean, widget-style card interface
  4. Menu bar icon visually reflects current state (headphone connected vs. not connected)
**Plans**: 3 plans

Plans:
- [x] 04-01-PLAN.md — LSUIElement + MacMenuView + SyncBudsApp MenuBarExtra (UI-01, UI-02)
- [ ] 04-02-PLAN.md — GlobalHotkeyManager (Carbon) + HotkeySettingsView + wire into SyncBudsApp (UI-03)
- [ ] 04-03-PLAN.md — iOSContentView widget-style cards + iOS WindowGroup update (UI-04)

### Phase 5: Automation
**Goal**: The app switches automatically based on audio activity and provides power-user shortcuts that remove all friction from headphone switching
**Depends on**: Phase 4
**Requirements**: SW-06, BT-05, UI-05
**Success Criteria** (what must be TRUE):
  1. When audio playback starts on iPhone while the headphone is on Mac, the app automatically initiates a switch without any user action
  2. The iOS home screen widget shows connection status and triggers a switch with one tap, without opening the app
  3. Headphone battery level is displayed in the Mac popover and iOS app when the connected device reports it
**Plans**: TBD
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 3/4 | In Progress|  |
| 2. Communication | 1/5 | In Progress|  |
| 3. Switching | 2/3 | In Progress|  |
| 4. UI | 1/3 | In Progress|  |
| 5. Automation | 0/TBD | Not started | - |
