# Forma v1.2.0 – Analytics & Insights Implementation Plan

This plan describes the implementation for the v1.2.0 Analytics & Insights features: historical storage trends, usage statistics, storage health scoring, and exportable reports. It aligns with the existing MVVM + Services + SwiftData architecture and reuses the Activity logging foundation already in place.

---

## 1. Problem Statement & Current State (Brief)

> [!NOTE]
> **Status**: Implemented in v1.5.0 (Dec 2025).
> **Implementation Note**: The final implementation moved the Storage Breakdown and Trends charts to the **Center Panel** to avoid redundancy, reserving the **Right Panel** for actionable recommendations ("Opportunities").

Today, Forma:
- Computes **point-in-time storage analytics** via `StorageAnalytics` and `StorageService.calculateAnalytics()` with a 60-second cache.
- Logs **user activity** via `ActivityLoggingService` into the SwiftData `ActivityItem` model.
- Surfaces **AI insights** (issues, learned patterns, summaries) via `InsightsService` and `AIInsightsView`.

However, Forma does not:
- Persist historical storage snapshots over time.
- Provide storage growth/reduction charts or cleanup impact metrics.
- Aggregate usage statistics (files organized per day/week/month, rule usage, time saved).
- Compute a storage health score or generate exportable weekly reports as PDFs.

v1.2.0 must introduce a small, focused analytics subsystem that:
- Uses existing `ActivityItem` and `StorageAnalytics` data.
- Persists compact historical summaries.
- Surfaces trends and health scores in a dedicated Analytics UI.
- Generates branded weekly reports with PDF export.

---

## 2. Goals & Non-Goals

### Goals
- **Storage Trends**
  - Persist daily `StorageSnapshot` records.
  - Provide growth/reduction charts over time.
  - Visualize category trends (top categories) over a rolling window.
  - Compute cleanup impact metrics (freed bytes, largest cleanups).
- **Usage Statistics**
  - Aggregate files organized per day/week/month.
  - Track most-used rules.
  - Estimate time saved from automation.
  - Support basic organization pattern analysis for recommendations.
- **Reports**
  - Generate weekly cleanup reports from aggregated analytics.
  - Compute a storage health score (0–100) with factor breakdowns.
  - Produce optimization recommendations.
  - Export reports to PDF with Forma branding.

### Non-Goals (v1.2.0)
- No new ML models beyond existing AI features (this is aggregation/analytics, not predictive modeling).
- No background daemons or launch agents; scheduling is app-lifecycle based (launch/activation).
- No server-side analytics; all computation is local and uses existing SwiftData stores.

---

## 3. Assumptions & Decisions

### Assumptions (v1.2.0 Defaults)
- **Retention period**: Keep **90 days** of `StorageSnapshot` history; older snapshots are pruned automatically. This is a fixed value for v1.2.0 to reduce complexity—user configuration may be added in a future release.
- **Time saved**: Use fixed per-operation heuristics (not exposed to users):
  - `fileOrganized`: ~6 seconds saved vs manual.
  - `bulkOrganized`: ~4 seconds saved per file.
  - `ruleApplied`: ~8 seconds saved per file affected.
  - *Rationale*: These are internal estimates for user delight, not contractual promises. Surfacing them in Settings invites scrutiny and support burden.
- **Health score**:
  - Base score of 100.
  - Capacity usage, unorganized items, rule coverage, and growth trend each contribute negative adjustments.
  - Factors and weights are codified in a small `StorageHealthScore` model for transparency.
  - See Section 6.4 for the detailed scoring algorithm.
- **Report frequency**:
  - Weekly reports are auto-generated on first app launch each week.
  - A dismissible banner notifies users when a new report is available.
  - The architecture supports `daily` and `monthly` periods for future expansion.
- **PDF styling**:
  - Use Forma brand colors and typography in headings and section markers.
  - Simplified charts with key metrics (not numeric tables or screenshots).
  - Keep layout simple (title + key metrics + charts/summary text), optimized for clarity over heavy visual design.

### Decisions Made

| Question | Decision | Rationale |
|----------|----------|-----------|
| 90-day retention configurable? | **No** – fixed for v1.2.0 | Reduces complexity; revisit if users request it. |
| Time-saved heuristics in Settings? | **No** – internal only | These are estimates for user delight, not promises. Surfacing invites unnecessary scrutiny. |
| Weekly report generation | **Auto on first launch each week** | Manual-only friction kills adoption. Show dismissible banner for new reports. |
| PDF chart detail level | **Simplified charts with key metrics** | Numeric tables feel like spreadsheets; screenshots are fragile. |

---

## 4. Feature Flags & Config

Analytics must follow the existing feature-flag pattern and allow opt-out of AI/ML-adjacent behavior.

### 4.1 Feature Flags

**Location:** `Services/FeatureFlagService.swift`

- Add a master analytics flag:
  - `case analyticsAndInsights`
- Add child flags:
  - `case storageTrends`
  - `case usageStats`
  - `case storageHealthScore`
  - `case optimizationRecommendations`
  - `case analyticsReports`
- Behavior:
  - All analytics entry points should guard with:
    - `guard FeatureFlagService.shared.isEnabled(.analyticsAndInsights) else { return }`
  - Child features (`.storageTrends`, `.usageStats`, etc.) are checked at more granular entry points.
  - Defaults: enabled for all users; master toggle disables all child features regardless of individual settings.

### 4.2 Configuration

**Location:** `Configuration/FormaConfig.swift`

- Add an analytics configuration struct:

