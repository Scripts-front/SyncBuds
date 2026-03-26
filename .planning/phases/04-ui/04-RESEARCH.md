# Phase 4: UI - Research

**Researched:** 2026-03-26
**Domain:** SwiftUI MenuBarExtra (macOS), global keyboard shortcut (macOS), iOS widget-style card layout, LSUIElement, iOS 26 Liquid Glass
**Confidence:** HIGH (core APIs confirmed; keyboard shortcut sandboxing pitfall verified from Apple Developer Forums)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Mac app uses MenuBarExtra with icon + dropdown menu style (not popover).
- **D-02:** No Dock icon — set LSUIElement = true in Info.plist.
- **D-03:** Claude's discretion on menu content — should include at minimum: headphone name, connection status, switch button, peer status.
- **D-04:** Menu bar icon should visually reflect connected vs disconnected state.
- **D-05:** iOS app should use a widget-style card layout — clean, modern, with rounded corners and clear visual hierarchy.
- **D-06:** User wants the switch available in Control Center and as a home screen Widget too — Widget (UI-05) is Phase 5 scope, but the app UI should be designed with this in mind.
- **D-07:** Claude's discretion on specific layout — should be visually appealing and functional.
- **D-08:** Global keyboard shortcut on Mac must be configurable by the user (not hard-coded).
- **D-09:** Claude's discretion on default shortcut and settings UI for changing it.

### Claude's Discretion
- Menu bar dropdown content and styling
- iOS card/widget visual design details
- Default keyboard shortcut value
- Settings UI for keyboard shortcut configuration
- Menu bar icon design (SF Symbols)
- Color scheme and visual polish level

### Deferred Ideas (OUT OF SCOPE)
- **iOS Widget (UI-05)** — Phase 5 scope. iOS app design should be widget-compatible but widget itself deferred.
- **Control Center integration** — Requires WidgetKit + Control Center API. Deferred to Phase 5.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| UI-01 | Mac app lives in menu bar via MenuBarExtra (.window style), no Dock icon (LSUIElement) | MenuBarExtra API confirmed; CONTEXT.md overrides to .menu style; LSUIElement = true in macOS Info.plist |
| UI-02 | Menu bar popover shows connected device, status, and one-click switch button | SwitchCoordinator.switchState + MultipeerService observables ready to bind; menu style confirmed for D-01 |
| UI-03 | Global keyboard shortcut on Mac to trigger switch (configurable hotkey) | Carbon RegisterEventHotKey confirmed for sandboxed apps; @AppStorage for persistence |
| UI-04 | iOS app shows connection status and switch button with minimalist interface | GroupBox card pattern + iOS 26 glassEffect modifier; AudioRouteMonitor + MultipeerService ready |
</phase_requirements>

---

## Summary

Phase 4 replaces the test harness `ContentView.swift` with a production-ready dual-platform UI. On macOS the `WindowGroup` in `SyncBudsApp.swift` is replaced with a `MenuBarExtra` using the `.menu` style (dropdown, not popover — confirmed by D-01); `LSUIElement = true` hides the Dock icon. The menu bar icon switches between SF Symbols based on `MultipeerService.isConnectedToPeer` and `peerBluetoothStatus`. A configurable global keyboard shortcut triggers `SwitchCoordinator.requestSwitch()` from anywhere on the system. On iOS the single-screen interface uses `GroupBox` cards styled with the iOS 26 `.glassEffect()` modifier for the widget-style look requested in D-05.

The existing `@Observable` services (`MultipeerService`, `SwitchCoordinator`, `BluetoothManager`) are already wired and injected via `.environment()` in `SyncBudsApp.swift`. The UI layer only needs to bind to their published state — no new service wiring is required.

**CRITICAL SANDBOXING CONSTRAINT:** The app has `com.apple.security.app-sandbox = true` in `SyncBuds.entitlements`. This rules out `NSEvent.addGlobalMonitorForEvents` (requires Accessibility permission, blocked by sandbox). The only viable no-dependency global hotkey approach for a sandboxed app is **Carbon `RegisterEventHotKey`**, which works in the sandbox and does not require user permission. Key-code and modifier flags are stored in `@AppStorage` (UserDefaults) for persistence.

