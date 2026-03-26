---
phase: 02-communication
plan: 02
subsystem: permissions
tags: [multipeer-connectivity, entitlements, info-plist, local-network, bonjour]
dependency_graph:
  requires: []
  provides: [mcf-permissions-ready]
  affects: [02-03-MultipeerService]
tech_stack:
  added: []
  patterns: [macOS-sandbox-entitlements, iOS-info-plist-permissions]
key_files:
  created: []
  modified:
    - SyncBuds/SyncBuds.entitlements
    - SyncBuds/Info.plist
decisions:
  - "Service type string 'syncbuds-bt' (11 chars, letters+hyphen only) locked in at permission layer — must match Plan 03 MultipeerService constant exactly"
metrics:
  duration: 5min
  completed: 2026-03-26
---

# Phase 02 Plan 02: MCF Platform Permissions Summary

**One-liner:** macOS network.client/server sandbox entitlements + iOS NSLocalNetworkUsageDescription and NSBonjourServices for _syncbuds-bt._tcp/_udp to unblock silent MCF peer discovery failure.

## What Was Built

Added the two sets of platform-level permissions required for Multipeer Connectivity Framework (MCF) to advertise and discover peers without silent failure.

### Task 1 — macOS network sandbox entitlements (SyncBuds/SyncBuds.entitlements)

Added `com.apple.security.network.client` and `com.apple.security.network.server` to the macOS App Sandbox. Without these, the MCNearbyServiceAdvertiser starts without error but no peers are ever discovered (Pitfall 3 from research). All existing keys preserved — app-sandbox, device.bluetooth, and the commented-out CloudKit block.

Commit: `2a5f4a9`

### Task 2 — iOS local network permission + Bonjour declaration (SyncBuds/Info.plist)

Added `NSLocalNetworkUsageDescription` (triggers iOS system permission prompt) and `NSBonjourServices` array with both `_syncbuds-bt._tcp` and `_syncbuds-bt._udp` (required for iOS 14+ local network permission enforcement). Without NSBonjourServices, the system blocks MCF traffic silently (Pitfall 2 from research). Existing `NSBluetoothAlwaysUsageDescription` preserved.

Commit: `da0cf92`

## Verification Results

| Check | Result |
|-------|--------|
| grep com.apple.security.network.client entitlements | PASS |
| grep com.apple.security.network.server entitlements | PASS |
| grep NSLocalNetworkUsageDescription Info.plist | PASS |
| grep -c syncbuds-bt Info.plist == 2 | PASS (2) |

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — these are configuration-only changes with no runtime stub code.

## Self-Check: PASSED

- SyncBuds/SyncBuds.entitlements — modified, verified 4 keys present
- SyncBuds/Info.plist — modified, verified 3 keys + 2 Bonjour entries
- Commit 2a5f4a9 — Task 1 (entitlements)
- Commit da0cf92 — Task 2 (Info.plist)
