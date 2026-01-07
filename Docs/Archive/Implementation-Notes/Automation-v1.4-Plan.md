# v1.4 Automation Plan (Q3 2025 Target)

## Goals & Guardrails

- **Background monitoring while the app is running:** Keep Desktop/Downloads (and opted-in folders) "fresh" via periodic scans plus lightweight triggers, not one-off manual scans.
- **Safe auto-organize:** Only move files when rules/destinations are clearly valid, with strong undo and a clear audit trail.
- **Scheduling & thresholds:** User-controllable cadence (time-based) plus smart triggers (backlog/age/size).
- **Notifications:** Clear, non-noisy summaries for auto-organization, reminders when backlog builds up, rule match highlights, and surfaced errors.
- **Feature flags + settings:** Everything opt-out-able via `FeatureFlagService` and Settings, default ON but easy to control.

---

## 1. Automation Core & Scheduling

### 1.1 AutomationEngine Architecture

Introduce an `AutomationEngine` service (non-UI, `@Observable`) that owns all background automation decisions and scheduling. It orchestrates:
- `FileScanPipeline.scanAndPersist` for file discovery
- `FileOrganizationCoordinator.organizeMultipleFiles` for safe moves
- `NotificationService` for user communication
- `ActivityLoggingService` for audit trail

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────────┐
│ AutomationPolicy│────▶│ AutomationEngine │────▶│ FileOrganization    │
│   (decisions)   │     │  (orchestrator)  │     │    Coordinator      │
└─────────────────┘     └──────────────────┘     └─────────────────────┘
                               │
                               ▼
                     ┌──────────────────┐
                     │NotificationService│
                     └──────────────────┘
```

### 1.2 AutomationPolicy Type

Create `AutomationPolicy` as the single source of truth for automation decisions:

```swift
struct AutomationPolicy: Equatable, Sendable {
    // Core settings
    let userMode: AutomationMode           // User's preference
    let effectiveMode: AutomationMode      // After applying feature flags
    let scanIntervalMinutes: Int
    let scanOnLaunch: Bool

    // Thresholds
    let backlogThreshold: Int              // Files count for early action
    let ageThresholdDays: Int              // Stale file reminder trigger
    let mlConfidenceThreshold: Double      // 0.90 for auto-moves
    let maxConsecutiveFailures: Int        // Before backoff

    // Notification settings
    let notificationsEnabled: Bool
    let backlogReminderCooldownHours: Int
    let errorNotificationCooldownMinutes: Int

    // Resolution
    static func resolve(flags: FeatureFlagService, userSettings: AutomationUserSettings) -> AutomationPolicy
}
```

### 1.3 Migration from DashboardViewModel

- Remove `DashboardViewModel.autoScanTask` and `scanInterval` properties
- `DashboardViewModel` becomes a consumer of `AutomationEngine.state`
- Wire existing `@AppStorage("autoScanOnLaunch")` and `@AppStorage("scanInterval")` from `GeneralSettingsView` to new `AutomationUserSettings` keys:
  - `automation.mode`
  - `automation.scanInterval`
  - `automation.scanOnLaunch`
  - `automation.notifications`

### 1.4 FormaConfig.Automation Constants

Extend `FormaConfig` with automation-specific values:

```swift
enum Automation {
    static let minScanIntervalMinutes = 5
    static let maxScanIntervalMinutes = 1440        // 24 hours
    static let defaultScanIntervalMinutes = 30
    static let scanDebounceDurationSeconds: TimeInterval = 60

    static let backlogThreshold = 50
    static let ageThresholdDays = 7

    static let mlRuleConfidenceMinimum: Double = 0.75
    static let mlAutoOrganizeConfidenceMinimum: Double = 0.90

    static let maxConsecutiveFailures = 3
    static let failureBackoffMultiplier: Double = 2.0
    static let maxBackoffIntervalMinutes = 120

    static let backlogReminderCooldownHours = 24
    static let errorNotificationCooldownMinutes = 60
    static let maxNotificationsPerHour = 5
}
```

---

## 2. App Lifecycle & State Management

### 2.1 Lifecycle States

Automation behavior varies based on app state:

| App State              | Scan Behavior                | Interval Multiplier |
|------------------------|------------------------------|---------------------|
| Active + window open   | Full automation              | 1.0x                |
| Active + window closed | Reduced cadence              | 2.0x                |
| Backgrounded           | Paused                       | N/A                 |
| Menu bar only          | On-demand only               | N/A                 |

```swift
enum AppLifecycleState: Equatable, Sendable {
    case activeWithWindow
    case activeWindowClosed
    case backgrounded
    case menuBarOnly

