# Coding Conventions

**Analysis Date:** 2026-03-25

## Naming Patterns

**Files:**
- Use PascalCase for all Swift filenames: `SyncBudsApp.swift`, `ContentView.swift`, `Item.swift`
- Match filename to primary class/struct name in file

**Functions:**
- Use camelCase for function names: `addItem()`, `deleteItems()`, `example()`
- Prefix helper/private functions: `private func addItem()`, `private func deleteItems()`
- Use descriptive action verbs: `add`, `delete`, `perform`
- Test functions use `@Test` macro (Swift Testing) or `testXxx` naming with `func` keyword (XCTest)

**Variables:**
- Use camelCase for instance variables: `timestamp`, `modelContext`, `items`
- Use lowercase for loop variables: `index`
- Private properties use `private` keyword: `private var modelContext`
- SwiftUI property wrappers use proper annotations: `@Environment`, `@Query`, `@State`

**Types:**
- Use PascalCase for struct/class/enum names: `SyncBudsApp`, `ContentView`, `Item`
- Use `final class` for classes that won't be subclassed: `final class Item`
- Use `struct` for SwiftUI Views: `struct ContentView: View`
- Use clear, singular names for models: `Item` not `Items`

## Code Style

**Formatting:**
- Use 4-space indentation (Swift default)
- Follow Apple's Swift API Design Guidelines
- Place opening braces on same line: `struct SyncBudsApp: App {`
- Keep line length reasonable (Xcode default guidelines)

**Linting:**
- Use Xcode's built-in Swift linting/warnings
- No additional linting tools detected in project configuration

**Spacing:**
- Include blank line between property declarations and methods
- Include blank lines between method groups: properties, lifecycle methods, computed properties, actions
- One blank line between related method definitions

## Import Organization

**Order:**
1. Foundation frameworks: `import Foundation`
2. Apple frameworks: `import SwiftUI`, `import SwiftData`
3. Testing frameworks (in test files): `import Testing`, `import XCTest`

**Pattern from codebase:**
```swift
// SyncBudsApp.swift
import SwiftUI
import SwiftData

// ContentView.swift
import SwiftUI
import SwiftData

// Item.swift
import Foundation
import SwiftData
```

## Error Handling

**Patterns:**
- Use `fatalError()` for unrecoverable initialization errors: `fatalError("Could not create ModelContainer: \(error)")`
- Use `throws` for operations that can fail: `init(timestamp: Date) throws` (though not yet in use)
- Wrap initialization errors with descriptive messages in `catch` blocks
- Use `do-catch` blocks for error propagation where applicable

## Logging

**Framework:** No explicit logging framework detected. Console output only through `print()` or Xcode debugger.

**Patterns:**
- No structured logging in current codebase
- Use string interpolation for error messages: `"Could not create ModelContainer: \(error)"`

## Comments

**When to Comment:**
- File headers: Standard Xcode template
  ```swift
  //
  //  FileName.swift
  //  SyncBuds
  //
  //  Created by Author on Date.
  //
  ```
- No block comments or extensive inline comments in current codebase
- Code should be self-documenting through clear naming

**JSDoc/TSDoc:**
- Not applicable to Swift (uses different documentation approach)
- Use Swift documentation comments (triple slash `///`) for public APIs when needed (not yet in use)

## Function Design

**Size:** Small, focused functions - `addItem()` and `deleteItems()` are 3-5 lines each

**Parameters:**
- Use explicit parameter names: `deleteItems(offsets: IndexSet)`
- Include type annotations: `func deleteItems(offsets: IndexSet)`
- Async operations use `async throws` when applicable

**Return Values:**
- SwiftUI Views return `some View`: `var body: some View`
- SwiftData models return instances: `Item(timestamp: Date)`
- No explicit return statements in simple cases; implicit returns used
- Use `-> some View` for SwiftUI computed properties

## Module Design

**Exports:**
- All public types are defined at module level (no nested visibility in current codebase)
- Use `private` keyword to restrict scope: `private var modelContext`
- SwiftUI preview modifiers: use `#Preview { }` macro pattern

**Barrel Files:**
- Not applicable - single-file module pattern used
- Each file is self-contained: `SyncBudsApp.swift`, `ContentView.swift`, `Item.swift`

**Computed Properties:**
- Use `var body:` for SwiftUI Views
- Include computed property bodies directly in type definition

## SwiftUI-Specific Conventions

**View Structure:**
- Primary content in `body` computed property
- Helper functions for complex subviews: `private func addItem()` for button actions
- Use `NavigationSplitView` for multi-column layouts
- Use `List` for scrollable content with ForEach loops

**State Management:**
- `@Environment` for accessing shared model context: `@Environment(\.modelContext)`
- `@Query` for fetching SwiftData models: `@Query private var items: [Item]`
- `withAnimation { }` blocks for state changes that trigger animations
- Use property wrappers directly in view struct definition

**Modifiers:**
- Chain modifiers for clarity
- Use tool item placements: `ToolbarItem(placement: .navigationBarTrailing)`
- Apply `.modelContainer()` at App level for SwiftData initialization

---

*Convention analysis: 2026-03-25*
