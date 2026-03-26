# Phase 5: Automation - Context

**Gathered:** 2026-03-26
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase delivers automatic switching (triggered by iOS foreground), an iOS home screen widget with status + switch button, and skips battery level display (BT-05 descoped by user).

</domain>

<decisions>
## Implementation Decisions

### Automatic Switching (SW-06)
- **D-01:** Auto-switch triggers when the iPhone app comes to foreground AND the headphone is currently on the Mac. Simple foreground-based heuristic — no audio session detection needed.
- **D-02:** This means: iOS app goes to foreground → checks if peer (Mac) has headphone → sends switchRequest automatically.
- **D-03:** Should have a toggle to enable/disable auto-switch (user might not always want it).

### Widget iOS (UI-05)
- **D-04:** Widget shows status (connected/disconnected, which device has the fone) + switch button.
- **D-05:** Medium-size widget. Uses WidgetKit + AppIntents for the switch action.
- **D-06:** Widget state reads from shared UserDefaults (App Group) since WidgetKit can't access @Observable directly.

### Battery Level (BT-05)
- **D-07:** BT-05 is SKIPPED for this phase. User decided battery display is not worth the effort for personal use. Requirement will be moved to v2/deferred.

### Claude's Discretion
- Auto-switch toggle UI placement and default state
- Widget visual design and layout
- App Group identifier for shared UserDefaults
- Whether to add Control Center toggle (if feasible with current APIs)

</decisions>

<canonical_refs>
## Canonical References

### Codebase
- `SyncBuds/Shared/SwitchCoordinator.swift` — requestSwitch() to trigger from auto-switch
- `SyncBuds/Shared/MultipeerService.swift` — peer status for widget
- `SyncBuds/iOS/iOSContentView.swift` — iOS UI to add auto-switch toggle
- `SyncBuds/SyncBudsApp.swift` — App lifecycle for foreground detection

### Research
- `.planning/research/FEATURES.md` — Widget and automation feature analysis

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SwitchCoordinator.requestSwitch()` — already handles the full switch flow
- `MultipeerService.isConnectedToPeer` / `peerBluetoothStatus` — peer state for widget
- `iOSContentView` — existing iOS UI with glassEffect cards pattern

### Integration Points
- iOS `scenePhase` environment value for foreground detection
- WidgetKit target needs to be added to Xcode project
- App Group for sharing state between app and widget extension

</code_context>

<specifics>
## Specific Ideas

- Auto-switch is foreground-based (simplest heuristic) — not audio-based
- Widget has both status AND switch button (medium size)
- Battery display skipped entirely

</specifics>

<deferred>
## Deferred Ideas

- **BT-05 (battery level)** — moved to v2. Not implemented in this phase.
- **Control Center integration** — evaluate feasibility but not required
- **Audio-based auto-switch** — more complex heuristic, deferred to v2 if foreground-based proves insufficient

</deferred>

---

*Phase: 05-automation*
*Context gathered: 2026-03-26*
