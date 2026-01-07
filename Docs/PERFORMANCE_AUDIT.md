# Forma Performance Audit & Optimization Guide

## Overview

This document tracks the performance optimization work for the Forma macOS app following Phase 3 AI/ML integration. The app was experiencing severe UI freezes (30-60 seconds) after the permissions screen and during actions like "Create Rule".

**Audit Date:** December 2025
**Status:** In Progress

---

## Problem Statement

### Symptoms
- App becomes sluggish immediately after permissions onboarding completes
- 30-60 second UI freezes when clicking "Create Rule" or similar actions
- Beach ball cursor during file scanning operations
- UI unresponsive while AI services process files

### Root Causes Identified

1. **`@MainActor` Cascade** - FileScanPipeline protocol marked `@MainActor` forces all AI work onto main thread
2. **Runaway onChange Triggers** - View modifiers fire repeatedly during data updates without debouncing
3. **O(n²) Algorithms** - Name similarity detection scales quadratically with file count
4. **Synchronous File I/O** - SHA256 hashing reads entire files into memory blocking main thread
5. **Sequential Processing** - ML predictions processed one-by-one instead of batched

---

## Architecture Analysis

### Call Flow: Permissions → Main Content → Freeze

```
App Launch
    └─> DashboardView.task
            └─> dashboardViewModel.scanFiles(context:)  [@MainActor]
                    └─> fileScanPipeline.scanAndPersist()  [@MainActor protocol - PROBLEM]
                            ├─> fileSystemService.scan()
                            ├─> ruleEngine.evaluateFiles()  [synchronous]
                            ├─> applyLearnedPatterns()  [synchronous]
                            └─> applyMLPredictions()  [sequential loop]
                    └─> detectClusters()
                            └─> contextDetectionService.detectClusters()  [O(n²)]

Meanwhile, in DefaultPanelView:
    └─> .onChange(of: dashboardViewModel.allFiles)  [fires repeatedly]
            └─> loadInsights()
                    └─> insightsService.generateInsights()  [chains 5 expensive ops]
                            ├─> detectFilePatterns()
                            ├─> detectStorageIssues()
                            ├─> detectRuleOpportunities()
                            │       └─> learningService.detectPatterns()  [4 algorithms]
                            └─> detectProjectClusters()
                                    └─> contextDetectionService.detectClusters()  [O(n²) AGAIN]
```

### Key Files & Issues

| File | Line | Issue | Severity |
|------|------|-------|----------|
| `FileScanPipeline.swift` | 11 | `@MainActor` on protocol | Critical |
| `DefaultPanelView.swift` | 64-68 | Unbounded onChange triggers | Critical |
| `InsightsService.swift` | 45-71 | Synchronous generateInsights() | Critical |
| `ContextDetectionService.swift` | 166-218 | O(n²) name similarity | High |
| `DuplicateDetectionService.swift` | ~calculateFileHash | Blocking file read | High |
| `LearningService.swift` | 49-72 | 4 sequential algorithms | Medium |
| `FileScanPipeline.swift` | 186-206 | Sequential ML predictions | Medium |

---

## Instrumentation Plan

### OSSignpost Timing Points

We will add 5 strategic signposts to measure baseline performance:

1. **FileScan** - Total scan duration in `DashboardViewModel.scanFiles()`
2. **RuleEvaluation** - Rule engine processing in `FileScanPipeline.persist()`
3. **ClusterDetection** - Context detection in `ContextDetectionService.detectClusters()`
4. **InsightGeneration** - Full insight pipeline in `InsightsService.generateInsights()`
5. **FileHash** - Per-file hashing in `DuplicateDetectionService`

### How to Measure

1. Build and run the app with Instruments attached
2. Select "Time Profiler" template with "os_signpost" enabled
3. Complete onboarding flow and observe signpost intervals
4. Record baseline measurements in the table below

### Baseline Measurements

| Metric | File Count | Duration | Date | Notes |
|--------|------------|----------|------|-------|
| FileScan | TBD | TBD | - | End-to-end scan |
| RuleEvaluation | TBD | TBD | - | Rule matching |
| ClusterDetection | TBD | TBD | - | O(n²) algorithm |
| InsightGeneration | TBD | TBD | - | Full pipeline |
| FileHash (avg) | TBD | TBD | - | Per-file average |

---

## Fix Implementation Plan

### Phase 1: Instrumentation (Current)
- [ ] Add PerformanceMonitor utility class
- [ ] Instrument DashboardViewModel.scanFiles()
- [ ] Instrument FileScanPipeline.persist()
- [ ] Instrument ContextDetectionService.detectClusters()
- [ ] Instrument InsightsService.generateInsights()
- [ ] Instrument DuplicateDetectionService hash calculation
- [ ] Record baseline measurements