```swift
struct AnalyticsConfig {
    let retentionDays: Int
    let minSnapshotsForTrends: Int

    // Time-saved heuristics (seconds per operation).
    let secondsPerFileOrganized: Int
    let secondsPerFileInBulkOrganize: Int
    let secondsPerFileWithRuleApplied: Int

    // Health score weights (must sum to 1.0).
    let healthWeightCapacity: Double
    let healthWeightUnorganized: Double
    let healthWeightRuleCoverage: Double
    let healthWeightGrowthTrend: Double
}
```

- Expose a static config:

```swift
extension FormaConfig {
    static let analytics = AnalyticsConfig(
        retentionDays: 90,
        minSnapshotsForTrends: 7,
        secondsPerFileOrganized: 6,
        secondsPerFileInBulkOrganize: 4,
        secondsPerFileWithRuleApplied: 8,
        healthWeightCapacity: 0.40,
        healthWeightUnorganized: 0.25,
        healthWeightRuleCoverage: 0.20,
        healthWeightGrowthTrend: 0.15
    )
}
```

---

## 5. Data Models & Persistence

### 5.1 StorageSnapshot (new SwiftData model)

**Location:** `Forma File Organizing/Models/StorageSnapshot.swift`

Purpose: Persist daily storage state for trend analysis, category breakdown over time, and cleanup impact metrics.

Design:

```swift
import Foundation
import SwiftData

@Model
final class StorageSnapshot {
    #Index<StorageSnapshot>([\.date])  // Index for efficient date-range queries

    @Attribute(.unique) var id: UUID
    var date: Date          // normalized to start-of-day in user's local timezone, stored as UTC

    var totalBytes: Int64
    var fileCount: Int

    // JSON-encoded category → bytes map (String key = FileTypeCategory rawValue).
    var categoryBreakdownData: Data

    // Optional: bytes freed compared to previous snapshot (negative if usage decreased).
    var deltaBytesSincePrevious: Int64?

    init(
        id: UUID = UUID(),
        date: Date,
        totalBytes: Int64,
        fileCount: Int,
        categoryBreakdownData: Data,
        deltaBytesSincePrevious: Int64? = nil
    ) {
        self.id = id
        self.date = date
        self.totalBytes = totalBytes
        self.fileCount = fileCount
        self.categoryBreakdownData = categoryBreakdownData
        self.deltaBytesSincePrevious = deltaBytesSincePrevious
    }

    // MARK: - Type-Safe Category Access

    /// Decoded category breakdown with type safety.
    /// Returns empty dictionary if decoding fails (defensive, non-throwing).
    var categoryBreakdown: [String: Int64] {
        get {
            (try? JSONDecoder().decode([String: Int64].self, from: categoryBreakdownData)) ?? [:]
        }
    }

    /// Type-safe accessor using FileTypeCategory enum.
    func bytes(for category: FileTypeCategory) -> Int64 {
        categoryBreakdown[category.rawValue] ?? 0
    }
}
```

Helper type for decoded category maps (value-type only, not persisted):

```swift
struct StorageCategoryBreakdown: Sendable {
    var bytesByCategory: [String: Int64]  // key: FileTypeCategory.rawValue

    init(bytesByCategory: [String: Int64] = [:]) {
        self.bytesByCategory = bytesByCategory
    }

    init(from data: Data) throws {
        self.bytesByCategory = try JSONDecoder().decode([String: Int64].self, from: data)
    }

    func encoded() throws -> Data {
        try JSONEncoder().encode(bytesByCategory)
    }
}
```

### 5.2 Analytics Value Types (new)

**Location:** `Forma File Organizing/Models/AnalyticsModels.swift`

These are plain structs/enums used by services and view models; they are not SwiftData models.

