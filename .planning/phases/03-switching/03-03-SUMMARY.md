---
plan: 03-03
phase: 03-switching
status: complete
started: 2026-03-26
completed: 2026-03-26
---

# Plan 03-03: Real-Device Verification — Summary

## What Was Verified

Bidirectional switching tested on real hardware (MacBook Air + iPhone + Redmi Buds 6 Play):

1. ✓ **Mac→iPhone** — Mac disconnects headphone via closeConnection(), iPhone connects. Cooldown prevents auto-reconnect.
2. ✓ **iPhone→Mac** — iPhone sends switchRequest, Mac connects headphone (or confirms already connected).
3. ✓ **Peer discovery** — Mac and iPhone find each other via Multipeer within ~10 seconds.
4. ✓ **Status signals** — Periodic status updates flowing between devices.

## Deviations / Fixes During Testing

- `openConnection()` fails with error `0xE00002D6` when headphone is still connected to iPhone — fixed by adding retry logic with increasing delays (1s, 2s, 3s, 4s, 5s)
- `.onAppear` in WindowGroup does not fire reliably on macOS — moved service initialization to `App.init()`
- `SwitchCoordinator.swift` needed `#if os(macOS) import IOBluetooth` (same pattern as ContentView)

## Requirements Verified

- **SW-01**: Mac disconnects headphone programmatically ✓
- **SW-02**: Mac connects headphone programmatically ✓
- **SW-03**: Bidirectional switching end-to-end ✓
- **SW-04**: Notification framework wired (permission flow works) ✓
- **SW-05**: Cooldown prevents auto-reconnect, state machine serializes requests ✓

## Self-Check: PASSED
