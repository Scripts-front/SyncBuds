# Project Research Summary

**Project:** SyncBuds — Bluetooth headphone auto-switching between macOS and iOS
**Domain:** Cross-device Bluetooth audio management utility (Apple ecosystem)
**Researched:** 2026-03-25
**Confidence:** MEDIUM-HIGH (stack verified against Apple JSON API docs; architecture and pitfalls from training data with high-confidence core claims)

## Executive Summary

SyncBuds occupies a genuine gap in the Apple ecosystem: no shipping product provides reliable, user-controlled switching of any Bluetooth headphone between Mac and iPhone. ToothFairy is Mac-only. AirBuddy requires AirPods. Apple's native switching is AirPods-exclusive and notoriously unreliable. The correct approach is an asymmetric control model where the Mac acts as the Bluetooth control center (using IOBluetooth for programmatic connect/disconnect) while the iPhone acts as a signal emitter and passive observer (using AVAudioSession for route detection). This asymmetry is not a design choice — it is a hard iOS OS constraint. iOS has no public API for programmatic A2DP/HFP connect or disconnect. This must be the architectural foundation before any code is written.

The recommended stack is entirely Apple frameworks — no third-party dependencies, consistent with PROJECT.md constraints. Cross-device signaling uses Multipeer Connectivity as the primary low-latency path (50-300ms) with CloudKit private database as the universal fallback. SwiftData handles local persistence. SwiftUI with MenuBarExtra provides the Mac UI; standard SwiftUI serves iOS. The entire stack targets iOS 17+ / macOS 14+ minimum (project targets 26.2, so all framework features are available without compatibility shims).

The dominant risk is IOBluetooth's behavior when disconnecting audio devices. There is a meaningful difference between `closeConnection()` (closes the ACL link) and `disconnect()` (fully releases the audio profile), and macOS may continue routing audio even after the baseband connection is nominally closed. This must be prototyped and verified in Phase 1 before any communication or switching logic is built on top of it. A secondary risk is Bluetooth race conditions: headphones auto-reconnect aggressively after being disconnected, and the Mac's own Bluetooth stack may attempt reconnection before the iPhone can claim the device. These are solvable with a cooldown lock and reconnect suppression, but must be designed in from the start, not patched later.

## Key Findings

### Recommended Stack

The stack is pure Apple frameworks, divided by platform role. On macOS, IOBluetooth is the only public framework providing programmatic A2DP/HFP device connect/disconnect — there is no alternative. On iOS, CoreBluetooth is BLE-only and cannot touch A2DP/HFP; AVAudioSession is the sole mechanism for detecting when a Bluetooth audio device connects or disconnects, via `AVAudioSession.routeChangeNotification`. These two facts are the load-bearing constraints of the entire stack.

CloudKit (private database with `CKDatabaseSubscription`) provides universal cross-device signaling without server infrastructure. Multipeer Connectivity provides a sub-500ms local path when both devices are on the same network. SwiftData handles device history and switch logging. SwiftUI MenuBarExtra (`.window` style) is the Mac UI. The Xcode project is already a single multi-platform target, which is the correct structure for sharing business logic.

**Core technologies:**
- IOBluetooth (macOS): programmatic Bluetooth audio device connect/disconnect — only public API for this; no alternative
- AVAudioSession (iOS): audio route change observation — only mechanism for A2DP detection on iOS without private APIs
- Multipeer Connectivity (shared): primary low-latency signaling transport (~50-300ms when local) — fast enough to feel instant
- CloudKit private database (shared): universal fallback signaling + push wake via CKDatabaseSubscription — works across networks, free, no server infra
- SwiftData (shared): device history and event log — already scaffolded, iOS 17+ / macOS 14+
- SwiftUI MenuBarExtra (macOS): menu bar presence with `.window` style popover — SwiftUI-native, no AppKit boilerplate needed

### Expected Features

The core value proposition is one-action switching of any paired Bluetooth audio headphone between Mac and iPhone — something no existing product does reliably for non-AirPods devices. The feature set has a clear dependency chain: detection must precede status display, which must precede manual switching, which must precede automation.