    var allowsScheduledScans: Bool { ... }
    var scanIntervalMultiplier: Double { ... }
}
```

### 2.2 Lifecycle Integration

`AutomationEngine` observes lifecycle changes:
- On `activeWithWindow`: Start/resume scheduled scans
- On `activeWindowClosed`: Continue with reduced frequency
- On `backgrounded`: Pause all scheduled scans
- On app termination: Cancel pending tasks cleanly

Wire to `NSApplication` notifications:
- `.didBecomeActiveNotification`
- `.didResignActiveNotification`
- `.willTerminateNotification`

---

## 3. Background Monitoring & Auto-Organize Behavior

### 3.1 Automation Modes

Three user-facing modes in Settings:

```swift
enum AutomationMode: String, CaseIterable {
    case off              // No auto scans or moves
    case scanOnly         // Scans update statuses, no moves
    case scanAndOrganize  // Full automation for eligible files
}
```

### 3.2 Auto-Organize Eligibility

Files qualify for auto-organization when ALL conditions are met:
1. `status == .pending` or `.ready`
2. `destination != nil`
3. `destination.resolve().validate() == .ok`
4. If ML-predicted destination: confidence ≥ `mlAutoOrganizeConfidenceMinimum` (0.90)
5. If rule-matched: confidence ≥ `mlRuleConfidenceMinimum` (0.75)
6. Source folder is not opted-out via `CustomFolder.excludeFromAutomation`

### 3.3 Safe Move Pipeline

All auto moves flow through existing security infrastructure:
1. `FileOperationsService.moveFile` for TOCTOU-safe moves
2. Security-scoped bookmark resolution via `SecureBookmarkStore`
3. `SwiftDataTransaction` for atomic state updates with rollback
4. `ActivityLoggingService.logBulkOrganized` for audit trail

### 3.4 Undo Support

Each auto-organize batch creates a single `BulkMoveCommand` via `FileOrganizationCoordinator`:
- Visible in Dashboard as "Auto-organized X files – Undo"
- Uses existing undo stack (max 20 actions via `FormaConfig.Limits`)

---

## 4. Scheduling, Time-Based, and Threshold Triggers

### 4.1 Time-Based Triggers

Managed by `AutomationEngine`:
- **On launch**: If `scanOnLaunch` enabled, immediate scan
- **Interval scans**: Every `scanIntervalMinutes` while app active
- **Debouncing**: Minimum 60 seconds between any two scans

### 4.2 Threshold Triggers

- **Backlog count**: If `pendingCount ≥ backlogThreshold` (50), trigger early action:
  - In `scanOnly` mode: Send reminder notification
  - In `scanAndOrganize` mode: Trigger immediate auto-organize pass

- **File age**: If oldest pending file age ≥ `ageThresholdDays` (7), send reminder even if auto-organize is OFF

- **Failure backoff**: If consecutive scan failures ≥ `maxConsecutiveFailures` (3):
  - Apply exponential backoff: `baseInterval × 2^(failures - maxConsecutiveFailures)`
  - Cap at `maxBackoffIntervalMinutes` (120 min)
  - Send error notification with call-to-action

### 4.3 Error Recovery Strategy

For bookmark/permission failures:

| Failure Type          | Recovery Action                                    |
|-----------------------|----------------------------------------------------|
| Stale bookmark        | Attempt refresh; if fails, notify user             |
| Permission denied     | Notify with "Review access in Settings" CTA        |
| Destination missing   | Skip file, mark as needs-review, continue batch    |
| Repeated failures     | Exponential backoff + consolidated error notif     |

---

## 5. Notifications for Automation

### 5.1 Notification Types

Extend `NotificationService` with automation-specific methods:

```swift
extension NotificationService {
    func notifyAutoOrganizeSummary(successCount: Int, failedCount: Int, skippedCount: Int)
    func notifyBacklogReminder(pendingCount: Int, oldestAgeDays: Int?)
    func notifyRuleHighlights(ruleName: String, matchCount: Int)
    func notifyAutomationError(type: AutomationErrorType, message: String)
}

