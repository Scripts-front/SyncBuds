# Phase 5: Automation - Research

**Researched:** 2026-03-26
**Domain:** WidgetKit + AppIntents (iOS home screen widget), SwiftUI scenePhase foreground detection (auto-switch trigger), UserDefaults App Group state sharing
**Confidence:** HIGH (stack is stable iOS 17+ APIs; code patterns verified from official sources and cross-referenced)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Auto-switch triggers when the iPhone app comes to foreground AND the headphone is currently on the Mac. Simple foreground-based heuristic — no audio session detection needed.
- **D-02:** iOS app goes to foreground → checks if peer (Mac) has headphone → sends switchRequest automatically.
- **D-03:** Should have a toggle to enable/disable auto-switch (user might not always want it).
- **D-04:** Widget shows status (connected/disconnected, which device has the fone) + switch button.
- **D-05:** Medium-size widget. Uses WidgetKit + AppIntents for the switch action.
- **D-06:** Widget state reads from shared UserDefaults (App Group) since WidgetKit can't access @Observable directly.
- **D-07:** BT-05 is SKIPPED for this phase. Battery display deferred to v2.

### Claude's Discretion
- Auto-switch toggle UI placement and default state
- Widget visual design and layout
- App Group identifier for shared UserDefaults
- Whether to add Control Center toggle (if feasible with current APIs)

### Deferred Ideas (OUT OF SCOPE)
- **BT-05 (battery level)** — moved to v2. Not implemented in this phase.
- **Control Center integration** — evaluate feasibility but not required
- **Audio-based auto-switch** — more complex heuristic, deferred to v2 if foreground-based proves insufficient
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SW-06 | Automatic switching based on audio activity detection (heuristic-based, no manual trigger) | scenePhase `.active` → check peerBluetoothStatus → call requestSwitch(); toggle guards the action |
| UI-05 | iOS home screen widget to initiate switch without opening app (WidgetKit) | WidgetKit StaticConfiguration + AppIntents Button(intent:) + App Group UserDefaults for state |
| BT-05 | App displays headphone battery level | SKIPPED per D-07; deferred to v2 |
</phase_requirements>

---

## Summary

Phase 5 adds two distinct features: (1) auto-switch when the iOS app foregrounds, and (2) an iOS home screen widget. Both are self-contained, low-risk additions that build on already-working infrastructure from Phases 2–4.

**Auto-switch (SW-06)** is implemented by observing `@Environment(\.scenePhase)` in `SyncBudsApp.body` and firing `switchCoordinator.requestSwitch()` when the scene transitions to `.active` — but only if auto-switch is enabled (toggle stored in `UserDefaults.standard`) AND `multipeerService.peerBluetoothStatus == "connected"` (meaning the Mac currently has the headphone). Since `requestSwitch()` already guards against duplicate/in-progress calls, double-fire is safe.

**Widget (UI-05)** requires a new Xcode target (Widget Extension, iOS only). The widget reads two keys from a shared App Group UserDefaults: `isConnectedToPeer` and `peerBluetoothStatus`. The app writes these keys every time MultipeerService state changes. A `Button(intent: SwitchHeadphoneIntent())` triggers the switch — the AppIntent must be added to both the app target AND the widget extension target. Because the AppIntent needs `SwitchCoordinator` (which runs in the app process), it must conform to `ForegroundContinuableIntent` so it runs in the main app process rather than the isolated widget process.

**Primary recommendation:** Implement auto-switch as a two-line `.onChange(of: scenePhase)` hook in `SyncBudsApp`, gated by a `@AppStorage("autoSwitchEnabled")` bool. Implement the widget as a standalone iOS-only Xcode target with App Group UserDefaults bridging the state gap — no @Observable sharing across targets.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| WidgetKit | iOS 14+ (interactive buttons: iOS 17+) | Home screen widget lifecycle, timeline, rendering | Apple's only widget framework; no alternative |
| AppIntents | iOS 16+ | Defines button actions inside widgets | Required by WidgetKit for interactive controls since iOS 17 |
| SwiftUI | iOS 14+ | Widget view rendering | WidgetKit renders exclusively with SwiftUI |
| Foundation (UserDefaults) | — | App Group shared state between app and widget extension | Only reliable IPC channel available to widget runtime |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| @AppStorage | iOS 14+ | Auto-switch toggle persistence in app views | SwiftUI-native wrapper over UserDefaults; no boilerplate |
| WidgetCenter | iOS 14+ | Request widget timeline reload after state change | Call from app when MultipeerService state changes |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| UserDefaults App Group | SwiftData (shared) | SwiftData containers are not shareable with extensions in the same lightweight way; UserDefaults is the documented approach for widgets |
| ForegroundContinuableIntent | URLSession background task from widget | Way more complexity; intent-in-app-process is cleaner and documented |
| @AppStorage for toggle | SwiftData @Query | Overkill; a single bool preference is a UserDefaults use case |