**Primary recommendation:** On macOS use MenuBarExtra(.menu) + Carbon RegisterEventHotKey stored in @AppStorage. On iOS use GroupBox + .glassEffect() cards. Both bind directly to the existing @Observable service layer.

---

## Standard Stack

### Core (all Apple system frameworks — no external dependencies per CLAUDE.md constraint)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI MenuBarExtra | macOS 13+ | Menu bar scene on Mac | SwiftUI-native; replaces NSStatusItem boilerplate; project targets macOS 26.2 |
| Carbon (global hotkeys only) | macOS 10.0+ | RegisterEventHotKey for global shortcuts | Only sandbox-compatible global hotkey API; no modern replacement exists |
| @AppStorage | iOS 17+ / macOS 14+ | Persist hotkey keyCode + modifierFlags | Thin UserDefaults wrapper; no extra storage layer needed |
| SwiftUI Settings scene | macOS 13+ | Hotkey configuration pane | Native macOS Settings window; Command+, opens it |
| GroupBox | iOS 14+ | Card containers on iOS | Native widget-like grouping; supports custom GroupBoxStyle |
| glassEffect modifier | iOS 26+ / macOS 26+ | Liquid Glass card styling | Project targets iOS 26.2; native to target SDK |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Carbon RegisterEventHotKey | NSEvent.addGlobalMonitorForEvents | NSEvent requires Accessibility permission — blocked by app sandbox. Not viable. |
| Carbon RegisterEventHotKey | CGEventTap | Also works in sandbox (Input Monitoring privilege) but more complex; no advantage for a simple 1-hotkey scenario |
| glassEffect (.regular) | GroupBox + RoundedRectangle | GroupBox works on any OS version; glassEffect is iOS 26-only. Since project targets iOS 26.2, glassEffect is the right choice |
| SF Symbols dynamic icon | Custom NSImage | SF Symbols render at correct menu bar size automatically; custom images need NSImage scaling workarounds |

---

## Architecture Patterns

### macOS App Structure Change

The most significant structural change is replacing `WindowGroup` with `MenuBarExtra` in `SyncBudsApp.swift`:

```swift
// Source: Apple Developer Docs — MenuBarExtra
var body: some Scene {
    #if os(macOS)
    MenuBarExtra {
        MacMenuView()
            .environment(multipeerService)
            .environment(switchCoordinator)
    } label: {
        // Dynamic icon based on connection state
        Image(systemName: menuBarIconName)
    }
    .menuBarExtraStyle(.menu)
    .modelContainer(sharedModelContainer)

    Settings {
        HotkeySettingsView()
    }
    #else
    WindowGroup {
        iOSContentView()
            .environment(multipeerService)
            .environment(switchCoordinator)
    }
    .modelContainer(sharedModelContainer)
    #endif
}

// macOS-only computed property for dynamic icon
#if os(macOS)
private var menuBarIconName: String {
    multipeerService.isConnectedToPeer ? "headphones.circle.fill" : "headphones.circle"
}
#endif
```

**Note:** `MenuBarExtra` does not natively support injecting `.environment()` the same way `WindowGroup` does — environment modifiers go on the content closure, not on the `MenuBarExtra` itself. The `Settings` scene is added alongside `MenuBarExtra` (not nested inside it) so the user can open it via Command+comma.

### macOS Menu Content Pattern

With `.menuBarExtraStyle(.menu)`, the content closure body must contain only menu-compatible SwiftUI views: `Button`, `Divider`, `Text`, `Toggle`, `Picker`. `VStack`, `HStack`, and complex views are NOT rendered in `.menu` style — the menu renders each top-level child as a menu item.

```swift
// Source: Apple developer community verified pattern
struct MacMenuView: View {
    @Environment(MultipeerService.self) private var multipeerService
    @Environment(SwitchCoordinator.self) private var switchCoordinator

    var body: some View {
        // Peer status line (Text renders as disabled menu item — greyed out, non-interactive)
        if multipeerService.isConnectedToPeer {
            Text("Connected to \(multipeerService.connectedPeerName ?? "peer")")
        } else {
            Text("Peer offline")
        }

        Text(headphoneStatusText)  // e.g. "Headphone: on iPhone"

        Divider()

        // Switch button — only interactive element
        Button(switchLabel) {
            Task { switchCoordinator.requestSwitch() }
        }
        .disabled(switchDisabled)

        Divider()

        Button("Settings...") {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }

        Button("Quit SyncBuds") {
            NSApp.terminate(nil)
        }
    }
}
```

