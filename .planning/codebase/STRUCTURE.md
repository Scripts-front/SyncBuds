# Codebase Structure

**Analysis Date:** 2026-03-25

## Directory Layout

```
/root/SyncBuds/
├── SyncBuds/                    # Main application source code
│   ├── Assets.xcassets/         # Image assets and app icon
│   ├── ContentView.swift        # Primary UI view
│   ├── Item.swift               # Data model
│   └── SyncBudsApp.swift        # App entry point and configuration
├── SyncBudsTests/               # Unit tests
│   └── SyncBudsTests.swift      # Unit test cases
├── SyncBudsUITests/             # UI automation tests
│   ├── SyncBudsUITests.swift    # UI test cases
│   └── SyncBudsUITestsLaunchTests.swift # Launch performance tests
├── SyncBuds.xcodeproj/          # Xcode project configuration
│   ├── project.pbxproj          # Build configuration and file references
│   └── project.xcworkspace/     # Workspace configuration
└── .planning/                   # GSD planning documents
    └── codebase/                # Codebase analysis documents
```

## Directory Purposes

**SyncBuds/ (Main Application):**
- Purpose: Contains all app source code, assets, and runtime logic
- Contains: Swift source files, asset catalog, app entry point
- Key files: `SyncBudsApp.swift`, `ContentView.swift`, `Item.swift`

**SyncBudsTests/ (Unit Tests):**
- Purpose: Contains unit tests using Swift Testing framework
- Contains: Test target source files
- Key files: `SyncBudsTests.swift`

**SyncBudsUITests/ (UI Tests):**
- Purpose: Contains UI automation tests using XCTest
- Contains: UI test target source files, launch performance tests
- Key files: `SyncBudsUITests.swift`, `SyncBudsUITestsLaunchTests.swift`

**SyncBuds.xcodeproj/ (Project Configuration):**
- Purpose: Xcode project settings, build configurations, file references
- Contains: project.pbxproj, workspace configuration
- Key files: `project.pbxproj`

**Assets.xcassets/ (Bundled Assets):**
- Purpose: Stores app resources (images, icons, colors) in Xcode asset catalog format
- Contains: AppIcon.appiconset, AccentColor.colorset, Contents.json
- Key files: Colors and icons used by app UI

## Key File Locations

**Entry Points:**
- `SyncBuds/SyncBudsApp.swift`: Main app entry point with @main decorator
- `SyncBuds/ContentView.swift`: Root UI view displayed to user

**Configuration:**
- `SyncBuds.xcodeproj/project.pbxproj`: Build settings, target definitions, file references
- `SyncBuds.xcodeproj/project.xcworkspace/contents.xcworkspacedata`: Workspace configuration

**Core Logic:**
- `SyncBuds/Item.swift`: Data model with SwiftData @Model decorator
- `SyncBuds/ContentView.swift`: All UI logic (list display, add, delete operations)

**Testing:**
- `SyncBudsTests/SyncBudsTests.swift`: Unit tests (currently empty template)
- `SyncBudsUITests/SyncBudsUITests.swift`: UI tests (currently empty template)
- `SyncBudsUITests/SyncBudsUITestsLaunchTests.swift`: Launch performance tests

## Naming Conventions

**Files:**
- PascalCase for Swift source files: `ContentView.swift`, `SyncBudsApp.swift`, `Item.swift`
- Descriptive names matching primary class/struct: ContentView class in ContentView.swift
- Test files match target with "Tests" suffix: SyncBudsTests.swift for SyncBudsTests target

**Directories:**
- PascalCase for source directories: `SyncBuds/`, `SyncBudsTests/`, `SyncBudsUITests/`
- Suffixes indicate purpose: "Tests" for unit tests, "UITests" for UI automation

**Types (Classes/Structs):**
- PascalCase: `ContentView`, `SyncBudsApp`, `Item`, `SyncBudsTests`
- Functional suffixes: View suffix for SwiftUI views, App suffix for app struct

**Properties & Methods:**
- camelCase for properties and methods: `timestamp`, `modelContext`, `items`, `addItem()`, `deleteItems()`
- Private methods use `private` modifier: `private func addItem()`

## Where to Add New Code

**New Feature (with data persistence):**
- Model definition: `SyncBuds/[FeatureName].swift` (create new @Model class)
- UI: Add view to `SyncBuds/ContentView.swift` or create new `SyncBuds/[FeatureName]View.swift`
- Schema registration: Update `SyncBudsApp.swift` Schema array to include new model
- Tests: Add test methods to `SyncBudsTests/SyncBudsTests.swift`

**New UI Component/View:**
- Implementation: Create `SyncBuds/[ComponentName]View.swift` as new SwiftUI struct
- Integration: Import in ContentView and embed in view hierarchy
- Preview: Include #Preview block for Xcode canvas live preview
- Tests: Add UI tests to `SyncBudsUITests/SyncBudsUITests.swift`

**Utilities/Helper Functions:**
- Shared helpers: Create `SyncBuds/Extensions.swift` or `SyncBuds/Utilities.swift`
- View extensions: Add extension blocks in respective view files
- Model helpers: Add computed properties or methods directly to model files

**New Test Suites:**
- Unit tests: Add @Test functions to `SyncBudsTests/SyncBudsTests.swift`
- UI tests: Add test methods to `SyncBudsUITests/SyncBudsUITests.swift`

## Special Directories

**Assets.xcassets/:**
- Purpose: Xcode asset catalog for images, colors, and icons
- Generated: Compiled at build time into app bundle
- Committed: Yes - source format committed to git
- Structure: Subdirectories per asset type (AppIcon.appiconset, AccentColor.colorset)

**.planning/codebase/:**
- Purpose: GSD codebase analysis and planning documents
- Generated: No - manually created by analysis tools
- Committed: Yes - documents are committed to git
- Contains: ARCHITECTURE.md, STRUCTURE.md, and other analysis documents

**SyncBuds.xcodeproj/:**
- Purpose: Xcode project metadata and build configuration
- Generated: Partially - some xcworkspace user data auto-generated
- Committed: Partially - project.pbxproj committed, xcuserdata typically gitignored
- Contains: Target definitions, build phases, file references, scheme definitions

---

*Structure analysis: 2026-03-25*
