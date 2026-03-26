---
phase: 1
slug: foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-25
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (@Test macro) + XCTest |
| **Config file** | SyncBudsTests/SyncBudsTests.swift |
| **Quick run command** | `xcodebuild test -scheme SyncBuds -destination 'platform=macOS'` |
| **Full suite command** | `xcodebuild test -scheme SyncBuds -destination 'platform=macOS' && xcodebuild build -scheme SyncBuds -destination 'generic/platform=iOS'` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild build -scheme SyncBuds -destination 'platform=macOS'`
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | INF-01 | build | `xcodebuild build` (entitlements present) | ❌ W0 | ⬜ pending |
| 01-01-02 | 01 | 1 | INF-02 | build | `xcodebuild build` (CloudKit entitlements) | ❌ W0 | ⬜ pending |
| 01-01-03 | 01 | 1 | INF-03 | build | `xcodebuild build -destination iOS` (no IOBluetooth leak) | ❌ W0 | ⬜ pending |
| 01-02-01 | 02 | 1 | INF-04 | unit | `swift test` (SwiftData model) | ❌ W0 | ⬜ pending |
| 01-02-02 | 02 | 1 | BT-03 | unit | `swift test` (persistence) | ❌ W0 | ⬜ pending |
| 01-03-01 | 03 | 2 | BT-01 | manual | Device enumeration on real Mac | N/A | ⬜ pending |
| 01-03-02 | 03 | 2 | BT-02 | manual | AVAudioSession route on real device | N/A | ⬜ pending |

---

## Wave 0 Requirements

- [ ] Test target compiles and runs
- [ ] BluetoothDevice model unit tests created

*Note: IOBluetooth hardware interaction cannot be unit tested — requires manual verification on real devices.*

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

- [ ] All tasks have automated verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
