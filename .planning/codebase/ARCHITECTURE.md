# Architecture

**Analysis Date:** 2026-03-25

## Pattern Overview

**Overall:** SwiftUI Single-Window MVVM with SwiftData Persistence

**Key Characteristics:**
- SwiftUI declarative UI framework
- SwiftData for data persistence (iOS 17+)
- Single content view with navigation split design
- Environment-injected model context for data operations
- MVVM-inspired architecture with view-driven state management

## Layers

**UI Layer (Presentation):**
- Purpose: Display data and handle user interactions
- Location: `SyncBuds/ContentView.swift`
- Contains: SwiftUI views, navigation, toolbar actions
- Depends on: SwiftData (model context), Item model
- Used by: App entry point

**Model Layer (Data):**
- Purpose: Define data structures and persistence schema
- Location: `SyncBuds/Item.swift`
- Contains: SwiftData @Model decorated class
- Depends on: SwiftData framework
- Used by: ContentView for data binding, SyncBudsApp for schema configuration

**App Layer (Entry Point):**
- Purpose: Initialize application and configure data persistence
- Location: `SyncBuds/SyncBudsApp.swift`
- Contains: @main struct, ModelContainer setup, window group configuration
- Depends on: SwiftData, Item model, ContentView
- Used by: iOS runtime

## Data Flow

**Add Item Flow:**

1. User taps "Add Item" button in toolbar
2. `addItem()` method creates new `Item(timestamp: Date())`
3. Item is inserted into modelContext with animation
4. SwiftData automatically persists to device storage
5. @Query property on ContentView updates and re-renders list

**Delete Item Flow:**

1. User swipes to delete item in list
2. `deleteItems(offsets:)` receives IndexSet of selected items
3. Items are deleted from modelContext with animation
4. SwiftData persists deletion to device storage
5. @Query property updates list view automatically

**State Management:**
- SwiftUI @Environment property provides modelContext (injected from .modelContainer modifier)
- @Query property provides reactive list of items (SwiftData query)
- View state is managed through SwiftUI's property system
- No separate view model; logic is minimal and contained in ContentView

## Key Abstractions

**Item Model:**
- Purpose: Represents a timestamped item in the system
- Examples: `SyncBuds/Item.swift`
- Pattern: SwiftData @Model decorator for automatic persistence mapping

**ContentView:**
- Purpose: Main UI for displaying and managing items
- Examples: `SyncBuds/ContentView.swift`
- Pattern: Single view handles list display, navigation, and CRUD operations

**SyncBudsApp:**
- Purpose: Application entry point and dependency configuration
- Examples: `SyncBuds/SyncBudsApp.swift`
- Pattern: Singleton ModelContainer created at app startup, shared via environment

## Entry Points

**SyncBudsApp (Main Entry Point):**
- Location: `SyncBuds/SyncBudsApp.swift`
- Triggers: iOS app launch
- Responsibilities:
  - Create and configure ModelContainer with Item schema
  - Apply ModelContainer to WindowGroup via .modelContainer modifier
  - Initialize ContentView as root view
  - Handle fatal initialization errors (ModelContainer creation failure)

**ContentView (UI Entry Point):**
- Location: `SyncBuds/ContentView.swift`
- Triggers: App launch and whenever model changes
- Responsibilities:
  - Render NavigationSplitView with master/detail layout
  - Display list of items via @Query
  - Handle add and delete operations
  - Manage toolbar appearance (iOS vs macOS differences)

## Error Handling

**Strategy:** Minimal error handling with fatal failures

**Patterns:**
- ModelContainer initialization failures cause fatalError (forces immediate crash during development)
- View-level errors: None currently - views assume successful data operations
- Delete operations assume valid indices from ForEach

**Current Limitations:**
- No error recovery for persistence failures
- No user-facing error messages for data operations
- No validation of item creation

## Cross-Cutting Concerns

**Logging:** Not implemented - no logging framework in use

**Validation:** Not implemented - Item can be created with any timestamp

**Authentication:** Not applicable - app has no auth system

**Data Persistence:** SwiftData handles automatic serialization/deserialization via @Model decorator and ModelConfiguration

---

*Architecture analysis: 2026-03-25*