```swift
import Foundation

// MARK: - Error Types

/// Errors that can occur during analytics operations.
enum AnalyticsError: Error, LocalizedError {
    case insufficientData(required: Int, available: Int)
    case snapshotEncodingFailed(underlyingError: Error)
    case snapshotDecodingFailed(underlyingError: Error)
    case retentionPolicyFailed(underlyingError: Error)
    case reportGenerationFailed(reason: String)
    case pdfExportFailed(underlyingError: Error)

    var errorDescription: String? {
        switch self {
        case .insufficientData(let required, let available):
            return "Insufficient data for analysis. Required: \(required) snapshots, available: \(available)."
        case .snapshotEncodingFailed(let error):
            return "Failed to encode snapshot data: \(error.localizedDescription)"
        case .snapshotDecodingFailed(let error):
            return "Failed to decode snapshot data: \(error.localizedDescription)"
        case .retentionPolicyFailed(let error):
            return "Failed to apply retention policy: \(error.localizedDescription)"
        case .reportGenerationFailed(let reason):
            return "Failed to generate report: \(reason)"
        case .pdfExportFailed(let error):
            return "Failed to export PDF: \(error.localizedDescription)"
        }
    }
}

// MARK: - Usage Types

enum UsagePeriod: Equatable, Sendable {
    case day
    case week
    case month
    case custom(DateInterval)
}

struct UsageStatistics: Sendable {
    let period: UsagePeriod
    let startDate: Date
    let endDate: Date

    let filesOrganized: Int
    let bulkOperations: Int
    let rulesAppliedByRuleID: [UUID: Int]

    let timeSavedSeconds: Int
    let averageFilesPerDay: Double
}

// MARK: - Trend Types

struct StorageTrendPoint: Identifiable, Sendable {
    let id: UUID
    let date: Date
    let totalBytes: Int64
    let deltaBytes: Int64
}

struct CleanupImpact: Sendable {
    let totalFreedBytes: Int64
    let averageFreedPerWeek: Int64
    let largestSingleCleanupBytes: Int64
}

// MARK: - Health Score Types

enum HealthFactorType: String, Sendable, CaseIterable {
    case capacity
    case unorganized
    case ruleCoverage
    case growthTrend
}

struct HealthFactor: Sendable {
    let type: HealthFactorType
    let description: String
    let rawScore: Double     // 0.0–1.0, where 1.0 is optimal
    let weight: Double       // from AnalyticsConfig
    let impact: Int          // negative numbers reduce score (computed: -Int((1 - rawScore) * weight * 100))
}

struct OptimizationRecommendation: Identifiable, Sendable {
    let id: UUID
    let title: String
    let detail: String
    let priority: Int    // 1 = highest priority
}

struct StorageHealthScore: Sendable {
    let score: Int               // 0–100
    let factors: [HealthFactor]
    let recommendations: [OptimizationRecommendation]

    /// Human-readable grade based on score.
    var grade: String {
        switch score {
        case 90...100: return "Excellent"
        case 75..<90: return "Good"
        case 60..<75: return "Fair"
        case 40..<60: return "Needs Attention"
        default: return "Critical"
        }
    }
}

// MARK: - Report Types

enum ReportPeriod: Equatable, Sendable {
    case weekly
    case monthly
    case custom(DateInterval)
}

struct AnalyticsReportSection: Sendable {
    let title: String
    let body: String
    let metrics: [String: String]
}

struct AnalyticsReport: Identifiable, Sendable {
    let id: UUID
    let generatedAt: Date
    let period: ReportPeriod

    let storageTrendPoints: [StorageTrendPoint]
    let usageStatistics: UsageStatistics
    let healthScore: StorageHealthScore
    let recommendations: [OptimizationRecommendation]

    let sections: [AnalyticsReportSection]
}

struct AnalyticsSummary: Sendable {
    let trendPoints: [StorageTrendPoint]
    let usageStatistics: UsageStatistics
    let healthScore: StorageHealthScore
}
```

### 5.3 StorageAnalytics Convenience Extensions (existing model)

**Location:** `Forma File Organizing/Models/StorageAnalytics.swift`

Add convenience initializers + helpers:

```swift
extension StorageAnalytics {
    init(snapshot: StorageSnapshot, categoryBreakdown: StorageCategoryBreakdown) {
        self.init(
            totalBytes: snapshot.totalBytes,
            fileCount: snapshot.fileCount,
            categoryBreakdown: categoryBreakdown.bytesByCategory
        )
    }

    func encodedCategoryBreakdown() throws -> Data {
        try JSONEncoder().encode(categoryBreakdown)
    }
}
```

### 5.4 Time Zone Handling

**Convention:** All `StorageSnapshot.date` values are normalized to the **start of day in the user's local timezone**, then stored as UTC.

```swift
extension Date {
    /// Returns the start of day in the user's local calendar/timezone.
    var startOfDayLocal: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// Returns true if this date is the same calendar day as another date (in local timezone).
    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }
}
```

This ensures:
- Users in different timezones see snapshots aligned to their local day boundaries.
- Comparisons like "is there a snapshot for today?" work correctly regardless of when the app launches.
- SwiftData stores the underlying UTC timestamp, preserving precision.

---

## 6. AnalyticsService – Trends & Usage Aggregation

**Location:** `Forma File Organizing/Services/AnalyticsService.swift`

### 6.1 Responsibilities

- Persist daily `StorageSnapshot` records using `StorageService.calculateAnalytics()`.
- Enforce retention policy (prune snapshots older than `AnalyticsConfig.retentionDays`).
- Compute storage trends (total bytes and deltas over time).
- Compute cleanup impact metrics from snapshots.
- Aggregate `UsageStatistics` from `ActivityItem` over a `UsagePeriod`.
- Compute `StorageHealthScore` from current analytics, snapshots, and usage statistics.
- Provide a single `AnalyticsSummary` DTO for UI consumption.

### 6.2 Type & Lifecycle

```swift
import Foundation
import SwiftData

final class AnalyticsService: Sendable {
    static let shared = AnalyticsService()

    private init() {}
}
```

AnalyticsService is not `@MainActor`; see Section 6.5 for threading model.

### 6.3 Public API Sketch

```swift
extension AnalyticsService {
    // MARK: - Storage Snapshots

    func recordDailySnapshotIfNeeded(
        modelContext: ModelContext,
        storageService: StorageService = .shared,
        now: Date = Date()
    ) async throws

    func fetchSnapshots(
        in range: DateInterval,
        modelContext: ModelContext
    ) async throws -> [StorageSnapshot]

    // MARK: - Trends & Cleanup Impact

    func computeStorageTrend(
        in range: DateInterval,
        modelContext: ModelContext
    ) async throws -> [StorageTrendPoint]

    func computeCleanupImpact(
        in range: DateInterval,
        modelContext: ModelContext
    ) async throws -> CleanupImpact

    // MARK: - Usage Statistics

    func fetchUsageStatistics(
        for period: UsagePeriod,
        modelContext: ModelContext
    ) async throws -> UsageStatistics

    // MARK: - Health Score

    func computeHealthScore(
        currentAnalytics: StorageAnalytics,
        snapshots: [StorageSnapshot],
        usage: UsageStatistics,
        modelContext: ModelContext
    ) async throws -> StorageHealthScore

    // MARK: - Combined Summary

    func loadAnalyticsSummary(
        for period: UsagePeriod,
        modelContext: ModelContext
    ) async throws -> AnalyticsSummary
}
```