**Installation:** No package installation required. WidgetKit and AppIntents are system frameworks — add them to the widget extension target via Xcode's "Frameworks and Libraries."

---

## Architecture Patterns

### Recommended Project Structure
```
SyncBuds/                          # Existing app target (unchanged)
│   ├── Shared/
│   │   ├── SwitchCoordinator.swift
│   │   ├── MultipeerService.swift
│   │   └── ...
│   ├── iOS/
│   │   ├── iOSContentView.swift   # Add auto-switch toggle card
│   │   └── AudioRouteMonitor.swift
│   └── SyncBudsApp.swift          # Add scenePhase auto-switch hook
│
SyncBudsWidget/                    # NEW Xcode target (Widget Extension, iOS only)
│   ├── SyncBudsWidget.swift       # @main WidgetBundle
│   ├── SyncBudsWidgetView.swift   # Widget body (status + Button)
│   ├── SyncBudsWidgetProvider.swift # TimelineProvider reads App Group
│   ├── SyncBudsWidgetEntry.swift  # TimelineEntry struct
│   └── SwitchHeadphoneIntent.swift # AppIntent (member of BOTH targets)
│
SyncBuds/Shared/
│   └── WidgetStateWriter.swift    # NEW: helper that writes App Group keys
```

### Pattern 1: scenePhase Auto-Switch Hook

**What:** In `SyncBudsApp.body`, attach `.onChange(of: scenePhase)` to the `WindowGroup` scene. When it transitions to `.active` AND auto-switch is enabled AND the peer has the headphone, call `switchCoordinator.requestSwitch()`.

**When to use:** iOS only — guard with `#if os(iOS)`.

```swift
// Source: Apple ScenePhase documentation + Hacking with Swift
// Inside SyncBudsApp.body — iOS WindowGroup:

#if os(iOS)
WindowGroup {
    iOSContentView()
        .environment(multipeerService)
        .environment(switchCoordinator)
}
.modelContainer(sharedModelContainer)
.onChange(of: scenePhase) { _, newPhase in
    guard newPhase == .active else { return }
    guard autoSwitchEnabled else { return }  // @AppStorage bool
    guard multipeerService.peerBluetoothStatus == "connected" else { return }
    Task { @MainActor in switchCoordinator.requestSwitch() }
}
#endif
```

`@AppStorage("autoSwitchEnabled") var autoSwitchEnabled = false` declared in `SyncBudsApp` (defaults to false — opt-in safer than opt-out).

**Critical:** `@Environment(\.scenePhase)` must be read at the `App` struct level (not inside a View) for reliable cross-scene detection. Reading it inside a `View` struct is unreliable on iOS because the View may not see scene transitions.

### Pattern 2: WidgetKit Interactive Button

**What:** A `StaticConfiguration` medium widget with `Button(intent: SwitchHeadphoneIntent())`. The AppIntent writes nothing — it just calls `requestSwitch()` in the app process via `ForegroundContinuableIntent`. The timeline is refreshed via `WidgetCenter`.

```swift
// Source: createwithswift.com + swiftjectivec.com verified patterns

// SwitchHeadphoneIntent.swift — member of BOTH app and widget targets
import AppIntents
import WidgetKit

struct SwitchHeadphoneIntent: AppIntent {
    static var title: LocalizedStringResource = "Switch Headphone"
    static var description = IntentDescription("Send headphone to Mac or iPhone")

    func perform() async throws -> some IntentResult {
        // Reads UserDefaults to trigger the switch coordinator
        // NOTE: runs in main app process via ForegroundContinuableIntent
        SwitchIntentBridge.requestSwitch()
        return .result()
    }
}

// Extension on SwitchHeadphoneIntent — app target ONLY (not widget target)
// Forces intent to run in the main app process where SwitchCoordinator lives
@available(iOSApplicationExtension, unavailable)
extension SwitchHeadphoneIntent: ForegroundContinuableIntent {}
```

