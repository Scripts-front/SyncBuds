# Phase 1: Foundation - Context

**Gathered:** 2026-03-25
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase delivers the project infrastructure and a verified IOBluetooth prototype. It proves that Mac-side Bluetooth control works before any other code depends on it. Scope: entitlements, project structure with platform-gated code, SwiftData device registry, and a complete IOBluetooth spike (enumerate, connect, disconnect, real-time state detection).

</domain>

<decisions>
## Implementation Decisions

### Entitlements & Developer Account
- **D-01:** Apple Developer Account does NOT exist yet — user will create it in parallel. CloudKit entitlements should be configured in code/project but cannot be tested until the account is active.
- **D-02:** Bluetooth entitlement (`com.apple.security.device.bluetooth`) must be added to macOS entitlements file.
- **D-03:** CloudKit container should be defined in entitlements even though it can't be tested yet — this prevents restructuring later.
- **D-04:** App should be set up with App Sandbox enabled (macOS) with Bluetooth entitlement.

### IOBluetooth Spike
- **D-05:** Spike must be comprehensive — not just connect/disconnect, but also: enumerate all paired Bluetooth audio devices, detect connection state in real-time, and verify that `closeConnection()` fully releases the A2DP profile.
- **D-06:** User has a non-Apple Bluetooth headphone available for real device testing.
- **D-07:** Success criteria: after `closeConnection()`, the headphone disappears from macOS System Settings connected list and becomes available for iPhone to connect.

### Device Registry
- **D-08:** Claude's discretion on what data to store per device — should include at minimum: name, MAC address, last seen timestamp, last connected platform. Claude can add more fields if useful for switching logic.
- **D-09:** Multiple headphones can be saved, but only one is active for switching at a time.
- **D-10:** Active device selection is Claude's discretion — the currently connected headphone is the natural default.

### Project Structure
- **D-11:** Claude's discretion on folder/module organization. Must use `#if os(macOS)` / `#if os(iOS)` for platform-specific code. IOBluetooth code must not leak into iOS target.

### Claude's Discretion
- Device registry data model fields beyond the minimum (name, MAC, last seen, platform)
- Active device selection mechanism (automatic vs manual)
- Project folder structure and module organization
- Whether to use a dedicated BluetoothService class or keep it simpler for the spike

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Codebase Analysis
- `.planning/codebase/STACK.md` — Current tech stack (Swift, SwiftUI, SwiftData, Xcode project structure)
- `.planning/codebase/ARCHITECTURE.md` — Current architecture (template MVVM, single-target multiplatform)
- `.planning/codebase/STRUCTURE.md` — Directory layout and file locations
- `.planning/codebase/CONVENTIONS.md` — Naming patterns, code style, import organization

### Research
- `.planning/research/STACK.md` — IOBluetooth API analysis, MenuBarExtra, CloudKit patterns
- `.planning/research/ARCHITECTURE.md` — Component boundaries, data flow, build order
- `.planning/research/PITFALLS.md` — IOBluetooth disconnect vs closeConnection, race conditions, sandbox entitlements

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SyncBuds/SyncBudsApp.swift` — App entry point with ModelContainer setup (needs to be extended, not replaced)
- `SyncBuds/Item.swift` — Placeholder model (will be replaced with BluetoothDevice model)
- `SyncBuds/ContentView.swift` — Placeholder view (will be replaced)

### Established Patterns
- SwiftData with `@Model` decorator for persistence
- `@Environment(\.modelContext)` for data access in views
- Single multiplatform target (iOS + macOS in one target)

### Integration Points
- `SyncBudsApp.swift` — ModelContainer configuration needs BluetoothDevice schema
- `project.pbxproj` — Needs entitlements file references added
- New entitlements files needed: `SyncBuds.entitlements` (macOS), potentially `SyncBuds-iOS.entitlements`

</code_context>

<specifics>
## Specific Ideas

- User emphasized wanting the spike to be comprehensive (enumerate + connect + disconnect + real-time state) rather than minimal
- Apple Developer Account creation is a prerequisite blocker for CloudKit testing — code should be written but CloudKit cannot be validated until account exists

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-foundation*
*Context gathered: 2026-03-25*
