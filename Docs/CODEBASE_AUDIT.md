# Forma Codebase Audit Report

**Date:** December 2, 2025
**Auditor:** Claude (Staff-level macOS Engineer)
**Scope:** Navigation, state management, SwiftUI, file I/O, persistence, business logic
**Excluded:** AI/ML performance hotspots (being addressed separately)

---

## Section 1: Orient (Architecture Overview)

### App Structure
Forma is a macOS file organization app built with:
- **SwiftUI** for UI
- **SwiftData** for persistence (`@Model` classes)
- **Protocol-based architecture** for testability
- **Coordinator pattern** for state decomposition

### Core Data Models (`/Models/`)
| Model | Purpose |
|-------|---------|
| `FileItem` | SwiftData model for scanned files |
| `FileMetadata` | Lightweight value type during scanning |
| `Rule` | Organization rules with conditions |
| `RuleCondition` | Type-safe condition enum |
| `ActivityItem` | User activity log |
| `LearnedPattern` | ML-detected patterns |
| `ProjectCluster` | Detected project groupings |
| `CustomFolder` | User-added scan locations |

### Services Layer (`/Services/`)
| Service | Responsibility |
|---------|---------------|
| `FileSystemService` | Directory scanning, security bookmarks |
| `FileOperationsService` | Move/copy/delete with TOCTOU protection |
| `RuleEngine` | Rule evaluation (protocol-based) |
| `FileScanPipeline` | Orchestrates scan → evaluate → persist |
| `StorageService` | Analytics caching |
| `LearningService` | Pattern detection |
| `DestinationPredictionService` | ML predictions |

### ViewModels & Coordinators
| Component | Lines | Responsibility |
|-----------|-------|---------------|
| `DashboardViewModel` | ~1400 | **God Object** - scanning, filtering, selection, undo/redo |
| `FileOrganizationCoordinator` | ~300 | File operations + undo stack |
| `FileFilterManager` | ~200 | Filtering logic |
| `SelectionManager` | ~100 | Multi-select state |
| `PanelStateManager` | ~150 | Right panel + toasts |

---

## Section 2: Bug & Risk Scan

### A. Crashes & Unsafe Operations (P0 - Critical)

> **Why preconditions crash in production:** `precondition()` terminates the process in both debug and release builds. For user-facing code, use `guard` with graceful error handling instead. Reserve `precondition` for truly unrecoverable programmer errors.

| ID | Location | Issue | Impact |
|----|----------|-------|--------|
| A1 | `FileItem.swift:131-132` | `precondition(!path.isEmpty)` | Crash if empty path from corrupted data |
| A2 | `FileItem.swift:176-177` | Same pattern | Crash on legacy data migration |
| A3 | `FileMetadata.swift:56-57, 116-117` | Same pattern | Crash during file scan |
| A4 | `ContextDetectionService.swift:355` | `dates.max()!.timeIntervalSince(dates.min()!)` | Crash if `files` array passed was empty |
| A5 | `ContextDetectionService.swift:368` | `files.first!` | Crash if empty array |
| A6 | `DestinationPredictionService.swift:421, 450` | `.first!` on FileManager URLs | Rare crash if app support unavailable |
| A7 | `DestinationGroupView.swift:220` | `components.first!` | Crash on malformed path |
| A8 | `FileInspectorView.swift:570` | `filesWithSuggestions.first!.suggestedDestination!` | Double force unwrap |
| A9 | `InlineRuleBuilderView.swift:679` | `finalConditions.first!` | Crash if empty conditions |
| A10 | `FileViews.swift:118` | `components.first!` | Crash on empty path |
| A11 | `StorageService.swift:28-29` | `lastCalculationDate!` and `cachedAnalytics!` | Thread race could bypass nil check |

### B. SwiftUI State & View Lifecycle (P1)

| ID | Location | Issue | Impact |
|----|----------|-------|--------|
| B1 | `DashboardViewModel` | 1400+ lines, 15+ `@Published` properties | Hard to reason about state changes, excessive re-renders |
| B2 | `DashboardView.swift:5-6` | Two `@StateObject` in same view | Potential initialization order issues |
| B3 | Nested `@ObservedObject` forwarding | `setupNestedObjectForwarding()` manual Combine piping | Error-prone, could miss updates |
| B4 | `RuleEditorView.swift` | 19 `@State` variables | Component too stateful, hard to test |
| B5 | `Views/Onboarding/OnboardingState.swift` | Shared onboarding state object | Complex state coordination in view layer |