**Quit button is MANDATORY** because `LSUIElement = true` removes the app from Dock and app switcher — there is no other way to quit without a menu item.

**Settings button** requires the `NSApp.sendAction(Selector("showSettingsWindow:"))` pattern since there is no SwiftUI-native API to open the Settings window from code in macOS 13-14. (On macOS 14+ `openSettings` environment action is available but the Selector pattern is the most reliable cross-version approach.)

### Dynamic Menu Bar Icon

The label closure of `MenuBarExtra` re-evaluates when `@Observable` state changes, so binding the icon name to `multipeerService.isConnectedToPeer` automatically updates the menu bar icon:

```swift
// Recommended SF Symbol pairs (HIGH confidence — standard Apple icons)
// Connected:    "headphones.circle.fill"   (filled = active)
// Disconnected: "headphones.circle"        (outline = idle)
// Switching:    "arrow.2.circlepath"       (animation indicator)
```

To observe `@Observable` services inside the App struct label closure, the app struct itself must hold `@State var multipeerService`. This is already the case in the existing `SyncBudsApp.swift` — no change needed.

### Global Keyboard Shortcut (macOS, sandboxed)

**Why Carbon:** The app has `com.apple.security.app-sandbox = true`. `NSEvent.addGlobalMonitorForEvents` requires Accessibility permission, which cannot be granted to sandboxed apps. `RegisterEventHotKey` (Carbon) works in the sandbox with no additional permission.

**Implementation pattern:**

```swift
// Source: Apple Developer Forums thread/735223 + HotKey.swift open source reference
import Carbon

final class GlobalHotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    func register(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        unregister()

        // Install Carbon event handler (once per app lifetime)
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, _ in return noErr },  // bridge via stored closure
            1,
            &eventType,
            nil,
            &eventHandler
        )

        var hotKeyID = EventHotKeyID(signature: OSType(0x53594E42), id: 1) // 'SYNB'
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }
}
```

**Persistence pattern:**

```swift
// keyCode and modifierFlags stored as integers in @AppStorage
@AppStorage("hotkeyKeyCode") var hotkeyKeyCode: Int = 49  // Space bar default
@AppStorage("hotkeyModifiers") var hotkeyModifiers: Int = Int(cmdKey | shiftKey)  // ⌘⇧
```

**Recommended default:** `⌘⇧Space` (keyCode 49, modifiers: cmdKey | shiftKey). This is unused by the system and intuitively suggests "sending audio somewhere."

**Recorder UI** (in Settings scene): A `NSViewRepresentable` wrapping an `NSTextField` subclass that overrides `keyDown(with:)` captures the next key press and updates the `@AppStorage` values. The display shows the key combination in symbol form (⌘⇧Space).

### iOS Single-Screen Layout

```swift
// Source: iOS 26 glassEffect + GroupBox patterns
struct iOSContentView: View {
    @Environment(MultipeerService.self) private var multipeerService
    @Environment(SwitchCoordinator.self) private var switchCoordinator

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Connection status card
                GroupBox {
                    ConnectionStatusRow(multipeerService: multipeerService)
                }
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))

                // Switch action card
                GroupBox {
                    SwitchButtonRow(switchCoordinator: switchCoordinator)
                }
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16))
            }
            .padding()
        }
        .navigationTitle("SyncBuds")
    }
}
```

**Widget compatibility note (D-06):** Keep state bindings to `@Observable` service objects passed via environment — no `@State` local view state for switch trigger. This structure maps cleanly to a WidgetKit AppIntent (Phase 5) because the switch action (`switchCoordinator.requestSwitch()`) is a single method call.

### Recommended Project Structure

