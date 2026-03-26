# SyncBuds

## What This Is

SyncBuds is a native macOS + iOS app that enables automatic Bluetooth headphone switching between Mac and iPhone. Unlike AirPods' native ecosystem switching, SyncBuds works with any Bluetooth headphone (Sony, JBL, Bose, etc.), delivering the same seamless experience for third-party devices.

## Core Value

When a user wants to use their Bluetooth headphones on a different device, the switch happens automatically — no manual disconnecting/reconnecting required.

## Requirements

### Validated

- ✓ Xcode project with SwiftUI + SwiftData scaffold — existing
- ✓ Dual-platform targets (iOS + macOS) configured — existing

### Active

- [ ] Mac app detects connected Bluetooth audio devices
- [ ] iOS app detects connected Bluetooth audio devices
- [ ] Mac can programmatically disconnect a Bluetooth audio device (via IOBluetooth)
- [ ] Mac and iPhone communicate via CloudKit to signal switch requests
- [ ] Fallback communication via local network (Multipeer Connectivity / Bonjour)
- [ ] When iPhone wants to connect a headphone, Mac automatically releases it
- [ ] When Mac wants to connect a headphone, iPhone receives notification and Mac initiates connection
- [ ] Bidirectional switching works end-to-end
- [ ] Mac app lives in menu bar with minimal UI
- [ ] Device history — remembers previously paired headphones
- [ ] Connection status notifications on both platforms
- [ ] Minimalist native interface on both platforms

### Out of Scope

- App Store publishing polish (onboarding, marketing, etc.) — personal use for now
- Support for more than 2 devices (e.g., iPad) — not needed yet
- Android support — Apple ecosystem only
- Audio routing controls (volume, EQ) — out of scope, only switching
- Real-time audio streaming between devices — not the goal

## Context

**Existing codebase:** Xcode template project with SwiftUI + SwiftData. Essentially greenfield — the Item model and ContentView are placeholder code from Xcode's project template.

**Technical landscape:**
- macOS has `IOBluetooth` framework with full control over Bluetooth connections (connect/disconnect A2DP/HFP devices programmatically)
- iOS Core Bluetooth is limited to BLE — cannot control audio device connections (A2DP/HFP) programmatically
- The switching mechanism relies on the Mac side having more control: Mac disconnects → headphone becomes available → iPhone connects
- For iPhone → Mac direction: the app signals Mac to initiate connection, which causes the headphone to switch
- CloudKit provides cross-device sync; Multipeer Connectivity provides low-latency local fallback

**Platform targets:** iOS 26.2+, macOS 26.2+, Swift 5.0, SwiftUI

## Constraints

- **iOS Bluetooth API**: iOS cannot programmatically disconnect audio (A2DP/HFP) devices — switching strategy must work around this limitation
- **Communication latency**: CloudKit has variable latency; local network fallback needed for responsive switching
- **Personal use**: No need for extensive error handling, onboarding, or polish — functional > polished
- **Tech stack**: Swift + SwiftUI + SwiftData, no external dependencies

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Mac as control center | macOS has IOBluetooth with full Bluetooth control; iOS lacks audio device management APIs | — Pending |
| CloudKit + local network fallback | CloudKit for sync when not on same network; local network for low-latency switching | — Pending |
| Menu bar app on Mac | Minimal footprint, always accessible, no dock icon needed | — Pending |
| Signaling-based switching | Instead of trying to control both sides, devices signal each other and the capable side acts | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-03-25 after initialization*