```swift
// SyncBudsWidgetView.swift
import SwiftUI
import WidgetKit

struct SyncBudsWidgetView: View {
    var entry: SyncBudsWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(entry.statusTitle, systemImage: entry.statusIcon)
                .font(.headline)
            Text(entry.statusSubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button(intent: SwitchHeadphoneIntent()) {
                Label("Switch", systemImage: "arrow.2.circlepath")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }
}
```

### Pattern 3: App Group State Sharing

**What:** App Group UserDefaults with suite name `group.com.syncbuds.shared`. App writes; widget reads.

```swift
// Source: Apple Developer Forums thread/651799 + Apple documentation pattern

// WidgetStateWriter.swift (app target only)
import Foundation
import WidgetKit

struct WidgetStateWriter {
    private static let suiteName = "group.com.syncbuds.shared"
    private static let defaults = UserDefaults(suiteName: suiteName)!

    static func update(isConnected: Bool, peerBTStatus: String, peerName: String?) {
        defaults.set(isConnected, forKey: "widget_isConnected")
        defaults.set(peerBTStatus, forKey: "widget_peerBTStatus")
        defaults.set(peerName ?? "", forKey: "widget_peerName")
        WidgetCenter.shared.reloadTimelines(ofKind: "SyncBudsWidget")
    }
}

// SyncBudsWidgetProvider.swift (widget target only)
import WidgetKit

struct SyncBudsWidgetProvider: TimelineProvider {
    private static let defaults = UserDefaults(suiteName: "group.com.syncbuds.shared")!

    func getTimeline(in context: Context, completion: @escaping (Timeline<SyncBudsWidgetEntry>) -> ()) {
        let isConnected = Self.defaults.bool(forKey: "widget_isConnected")
        let btStatus = Self.defaults.string(forKey: "widget_peerBTStatus") ?? "unknown"
        let peerName = Self.defaults.string(forKey: "widget_peerName")
        let entry = SyncBudsWidgetEntry(date: Date(), isConnected: isConnected,
                                        peerBTStatus: btStatus, peerName: peerName)
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }

    func placeholder(in context: Context) -> SyncBudsWidgetEntry {
        SyncBudsWidgetEntry(date: Date(), isConnected: false, peerBTStatus: "unknown", peerName: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SyncBudsWidgetEntry) -> ()) {
        completion(placeholder(in: context))
    }
}
```

**App Group ID convention:** `group.com.syncbuds.shared` — must be registered in Apple Developer portal and added as a Capability in both the main app target and the widget extension target.

**Important:** Since SyncBuds runs without a paid Developer Account (based on existing entitlements), App Groups must be created manually in Xcode via the free provisioning path. With a free account, App Groups work for local testing on real devices via Xcode's automatic signing, but the group must be configured consistently across both targets.

### Pattern 4: Auto-Switch Toggle in iOSContentView

**What:** Add a settings-style toggle card below the existing Switch Action Card. Bind to `@AppStorage`.

```swift
// iOSContentView.swift addition — new GroupBox card

@AppStorage("autoSwitchEnabled") private var autoSwitchEnabled: Bool = false

// Inside VStack after the switch card:
GroupBox {
    Toggle("Auto-switch on foreground", isOn: $autoSwitchEnabled)
        .font(.subheadline)
    Text("When enabled, headphone switches to iPhone automatically when you open SyncBuds.")
        .font(.caption)
        .foregroundStyle(.secondary)
} label: {
    Label("Automation", systemImage: "bolt.fill")
        .font(.caption)
        .foregroundStyle(.secondary)
}
.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
```

### Pattern 5: WidgetStateWriter call site in MultipeerService

`WidgetStateWriter.update()` must be called every time `isConnectedToPeer` or `peerBluetoothStatus` changes in `MultipeerService`. The right locations are the two existing `DispatchQueue.main.async` blocks in `MCSessionDelegate`:

1. In the `.connected` case — call with `isConnected: true`
2. In the `.notConnected` case — call with `isConnected: false`
3. In `handleReceivedSignal(.status)` — call with updated `peerBTStatus`

