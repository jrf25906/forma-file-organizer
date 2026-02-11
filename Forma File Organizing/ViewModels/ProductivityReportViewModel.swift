import Foundation
import SwiftData
import Combine
import SwiftUI

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
    private let navigation: NavigationViewModel
    private let dashboardViewModel: DashboardViewModel
    private var dismissedInsightIds: Set<UUID> = []
    private var refreshTask: Task<Void, Never>?
    private var reportCache: [UsagePeriod: CachedReport] = [:]

    private struct CachedReport {
        let report: ProductivityHealthReport
        let timestamp: Date
    }

    private let cacheTTL: TimeInterval = 60

    // MARK: - Derived UI State

    var hasStorageData: Bool {
        guard let storageTreemap else { return false }
        return !storageTreemap.children.isEmpty
    }

    var hasAutomationData: Bool {
        automationTimeline.contains { $0.totalActions > 0 }
    }

    var hasFreshnessData: Bool {
        stalenessCalendar.contains { $0.totalFiles > 0 }
    }

    var hasInsightData: Bool {
        !smartInsights.isEmpty
    }

    var hasAnyProductivityData: Bool {
        hasStorageData || hasAutomationData || hasFreshnessData || hasInsightData
    }

    var showsNoDataGuidance: Bool {
        !isLoading && !hasAnyProductivityData
    }

    // MARK: - Initialization

    init(
        analyticsService: AnalyticsService = .shared,
        modelContext: ModelContext,
        navigation: NavigationViewModel,
        dashboardViewModel: DashboardViewModel
    ) {
        self.analyticsService = analyticsService
        self.modelContext = modelContext
        self.navigation = navigation
        self.dashboardViewModel = dashboardViewModel
    }

    // MARK: - Lifecycle

    func onAppear() {
        guard !isLoading else { return }
        scheduleRefresh(force: productivityMetrics == nil)
    }

    // MARK: - Data Loading

    func scheduleRefresh(force: Bool = false) {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            await self.refresh(force: force)
        }
    }

    func cancelRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    private func refresh(force: Bool = false) async {
        guard FeatureFlagService.shared.isEnabled(.analyticsAndInsights) else {
            errorMessage = "Analytics is disabled."
            return
        }

        if !force,
           let cached = reportCache[selectedPeriod],
           Date().timeIntervalSince(cached.timestamp) < cacheTTL {
            applyReport(cached.report)
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Ensure we have a recent snapshot
            try await analyticsService.recordDailySnapshotIfNeeded(container: modelContext.container)
            guard !Task.isCancelled else { return }

            // Load the entire productivity report in one detached pass to avoid
            // repeated main-actor fetches of FileItem and snapshot data.
            let report = try await analyticsService.generateProductivityHealthReport(
                for: selectedPeriod,
                container: modelContext.container
            )
            guard !Task.isCancelled else { return }

            reportCache[selectedPeriod] = CachedReport(report: report, timestamp: Date())
            applyReport(report)
        } catch {
            guard !Task.isCancelled else { return }
            Log.error("ProductivityReportViewModel: Failed to refresh - \(error.localizedDescription)", category: .analytics)
            errorMessage = error.localizedDescription
        }
    }

    private func applyReport(_ report: ProductivityHealthReport) {
        productivityMetrics = report.metrics
        automationTimeline = report.automationTimeline
        storageTreemap = report.storageTreemap
        stalenessCalendar = report.stalenessCalendar
        smartInsights = report.insights.filter { !dismissedInsightIds.contains($0.id) }
        errorMessage = nil
    }

    // MARK: - User Interactions

    /// Handle tap on a treemap node - could navigate to folder or show details
    func handleTreemapNodeTap(_ node: TreemapNode) {
        Log.info("ProductivityReportViewModel: Treemap node tapped - \(node.label)", category: .analytics)

        // If a category node is tapped, navigate to that category view
        if let category = node.category {
            navigation.select(.category(category))
            dashboardViewModel.selectCategory(category)
            dashboardViewModel.setSecondaryFilter(.none)
            dashboardViewModel.reviewFilterMode = .all
            navigation.searchText = ""
            dashboardViewModel.updateSearchText("")
        }
    }

    /// Handle smart insight action button tap
    func handleInsightAction(_ insight: SmartInsight) {
        Log.info("ProductivityReportViewModel: Insight action tapped - \(insight.title)", category: .analytics)

        guard let actionType = insight.actionType else { return }

        switch actionType {
        case .archiveScreenshots:
            navigateToFolder(.pictures, searchText: "Screenshot", secondaryFilter: .none, reviewMode: .needsReview)
        case .reviewLargeFiles:
            navigateToHome(secondaryFilter: .largeFiles, reviewMode: .all)
        case .cleanDownloads:
            navigateToFolder(.downloads, searchText: nil, secondaryFilter: .none, reviewMode: .needsReview)
        case .createRule(let pattern):
            Log.info("ProductivityReportViewModel: Suggesting rule pattern - \(pattern)", category: .analytics)
            navigation.ruleEditorSuggestedText = pattern
            navigation.editingRule = nil
            navigation.ruleEditorFileContext = nil
            withAnimation(.easeInOut(duration: 0.2)) {
                navigation.isShowingRuleEditor = true
            }
        case .enableAutomation:
            Log.info("ProductivityReportViewModel: Enable automation action is handled by SettingsLink", category: .analytics)
        case .reviewFolder(let path):
            Log.info("ProductivityReportViewModel: Review folder - \(path.path)", category: .analytics)
            navigateToFolder(path)
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
        navigateToHome(secondaryFilter: .none, reviewMode: .needsReview)
    }

    func runInitialScan() {
        Task { @MainActor in
            await dashboardViewModel.scanFiles(context: modelContext)
            reportCache.removeAll()
            scheduleRefresh(force: true)
        }
    }

    func openRuleBuilder() {
        navigation.ruleEditorSuggestedText = "Move files older than 30 days to Archive"
        navigation.editingRule = nil
        navigation.ruleEditorFileContext = nil
        withAnimation(.easeInOut(duration: 0.2)) {
            navigation.isShowingRuleEditor = true
        }
    }

    func openPendingReviewQueue() {
        navigateToHome(secondaryFilter: .none, reviewMode: .needsReview)
    }

    // MARK: - Navigation Helpers

    private func navigateToHome(secondaryFilter: SecondaryFilter, reviewMode: ReviewFilterMode) {
        navigation.select(.home)
        dashboardViewModel.selectFolder(.home)
        dashboardViewModel.setSecondaryFilter(secondaryFilter)
        dashboardViewModel.reviewFilterMode = reviewMode
        navigation.searchText = ""
        dashboardViewModel.updateSearchText("")
    }

    private func navigateToFolder(
        _ folder: FolderLocation,
        searchText: String?,
        secondaryFilter: SecondaryFilter,
        reviewMode: ReviewFilterMode
    ) {
        navigation.select(navigationSelection(for: folder))
        dashboardViewModel.selectFolder(folder)
        dashboardViewModel.setSecondaryFilter(secondaryFilter)
        dashboardViewModel.reviewFilterMode = reviewMode
        let resolvedSearch = searchText ?? ""
        navigation.searchText = resolvedSearch
        dashboardViewModel.updateSearchText(resolvedSearch)
    }

    private func navigateToFolder(_ url: URL) {
        let standardizedPath = url.standardizedFileURL.path
        let folderService = BookmarkFolderService.shared

        if let matchedFolder = folderService.availableFolders.first(where: { $0.path == standardizedPath }) {
            let location = FolderLocation.from(bookmarkFolderType: matchedFolder.folderType)
            navigateToFolder(location, searchText: nil, secondaryFilter: .none, reviewMode: .needsReview)
        } else {
            navigation.select(.home)
            dashboardViewModel.selectFolder(.home)
            dashboardViewModel.setSecondaryFilter(.none)
            dashboardViewModel.reviewFilterMode = .needsReview
            navigation.searchText = url.lastPathComponent
            dashboardViewModel.updateSearchText(url.lastPathComponent)
        }
    }

    private func navigationSelection(for folder: FolderLocation) -> NavigationSelection {
        switch folder {
        case .home:
            return .home
        case .desktop:
            return .desktop
        case .downloads:
            return .downloads
        case .documents:
            return .documents
        case .pictures:
            return .pictures
        case .music:
            return .music
        }
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
