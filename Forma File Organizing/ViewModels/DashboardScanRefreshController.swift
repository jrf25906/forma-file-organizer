import Foundation
import SwiftData
import Combine

@MainActor
final class DashboardScanRefreshController: ObservableObject {
    private struct HarnessEventRecord: Encodable {
        let event: String
        let kind: String
        let index: Int
        let startedAtNs: UInt64
        let durationMs: Double
    }

    struct Actions {
        let onScanErrorSummary: @MainActor (String) -> Void
        let onAutomationSummary: @MainActor (String?) -> Void
        let resetOrganizationProgress: @MainActor ([FileItem]) -> Void
        let currentSearchText: @MainActor () -> String
        let triggerContentSearch: @MainActor (String) -> Void
        let refreshAvailableFolders: @MainActor () -> Void

        init(
            onScanErrorSummary: @escaping @MainActor (String) -> Void,
            onAutomationSummary: @escaping @MainActor (String?) -> Void,
            resetOrganizationProgress: @escaping @MainActor ([FileItem]) -> Void,
            currentSearchText: @escaping @MainActor () -> String,
            triggerContentSearch: @escaping @MainActor (String) -> Void,
            refreshAvailableFolders: @escaping @MainActor () -> Void,
            prepareForIncrementalFileUpdate: @escaping @MainActor () -> Void = {}
        ) {
            self.onScanErrorSummary = onScanErrorSummary
            self.onAutomationSummary = onAutomationSummary
            self.resetOrganizationProgress = resetOrganizationProgress
            self.currentSearchText = currentSearchText
            self.triggerContentSearch = triggerContentSearch
            self.refreshAvailableFolders = refreshAvailableFolders
            self.prepareForIncrementalFileUpdate = prepareForIncrementalFileUpdate
        }

        let prepareForIncrementalFileUpdate: @MainActor () -> Void
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
        scannedPaths: [String] = [],
        scannedRootPaths: [String],
        errorSummary: String?,
        replacesAllFiles: Bool,
        context: ModelContext,
        actions: Actions
    ) async {
        phaseStatusText = "Applying automation updates..."
        let refreshId = PerformanceMonitor.shared.begin(
            .dashboardScanRefresh,
            metadata: "automation update (\(scannedRootPaths.count) roots)"
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
            files = try fetchAutomationFilesForRootRefresh(
                scannedPaths: scannedPaths,
                scannedRootPaths: scannedRootPaths,
                context: context
            )
        } catch {
            Log.error(
                "DashboardViewModel: Failed to fetch automation scan files - \(error.localizedDescription)",
                category: .pipeline
            )
            actions.onScanErrorSummary("Failed to refresh scanned files.")
            return
        }

        if replacesAllFiles {
            scanViewModel.replaceScannedFiles(files)
        } else {
            scanViewModel.mergeScannedFiles(
                files,
                scannedPaths: scannedPaths,
                forScannedRootPaths: scannedRootPaths
            )
        }
        actions.onAutomationSummary(errorSummary)
        actions.resetOrganizationProgress(scanViewModel.allFiles)

        await refreshClustersAndPublish(
            context: context,
            clusterMetadata: "automation update",
            publishMetadata: "automation update",
            actions: actions
        )
    }

