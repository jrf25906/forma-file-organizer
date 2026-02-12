import Foundation
import SwiftData
import Combine

@MainActor
final class DashboardScanRefreshController: ObservableObject {
    struct Actions {
        let onScanErrorSummary: @MainActor (String) -> Void
        let onAutomationSummary: @MainActor (String?) -> Void
        let resetOrganizationProgress: @MainActor ([FileItem]) -> Void
        let currentSearchText: @MainActor () -> String
        let triggerContentSearch: @MainActor (String) -> Void
        let refreshAvailableFolders: @MainActor () -> Void
    }

    @Published private(set) var phaseStatusText: String?

    private let scanViewModel: FileScanViewModel
    private let analyticsViewModel: AnalyticsDashboardViewModel
    private let insightsService: InsightsService

    private var hasRunPerformanceSignpostHarness = false

    init(
        scanViewModel: FileScanViewModel,
        analyticsViewModel: AnalyticsDashboardViewModel,
        insightsService: InsightsService
    ) {
        self.scanViewModel = scanViewModel
        self.analyticsViewModel = analyticsViewModel
        self.insightsService = insightsService
    }

    func scanFiles(
        context: ModelContext,
        rules: [Rule],
        actions: Actions
    ) async {
        phaseStatusText = "Preparing scan..."
        let refreshId = PerformanceMonitor.shared.begin(
            .dashboardScanRefresh,
            metadata: "manual scan"
        )
        defer {
            phaseStatusText = nil
            PerformanceMonitor.shared.end(
                .dashboardScanRefresh,
                id: refreshId,
                metadata: "\(scanViewModel.allFiles.count) files, \(analyticsViewModel.detectedClusters.count) clusters"
            )
        }

        phaseStatusText = "Scanning folders..."
        await scanViewModel.scanFiles(context: context, rules: rules)
        if let summary = scanViewModel.errorMessage {
            actions.onScanErrorSummary(summary)
        }

        actions.resetOrganizationProgress(scanViewModel.allFiles)
        await refreshClustersAndPublish(
            context: context,
            clusterMetadata: "manual scan",
            publishMetadata: "manual scan",
            actions: actions
        )
    }

    func applyAutomationScanUpdate(
        scannedPaths: [String],
        errorSummary: String?,
        context: ModelContext,
        actions: Actions
    ) async {
        phaseStatusText = "Applying automation updates..."
        let refreshId = PerformanceMonitor.shared.begin(
            .dashboardScanRefresh,
            metadata: "automation update (\(scannedPaths.count) paths)"
        )
        defer {
            phaseStatusText = nil
            PerformanceMonitor.shared.end(
                .dashboardScanRefresh,
                id: refreshId,
                metadata: "\(scanViewModel.allFiles.count) files, \(analyticsViewModel.detectedClusters.count) clusters"
            )
        }

        let files: [FileItem]
        do {
            files = try fetchAutomationFiles(scannedPaths: scannedPaths, context: context)
        } catch {
            Log.error(
                "DashboardViewModel: Failed to fetch automation scan files - \(error.localizedDescription)",
                category: .pipeline
            )
            actions.onScanErrorSummary("Failed to refresh scanned files.")
            return
        }

        scanViewModel.replaceScannedFiles(files)
        actions.onAutomationSummary(errorSummary)
        actions.resetOrganizationProgress(scanViewModel.allFiles)

        await refreshClustersAndPublish(
            context: context,
            clusterMetadata: "automation update",
            publishMetadata: "automation update",
            actions: actions
        )
    }

    func runPerformanceSignpostHarness(
        iterations: Int,
        warmupIterations: Int = 3,
        context: ModelContext,
        recentActivitiesProvider: @MainActor () -> [ActivityItem],
        actions: Actions
    ) async {
        #if DEBUG
        guard !hasRunPerformanceSignpostHarness else { return }
        let boundedSampleIterations = max(1, iterations)
        let boundedWarmupIterations = max(0, warmupIterations)
        let totalIterations = boundedWarmupIterations + boundedSampleIterations
        let scannedPaths = scanViewModel.allFiles.map(\.path)
        guard !scannedPaths.isEmpty else { return }
        hasRunPerformanceSignpostHarness = true

        for iteration in 1...totalIterations {
            let isWarmupIteration = iteration <= boundedWarmupIterations
            let phaseLabel = isWarmupIteration ? "warmup" : "sample"
            let phaseIteration = isWarmupIteration ? iteration : iteration - boundedWarmupIterations
            let metadata = "harness \(phaseLabel) \(phaseIteration)"

            let dashboardRefreshId = PerformanceMonitor.shared.begin(
                .dashboardScanRefresh,
                metadata: metadata
            )
            await applyAutomationScanUpdate(
                scannedPaths: scannedPaths,
                errorSummary: nil,
                context: context,
                actions: actions
            )
            PerformanceMonitor.shared.end(
                .dashboardScanRefresh,
                id: dashboardRefreshId,
                metadata: "\(scanViewModel.allFiles.count) files, \(analyticsViewModel.detectedClusters.count) clusters"
            )

            let insightRefreshId = PerformanceMonitor.shared.begin(
                .defaultPanelInsightRefresh,
                metadata: metadata
            )
            let insights = await insightsService.generateInsights(
                from: scanViewModel.allFiles,
                activities: recentActivitiesProvider(),
                rules: [],
                precomputedClusters: analyticsViewModel.detectedClusters
            )
            PerformanceMonitor.shared.end(
                .defaultPanelInsightRefresh,
                id: insightRefreshId,
                metadata: "\(insights.count) insights"
            )

            if iteration < totalIterations {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }
        #else
        _ = iterations
        _ = warmupIterations
        _ = context
        _ = recentActivitiesProvider
        _ = actions
        #endif
    }

    private func fetchAutomationFiles(
        scannedPaths: [String],
        context: ModelContext
    ) throws -> [FileItem] {
        let pathSet = Set(scannedPaths)
        let descriptor = FetchDescriptor<FileItem>(
            predicate: #Predicate<FileItem> { file in
                pathSet.contains(file.path)
            }
        )
        return try context.fetch(descriptor)
    }

    private func refreshClustersAndPublish(
        context: ModelContext,
        clusterMetadata: String,
        publishMetadata: String,
        actions: Actions
    ) async {
        let clusterRefreshId = PerformanceMonitor.shared.begin(
            .dashboardClusterRefresh,
            metadata: clusterMetadata
        )
        phaseStatusText = "Analyzing clusters..."
        await analyticsViewModel.detectClusters(from: scanViewModel.allFiles, context: context)
        PerformanceMonitor.shared.end(
            .dashboardClusterRefresh,
            id: clusterRefreshId,
            metadata: "\(analyticsViewModel.detectedClusters.count) clusters"
        )

        let publishId = PerformanceMonitor.shared.begin(
            .dashboardPublish,
            metadata: publishMetadata
        )
        phaseStatusText = "Updating dashboard..."
        if !actions.currentSearchText().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            actions.triggerContentSearch(actions.currentSearchText())
        }
        actions.refreshAvailableFolders()
        PerformanceMonitor.shared.end(
            .dashboardPublish,
            id: publishId,
            metadata: "\(scanViewModel.allFiles.count) files"
        )
    }
}
