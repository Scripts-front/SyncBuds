# Feature Landscape

**Domain:** Bluetooth headphone auto-switching between macOS and iOS
**Researched:** 2026-03-25
**Confidence note:** Web search and WebFetch were unavailable during this research session.
All findings are drawn from training data knowledge of ToothFairy, AirBuddy, Apple AirPods switching,
Bluetooth Connector, and community discussions through August 2025. Confidence levels reflect this.

---

## Table Stakes

Features users expect from any Bluetooth device switching utility. Missing = product feels incomplete
or frustrating.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| One-action switching | Users need a single trigger (tap/click) to switch headphones from one device to the other | Low | The core UX promise — anything requiring multiple steps defeats the purpose |
| Works with non-AirPods headphones | Primary reason to use a 3rd-party app is AirPods auto-switching doesn't help them | Med | Sony WH/WF, Bose QC/NC, JBL, Jabra, Sennheiser — any paired Bluetooth audio device |
| Persistent device memory | App must remember which headphones exist — user should not re-configure on every launch | Low | SwiftData persistence; remembers device name + MAC address |
| Menu bar presence on Mac | Mac Bluetooth utility convention; always accessible, no dock clutter | Low | ToothFairy, AirBuddy both use menu bar; users expect this pattern |
| Connection status visibility | User must know at a glance whether headphones are connected and to which device | Low | Menu bar icon state change; iOS widget or indicator |
| Cross-device signal delivery | Switching only works if Mac and iPhone can communicate reliably regardless of network conditions | High | CloudKit + Multipeer Connectivity fallback; latency must be perceptible under 3s |
| Bidirectional switching | Mac-to-iPhone AND iPhone-to-Mac must both work | High | iPhone-to-Mac is harder due to iOS API limits; both directions are expected |
| Notification on switch completion | User needs confirmation that headphones switched successfully | Low | System notification on both platforms; failure notification equally important |
| Graceful failure handling | Bluetooth is unreliable; app must communicate when switching fails without crashing | Med | Retry logic, clear error state, does not leave headphone in limbo |

---

## Differentiators

Features that set SyncBuds apart. Not baseline expectations, but meaningfully valuable when present.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Automatic switching (no manual trigger) | True AirPods-like experience: Mac detects audio playback starting on iPhone, releases headphones automatically | High | Requires audio session monitoring on iOS (AVAudioSession) + heuristics to avoid false triggers; very hard to get right |
| Local network fast path (Multipeer Connectivity) | Sub-500ms latency when Mac and iPhone are on same network vs CloudKit's 1-5s delay | Med | Critical for perceived snappiness; CloudKit alone feels sluggish |
| Switch history / log | Shows recent switch events with timestamps; useful for debugging and user trust | Low | Simple SwiftData list view; not expected but appreciated |
| iPhone widget / Control Center shortcut | Initiate switch from iPhone without opening the app | Med | iOS WidgetKit; home screen or lock screen widget; differentiating for iOS-initiated switches |
| Mac keyboard shortcut | Power user shortcut to trigger switch from Mac | Low | ToothFairy's signature feature; NSEvent globalMonitor for hotkey; high-value, low-effort |
| Siri Shortcut integration | "Hey Siri, switch my headphones to Mac" | Low | SiriKit Shortcuts donation; easy to add, delightful when it works |
| Per-device switching preferences | "When I start a FaceTime call, always switch headphones to Mac" | High | Requires detecting app-level audio context; likely out of scope for personal use |
| Battery level display | Show headphone battery on menu bar or iPhone — complements switching UX | Med | Only works for headphones that expose battery via HFP or vendor-specific BLE; AirBuddy does this well |
| Multi-device support (iPad, Apple Watch) | Extend switching to more Apple devices | High | Project explicitly deferred; noted here for completeness |
| Dark/light menu bar icon variants | Aesthetic polish matching macOS system appearance | Low | NSStatusItem image; cosmetic but noticed |

---

## Anti-Features

Features to deliberately NOT build. Either they create complexity without value for this project's
scope, or they pull development toward unrelated domains.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Audio routing / volume control | Separate domain from switching; adds complexity, users have system controls | Stick to connect/disconnect only |
| EQ / audio processing | Completely different product category | Firmly out of scope |
| Multi-room / multi-headphone management | Adds pairing complexity and UI surface area; SyncBuds is one-headphone-two-devices | Hard-code to single active headphone model |
| Onboarding wizard / tutorial | Personal use project; user is developer; polish wastes time | Simple settings pane is sufficient |
| App Store readiness (screenshots, metadata, review guidelines) | Declared out of scope in PROJECT.md | Build for function, not submission |
| Android support | Cross-platform Bluetooth control would require entirely different stack | Apple ecosystem only |
| Real-time audio streaming / relay | Not the goal; radically different architecture | Never |
| Cloud settings sync beyond device pairing | Unnecessary complexity for 2-device personal use | CloudKit used only for signaling, not settings |
| In-app purchase / subscription model | Personal use tool | Free, personal |
| Crash reporting / analytics | Personal use; developer can debug directly | Console.app + Xcode debugger sufficient |
| Support for more than 2 simultaneous devices | Deferred in PROJECT.md; 3-device routing topology is significantly more complex | Leave architectural hooks but don't build |