Implementation details:
- `recordDailySnapshotIfNeeded`:
  - Normalize `now` to the start of day using `Date.startOfDayLocal`.
  - Query the most recent snapshot; if none for today, call `StorageService.calculateAnalytics()` to compute `StorageAnalytics`, encode category breakdown, and create a `StorageSnapshot`.
  - After insertion, prune snapshots older than `AnalyticsConfig.retentionDays`.
- `computeStorageTrend`:
  - Sort snapshots by date.
  - For each snapshot, compute `deltaBytes` from the previous snapshot (0 for the first one).
- `computeCleanupImpact`:
  - Consider negative deltas (`deltaBytes < 0`) as freed storage.
  - Sum freed bytes, compute weekly averages, and track the largest absolute negative delta.
- `fetchUsageStatistics`:
  - Translate `UsagePeriod` to `startDate`/`endDate`.
  - Query `ActivityItem` by timestamp.
  - Count `fileOrganized`, `bulkOrganized`, `fileMoved`, `ruleApplied`.
  - Use `AnalyticsConfig` to estimate `timeSavedSeconds`.
- `computeHealthScore`:
  - See Section 6.4 for the detailed algorithm.

### 6.4 Health Score Algorithm

The health score is computed as follows:

```
score = 100 - (capacityPenalty + unorganizedPenalty + ruleCoveragePenalty + growthTrendPenalty)
```

Each factor is computed independently, then weighted according to `AnalyticsConfig`:

| Factor | Weight | Calculation |
|--------|--------|-------------|
| **Capacity** | 0.40 | `rawScore = 1.0 - (usedBytes / totalDiskBytes)`. Penalizes high disk usage. Score of 1.0 means plenty of free space. |
| **Unorganized** | 0.25 | `rawScore = 1.0 - (unorganizedFiles / totalFiles)`. Penalizes high ratio of unorganized files. |
| **Rule Coverage** | 0.20 | `rawScore = ruleTriggeredOperations / totalOperations`. Rewards automation via rules. |
| **Growth Trend** | 0.15 | `rawScore` based on 7-day slope. Positive sustained growth penalized; cleanup trend rewarded. |

**Penalty calculation:**

```swift
let penalty = Int((1.0 - rawScore) * weight * 100)
```

**Example:**
- Disk 80% full: `rawScore = 0.2`, `penalty = (1 - 0.2) * 0.40 * 100 = 32`
- 10% unorganized: `rawScore = 0.9`, `penalty = (1 - 0.9) * 0.25 * 100 = 2.5 ≈ 3`
- 60% rule coverage: `rawScore = 0.6`, `penalty = (1 - 0.6) * 0.20 * 100 = 8`
- Flat growth trend: `rawScore = 0.7`, `penalty = (1 - 0.7) * 0.15 * 100 = 4.5 ≈ 5`
- **Total score:** `100 - 32 - 3 - 8 - 5 = 52` (Grade: "Needs Attention")

Implementation:

```swift
func computeHealthScore(
    currentAnalytics: StorageAnalytics,
    snapshots: [StorageSnapshot],
    usage: UsageStatistics,
    modelContext: ModelContext
) async throws -> StorageHealthScore {
    let config = FormaConfig.analytics
    var factors: [HealthFactor] = []
    var totalPenalty = 0

    // 1. Capacity factor
    let capacityRaw = 1.0 - (Double(currentAnalytics.totalBytes) / Double(totalDiskSpace))
    let capacityPenalty = Int((1.0 - capacityRaw) * config.healthWeightCapacity * 100)
    factors.append(HealthFactor(
        type: .capacity,
        description: "Disk space utilization",
        rawScore: capacityRaw,
        weight: config.healthWeightCapacity,
        impact: -capacityPenalty
    ))
    totalPenalty += capacityPenalty

    // 2. Unorganized factor
    // ... similar pattern

    // 3. Rule coverage factor
    // ... similar pattern

    // 4. Growth trend factor
    // ... similar pattern

    let score = max(0, min(100, 100 - totalPenalty))
    let recommendations = generateRecommendations(from: factors)

    return StorageHealthScore(score: score, factors: factors, recommendations: recommendations)
}
```

### 6.5 SwiftData Threading Model

SwiftData's `ModelContext` has thread affinity—it must be used on the thread/actor where it was created. Since `AnalyticsService` is not `@MainActor`, we follow these conventions:

**Convention 1: Callers provide the appropriate context.**

```swift
// From @MainActor code (ViewModels):
@MainActor
func refresh() async {
    do {
        // modelContext is from @Environment(\.modelContext) or created on MainActor
        let summary = try await analyticsService.loadAnalyticsSummary(
            for: selectedPeriod,
            modelContext: modelContext  // MainActor context
        )
        self.trendPoints = summary.trendPoints
    } catch {
        self.errorMessage = error.localizedDescription
    }
}
```

**Convention 2: For background operations, create a dedicated context.**

```swift
// For app-launch snapshot recording (can be background):
func recordSnapshotOnLaunch(container: ModelContainer) {
    Task.detached {
        let context = ModelContext(container)  // Background context
        try await AnalyticsService.shared.recordDailySnapshotIfNeeded(
            modelContext: context
        )
    }
}
```

**Convention 3: Document context expectations in API.**

```swift
/// Records a daily snapshot if one doesn't exist for today.
/// - Parameter modelContext: A ModelContext appropriate for the calling context.
///   Use MainActor context for UI-driven calls, or create a background context
///   for launch-time operations.
func recordDailySnapshotIfNeeded(
    modelContext: ModelContext,
    ...
) async throws
```

