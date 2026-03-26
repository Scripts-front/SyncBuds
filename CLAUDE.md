<!-- GSD:project-start source:PROJECT.md -->
## Project

**SyncBuds**

SyncBuds is a native macOS + iOS app that enables automatic Bluetooth headphone switching between Mac and iPhone. Unlike AirPods' native ecosystem switching, SyncBuds works with any Bluetooth headphone (Sony, JBL, Bose, etc.), delivering the same seamless experience for third-party devices.

**Core Value:** When a user wants to use their Bluetooth headphones on a different device, the switch happens automatically — no manual disconnecting/reconnecting required.

### Constraints

- **iOS Bluetooth API**: iOS cannot programmatically disconnect audio (A2DP/HFP) devices — switching strategy must work around this limitation
- **Communication latency**: CloudKit has variable latency; local network fallback needed for responsive switching
- **Personal use**: No need for extensive error handling, onboarding, or polish — functional > polished
- **Tech stack**: Swift + SwiftUI + SwiftData, no external dependencies
<!-- GSD:project-end -->

<!-- GSD:stack-start source:codebase/STACK.md -->
## Technology Stack

## Languages
- Swift 5.0 - iOS and macOS app development
- Objective-C (via interop) - Implicit through Xcode framework integration
## Runtime
- iOS 26.2+ and macOS 26.2+
- Xcode 26.3 (implied by build configuration)
- Apple development environment
## Frameworks
- SwiftUI - UI framework for declarative interface building (`SyncBuds/SyncBudsApp.swift`, `SyncBuds/ContentView.swift`)
- SwiftData - Persistent data storage and object modeling (`SyncBuds/Item.swift`, `SyncBuds/SyncBudsApp.swift`)
- XCTest - Unit and UI testing framework (used in `SyncBudsUITests/SyncBudsUITests.swift`)
- Swift Testing - New Swift-native testing framework (used in `SyncBudsTests/SyncBudsTests.swift`)
- Xcode Project Format (pbxproj) - Xcode project configuration (`SyncBuds.xcodeproj/project.pbxproj`)
## Key Dependencies
- SwiftData - Object persistence and data modeling with native Swift syntax
- SwiftUI - Modern declarative UI framework for iOS/macOS
- Foundation - Standard Swift library (imported in `SyncBuds/Item.swift`)
## Configuration
- Deployment targets: iOS 26.2, macOS 26.2
- Swift compiler version: 5.0
- Build configuration: Debug and Release variants available
- `SyncBuds.xcodeproj/project.pbxproj` - Main project configuration
- Xcode uses file system synchronization for source group organization
- No external package dependencies declared (packageProductDependencies is empty)
## Platform Requirements
- Xcode 26.3 or later
- macOS 13.0+ (minimum for Xcode 26.3)
- Swift 5.0 toolchain
- Deployment target: iOS 26.2 for iPhone/iPad apps
- Deployment target: macOS 26.2 for macOS apps
- Native Apple silicon and Intel x86_64 architecture support
## Build Architecture
- Main app target: `SyncBuds` (produces `SyncBuds.app`)
- Unit test target: `SyncBudsTests` (produces `SyncBudsTests.xctest`)
- UI test target: `SyncBudsUITests` (produces `SyncBudsUITests.xctest`)
- SyncBudsTests depends on SyncBuds target
- SyncBudsUITests depends on SyncBuds target
- No external framework dependencies
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

## Naming Patterns
- Use PascalCase for all Swift filenames: `SyncBudsApp.swift`, `ContentView.swift`, `Item.swift`
- Match filename to primary class/struct name in file
- Use camelCase for function names: `addItem()`, `deleteItems()`, `example()`
- Prefix helper/private functions: `private func addItem()`, `private func deleteItems()`
- Use descriptive action verbs: `add`, `delete`, `perform`
- Test functions use `@Test` macro (Swift Testing) or `testXxx` naming with `func` keyword (XCTest)
- Use camelCase for instance variables: `timestamp`, `modelContext`, `items`
- Use lowercase for loop variables: `index`
- Private properties use `private` keyword: `private var modelContext`
- SwiftUI property wrappers use proper annotations: `@Environment`, `@Query`, `@State`
- Use PascalCase for struct/class/enum names: `SyncBudsApp`, `ContentView`, `Item`
- Use `final class` for classes that won't be subclassed: `final class Item`
- Use `struct` for SwiftUI Views: `struct ContentView: View`
- Use clear, singular names for models: `Item` not `Items`
## Code Style
- Use 4-space indentation (Swift default)
- Follow Apple's Swift API Design Guidelines
- Place opening braces on same line: `struct SyncBudsApp: App {`
- Keep line length reasonable (Xcode default guidelines)
- Use Xcode's built-in Swift linting/warnings
- No additional linting tools detected in project configuration
- Include blank line between property declarations and methods
- Include blank lines between method groups: properties, lifecycle methods, computed properties, actions
- One blank line between related method definitions
## Import Organization
## Error Handling
- Use `fatalError()` for unrecoverable initialization errors: `fatalError("Could not create ModelContainer: \(error)")`
- Use `throws` for operations that can fail: `init(timestamp: Date) throws` (though not yet in use)
- Wrap initialization errors with descriptive messages in `catch` blocks
- Use `do-catch` blocks for error propagation where applicable
## Logging
- No structured logging in current codebase
- Use string interpolation for error messages: `"Could not create ModelContainer: \(error)"`
## Comments
- File headers: Standard Xcode template
- No block comments or extensive inline comments in current codebase
- Code should be self-documenting through clear naming
- Not applicable to Swift (uses different documentation approach)
- Use Swift documentation comments (triple slash `///`) for public APIs when needed (not yet in use)
## Function Design
- Use explicit parameter names: `deleteItems(offsets: IndexSet)`
- Include type annotations: `func deleteItems(offsets: IndexSet)`
- Async operations use `async throws` when applicable
- SwiftUI Views return `some View`: `var body: some View`
- SwiftData models return instances: `Item(timestamp: Date)`
- No explicit return statements in simple cases; implicit returns used
- Use `-> some View` for SwiftUI computed properties
## Module Design
- All public types are defined at module level (no nested visibility in current codebase)
- Use `private` keyword to restrict scope: `private var modelContext`
- SwiftUI preview modifiers: use `#Preview { }` macro pattern
- Not applicable - single-file module pattern used
- Each file is self-contained: `SyncBudsApp.swift`, `ContentView.swift`, `Item.swift`
- Use `var body:` for SwiftUI Views
- Include computed property bodies directly in type definition
## SwiftUI-Specific Conventions
- Primary content in `body` computed property
- Helper functions for complex subviews: `private func addItem()` for button actions
- Use `NavigationSplitView` for multi-column layouts
- Use `List` for scrollable content with ForEach loops
- `@Environment` for accessing shared model context: `@Environment(\.modelContext)`
- `@Query` for fetching SwiftData models: `@Query private var items: [Item]`
- `withAnimation { }` blocks for state changes that trigger animations
- Use property wrappers directly in view struct definition
- Chain modifiers for clarity
- Use tool item placements: `ToolbarItem(placement: .navigationBarTrailing)`
- Apply `.modelContainer()` at App level for SwiftData initialization
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

