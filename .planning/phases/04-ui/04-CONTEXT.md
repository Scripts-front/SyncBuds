# Phase 4: UI - Context

**Gathered:** 2026-03-26
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase delivers the native UI for both platforms: Mac menu bar app (MenuBarExtra) with no Dock icon, iOS app with clean widget-style interface, and a configurable global keyboard shortcut on Mac.

</domain>

<decisions>
## Implementation Decisions

### Menu Bar (Mac)
- **D-01:** Mac app uses MenuBarExtra with icon + dropdown menu style (not popover).
- **D-02:** No Dock icon — set LSUIElement = true in Info.plist.
- **D-03:** Claude's discretion on menu content — should include at minimum: headphone name, connection status, switch button, peer status.
- **D-04:** Menu bar icon should visually reflect connected vs disconnected state.

### iOS Layout
- **D-05:** iOS app should use a widget-style card layout — clean, modern, with rounded corners and clear visual hierarchy.
- **D-06:** User wants the switch available in Control Center and as a home screen Widget too — Widget (UI-05) is Phase 5 scope, but the app UI should be designed with this in mind.
- **D-07:** Claude's discretion on specific layout — should be visually appealing and functional.

### Keyboard Shortcut (Mac)
- **D-08:** Global keyboard shortcut on Mac must be configurable by the user (not hard-coded).
- **D-09:** Claude's discretion on default shortcut and settings UI for changing it.

### Claude's Discretion
- Menu bar dropdown content and styling
- iOS card/widget visual design details
- Default keyboard shortcut value
- Settings UI for keyboard shortcut configuration
- Menu bar icon design (SF Symbols)
- Color scheme and visual polish level

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Codebase
- `SyncBuds/SyncBudsApp.swift` — App entry point, service initialization
- `SyncBuds/ContentView.swift` — Current test harness UI (to be replaced)
- `SyncBuds/Shared/SwitchCoordinator.swift` — Switch state machine (UI binds to this)
- `SyncBuds/Shared/MultipeerService.swift` — Peer connection status (UI binds to this)
- `SyncBuds/macOS/BluetoothManager.swift` — Bluetooth state (UI binds to this)
- `SyncBuds/Info.plist` — Needs LSUIElement for no-Dock-icon

### Research
- `.planning/research/STACK.md` — MenuBarExtra API details, .window style
- `.planning/research/FEATURES.md` — ToothFairy menu bar pattern, keyboard shortcuts

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SwitchCoordinator.switchState` — Observable state for button label/enabled state
- `MultipeerService.isConnectedToPeer` / `connectedPeerName` / `peerBluetoothStatus` — Observable peer status
- `BluetoothManager.pairedAudioDevices()` — Device info for display
- `BluetoothDevice` SwiftData model — Persisted device list

### Established Patterns
- `@Observable` classes with `@Environment` injection
- `#if os(macOS)` / `#if os(iOS)` platform guards
- SwiftUI with SwiftData `@Query`

### Integration Points
- `SyncBudsApp.swift` — Needs to switch from WindowGroup to MenuBarExtra on macOS
- `ContentView.swift` — Complete rewrite for both platforms
- `Info.plist` — Add LSUIElement = true

</code_context>

<specifics>
## Specific Ideas

- User specifically wants "widget-style" cards on iOS — modern, rounded corners, visual
- User wants Control Center + home screen widget access (widget is Phase 5 but design should accommodate)
- Keyboard shortcut must be configurable, not fixed

</specifics>

<deferred>
## Deferred Ideas

- **iOS Widget (UI-05)** — Phase 5 scope. iOS app design should be widget-compatible but widget itself deferred.
- **Control Center integration** — Requires WidgetKit + Control Center API. Deferred to Phase 5.

</deferred>

---

*Phase: 04-ui*
*Context gathered: 2026-03-26*