### C. Concurrency & async/await (P1)

| ID | Location | Issue | Impact |
|----|----------|-------|--------|
| C1 | `FileSystemService.requestFolderURL:276` | `DispatchQueue.main.async` inside `withCheckedThrowingContinuation` | Potential deadlock if called from main |
| C2 | `StorageService` | Non-thread-safe singleton with caching | Race condition on cache access |
| C3 | `DashboardViewModel.autoScanTask` | `[weak self]` with nullable context | Silent failure if self is deallocated |
| C4 | `ThumbnailService.swift:69` | `Task { @MainActor in }` without cancellation | Leaking tasks on rapid navigation |
| C5 | Multiple views | `Task { }` without storing handle | Unmanaged task lifecycle |

### D. File I/O & Persistence Risks (P1)

| ID | Location | Issue | Impact |
|----|----------|-------|--------|
| D1 | `FileOperationsService` | **Good:** TOCTOU protection via file descriptors | ✓ Positive |
| D2 | `FileSystemService` | **Good:** Symlink detection and validation | ✓ Positive |
| D3 | `SecureBookmarkStore` | **Good:** Keychain storage for bookmarks | ✓ Positive |
| D4 | `InlineRuleBuilderView.swift:692` | `try? modelContext.save()` | Silent persistence failure |
| D5 | Various SwiftData saves | `try context.save()` without rollback | Partial state on failure |
| D6 | Custom folder staleness | Bookmark can go stale between scans | Access errors |

### E. Business Logic Edge Cases (P2)

| ID | Location | Issue | Impact |
|----|----------|-------|--------|
| E1 | `detectAndPersistPatterns` | Requires `activities.count >= 3` | Silent skip for new users |
| E2 | `detectClusters` | Requires `allFiles.count >= 5` | No clusters for small file counts |
| E3 | `DashboardViewModel.organizeCluster` | `// TODO: Implement actual file operations` | Cluster organize does nothing! |
| E4 | `Rule.destinationFolder` validation | Only validates special chars, not existence | User sees error only at move time |
| E5 | `ByteSizeFormatterUtil.parse` | Returns 0 on parse failure | "0 bytes" shown for invalid input |

---

## Section 3: Complexity & Design Smells

### God Object: `DashboardViewModel`
**Lines:** ~1400
**Responsibilities:** File scanning, rule management, filtering, selection, undo/redo, analytics, cluster detection, custom folders, activity tracking, pattern detection, view mode preferences, panel state, bulk operations, auto-scanning.

**Recommendation:** Split into focused view models:
- `ScanViewModel` - scanning, rules, file state
- `SelectionViewModel` - selection, bulk operations
- `AnalyticsViewModel` - storage analytics, insights
- `PreferencesViewModel` - view modes, settings

### Over-Abstraction: Coordinator Layer
Four coordinators (`FileOrganizationCoordinator`, `FileFilterManager`, `SelectionManager`, `PanelStateManager`) plus the DashboardViewModel create a 5-layer deep state graph. Changes propagate through Combine subscriptions with manual forwarding.

**Recommendation:** Consolidate to 2 coordinators max, or use SwiftUI's native `@Observable` (iOS 17+) for automatic propagation.

### Redundant Protocols
`Fileable` and `Ruleable` protocols exist for testability, but many services still downcast to concrete types:
```swift
if let concreteFS = fileSystemService as? FileSystemService {
    // Uses concrete type anyway
}
```

---

## Section 4: Debugging & Instrumentation

### Current State
- `Log` utility with categories (`.pipeline`, `.filesystem`, `.security`, etc.)
- `PerformanceMonitor` for timing
- `#if DEBUG` guards throughout

### Recommendations

#### 1. Add Structured Error Context
```swift
// Instead of:
Log.error("Failed: \(error)")
// Use:
Log.error("Failed", metadata: ["file": path, "error": error])
```

#### 2. Add State Snapshots on Crash
```swift
func captureStateForDiagnostics() -> [String: Any] {
    ["fileCount": allFiles.count, "selection": selectedFileIDs.count, ...]
}
```

#### 3. Add Analytics Events for User Flows
- Track: onboarding completion, rule creation, organize success/failure rates
- Helps identify UX friction points

#### 4. Add Defensive Logging Before Force Unwraps
Replace force unwraps with:
```swift
guard let first = array.first else {
    Log.error("Unexpected empty array", category: .pipeline)
    return defaultValue
}
```