Since `WidgetKit` is iOS-only, wrap `WidgetStateWriter` calls with `#if os(iOS)`.

### Anti-Patterns to Avoid
- **Accessing @Observable from widget extension:** The widget process has no access to the app's `@Observable` objects (MultipeerService, SwitchCoordinator). State must flow through UserDefaults App Group.
- **Calling MultipeerConnectivity from AppIntent directly:** Widget extension runs in a sandboxed process with restricted networking. MCSession is not available there. Use ForegroundContinuableIntent to execute the intent in the main app process.
- **Reading scenePhase inside a View:** Unreliable on iOS. Always observe at `App` struct level (on the `WindowGroup` scene modifier).
- **`WidgetCenter.shared.reloadAllTimelines()` as immediate refresh:** System throttles this. It is a suggestion, not a guaranteed immediate reload. Use `reloadTimelines(ofKind:)` with the specific widget kind.
- **Defaulting auto-switch to enabled:** Default should be `false` (opt-in). Unexpected auto-switches when the user opens the app for other purposes are jarring.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Widget-to-app communication | Custom IPC, file-based messaging, NotificationCenter across processes | UserDefaults App Group + ForegroundContinuableIntent | App Group is the documented, sandboxed-safe IPC for extensions |
| Widget state updates | Polling timer inside widget | `WidgetCenter.shared.reloadTimelines(ofKind:)` called from app | WidgetKit controls rendering schedule; app pushes updates, widget doesn't pull |
| Toggle persistence | Custom storage class | `@AppStorage` property wrapper | One-line SwiftUI-native persistence over UserDefaults |
| Widget button action | URL scheme launch, openURL | `Button(intent:)` with AppIntents | The only supported interactive control in WidgetKit since iOS 17 |

**Key insight:** The widget extension process is a read-only consumer of App Group state. All write operations (switch coordination, state mutation) live exclusively in the main app process. The intent is the bridge.

---

## Common Pitfalls

### Pitfall 1: AppIntent Runs in Widget Process, Cannot Reach MultipeerService
**What goes wrong:** `SwitchHeadphoneIntent.perform()` is called inside the widget extension process, which has no access to the running `MultipeerService` or `SwitchCoordinator` instances.
**Why it happens:** Widget extensions are separate processes from the main app.
**How to avoid:** Conform `SwitchHeadphoneIntent` to `ForegroundContinuableIntent` via an extension in the **app target only** (not the widget target), marked `@available(iOSApplicationExtension, unavailable)`. The system then routes the intent execution to the main app process.
**Warning signs:** `perform()` runs but no switch happens, or networking errors appear in widget logs.

### Pitfall 2: App Group Not Configured in Both Targets
**What goes wrong:** `UserDefaults(suiteName: "group.com.syncbuds.shared")` returns `nil`, crashing on forced unwrap, or returns an isolated store with no shared data.
**Why it happens:** App Group capability must be added to BOTH the main SyncBuds target AND the SyncBudsWidget target in Xcode → Signing & Capabilities → + Capability → App Groups. Both must use the identical group ID string.
**How to avoid:** Verify both targets list the same group identifier. Test by writing a value from the app and reading it in the widget's `getTimeline`.
**Warning signs:** Widget always shows default/empty state regardless of app activity.

### Pitfall 3: scenePhase Fires Multiple Times Per Foreground
**What goes wrong:** `onChange(of: scenePhase)` fires `.inactive` then `.active` in rapid succession on some launches. If `requestSwitch()` is called on `.active` and the app was briefly background/inactive (e.g., control center dismissed), a spurious auto-switch fires.
**Why it happens:** iOS transitions through `.inactive` on the way to `.active` even for minor interruptions. The scenePhase environment value is updated for each transition.
**How to avoid:** The guard `guard newPhase == .active` already filters correctly. Additionally, `SwitchCoordinator.requestSwitch()` already checks `guard case .idle = switchState` — so a switch in progress won't double-fire. The `peerBluetoothStatus == "connected"` guard also prevents firing when headphone is already on iPhone.
**Warning signs:** Switch fires when the user just checks their phone and then locks it.

