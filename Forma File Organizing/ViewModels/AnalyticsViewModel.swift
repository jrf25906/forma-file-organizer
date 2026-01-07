import Foundation
import SwiftUI
import SwiftData
import Combine

/// ViewModel for the dedicated Analytics tab/view.
/// Provides storage analytics, trends, health scores, and reports.
@MainActor
class AnalyticsViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Current loading state
    @Published private(set) var isLoading: Bool = false

    /// Error message if any operation fails
    @Published var errorMessage: String?

    /// Selected time period for analytics
    @Published var selectedPeriod: UsagePeriod = .week {
        didSet {
            Task { await refresh() }
        }
    }

    /// Whether a new report is available
    @Published private(set) var hasNewReport: Bool = false

    /// Latest storage analytics snapshot
    @Published private(set) var latestStorageAnalytics: StorageAnalytics?

    /// Storage trend data points
    @Published private(set) var trendPoints: [StorageTrendPoint] = []

    /// Usage statistics for the selected period
    @Published private(set) var usageStatistics: UsageStatistics?

    /// Storage health score
    @Published private(set) var healthScore: StorageHealthScore?

    /// Latest generated report
    @Published private(set) var latestReport: AnalyticsReport?

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let analyticsService: AnalyticsService
    private let storageService: StorageService
    private let reportService: ReportService

    // MARK: - Initialization

    init(
        modelContext: ModelContext,
        analyticsService: AnalyticsService = .shared,
        storageService: StorageService = .shared,
        reportService: ReportService = .shared
    ) {
        self.modelContext = modelContext
        self.analyticsService = analyticsService
        self.storageService = storageService
        self.reportService = reportService
    }

    // MARK: - Public Interface

    /// Called when the view appears
    func onAppear() {
        Task {
            await refresh()
        }
    }

    /// Refresh all analytics data
    func refresh() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            // Calculate date range based on selected period
            let dateRange = dateInterval(for: selectedPeriod)

            // Fetch latest storage analytics from files
            let files = try modelContext.fetch(FetchDescriptor<FileItem>())
            latestStorageAnalytics = storageService.calculateAnalytics(from: files)

            // Fetch storage trend points
            trendPoints = try await analyticsService.computeStorageTrend(
                in: dateRange,
                modelContext: modelContext
            )

            // Calculate usage statistics
            usageStatistics = try await computeUsageStatistics(in: dateRange)

            // Calculate health score
            healthScore = try await computeHealthScore()

            // Check for new reports
            latestReport = try await fetchLatestReport()
            hasNewReport = latestReport != nil && isReportNew(latestReport)

        } catch {
            Log.error("Failed to refresh analytics: \(error.localizedDescription)", category: .analytics)
            errorMessage = error.localizedDescription
        }
    }

    /// Dismiss the new report banner
    func dismissNewReportBanner() {
        hasNewReport = false
    }

    /// Export the current report to a file
    func exportCurrentReport(to url: URL) throws {
        guard let report = latestReport else {
            throw AnalyticsError.reportGenerationFailed(reason: "No report available to export")
        }

        try reportService.exportReportAsPDF(report, to: url)
    }

    // MARK: - Private Helpers

    private func dateInterval(for period: UsagePeriod) -> DateInterval {
        let now = Date()
        let calendar = Calendar.current

        switch period {
        case .day:
            let start = calendar.startOfDay(for: now)
            return DateInterval(start: start, end: now)

        case .week:
            let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return DateInterval(start: start, end: now)

        case .month:
            let start = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            return DateInterval(start: start, end: now)

        case .custom(let interval):
            return interval
        }
    }

    private func computeUsageStatistics(in range: DateInterval) async throws -> UsageStatistics? {
        // Fetch activities in the date range
        let descriptor = FetchDescriptor<ActivityItem>(
            predicate: #Predicate<ActivityItem> { activity in
                activity.timestamp >= range.start && activity.timestamp <= range.end
            }
        )

        let activities = try modelContext.fetch(descriptor)

        guard !activities.isEmpty else { return nil }

        // Count organized files
        let organizedCount = activities.filter { $0.activityType == .fileOrganized }.count

        // Count bulk operations
        let bulkCount = activities.filter { $0.activityType == .bulkOrganized }.count

        // Count rules applied
        var rulesApplied: [UUID: Int] = [:]
        for activity in activities where activity.activityType == .ruleApplied {
            if let ruleId = activity.ruleID {
                rulesApplied[ruleId, default: 0] += 1
            }
        }

        // Estimate time saved (assume 5 seconds per file)
        let timeSaved = organizedCount * 5

        // Calculate average files per day
        let days = max(1, Calendar.current.dateComponents([.day], from: range.start, to: range.end).day ?? 1)
        let avgPerDay = Double(organizedCount) / Double(days)

        return UsageStatistics(
            period: selectedPeriod,
            startDate: range.start,
            endDate: range.end,
            filesOrganized: organizedCount,
            bulkOperations: bulkCount,
            rulesAppliedByRuleID: rulesApplied,
            timeSavedSeconds: timeSaved,
            averageFilesPerDay: avgPerDay
        )
    }

    private func computeHealthScore() async throws -> StorageHealthScore? {
        guard let analytics = latestStorageAnalytics else { return nil }

        var factors: [HealthFactor] = []
        var totalWeightedScore: Double = 0
        var totalWeight: Double = 0

        // Capacity factor (higher free space = better)
        let capacityScore = min(1.0, Double(analytics.fileCount) / 1000.0)
        let capacityFactor = HealthFactor(
            type: .capacity,
            description: "Storage utilization",
            rawScore: 1.0 - capacityScore,
            weight: 0.25,
            impact: Int((1.0 - capacityScore) * 100)
        )
        factors.append(capacityFactor)
        totalWeightedScore += capacityFactor.rawScore * capacityFactor.weight
        totalWeight += capacityFactor.weight

        // Unorganized factor (fewer pending = better)
        let files = try modelContext.fetch(FetchDescriptor<FileItem>())
        let pendingCount = files.filter { $0.status == .pending || $0.status == .ready }.count
        let totalCount = max(1, files.count)
        let organizedRatio = 1.0 - (Double(pendingCount) / Double(totalCount))
        let unorganizedFactor = HealthFactor(
            type: .unorganized,
            description: "Organization level",
            rawScore: organizedRatio,
            weight: 0.35,
            impact: Int(organizedRatio * 100)
        )
        factors.append(unorganizedFactor)
        totalWeightedScore += unorganizedFactor.rawScore * unorganizedFactor.weight
        totalWeight += unorganizedFactor.weight

        // Rule coverage factor
        let rules = try modelContext.fetch(FetchDescriptor<Rule>())
        let enabledRules = rules.filter { $0.isEnabled }.count
        let ruleScore = min(1.0, Double(enabledRules) / 10.0)
        let ruleFactor = HealthFactor(
            type: .ruleCoverage,
            description: "Rule coverage",
            rawScore: ruleScore,
            weight: 0.2,
            impact: Int(ruleScore * 100)
        )
        factors.append(ruleFactor)
        totalWeightedScore += ruleFactor.rawScore * ruleFactor.weight
        totalWeight += ruleFactor.weight

        // Growth trend factor (stable or decreasing = better)
        let growthScore = trendPoints.isEmpty ? 0.5 : computeGrowthScore()
        let growthFactor = HealthFactor(
            type: .growthTrend,
            description: "Growth trend",
            rawScore: growthScore,
            weight: 0.2,
            impact: Int(growthScore * 100)
        )
        factors.append(growthFactor)
        totalWeightedScore += growthFactor.rawScore * growthFactor.weight
        totalWeight += growthFactor.weight

        let finalScore = Int((totalWeightedScore / totalWeight) * 100)

        return StorageHealthScore(
            score: finalScore,
            factors: factors,
            recommendations: generateRecommendations(from: factors)
        )
    }

    private func computeGrowthScore() -> Double {
        guard trendPoints.count >= 2 else { return 0.5 }

        let recentPoints = trendPoints.suffix(7)
        var netGrowth: Int64 = 0

        for point in recentPoints {
            netGrowth += point.deltaBytes
        }

        // Negative growth (shrinking) is good, positive (growing) is bad
        if netGrowth <= 0 {
            return 1.0
        } else {
            // Scale: 100MB growth = 0.5 score, 1GB+ growth = 0 score
            let growthMB = Double(netGrowth) / (1024 * 1024)
            return max(0, 1.0 - (growthMB / 1024))
        }
    }

    private func generateRecommendations(from factors: [HealthFactor]) -> [OptimizationRecommendation] {
        var recommendations: [OptimizationRecommendation] = []

        for factor in factors where factor.rawScore < 0.6 {
            let recommendation = OptimizationRecommendation(
                id: UUID(),
                title: "Improve \(factor.type.rawValue.capitalized)",
                detail: factor.description,
                priority: factor.rawScore < 0.3 ? 1 : 2
            )
            recommendations.append(recommendation)
        }

        return recommendations.sorted { $0.priority < $1.priority }
    }

    private func fetchLatestReport() async throws -> AnalyticsReport? {
        // Attempt to generate or fetch the latest report
        guard latestStorageAnalytics != nil,
              let usage = usageStatistics,
              let health = healthScore else {
            return nil
        }

        return AnalyticsReport(
            id: UUID(),
            generatedAt: Date(),
            period: .weekly,
            storageTrendPoints: trendPoints,
            usageStatistics: usage,
            healthScore: health,
            recommendations: health.recommendations,
            sections: []
        )
    }

    private func isReportNew(_ report: AnalyticsReport?) -> Bool {
        guard let report = report else { return false }

        // Consider report new if generated within the last 24 hours
        let oneDayAgo = Date().addingTimeInterval(-86400)
        return report.generatedAt > oneDayAgo
    }
}
