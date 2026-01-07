# Automation Architecture (v1.4)

## Overview

The Automation system enables background file monitoring, scheduled scans, and automatic file organization. This document explains the architecture, key components, and design decisions.

## Problem Statement

Users want Forma to automatically organize files without manual intervention. This requires:

- **Background Monitoring**: Detect new files and organize them automatically
- **Scheduling**: Run scans at appropriate intervals based on system state
- **Policy-Driven Decisions**: Determine when auto-organize is safe vs when to wait for user review
- **Observability**: Show users what automation is doing and let them control it

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         App Lifecycle                                │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │            AutomationLifecycleModifier                        │   │
│  │  (Starts/stops engine based on ScenePhase)                    │   │
│  └──────────────────────────┬───────────────────────────────────┘   │
└─────────────────────────────┼───────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                      AutomationEngine                                │
│  ┌─────────────────┐  ┌─────────────────┐  ┌────────────────────┐   │
│  │ AutomationState │  │ Timer/Scheduler │  │ Scan Coordinator   │   │
│  │ (@Observable)   │  │ (Adaptive)      │  │ (FileScanProvider) │   │
│  └────────┬────────┘  └────────┬────────┘  └─────────┬──────────┘   │
│           │                    │                      │              │
│           └────────────────────┴──────────────────────┘              │
└─────────────────────────────────┬───────────────────────────────────┘
                                  │
              ┌───────────────────┼───────────────────┐
              │                   │                   │
              ▼                   ▼                   ▼
┌─────────────────────┐  ┌───────────────┐  ┌────────────────────────┐
│  AutomationPolicy   │  │ FeatureFlags  │  │ ActivityLoggingService │
│  (Decision Logic)   │  │ (Gates)       │  │ (Audit Trail)          │
└─────────────────────┘  └───────────────┘  └────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    FormaConfig.Automation                            │
│  (Thresholds, Intervals, Cooldowns)                                  │
└─────────────────────────────────────────────────────────────────────┘
```

## Key Components

### 1. AutomationEngine (`Services/AutomationEngine.swift`)

Singleton `@MainActor` class coordinating all automation activities.

```swift
@MainActor
final class AutomationEngine: ObservableObject {
    static let shared = AutomationEngine()

    @Published private(set) var state: AutomationState

    func start()   // Begin scheduled scans
    func stop()    // Pause automation
    func runScan() // Trigger immediate scan
}
```

**Responsibilities:**
- Manage scan timer with adaptive intervals
- Coordinate with `FileScanProvider` for actual scanning
- Update `AutomationState` for UI binding
- Respect feature flags before operations

### 2. AutomationState (`Services/AutomationEngine.swift`)

Observable state for UI binding.

```swift
@Observable
final class AutomationState {
    var isRunning: Bool = false
    var lastRunDate: Date?
    var nextScheduledRun: Date?
    var statusMessage: String = "Idle"

    // Last run statistics
    var lastRunSuccessCount: Int = 0
    var lastRunFailedCount: Int = 0
    var lastRunSkippedCount: Int = 0
}
```

### 3. AutomationPolicy (`Services/AutomationPolicy.swift`)

Pure struct containing decision logic (no side effects, easily testable).

```swift
struct AutomationPolicy {
    /// Determines if a file should be auto-organized
    func shouldAutoOrganize(
        file: FileItem,
        mlConfidence: Double?,
        fileAgeDays: Int
    ) -> Bool

    /// Calculates next scan interval based on backlog
    func calculateScanInterval(metrics: AutomationMetrics) -> TimeInterval

    /// Determines if backlog reminder should be sent
    func shouldSendBacklogReminder(
        metrics: AutomationMetrics,
        lastReminderDate: Date?
    ) -> Bool
}
```

**Decision Factors:**
- ML prediction confidence (≥0.85 for auto-organize)
- File age (>7 days = stale, prioritize)
- Backlog size (>50 files = increase scan frequency)
- Cooldown timers (rate-limit notifications)

### 4. AutomationLifecycleModifier (`Views/AutomationLifecycleModifier.swift`)

SwiftUI view modifier managing engine lifecycle.

```swift
struct AutomationLifecycleModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content.onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                AutomationEngine.shared.start()
            case .background, .inactive:
                AutomationEngine.shared.stop()
            }
        }
    }
}
```

### 5. AutomationStatusWidget (`Components/AutomationStatusWidget.swift`)

Dashboard UI component displaying automation status.

**Features:**
- Status indicator dot (blue=running, green=scheduled, orange=paused)
- Pause/resume toggle button
- Expandable last-run statistics
- Feature-flag gated display

## Data Flow

### Scan Cycle

```
1. Timer fires (based on adaptive interval)
         │
         ▼
