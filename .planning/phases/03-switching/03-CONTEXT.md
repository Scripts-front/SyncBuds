# Phase 3: Switching - Context

**Gathered:** 2026-03-26
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase delivers bidirectional headphone switching between Mac and iPhone, including the SwitchCoordinator state machine, race condition handling (cooldown window to prevent auto-reconnect), and system notifications on switch completion/failure.

</domain>

<decisions>
## Implementation Decisions

### Switching Flow
- **D-01:** Claude's discretion on all switching flow details. The validated architecture is:
  - **Mac→iPhone:** Mac calls `closeConnection()` (proven in Phase 1) → sends `.switchRequest` via Multipeer → iPhone connects headphone
  - **iPhone→Mac:** iPhone sends `.switchRequest` via Multipeer → Mac calls `openConnection()` (proven in Phase 1) → headphone switches to Mac
- **D-02:** iOS cannot programmatically disconnect audio devices. The strategy works around this by having the Mac always be the actuator (it has IOBluetooth control).

### State Machine
- **D-03:** Claude's discretion on SwitchCoordinator state machine design. Should handle states: idle, switching-in-progress, cooldown, error.
- **D-04:** Claude's discretion on how to serialize switch requests (reject second request while one is in progress).

### Race Condition Handling
- **D-05:** Claude's discretion on cooldown window duration after a switch (prevents headphone auto-reconnecting to the releasing device). Research suggested headphones reconnect within 1-3 seconds — cooldown should be longer than that.
- **D-06:** Claude's discretion on reconnect suppression mechanism during cooldown.

### Notifications
- **D-07:** Claude's discretion on notification type and content. Options: macOS/iOS system notifications (UserNotifications framework), or in-app status updates only. Both success and failure should be communicated.

### Claude's Discretion
- All switching flow implementation details
- SwitchCoordinator state machine design (states, transitions, error handling)
- Cooldown window duration and reconnect suppression mechanism
- Notification strategy (system vs in-app, content, timing)
- Whether to add a SwitchCoordinator class or extend existing BluetoothManager/MultipeerService
- Error recovery strategy (what happens when switch fails mid-way)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 1 Artifacts
- `.planning/phases/01-foundation/01-CONTEXT.md` — Phase 1 decisions
- `.planning/phases/01-foundation/01-04-SUMMARY.md` — IOBluetooth spike results (closeConnection + openConnection verified)

### Phase 2 Artifacts
- `.planning/phases/02-communication/02-CONTEXT.md` — Phase 2 decisions (Multipeer only, no CloudKit)
- `.planning/phases/02-communication/02-03-SUMMARY.md` — MultipeerService implementation details

### Codebase
- `SyncBuds/macOS/BluetoothManager.swift` — IOBluetooth connect/disconnect/enumerate/monitor
- `SyncBuds/iOS/AudioRouteMonitor.swift` — iOS audio route detection
- `SyncBuds/Shared/MultipeerService.swift` — Multipeer peer discovery + signal sending/receiving
- `SyncBuds/Shared/Models/SyncSignal.swift` — Wire format (type, sender, timestamp, bluetoothStatus)

### Research
- `.planning/research/PITFALLS.md` — Race conditions, auto-reconnect aggressiveness, cooldown strategies
- `.planning/research/ARCHITECTURE.md` — SwitchCoordinator component design

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `BluetoothManager.connectDevice()` / `disconnectDevice()` — proven on real hardware
- `MultipeerService.send(_:)` — sends SyncSignal to peer, verified end-to-end
- `MultipeerService.onSignalReceived` — callback for incoming signals (has TODO for switchRequest handling)
- `SyncSignal.SignalType.switchRequest` — already defined in the wire format

### Established Patterns
- `#if os(macOS)` / `#if os(iOS)` platform guards
- `@Observable` classes with weak references for delegate callbacks
- `DispatchQueue.main.async` for UI state updates from delegates

### Integration Points
- `MultipeerService.onSignalReceived` needs to route `.switchRequest` signals to SwitchCoordinator
- `BluetoothManager` needs to be called by SwitchCoordinator for connect/disconnect
- `ContentView` needs switch button that triggers SwitchCoordinator
- System notifications via `UNUserNotificationCenter`

</code_context>

<specifics>
## Specific Ideas

No specific requirements — user trusts Claude's judgment on all implementation details for this phase.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-switching*
*Context gathered: 2026-03-26*