```
SyncBuds/
├── macOS/
│   ├── BluetoothManager.swift         (existing)
│   ├── MacMenuView.swift              (NEW — menu bar dropdown content)
│   └── HotkeySettingsView.swift       (NEW — Settings pane with hotkey recorder)
├── iOS/
│   ├── AudioRouteMonitor.swift        (existing)
│   └── iOSContentView.swift           (NEW — replaces current ContentView for iOS)
├── Shared/
│   ├── GlobalHotkeyManager.swift      (NEW — Carbon hotkey registration, macOS only)
│   ├── MultipeerService.swift         (existing)
│   ├── SwitchCoordinator.swift        (existing)
│   └── Models/                        (existing)
├── ContentView.swift                  (REPLACE with platform-specific views above)
├── SyncBudsApp.swift                  (MODIFY — WindowGroup → MenuBarExtra on macOS)
└── Info.plist                         (MODIFY — add LSUIElement for macOS target)
```

### Anti-Patterns to Avoid

- **VStack/HStack in `.menu` style MenuBarExtra:** Only `Button`, `Divider`, `Text`, `Toggle`, `Picker` render as menu items. Complex views silently fail to appear.
- **Using NSEvent.addGlobalMonitorForEvents in sandboxed app:** Requires Accessibility permission, which cannot be granted by a sandboxed app. Results in silent failure — hotkey never fires.
- **Injecting .environment() on MenuBarExtra itself:** Environment modifiers must go on the content view inside the closure, not on the `MenuBarExtra` scene modifier chain.
- **Hardcoding LSUIElement only in shared Info.plist:** The macOS app needs `LSUIElement = true` in the macOS-specific Info.plist. The current `SyncBuds/Info.plist` is shared — confirm it applies to the macOS target, or use a separate macOS Info.plist.
- **Forgetting a Quit button:** LSUIElement removes all Dock/app-switcher access. Without a Quit menu item, the only escape is `kill` from Terminal.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Hotkey persistence | Custom file storage / NSKeyedArchiver | @AppStorage (UserDefaults) | Two integers (keyCode + modifierFlags); @AppStorage is sufficient and SwiftUI-idiomatic |
| Carbon bridging | C-style function pointers in Swift | Carbon event handler pattern (InstallEventHandler + C closure) | Swift cannot directly pass closures as CFunctionPointer; the bridging requires a static C function or the pattern shown in the code example section |
| Menu bar icon sizing | NSImage dimension manipulation | SF Symbols via Image(systemName:) | SF Symbols render at the correct system-defined menu bar size automatically |
| Settings window presentation | Custom NSWindow management | SwiftUI Settings scene + NSApp.sendAction | The Settings scene handles window lifecycle; no manual NSWindow needed |
| Card styling | Manual UIBezierPath / CALayer | GroupBox + .glassEffect() | Native iOS 26 APIs handle material, shadows, and light refraction automatically |

**Key insight:** The most dangerous hand-roll temptation is the keyboard shortcut. Carbon's `RegisterEventHotKey` looks intimidating but is only ~20 lines. The alternative approaches (`NSEvent` global monitor, `CGEventTap`) either don't work in the sandbox or require user-granted permissions that create a confusing first-run experience.

---

## Common Pitfalls

### Pitfall 1: .menu Style Ignores Non-Menu Views
**What goes wrong:** Developer puts `VStack { Text(...) HStack { ... } }` inside the MenuBarExtra content closure with `.menuBarExtraStyle(.menu)`. Nothing renders — the menu appears empty or shows only part of the structure.
**Why it happens:** `.menu` style maps each top-level child view to a native NSMenuItem. SwiftUI container views (`VStack`, `HStack`, `Group`) are transparent containers and do not generate menu items.
**How to avoid:** Only use `Button`, `Divider`, `Text` (renders as disabled label), `Toggle`, `Picker` as direct children of the menu content view body.
**Warning signs:** Menu opens but shows far fewer items than expected; items from inside nested containers disappear.

### Pitfall 2: LSUIElement in Wrong Plist
**What goes wrong:** `LSUIElement = true` is added to `SyncBuds/Info.plist` which may be the iOS target plist, not the macOS target plist. iOS ignores it; macOS never gets it.
**Why it happens:** The project has a single shared `Info.plist` at `SyncBuds/Info.plist`. In a multi-platform Xcode project, the macOS and iOS targets may reference different Info.plist files, or the same one. The macOS target must be the one that gets `LSUIElement`.
**How to avoid:** Check target membership of `Info.plist` in Xcode target settings. Add `LSUIElement = true` to the plist file linked to the macOS target.
**Warning signs:** App still shows Dock icon after adding LSUIElement; or iOS app crashes on launch with an unexpected key error.

