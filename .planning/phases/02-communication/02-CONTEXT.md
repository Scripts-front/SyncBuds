# Phase 2: Communication - Context

**Gathered:** 2026-03-26
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase delivers cross-device signaling between Mac and iPhone via Multipeer Connectivity, with live connection status visible on both platforms. CloudKit is deferred — user does not have an Apple Developer Account yet.

</domain>

<decisions>
## Implementation Decisions

### CloudKit Deferral
- **D-01:** CloudKit is NOT implemented in this phase. User does not have Apple Developer Account. Only Multipeer Connectivity is implemented.
- **D-02:** COM-02 (CloudKit fallback) and COM-04 (silent push wake) are deferred to a future phase when Developer Account exists.
- **D-03:** No SignalRouter abstraction needed yet — direct Multipeer implementation is sufficient. When CloudKit is added later, a router can be introduced.

### Signal Format
- **D-04:** Minimal signal format: type (switch/status), direction (mac→iphone or iphone→mac), timestamp. No device-specific data in the signal.
- **D-05:** Signal is encoded as simple Codable struct sent via Multipeer Connectivity data channel.

### Status Display
- **D-06:** Devices exchange connection status periodically via Multipeer Connectivity. Both apps show which device currently has the headphone.
- **D-07:** Status updates only work when devices are on the same network (Multipeer limitation). This is acceptable for now — CloudKit will extend range later.

### Multipeer Connectivity
- **D-08:** Service type string must be consistent across both targets (e.g., "syncbuds-signal").
- **D-09:** Claude's discretion on MCSession configuration, peer discovery, and reconnection handling.

### Claude's Discretion
- MCSession configuration details (encryption, max peers)
- Peer discovery and reconnection strategy
- Status update frequency (polling interval)
- Whether to use MCNearbyServiceAdvertiser/Browser or MCBrowserViewController
- Error handling and retry logic for Multipeer

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase 1 Artifacts
- `.planning/phases/01-foundation/01-CONTEXT.md` — Phase 1 decisions (D-01 through D-11)
- `.planning/phases/01-foundation/01-04-SUMMARY.md` — IOBluetooth spike results (closeConnection works)

### Codebase
- `SyncBuds/macOS/BluetoothManager.swift` — Existing macOS Bluetooth control (connect/disconnect/enumerate/monitor)
- `SyncBuds/iOS/AudioRouteMonitor.swift` — Existing iOS audio route detection
- `SyncBuds/Shared/Models/BluetoothDevice.swift` — SwiftData device model

### Research
- `.planning/research/ARCHITECTURE.md` — Component boundaries and communication design
- `.planning/research/PITFALLS.md` — Multipeer background limitations, CloudKit latency issues

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `BluetoothManager` (macOS) — already monitors connection state changes via IOBluetoothUserNotification. Can trigger status updates to send via Multipeer.
- `AudioRouteMonitor` (iOS) — already detects Bluetooth audio route changes. Can trigger status updates to send via Multipeer.
- `BluetoothDevice` SwiftData model — stores device info, can be extended for communication state.

### Established Patterns
- `#if os(macOS)` / `#if os(iOS)` platform guards in all platform-specific code
- `final class` with NSObject inheritance for framework delegates (BluetoothManager pattern)
- Directory structure: `SyncBuds/macOS/`, `SyncBuds/iOS/`, `SyncBuds/Shared/`

### Integration Points
- BluetoothManager needs to send status updates when connection state changes
- AudioRouteMonitor needs to send status updates when audio route changes
- New Multipeer service classes go in `SyncBuds/Shared/` (used by both platforms)
- ContentView needs to display connection status from peer device

</code_context>

<specifics>
## Specific Ideas

- Multipeer is the ONLY communication channel for now — no CloudKit, no fallback
- Signal format is deliberately minimal (type + direction + timestamp)
- Status display only works on same network — this is an accepted limitation

</specifics>

<deferred>
## Deferred Ideas

- **CloudKit integration** — requires Apple Developer Account ($99/year). Deferred to future phase.
- **COM-02 (CloudKit fallback)** — deferred with CloudKit
- **COM-04 (silent push wake)** — deferred with CloudKit
- **SignalRouter abstraction** — not needed until CloudKit is added as second transport

</deferred>

---

*Phase: 02-communication*
*Context gathered: 2026-03-26*
