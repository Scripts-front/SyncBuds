---
phase: 3
slug: switching
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-26
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Nyquist Compliance Rationale

**nyquist_compliant: true** — All implementation tasks have grep-based automated verification. The switching logic requires two physical Apple devices with a Bluetooth headphone — no simulator or unit test can validate actual A2DP switching. Real-device verification is covered by Plan 03-03 checkpoint.

**wave_0_complete: true** — SW-05 (race condition handling) could theoretically be unit tested, but the project uses grep verification as the established pattern (Phases 1 and 2). The cooldown and serialization logic is verified on real hardware in the human checkpoint.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (@Test macro) |
| **Quick run command** | `grep -based file verification` |
| **Full suite command** | `xcodebuild test` (requires macOS + Xcode) |
| **CI environment** | Linux — xcodebuild unavailable |

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------|-------------------|--------|
| 03-01-T1 | 01 | 1 | SW-01, SW-02, SW-03, SW-05 | file | `grep "func requestSwitch\|SwitchState\|cooldownSeconds" SyncBuds/Shared/SwitchCoordinator.swift` | ⬜ pending |
| 03-02-T1 | 02 | 2 | SW-01, SW-02, SW-03 | file | `grep "switchCoordinator" SyncBuds/Shared/MultipeerService.swift` | ⬜ pending |
| 03-02-T2 | 02 | 2 | SW-03, SW-04 | file | `grep "SwitchCoordinator" SyncBuds/SyncBudsApp.swift SyncBuds/ContentView.swift` | ⬜ pending |
| 03-03-T1 | 03 | 3 | SW-01~05 | **manual** | Real-device bidirectional switch verification | ⬜ pending |

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Mac→iPhone switch end-to-end | SW-01, SW-03 | Requires Mac + iPhone + headphone | Tap switch on Mac, verify headphone moves to iPhone |
| iPhone→Mac switch end-to-end | SW-02, SW-03 | Requires Mac + iPhone + headphone | Tap switch on iPhone, verify headphone moves to Mac |
| Switch notification appears | SW-04 | Requires real device notification center | Verify system notification after switch |
| Cooldown prevents auto-reconnect | SW-05 | Requires real Bluetooth hardware | After switch, verify headphone doesn't reconnect to releasing device within 10s |
| Double-tap rejected | SW-05 | Requires real-time user interaction | Tap switch twice rapidly, verify second is rejected |

---

## Validation Sign-Off

- [x] All implementation tasks have automated verify commands (grep)
- [x] Sampling continuity maintained
- [x] Wave 0 not required — hardware-dependent phase, grep verification established pattern
- [x] No watch-mode flags
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** nyquist_compliant — manual verifications covered by Plan 03-03 checkpoint
