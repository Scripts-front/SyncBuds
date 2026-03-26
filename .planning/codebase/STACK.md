# Technology Stack

**Analysis Date:** 2026-03-25

## Languages

**Primary:**
- Swift 5.0 - iOS and macOS app development

**Secondary:**
- Objective-C (via interop) - Implicit through Xcode framework integration

## Runtime

**Environment:**
- iOS 26.2+ and macOS 26.2+

**Build System:**
- Xcode 26.3 (implied by build configuration)
- Apple development environment

## Frameworks

**Core:**
- SwiftUI - UI framework for declarative interface building (`SyncBuds/SyncBudsApp.swift`, `SyncBuds/ContentView.swift`)
- SwiftData - Persistent data storage and object modeling (`SyncBuds/Item.swift`, `SyncBuds/SyncBudsApp.swift`)

**Testing:**
- XCTest - Unit and UI testing framework (used in `SyncBudsUITests/SyncBudsUITests.swift`)
- Swift Testing - New Swift-native testing framework (used in `SyncBudsTests/SyncBudsTests.swift`)

**Build/Dev:**
- Xcode Project Format (pbxproj) - Xcode project configuration (`SyncBuds.xcodeproj/project.pbxproj`)

## Key Dependencies

**Critical:**
- SwiftData - Object persistence and data modeling with native Swift syntax
- SwiftUI - Modern declarative UI framework for iOS/macOS

**Framework Integration:**
- Foundation - Standard Swift library (imported in `SyncBuds/Item.swift`)

## Configuration

**Environment:**
- Deployment targets: iOS 26.2, macOS 26.2
- Swift compiler version: 5.0
- Build configuration: Debug and Release variants available

**Build:**
- `SyncBuds.xcodeproj/project.pbxproj` - Main project configuration
- Xcode uses file system synchronization for source group organization
- No external package dependencies declared (packageProductDependencies is empty)

## Platform Requirements

**Development:**
- Xcode 26.3 or later
- macOS 13.0+ (minimum for Xcode 26.3)
- Swift 5.0 toolchain

**Production:**
- Deployment target: iOS 26.2 for iPhone/iPad apps
- Deployment target: macOS 26.2 for macOS apps
- Native Apple silicon and Intel x86_64 architecture support

## Build Architecture

**Project Structure:**
- Main app target: `SyncBuds` (produces `SyncBuds.app`)
- Unit test target: `SyncBudsTests` (produces `SyncBudsTests.xctest`)
- UI test target: `SyncBudsUITests` (produces `SyncBudsUITests.xctest`)

**Dependency Graph:**
- SyncBudsTests depends on SyncBuds target
- SyncBudsUITests depends on SyncBuds target
- No external framework dependencies

---

*Stack analysis: 2026-03-25*