### Pitfall 4: WidgetKit Target Causes macOS Build Failures
**What goes wrong:** Adding a Widget Extension target to the multiplatform project causes the macOS build to fail with `WidgetKit not available` errors, or the Xcode scheme tries to build the widget for macOS.
**Why it happens:** The project builds for both iOS and macOS. WidgetKit is iOS/watchOS/iPadOS only — not available on macOS (macOS widgets use a different mechanism embedded in the main app target, not a separate extension).
**How to avoid:** When creating the Widget Extension target in Xcode, set SUPPORTED_PLATFORMS to `iphonesimulator iphoneos` only. Do not add the widget target to the macOS scheme. Verify the widget target's Deployment Info shows iOS only.
**Warning signs:** macOS build fails with `WidgetKit` import errors.

### Pitfall 5: Widget State Stale After Switch Completes
**What goes wrong:** User taps widget button, switch completes, but widget still shows old status.
**Why it happens:** `WidgetCenter.shared.reloadTimelines(ofKind:)` is a suggestion and the system may delay the refresh.
**How to avoid:** Call `WidgetCenter.shared.reloadTimelines(ofKind: "SyncBudsWidget")` from `WidgetStateWriter.update()` immediately after writing new values to UserDefaults. Accept that the widget may lag a few seconds — this is system behavior, not a bug.
**Warning signs:** Widget shows "on Mac" after switch succeeded; resolves on next manual interaction.

### Pitfall 6: @AppStorage Key Collision with Widget UserDefaults Keys
**What goes wrong:** Auto-switch toggle key `"autoSwitchEnabled"` accidentally matches a widget App Group key, causing unexpected cross-contamination.
**Why it happens:** `@AppStorage` writes to `UserDefaults.standard` (not the App Group suite). Widget reads from the App Group suite. These are separate stores — but naming discipline prevents confusion.
**How to avoid:** Prefix widget App Group keys with `widget_` (e.g., `widget_isConnected`, `widget_peerBTStatus`). Keep `@AppStorage` keys unprefixed and on `UserDefaults.standard`. Never use the App Group suite name for `@AppStorage`.

---

## Code Examples

### Full Widget Configuration Entry Point

```swift
// SyncBudsWidget.swift — widget extension target
import WidgetKit
import SwiftUI

@main
struct SyncBudsWidgetBundle: WidgetBundle {
    var body: some Widget {
        SyncBudsWidget()
    }
}

struct SyncBudsWidget: Widget {
    let kind: String = "SyncBudsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SyncBudsWidgetProvider()) { entry in
            SyncBudsWidgetView(entry: entry)
        }
        .configurationDisplayName("SyncBuds")
        .description("Switch headphones between your Mac and iPhone.")
        .supportedFamilies([.systemMedium])
    }
}
```

### TimelineEntry

```swift
// SyncBudsWidgetEntry.swift — widget target
import WidgetKit
import Foundation

struct SyncBudsWidgetEntry: TimelineEntry {
    let date: Date
    let isConnected: Bool
    let peerBTStatus: String   // "connected" | "disconnected" | "unknown"
    let peerName: String?

    var statusTitle: String {
        isConnected ? "Connected to \(peerName ?? "Mac")" : "Mac offline"
    }

    var statusSubtitle: String {
        switch peerBTStatus {
        case "connected": return "Headphone is on Mac"
        case "disconnected": return "Headphone is available"
        default: return "Status unknown"
        }
    }

    var statusIcon: String {
        isConnected ? "headphones.circle.fill" : "headphones.circle"
    }
}
```

### SwitchIntentBridge (app target only — IPC shim)

Because `SwitchCoordinator` is an `@Observable` object owned by `SyncBudsApp`, the `AppIntent` cannot directly reference it. The cleanest bridge for personal-use scale is a `UserDefaults` flag that the app polls on foreground — but for immediate triggering, a simpler approach is to post a `NotificationCenter` notification that `SyncBudsApp` observes:

```swift
// SwitchIntentBridge.swift — app target only
import Foundation

extension Notification.Name {
    static let widgetSwitchRequested = Notification.Name("widgetSwitchRequested")
}

enum SwitchIntentBridge {
    static func requestSwitch() {
        NotificationCenter.default.post(name: .widgetSwitchRequested, object: nil)
    }
}
```

```swift
// In SyncBudsApp.init() — iOS block only
NotificationCenter.default.addObserver(
    forName: .widgetSwitchRequested,
    object: nil,
    queue: .main
) { [weak coordinator] _ in
    Task { @MainActor in coordinator?.requestSwitch() }
}
```