### Pitfall 3: Global Hotkey Silent Failure in Sandbox
**What goes wrong:** Developer uses `NSEvent.addGlobalMonitorForEvents(matching: .keyDown)` expecting the hotkey to work. In the sandboxed app, the handler never fires.
**Why it happens:** `NSEvent` global monitor for keyboard events requires Accessibility permission (`com.apple.security.automation.apple-events` or explicit Accessibility trust). Sandboxed apps cannot receive this permission.
**How to avoid:** Use Carbon `RegisterEventHotKey` instead. It works in the sandbox with no permission prompt required.
**Warning signs:** Hotkey works in simulator/debug builds with sandbox disabled but fails in release build or on device.

### Pitfall 4: @Observable Services Not Observed in App Body
**What goes wrong:** `menuBarIconName` computed property in `SyncBudsApp.body` reads `multipeerService.isConnectedToPeer` but the icon never updates when connection state changes.
**Why it happens:** `@Observable` tracking requires the read to happen inside a SwiftUI view's `body` that is tracked by the observation system. Reading an `@Observable` property inside an `App.body` computed property for a non-view return value may not establish tracking.
**How to avoid:** Move the icon name logic into the `label` closure of `MenuBarExtra` directly (as a `@State`-driven computed property), or use a dedicated `@State var` that is updated via `onChange` on the service.
**Warning signs:** Menu bar icon shows the initial state at launch and never changes thereafter.

### Pitfall 5: Carbon InstallEventHandler C-Closure Bridging
**What goes wrong:** Developer tries to pass a Swift closure directly as the `EventHandlerProcPtr` parameter to `InstallEventHandler` and gets a compile error about `@convention(c)` function pointers.
**Why it happens:** Carbon APIs predate Swift; they expect C function pointers, not Swift closures.
**How to avoid:** Use a `@convention(c)` static function wrapper or the `UnsafeRawPointer` userInfo pattern to forward the call to a Swift method. The simplest pattern is a singleton `GlobalHotkeyManager` that installs a static handler and dispatches via the singleton reference.
**Warning signs:** Compiler error: "a C function pointer cannot be formed from a closure that captures context."

### Pitfall 6: Settings Scene Not Opening from Menu Button
**What goes wrong:** The "Settings..." menu button's action calls `NSApp.sendAction(Selector("showSettingsWindow:"), to: nil, from: nil)` but nothing happens.
**Why it happens:** On macOS 13, the responder chain action for showing the Settings window is `orderFrontStandardAboutPanel:` for About and `showSettingsWindow:` for Settings — but only when a `Settings { }` scene is registered in the App body. If the Settings scene is missing, the action has no receiver.
**How to avoid:** Confirm the `Settings { }` scene is declared alongside `MenuBarExtra` in the App body before wiring the button.
**Warning signs:** Button tap does nothing; no Settings window appears; no crash (action silently finds no receiver).

---

## Code Examples

### MenuBarExtra with Dynamic Icon

```swift
// Source: Verified pattern from MenuBarExtra WWDC22 session + community verification
// In SyncBudsApp.swift (macOS target only)
#if os(macOS)
MenuBarExtra {
    MacMenuView()
        .environment(multipeerService)
        .environment(switchCoordinator)
        .modelContainer(sharedModelContainer)
} label: {
    let connected = multipeerService.isConnectedToPeer
    Image(systemName: connected ? "headphones.circle.fill" : "headphones.circle")
}
.menuBarExtraStyle(.menu)
#endif
```

### Minimal macOS Menu Content

