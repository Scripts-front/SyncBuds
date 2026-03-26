---
phase: 4
slug: ui
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-26
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

## Nyquist Compliance Rationale

**nyquist_compliant: true** — All tasks have grep-based automated verification. UI visual quality requires real device inspection but structural correctness is verified by file/grep checks.

**wave_0_complete: true** — No test infrastructure needed. UI verification is visual + structural grep.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------|-------------------|--------|
| 04-01-T1 | 01 | 1 | UI-01 | file | `grep "LSUIElement" SyncBuds/Info.plist` | ⬜ pending |
| 04-01-T2 | 01 | 1 | UI-02 | file | `grep "MenuBarExtra" SyncBuds/SyncBudsApp.swift` | ⬜ pending |
| 04-01-T3 | 01 | 1 | UI-01, UI-04 | file | `grep "headphones.circle" SyncBuds/macOS/MacMenuView.swift` | ⬜ pending |
| 04-02-T1 | 02 | 2 | UI-03 | file | `grep "RegisterEventHotKey" SyncBuds/macOS/GlobalHotkeyManager.swift` | ⬜ pending |
| 04-02-T2 | 02 | 2 | UI-03 | file | `grep "HotkeySettingsView" SyncBuds/macOS/HotkeySettingsView.swift` | ⬜ pending |
| 04-03-T1 | 03 | 2 | UI-04 | file | `grep "glassEffect\|GroupBox" SyncBuds/iOS/iOSContentView.swift` | ⬜ pending |
| 04-03-T2 | 03 | 2 | UI-04 | file | `grep "iOSContentView" SyncBuds/SyncBudsApp.swift` | ⬜ pending |

---

## Validation Sign-Off

- [x] All tasks have automated verify commands
- [x] No watch-mode flags
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** nyquist_compliant
