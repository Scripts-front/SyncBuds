# External Integrations

**Analysis Date:** 2026-03-25

## APIs & External Services

**Third-party APIs:**
- Not detected - No external API integrations configured

**Custom Web Services:**
- Not detected - No network calls or API client libraries imported

**Social Integration:**
- Not detected - No social authentication or sharing services

## Data Storage

**Databases:**
- SwiftData (local)
  - Connection: In-app via ModelContainer
  - Persistence: Local SQLite database (default SwiftData backend)
  - Client: SwiftData framework
  - Configuration: `SyncBuds/SyncBudsApp.swift` lines 13-24
  - Models: `SyncBuds/Item.swift`

**File Storage:**
- Local filesystem only - No cloud storage integration

**Caching:**
- SwiftData managed caching - Built-in to SwiftData persistence layer
- No external caching service detected

## Authentication & Identity

**Auth Provider:**
- Not applicable - No user authentication implemented

**Current Implementation:**
- No authentication layer present
- App operates without user login or identity management

## Monitoring & Observability

**Error Tracking:**
- Not detected - No error tracking service (Sentry, Firebase Crashlytics, etc.)

**Logs:**
- Standard output only - Uses console/Xcode debugging
- No structured logging framework detected

**Analytics:**
- Not detected - No analytics service integrated

## CI/CD & Deployment

**Hosting:**
- Apple App Store - Expected deployment target (native iOS app)
- Mac App Store - Expected deployment target (native macOS app)

**CI Pipeline:**
- Not detected - No CI/CD configuration files present
- Manual Xcode build and deployment only

**Build Automation:**
- Xcode build schemes only - No external build system configured

## Environment Configuration

**Required env vars:**
- Not applicable - No environment variables referenced in code
- Build configuration managed entirely through Xcode project settings

**Secrets location:**
- Not applicable - No secrets management implemented
- No API keys or credentials stored

## Webhooks & Callbacks

**Incoming:**
- Not detected - No webhook endpoints implemented

**Outgoing:**
- Not detected - No outbound webhook callbacks configured

## Network Configuration

**Network Requests:**
- Not detected - No URLSession or network request code
- No external API communication present

**Permissions:**
- No explicit network permissions required
- Typical iOS/macOS app permissions (none special required for current functionality)

---

*Integration audit: 2026-03-25*