### Phase 2: Critical Fixes (P0)
- [ ] Remove `@MainActor` from FileScanPipelineProtocol
- [ ] Wrap heavy work in `Task.detached` in DashboardViewModel
- [ ] Add debouncing to DefaultPanelView onChange handlers
- [ ] Make InsightsService.generateInsights() async

### Phase 3: High Priority Fixes (P1)
- [ ] Cap or parallelize name similarity detection
- [ ] Stream file hashing with chunked reads
- [ ] Run LearningService algorithms in parallel

### Phase 4: Medium Priority Fixes (P2)
- [ ] Batch ML predictions with TaskGroup
- [ ] Add early-exit conditions to expensive loops
- [ ] Implement progressive loading for large file counts

### Phase 5: Verification
- [ ] Re-measure with instrumentation
- [ ] Compare before/after metrics
- [ ] Verify UI responsiveness during scan
- [ ] Test with 500+ files
- [ ] Test with large files (100MB+)

---

## Code Patterns to Apply

### Pattern 1: Moving Work Off Main Thread

```swift
// BEFORE: @MainActor forces main thread
@MainActor
func heavyOperation() async {
    let result = expensiveComputation()  // Blocks UI
}

// AFTER: Dispatch to background
@MainActor
func heavyOperation() async {
    let result = await Task.detached(priority: .userInitiated) {
        expensiveComputation()  // Background thread
    }.value
    // Back on MainActor for UI updates
    self.data = result
}
```

### Pattern 2: Debouncing onChange

```swift
// BEFORE: Fires on every change
.onChange(of: data) { _, _ in
    expensiveUpdate()
}

// AFTER: Debounced
@State private var updateTask: Task<Void, Never>?

.onChange(of: data) { _, _ in
    updateTask?.cancel()
    updateTask = Task {
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        await expensiveUpdateAsync()
    }
}
```

### Pattern 3: Parallel Processing

```swift
// BEFORE: Sequential
for item in items {
    await process(item)
}

// AFTER: Concurrent with TaskGroup
await withTaskGroup(of: Result.self) { group in
    for item in items {
        group.addTask { await process(item) }
    }
    for await result in group {
        results.append(result)
    }
}
```

### Pattern 4: Streaming File I/O

```swift
// BEFORE: Load entire file
let data = FileManager.default.contents(atPath: path)!
let hash = SHA256.hash(data: data)

// AFTER: Stream in chunks
var hasher = SHA256()
let stream = InputStream(fileAtPath: path)!
stream.open()
defer { stream.close() }

var buffer = [UInt8](repeating: 0, count: 64 * 1024)
while stream.hasBytesAvailable {
    let count = stream.read(&buffer, maxLength: buffer.count)
    if count > 0 { hasher.update(data: Data(buffer[0..<count])) }
}
let hash = hasher.finalize()
```

---

## Testing Checklist

### Functional Tests
- [ ] App launches without crash
- [ ] Onboarding flow completes
- [ ] File scanning discovers files
- [ ] Rules are evaluated correctly
- [ ] ML predictions still work
- [ ] Insights are generated

### Performance Tests
- [ ] UI remains responsive during scan (target: <100ms frame time)
- [ ] Scan completes in reasonable time (target: <5s for 500 files)
- [ ] "Create Rule" responds immediately
- [ ] Large file handling doesn't freeze UI

### Edge Cases
- [ ] Empty folders
- [ ] 1000+ files
- [ ] Files >100MB
- [ ] Network drives (if supported)
- [ ] Simultaneous operations

---

## References

- [Apple: Improving App Responsiveness](https://developer.apple.com/documentation/xcode/improving-app-responsiveness)
- [WWDC 2021: Diagnose Power and Performance Regressions](https://developer.apple.com/videos/play/wwdc2021/10087/)
- [Swift Concurrency: Task and TaskGroup](https://developer.apple.com/documentation/swift/task)
- [OSSignpost for Performance Measurement](https://developer.apple.com/documentation/os/logging/recording_performance_data)

---

## Related Documentation

### Audits & Analysis
- [Codebase Audit](CODEBASE_AUDIT.md) - Full codebase review
- [UX/UI Analysis](UX-UI-ANALYSIS.md) - User experience review

### Architecture
- [System Architecture](Architecture/ARCHITECTURE.md) - Overall system design
- [Rule Engine Architecture](Architecture/RuleEngine-Architecture.md) - Rule evaluation system

### Implementation
- [Performance Optimization Report](Archive/Implementation-Notes/PERFORMANCE_OPTIMIZATION_REPORT.md) - Historical optimization notes

### Navigation
- [Documentation Index](INDEX.md) - Master navigation

---

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2025-12-02 | Initial audit and documentation | Claude Code |
| 2025-12-22 | Analytics performance optimization (background threading) | Antigravity |
| - | Added instrumentation | - |
| - | Phase 2 fixes | - |
| - | Verification complete | - |
