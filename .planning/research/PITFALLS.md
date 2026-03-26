# Domain Pitfalls

**Domain:** Bluetooth headphone auto-switching between macOS and iOS
**Project:** SyncBuds
**Researched:** 2026-03-25
**Confidence:** MEDIUM (training data + deep domain knowledge; web verification unavailable)

---

## Critical Pitfalls

Mistakes that cause rewrites or fundamental architecture changes.

---

### Pitfall 1: IOBluetooth Is a Private/Semi-Private Framework on macOS

**What goes wrong:** `IOBluetooth.framework` is a public macOS framework, but many of its most useful methods for programmatic connect/disconnect — particularly around A2DP/HFP audio profiles — are either undocumented, use private selectors, or depend on private `IOBluetoothDevice` internals. Developers who import IOBluetooth and call `openConnection()` / `closeConnection()` discover these work at the L2CAP transport level but don't reliably disconnect the audio profile, leaving the device "connected" at the OS audio routing level.

**Why it happens:** Apple distinguishes between the Bluetooth transport connection and the audio profile (A2DP/HFP) session. `IOBluetoothDevice -closeConnection` closes the raw ACL link but the CoreAudio/AudioHAL layer may keep the audio route active. The correct path requires either:
1. Using `IOBluetoothDevice -disconnect` (different from `closeConnection`) combined with waiting for the `kIOBluetoothDeviceNotificationNameDisconnected` notification, OR
2. Calling into private `BluetoothManager` (private framework, not available to App Store apps) or via the `bluetoothd` user space daemon

**Consequences:**
- Headphone appears "connected" in System Settings but audio doesn't route through it, or vice versa
- Mac side claims it disconnected but the headphone refuses a new connection from iPhone because the ACL link is still partially held
- Switching appears to "work" in development but fails in production with real audio playback active

**Warning signs:**
- `IOBluetoothDevice.isConnected()` returns `false` but audio continues playing through the device
- iPhone's Bluetooth connects but no audio routes through the headphone after "switch"
- Headphone shows connection indicator lights for both devices simultaneously

**Prevention:**
- Test `IOBluetoothDevice -disconnect` (not `closeConnection`) in early Phase 1 with real audio playing before building anything else
- Confirm via `IOBluetoothDevice.connectedDevices()` AND System Settings that the device is fully gone after disconnect
- If `disconnect` alone is insufficient, explore sending an HFP disconnect command via `IOBluetoothRFCOMMChannel` — verify this approach in a prototype before committing to it
- Since this is personal use (no App Store), calling `IOBluetoothDevice -disconnect` is acceptable; document the approach clearly

**Phase:** Address in Phase 1 (Mac Bluetooth detection + disconnect prototype). Do not proceed to communication layer until this is verified working.

---

### Pitfall 2: iOS Cannot Programmatically Disconnect or Connect Classic Bluetooth Audio Devices

**What goes wrong:** Developers assume CoreBluetooth on iOS can manage A2DP/HFP headphone connections. CoreBluetooth is BLE-only. Classic Bluetooth (BR/EDR) audio profiles are managed entirely by the OS. iOS has zero public API for programmatic connect, disconnect, or even reliably detecting connection state changes for A2DP devices.

**Why it happens:** The confusion stems from:
1. `CoreBluetooth` and "Bluetooth" being conflated — CoreBluetooth is BLE only
2. `ExternalAccessory` framework covers MFi accessories (Lightning/USB-C), not wireless audio
3. `AVAudioSession` can observe audio route changes but cannot initiate Bluetooth connections
4. `CBCentralManager` scans for BLE peripherals only; it will never surface a Sony WH-1000XM5 as a discoverable device

**Consequences:**
- iPhone-side "disconnect" is impossible — any design that requires iOS to actively drop the connection must be rearchitected
- The project's architecture (Mac does the actual connecting/disconnecting, iOS only signals) is correct, but developers who discover this mid-build waste significant time

**Warning signs:**
- Trying to find a CoreBluetooth API to disconnect paired audio devices
- Attempting `AVAudioSession.setPreferredInput` to force a disconnect
- Looking for `ExternalAccessory` sessions for wireless headphones

**Prevention:**
- The project already correctly identifies this constraint (PROJECT.md). Make it the first thing every new contributor reads.
- On iOS, the only mechanism is: detect audio route changes via `AVAudioSessionRouteChangeNotification`, display connection status in UI, and send signals to Mac via CloudKit/Multipeer. iOS is a passive observer + signal sender only.
- Never add iOS-side "connect" or "disconnect" buttons that purport to control the headphone directly.