    func applyAutomationScanUpdate(
        updatedPaths: [String],
        removedPaths: [String],
        scannedRootPaths: [String],
        errorSummary: String?,
        replacesAllFiles: Bool,
        requiresClusterRefresh: Bool,
        context: ModelContext,
        actions: Actions
    ) async {
        guard !requiresClusterRefresh, !replacesAllFiles else {
            await applyAutomationScanUpdate(
                scannedPaths: updatedPaths,
                scannedRootPaths: scannedRootPaths,
                errorSummary: errorSummary,
                replacesAllFiles: replacesAllFiles,
                context: context,
                actions: actions
            )
            return
        }

        phaseStatusText = "Applying automation updates..."
        let refreshId = PerformanceMonitor.shared.begin(
            .dashboardScanRefresh,
            metadata: "automation delta (\(scannedRootPaths.count) roots)"
        )
        defer {
            phaseStatusText = nil
            PerformanceMonitor.shared.end(
                .dashboardScanRefresh,
                id: refreshId,
                metadata: "\(scanViewModel.allFiles.count) files, \(analyticsViewModel.detectedClusters.count) clusters"
            )
        }

        let updatedFiles: [FileItem]
        do {
            updatedFiles = try fetchFilesForUpdatedPaths(updatedPaths, context: context)
        } catch {
            Log.error(
                "DashboardViewModel: Failed to fetch automation delta files - \(error.localizedDescription)",
                category: .pipeline
            )
            actions.onScanErrorSummary("Failed to refresh scanned files.")
            return
        }

        actions.prepareForIncrementalFileUpdate()
        scanViewModel.applyIncrementalAutomationUpdate(
            updatedFiles: updatedFiles,
            removedPaths: removedPaths
        )
        actions.onAutomationSummary(errorSummary)
        actions.resetOrganizationProgress(scanViewModel.allFiles)

        await publishDashboardRefresh(
            metadata: "automation delta",
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
        let scannedRootPaths = Array(
            Set(scanViewModel.allFiles.compactMap { normalizedScanRoot(for: $0) })
        ).sorted()
        guard !scannedRootPaths.isEmpty else { return }
        hasRunPerformanceSignpostHarness = true

        for iteration in 1...totalIterations {
            let isWarmupIteration = iteration <= boundedWarmupIterations
            let phaseLabel = isWarmupIteration ? "warmup" : "sample"
            let phaseIteration = isWarmupIteration ? iteration : iteration - boundedWarmupIterations
            let metadata = "harness \(phaseLabel) \(phaseIteration)"

            let dashboardStartNs = DispatchTime.now().uptimeNanoseconds
            let dashboardRefreshId = PerformanceMonitor.shared.begin(
                .dashboardScanRefresh,
                metadata: metadata
            )
            await applyAutomationScanUpdate(
                scannedRootPaths: scannedRootPaths,
                errorSummary: nil,
                replacesAllFiles: false,
                context: context,
                actions: actions
            )
            PerformanceMonitor.shared.end(
                .dashboardScanRefresh,
                id: dashboardRefreshId,
                metadata: "\(scanViewModel.allFiles.count) files, \(analyticsViewModel.detectedClusters.count) clusters"
            )
            recordHarnessEventIfNeeded(
                event: PerformanceMonitor.Operation.dashboardScanRefresh.rawValue,
                kind: phaseLabel,
                index: phaseIteration,
                startedAtNs: dashboardStartNs,
                durationMs: durationMs(since: dashboardStartNs)
            )

            let insightStartNs = DispatchTime.now().uptimeNanoseconds
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
            recordHarnessEventIfNeeded(
                event: PerformanceMonitor.Operation.defaultPanelInsightRefresh.rawValue,
                kind: phaseLabel,
                index: phaseIteration,
                startedAtNs: insightStartNs,
                durationMs: durationMs(since: insightStartNs)
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

    private func fetchAutomationFilesForRootRefresh(
        scannedPaths: [String],
        scannedRootPaths: [String],
        context: ModelContext
    ) throws -> [FileItem] {
        let pathSet = Set(scannedPaths.map { URL(fileURLWithPath: $0).standardizedFileURL.path })
        let rootSet = Set(scannedRootPaths.map { URL(fileURLWithPath: $0).standardizedFileURL.path })
        guard !pathSet.isEmpty || !rootSet.isEmpty else { return [] }
        let descriptor = FetchDescriptor<FileItem>()
        return try context.fetch(descriptor).filter { file in
            let standardizedPath = URL(fileURLWithPath: file.path).standardizedFileURL.path
            if pathSet.contains(standardizedPath) {
                return true
            }

            guard let root = normalizedScanRoot(for: file) else { return false }
            return rootSet.contains(root)
        }
    }

    private func fetchFilesForUpdatedPaths(
        _ updatedPaths: [String],
        context: ModelContext
    ) throws -> [FileItem] {
        let pathSet = Set(updatedPaths.map { URL(fileURLWithPath: $0).standardizedFileURL.path })
        guard !pathSet.isEmpty else { return [] }

        return try context.fetch(FetchDescriptor<FileItem>()).filter { file in
            pathSet.contains(URL(fileURLWithPath: file.path).standardizedFileURL.path)
        }
    }

    private func normalizedScanRoot(for file: FileItem) -> String? {
        if let scanRootPath = file.scanRootPath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !scanRootPath.isEmpty {
            return URL(fileURLWithPath: scanRootPath).standardizedFileURL.path
        }

        let parentPath = URL(fileURLWithPath: file.path).standardizedFileURL.deletingLastPathComponent().path
        return parentPath.isEmpty ? nil : parentPath
    }

    private func durationMs(since startNs: UInt64) -> Double {
        Double(DispatchTime.now().uptimeNanoseconds - startNs) / 1_000_000
    }

    private func recordHarnessEventIfNeeded(
        event: String,
        kind: String,
        index: Int,
        startedAtNs: UInt64,
        durationMs: Double
    ) {
        guard let rawPath = PerformanceHarnessConfiguration.eventsFilePath,
              !rawPath.isEmpty else {
            return
        }

        let url = URL(fileURLWithPath: rawPath)
        let record = HarnessEventRecord(
            event: event,
            kind: kind,
            index: index,
            startedAtNs: startedAtNs,
            durationMs: durationMs
        )

        do {
            let data = try JSONEncoder().encode(record)
            var line = data
            line.append(0x0A)

            if FileManager.default.fileExists(atPath: url.path) {
                let handle = try FileHandle(forWritingTo: url)
                try handle.seekToEnd()
                try handle.write(contentsOf: line)
                try handle.close()
            } else {
                try line.write(to: url, options: .atomic)
            }
        } catch {}
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

        await publishDashboardRefresh(
            metadata: publishMetadata,
            actions: actions
        )
    }

    private func publishDashboardRefresh(
        metadata: String,
        actions: Actions
    ) async {
        let publishId = PerformanceMonitor.shared.begin(
            .dashboardPublish,
            metadata: metadata
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