**Must have (MVP):**
- Device discovery and persistent memory (IOBluetooth enumeration + SwiftData) — baseline requirement
- Connection status display on Mac (menu bar icon state) and iOS (simple indicator) — user must know what is connected where
- Manual switching Mac-to-iPhone: Mac disconnects, signals iPhone, iPhone connects — primary use case
- Manual switching iPhone-to-Mac: iPhone signals Mac, Mac connects headphone — equally expected, harder due to iOS constraints
- Cross-device signaling via CloudKit — reliable delivery when off local network
- Local network fast path via Multipeer Connectivity — required for sub-3s latency in the common case
- Switch completion notification (success and failure) — user confirmation loop

**Should have (high value, low effort — add early):**
- Mac keyboard shortcut — ToothFairy proved this is a power-user priority; NSEvent global monitor is simple to add
- Switch history / event log — simple SwiftData list view; builds user trust and aids debugging

**Defer (v2+):**
- Automatic switching (heuristic-based, AirPods-style) — fragile, high complexity, get manual switching right first
- iOS WidgetKit widget — useful after core switching is stable
- Siri Shortcuts donation — trivial to add during a polish phase
- Battery level display — headphone-vendor-dependent; adds complexity for limited users
- Multi-device support (iPad, Apple Watch) — explicitly deferred in PROJECT.md

**Hard anti-features (never build):**
- Audio routing or EQ — different product category
- Multi-headphone management — one headphone, two devices is the scope
- iOS-side disconnect button — impossible with public APIs; would mislead users

### Architecture Approach

The architecture has four layers: Presentation (SwiftUI MenuBarExtra on Mac, minimal SwiftUI on iOS), Domain (shared `SwitchCoordinator` state machine, `DeviceRegistry`, `SignalRouter`), Bluetooth (macOS `BluetoothMonitor` + `BluetoothActuator` using IOBluetooth; iOS `AudioSessionMonitor` using AVAudioSession), and Communication (`MultipeerTransport` + `CloudKitTransport` behind a `SignalRouter` abstraction). Platform-gated code uses `#if os(macOS)` / `#if os(iOS)` guards; all IOBluetooth code lives in macOS-only files. The `SwitchCoordinator` state machine has five named states (idle → requestingSend → awaitingRelease → connecting → connected → idle) and is the single place where switching logic lives.

**Major components:**
1. `BluetoothActuator` (macOS only) — calls `IOBluetoothDevice.openConnection()` / `disconnect()` on command from SwitchCoordinator; highest-risk component; must be validated first
2. `SwitchCoordinator` (shared, platform-gated) — orchestrates the state machine; routes signals; the central nervous system of the app
3. `SignalRouter` (shared, implemented as a Swift actor) — tries Multipeer first, always writes to CloudKit as durable backup; deduplicates by signal ID
4. `DeviceRegistry` (shared) — SwiftData-backed store of known headphones (address, name, last-seen platform, timestamp)
5. `MenuBarController` (macOS only) — owns NSStatusItem, renders SwiftUI popover showing status and switch controls
6. `AudioSessionMonitor` (iOS only) — observes `AVAudioSession.routeChangeNotification` for A2DP connect/disconnect events
7. `CloudKitTransport` / `MultipeerTransport` (shared) — transport implementations behind SignalRouter; signals are ephemeral CKRecords in a separate private CKRecordZone (not SwiftData)

### Critical Pitfalls

1. **IOBluetooth disconnect may not fully release the audio profile** — `closeConnection()` closes the ACL link but CoreAudio may continue routing audio. Use `IOBluetoothDevice -disconnect` (not `closeConnection`) and confirm via `IOBluetoothDevice.connectedDevices()` AND System Settings that the device fully disappears. Prototype this before building anything else. Do not proceed to Phase 2 until verified.

2. **Bluetooth race condition: headphone auto-reconnects to Mac after disconnect** — headphones maintain pairing lists and auto-reconnect; Mac's Bluetooth stack may also attempt reconnect. Prevention: set a "switching in progress" flag after disconnect, suppress reconnects for 10-15 seconds, include a `switchLock` token in signals to prevent re-triggering. Build this into the first switching implementation, not as a later fix.

3. **CloudKit latency is unsuitable as primary switching channel** — CloudKit push delivery ranges 2-30+ seconds and iOS may delay/drop silent pushes under background restrictions. Multipeer Connectivity is the primary path; CloudKit is the fallback and the durable write. The STACK.md research has this priority correct; do not invert it.

