# Requirements: SyncBuds

**Defined:** 2026-03-25
**Core Value:** When a user wants to use their Bluetooth headphones on a different device, the switch happens automatically — no manual disconnecting/reconnecting required.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Bluetooth Detection

- [x] **BT-01**: Mac app detects all paired Bluetooth audio devices (A2DP/HFP) via IOBluetooth
- [x] **BT-02**: iOS app detects current audio route and connected Bluetooth device via AVAudioSession
- [x] **BT-03**: App persists known devices across launches (name, MAC address, last seen)
- [ ] **BT-04**: App shows real-time connection status (connected/disconnected, which device has it)
- [ ] **BT-05**: App displays headphone battery level when available via HFP or vendor BLE profile

### Switching

- [ ] **SW-01**: Mac can programmatically disconnect a Bluetooth audio device via IOBluetooth closeConnection()
- [ ] **SW-02**: Mac can programmatically connect a known Bluetooth audio device via IOBluetooth openConnection()
- [ ] **SW-03**: Bidirectional switching works end-to-end (Mac→iPhone and iPhone→Mac)
- [ ] **SW-04**: Switch completion triggers system notification on both platforms (success or failure)
- [ ] **SW-05**: Switching handles race conditions (headphone auto-reconnect suppression, cooldown window)
- [ ] **SW-06**: Automatic switching based on audio activity detection (heuristic-based, no manual trigger)

### Communication

- [x] **COM-01**: Mac and iPhone communicate via Multipeer Connectivity as primary channel (~50-300ms latency)
- [ ] **COM-02**: CloudKit serves as fallback channel when devices are not on the same local network
- [ ] **COM-03**: SignalRouter automatically selects best available transport (Multipeer preferred, CloudKit fallback)
- [ ] **COM-04**: Communication survives iOS background state (CloudKit silent push for wake)

### UI/UX

- [ ] **UI-01**: Mac app lives in menu bar via MenuBarExtra (.window style), no Dock icon (LSUIElement)
- [ ] **UI-02**: Menu bar popover shows connected device, status, and one-click switch button
- [ ] **UI-03**: Global keyboard shortcut on Mac to trigger switch (configurable hotkey)
- [ ] **UI-04**: iOS app shows connection status and switch button with minimalist interface
- [ ] **UI-05**: iOS home screen widget to initiate switch without opening app (WidgetKit)

### Infrastructure

- [ ] **INF-01**: Bluetooth entitlement configured (com.apple.security.device.bluetooth) for macOS sandbox
- [ ] **INF-02**: CloudKit entitlements and container configured in Apple Developer portal
- [ ] **INF-03**: Platform-gated code via #if os(macOS) / #if os(iOS) in shared Swift files
- [x] **INF-04**: SwiftData models for device registry and switch history

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Automation

- **AUTO-01**: Per-device switching preferences (e.g., "always switch to Mac for FaceTime calls")
- **AUTO-02**: Siri Shortcut integration ("Hey Siri, switch my headphones to Mac")

### Polish

- **POL-01**: Dark/light menu bar icon variants matching system appearance
- **POL-02**: Switch history log with timestamps and device details
- **POL-03**: App Store readiness (onboarding, screenshots, metadata)

## Out of Scope

| Feature | Reason |
|---------|--------|
| Audio routing / volume control | Separate domain; users have system controls |
| EQ / audio processing | Different product category entirely |
| Multi-headphone management | SyncBuds is one-headphone-two-devices; multi-headphone adds complexity |
| Android support | Apple ecosystem only |
| Real-time audio streaming | Not the goal; radically different architecture |
| More than 2 devices (iPad, Watch) | 3-device routing is significantly more complex; defer |
| Crash reporting / analytics | Personal use; developer can debug directly |
| In-app purchase / subscription | Personal use tool |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| BT-01 | Phase 1 | Complete |
| BT-02 | Phase 1 | Complete |
| BT-03 | Phase 1 | Complete |
| BT-04 | Phase 2 | Pending |
| BT-05 | Phase 5 | Pending |
| SW-01 | Phase 3 | Pending |
| SW-02 | Phase 3 | Pending |
| SW-03 | Phase 3 | Pending |
| SW-04 | Phase 3 | Pending |
| SW-05 | Phase 3 | Pending |
| SW-06 | Phase 5 | Pending |
| COM-01 | Phase 2 | Complete |
| COM-02 | Phase 2 | Pending |
| COM-03 | Phase 2 | Pending |
| COM-04 | Phase 2 | Pending |
| UI-01 | Phase 4 | Pending |
| UI-02 | Phase 4 | Pending |
| UI-03 | Phase 4 | Pending |
| UI-04 | Phase 4 | Pending |
| UI-05 | Phase 5 | Pending |
| INF-01 | Phase 1 | Pending |
| INF-02 | Phase 1 | Pending |
| INF-03 | Phase 1 | Pending |
| INF-04 | Phase 1 | Complete |

**Coverage:**
- v1 requirements: 24 total
- Mapped to phases: 24
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-25*
*Last updated: 2026-03-25 after roadmap creation*