```swift
// MacMenuView.swift
struct MacMenuView: View {
    @Environment(MultipeerService.self) private var multipeerService
    @Environment(SwitchCoordinator.self) private var switchCoordinator

    private var switchLabel: String {
        switch switchCoordinator.switchState {
        case .idle:       return "Switch Headphone"
        case .switching:  return "Switching..."
        case .cooldown:   return "Cooldown..."
        case .error(let msg): return "Error: \(msg)"
        }
    }

    private var switchDisabled: Bool {
        if case .idle = switchCoordinator.switchState { return false }
        return true
    }

    var body: some View {
        // Status row (Text = disabled/greyed menu item — no action)
        if multipeerService.isConnectedToPeer {
            Text(multipeerService.peerBluetoothStatus == "connected"
                 ? "Headphone on \(multipeerService.connectedPeerName ?? "peer")"
                 : "Headphone available")
        } else {
            Text("Peer offline")
        }

        Divider()

        Button(switchLabel) {
            Task { switchCoordinator.requestSwitch() }
        }
        .disabled(switchDisabled)

        Divider()

        Button("Settings\u{2026}") {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }

        Button("Quit SyncBuds") {
            NSApp.terminate(nil)
        }
    }
}
```

### Carbon Hotkey Registration (Sandboxed, No External Deps)

```swift
// Source: Apple Developer Forums thread/735223, HotKey open-source reference
// GlobalHotkeyManager.swift (macOS only, no platform guard needed — file is in macOS/ folder)
import Carbon

final class GlobalHotkeyManager {

    static let shared = GlobalHotkeyManager()
    private var hotKeyRef: EventHotKeyRef?
    private var action: (() -> Void)?

    // Called from AppDelegate or SyncBudsApp.init() on macOS
    func register(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        self.action = action
        unregister()

        // Event handler spec for hotkey-pressed events
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // C-compatible handler using UnsafeRawPointer to bridge to Swift
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, userInfo) -> OSStatus in
                guard let ptr = userInfo else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(ptr).takeUnretainedValue()
                DispatchQueue.main.async { manager.action?() }
                return noErr
            },
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            nil
        )

        var hotKeyID = EventHotKeyID(signature: FourCharCode(0x53594E42), id: 1)
        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }
}
```

### @AppStorage Hotkey Persistence

```swift
// In HotkeySettingsView.swift or a shared ShortcutSettings model
extension UserDefaults {
    static let hotkeyKeyCode = "hotkeyKeyCode"
    static let hotkeyModifiers = "hotkeyModifiers"
}

// Default: ⌘⇧Space
// kVK_Space = 49, cmdKey = 256, shiftKey = 512 (Carbon modifier constants)
@AppStorage("hotkeyKeyCode") var keyCode: Int = 49
@AppStorage("hotkeyModifiers") var modifiers: Int = Int(cmdKey | shiftKey)
```

### iOS Card Layout (iOS 26)