4. **iOS background execution kills Bluetooth monitoring** — `AVAudioSessionRouteChangeNotification` is not delivered to suspended apps. Design iOS as event-driven and stateless: read `AVAudioSession.currentRoute` on every wake rather than tracking continuous changes. Use CloudKit silent push (remote-notification background mode) as the wake mechanism.

5. **IOBluetooth sandbox entitlement must be configured before testing** — `com.apple.security.device.bluetooth` entitlement is required for sandboxed macOS app; `IOBluetoothDevice.pairedDevices()` silently returns empty without it. Also requires `NSBluetoothAlwaysUsageDescription` in Info.plist. Test as a signed bundle (not just from Xcode) from the first prototype run.

## Implications for Roadmap

Based on combined research, the dependency chain is clear and non-negotiable: Bluetooth actuation must be proven before communication, and communication must be proven before coordination. The IOBluetooth disconnect behavior is the single highest-risk unknown in the entire project and must be the first thing addressed — not the last.

### Phase 1: Foundation and Bluetooth Prototype (Mac-side verification)

**Rationale:** IOBluetooth's actual behavior when disconnecting audio devices is the highest-risk unknown. Before designing anything else, verify that `IOBluetoothDevice -disconnect` fully releases the audio profile with real audio playing. If this doesn't work as documented, the entire architecture needs to pivot early. Build the minimum working data model alongside this.

**Delivers:** Verified disconnect/connect behavior on macOS; device discovery working; SwiftData device model; sandbox entitlements confirmed; macOS Bluetooth permission flow verified with signed bundle.

**Addresses:** Must-have features: device discovery, persistent device memory.

**Avoids:** Pitfall 1 (IOBluetooth profile release), Pitfall 5 (sandbox entitlements), Pitfall 8 (CoreBluetooth/IOBluetooth confusion), Pitfall 9 (radio scanning anti-pattern).

**Research flag: YES** — IOBluetooth A2DP release behavior and sandbox entitlement requirements for A2DP control need phase-specific verification against live device behavior. The open question of whether `com.apple.security.device.bluetooth` alone is sufficient, or whether additional entitlements are needed for full A2DP profile control, must be answered here.

### Phase 2: iOS Detection and Cross-Device Communication

**Rationale:** Once macOS Bluetooth actuation is verified, the two remaining unknowns are iOS detection reliability and signal delivery latency. Both can be developed in parallel (iOS monitoring has no dependency on macOS actuation). Multipeer Connectivity must be proven as the primary path before CloudKit fallback is layered in.

**Delivers:** iOS `AudioSessionMonitor` using AVAudioSession; Multipeer Connectivity transport (MCSession peer discovery + data transfer); CloudKit transport (CKDatabaseSubscription + CKRecord writes); `SignalRouter` with transport fallback; iOS background wake via silent push; end-to-end signal delivery verified on real devices.

**Uses:** Multipeer Connectivity (MCSession, MCNearbyServiceBrowser/Advertiser), CloudKit (CKDatabaseSubscription, CKQueryOperation), Background Modes: remote-notification.

**Implements:** `MultipeerTransport`, `CloudKitTransport`, `SignalRouter`, `AudioSessionMonitor`.

**Avoids:** Pitfall 3 (CloudKit-as-primary), Pitfall 4 (iOS background blindness), Pitfall 6 (iOS Bluetooth permission — avoid requesting unnecessary CoreBluetooth permission on iOS), Pitfall 11 (Multipeer-only with no fallback).

**Research flag: YES** — CloudKit silent push reliability when iOS app is backgrounded/locked needs measurement on real devices. MCSession behavior when iOS app is suspended needs verification. iOS 26.2 background execution changes (post-August 2025 knowledge cutoff) need review.

### Phase 3: Switching Logic and State Machine

**Rationale:** With Bluetooth actuation proven (Phase 1) and signaling proven (Phase 2), the state machine can be assembled with confidence. The state machine is where race conditions are most dangerous — it must be built with all error states defined, including the "device unavailable" state and reconnect suppression.

**Delivers:** Full bidirectional switching (Mac-to-iPhone and iPhone-to-Mac); `SwitchCoordinator` state machine with all states (idle, requestingSend, awaitingRelease, connecting, connected, plus error/unavailable); reconnect suppression cooldown; switch completion notifications; switch history log via SwiftData.