**Phase:** Establish this constraint in architecture documentation before any iOS work begins (Phase 1 or project kickoff).

---

### Pitfall 3: Bluetooth State Race Condition During Switching

**What goes wrong:** When Mac disconnects the headphone to let iPhone connect, both devices may attempt to claim the headphone during the window between disconnect and iPhone connection. Additionally, the headphone itself has auto-reconnect logic that may try to reconnect to the Mac immediately after being disconnected.

**Why it happens:**
- Headphones maintain a pairing list and auto-reconnect to the most recently used device on disconnect
- The Mac OS Bluetooth stack may also auto-reconnect if a reconnect policy is set (happens with some devices)
- iPhone's "connect" is not instantaneous — there's a 1-5 second window after Mac disconnects where the headphone may race back to the Mac

**Consequences:**
- Switch appears to succeed but headphone reconnects to Mac within 2 seconds
- "Switching loop" where the two sides keep triggering each other
- Inconsistent behavior depending on headphone model (Sony vs Bose vs JBL have different auto-reconnect aggressiveness)

**Warning signs:**
- Successful disconnect followed by immediate reconnect notification
- Switch works when tested manually but fails during automated back-to-back switching
- Headphone-model-dependent behavior

**Prevention:**
- After `IOBluetoothDevice -disconnect` on Mac, set a "switching in progress" flag and suppress any reconnect attempts for 10-15 seconds
- Monitor `kIOBluetoothDeviceNotificationNameConnected` notifications and if the device reconnects within the cooldown window, immediately disconnect again
- Consider adding a brief delay (500ms-1s) after Mac disconnect before signaling iPhone to connect — gives the headphone time to enter "available" state
- The signaling protocol (CloudKit/Multipeer) should include a `switchLock` token to prevent the other side from re-triggering while a switch is in progress

**Phase:** Address in Phase 2 (switching logic). Build the cooldown mechanism into the first implementation, not as a later fix.

---

### Pitfall 4: CloudKit Latency Makes It Unsuitable as the Primary Switching Mechanism

**What goes wrong:** Developers use CloudKit as the primary (or only) communication channel for switch requests. CloudKit records have variable delivery latency — typically 1-10 seconds under good conditions, but often 30+ seconds or simply no delivery when the device is backgrounded or network conditions vary.

**Why it happens:**
- CloudKit uses push notifications (APNs) for change delivery, which are best-effort and subject to OS-level throttling
- Background apps on iOS receive silent push notifications for CloudKit changes, but iOS may delay or drop them under battery pressure, low-power mode, or background app refresh restrictions
- CloudKit is designed for data sync, not real-time signaling

**Consequences:**
- User initiates switch, headphone disconnects from Mac, but iPhone doesn't get the signal for 15 seconds
- User manually connects iPhone in the gap, now the system is out of sync
- Perceived as "broken" even though both apps are working correctly

**Warning signs:**
- Switching works when both apps are in foreground but fails reliably when iOS is backgrounded
- Testing on a developer device (which has fewer background restrictions) works fine; real-world usage fails
- CloudKit delivery times vary from 2 seconds to 45 seconds in testing

**Prevention:**
- Use Multipeer Connectivity (or Bonjour/local network) as the PRIMARY channel when both devices are on the same network — this is the common case
- Use CloudKit as a FALLBACK for cross-network use, not as the default path
- The architecture in PROJECT.md has this backwards — CloudKit is listed first. Invert the priority: Multipeer first, CloudKit as fallback
- When CloudKit is the only option, accept that switching latency will be 5-30 seconds and set user expectations accordingly (UI should show "Switching..." state)

**Phase:** Critical for Phase 2 (communication layer). Design Multipeer as the primary path from day one.

---

### Pitfall 5: iOS Background Execution Kills Bluetooth Monitoring

**What goes wrong:** The iOS app cannot maintain a persistent Bluetooth monitoring process in the background. When backgrounded, iOS suspends the app, and any Bluetooth audio route monitoring via `AVAudioSession` notifications stops firing. The app misses "headphone connected" events that should trigger status updates.