### 6.6 Performance Considerations

With 90 days of snapshots and potentially thousands of `ActivityItem` rows:

**Indexing:**
- `StorageSnapshot.date` is indexed via `#Index` (see Section 5.1).
- `ActivityItem.timestamp` should already be indexed; verify and add if missing.

**Batch Fetching:**
- Use `FetchDescriptor` with `fetchLimit` for paginated access when needed.
- For trend computation, fetch all snapshots in range (max 90) in a single query—this is acceptable.

**Lazy Aggregation:**
- `UsageStatistics` aggregates over `ActivityItem` which may have many rows.
- Use SwiftData's `#Predicate` to filter at the database level:

```swift
let descriptor = FetchDescriptor<ActivityItem>(
    predicate: #Predicate { $0.timestamp >= startDate && $0.timestamp <= endDate }
)
```

**Memory:**
- `AnalyticsSummary` is a lightweight value type; no concern for 90 trend points.
- Avoid loading full `ActivityItem` objects when only counting—use `fetchCount` where possible.

### 6.7 Integration with InsightsService

**Location:** `Forma File Organizing/Services/InsightsService.swift`

Add a dedicated method for optimization recommendations:

```swift
extension InsightsService {
    func generateOptimizationRecommendations(
        snapshots: [StorageSnapshot],
        usage: UsageStatistics,
        recentActivities: [ActivityItem]
    ) -> [OptimizationRecommendation]
}
```

Notes:
- This method can reuse existing pattern-detection helpers and learned pattern insights.
- `AnalyticsService` should call this only when `.optimizationRecommendations` is enabled.

---

## 7. ReportService & PDF Export

**Location:** `Forma File Organizing/Services/ReportService.swift`

### 7.1 Responsibilities

- Compose high-level `AnalyticsReport` objects from `AnalyticsSummary` and recommendations.
- Track last generated weekly report date.
- Store generated reports transiently (in memory) for the current session.
- Export reports to PDF using PDFKit with Forma branding.

### 7.2 Report Persistence Strategy

**Decision:** Reports are generated on-demand and held in memory. PDFs are exported to user-chosen locations.

Rationale:
- Reports are derived data—they can always be regenerated from snapshots and activity logs.
- Persisting reports adds storage overhead and migration complexity.
- Users who want to keep reports can export them as PDFs.

Implementation:
- `lastWeeklyReportDate: Date?` is stored in `UserDefaults` to track generation timing.
- `latestReport: AnalyticsReport?` is held in memory by `ReportService` and `AnalyticsViewModel`.
- On app launch, if a new week has started, regenerate the report.

### 7.3 Type & Public API

```swift
import Foundation
import SwiftData
import PDFKit

final class ReportService: Sendable {
    static let shared = ReportService()

    private static let lastReportDateKey = "forma.analytics.lastWeeklyReportDate"

    private init() {}
}

extension ReportService {
    func generateReport(
        period: ReportPeriod,
        analyticsSummary: AnalyticsSummary,
        recommendations: [OptimizationRecommendation]
    ) -> AnalyticsReport

    func exportReportAsPDF(
        _ report: AnalyticsReport,
        to url: URL
    ) throws

    func generateWeeklyReportIfNeeded(
        modelContext: ModelContext,
        now: Date = Date()
    ) async throws -> AnalyticsReport?

    /// Returns true if a new week has started since the last report.
    func shouldGenerateWeeklyReport(now: Date = Date()) -> Bool
}
```

Implementation notes:
- `generateReport`:
  - Builds sections: Storage Trends, Usage Statistics, Storage Health, Recommendations.
  - Attaches key metrics (e.g. total storage change, files organized, estimated time saved).
- `exportReportAsPDF`:
  - Uses PDFKit to create a multi-page PDF.
  - Maps `FormaTypography` to system fonts and sizes.
  - Uses `FormaColors` for titles, section headers, and accents.
  - Uses Swift Charts rendered to images for trend visualization.
- `generateWeeklyReportIfNeeded`:
  - Checks `UserDefaults` for `lastWeeklyReportDate`.
  - Uses `Calendar.current.isDate(_:equalTo:toGranularity: .weekOfYear)` to determine if in same week.
  - If last report is from a prior week and feature flags are enabled, generates a new report and updates the stored date.
  - Returns `nil` if no new report is needed.

---

## 8. View Models & UI Integration

### 8.1 AnalyticsViewModel (new)

**Location:** `Forma File Organizing/ViewModels/AnalyticsViewModel.swift`

Responsibilities:
- Drive Analytics UI state (selected period, charts, stats, reports).
- Coordinate calls to `AnalyticsService` and `ReportService`.
- Surface loading and error states to the view.

Public API sketch:

```swift
import Foundation
import SwiftData

@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published var selectedPeriod: UsagePeriod = .week

    @Published var trendPoints: [StorageTrendPoint] = []
    @Published var usageStatistics: UsageStatistics?
    @Published var healthScore: StorageHealthScore?
    @Published var latestReport: AnalyticsReport?

    @Published var hasNewReport: Bool = false  // For badge/banner display

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let analyticsService: AnalyticsService
    private let reportService: ReportService
    private let modelContext: ModelContext

    init(
        analyticsService: AnalyticsService = .shared,
        reportService: ReportService = .shared,
        modelContext: ModelContext
    ) {
        self.analyticsService = analyticsService
        self.reportService = reportService
        self.modelContext = modelContext
    }

    func onAppear()
    func refresh()
    func changePeriod(_ period: UsagePeriod)

    func loadWeeklyReport()
    func exportCurrentReport(to url: URL) throws
    func dismissNewReportBanner()
}
```

