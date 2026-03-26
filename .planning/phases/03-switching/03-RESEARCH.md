# Phase 3: Switching - Research

**Researched:** 2026-03-26
**Domain:** Bidirectional Bluetooth switching coordination — state machine, race condition handling, system notifications
**Confidence:** HIGH (all core components verified on real hardware in Phases 1-2; architecture is well-understood; all decisions are Claude's discretion)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** The validated switching architecture is:
  - **Mac→iPhone:** Mac calls `closeConnection()` → sends `.switchRequest` via Multipeer → iPhone connects headphone
  - **iPhone→Mac:** iPhone sends `.switchRequest` via Multipeer → Mac calls `openConnection()` → headphone switches to Mac
- **D-02:** iOS cannot programmatically disconnect audio devices. Mac is always the actuator.

### Claude's Discretion

- All switching flow implementation details
- SwitchCoordinator state machine design (states, transitions, error handling)
- Cooldown window duration and reconnect suppression mechanism
- Notification strategy (system vs in-app, content, timing)
- Whether to add a SwitchCoordinator class or extend existing BluetoothManager/MultipeerService
- Error recovery strategy (what happens when switch fails mid-way)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SW-01 | Mac can programmatically disconnect a Bluetooth audio device via IOBluetooth closeConnection() | Verified on real hardware (Phase 1, Plan 04). BluetoothManager.disconnectDevice() is production-ready. |
| SW-02 | Mac can programmatically connect a known Bluetooth audio device via IOBluetooth openConnection() | Verified on real hardware (Phase 1, Plan 04). BluetoothManager.connectDevice() is production-ready. |
| SW-03 | Bidirectional switching works end-to-end (Mac→iPhone and iPhone→Mac) | Requires SwitchCoordinator wiring MultipeerService + BluetoothManager. Both transports verified individually. |
| SW-04 | Switch completion triggers system notification on both platforms (success or failure) | UNUserNotificationCenter available on both macOS and iOS. Permission request pattern documented below. |
| SW-05 | Switching handles race conditions (headphone auto-reconnect suppression, cooldown window) | IOBluetooth connect notifications provide the hook. Cooldown window + reconnect suppression pattern documented below. |
</phase_requirements>

---

## Summary

Phase 3 wires together the two proven subsystems from Phases 1 and 2 — IOBluetooth control on macOS and MultipeerConnectivity signaling — into a single `SwitchCoordinator` class that orchestrates the state machine for bidirectional headphone switching. The core Bluetooth operations and the communication channel are already verified on real hardware. This phase is primarily an integration and coordination problem, not a new technology problem.

The key asymmetry is confirmed: Mac is the sole Bluetooth actuator. iOS can only observe its audio route and send `switchRequest` signals — it cannot disconnect A2DP/HFP devices. This means the two switching directions have different shapes: Mac→iPhone has Mac do the disconnect then signal iPhone to connect, while iPhone→Mac only requires Mac to call `openConnection()` after receiving the signal (because the headphone is already released from iPhone once iOS signals).

The main technical risks in this phase are the race condition window (headphone auto-reconnect to Mac during the 1-3 seconds after disconnect) and the iPhone→Mac path where Mac must wait for the headphone to actually become available. Both are solvable with a cooldown flag + IOBluetooth reconnect notification hook, already present in `BluetoothManager`.

**Primary recommendation:** Create a `SwitchCoordinator` class in `Shared/` with platform-gated logic blocks. Wire it into the existing `MultipeerService.handleReceivedSignal()` TODO and expose a `requestSwitch()` method to `ContentView`. Use `UNUserNotificationCenter` for notifications. Set the cooldown to 10 seconds.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| IOBluetooth | System (macOS) | closeConnection() / openConnection() / connect notifications | Already in use; verified on real hardware |
| MultipeerConnectivity | System (iOS+macOS) | Send/receive SyncSignal.switchRequest between devices | Already in use; COM-01 complete |
| UserNotifications (UNUserNotificationCenter) | System (iOS+macOS) | Local system notifications for switch success/failure | Standard Apple notification framework for both platforms |
| Foundation | System | Timer, DispatchQueue, async/await for state machine timing | Already in use throughout project |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| SwiftUI (@Observable) | System | Expose SwitchCoordinator state to ContentView | SwitchCoordinator should be @Observable so UI binds to switchState |
| AVAudioSession (iOS) | System | Confirm headphone connected on iPhone after switch | Read currentRoute.outputs after receiving switchRequest to confirm connection |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| UNUserNotificationCenter | In-app status only (statusMessage var) | Simpler but doesn't surface completion when app is in background; system notification is better for real use |
| Single SwitchCoordinator class | Extend BluetoothManager + MultipeerService | Extending existing classes creates tighter coupling; separate coordinator keeps concerns isolated |
| Timer-based cooldown | Notification-based cooldown exit | Timer is simpler; notification-based is more precise but adds complexity not warranted here |

**Installation:** No new packages. All frameworks are Apple system frameworks already linked.

---

## Architecture Patterns

### Recommended Project Structure

```
SyncBuds/
├── Shared/
│   ├── Models/
│   │   ├── BluetoothDevice.swift     (existing)
│   │   └── SyncSignal.swift          (existing — no changes needed)
│   ├── MultipeerService.swift        (existing — fill in switchRequest TODO)
│   └── SwitchCoordinator.swift       (NEW — state machine + notification)
├── macOS/
│   └── BluetoothManager.swift        (existing — add cooldown flag)
└── iOS/
    └── AudioRouteMonitor.swift       (existing — no changes needed for SW-03/05)
```

### Pattern 1: SwitchCoordinator State Machine

**What:** A shared `@Observable final class` that owns the switch state and orchestrates the two-step flows. Platform-gated `#if os(macOS)` / `#if os(iOS)` blocks inside the class handle the asymmetric logic.

**States:**
```
idle → switching → cooldown → idle
                ↓
              error → idle
```

**State definitions:**
- `.idle` — no switch in progress; ready to accept a new request
- `.switching` — switch in progress; reject second requests here (SW-05)
- `.cooldown` — disconnect completed on Mac; suppressing reconnect for N seconds
- `.error(String)` — switch failed; hold error message for notification, then reset to idle

**Transitions:**
```
requestSwitch() called:
  if state == .idle → start switch → state = .switching

Mac→iPhone flow:
  .switching → disconnectDevice() → state = .cooldown
  .cooldown → send .switchRequest via Multipeer → (timer fires after cooldown) → state = .idle

iPhone→Mac flow (iOS side):
  .switching → send .switchRequest via Multipeer → await confirmation → state = .idle

Mac receives .switchRequest from iOS:
  (no state change on Mac — just calls openConnection()) → notify success

Reconnect during cooldown:
  deviceDidConnect fires → if in .cooldown → immediately call disconnectDevice() again
```

**Example:**
```swift
// Source: Apple Developer Documentation — UserNotifications, IOBluetooth (HIGH confidence)
@Observable final class SwitchCoordinator {

    enum SwitchState {
        case idle
        case switching
        case cooldown
        case error(String)
    }

    private(set) var switchState: SwitchState = .idle

    // Set by app wiring (SyncBudsApp) after instantiation
    weak var multipeerService: MultipeerService?

    #if os(macOS)
    weak var bluetoothManager: BluetoothManager?
    #endif

    func requestSwitch() {
        guard case .idle = switchState else {
            // Second request while in progress — reject (SW-05)
            print("[SwitchCoordinator] Switch already in progress — ignoring duplicate request")
            return
        }
        switchState = .switching
        // Platform-specific logic below
    }
}
```

### Pattern 2: Mac→iPhone Flow

**What:** Mac disconnects the headphone, enters cooldown, then sends switchRequest. iPhone user connects headphone manually or it auto-connects.

**Sequence:**
1. User taps "Switch to iPhone" on Mac
2. `SwitchCoordinator.requestSwitch()` called — state → `.switching`
3. `BluetoothManager.disconnectDevice()` called (async) — retry loop already implemented
4. On success: state → `.cooldown`, start 10-second Timer
5. During cooldown: if `deviceDidConnect` fires → immediately call `disconnectDevice()` again (suppress auto-reconnect)
6. `MultipeerService.send(SyncSignal(type: .switchRequest, sender: .mac, ...))` — tells iPhone to expect headphone
7. Timer fires → state → `.idle`
8. On disconnect failure: state → `.error("Disconnect failed")` → show notification → state → `.idle`

**Why cooldown before signal, not after:** The headphone needs ~500ms-2s to fully release and become discoverable. Sending the signal immediately while the headphone is still in the ACL teardown window risks iPhone attempting to connect before the headphone is ready. Sending after the cooldown starts (i.e., after confirmed disconnect) is safe.

**Reconnect suppression implementation:**
```swift
// In BluetoothManager.deviceDidConnect — add cooldown check
@objc private func deviceDidConnect(
    _ notification: IOBluetoothUserNotification,
    device: IOBluetoothDevice
) {
    // If coordinator is in cooldown, immediately suppress this reconnect
    if let coordinator = switchCoordinator, coordinator.isInCooldown(for: device.addressString) {
        print("[BluetoothManager] Suppressing auto-reconnect during cooldown: \(device.name ?? "")")
        Task { await disconnectDevice(device) }
        return
    }
    // ... existing connect handling
}
```

### Pattern 3: iPhone→Mac Flow

**What:** iPhone sends switchRequest, Mac receives it and calls openConnection(). Headphone switches to Mac.

**Sequence:**
1. User taps "Switch to Mac" on iOS
2. `SwitchCoordinator.requestSwitch()` called on iOS — state → `.switching`
3. iOS sends `SyncSignal(type: .switchRequest, sender: .ios, ...)` via MultipeerService
4. iOS state: wait for audio route to lose Bluetooth (confirm headphone left iOS) OR timeout
5. Mac receives `.switchRequest` in `MultipeerService.handleReceivedSignal()`
6. Mac routes signal to `SwitchCoordinator`
7. Mac calls `BluetoothManager.connectDevice()` — `openConnection()`
8. Mac's `deviceDidConnect` callback fires → send `.status` signal back to iOS → post success notification
9. iOS: receives `.status` with "connected" from Mac → post success notification → state → `.idle`

**Key insight:** On the iPhone→Mac path, the headphone is already on iPhone's audio route. iPhone cannot disconnect it. But when Mac calls `openConnection()`, the headphone negotiates which device it prefers — if Mac's connection is strong enough, the headphone may switch. In practice, verified behavior (Phase 1): `openConnection()` causes the headphone to appear on Mac. The headphone's auto-connect logic favors the most recent `openConnection()` call. iOS side will see `oldDeviceUnavailable` route change notification when the headphone leaves.

**Timeout handling:** If Mac's `openConnection()` does not result in a `deviceDidConnect` callback within 10 seconds, treat as failure.

### Pattern 4: Filling the MultipeerService TODO

The TODO at `MultipeerService.handleReceivedSignal()` is the Phase 3 integration point:

```swift
// MultipeerService.swift — replace TODO with:
case .switchRequest:
    print("[MultipeerService] Received switch request from \(signal.sender.rawValue)")
    switchCoordinator?.handleIncomingSwitchRequest(from: signal.sender)
```

`switchCoordinator` is a weak reference set by app wiring, same pattern as `multipeerService` in `BluetoothManager`.

### Pattern 5: UNUserNotificationCenter Notifications (SW-04)

**What:** Post local notifications on both platforms when a switch completes or fails.

**Permission request** — must be requested once at app startup:
```swift
// Source: Apple Developer Documentation — UserNotifications framework (HIGH confidence)
UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
    print("[Notifications] Authorization granted: \(granted)")
}
```

**Posting a notification:**
```swift
// Source: Apple Developer Documentation — UNUserNotificationCenter (HIGH confidence)
func postSwitchNotification(title: String, body: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: content,
        trigger: nil  // nil = deliver immediately
    )
    UNUserNotificationCenter.current().add(request)
}
```

**Notification content:**

| Event | Title | Body |
|-------|-------|------|
| Mac→iPhone success | "Headphone Switched" | "Now available for iPhone" |
| iPhone→Mac success | "Headphone Switched" | "Now connected to Mac" |
| Switch failed (disconnect) | "Switch Failed" | "Could not disconnect headphone" |
| Switch failed (connect timeout) | "Switch Failed" | "Headphone did not connect within 10s" |

**Note:** `UNUserNotificationCenter` is available on macOS 10.14+ and iOS 10+. Both platforms share the same API. The import is `import UserNotifications`.

### Anti-Patterns to Avoid

- **Two coordinators fighting:** Do not instantiate separate `SwitchCoordinator` on Mac and iOS and have them both try to act on every signal. The Mac coordinator is the actuator; the iOS coordinator is the signal emitter. Incoming `.switchRequest` on Mac should trigger the Mac actuator path. Incoming `.status("connected")` on iOS should confirm the switch and reset iOS state.
- **Blocking main thread for disconnect:** `BluetoothManager.disconnectDevice()` is already `async` — always call it from a `Task {}` block. Do not call it synchronously from a button action without wrapping.
- **Ignoring the error path:** If `disconnectDevice()` returns `false` after 10 attempts, do not leave the state machine in `.switching` forever. Transition to `.error`, post notification, reset to `.idle`.
- **Not suppressing reconnect during cooldown:** Without the cooldown guard in `deviceDidConnect`, the headphone auto-reconnects to Mac within 2 seconds, undoing the switch. This is Pitfall 3 from PITFALLS.md and is the most common failure mode.
- **Sending switchRequest before disconnect completes:** The signal to iPhone should be sent after `disconnectDevice()` returns `true`, not before. If sent before, iPhone may attempt to connect while Mac still holds the ACL link.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Local notifications | Custom in-app toast or alert | UNUserNotificationCenter | System framework, works in background, consistent OS look |
| State serialization | Custom lock flags or semaphores | Swift enum with @Observable | Swift's actor/enum pattern is sufficient; no external sync needed at this scale |
| Bluetooth connect callbacks | Polling `device.isConnected()` | IOBluetoothUserNotification (already in BluetoothManager) | Event-driven pattern already implemented; polling would miss events |
| Retry logic for connect/disconnect | Custom retry loop | Existing BluetoothManager retry loop | Already implemented and verified on real hardware |

**Key insight:** All the hard parts are already built. Phase 3 is orchestration, not new primitives.

---

## Common Pitfalls

### Pitfall 1: Headphone Auto-Reconnects During Cooldown Window (CRITICAL)
**What goes wrong:** Mac calls `closeConnection()`, disconnect confirmed, but headphone reconnects to Mac within 1-3 seconds before iPhone can connect. This is the most common failure mode for Bluetooth switching.
**Why it happens:** Headphones maintain a pairing priority list and auto-reconnect to the last-used device. Mac's Bluetooth stack may also initiate reconnect if a reconnect policy is active.
**How to avoid:** Set a cooldown flag when disconnect is confirmed. In `BluetoothManager.deviceDidConnect`, check the flag — if in cooldown, immediately call `disconnectDevice()` again. The cooldown duration should be 10 seconds (longer than the observed 1-3 second auto-reconnect window).
**Warning signs:** Switch appears to succeed in logs but headphone reconnects immediately; `deviceDidConnect` fires within 3 seconds of a `deviceDidDisconnect` for the target device.

### Pitfall 2: Second Switch Request Corrupts State (SW-05)
**What goes wrong:** User taps the switch button twice rapidly. First switch is mid-disconnect; second request starts a new disconnect or sends a duplicate signal, leaving state machine in undefined condition.
**How to avoid:** In `requestSwitch()`, guard `case .idle = switchState else { return }`. All non-idle states reject new requests silently. This is the single most important guard in the coordinator.
**Warning signs:** Two `.switchRequest` signals arrive at the peer within 1 second; disconnect retry loop runs with an already-disconnected device.

### Pitfall 3: Mac Calls openConnection() Before Headphone Is Available
**What goes wrong:** On the iPhone→Mac path, Mac receives the `.switchRequest` and immediately calls `openConnection()`. But the headphone may still be negotiating its connection with iPhone. `openConnection()` fails or connects partially.
**How to avoid:** Add a 500ms delay on Mac after receiving the switchRequest before calling `openConnection()`. This gives the headphone time to become available. Alternatively, check `device.isConnected()` first — if it returns `true`, the headphone is already on Mac (no action needed).
**Warning signs:** `openConnection()` returns `kIOReturnSuccess` but `deviceDidConnect` never fires within 10 seconds.

### Pitfall 4: UNUserNotificationCenter Permission Not Requested
**What goes wrong:** `postSwitchNotification()` is called but the user was never asked for notification permission. Notifications silently fail. SW-04 appears to work in tests (because developer already granted permission) but fails for a fresh install.
**How to avoid:** Call `UNUserNotificationCenter.current().requestAuthorization(options:completionHandler:)` once at app launch (in `SyncBudsApp.body` or in `ContentView.onAppear`). Check the granted flag in the callback before relying on notifications.
**Warning signs:** No notification appears after a successful switch; no permission prompt ever appeared.

### Pitfall 5: MultipeerService Sends to Empty Peer List
**What goes wrong:** Switch is requested but `MultipeerService.isConnectedToPeer` is false. `send()` silently returns without error. Switch request is lost.
**How to avoid:** In `SwitchCoordinator.requestSwitch()`, check `multipeerService?.isConnectedToPeer == true` before starting the switch. If not connected, immediately transition to `.error("Not connected to peer")` and post notification.
**Warning signs:** Logs show `send()` called but no signal received on the other side; `session.connectedPeers.isEmpty` guard in `MultipeerService.send()` returns early.

### Pitfall 6: iOS State Machine Never Resets After iPhone→Mac
**What goes wrong:** iOS sends `.switchRequest`, transitions to `.switching`, but never receives confirmation from Mac. State remains `.switching` indefinitely. User cannot initiate another switch.
**How to avoid:** Set a 15-second timeout on iOS after sending the switchRequest. If no `.status("connected")` signal is received from Mac within that window, transition to `.error("Switch timeout")` and reset to `.idle`. Mac's `deviceDidConnect` callback sends a `.status` signal that iOS uses as confirmation.
**Warning signs:** Second switch attempt on iOS is rejected ("switch already in progress") even though the first switch completed on Mac.

---

## Code Examples

### SwitchCoordinator Skeleton

```swift
// Shared/SwitchCoordinator.swift
// Source: Pattern derived from BluetoothManager + MultipeerService conventions in project

import Foundation
import UserNotifications

@Observable final class SwitchCoordinator {

    enum SwitchState: Equatable {
        case idle
        case switching
        case cooldown
        case error(String)
    }

    // MARK: - Observable State
    private(set) var switchState: SwitchState = .idle

    // MARK: - Cooldown
    private static let cooldownSeconds: TimeInterval = 10
    private var cooldownTimer: Timer?
    private var cooldownDeviceAddress: String? // address of device in cooldown

    // MARK: - Dependencies (set by app wiring)
    weak var multipeerService: MultipeerService?
    #if os(macOS)
    weak var bluetoothManager: BluetoothManager?
    #endif

    // MARK: - Public API

    func requestSwitch() {
        guard case .idle = switchState else {
            print("[SwitchCoordinator] Switch in progress — ignoring duplicate request")
            return
        }
        switchState = .switching
        #if os(macOS)
        performMacToiPhoneSwitch()
        #else
        performiPhoneToMacSwitch()
        #endif
    }

    func handleIncomingSwitchRequest(from sender: SyncSignal.Platform) {
        #if os(macOS)
        // Mac receives request from iOS — connect headphone
        guard sender == .ios else { return }
        performMacConnectForIncomingRequest()
        #else
        // iOS receives request from Mac — inform user headphone is coming
        guard sender == .mac else { return }
        // iOS has nothing to do except update UI; headphone will auto-connect
        #endif
    }

    // MARK: - Cooldown Query (used by BluetoothManager)
    func isInCooldown(for addressString: String?) -> Bool {
        guard case .cooldown = switchState else { return false }
        return cooldownDeviceAddress == addressString
    }
}
```

### Cooldown Timer Pattern

```swift
// Source: Foundation Timer pattern consistent with MultipeerService.statusTimer
private func startCooldown(for device: IOBluetoothDevice) {
    cooldownDeviceAddress = device.addressString
    switchState = .cooldown
    cooldownTimer = Timer.scheduledTimer(
        withTimeInterval: Self.cooldownSeconds,
        repeats: false
    ) { [weak self] _ in
        self?.endCooldown()
    }
}

private func endCooldown() {
    cooldownTimer?.invalidate()
    cooldownTimer = nil
    cooldownDeviceAddress = nil
    switchState = .idle
    print("[SwitchCoordinator] Cooldown ended — ready for next switch")
}
```

### Notification Helper

```swift
// Source: Apple Developer Documentation — UserNotifications (HIGH confidence)
// Place in SwitchCoordinator or a NotificationHelper struct

func postNotification(title: String, body: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: content,
        trigger: nil
    )
    UNUserNotificationCenter.current().add(request) { error in
        if let error {
            print("[SwitchCoordinator] Notification failed: \(error)")
        }
    }
}

// Request permission — call once at app startup
func requestNotificationPermission() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
        print("[SwitchCoordinator] Notification permission granted: \(granted)")
    }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| closeConnection() may not release audio profile (concern pre-Phase 1) | closeConnection() confirmed to fully release A2DP on real hardware | Phase 1, 2026-03-26 | Architecture is sound; no workaround needed |
| UNUserNotificationCenter required bridging in older Swift | Pure Swift API, identical on macOS and iOS | macOS 10.14 / iOS 10 | Single implementation serves both platforms |

**Deprecated/outdated:**
- Phase 1 concern about `closeConnection()` vs `disconnect()` — resolved. `closeConnection()` with retry loop (already implemented) is sufficient.
- PITFALLS.md Pitfall 1 concern about partial audio profile release — resolved by Phase 1 spike result ("closeConnection() WORKS — fully releases the A2DP profile").

---

## Open Questions

1. **openConnection() timing on iPhone→Mac path**
   - What we know: `openConnection()` returns `kIOReturnSuccess` quickly but actual connection may take 2-10 seconds
   - What's unclear: Whether a 500ms delay before calling is sufficient for all headphone models, or if we should wait for the previous owner (iOS) to confirm release
   - Recommendation: Start with 500ms delay + 10-second `deviceDidConnect` timeout. If real-device testing shows failures, increase delay.

2. **iOS confirmation signal timing**
   - What we know: iOS receives `deviceDidConnect` → sends `.status("connected")` to Mac
   - What's unclear: How long after Mac sends the switchRequest does iOS actually gain the headphone
   - Recommendation: 15-second timeout on iOS side before declaring failure. This covers slow headphone models.

3. **ConnectView / UI for Phase 3**
   - What we know: ContentView currently has test harness buttons for Phase 1
   - What's unclear: Whether Phase 3 should replace the harness with real switch buttons or add alongside
   - Recommendation: Replace the "IOBluetooth Spike Controls" section with a single "Switch Headphone" button backed by SwitchCoordinator. Keep the device list. Phase 4 (UI) will fully redesign the view.

---

## Environment Availability

> Step 2.6: SKIPPED for most tools. This phase is pure Swift code changes. No external CLI tools, databases, or services are required beyond the Apple system frameworks already linked in the project.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| UserNotifications framework | SW-04 notifications | System (always available) | macOS 10.14+ / iOS 10+ | — |
| MultipeerConnectivity | switchRequest signal | System (always available) | Already linked | — |
| IOBluetooth | SW-01, SW-02 | macOS only (system) | Already linked | — |
| xcodebuild | Build verification | ✗ (Linux CI) | — | Grep-based acceptance criteria (same as Phase 2) |

**Missing dependencies with no fallback:** None — all required frameworks are system Apple frameworks.

**Missing dependencies with fallback:** `xcodebuild` unavailable in Linux environment; grep-based verification used as in prior phases. Real build must be confirmed on developer's macOS machine.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (`swift-testing`) + XCTest |
| Config file | SyncBudsTests target in SyncBuds.xcodeproj |
| Quick run command | `xcodebuild test -scheme SyncBuds -destination 'platform=macOS'` (on macOS only) |
| Full suite command | same — no separate suites yet |

**Note:** `xcodebuild` is unavailable in this Linux environment. All verification in this phase uses grep-based acceptance criteria to confirm code structure, with real compile/run verification on the developer's macOS machine (same approach as Phases 1-2).

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SW-01 | `disconnectDevice()` returns true for connected device | Manual (requires real hardware + paired headphone) | — | ✅ (BluetoothManager.swift) |
| SW-02 | `connectDevice()` returns true and headphone connects | Manual (requires real hardware) | — | ✅ (BluetoothManager.swift) |
| SW-03 | End-to-end switch: both devices in foreground, headphone moves | Manual (requires two real devices) | — | ❌ Wave 0: SwitchCoordinator.swift |
| SW-04 | Notification appears on both platforms after switch | Manual (run on real devices) | — | ❌ Wave 0: needs UNUserNotificationCenter integration |
| SW-05 | Second switch request rejected while first is in progress | Unit test (state machine) | `xcodebuild test -only-testing:SyncBudsTests/SwitchCoordinatorTests` | ❌ Wave 0: SwitchCoordinatorTests.swift |

**SW-01 and SW-02 are manual-only** because they require real Bluetooth hardware that cannot be simulated. They were already verified in Phase 1 — Phase 3 does not need to re-verify the underlying IOBluetooth calls, only that SwitchCoordinator calls them correctly.

**SW-05 is the only requirement suitable for unit testing** — the state machine rejection of duplicate requests can be tested by calling `requestSwitch()` twice on a mock coordinator and asserting state remains `.switching` (not reset).

### Sampling Rate
- **Per task commit:** Grep-based structural verification (symbol counts, method presence)
- **Per wave merge:** Full manual test on real devices (Mac + iPhone in same room, headphone connected to Mac, initiate switch both directions)
- **Phase gate:** Both bidirectional paths succeed manually before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `SyncBuds/Shared/SwitchCoordinator.swift` — covers SW-03, SW-05 (main deliverable of Phase 3)
- [ ] `SyncBudsTests/SwitchCoordinatorTests.swift` — covers SW-05 state machine unit test (optional but recommended)
- [ ] Notification permission call in `SyncBudsApp.swift` — covers SW-04

*(All gaps are new files to create, not missing infrastructure — existing XCTest/Swift Testing setup is already configured.)*

---

## Project Constraints (from CLAUDE.md)

Directives the planner must verify all tasks comply with:

| Directive | Impact on Phase 3 |
|-----------|------------------|
| No external dependencies | `SwitchCoordinator` must use only system Apple frameworks (UserNotifications, Foundation) |
| `#if os(macOS)` / `#if os(iOS)` for platform-specific code | SwitchCoordinator must use these guards for all IOBluetooth calls |
| `@Observable` classes with weak references for delegate callbacks | SwitchCoordinator should be `@Observable final class`; `multipeerService` and `bluetoothManager` refs must be `weak var` |
| `DispatchQueue.main.async` for UI state updates from delegates | Any state transitions triggered by IOBluetooth callbacks must dispatch to main |
| `final class` for classes that won't be subclassed | `SwitchCoordinator` should be `final class` |
| PascalCase filenames matching primary type | File: `SwitchCoordinator.swift` |
| 4-space indentation, opening braces on same line | Standard project style |
| Commit message emoji format (no Co-Authored-By) | All commits must follow `<emoji> <type>[scope]: <description>` format |
| Personal use — functional over polished | Minimal error handling; `print()` for logging is acceptable |
| SwiftData + SwiftUI + Swift (no Objective-C additions) | SwitchCoordinator is pure Swift; Objective-C selectors already handled in BluetoothManager |
| Deployment target iOS 26.2 / macOS 26.2 | All APIs used (UNUserNotificationCenter, @Observable) are well within these targets |

---

## Sources

### Primary (HIGH confidence)
- Phase 1 Plan 04 Summary (`.planning/phases/01-foundation/01-04-SUMMARY.md`) — `closeConnection()` and `openConnection()` verified on real hardware
- Phase 2 Plan 03 Summary (`.planning/phases/02-communication/02-03-SUMMARY.md`) — MultipeerService end-to-end verified
- `BluetoothManager.swift` — existing code, production patterns for connect/disconnect/monitoring
- `MultipeerService.swift` — existing code, switchRequest TODO location confirmed
- `SyncSignal.swift` — wire format, `.switchRequest` type already defined
- Apple Developer Documentation: `UNUserNotificationCenter` — available macOS 10.14+/iOS 10+ (HIGH confidence — stable, well-established API)

### Secondary (MEDIUM confidence)
- `.planning/research/PITFALLS.md` — Pitfall 3 (auto-reconnect race), informed cooldown duration recommendation
- `.planning/research/ARCHITECTURE.md` — SwitchCoordinator component design, state machine states

### Tertiary (LOW confidence)
- Cooldown duration of 10 seconds — empirical estimate from PITFALLS.md noting "1-3 seconds" auto-reconnect window. Recommend verifying on real hardware during Phase 3 execution; may need adjustment per headphone model.
- 500ms delay before iPhone→Mac `openConnection()` — reasonable estimate; verify on real devices.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all frameworks verified or system-standard
- Architecture: HIGH — derived directly from verified Phase 1/2 code; no new unknowns
- State machine design: HIGH — simple enum, standard Swift pattern
- Cooldown duration (10s): MEDIUM — empirical estimate; needs real-device validation
- Notification implementation: HIGH — UNUserNotificationCenter is stable, well-documented API

**Research date:** 2026-03-26
**Valid until:** 2026-06-26 (stable frameworks; cooldown duration may need adjustment after real-device testing)