## Pattern Overview
- SwiftUI declarative UI framework
- SwiftData for data persistence (iOS 17+)
- Single content view with navigation split design
- Environment-injected model context for data operations
- MVVM-inspired architecture with view-driven state management
## Layers
- Purpose: Display data and handle user interactions
- Location: `SyncBuds/ContentView.swift`
- Contains: SwiftUI views, navigation, toolbar actions
- Depends on: SwiftData (model context), Item model
- Used by: App entry point
- Purpose: Define data structures and persistence schema
- Location: `SyncBuds/Item.swift`
- Contains: SwiftData @Model decorated class
- Depends on: SwiftData framework
- Used by: ContentView for data binding, SyncBudsApp for schema configuration
- Purpose: Initialize application and configure data persistence
- Location: `SyncBuds/SyncBudsApp.swift`
- Contains: @main struct, ModelContainer setup, window group configuration
- Depends on: SwiftData, Item model, ContentView
- Used by: iOS runtime
## Data Flow
- SwiftUI @Environment property provides modelContext (injected from .modelContainer modifier)
- @Query property provides reactive list of items (SwiftData query)
- View state is managed through SwiftUI's property system
- No separate view model; logic is minimal and contained in ContentView
## Key Abstractions
- Purpose: Represents a timestamped item in the system
- Examples: `SyncBuds/Item.swift`
- Pattern: SwiftData @Model decorator for automatic persistence mapping
- Purpose: Main UI for displaying and managing items
- Examples: `SyncBuds/ContentView.swift`
- Pattern: Single view handles list display, navigation, and CRUD operations
- Purpose: Application entry point and dependency configuration
- Examples: `SyncBuds/SyncBudsApp.swift`
- Pattern: Singleton ModelContainer created at app startup, shared via environment
## Entry Points
- Location: `SyncBuds/SyncBudsApp.swift`
- Triggers: iOS app launch
- Responsibilities:
- Location: `SyncBuds/ContentView.swift`
- Triggers: App launch and whenever model changes
- Responsibilities:
## Error Handling
- ModelContainer initialization failures cause fatalError (forces immediate crash during development)
- View-level errors: None currently - views assume successful data operations
- Delete operations assume valid indices from ForEach
- No error recovery for persistence failures
- No user-facing error messages for data operations
- No validation of item creation
## Cross-Cutting Concerns
<!-- GSD:architecture-end -->

## Commit Message Format

```
<emoji> <type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Types with Emojis

| Emoji | Type | When to use |
|-------|------|-------------|
| ✨ | **feat** | A new feature |
| 🐛 | **fix** | A bug fix |
| 📝 | **docs** | Documentation only changes |
| 💄 | **style** | Code style/formatting (whitespace, semicolons, etc) |
| ♻️ | **refactor** | Code change that neither fixes a bug nor adds a feature |
| ⚡️ | **perf** | Performance improvements |
| ✅ | **test** | Adding or updating tests |
| 🔧 | **chore** | Changes to build process or auxiliary tools |
| 🏗️ | **build** | Changes that affect the build system or dependencies |
| 🤖 | **ci** | Changes to CI configuration files and scripts |
| ⏪️ | **revert** | Reverts a previous commit |
| 🔒️ | **security** | Security improvements or fixes |

### Important Rules

**NEVER** include these lines in commits:
```
🤖 Generated with [Claude Code](https://claude.com/claude-code)
Co-Authored-By: Claude <noreply@anthropic.com>
```

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd:quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd:debug` for investigation and bug fixing
- `/gsd:execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd:profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