Behavior:
- `onAppear`:
  - Guards with feature flags.
  - Calls `refresh()` and `loadWeeklyReport()` asynchronously.
- `refresh`:
  - Calls `AnalyticsService.loadAnalyticsSummary` for `selectedPeriod`.
  - Updates `trendPoints`, `usageStatistics`, and `healthScore`.
- `changePeriod`:
  - Updates `selectedPeriod` and re-runs `refresh`.
- `loadWeeklyReport`:
  - Calls `ReportService.generateWeeklyReportIfNeeded`.
  - If a new report is returned, sets `hasNewReport = true`.
- `exportCurrentReport`:
  - Delegates to `ReportService.exportReportAsPDF`.
- `dismissNewReportBanner`:
  - Sets `hasNewReport = false`.

### 8.2 DashboardViewModel Extensions (existing)

**Location:** `Forma File Organizing/ViewModels/DashboardViewModel.swift`

Option A: Keep analytics-specific state in `AnalyticsViewModel` only (preferred for separation of concerns).
Option B: Mirror high-level analytics summary in `DashboardViewModel` to show a condensed view in the default panel.

Minimal additions if Option B is chosen:

```swift
@Published var dashboardAnalyticsSummary: AnalyticsSummary?

func loadDashboardAnalyticsSummary()
```

`loadDashboardAnalyticsSummary` would call into `AnalyticsService` for a fixed period (e.g. last 7 days) and update a small set of stat cards in the default right panel.

### 8.3 AnalyticsView (new)

**Location:** `Forma File Organizing/Views/AnalyticsView.swift`

High-level structure:

```swift
import SwiftUI

struct AnalyticsView: View {
    @ObservedObject var viewModel: AnalyticsViewModel

    var body: some View {
        VStack(spacing: FormaSpacing.standard) {
            // New report banner (dismissible)
            // Period picker (Day / Week / Month)
            // Summary stat cards (storage change, files organized, time saved, health score)
            // Trend charts (storage trend, category trends)
            // Usage section (rules usage, files per period)
            // Health & recommendations section
            // Reports section with latest weekly report + export button
        }
        .padding(FormaSpacing.generous)
        .onAppear { viewModel.onAppear() }
    }
}
```

Design:
- Reuse stat card patterns from `AIInsightsView`.
- Use `FormaColors` and `FormaTypography` for titles, captions, and metrics.
- Use collapsible sections similar to `StoragePanel` for Storage / Usage / Health / Reports.

### 8.4 TrendChart Component (new)

**Location:** `Forma File Organizing/Components/TrendChart.swift`

Purpose: Render storage trend lines and optionally category series over time.

**Framework Decision:** Use **Swift Charts** (available macOS 13+).

Rationale:
- Built-in accessibility support (VoiceOver, etc.).
- Automatic animations and transitions.
- Localization of axis labels and values.
- Consistent with Apple's design language.

Public API sketch:

```swift
import SwiftUI
import Charts

struct TrendChart: View {
    let points: [StorageTrendPoint]
    let highlightedDate: Date?

    @State private var selectedPoint: StorageTrendPoint?

    var body: some View {
        Chart(points) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Storage", point.totalBytes)
            )
            .foregroundStyle(FormaColors.primary)

            AreaMark(
                x: .value("Date", point.date),
                y: .value("Storage", point.totalBytes)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [FormaColors.primary.opacity(0.3), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 7))
        }
        .chartYAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let bytes = value.as(Int64.self) {
                        Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                    }
                }
            }
        }
        .chartOverlay { proxy in
            // Interactive selection overlay
        }
    }
}
```

Extensions:
- Future versions may add multi-series support for top N categories:

```swift
struct CategoryTrendSeries: Identifiable {
    let id: UUID
    let categoryName: String   // FileTypeCategory.rawValue
    let points: [StorageTrendPoint]
}
```

### 8.5 StorageChart Enhancements (existing)

**Location:** `Forma File Organizing/Components/StorageChart.swift`

Enhancements:
- Allow displaying a category breakdown for a selected historical date (from `StorageSnapshot`).
- Public helper:

```swift
func storageAnalyticsForSnapshot(_ snapshot: StorageSnapshot) -> StorageAnalytics
```

Usage:
- When the user hovers or taps a point in `TrendChart`, update the pie chart to reflect the snapshot's category breakdown.

### 8.6 Reports UI – ReportPreviewView (new)

**Location:** `Forma File Organizing/Views/ReportPreviewView.swift`

Purpose: Show a summary of the latest weekly report and provide a PDF export button.

Public API sketch:

```swift
import SwiftUI

struct ReportPreviewView: View {
    let report: AnalyticsReport
    let exportAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            // Title, date, key metrics, recommendations list, Export button
        }
    }
}
```

### 8.7 Navigation Integration

**Sidebar / Dashboard Integration**

**Location:** `Forma File Organizing/Views/DashboardView.swift`, `Views/SidebarView.swift`

- Add an "Analytics" entry to the sidebar or main dashboard tab strip, gated by feature flags:

```swift
if FeatureFlagService.shared.isEnabled(.analyticsAndInsights) {
    // Show Analytics tab/section
}
```

- When selected, display `AnalyticsView` with an `AnalyticsViewModel` instance.

**Right Panel Integration (Optional)**

**Location:** `Forma File Organizing/Views/RightPanelView.swift`

- Add a new mode to `RightPanelMode`:
  - `case analytics`
