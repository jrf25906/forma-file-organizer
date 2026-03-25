# Automation Architecture (v1.5)

## Overview

Forma automation now combines realtime filesystem watching with scheduled recovery sweeps. `AutomationEngine` owns both paths: it starts an `FSEvents` stream for enabled bookmark-backed standard folders while the app is active, converts bursty path changes into debounced root-level rescans, and keeps interval-based full scans as a fallback.

## Problem Statement

Users want Forma to react quickly when files appear, move, or disappear without sacrificing correctness. This requires:

- **Realtime Watching**: detect nested file changes under watched roots without polling the whole filesystem
- **Targeted Rescans**: rescan only the affected roots to keep automation lightweight
- **Scheduled Recovery Sweeps**: periodically run a full automation scan in case watcher events are missed
- **Policy-Driven Decisions**: determine when scan-only versus scan-and-organize behavior is allowed
- **Partial Refresh Correctness**: update dashboard and menu bar after root-scoped persistence without dropping unaffected state

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         App Lifecycle                              │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │          AutomationLifecycleModifier / WindowLifecycle       │  │
│  │  (activeWithWindow / menuBarOnly start, background stops)   │  │
│  └──────────────────────────┬───────────────────────────────────┘  │
└─────────────────────────────┼──────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         AutomationEngine                           │
│  ┌─────────────────┐ ┌──────────────────┐ ┌─────────────────────┐  │
│  │ AutomationState │ │ Scheduler/Backoff│ │ Realtime Watch Queue│  │
│  │ (@Observable)   │ │ (full sweeps)    │ │ (debounced roots)   │  │
│  └────────┬────────┘ └────────┬─────────┘ └──────────┬──────────┘  │
│           │                   │                       │             │
│           └───────────────────┴──────────────┬────────┘             │
└──────────────────────────────────────────────┼──────────────────────┘
                                               │
                     ┌─────────────────────────┼────────────────────────┐
                     │                         │                        │
                     ▼                         ▼                        ▼
         ┌─────────────────────┐  ┌──────────────────────┐  ┌──────────────────────┐
         │  AutomationPolicy   │  │  FileMonitorService  │  │ DashboardFileScan... │
         │  (decisions/gates)  │  │  (FSEvents + scopes) │  │ + FileScanPipeline   │
         └─────────────────────┘  └──────────────────────┘  └──────────────────────┘
                     │                         │                        │
                     ▼                         ▼                        ▼
         ┌─────────────────────┐  ┌──────────────────────┐  ┌──────────────────────┐
         │   Feature Flags     │  │ BookmarkFolderService│  │ Activity / UI Refresh │
         │  (rollout gates)    │  │  (enabled roots)     │  │ notifications/state   │
         └─────────────────────┘  └──────────────────────┘  └──────────────────────┘
```

## Key Components

### 1. AutomationEngine (`Services/AutomationEngine.swift`)

Singleton `@MainActor` coordinator for automation lifecycle, scheduling, watcher state, and scan orchestration.

```swift
@MainActor
final class AutomationEngine: ObservableObject {
    static let shared = AutomationEngine()

    @Published private(set) var state: AutomationState

    func start()
    func stop()
    func triggerManualScan() async
    func refreshPolicy()
}
```

**Responsibilities:**
- Start and stop realtime monitoring based on lifecycle and policy
- Schedule interval-based full sweeps
- Route watcher callbacks into root-targeted `FileScanProvider` scans
- Prevent concurrent scans by queuing one follow-up realtime root set
- Trigger auto-organize after both scheduled and watcher-driven scans when policy allows it

### 2. FileMonitorService (`Services/FileMonitorService.swift`)

`FSEvents`-backed implementation of `FileMonitoring`.

```swift
@MainActor
protocol FileMonitoring: AnyObject {
    func startMonitoring(
        folders: [WatchedFolderDescriptor],
        onChange: @escaping @MainActor (Set<FolderLocation>) -> Void
    )

    func updateMonitoredFolders(_ folders: [WatchedFolderDescriptor])
    func stopMonitoring()
}
```

**Responsibilities:**
- Watch only currently enabled bookmark-backed standard folders
- Hold security-scoped access for watched roots while the stream is active
- Map changed file paths back to the owning `FolderLocation`
- Debounce bursts of file events into one set of changed roots
- Rebuild the stream when watched roots change

### 3. AutomationState (`Services/AutomationEngine.swift`)

Observable state shared by dashboard and menu bar surfaces.

```swift
@Observable
final class AutomationState {
    var isRunning: Bool = false
    var isWatchingFolders: Bool = false
    var lastRunDate: Date?
    var nextScheduledRun: Date?
    var statusMessage: String
}
```

`statusMessage` now distinguishes between active scanning, live watching, scheduled sweeps, and paused states.

### 4. DashboardFileScanProvider + FileScanPipeline

`DashboardFileScanProvider` now supports two scan modes:

- **Full sweep**: `scanFiles(context:baseFolders: nil)` for manual, launch, and scheduled scans
- **Targeted rescan**: `scanFiles(context:baseFolders: watchedRoots)` for watcher-triggered changes

`FileScanPipeline` persists both scanned file paths and `scannedRootPaths`, allowing downstream UI to merge only the refreshed roots.

### 5. Dashboard/Menu Bar Refresh Path

Automation persistence notifications now carry:

- `scannedPaths`
- `scannedRootPaths`
- `replacesAllFiles`
- `errorSummary`

Dashboard refresh uses `scanRootPath` to replace only files that belong to rescanned roots for partial watcher updates, or to replace the full in-memory slice for scheduled/manual full sweeps. The menu bar keeps a simpler model and re-queries its SwiftData-backed counts/files after any automation persistence event.

### 6. AutomationLifecycleModifier (`Configuration/AutomationLifecycleModifier.swift`)

Lifecycle integration keeps behavior explicit:

- `.activeWithWindow` and `.menuBarOnly`: watchers and scheduled scans may run if policy allows scanning
- `.backgrounded` or app termination: watchers and scheduled scans stop

## Data Flow

### Realtime Watch Cycle

```
1. Lifecycle/policy permit automation
         │
         ▼