```swift
// iOSContentView.swift
struct iOSContentView: View {
    @Environment(MultipeerService.self) private var multipeerService
    @Environment(SwitchCoordinator.self) private var switchCoordinator

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Connection status card
                    GroupBox("Connection") {
                        HStack {
                            Image(systemName: multipeerService.isConnectedToPeer
                                  ? "circle.fill" : "circle")
                                .foregroundStyle(multipeerService.isConnectedToPeer
                                                 ? Color.green : Color.gray)
                            Text(multipeerService.isConnectedToPeer
                                 ? "Connected to \(multipeerService.connectedPeerName ?? "Mac")"
                                 : "Mac offline")
                            Spacer()
                        }
                        .padding(.top, 4)
                    }
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))

                    // Headphone status card
                    GroupBox("Headphone") {
                        Text(headphoneStatusText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    }
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))

                    // Switch action card
                    GroupBox {
                        Button(switchLabel) {
                            Task { switchCoordinator.requestSwitch() }
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.blue)
                        .disabled(switchDisabled)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                    }
                    .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16))
                }
                .padding()
            }
            .navigationTitle("SyncBuds")
        }
    }

    private var headphoneStatusText: String {
        guard multipeerService.isConnectedToPeer else { return "Unknown" }
        switch multipeerService.peerBluetoothStatus {
        case "connected": return "On Mac (\(multipeerService.connectedPeerName ?? "peer"))"
        case "disconnected": return "Available"
        default: return "Unknown"
        }
    }

    private var switchLabel: String {
        switch switchCoordinator.switchState {
        case .idle:       return "Switch to Mac"
        case .switching:  return "Switching..."
        case .cooldown:   return "Cooldown..."
        case .error(let m): return "Error: \(m)"
        }
    }

    private var switchDisabled: Bool {
        guard case .idle = switchCoordinator.switchState else { return true }
        return !multipeerService.isConnectedToPeer
    }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| NSStatusItem + NSMenu (AppKit) | SwiftUI MenuBarExtra | macOS 13 / WWDC22 | Pure SwiftUI; no AppKit bridging needed |
| MASShortcut / custom Carbon wrappers | Carbon RegisterEventHotKey directly | Still the mechanism; libraries are just wrappers | For 1 hotkey, the wrapper overhead is not worth an external dep |
| UIKit card layouts (UITableViewCell, UICollectionViewCell) | SwiftUI GroupBox + glassEffect | iOS 26 (2025) | Native declarative card with Liquid Glass material |
| ContainerRelativeShape (iOS 14) | ConcentricRectangle + containerShape() | iOS 26 | Automatic concentric corner radii for nested cards |

**Deprecated/outdated:**
- `NSStatusItem` + `NSMenu`: Not deprecated but superseded by `MenuBarExtra` for new SwiftUI apps
- `Option`-only modifier hotkeys with Carbon `RegisterEventHotKey` on macOS 15: Apple intentionally broke single-modifier hotkeys in Sequoia to prevent keyloggers. Always use at least `cmdKey` or `controlKey` combined with another modifier.

---

## Open Questions

1. **Carbon event handler lifetime**
   - What we know: `InstallEventHandler` must remain installed for the hotkey to fire; `GlobalHotkeyManager.shared` singleton pattern keeps it alive.
   - What's unclear: Whether the handler needs to be re-registered after macOS sleep/wake cycles.
   - Recommendation: Test wake-from-sleep on real hardware in Wave 1. If it fails, call `register()` again in `NSWorkspace.didWakeNotification`.

2. **glassEffect availability at runtime**
   - What we know: `glassEffect()` is an iOS 26 / macOS 26 API. The project targets iOS 26.2 and macOS 26.2.
   - What's unclear: Whether Xcode 26.3 ships with the full iOS 26 SDK where `glassEffect` is available without `@available` guards.
   - Recommendation: If the compiler does not recognize `glassEffect`, fall back to `GroupBox` with `.background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 16))`.

3. **LSUIElement scope in multi-target project**
   - What we know: `LSUIElement = true` must be in the macOS target's Info.plist. The current `SyncBuds/Info.plist` may be shared.
   - What's unclear: Whether Xcode routes the shared plist to both iOS and macOS targets or uses separate plists per target.
   - Recommendation: Check the macOS target's "Info.plist File" build setting in Xcode. If shared, add `LSUIElement` anyway — iOS silently ignores it.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode 26.3 | glassEffect API, iOS 26 SDK | Assumed (per CLAUDE.md) | 26.3 | Group Box with manual RoundedRectangle styling |
| Carbon framework (macOS) | RegisterEventHotKey | Always available (system framework) | macOS 10.0+ | — |
| SF Symbols 6+ | headphones.circle.fill, headphones.circle | Bundled with macOS 26 / iOS 26 | — | headphones (fallback symbol, exists in SF 3+) |

**Missing dependencies with no fallback:** None — all required APIs are Apple system frameworks.

---

## Project Constraints (from CLAUDE.md)

- **No external dependencies** — Swift + SwiftUI + SwiftData + Apple frameworks only. `KeyboardShortcuts`, `HotKey`, `MASShortcut` packages are all forbidden. Carbon `RegisterEventHotKey` is the required approach.
- **iOS 26.2+ and macOS 26.2+** — No backwards compatibility shims needed. `glassEffect()` and `MenuBarExtra(.menu)` are both in range.
- **Swift 5.0, PascalCase filenames, 4-space indentation** — New files: `MacMenuView.swift`, `iOSContentView.swift`, `GlobalHotkeyManager.swift`, `HotkeySettingsView.swift`.
- **#if os(macOS) / #if os(iOS) guards** — `GlobalHotkeyManager.swift` placed in `macOS/` folder means no file-level guard needed (Xcode target membership excludes it from iOS). Same pattern as `BluetoothManager.swift`.
- **@Observable with @Environment injection** — All new views use `@Environment(ServiceType.self)` pattern, not `@EnvironmentObject`. Already established in Phases 1-3.
- **Commit format** — emoji conventional commits, no Co-Authored-By lines.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Swift Testing (import Testing) |
| Config file | None — Xcode scheme runs tests automatically |
| Quick run command | `xcodebuild test -scheme SyncBuds -destination 'platform=macOS'` |
| Full suite command | `xcodebuild test -scheme SyncBuds -destination 'platform=macOS' && xcodebuild test -scheme SyncBuds -destination 'platform=iOS Simulator,name=iPhone 16'` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| UI-01 | MenuBarExtra scene replaces WindowGroup on macOS; LSUIElement in plist | Manual (launch app, verify no Dock icon) | — | N/A |
| UI-02 | Menu shows peer name, headphone status, switch button | Manual (open menu, verify items) | — | N/A |
| UI-03 | Global hotkey fires requestSwitch() | Manual (press hotkey, verify switch) | — | N/A |
| UI-03 | Hotkey keyCode + modifierFlags persist across launch | Unit: `HotkeyPersistenceTests` | `xcodebuild test -scheme SyncBuds -only-testing:SyncBudsTests/HotkeyPersistenceTests` | ❌ Wave 0 |
| UI-04 | iOS view shows connection status and switch button | Manual (run on iOS simulator) | — | N/A |

**Note:** UI requirements are inherently manual-verification-heavy. The one automatable piece is hotkey persistence (verifying @AppStorage round-trip).

### Sampling Rate
- **Per task commit:** Run existing `SyncSignalTests` to confirm no regressions — `xcodebuild test -scheme SyncBuds -only-testing:SyncBudsTests/SyncSignalTests`
- **Per wave merge:** Full suite on both platforms
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `SyncBudsTests/HotkeyPersistenceTests.swift` — covers UI-03 @AppStorage round-trip
  - Tests: `keyCodeDefaultsTo49`, `modifiersDefaultToCmdShift`, `persistsAfterWrite`

*(No test framework install needed — Swift Testing already in place)*

---

## Sources

### Primary (HIGH confidence)
- Apple Developer Documentation — MenuBarExtra: `https://developer.apple.com/documentation/SwiftUI/MenuBarExtra`
- Apple Developer Forums — Global hotkeys sandboxed apps: `https://developer.apple.com/forums/thread/735223`
- Apple Developer Forums — NSEvent global monitor requires Accessibility (sandbox blocks): `https://developer.apple.com/forums/thread/100877`
- Apple Developer Forums — RegisterEventHotKey in sandbox: `https://developer.apple.com/forums/thread/735223`