- Provide a compact analytics summary (e.g. last 7 days) in the default panel:
  - Reuse the same `AnalyticsViewModel` or a lightweight projection of `AnalyticsSummary`.

**Settings Integration**

**Location:** `Forma File Organizing/Views/Settings/SettingsView.swift`

- Under "Smart Features" or equivalent section, add toggles for:
  - `Analytics & Insights (master)`
  - `Storage Trends`
  - `Usage Statistics`
  - `Storage Health Score`
  - `Optimization Recommendations`
  - `Analytics Reports`
- Each toggle should call into `FeatureFlagService` and clearly describe the feature.

---

## 9. Scheduling & Triggers

Scheduling should be simple and aligned with app lifecycle; no background processes outside the app sandbox.

### 9.1 Daily StorageSnapshot Capture

Integration points:
- On app launch or activation:
  - `Forma_File_OrganizingApp` or the dashboard coordinator should call:

```swift
Task {
    guard FeatureFlagService.shared.isEnabled(.storageTrends) else { return }
    try await AnalyticsService.shared.recordDailySnapshotIfNeeded(
        modelContext: modelContext
    )
}
```

- Optional: A lightweight timer that, once per day while the app is open, attempts another `recordDailySnapshotIfNeeded` call, which will be a no-op if today's snapshot already exists.

### 9.2 Weekly Report Generation

On app launch:

```swift
Task {
    guard FeatureFlagService.shared.isEnabled(.analyticsReports) else { return }
    if let newReport = try await ReportService.shared.generateWeeklyReportIfNeeded(
        modelContext: modelContext
    ) {
        // Notify UI to show "New report available" banner
        await MainActor.run {
            analyticsViewModel.latestReport = newReport
            analyticsViewModel.hasNewReport = true
        }
    }
}
```

UI:
- If a new report is generated, display a subtle nudge:
  - Badge in the Analytics navigation entry.
  - Dismissible banner at the top of `AnalyticsView` indicating "New weekly report available".

### 9.3 Usage Statistics Refresh

- When the user navigates to `AnalyticsView`, call `viewModel.onAppear()` to refresh:
  - `AnalyticsSummary` (trend, usage, health score) for the selected period.
- Optionally add a manual "Refresh" button for power users.

---

## 10. Testing Strategy

### 10.1 Unit Tests

**New test files:**
- `Forma File OrganizingTests/AnalyticsServiceTests.swift`
- `Forma File OrganizingTests/ReportServiceTests.swift`
- `Forma File OrganizingTests/AnalyticsViewModelTests.swift`

Focus areas:
- `AnalyticsServiceTests`:
  - Snapshot creation behavior and idempotency for a given day.
  - Retention pruning at `retentionDays` boundary.
  - Trend computation (including missing days, flat usage, and sustained growth or shrinkage).
  - Cleanup impact metrics from synthetic snapshot sequences.
  - Usage statistics aggregation across day/week/month periods.
  - Time-saved estimation with various mixes of `ActivityItem` types.
  - Health score ranges and factor breakdowns for representative scenarios.
  - **Health score algorithm:** Verify weights sum to expected penalties.
- `ReportServiceTests`:
  - Section composition correctness for given `AnalyticsSummary` and recommendations.
  - Weekly report generation logic (only once per week).
  - `shouldGenerateWeeklyReport` boundary conditions (same week, new week, year boundary).
  - PDF export sanity (successful write and non-empty file).
- `AnalyticsViewModelTests`:
  - State updates for `onAppear`, `refresh`, and `changePeriod`.
  - Handling of feature flags (no calls when disabled).
  - Error propagation when services throw.
  - `hasNewReport` flag behavior.

**Mocking Strategy:**
- Create `MockAnalyticsService` and `MockReportService` protocols/classes for ViewModel tests.
- Use in-memory SwiftData containers (`ModelConfiguration(isStoredInMemoryOnly: true)`) for service tests.

### 10.2 Integration Tests

- Use `TemporaryDirectory` helpers from `Forma File OrganizingTests/TestHelpers/TemporaryDirectory.swift` to:
  - Simulate file operations and ensure `ActivityLoggingService` creates expected `ActivityItem` rows.
  - Verify that `AnalyticsService.fetchUsageStatistics` matches these synthetic operations.
  - Ensure that `recordDailySnapshotIfNeeded` interacts safely with `StorageService` and SwiftData.

### 10.3 UI Tests

- Add basic UI tests in `Forma File OrganizingUITests`:
  - Navigate to Analytics tab (when enabled).
  - Verify presence of key sections (Storage, Usage, Health, Reports).
  - Check that tapping "Export as PDF" presents a save panel (if applicable) and does not crash.

---

## 11. File-by-File Checklist

### 11.1 New Files

- `Forma File Organizing/Models/StorageSnapshot.swift`
  - New SwiftData `@Model` for daily storage snapshots.
- `Forma File Organizing/Models/AnalyticsModels.swift`
  - Value types: `AnalyticsError`, `UsagePeriod`, `UsageStatistics`, `StorageTrendPoint`, `CleanupImpact`,
    `HealthFactorType`, `HealthFactor`, `OptimizationRecommendation`, `StorageHealthScore`,
    `ReportPeriod`, `AnalyticsReportSection`, `AnalyticsReport`, `AnalyticsSummary`.
- `Forma File Organizing/Services/AnalyticsService.swift`
  - Singleton responsible for snapshots, trends, usage stats, and health score.
- `Forma File Organizing/Services/ReportService.swift`
  - Singleton responsible for report composition and PDF export.
- `Forma File Organizing/ViewModels/AnalyticsViewModel.swift`
  - `@MainActor` view model driving Analytics UI.