**Why it happens:**
- iOS background modes relevant here: `audio`, `bluetooth-central`, `fetch`, `remote-notification`
- `bluetooth-central` background mode only applies to BLE (CoreBluetooth), not Classic Bluetooth audio
- `audio` background mode only keeps the app running if it's actively playing/recording audio — a passive monitoring app doesn't qualify
- `AVAudioSessionRouteChangeNotification` is not delivered to suspended apps

**Consequences:**
- iOS app shows stale connection status until user opens it
- Switch requests from Mac arrive (via silent push) but the app is suspended and cannot process them until iOS wakes it
- If the app relies on "confirm connection" after switch, it may never send that confirmation

**Warning signs:**
- Everything works in testing (app always in foreground) but fails in real use
- iOS app shows "not connected" when headphone is actually connected
- Monitoring code written with `NotificationCenter` observers that aren't registered in background

**Prevention:**
- Treat the iOS app as event-driven, not polling-driven — it should react when woken, not continuously monitor
- Use `BGAppRefreshTask` to periodically wake the app and sync state (up to every 15 minutes, OS-determined)
- Use silent push notifications (via CloudKit or direct APNs) to wake the app when a switch is requested
- Design the iOS app so it can correctly reconstruct its Bluetooth state from scratch each time it's woken — don't rely on in-memory state
- `AVAudioSession.currentRoute` is readable at any time (not notification-based), so read it on every wake rather than tracking changes

**Phase:** Address in Phase 2 (iOS side). Design the wake-and-reconstruct pattern upfront.

---

## Moderate Pitfalls

---

### Pitfall 6: macOS Bluetooth Permission Changes (Ventura/Sonoma/Sequoia and Later)

**What goes wrong:** Starting with macOS 12 (Monterey) and tightened further in macOS 13+, Bluetooth access requires explicit user authorization via `NSBluetoothAlwaysUsageDescription` in the app's `Info.plist`. IOBluetooth access will silently return empty device lists or fail without this entitlement properly configured. With macOS sandboxing, additional complications arise.

**Why it happens:**
- Apple added `com.apple.bluetooth` entitlement requirements for App Store macOS apps
- Even for non-App Store (direct distribution) apps, the TCC (Transparency Consent and Control) database must grant Bluetooth access
- The first time the app calls `IOBluetoothDevice.pairedDevices()`, a permission prompt should appear — but if the app is not properly configured, this silently fails instead

**Warning signs:**
- `IOBluetoothDevice.pairedDevices()` returns empty array on first launch
- No permission prompt ever appears
- Works when running from Xcode (which has elevated permissions) but fails as a signed app bundle

**Prevention:**
- Add `NSBluetoothAlwaysUsageDescription` to the macOS app's `Info.plist` with a clear description
- Test the app as a properly signed bundle (not just from Xcode) early in development
- For personal use (non-App Store), notarization is optional but signing is required for TCC to work correctly
- Check System Settings > Privacy & Security > Bluetooth after first launch to confirm the app appears

**Phase:** Phase 1 (macOS setup). Verify permissions work in the first prototype run.

---

### Pitfall 7: iOS Bluetooth Permission Model Is More Restrictive Than Expected

**What goes wrong:** iOS 13+ requires `NSBluetoothAlwaysUsageDescription` for any Bluetooth access. However, since CoreBluetooth (BLE) is the only public iOS Bluetooth API, and SyncBuds on iOS won't use CoreBluetooth for headphone control, developers may be unsure whether they need Bluetooth permission at all. The answer depends on whether CoreBluetooth is used for any purpose.

**Why it happens:**
- `AVAudioSession` route observation does not require Bluetooth permission — it's an audio API
- If the iOS app uses only `AVAudioSession` for headphone detection, it does not need `NSBluetoothAlwaysUsageDescription`
- If CoreBluetooth is added for any purpose (e.g., trying to detect headphone presence via BLE), the permission is required and users see a Bluetooth permission prompt, which is confusing when the app's purpose is "automatic audio switching"

**Warning signs:**
- Unnecessary CoreBluetooth imports in the iOS target
- Bluetooth permission prompt on iOS app first launch with no clear reason shown to user
- Rejection from App Store review (if submitted) for requesting Bluetooth without clear user benefit

**Prevention:**
- Confirm that iOS headphone detection uses only `AVAudioSession.currentRoute` and `AVAudioSessionRouteChangeNotification`
- Do NOT add CoreBluetooth to the iOS target unless there is a specific BLE use case
- If CoreBluetooth is not used, do NOT add `NSBluetoothAlwaysUsageDescription` — its absence signals to iOS that the app doesn't need Bluetooth