### Secondary (MEDIUM confidence)
- nilcoalescing.com — MenuBarExtra LSUIElement pattern: `https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/`
- nilcoalescing.com — iOS 26 ConcentricRectangle / containerShape: `https://nilcoalescing.com/blog/ConcentricRectangleInSwiftUI/`
- Medium / madebyluddy — iOS 26 glassEffect API reference: `https://medium.com/@madebyluddy/overview-37b3685227aa`
- Apple Developer Docs — MenuBarExtraStyle variants: `https://developer.apple.com/documentation/swiftui/menubarextrastyle`

### Tertiary (LOW confidence — training data, needs validation on real hardware)
- RegisterEventHotKey Carbon API call structure and Swift bridging pattern — derived from open-source implementations (HotKey, Magnet); not directly verified from Apple JSON API docs in this session
- glassEffect modifier availability in Xcode 26.3 — project targets iOS 26.2 but SDK availability at development time is unconfirmed

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — MenuBarExtra, Carbon, @AppStorage, GroupBox, glassEffect all verified against Apple docs or developer forums
- Architecture: HIGH — existing @Observable injection pattern is established; MenuBarExtra .menu limitations are verified from developer community
- Pitfalls: HIGH — sandboxing constraint and .menu style limitations are verified against Apple Developer Forums; Carbon bridging pattern is LOW (derived from open source, not Apple docs directly)

**Research date:** 2026-03-26
**Valid until:** 2026-06-26 (stable APIs; glassEffect is new in iOS 26, watch for beta changes)