This pattern mirrors the existing `hotkeyChanged` notification pattern already in `SyncBudsApp.swift` — consistent with existing architecture.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| INTENTConfiguration (SiriKit) | AppIntentConfiguration / StaticConfiguration + AppIntents | iOS 17 (WWDC23) | Old Intents framework deprecated for widgets; use AppIntents |
| Passive-only widgets (no taps) | Interactive widgets with `Button(intent:)` and `Toggle(intent:)` | iOS 17 | Buttons in widgets are now supported and expected |
| getTimeline completion handler | Still used (TimelineProvider is stable; async/await variant available) | iOS 16+ | Both APIs work; completion handler is fine |

**Deprecated/outdated:**
- `INIntentConfiguration` / `IntentConfiguration` with SiriKit Intents: Replaced by `AppIntentConfiguration`. For new widgets, always use `AppIntents`.
- `UIApplicationDelegate` lifecycle hooks for foreground detection: Replaced by SwiftUI `scenePhase` in SwiftUI App lifecycle (which SyncBuds already uses).

---

## Open Questions

1. **ForegroundContinuableIntent behavior with app suspended**
   - What we know: When the app is suspended (not running), `ForegroundContinuableIntent` launches the app to run the intent.
   - What's unclear: Whether the full `SyncBudsApp.init()` (including MultipeerService.start() and wiring) completes fast enough before `perform()` is called, and whether the NotificationCenter observer is registered in time.
   - Recommendation: The `NotificationCenter` approach may be too early in the launch sequence. Alternative: have `SwitchHeadphoneIntent.perform()` write a `UserDefaults` key (e.g., `pendingSwitchRequest = true`), then `SyncBudsApp.init()` checks this key and triggers the switch after setup completes. This is more robust.

2. **App Group provisioning without paid Developer Account**
   - What we know: Xcode automatic signing with a free account creates local App Group entitlements for device testing.
   - What's unclear: Whether the group ID `group.com.syncbuds.shared` works without registering it in the Apple Developer portal (free accounts cannot create App Group IDs in the portal).
   - Recommendation: Test on device with Xcode automatic signing. The App Group should be created automatically by Xcode for free-account local testing. If it fails, use a simpler bundle-ID-derived group: `group.$(PRODUCT_BUNDLE_IDENTIFIER)`.

3. **Widget button disabled state when peer offline**
   - What we know: The widget has no `.disabled()` modifier support with AppIntents buttons in the same way as SwiftUI views.
   - What's unclear: Can the widget button be visually disabled based on `entry.isConnected`?
   - Recommendation: Show the button regardless of connection state; let `requestSwitch()` handle the "not connected to peer" rejection gracefully (already implemented: posts "Not connected to peer device" notification). Widget UX is always slightly behind real state.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| WidgetKit framework | UI-05 widget target | ✓ (system) | iOS 14+ — target is iOS 26.2 | — |
| AppIntents framework | UI-05 interactive button | ✓ (system) | iOS 16+ — target is iOS 26.2 | — |
| UserDefaults App Group | D-06 widget state sharing | ✓ (requires Xcode capability) | — | — |
| Xcode Widget Extension target | UI-05 | ✓ (manual creation step) | Xcode 26.3 | — |

**Missing dependencies with no fallback:** None — all APIs are system frameworks available at the deployment target.

**Action required before code:** Create the Widget Extension target in Xcode (File → New → Target → Widget Extension). This is a one-time manual Xcode step that cannot be scripted by code tasks.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Swift Testing (`@Test` macros in `SyncBudsTests/`) |
| Config file | Xcode scheme (no standalone config file) |
| Quick run command | `xcodebuild test -scheme SyncBuds -destination 'platform=iOS Simulator,name=iPhone 16'` |
| Full suite command | Same (single scheme covers all unit tests) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SW-06 | Auto-switch fires on foreground when peer has headphone | unit | `xcodebuild test -scheme SyncBuds ...` | ❌ Wave 0 |
| SW-06 | Auto-switch does NOT fire when toggle disabled | unit | same | ❌ Wave 0 |
| SW-06 | Auto-switch does NOT fire when peerBTStatus != "connected" | unit | same | ❌ Wave 0 |
| UI-05 | WidgetStateWriter writes correct keys to App Group | unit | same | ❌ Wave 0 |
| UI-05 | SyncBudsWidgetEntry computes correct statusTitle/statusSubtitle | unit | same | ❌ Wave 0 |
| UI-05 | SwitchHeadphoneIntent.perform() posts widgetSwitchRequested notification | unit | same | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** Quick targeted test for touched component
- **Per wave merge:** Full suite
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `SyncBudsTests/AutoSwitchTests.swift` — covers SW-06 logic (mock scenePhase + mock coordinator)
- [ ] `SyncBudsTests/WidgetStateWriterTests.swift` — covers App Group write correctness
- [ ] `SyncBudsTests/WidgetEntryTests.swift` — covers computed label strings
- [ ] `SyncBudsTests/SwitchIntentTests.swift` — covers intent bridge notification

