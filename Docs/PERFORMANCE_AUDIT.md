# Forma Performance Audit & Optimization Guide

## Overview

This document tracks the performance optimization work for the Forma macOS app following Phase 3 AI/ML integration. The app was experiencing severe UI freezes (30-60 seconds) after the permissions screen and during actions like "Create Rule".

**Audit Date:** December 2025
**Last Verified:** February 12, 2026
**Status:** Active and benchmarked

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

### Captured Optimization Benchmarks (February 5, 2026)

The following microbenchmarks were captured with the benchmark harness in `OptimizationBenchmarksTests`.

**Command used**

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -derivedDataPath DerivedDataCodexBench CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -skip-testing:"Forma File OrganizingUITests" -only-testing:"Forma File OrganizingTests/OptimizationBenchmarksTests"
```

**Environment**
- Xcode 26.3 (Build 17C519)
- Destination: `platform=macOS` (arm64)
- Date: February 5, 2026

| Benchmark | Baseline (ms) | Optimized (ms) | Speedup |
|-----------|---------------|----------------|---------|
| `search_lookup_linear_vs_indexed` | 8392.46 | 2.17 | 3869.27x |
| `scan_syscalls_baseline_vs_prefetch` | 140.87 | 15.84 | 8.89x |
| `duplicate_detection_legacy_vs_optimized` | 201.21 | 62.37 | 3.23x |

Notes:
- These are synthetic microbenchmarks intended for relative comparison, not user-facing latency guarantees.
- The benchmark output is emitted as `BENCHMARK|...` lines in test logs for easy regression tracking.

### Performance Regression Budgets (Added February 12, 2026)

`OptimizationBenchmarksTests` now enforces hard guardrails based on the February 5, 2026 baseline run.
The test fails when optimized-path timing or speedup regresses beyond these budgets.

| Benchmark | Max Optimized (ms) | Min Speedup |
|-----------|--------------------|-------------|
| `search_lookup_linear_vs_indexed` | 5.00 | 1000.00x |
| `scan_syscalls_baseline_vs_prefetch` | 24.00 | 5.00x |
| `duplicate_detection_legacy_vs_optimized` | 90.00 | 2.00x |

### Signpost Snapshot & Warm-up Policy (February 12, 2026)

A debug-only harness drives repeated dashboard refresh flows and now tags each interval as warm-up or sample:

- Launch argument: `--perf-signpost-harness`
- Sample iteration control: `FORMA_PERF_HARNESS_ITERATIONS` (environment variable)
- Warm-up control: `FORMA_PERF_HARNESS_WARMUP` (environment variable, default `3`)
- Data mode: `--uitesting` (in-memory deterministic mock files)
- Harness guard: `runPerformanceSignpostHarness` executes once per app launch to prevent overlapping duplicate runs in a single trace.

**Preferred capture command (scripted)**

```bash
Scripts/signpost_harness_snapshot.sh --iterations 60 --warmup 3 --time-limit 95 --output-prefix /tmp/forma-signpost-harness-60
```

**Raw xctrace command (manual fallback)**

```bash
xcrun xctrace record --template 'Logging' --output /tmp/forma-signpost-harness-warmup-once.trace --time-limit 28s --no-prompt --launch -- /usr/bin/env FORMA_PERF_HARNESS_WARMUP=3 FORMA_PERF_HARNESS_ITERATIONS=30 '/Users/jamesfarmer/Library/Developer/Xcode/DerivedData/Forma_File_Organizing-fnipupejxxbcmfgxesfzcmrikizz/Build/Products/Debug/Forma File Organizing.app/Contents/MacOS/Forma File Organizing' --uitesting --perf-signpost-harness
```

**Sample selection**

- Source table: `os-signpost-interval` from `xctrace export`
- Included only complete intervals (`→` present in row metadata)
- Filtered start metadata:
  - `[ DashboardScanRefresh ]  harness warmup N`
  - `[ DashboardScanRefresh ]  harness sample N`
  - `[ DefaultPanelInsightRefresh ]  harness warmup N`
  - `[ DefaultPanelInsightRefresh ]  harness sample N`

**Warm-up cutoff policy**

- Performance budget tracking uses **sample-only** intervals (`harness sample N`).
- We still retain **warmup+sample** p95 as a diagnostic for cold-start behavior.

### Long-Run Snapshot (Captured February 11, 2026)

- Command: `Scripts/signpost_harness_snapshot.sh --iterations 60 --warmup 3 --time-limit 95 --output-prefix /tmp/forma-signpost-harness-60`
- Captured complete intervals: `3` warmups + `60` dashboard samples and `58` default-panel samples.

| Operation | Sample Count | Min (ms) | P50 (ms) | P95 (ms) | P99 (ms) | Mean (ms) | Max (ms) |
|-----------|--------------|----------|----------|----------|----------|-----------|----------|
| `DashboardScanRefresh` (sample-only) | 60 | 354.606 | 410.458 | 430.861 | 460.897 | 409.659 | 460.897 |
| `DefaultPanelInsightRefresh` (sample-only) | 58 | 0.223 | 0.254 | 0.305 | 0.333 | 0.258 | 0.333 |

| Operation | P95 (warmup+sample) | P95 (sample-only) | Delta (ms) |
|-----------|----------------------|-------------------|------------|
| `DashboardScanRefresh` | 453.824 | 430.861 | -22.963 |
| `DefaultPanelInsightRefresh` | 0.305 | 0.305 | 0.000 |

### Provisional P95 Budgets (February 12, 2026)

| Operation | Latest Sample-Only P95 (ms) | Provisional P95 Budget (ms) | Rationale |
|-----------|-----------------------------|------------------------------|-----------|
| `DashboardScanRefresh` | 430.861 | 500.000 | Keeps meaningful headroom while still detecting user-perceptible scan regressions. |
| `DefaultPanelInsightRefresh` | 0.305 | 0.400 | Keeps insight refresh effectively instant while allowing minor run-to-run variance. |

Sub-phase signposts now emitted within dashboard refresh flows:
- `DashboardScanDiscovery`
- `DashboardRuleEvaluation`
- `DashboardClusterRefresh`
- `DashboardPublish`
- Current harness mode (`--perf-signpost-harness` using automation update) emits `DashboardClusterRefresh` and `DashboardPublish`; full scan pipeline runs emit `DashboardScanDiscovery` and `DashboardRuleEvaluation`.

### Regression Gate Command

Run the dedicated performance plan (which now includes `OptimizationBenchmarksTests`) before merge:

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -testPlan "Forma File Organizing - Performance" -destination 'platform=macOS'
```

