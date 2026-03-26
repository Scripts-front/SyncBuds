# Testing Patterns

**Analysis Date:** 2026-03-25

## Test Framework

**Test Runners:**
- **Unit Tests:** Swift Testing (`@Test` macro) - `SyncBudsTests/SyncBudsTests.swift`
- **UI Tests:** XCTest (traditional) - `SyncBudsUITests/SyncBudsUITests.swift` and `SyncBudsUITestsLaunchTests.swift`

**Assertion Library:**
- Swift Testing: `#expect()` macro for assertions
- XCTest: `XCTAssert()`, `XCTAssertEqual()`, `XCTAssertNil()` family of assertions

**Run Commands:**
```bash
# Run all unit tests (Swift Testing)
xcodebuild test -scheme SyncBuds -testPlan SyncBuds

# Run UI tests
xcodebuild test -scheme SyncBuds -testPlan SyncBuds -destination 'generic/platform=iOS'

# Run from Xcode
⌘U in Xcode to run all tests
```

## Test File Organization

**Location:**
- **Unit Tests:** `SyncBudsTests/` - separate test target
- **UI Tests:** `SyncBudsUITests/` - separate test target
- Tests are co-located by target but separated from source code

**Naming:**
- Unit test file: `SyncBudsTests.swift` (corresponds to main target `SyncBuds`)
- UI test files: `SyncBudsUITests.swift` (functional tests) and `SyncBudsUITestsLaunchTests.swift` (launch tests)
- Test class/struct names follow pattern: `[ComponentName]Tests` or `[ComponentName]UITests`

**Structure:**
```
SyncBuds/                          # Source code
├── SyncBudsApp.swift
├── ContentView.swift
├── Item.swift
└── Assets.xcassets

SyncBudsTests/                     # Unit tests (Swift Testing)
└── SyncBudsTests.swift

SyncBudsUITests/                   # UI/Integration tests (XCTest)
├── SyncBudsUITests.swift
└── SyncBudsUITestsLaunchTests.swift
```

## Test Structure

**Swift Testing Pattern (Unit Tests):**
```swift
// SyncBudsTests.swift
import Testing

struct SyncBudsTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

}
```

**XCTest Pattern (UI Tests):**
```swift
// SyncBudsUITests.swift
import XCTest

final class SyncBudsUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method.
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method.
    }

    @MainActor
    func testExample() throws {
        // Test implementation
    }

}
```

**Patterns:**
- **Setup:** Override `setUpWithError()` for per-test setup initialization
- **Teardown:** Override `tearDownWithError()` for cleanup after each test
- **Async Testing:** Use `async throws` in test function signatures when testing async code
- **Main Thread:** Use `@MainActor` annotation for UI tests that require main thread
- **Test Methods:** Prefix with `test` keyword: `testExample()`, `testLaunchPerformance()`
- **Test Structs (Swift Testing):** Use `struct` not `class`, decorated with `@Test` macro on methods

## Mocking

**Framework:** None detected in current codebase

**Patterns:**
- SwiftData uses in-memory container for preview/test isolation: `ContentView().modelContainer(for: Item.self, inMemory: true)`
- No mock objects implemented yet in test files
- UI tests use `XCUIApplication()` directly for app interaction testing

**What to Mock (Recommendations):**
- External API calls when available
- File system operations
- Network requests
- SwiftData queries (use in-memory containers instead)

**What NOT to Mock:**
- SwiftUI Views (test via UI tests or SwiftUI Preview)
- Core data models with simple logic
- Foundation types

## Fixtures and Factories

**Test Data:**
No fixtures or factories currently implemented. Basic pattern observed:
```swift
// From ContentView Preview
#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
```

**Location:**
- Currently embedded in test class methods
- Previews live in source files with `#Preview` macro

## Coverage

**Requirements:** Not enforced - no coverage configuration detected

**View Coverage:**
```bash
# In Xcode: Product > Scheme > Edit Scheme > Test > Code Coverage (enable)
# View results in Xcode: Product > Scheme > Edit Scheme > Test tab
```

## Test Types

**Unit Tests:**
- **Framework:** Swift Testing
- **File:** `SyncBudsTests/SyncBudsTests.swift`
- **Scope:** Logic testing with `@Test` macro
- **Approach:** Async-first (`async throws`), use `#expect()` for assertions
- **Example:** Placeholder test method `example()` - awaiting implementation

**UI Tests:**
- **Framework:** XCTest
- **Files:** `SyncBudsUITests/SyncBudsUITests.swift`, `SyncBudsUITestsLaunchTests.swift`
- **Scope:** User interaction simulation via `XCUIApplication()`
- **Approach:** Launch app, simulate user interactions, verify UI state
- **Special Case - Launch Tests:**
  - `SyncBudsUITestsLaunchTests.swift` tests app launch behavior
  - Uses `runsForEachTargetApplicationUIConfiguration = true` to test multiple configurations
  - Captures launch screenshot with `XCTAttachment(screenshot:)`

**Integration Tests:**
- Not explicitly separated - UI tests serve as integration tests
- Test full app flow from launch to user interaction

## Common Patterns

**Async Testing:**
```swift
@Test func example() async throws {
    // async/await support
    // Use await for async operations
    // Use try for throwing operations
}
```

**Error Testing:**
Current pattern uses `throws` keyword in test method signature:
```swift
@Test func example() async throws {
    // Errors can propagate and fail test
    // No explicit try/catch needed - test fails on throw
}
```

**App Lifecycle in UI Tests:**
```swift
override func setUpWithError() throws {
    continueAfterFailure = false
    // Initialize app state before each test
}

@MainActor
func testExample() throws {
    let app = XCUIApplication()
    app.launch()
    // Interact with app
}
```

**Performance Testing:**
```swift
func testLaunchPerformance() throws {
    measure(metrics: [XCTApplicationLaunchMetric()]) {
        XCUIApplication().launch()
    }
}
```

## Test Organization Best Practices (Observed)

1. **Separate test targets** for unit tests vs UI tests - allows different frameworks and scopes
2. **Use @MainActor** on UI test methods to ensure main thread execution
3. **Set continueAfterFailure = false** in UI tests for fast failure feedback
4. **Use in-memory SwiftData containers** for isolated testing
5. **Capture screenshots** for launch/UI verification tests
6. **Async/await first** in Swift Testing for modern async operations
7. **File naming matches purpose**: `SyncBudsTests` for unit, `SyncBudsUITests` for UI

---

*Testing analysis: 2026-03-25*