**Phase:** Phase 1 (iOS setup). Decide the iOS detection approach before writing any Bluetooth-related code.

---

### Pitfall 8: CoreBluetooth vs IOBluetooth Confusion

**What goes wrong:** Developers conflate CoreBluetooth and IOBluetooth, or assume one can substitute for the other. This leads to:
- Attempting to use `CBCentralManager` on macOS to disconnect a paired A2DP device (won't work)
- Attempting to use `IOBluetooth` on iOS (the framework doesn't exist on iOS)
- Writing shared code that tries to import IOBluetooth in an iOS target, causing build failures

**Framework map:**
| Framework | Platform | Scope |
|-----------|----------|-------|
| `IOBluetooth` | macOS only | Classic Bluetooth (BR/EDR): paired devices, A2DP, HFP, connect/disconnect |
| `CoreBluetooth` | macOS + iOS | BLE only: scan, advertise, GATT characteristics |
| `AVAudioSession` | iOS only | Audio routing, not Bluetooth control |
| `AVAudioEngine` / `AVAudioSession` | macOS | Audio routing (separate from Bluetooth management) |

**Warning signs:**
- iOS build errors importing IOBluetooth
- `CBCentralManager` scan returning no results for headphones (they're Classic BT, not BLE)
- Shared SwiftUI files that reference IOBluetooth types

**Prevention:**
- Strictly separate platform-specific Bluetooth code using `#if os(macOS)` / `#if os(iOS)` guards from day one
- Never put IOBluetooth types in shared files — they belong in macOS-only files
- Create a `BluetoothManager` protocol with platform-specific implementations for macOS and iOS

**Phase:** Phase 1 architecture. Enforce at project structure level before any code is written.

---

### Pitfall 9: Battery Drain from Continuous Bluetooth Scanning

**What goes wrong:** If the iOS or Mac app continuously scans for Bluetooth devices using `CBCentralManager.scanForPeripherals` in hopes of detecting headphone presence, battery drain becomes severe. BLE scanning is one of the highest-power Bluetooth operations.

**Why it happens:**
- Developers unfamiliar with Bluetooth architectures default to "scan for it" as the detection approach
- For A2DP audio devices, scanning with CoreBluetooth will never find them anyway (wrong protocol)
- Continuous scanning disables the Bluetooth hardware's low-power duty cycling

**Warning signs:**
- `CBCentralManager.scanForPeripherals(withServices:, options:)` called with `CBCentralManagerScanOptionAllowDuplicatesKey: true`
- Scan started on app launch and never stopped
- Battery draining faster than normal during app use

**Prevention:**
- Do NOT scan with CoreBluetooth for headphone detection — it won't work for A2DP devices
- Use `IOBluetoothDevice.pairedDevices()` on macOS (polls the system, no radio scan) for device discovery
- Use `AVAudioSession.currentRoute.outputs` on iOS for headphone detection (no radio involved)
- Use `IOBluetoothDevice.register(forConnectNotifications:, selector:)` on macOS for event-driven connection detection
- If CoreBluetooth is used for any purpose, always call `centralManager.stopScan()` after finding what you need

**Phase:** Phase 1. Establish event-driven detection from the start; never poll with active radio scan.

---

### Pitfall 10: Headphone "Not Connected to Either Device" State Is Ignored

**What goes wrong:** The app assumes the headphone is always connected to either the Mac or the iPhone. When it's in a third state (off, out of range, connected to a third device, or in pairing mode), the state machine breaks — both sides think the other has it, or both think neither has it, leading to broken UI and failed switch attempts.

**Why it happens:**
- Happy-path development skips "device unavailable" states
- The signaling protocol (CloudKit/Multipeer) only sends "I have it" / "I want it" messages, not "device disappeared" messages
- Headphone power-off while connected is indistinguishable from a crash/disconnect for several seconds

**Warning signs:**
- Turning off the headphone causes the app UI to freeze or show incorrect state
- Switch request sent when headphone is off causes the Mac to attempt connect indefinitely
- No timeout or "device not found" handling in connect attempts

**Prevention:**
- Treat "unknown" as a valid first-class state alongside "Mac has it" / "iPhone has it"
- `IOBluetoothDevice` connection notifications include disconnect reasons — log and handle `kIOBluetoothHCIErrorConnectionTimeout` and power-off cases separately
- Add a connect timeout: if `IOBluetoothDevice.openConnection()` doesn't complete within 10 seconds, mark as "device unavailable" and notify the other side
- Both apps should be able to reset to "unknown" state and recover gracefully

**Phase:** Phase 2 (switching logic). Define the full state machine including error states before implementing switching.

---

## Minor Pitfalls

---

### Pitfall 11: Multipeer Connectivity Requires Both Apps to Be Active

**What goes wrong:** Multipeer Connectivity (MCSession) requires both peers to have the framework active for discovery to work. If the iOS app is suspended, it cannot advertise or browse. This means the low-latency local path is only reliable when both apps are in the foreground.

**Prevention:**
- Document this limitation clearly: Multipeer is "instant" when both apps are open; CloudKit is the fallback when one is backgrounded
- The Mac menu bar app should stay running continuously (it's a persistent process); this is fine for MCSession advertising
- The iOS app should use a notification (from CloudKit silent push) to wake itself before expecting Multipeer to work

**Phase:** Phase 2 (communication layer).

---

### Pitfall 12: SwiftData Overkill for Device History

**What goes wrong:** Using `SwiftData` for storing the list of previously paired headphones introduces migration complexity and concurrency concerns that aren't necessary for this use case. Device history is simple, small data that rarely changes.

**Prevention:**
- Use `UserDefaults` (or `@AppStorage`) for storing the list of known headphone identifiers and their display names
- Reserve SwiftData for if/when truly relational data is needed
- This avoids schema migration issues in early development when data models change frequently

**Phase:** Phase 1. Make the storage decision before implementing device history.

---

### Pitfall 13: Assuming Headphone Bluetooth Address Is Stable Across Pairing

**What goes wrong:** Some headphones use Bluetooth address randomization or present different addresses when reconnected. Code that caches device identity by MAC address breaks.

**Why it happens:** Classic Bluetooth devices don't randomize addresses like BLE (which introduced privacy address rotation), but some headphones with both BLE and Classic modes present different addresses depending on which mode connects first.

**Prevention:**
- Use `IOBluetoothDevice.addressString` as the primary key but also match by device name as a fallback
- When re-pairing is detected (new address, same device name), prompt the user to confirm or update the mapping
- Store both address and name in device history records

**Phase:** Phase 1 (device history implementation).

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| macOS Bluetooth detection | IOBluetooth disconnect may not fully release audio profile | Prototype and verify `disconnect` vs `closeConnection` before architecture is set |
| macOS disconnect implementation | Headphone auto-reconnects after disconnect (race condition) | Build cooldown + reconnect suppression into first implementation |
| iOS detection | Using CoreBluetooth instead of AVAudioSession | Confirm AVAudioSession-only approach; no CoreBluetooth needed |
| iOS background state | App suspended, misses events | Design wake-and-reconstruct pattern; use silent push to trigger |
| Communication layer | CloudKit latency makes switching feel broken | Multipeer Connectivity is the primary path; CloudKit is fallback |
| Switching state machine | "Device unavailable" state not handled | Define all states including error/unknown before coding switches |
| Device history storage | SwiftData complexity | Use UserDefaults; SwiftData not needed for this data |
| Menu bar app | Persistent process requirements for Multipeer | Ensure Mac process never exits; menu bar lifecycle is appropriate |

---

## Sources

- Apple Developer Documentation: `IOBluetooth` framework (training data, HIGH confidence for framework existence and basic API shapes)
- Apple Developer Documentation: `CoreBluetooth` overview — BLE-only scope (HIGH confidence)
- Apple Developer Documentation: `AVAudioSession.currentRoute` and route change notifications (HIGH confidence)
- Apple Developer Documentation: CloudKit + APNs delivery semantics (MEDIUM confidence — latency characteristics from community reports)
- Apple Developer Documentation: Multipeer Connectivity background limitations (MEDIUM confidence)
- Community reports: Bluetooth auto-reconnect behavior after programmatic disconnect (MEDIUM confidence — headphone-model-dependent)
- Note: Web verification was unavailable during this research session. All claims marked MEDIUM or HIGH are based on Apple's documented API contracts as of the knowledge cutoff (August 2025). iOS 26.2 / macOS 26.2 (project targets) post-date this cutoff and may introduce changes — verify permission requirements against current documentation before Phase 1 implementation.