- `Forma File Organizing/Views/AnalyticsView.swift`
  - Main Analytics dashboard view with sections/tabs.
- `Forma File Organizing/Components/TrendChart.swift`
  - Reusable trend chart component using Swift Charts.
- `Forma File Organizing/Views/ReportPreviewView.swift`
  - Report preview and export UI.
- `Forma File OrganizingTests/AnalyticsServiceTests.swift`
- `Forma File OrganizingTests/ReportServiceTests.swift`
- `Forma File OrganizingTests/AnalyticsViewModelTests.swift`

### 11.2 Modified Files

- `Forma File Organizing/Models/StorageAnalytics.swift`
  - Add helpers for encoding/decoding category breakdown, initializer from `StorageSnapshot`.
- `Forma File Organizing/Services/StorageService.swift`
  - Ensure `calculateAnalytics()` remains accessible for snapshotting; add documentation where needed.
- `Forma File Organizing/Models/ActivityItem.swift`
  - Confirm activity types expose enough information for usage stats (no schema change expected).
  - Verify `#Index` on `timestamp` exists; add if missing.
- `Forma File Organizing/Services/ActivityLoggingService.swift`
  - Confirm all relevant operations are logged (no API change expected).
- `Forma File Organizing/Services/InsightsService.swift`
  - Add `generateOptimizationRecommendations` entry point used by analytics.
- `Forma File Organizing/Services/FeatureFlagService.swift`
  - Add master and child analytics flags.
- `Forma File Organizing/Configuration/FormaConfig.swift`
  - Add `AnalyticsConfig` and `FormaConfig.analytics` configuration.
- `Forma File Organizing/ViewModels/DashboardViewModel.swift`
  - Optional: add a lightweight `dashboardAnalyticsSummary` and loader for right panel summary.
- `Forma File Organizing/Views/DashboardView.swift`
  - Add navigation entry / tab for Analytics view when enabled.
- `Forma File Organizing/Views/SidebarView.swift`
  - Show "Analytics" entry under appropriate section, gated by feature flags.
- `Forma File Organizing/Views/RightPanelView.swift`
  - (Optional) Add `RightPanelMode.analytics` and compact analytics summary.
- `Forma File Organizing/Components/StorageChart.swift`
  - Support displaying category breakdown for a selected historical snapshot.
- `Forma File Organizing/Views/Settings/SettingsView.swift`
  - Add toggles under "Smart Features" for analytics feature flags.

---

## 12. Rollout Notes

- Default all analytics flags to ON for v1.2.0 to maximize discoverability.
- Allow users to disable analytics entirely via the master "Analytics & Insights" toggle.
- Keep all analytics processing local to the device; no additional permissions beyond existing file-access entitlements are required.
- Ensure undo and non-destructive behavior for all file operations remains unchanged; analytics only observe and summarize existing actions.

---

## 13. Migration Strategy

SwiftData models may evolve in future versions. To avoid "delete and recreate" scenarios for existing users, use SwiftData's versioned schema system from the start.

### 13.1 Schema Versioning Setup

**Location:** `Forma File Organizing/Models/SchemaVersions.swift`

```swift
import SwiftData

// MARK: - v1.2.0 Schema (Initial Analytics)

enum StorageSnapshotSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [StorageSnapshot.self]
    }
}

// MARK: - Migration Plan

enum StorageSnapshotMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [StorageSnapshotSchemaV1.self]
        // Future: StorageSnapshotSchemaV2.self
    }

    static var stages: [MigrationStage] {
        []  // No migrations yet; add as schema evolves
    }
}
```

### 13.2 Future Migration Example

When `StorageSnapshot` needs a new field in v1.3.0:

```swift
// 1. Define new schema version
enum StorageSnapshotSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version = Schema.Version(2, 0, 0)

    @Model
    final class StorageSnapshot {
        // ... existing fields ...
        var newField: String?  // New optional field
    }

    static var models: [any PersistentModel.Type] {
        [StorageSnapshot.self]
    }
}

// 2. Add migration stage
enum StorageSnapshotMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [StorageSnapshotSchemaV1.self, StorageSnapshotSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: StorageSnapshotSchemaV1.self,
        toVersion: StorageSnapshotSchemaV2.self
    )
}
```

### 13.3 Container Configuration

Update `ModelContainer` initialization to use the migration plan:

```swift
let container = try ModelContainer(
    for: StorageSnapshot.self, ActivityItem.self, /* ... */,
    migrationPlan: StorageSnapshotMigrationPlan.self
)
```

---

## Appendix A: Quick Reference

### Health Score Weights

| Factor | Weight | Description |
|--------|--------|-------------|
| Capacity | 0.40 | Disk space utilization |
| Unorganized | 0.25 | Ratio of unorganized files |
| Rule Coverage | 0.20 | Automation via rules |
| Growth Trend | 0.15 | 7-day storage slope |

### Time Saved Heuristics

| Operation | Seconds Saved |
|-----------|---------------|
| File Organized | 6 |
| Bulk Organize (per file) | 4 |
| Rule Applied (per file) | 8 |

### Feature Flags

| Flag | Default | Parent |
|------|---------|--------|
| `analyticsAndInsights` | ON | — |
| `storageTrends` | ON | `analyticsAndInsights` |
| `usageStats` | ON | `analyticsAndInsights` |
| `storageHealthScore` | ON | `analyticsAndInsights` |
| `optimizationRecommendations` | ON | `analyticsAndInsights` |
| `analyticsReports` | ON | `analyticsAndInsights` |