**Implements:** `SwitchCoordinator`, `NotificationPresenter`, full switch event flow for both directions.

**Avoids:** Pitfall 2 (Bluetooth race condition — reconnect suppression built in from start), Pitfall 10 (headphone unavailable state not handled), anti-pattern of using SwiftData for ephemeral signals.

**Research flag: NO** — The state machine pattern is well-understood; no API-level unknowns after Phases 1 and 2 are complete.

### Phase 4: UI and Polish

**Rationale:** UI is deferred until switching actually works. A polished UI on top of unreliable switching is wasted effort. Once Phase 3 is solid, the UI layer binds to `@Observable` SwitchCoordinator state with minimal complexity.

**Delivers:** Mac MenuBarExtra with `.window` style popover (device list, connection status, switch controls, switch history); iOS minimal view (status indicator, manual switch trigger); Mac keyboard shortcut (NSEvent global monitor); menu bar icon state variants; LSUIElement = true for Dock hiding.

**Implements:** `MenuBarController`, SwiftUI popover views, keyboard shortcut handler.

**Avoids:** Anti-pattern of building UI before switching is stable; Pitfall 12 (SwiftData overkill — consider UserDefaults for device list if SwiftData introduces migration friction during earlier phases).

**Research flag: NO** — SwiftUI MenuBarExtra is well-documented; standard patterns apply.

### Phase 5: Automation and Differentiators (optional / post-MVP)

**Rationale:** After manual switching is solid, automation features can be layered on without risk of destabilizing the core. Each is independent and can be added individually.

**Delivers (pick any):** iOS WidgetKit widget for home screen switching; Siri Shortcuts donation ("switch headphones to Mac"); automatic switching heuristics based on AVAudioSession activity; battery level display for supported headphones.

**Avoids:** Shipping automation before manual switching is proven reliable — Apple's own AirPods switching is the cautionary tale for unreliable automation.

**Research flag: NO for Siri Shortcuts / Widget; YES for automatic switching** — Automatic switching heuristics require deeper research into AVAudioSession activity signals and false-trigger mitigation.

### Phase Ordering Rationale

- Phase 1 before everything else: IOBluetooth A2DP release is the only claim that cannot be verified from documentation alone; it requires hardware testing. If this fails, the project needs a pivot before any other code exists.
- Phase 2 can partially parallel Phase 1: iOS AudioSessionMonitor and CloudKit/Multipeer transport have no dependency on IOBluetooth behavior. The SignalRouter cannot be finalized until Phase 1 confirms what the Mac side can actually do, but transport code can be written and tested independently.
- Phase 3 is the integration phase: all components assembled into the working switching flow. Building this before Phase 1 and 2 are verified would mean building on unverified assumptions.
- Phase 4 (UI) always last: utility app, not a consumer product; switching reliability is the value proposition, not the UI.
- The FEATURES.md dependency chain (discovery → persistence → status → switching → signaling → fast path → notification → automation) maps directly to this phase order.

### Research Flags

Phases needing deeper research during planning:
- **Phase 1:** IOBluetooth A2DP profile release behavior — does `disconnect` fully release the audio route? Does the sandbox entitlement cover HFP as well as A2DP? Requires real-device spike before any other architecture is set.
- **Phase 2:** CloudKit silent push reliability in iOS background/locked state — latency distribution and delivery rate under real conditions. MCSession behavior when iOS app suspends. iOS 26.2 background execution changes (post knowledge cutoff).
- **Phase 5 (if automatic switching pursued):** AVAudioSession heuristics for detecting "active audio use" on iOS — false trigger rate and mitigation strategies.