### Validation Snapshot (February 5, 2026)

**Command used**

```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination 'platform=macOS' -derivedDataPath DerivedDataCodexFullNonUI CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO -skip-testing:"Forma File OrganizingUITests"
```

**Result**
- `TEST SUCCEEDED`
- 513 tests executed, 0 failures, 0 unexpected

---

## Next Optimization Batch (Starting February 12, 2026)

The initial speed sprint goals are complete. This next batch focuses on reducing tail latency and making performance checks repeatable before merge.

### Priority 1: Tail-Latency Containment
- [x] Split `DashboardScanRefresh` into sub-phase signposts (scan discovery, rule evaluation, cluster refresh, dashboard publish) to isolate the `860ms` outlier path seen in the current snapshot.
- [x] Add a warm-up cutoff policy for harness analysis (for example, discard first N intervals) and document it with before/after p95 values.
- [x] Capture a longer run (`60+` complete intervals) and record p50/p95/p99 for `DashboardScanRefresh`.

### Priority 2: Regression Automation
- [x] Add a script in `Scripts/` that runs the signpost harness and exports summary stats (samples, min/p50/p95/p99/mean/max) from `xctrace`.
- [x] Add a dedicated pre-PR command in `Docs/Development/TESTING.md` for running the signpost snapshot flow.
- [x] Define provisional p95 budget targets for dashboard and default-panel refresh operations based on the latest trace.

### Priority 3: User-Perceived Responsiveness
- [x] Ensure default-panel insight refresh uses a strict single in-flight task policy under rapid data updates.
- [x] Add lightweight scan phase status text in the dashboard so long operations communicate progress instead of appearing stalled.

## References

- [Apple: Improving App Responsiveness](https://developer.apple.com/documentation/xcode/improving-app-responsiveness)
- [WWDC 2021: Diagnose Power and Performance Regressions](https://developer.apple.com/videos/play/wwdc2021/10087/)
- [Swift Concurrency: Task and TaskGroup](https://developer.apple.com/documentation/swift/task)
- [OSSignpost for Performance Measurement](https://developer.apple.com/documentation/os/logging/recording_performance_data)

---

## Related Documentation

### Audits & Analysis
- [Codebase Audit](Archive/Audits/CODEBASE_AUDIT.md) - Full codebase review (archived)
- [UX/UI Analysis](Archive/Audits/UX-UI-ANALYSIS.md) - User experience review (archived)

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
| 2026-02-05 | Added measured optimization benchmark results and non-UI suite verification snapshot | Codex |
| 2026-02-12 | Removed stale checklist content and added next optimization batch priorities | Codex |
| 2026-02-12 | Completed next optimization batch with scripted signpost harness snapshots, long-run p50/p95/p99 metrics, provisional p95 budgets, and responsiveness UX updates | Codex |
