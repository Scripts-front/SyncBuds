---
phase: 2
slug: communication
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-26
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Nyquist Compliance Rationale

**nyquist_compliant: true** — All automatable tasks have grep/build verification commands. The single manual-only verification (real-device Multipeer Connectivity test) is covered by an explicit `checkpoint:human-verify` in Plan 02-05.

**wave_0_complete: true** — Plan 02-01 creates SyncSignal unit tests as its first task (TDD pattern). These tests serve as Wave 0 infrastructure for the signal format. MultipeerService testing requires two physical Apple devices on the same network — no simulator-based unit test can validate peer discovery or message delivery.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (@Test macro) |
| **Config file** | SyncBudsTests/SyncSignalTests.swift |
| **Quick run command** | `xcodebuild test -scheme SyncBuds -destination 'platform=macOS'` |
| **Full suite command** | `xcodebuild test -scheme SyncBuds -destination 'platform=macOS' && xcodebuild build -scheme SyncBuds -destination 'generic/platform=iOS'` |
| **Estimated runtime** | ~30 seconds |
| **CI environment** | Linux — xcodebuild unavailable; file-level grep verification used |

---

## Sampling Rate

- **After every task commit:** Run task's `<verify>` command (grep/ls)
- **After every plan wave:** Confirm all task verify commands pass
- **Before `/gsd:verify-work`:** Full suite must be green; hardware test documented in Plan 02-05
- **Max feedback latency:** 30 seconds for automated checks

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------|-------------------|--------|
| 02-01-T1 | 01 | 1 | COM-01 | unit | `grep "@Test" SyncBudsTests/SyncSignalTests.swift` | ⬜ pending |
| 02-01-T2 | 01 | 1 | COM-01 | unit | `xcodebuild test` (6 SyncSignal tests) | ⬜ pending |
| 02-02-T1 | 02 | 1 | COM-01 | file | `grep "network.client" SyncBuds/SyncBuds.entitlements` | ⬜ pending |
| 02-02-T2 | 02 | 1 | COM-01 | file | `grep "syncbuds-bt" SyncBuds/Info.plist` | ⬜ pending |
| 02-03-T1 | 03 | 2 | COM-01 | file | `grep "MCSession\|MCNearbyServiceAdvertiser" SyncBuds/Shared/MultipeerService.swift` | ⬜ pending |
| 02-04-T1 | 04 | 3 | COM-01 | file | `grep "MultipeerService" SyncBuds/SyncBudsApp.swift` | ⬜ pending |
| 02-04-T2 | 04 | 3 | COM-01 | file | `grep "multipeerService" SyncBuds/macOS/BluetoothManager.swift` | ⬜ pending |
| 02-04-T3 | 04 | 3 | BT-04 | file | `grep "peerBluetoothStatus\|connectedPeerName" SyncBuds/ContentView.swift` | ⬜ pending |
| 02-05-T1 | 05 | 4 | COM-01, BT-04 | **manual** | Real-device Multipeer verification (checkpoint:human-verify) | ⬜ pending |

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Mac and iPhone discover each other via Multipeer | COM-01 | Requires two physical Apple devices on same Wi-Fi | Run on Mac + iPhone, verify peer appears |
| Signal sent from Mac arrives on iPhone within 500ms | COM-01 | Network latency measurement requires real devices | Send switch signal, time arrival |
| Both apps display live connection status | BT-04 | Requires real Bluetooth headphone + two devices | Connect headphone, verify status shows on both |
| Multipeer reconnects after brief disconnection | COM-01 | Network behavior requires real environment | Disconnect/reconnect Wi-Fi, verify recovery |

---

## Validation Sign-Off

- [x] All tasks have automated verify commands or documented manual rationale
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covered by Plan 02-01 TDD (SyncSignal tests created first)
- [x] No watch-mode flags
- [x] Feedback latency < 30s for automated checks
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** nyquist_compliant — manual verifications covered by Plan 02-05 checkpoint