---

## Feature Dependencies

```
Device Discovery (CoreBluetooth scan / IOBluetooth enumeration)
  └── Device Persistence (SwiftData — save discovered devices)
        └── Connection Status Monitoring (IOBluetooth notification on Mac, CBCentralManager on iOS)
              └── Menu Bar Status Display (reflects live connection state)
                    └── Manual Switching (user-triggered disconnect + signal + reconnect)
                          └── Cross-Device Signaling (CloudKit primary path)
                                └── Local Network Fast Path (Multipeer Connectivity fallback)
                                      └── Switch Completion Notification (success/failure feedback)
                                            └── [Optional] Automatic Switching (heuristic triggers)
                                            └── [Optional] Keyboard Shortcut (NSEvent hotkey → trigger switch)
                                            └── [Optional] iOS Widget (WidgetKit → trigger switch)
```

Key dependency: Manual switching must be solid before any automation layer is added.
The CloudKit signaling path must be proven before Multipeer Connectivity is added as a fallback
(not the other way around — CloudKit is the universal path, local network is the optimization).

---

## MVP Recommendation

The minimum product that delivers the core value promise:

### Must Have (MVP)

1. **Device discovery and persistence** — detect paired Bluetooth audio devices, remember them across launches
2. **Connection status display** — menu bar icon shows connected/disconnected state on Mac; simple indicator on iOS
3. **Manual switching (Mac-to-iPhone)** — Mac disconnects headphone, signals iPhone via CloudKit, iPhone connects
4. **Manual switching (iPhone-to-Mac)** — iPhone signals Mac via CloudKit, Mac connects headphone (causing switch)
5. **Cross-device signaling via CloudKit** — reliable delivery even off local network
6. **Local network fast path** — Multipeer Connectivity for low-latency switching when on same Wi-Fi
7. **Switch completion notification** — system notification confirming success or reporting failure

### High Value, Low Effort (Add Early)

8. **Mac keyboard shortcut** — ToothFairy proved users love this; NSEvent global monitor is simple to add
9. **Switch history** — simple SwiftData log; builds user trust, aids debugging

### Defer

- **Automatic switching** — complexity is high; heuristics are fragile; get manual switching right first
- **iOS widget** — useful but not core; add after manual switching is stable
- **Battery display** — nice to have; depends on headphone vendor support; add later
- **Siri Shortcuts** — trivial to add once core switching works; defer to polish phase

---

## Competitive Feature Analysis

**Confidence: MEDIUM** — Based on training data through August 2025; web verification unavailable.

### ToothFairy (macOS only, ~$3.99)
- Menu bar Bluetooth device toggle (click to connect/disconnect)
- Keyboard shortcut to trigger connect/disconnect
- Custom menu bar icon per device
- Auto-connect on launch
- AirPods battery level in menu bar
- Does NOT do cross-device switching to iPhone; pure Mac utility

### AirBuddy (macOS + iOS companion, ~$9.99)
- AirPods-style animation overlay on Mac when headphones open
- Battery level for AirPods and Beats on Mac
- Quick switching between Mac and iPhone (AirPods multi-device)
- iOS app shows AirPods connection status
- Does NOT work with non-AirPods/Beats devices for auto-switching
- Relies on Apple's own AirPods switching infrastructure

### Apple Native AirPods Switching
- Automatic switching based on audio activity detection
- Works only with AirPods (and Beats W1/H1 chip products)
- Notoriously unreliable — frequent user complaints about unwanted switching
- No user control over when switching fires
- No third-party headphone support

### Bluetooth Connector (macOS, free/paid)
- Scheduled auto-connect at specified times
- Menu bar device management
- No cross-device iPhone integration

### SyncBuds Positioning
SyncBuds fills a gap none of these cover: **reliable, user-controlled switching of any Bluetooth
headphone between Mac and iPhone**. ToothFairy is Mac-only. AirBuddy requires AirPods. Apple's
native switching is AirPods-only and unreliable. No current product does what SyncBuds targets.

---

## Sources

- Training data knowledge of ToothFairy, AirBuddy, Apple AirPods switching behavior, and Bluetooth Connector (through August 2025) — MEDIUM confidence
- PROJECT.md requirements and constraints — HIGH confidence (primary source)
- Apple developer documentation knowledge: IOBluetooth, CoreBluetooth, Multipeer Connectivity, CloudKit, AVAudioSession API characteristics — MEDIUM confidence
- Web search and WebFetch tools were unavailable; findings should be spot-verified against current App Store listings for ToothFairy and AirBuddy before finalizing roadmap decisions