2. Check feature flags (.backgroundMonitoring, .autoOrganize)
         │
         ▼
3. Run scan via FileScanProvider
         │
         ▼
3a. If scan completes with partial failures, surface `errorSummary` via notification and activity log
         │
         ▼
4. For each file: AutomationPolicy.shouldAutoOrganize()
         │
         ├─ Yes → Queue for auto-organize
         │
         └─ No → Leave for user review
         │
         ▼
5. Execute moves (if auto-organize enabled)
         │
         ▼
6. Log results via ActivityLoggingService
         │
         ▼
7. Update AutomationState with statistics
         │
         ▼
8. Calculate next interval, schedule timer
```

### State Updates

```swift
// Engine updates state
state.isRunning = true
state.statusMessage = "Scanning..."

// Widget observes via @ObservedObject
@ObservedObject private var engine = AutomationEngine.shared

// UI automatically updates
Text(engine.state.statusMessage)
```

## Configuration

All automation thresholds are centralized in `FormaConfig.Automation`:

| Constant | Default | Description |
|----------|---------|-------------|
| `backlogThreshold` | 50 | Files pending before increasing scan frequency |
| `ageThresholdDays` | 7 | Days before file is considered "stale" |
| `minScanIntervalMinutes` | 5 | Minimum time between scans |
| `maxScanIntervalMinutes` | 60 | Maximum time between scans |
| `mlRuleConfidenceMinimum` | 0.75 | Min confidence for rule suggestion |
| `mlAutoOrganizeConfidenceMinimum` | 0.85 | Min confidence for auto-organize |
| `backlogReminderCooldownHours` | 24 | Hours between backlog reminders |
| `errorNotificationCooldownMinutes` | 30 | Minutes between error notifications |
| `maxNotificationsPerHour` | 5 | Rate limit for user notifications |

## Feature Flags

Automation features are gated for staged rollout:

```swift
enum FeatureFlag {
    case backgroundMonitoring  // Master toggle for automation
    case autoOrganize          // Enable auto-move (vs suggest-only)
    case automationReminders   // Send backlog/stale file reminders
}
```

**Usage:**
```swift
if FeatureFlagService.shared.isEnabled(.autoOrganize) {
    // Perform auto-organize
} else {
    // Just suggest, require user confirmation
}
```

## Activity Logging

All automation activities are logged for audit/debugging:

| Activity Type | Logged When |
|---------------|-------------|
| `.automationScanCompleted` | Scan finishes with file counts |
| `.automationAutoOrganized` | Batch auto-organize completes |
| `.automationError` | Scan or move fails |
| `.automationPaused` | User or system pauses automation |
| `.automationResumed` | Automation resumes |

## Undo Support

Auto-organized files can be undone via:

- **BulkMoveCommand**: Groups multiple auto-moved files into single undo entry
- **MoveFileCommand**: Individual file moves preserve original status

```swift
// Batch auto-organize creates ONE undo entry
let command = BulkMoveCommand(
    id: UUID(),
    timestamp: Date(),
    operations: movedFiles.map { /* preserve original state */ }
)
coordinator.pushUndo(command)
```

## Testing

### Unit Tests

`AutomationPolicy` is pure and easily unit-tested:

```swift
@Test
func policy_shouldAutoOrganize_highConfidence() {
    let policy = AutomationPolicy()
    let result = policy.shouldAutoOrganize(
        file: mockFile,
        mlConfidence: 0.92,
        fileAgeDays: 3
    )
    #expect(result == true)
}
```

### Integration Tests

`AutomationIntegrationTests.swift` covers:

- Activity logging for all event types
- Undo entry creation and state preservation
- AutomationMetrics conversion
- Feature flag validation
- Config threshold verification

## Design Decisions

### Why Singleton Engine?

The `AutomationEngine` is a singleton because:
1. Only one timer should run at a time
2. State must be consistent across all UI surfaces
3. Lifecycle management is simpler with single instance

### Why Pure Policy Struct?

`AutomationPolicy` is stateless for:
1. Easy unit testing without mocks
2. Deterministic behavior
3. Thread safety (no shared mutable state)

### Why Feature Flags?

Staged rollout allows:
1. Testing in production with subset of users
2. Quick disable if issues arise
3. A/B testing different thresholds

---

**Created:** December 6, 2025
**Last Updated:** December 6, 2025