> Note: WidgetKit itself cannot be unit tested easily (TimelineProvider needs real WidgetKit context). Test the data layer (Entry computed properties, WidgetStateWriter) rather than the WidgetConfiguration.

---

## Project Constraints (from CLAUDE.md)

| Directive | Impact on Phase 5 |
|-----------|------------------|
| No external dependencies | No third-party widget libraries; WidgetKit + AppIntents are system frameworks — compliant |
| Swift + SwiftUI + SwiftData only | Widget views in SwiftUI only; state via UserDefaults (Foundation), not external packages — compliant |
| iOS 26.2+ deployment target | All WidgetKit interactive features (iOS 17+ requirement) are well within target — compliant |
| No Dock icon / menu bar on macOS | Widget is iOS-only target — no macOS impact |
| Functional > polished | Simple widget layout; no animations — compliant with stated priority |
| PascalCase filenames matching primary type | `SyncBudsWidget.swift`, `SwitchHeadphoneIntent.swift`, `SyncBudsWidgetEntry.swift` etc. |
| Commit message format: emoji conventional | Applies to all commits in this phase |
| #if os() file-level guards for platform-specific code | `WidgetStateWriter` calls in `MultipeerService` wrapped with `#if os(iOS)` |

---

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation: [Adding interactivity to widgets and Live Activities](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities) — AppIntents Button pattern
- Apple Developer Documentation: [WidgetFamily.systemMedium](https://developer.apple.com/documentation/widgetkit/widgetfamily/systemmedium) — widget size API
- Apple Developer Documentation: [ForegroundContinuableIntent](https://developer.apple.com/documentation/appintents/foregroundcontinuableintent) — intent routing protocol
- Apple Developer Documentation: [ScenePhase](https://developer.apple.com/documentation/swiftui/scenephase) — foreground detection

### Secondary (MEDIUM confidence)
- [Creating an interactive widget with SwiftUI](https://www.createwithswift.com/creating-interactive-widget-swiftui/) — full code examples verified against Apple docs
- [Snip: Create A Basic Interactive Widget Using App Intent Button](https://swiftjectivec.com/Snip-Create-A-Basic-Interactive-Widget-Using-App-Intent-Button/) — Button(intent:) syntax
- [Forcing an AppIntent to run in the main app process](https://zachwaugh.com/posts/forcing-appintent-to-run-in-main-app-process) — ForegroundContinuableIntent extension pattern
- [Sharing UserDefaults with widgets](https://developer.apple.com/forums/thread/651799) — App Group UserDefaults pattern (Apple Developer Forums)
- [SwiftUI App Lifecycle Mastery](https://dev.to/sebastienlato/swiftui-app-lifecycle-mastery-scene-phases-background-tasks-state-44ao) — scenePhase at App vs View level

### Tertiary (LOW confidence — needs validation on device)
- Open Question 1: ForegroundContinuableIntent launch timing when app is suspended — not officially documented with timing guarantees
- Open Question 2: App Group provisioning behavior with free Apple Developer Account

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — WidgetKit + AppIntents are stable documented APIs at iOS 17+; project targets iOS 26.2
- Architecture patterns: HIGH — verified against multiple official sources and working code examples
- Pitfalls: MEDIUM — Pitfalls 1–5 verified; Pitfall 6 (free account App Group) is from inference + forum posts, not official docs
- ForegroundContinuableIntent launch timing: LOW — not covered in official docs with specific timing guarantees

**Research date:** 2026-03-26
**Valid until:** 2026-09-26 (WidgetKit APIs are stable; AppIntents evolves yearly at WWDC but interactive widget pattern is established)