2. AutomationEngine resolves enabled watched roots from BookmarkFolderService
         │
         ▼
3. FileMonitorService starts or rebuilds an FSEvents stream
         │
         ▼
4. Filesystem changes arrive as concrete paths
         │
         ▼
5. FileMonitorService maps paths → watched roots and debounces bursts
         │
         ▼
6. AutomationEngine runs scanFiles(context:baseFolders:) for only those roots
         │
         ▼
7. FileScanPipeline persists results and posts automationScanDidPersist
         │
         ▼
8. Dashboard merges rescanned roots by scanRootPath; menu bar re-queries SwiftData
         │
         ▼
9. If policy.canAutoOrganize, eligible files are auto-organized after the scan
```

If a realtime change arrives while another automation scan is already running, the engine unions the changed roots into a single queued follow-up rescan instead of launching a concurrent scan.

### Scheduled Sweep Cycle

```
1. Scheduler fires using AutomationPolicy interval/backoff rules
         │
         ▼
2. AutomationEngine performs a full scan (baseFolders = nil)
         │
         ▼
3. Persistence, notifications, threshold checks, and optional auto-organize run normally
         │
         ▼
4. Next sweep is scheduled
```

Scheduled sweeps remain the recovery path if watcher setup fails or an event is missed.

## Configuration

All automation thresholds live in `FormaConfig.Automation`:

| Constant | Default | Description |
|----------|---------|-------------|
| `backlogThreshold` | 50 | Files pending before increasing scan frequency |
| `ageThresholdDays` | 7 | Days before a file is considered stale |
| `minScanIntervalMinutes` | 5 | Minimum time between scheduled sweeps |
| `maxScanIntervalMinutes` | 60 | Maximum time between scheduled sweeps |
| `fileWatcherDebounceDurationSeconds` | 1.5 | Debounce window for coalescing watcher events |
| `mlRuleConfidenceMinimum` | 0.75 | Minimum confidence for rule suggestion |
| `mlAutoOrganizeConfidenceMinimum` | 0.85 | Minimum confidence for auto-organize |
| `backlogReminderCooldownHours` | 24 | Hours between backlog reminders |
| `errorNotificationCooldownMinutes` | 30 | Minutes between error notifications |
| `maxNotificationsPerHour` | 5 | Rate limit for user notifications |

## Feature Flags

Automation continues to be gated for staged rollout:

```swift
enum FeatureFlag {
    case backgroundMonitoring
    case autoOrganize
    case automationReminders
}
```

`backgroundMonitoring` gates both live watching and scheduled sweeps. `autoOrganize` controls whether completed scans also execute automatic file moves.

## Activity Logging and Notifications

Automation continues to log scan completion, auto-organize batches, and failures through `ActivityLoggingService`. Partial scan failures are surfaced through `errorSummary` in the persistence notification and through the existing automation error logging/notification path.

## Undo Support

Auto-organized files still flow through `FileOrganizationCoordinator`, which groups automation-driven moves into undoable commands so users can reverse a batch move after an automatic run.

## Testing

Key coverage for v1.5:

- `FileMonitorServiceTests`: watcher start/stop, root mapping, debounce coalescing
- `AutomationEngineRealtimeMonitoringTests`: watcher lifecycle, root-targeted scans, queued follow-up rescans
- `DashboardViewModelTests`: root-scoped merge after partial automation persistence
- Existing automation integration coverage: policy, metrics, logging, and auto-organize behavior

Default unit tests use fake watcher injections. Live filesystem watcher behavior should remain integration-gated rather than timing-sensitive in standard unit runs.

## Design Decisions

### Why root-level rescans instead of per-file refreshes?

Watcher callbacks report path changes, but the scan pipeline persists and reconciles state at the root level. Rescanning the affected roots keeps persistence correct for creations, deletions, renames, and metadata changes without needing fragile incremental diff logic.

### Why keep scheduled sweeps after adding watchers?

`FSEvents` is a trigger mechanism, not a persistence guarantee. Scheduled sweeps provide recovery if a watcher cannot start, bookmark access changes, or an event is missed while the app is not active.

### Why keep watcher ownership inside AutomationEngine?

The engine already owns lifecycle, policy, scheduling, and auto-organize decisions. Centralizing watcher lifecycle there prevents split-brain behavior between the scheduler and realtime monitoring paths.

---

**Created:** December 6, 2025
**Last Updated:** March 25, 2026