enum AutomationErrorType {
    case scanFailed
    case bookmarkInvalid
    case destinationInaccessible
    case permissionDenied
}
```

### 5.2 Rate Limiting & Persistence

Rate limits prevent notification spam:

| Notification Type  | Cooldown                | Persistence          |
|--------------------|-------------------------|----------------------|
| Backlog reminder   | 24 hours                | `UserDefaults`       |
| Error cluster      | 60 minutes              | In-memory            |
| Auto-organize      | 5 per hour max          | In-memory counter    |
| Rule highlights    | Once per rule per day   | `UserDefaults`       |

Persistence keys:
- `automation.lastBacklogReminderDate`
- `automation.lastErrorNotificationDate`
- `automation.ruleHighlightDates` (Dictionary<UUID, Date>)

### 5.3 Notification Clearing

Use `removeNotification(withIdentifier:)` to dismiss resolved issues:
- When backlog drops below threshold, clear backlog reminders
- When bookmark is refreshed, clear access error notifications

---

## 6. Feature Flags & Settings UX

### 6.1 New Feature Flags

Add to `FeatureFlagService.Feature`:

```swift
case backgroundMonitoring    // Controls AutomationEngine scheduling
case autoOrganize           // Controls automatic moves (requires backgroundMonitoring)
case automationReminders    // Controls reminder notifications

// Dependencies
var dependencies: [Feature] {
    switch self {
    case .autoOrganize: return [.backgroundMonitoring]
    case .automationReminders: return [.backgroundMonitoring]
    // ...
    }
}

// Defaults
var defaultValue: Bool {
    switch self {
    case .backgroundMonitoring: return true
    case .autoOrganize: return false   // Opt-in for v1.4 launch
    case .automationReminders: return true
    // ...
    }
}
```

### 6.2 Hierarchical Semantics

Flag precedence:
1. If `masterAIEnabled == false`: All automation OFF
2. If `.backgroundMonitoring == false`: All automation OFF
3. If `.autoOrganize == false`: Scan-only mode max
4. User's `AutomationMode` selection applies within allowed bounds

### 6.3 Settings UI

Add "Automation" section to `SettingsView` → `SmartFeaturesView`:

```
┌─────────────────────────────────────────────────────────┐
│ Automation                                              │
├─────────────────────────────────────────────────────────┤
│ ○ Off                                                   │
│   No automatic scans or organization                    │
│                                                         │
│ ● Scan Only                          [Recommended]      │
│   Periodically scan and suggest, but don't move files   │
│                                                         │
│ ○ Scan & Auto-Organize                                  │
│   Automatically organize high-confidence matches        │
├─────────────────────────────────────────────────────────┤
│ Scan interval          [Every 30 minutes ▼]             │
│ Scan on launch         [✓]                              │
│ Smart reminders        [✓]                              │
└─────────────────────────────────────────────────────────┘
```

---

## 7. Data, Undo, and Observability

### 7.1 AutomationState for UI Binding

```swift
@Observable
final class AutomationState {
    var isRunning: Bool = false
    var lastRunDate: Date?
    var lastRunSuccessCount: Int = 0
    var lastRunFailedCount: Int = 0
    var nextScheduledRun: Date?
    var consecutiveFailures: Int = 0
    var currentBackoffMinutes: Int = 0

