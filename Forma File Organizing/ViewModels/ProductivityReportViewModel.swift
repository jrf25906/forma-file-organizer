import Foundation
import SwiftData
import Combine

/// ViewModel for the Productivity Health Report view.
/// Coordinates loading of all productivity metrics and handles user interactions.
@MainActor
final class ProductivityReportViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var selectedPeriod: UsagePeriod = .week

    /// The "Big Three" impact metrics
    @Published var productivityMetrics: ProductivityMetrics?

    /// Timeline data for the automation efficiency stacked area chart
    @Published var automationTimeline: [AutomationEfficiencyPoint] = []

    /// Storage treemap data
    @Published var storageTreemap: TreemapNode?

    /// 365-day staleness calendar data
    @Published var stalenessCalendar: [DayStaleness] = []

    /// Smart actionable insights
    @Published var smartInsights: [SmartInsight] = []

    /// UI State
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let analyticsService: AnalyticsService
    private let modelContext: ModelContext
    private var dismissedInsightIds: Set<UUID> = []

    // MARK: - Initialization

    init(
        analyticsService: AnalyticsService = .shared,
        modelContext: ModelContext
    ) {
        self.analyticsService = analyticsService
        self.modelContext = modelContext
    }

    // MARK: - Lifecycle

    func onAppear() {
        Task { await refresh() }
    }

    // MARK: - Data Loading

    func refresh() async {
        guard FeatureFlagService.shared.isEnabled(.analyticsAndInsights) else {
            errorMessage = "Analytics is disabled."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Ensure we have a recent snapshot
            try await analyticsService.recordDailySnapshotIfNeeded(container: modelContext.container)

            // Load all data concurrently using structured concurrency
            async let metricsTask = loadProductivityMetrics()
            async let timelineTask = loadAutomationTimeline()
            async let treemapTask = loadStorageTreemap()
            async let calendarTask = loadStalenessCalendar()

            // Await all tasks
            productivityMetrics = try await metricsTask
            automationTimeline = try await timelineTask
            storageTreemap = try await treemapTask
            stalenessCalendar = await calendarTask

            // Generate smart insights based on all the loaded data
            await loadSmartInsights()

            errorMessage = nil
        } catch {
            Log.error("ProductivityReportViewModel: Failed to refresh - \(error.localizedDescription)", category: .analytics)
            errorMessage = error.localizedDescription
        }
    }

    private func loadProductivityMetrics() async throws -> ProductivityMetrics {
        try await analyticsService.computeProductivityMetrics(
            for: selectedPeriod,
            container: modelContext.container
        )
    }

    private func loadAutomationTimeline() async throws -> [AutomationEfficiencyPoint] {
        try await analyticsService.computeAutomationEfficiencyTimeline(
            for: selectedPeriod,
            container: modelContext.container
        )
    }

    private func loadStorageTreemap() async throws -> TreemapNode? {
        // Fetch latest storage analytics
        guard let analytics = try fetchLatestStorageAnalytics() else {
            return nil
        }

        // Fetch files for large file detection
        let files = try fetchAllFiles()

        return analyticsService.buildStorageTreemap(
            from: analytics,
            files: files,
            largeFileThreshold: 500_000_000 // 500 MB
        )
    }

    private func loadStalenessCalendar() async -> [DayStaleness] {
        do {
            let files = try fetchAllFiles()
            return analyticsService.computeStalenessCalendar(files: files)
        } catch {
            Log.warning("ProductivityReportViewModel: Failed to load staleness calendar - \(error.localizedDescription)", category: .analytics)
            return []
        }
    }

    private func loadSmartInsights() async {
        do {
            let files = try fetchAllFiles()
            guard let analytics = try fetchLatestStorageAnalytics() else {
                smartInsights = []
                return
            }

            let allInsights = try await analyticsService.generateSmartInsights(
                files: files,
                analytics: analytics,
                automationTimeline: automationTimeline,
                stalenessCalendar: stalenessCalendar,
                modelContext: modelContext
            )

            // Filter out dismissed insights
            smartInsights = allInsights.filter { !dismissedInsightIds.contains($0.id) }
        } catch {
            Log.warning("ProductivityReportViewModel: Failed to generate smart insights - \(error.localizedDescription)", category: .analytics)
            smartInsights = []
        }
    }

    // MARK: - Data Fetching Helpers

    private func fetchLatestStorageAnalytics() throws -> StorageAnalytics? {
        var descriptor = FetchDescriptor<StorageSnapshot>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        guard let snapshot = try modelContext.fetch(descriptor).first else {
            return nil
        }

        let breakdown = try StorageCategoryBreakdown(from: snapshot.categoryBreakdownData)
        return StorageAnalytics(snapshot: snapshot, categoryBreakdown: breakdown)
    }

    private func fetchAllFiles() throws -> [FileItem] {
        let descriptor = FetchDescriptor<FileItem>()
        return try modelContext.fetch(descriptor)
    }

    // MARK: - User Interactions

    /// Handle tap on a treemap node - could navigate to folder or show details
    func handleTreemapNodeTap(_ node: TreemapNode) {
        Log.info("ProductivityReportViewModel: Treemap node tapped - \(node.label)", category: .analytics)
        // TODO: Navigate to folder or show file details
    }

    /// Handle smart insight action button tap
    func handleInsightAction(_ insight: SmartInsight) {
        Log.info("ProductivityReportViewModel: Insight action tapped - \(insight.title)", category: .analytics)

        guard let actionType = insight.actionType else { return }

        switch actionType {
        case .archiveScreenshots:
            // TODO: Navigate to screenshot management or trigger archive
            break
        case .reviewLargeFiles:
            // TODO: Navigate to large files view
            break
        case .cleanDownloads:
            // TODO: Navigate to Downloads folder review
            break
        case .createRule(let pattern):
            // TODO: Open rule editor with suggested pattern
            Log.info("ProductivityReportViewModel: Suggesting rule pattern - \(pattern)", category: .analytics)
        case .enableAutomation:
            // TODO: Navigate to automation settings
            break
        case .reviewFolder(let path):
            // TODO: Navigate to specific folder
            Log.info("ProductivityReportViewModel: Review folder - \(path.path)", category: .analytics)
        }
    }

    /// Dismiss an insight (hide it from the list)
    func dismissInsight(_ insight: SmartInsight) {
        dismissedInsightIds.insert(insight.id)
        smartInsights.removeAll { $0.id == insight.id }
    }

    /// Handle the "nudge cleanup" button on the staleness heatmap
    func nudgeCleanup() {
        Log.info("ProductivityReportViewModel: Nudge cleanup tapped", category: .analytics)
        // TODO: Navigate to cleanup view or show stale files
    }
}

// MARK: - Preview Support

#if DEBUG
extension ProductivityReportViewModel {
    /// Create a preview instance with sample data
    static func preview() -> ProductivityReportViewModel {
        // This would need a proper ModelContext for preview
        fatalError("Preview requires ModelContext - use SwiftUI Preview with @Previewable")
    }
}
#endif
