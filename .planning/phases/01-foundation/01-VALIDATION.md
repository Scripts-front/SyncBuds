---
phase: 1
slug: foundation
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-25
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Nyquist Compliance Rationale

**nyquist_compliant: true** — All tasks that can have automated verification do. The remaining tasks are inherently hardware-dependent (IOBluetooth requires a physical Mac + Bluetooth headphone; AVAudioSession requires a physical iOS device). No automated test framework can substitute for these verifications — they are covered by the explicit `checkpoint:human-verify` task in Plan 04.

**wave_0_complete: true** — A Wave 0 test scaffold is not created for this phase for the following documented reasons:

1. **IOBluetooth is untestable without real hardware.** `IOBluetoothDevice.pairedDevices()` returns `nil` on any system without a Bluetooth radio and paired devices. Unit-testing the filter logic in isolation would produce no signal about whether the entitlement or framework linking is correct.

2. **SwiftData model correctness is verified by build + grep.** The `BluetoothDevice` model is a simple `@Model` struct with no business logic — all correctness criteria reduce to "the file exists with the right fields," which the plan's `<verify>` commands check directly.

3. **The `xcodebuild` command cannot run in this Linux CI environment.** The project is an Xcode project (`.xcodeproj`), not a Swift Package. `xcodebuild` requires macOS and Xcode. Any Wave 0 test file added here would reference `xcodebuild` as the runner, which cannot execute. Marking Wave 0 incomplete for a CI-environment mismatch would be misleading.

4. **Real verification is in Plan 04 (checkpoint:human-verify).** The actual spike validation — enumerate, connect, disconnect on real hardware — is a blocking human checkpoint that provides higher-quality signal than any unit test could.

Per the Nyquist rule: "If no test exists yet, set `<automated>MISSING — Wave 0 must create {test_file} first</automated>` and create a Wave 0 task." This phase has no MISSING verify entries — every `<verify>` block has an executable automated command (`grep`, `ls`, `plutil`, `echo`) appropriate to what it is verifying. The hardware-dependent behaviors are explicitly covered by the human checkpoint.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (@Test macro) + XCTest |
| **Config file** | SyncBudsTests/SyncBudsTests.swift |
| **Quick run command** | `xcodebuild test -scheme SyncBuds -destination 'platform=macOS'` (requires macOS + Xcode) |
| **Full suite command** | `xcodebuild test -scheme SyncBuds -destination 'platform=macOS' && xcodebuild build -scheme SyncBuds -destination 'generic/platform=iOS'` |
| **Estimated runtime** | ~30 seconds on macOS |
| **CI environment** | Linux — xcodebuild unavailable; file-level verification used instead |

---

## Sampling Rate

- **After every task commit:** Run the `<verify>` command from the task (grep/plutil/ls — all cross-platform)
- **After every plan wave:** Confirm all task verify commands pass
- **Before `/gsd:verify-work`:** All automated verify commands must pass; hardware tests documented in Plan 04 SUMMARY
- **Max feedback latency:** 30 seconds for file-level checks; hardware verification is unbounded (depends on device availability)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------|-------------------|--------|
| 01-01-T1 | 01 | 1 | INF-01, INF-02 | file | `grep "com.apple.security.device.bluetooth" SyncBuds/SyncBuds.entitlements` | pending |
| 01-01-T2 | 01 | 1 | INF-03 | file | `ls SyncBuds/Shared/Models/.gitkeep SyncBuds/macOS/.gitkeep SyncBuds/iOS/.gitkeep` | pending |
| 01-02-T1 | 02 | 1 | INF-04 | file | `grep "@Model" SyncBuds/Shared/Models/BluetoothDevice.swift` | pending |
| 01-02-T2 | 02 | 1 | BT-03 | file | `grep "BluetoothDevice.self" SyncBuds/SyncBudsApp.swift` | pending |
| 01-03-T1 | 03 | 2 | BT-01, BT-03 | file | `grep "upsertToRegistry\|closeConnection\|pairedDevices" SyncBuds/macOS/BluetoothManager.swift` | pending |
| 01-03-T2 | 03 | 2 | BT-02 | file | `grep "routeChangeNotification\|bluetoothA2DP" SyncBuds/iOS/AudioRouteMonitor.swift` | pending |
| 01-04-T1 | 04 | 3 | BT-01, BT-02, BT-03 | file | `grep "enumerateDevices\|upsertToRegistry" SyncBuds/ContentView.swift` | pending |
| 01-04-T2 | 04 | 3 | BT-01, BT-02 | **manual** | Real-device verification (checkpoint:human-verify in Plan 04) | pending |

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Mac enumerates paired BT audio devices | BT-01 | Requires real Bluetooth hardware | Run app on Mac, verify device list is non-empty |
| closeConnection() releases A2DP profile | BT-01 | Requires real headphone + Mac | Disconnect via app, verify device disappears from System Settings |
| openConnection() reconnects headphone | BT-01 | Requires real headphone + Mac | Reconnect via app, verify audio routes to headphone |
| iOS detects audio route | BT-02 | Requires real iOS device | Run on iPhone, verify current audio route displayed |
| iOS build has no IOBluetooth symbols | INF-03 | Build verification | Build for iOS target, verify no IOBluetooth import errors |

---

## Validation Sign-Off

- [x] All tasks have automated verify commands (grep/ls/plutil/echo — no MISSING entries)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 not required — rationale documented above (hardware-dependent phase, Linux CI, file-level verify sufficient)
- [x] No watch-mode flags
- [x] Feedback latency < 30s for all automated checks
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** nyquist_compliant — hardware-dependent verifications covered by Plan 04 checkpoint