Phases with standard patterns (skip research-phase):
- **Phase 3:** SwitchCoordinator state machine — well-understood pattern; implement directly with the states and transitions identified in ARCHITECTURE.md.
- **Phase 4:** SwiftUI MenuBarExtra and keyboard shortcut — fully documented APIs; no unknowns.
- **Phase 5 (Siri Shortcuts / Widget):** Standard SiriKit Shortcuts donation and WidgetKit patterns; no novel API territory.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Core APIs (IOBluetooth, CloudKit, Multipeer, SwiftData, MenuBarExtra) verified against Apple's JSON API documentation; platform constraints confirmed. One LOW-confidence item: whether `closeConnection()` vs `disconnect()` behavior for A2DP profile release — requires hardware verification. |
| Features | MEDIUM | Competitive analysis (ToothFairy, AirBuddy) based on training data through August 2025; web verification was unavailable. Feature set derived from PROJECT.md (HIGH confidence primary source) + domain knowledge. Core MVP feature list is solid; competitive positioning should be spot-checked against current App Store listings before finalizing. |
| Architecture | MEDIUM-HIGH | Structural decisions (Mac-as-control-center, asymmetric model, actor-based SignalRouter, state machine) are well-reasoned and grounded in documented API constraints. Specific behavioral claims (Multipeer latency figures, CloudKit push timing) are from training data and need real-device verification. The IOBluetooth sandbox entitlement requirements are HIGH confidence. |
| Pitfalls | MEDIUM | Core pitfalls (iOS API limitations, IOBluetooth profile release subtlety, race conditions, CloudKit latency, iOS background suspension) are well-established domain knowledge. Headphone auto-reconnect behavior is model-dependent and MEDIUM confidence. iOS 26.2 / macOS 26.2 specifics are unknown (post knowledge cutoff). |

**Overall confidence:** MEDIUM-HIGH

### Gaps to Address

- **IOBluetooth A2DP disconnect behavior (HIGH RISK):** The distinction between `closeConnection()` and `disconnect()` for fully releasing the audio profile is the most critical unresolved question. Address via hardware spike in Phase 1 before any other code is written.
- **iOS background push delivery reliability:** CloudKit silent push behavior under real-world conditions (battery pressure, low-power mode, background app refresh off) needs measurement with real devices. Design the iOS app to function correctly even when push delivery is delayed 30+ seconds.
- **iOS 26.2 / macOS 26.2 compatibility:** Project targets post-date the knowledge cutoff (August 2025). Permission requirements, background execution modes, and IOBluetooth entitlements should be verified against current documentation and Xcode 26.x release notes before Phase 1 begins.
- **Headphone auto-reconnect behavior:** Varies significantly by headphone model (Sony vs Bose vs JBL). The 10-15 second cooldown + reconnect suppression approach is correct in principle; specific timing may need tuning per device. Test with the actual headphones to be used.
- **SwiftData vs UserDefaults for device history:** PITFALLS.md flags SwiftData as potential overkill for simple device history. Consider starting with UserDefaults/AppStorage and migrating to SwiftData only if relational queries are needed. Decide before Phase 1 implementation to avoid schema migration pain.
- **Competitive landscape verification:** ToothFairy and AirBuddy feature sets based on training data. Verify current App Store listings before finalizing SyncBuds positioning claims.

## Sources

### Primary (HIGH confidence)
- Apple JSON API documentation (fetched live): IOBluetooth, IOBluetoothDevice (openConnection, closeConnection), CloudKit, CKDatabaseSubscription, CKQuerySubscription, Multipeer Connectivity (MCSession, MCNearbyServiceBrowser, MCNearbyServiceAdvertiser), SwiftUI MenuBarExtra, SwiftData
- `/root/SyncBuds/.planning/PROJECT.md` — project requirements and constraints
- `/root/SyncBuds/SyncBuds.xcodeproj/project.pbxproj` — confirmed single multi-platform target, platform targets, sandbox configuration

### Secondary (MEDIUM confidence)
- Training data knowledge of AVAudioSession route change notification behavior (well-established pattern, HIGH confidence for API shape, MEDIUM for behavioral edge cases)
- Training data knowledge of Multipeer Connectivity cross-platform latency and background suspension behavior
- Training data knowledge of CloudKit push delivery latency characteristics
- Training data knowledge of IOBluetooth A2DP profile release behavior (closeConnection vs disconnect distinction)
- Training data knowledge of headphone auto-reconnect behavior post-programmatic disconnect

### Tertiary (LOW confidence / needs validation)
- Competitive feature sets for ToothFairy and AirBuddy — training data through August 2025; verify against current App Store listings
- iOS 26.2 / macOS 26.2 specific behaviors — post knowledge cutoff; verify against Xcode 26.x release notes and current Apple documentation

---
*Research completed: 2026-03-25*
*Ready for roadmap: yes*