    var statusMessage: String { ... }  // "Next scan in 5m" etc.
}
```

### 7.2 Activity Logging

Log automation events via `ActivityLoggingService`:
- `logAutomationScanCompleted(filesScanned:newPending:)`
- `logAutoOrganizeBatch(successCount:failedCount:)`
- `logAutomationError(type:message:)`

### 7.3 Analytics Integration

Track in existing `AnalyticsService`:
- `automation.scansPerDay`
- `automation.filesAutoOrganized`
- `automation.manualVsAutoRatio`

Display on Dashboard:
- "X files auto-organized this week"
- Trend sparkline for automation activity

### 7.4 Debug Logging

In debug builds, log automation decisions:
```
[Automation] Scan triggered (reason: scheduled)
[Automation] Found 5 eligible files for auto-organize
[Automation] Skipped file X (confidence 0.72 < 0.90 threshold)
[Automation] Auto-organized 4 files, 0 failed
[Automation] Next scan scheduled for 2025-07-15 14:30:00
```

---

## 8. Implementation Phases

### Phase 1 – Foundation (Design & Spikes)

**Deliverables:**
- [ ] `AutomationPolicy.swift` with mode enum and resolution logic
- [ ] `AutomationUserSettings` with UserDefaults backing
- [ ] `FormaConfig.Automation` constants
- [ ] Updated `FeatureFlagService` with new flags
- [ ] Spike: Lifecycle observation via NSApplication notifications
- [ ] Design review of Settings UI mockups

**Exit Criteria:**
- Policy resolution works in unit tests
- Feature flags hierarchy is verified
- Settings UI design approved

---

### Phase 2 – Core Implementation

#### 2.1 AutomationEngine Foundation
- [ ] Create `AutomationEngine` singleton with `configure()` entry point
- [ ] Implement `FileScanProvider` protocol abstraction
- [ ] Wire `AutomationState` observable for UI binding
- [ ] Add `Log.Category.automation` for dedicated logging

#### 2.2 Scheduling & Lifecycle
- [ ] Implement `scheduleNextScan()` with interval + backoff calculation
- [ ] Add `AppLifecycleState` enum and observation
- [ ] Wire `NSApplication` notifications for lifecycle changes
- [ ] Implement scan debouncing (60-second minimum gap)

#### 2.3 Scan Integration
- [ ] Create `DashboardFileScanProvider` implementing `FileScanProvider`
- [ ] Migrate `DashboardViewModel.scanFiles()` call to use engine
- [ ] Remove `DashboardViewModel.autoScanTask` and `scanInterval`
- [ ] Add scan-on-launch trigger in app initialization

#### 2.4 Auto-Organize Pipeline
- [ ] Implement `getAutoOrganizeEligibleFiles()` with eligibility checks
- [ ] Wire to `FileOrganizationCoordinator.organizeMultipleFiles()`
- [ ] Verify undo entries created for auto-batches
- [ ] Add ML confidence gating via `DestinationPredictionService`

#### 2.5 Threshold Triggers
- [ ] Implement `checkThresholds()` with backlog and age checks
- [ ] Add threshold-triggered early scan logic
- [ ] Implement exponential backoff on failures

#### 2.6 Notifications
- [ ] Add `notifyAutoOrganizeSummary()` to `NotificationService`
- [ ] Add `notifyBacklogReminder()` with cooldown tracking
- [ ] Add `notifyAutomationError()` with rate limiting
- [ ] Implement notification clearing on issue resolution

#### 2.7 Settings UI
- [ ] Create `AutomationSettingsView` component
- [ ] Wire `@AppStorage` bindings to new keys
- [ ] Add mode picker with descriptions
- [ ] Integrate into `SmartFeaturesView`

#### 2.8 Testing
- [ ] Unit tests for `AutomationPolicy.resolve()` combinations
- [ ] Unit tests for backoff calculation
- [ ] Unit tests for notification rate limiting
- [ ] Integration test for full scan → auto-organize → undo flow
- [ ] Create `MockFileScanProvider` for isolated engine testing

**Exit Criteria:**
- Engine runs scheduled scans in dev builds
- Auto-organize respects confidence thresholds
- Undo works for auto-organized batches
- Notifications respect rate limits

---

### Phase 3 – Hardening & UX Polish

**Deliverables:**
- [ ] Tune thresholds using internal dogfooding data
- [ ] Refine notification copy and frequency
- [ ] Add "Auto-organized X files – Undo" toast on Dashboard
- [ ] Add automation status indicator to sidebar/toolbar
- [ ] Performance profiling of scheduled scans
- [ ] Update CHANGELOG and user documentation

**Exit Criteria:**
- No notification spam in 48-hour dogfood test
- Scan performance < 2 seconds for typical folders
- User docs cover all automation settings

---

### Phase 4 – Beta & Release

**Deliverables:**
- [ ] Ship beta with `autoOrganize` flag OFF by default
- [ ] Gather telemetry on scan frequency and auto-organize usage
- [ ] Adjust defaults based on feedback
- [ ] Enable `autoOrganize` default ON for new installs at GA

**Exit Criteria:**
- Beta feedback incorporated
- No P0/P1 bugs in automation paths
- Telemetry shows healthy adoption without issues

---

## 9. Files to Create/Modify

### New Files
- `Configuration/AutomationPolicy.swift`
- `Services/AutomationEngine.swift`
- `Views/Settings/AutomationSettingsView.swift`

### Modified Files
- `Configuration/FormaConfig.swift` – Add `Automation` enum
- `Services/FeatureFlagService.swift` – Add 3 new flags
- `Services/NotificationService.swift` – Add automation methods
- `Services/ActivityLoggingService.swift` – Add automation events
- `ViewModels/DashboardViewModel.swift` – Remove autoScan, add engine binding
- `Views/Settings/SmartFeaturesView.swift` – Add Automation section
- `Forma_File_OrganizingApp.swift` – Initialize and start engine

---

## 10. Risk Mitigations

| Risk | Mitigation |
|------|------------|
| Aggressive scanning drains battery | Min 5-min interval, pause when backgrounded |
| Users surprised by auto-moves | Default to scan-only; require opt-in for auto-organize |
| Notification spam | Rate limits + cooldowns + hourly cap |
| Undo stack overflow | Existing 20-action cap applies |
| Bookmark failures block automation | Graceful degradation with user notification |
| Race conditions in bulk moves | Existing `FileOperationCoordinator` guards |