---

## Section 5: Prioritized Findings & Action Plan

### P0 - Fix Immediately (Production Crashes)

| # | Issue | File:Line | Fix | Status |
|---|-------|-----------|-----|--------|
| 1 | `precondition` in FileItem | `FileItem.swift:131-132, 176-177` | Replace with `guard + Log.error + return nil` | ✅ |
| 2 | `precondition` in FileMetadata | `FileMetadata.swift:56-57, 116-117` | Replace with failable initializer | ✅ |
| 3 | Force unwrap on empty arrays | `ContextDetectionService.swift:355,368` | Add `guard !files.isEmpty` | ✅ |
| 4 | Double force unwrap | `FileInspectorView.swift:570` | Add optional binding | ✅ |
| 5 | Force unwrap in rule builder | `InlineRuleBuilderView.swift:679` | Add `guard !finalConditions.isEmpty` | ✅ |
| 6 | Force unwrap in path truncation | `DestinationGroupView.swift:220`, `FileViews.swift:118` | Add `guard !components.isEmpty` | ✅ |
| 7 | Force unwrap in ML service | `DestinationPredictionService.swift:421,450` | Add fallback for missing app support | ✅ |
| 8 | Race condition in cache | `StorageService.swift:28-29` | Thread-safe access | ✅ |

### P1 - Fix This Sprint (Reliability)

| # | Issue | Recommendation | Status |
|---|-------|----------------|--------|
| 9 | Silent persistence failures | Replace `try?` with proper error handling | ✅ |
| 10 | NSOpenPanel deadlock risk | Use `@MainActor` instead of `DispatchQueue.main.async` | ✅ |
| 11 | Unmanaged Task lifecycle | Store task handles and cancel in `onDisappear` | ✅ |
| 12 | Cluster organize is a no-op | Implement actual file operations via `organizeMultipleFiles` | ✅ |

### P2 - Address When Possible (Quality)

| # | Issue | Recommendation | Status |
|---|-------|----------------|--------|
| 13 | `DashboardViewModel` god object | Split into focused ViewModels | ⬜ |
| 14 | 147 state property usages in views | Audit for unnecessary re-renders | ⬜ |
| 15 | Over-abstracted coordinator layer | Consolidate or migrate to `@Observable` | ⬜ |
| 16 | Redundant protocol downcasts | Remove dead code paths | ⬜ |
| 17 | Missing analytics events | Add lightweight telemetry | ⬜ |

---

## Quick Reference: Files to Modify

### P0 Fixes (In Order)
1. `Forma File Organizing/Models/FileItem.swift`
2. `Forma File Organizing/Models/FileMetadata.swift`
3. `Forma File Organizing/Services/ContextDetectionService.swift`
4. `Forma File Organizing/Views/FileInspectorView.swift`
5. `Forma File Organizing/Views/InlineRuleBuilderView.swift`
6. `Forma File Organizing/Views/Components/DestinationGroupView.swift`
7. `Forma File Organizing/Components/FileViews.swift`
8. `Forma File Organizing/Services/DestinationPredictionService.swift`
9. `Forma File Organizing/Services/StorageService.swift`

---

## Appendix: Security Positives

The codebase demonstrates strong security practices in several areas:

1. **TOCTOU Protection** - `FileOperationsService` uses file descriptors to prevent time-of-check-time-of-use vulnerabilities
2. **Symlink Detection** - `FileSystemService` skips symlinks to prevent path traversal attacks
3. **Keychain Storage** - Security-scoped bookmarks stored in Keychain via `SecureBookmarkStore`
4. **Path Validation** - `PathValidator` checks for traversal attempts and special characters
5. **Bookmark Validation** - Resolved bookmarks are verified against expected folder names

These should be preserved during refactoring.

---

## Related Documentation

### Audits & Analysis
- [Performance Audit](PERFORMANCE_AUDIT.md) - Performance analysis and optimization
- [UX/UI Analysis](UX-UI-ANALYSIS.md) - User experience review

### Architecture
- [System Architecture](Architecture/ARCHITECTURE.md) - Overall system design
- [Component Architecture](Architecture/ComponentArchitecture.md) - UI component catalog

### Security
- [Security Documentation](Security/README.md) - Security audits and fixes
- [File Operations Audit](Architecture/File-Operations-Audit.md) - File operations review

### Navigation
- [Documentation Index](INDEX.md) - Master navigation

---

**Document Version:** 1.0
**Last Updated:** 2026-01-06
