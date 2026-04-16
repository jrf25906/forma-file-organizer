import Foundation
import SwiftData

/// Concrete implementation of `FileScanProvider` that bridges
/// the `AutomationEngine` to the existing scan infrastructure.
///
/// This provider wraps `FileScanPipeline` and `DashboardViewModel`'s
/// scanning logic to provide a clean interface for automation.
@MainActor
final class DashboardFileScanProvider: FileScanProvider {
    // MARK: - Dependencies

    private let pipeline: FileScanPipelineProtocol
    private let fileSystemService: FileSystemServiceProtocol
    private let ruleEngine: RuleEngine

    // MARK: - Initialization

    @MainActor
    init(
        pipeline: FileScanPipelineProtocol,
        fileSystemService: FileSystemServiceProtocol,
        ruleEngine: RuleEngine
    ) {
        self.pipeline = pipeline
        self.fileSystemService = fileSystemService
        self.ruleEngine = ruleEngine
    }

    @MainActor
    convenience init() {
        self.init(
            pipeline: FileScanPipeline(),
            fileSystemService: FileSystemService(),
            ruleEngine: RuleEngine()
        )
    }

    // MARK: - FileScanProvider

    func scanFiles(context: ModelContext, request: AutomationScanRequest) async throws -> FileScanResult {
        Log.info("DashboardFileScanProvider: Starting scan", category: .automation)

        // Fetch current rules
        let rules = try fetchRules(context: context)
        switch request {
        case .full:
            let result = await runRootScan(
                baseFolders: BookmarkFolderService.shared.enabledFolderLocations,
                context: context,
                rules: rules
            )
            if result.timedOut {
                throw ScanError.timeout
            }
            if let errorSummary = result.errorSummary, !result.rawErrors.isEmpty {
                Log.warning("DashboardFileScanProvider: Scan completed with errors - \(errorSummary)", category: .automation)
            }
            let metrics = computeAggregateMetrics(
                totalScanned: result.files.count,
                context: context,
                errorSummary: result.errorSummary,
                rawErrors: result.rawErrors,
                scannedRootPaths: result.scannedRootPaths
            )
            postDashboardUpdate(
                updatedPaths: result.files.map(\.path),
                removedPaths: [],
                scannedRootPaths: result.scannedRootPaths,
                replacesAllFiles: true,
                requiresClusterRefresh: true,
                errorSummary: result.errorSummary
            )
            Log.info("DashboardFileScanProvider: Scan complete - \(result.files.count) touched files, \(metrics.pendingCount) pending", category: .automation)
            return metrics
        case .roots(let baseFolders):
            let result = await runRootScan(
                baseFolders: baseFolders,
                context: context,
                rules: rules
            )
            if result.timedOut {
                throw ScanError.timeout
            }
            if let errorSummary = result.errorSummary, !result.rawErrors.isEmpty {
                Log.warning("DashboardFileScanProvider: Scan completed with errors - \(errorSummary)", category: .automation)
            }
            let metrics = computeAggregateMetrics(
                totalScanned: result.files.count,
                context: context,
                errorSummary: result.errorSummary,
                rawErrors: result.rawErrors,
                scannedRootPaths: result.scannedRootPaths
            )
            postDashboardUpdate(
                updatedPaths: result.files.map(\.path),
                removedPaths: [],
                scannedRootPaths: result.scannedRootPaths,
                replacesAllFiles: false,
                requiresClusterRefresh: true,
                errorSummary: result.errorSummary
            )
            Log.info("DashboardFileScanProvider: Scan complete - \(result.files.count) touched files, \(metrics.pendingCount) pending", category: .automation)
            return metrics
        case .delta(let changeSet):
            return try await scanDelta(context: context, changeSet: changeSet)
        }
    }

    func getAutoOrganizeEligibleFiles(
        context: ModelContext,
        confidenceThreshold: Double
    ) async throws -> [FileItem] {
        Log.info("DashboardFileScanProvider: Finding eligible files (threshold: \(confidenceThreshold))", category: .automation)

        let candidates = try await getAutoOrganizeCandidates(context: context)
        let preflight = AutomationEngine.buildPreflightSummary(
            candidates: candidates,
            confidenceThreshold: confidenceThreshold
        )

        Log.info(
            "DashboardFileScanProvider: Found \(preflight.eligibleCount) eligible files from \(candidates.count) candidates",
            category: .automation
        )

        return preflight.eligibleFiles
    }

    func getAutoOrganizeCandidates(context: ModelContext) async throws -> [FileItem] {
        Log.info("DashboardFileScanProvider: Loading auto-organize candidates", category: .automation)

        // Fetch all pending/ready files
        // Note: SwiftData predicates can only access stored properties.
        // FileItem stores status as `statusRaw` (String), so we query that directly.
        let pendingRaw = FileItem.OrganizationStatus.pending.rawValue
        let readyRaw = FileItem.OrganizationStatus.ready.rawValue
        let descriptor = FetchDescriptor<FileItem>(
            predicate: #Predicate<FileItem> { file in
                file.statusRaw == pendingRaw || file.statusRaw == readyRaw
            }
        )

        do {
            return try context.fetch(descriptor)
        } catch {
            Log.error("DashboardFileScanProvider: Failed to fetch auto-organize candidates - \(error.localizedDescription)", category: .automation)
            throw ScanError.candidateFetchFailed(error.localizedDescription)
        }
    }

    static func autoOrganizeEligibleFiles(
        from candidates: [FileItem],
        confidenceThreshold: Double = 0.9
    ) -> [FileItem] {
        AutomationEngine.buildPreflightSummary(
            candidates: candidates,
            confidenceThreshold: confidenceThreshold
        ).eligibleFiles
    }

    // MARK: - Private Helpers

    private func fetchRules(context: ModelContext) throws -> [Rule] {
        let descriptor = FetchDescriptor<Rule>(
            predicate: #Predicate { $0.isEnabled },
            sortBy: [SortDescriptor<Rule>(\.sortOrder, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    private func scanDelta(
        context: ModelContext,
        changeSet: WatchedFolderChangeSet
    ) async throws -> FileScanResult {
        if changeSet.requiresFallbackRootScan {
            let roots = changeSet.touchedRoots.compactMap { touchedRoot in
                BookmarkFolderService.shared.availableFolders.first { folder in
                    folder.isEnabled && folder.resolvedRootPath == touchedRoot
                }?.folderType.folderLocation
            }
            return try await scanFiles(context: context, request: .roots(roots))
        }

        let rules = try fetchRules(context: context)
        let scanOptions = ScanOptionsResolver.current()
        let standardizedUpdatedPaths = Array(changeSet.updatedPaths).sorted().map {
            URL(fileURLWithPath: $0).standardizedFileURL.path
        }

        let explicitSelection: ExplicitSelectionScanResult
        if standardizedUpdatedPaths.isEmpty {
            explicitSelection = ExplicitSelectionScanResult(
                files: [],
                skippedItems: [],
                scannedRootPaths: Array(changeSet.touchedRoots).sorted()
            )
        } else {
            explicitSelection = try await fileSystemService.scanExplicitSelection(
                urls: standardizedUpdatedPaths.map(URL.init(fileURLWithPath:)),
                options: scanOptions
            )
        }

        let scannedRootPaths = explicitSelection.scannedRootPaths.isEmpty
            ? Array(changeSet.touchedRoots).sorted()
            : explicitSelection.scannedRootPaths

        let pipelineResult = await pipeline.evaluateAndPersistExplicitFiles(
            files: explicitSelection.files,
            scannedRootPaths: scannedRootPaths,
            reconcileMissingFiles: false,
            ruleEngine: ruleEngine,
            rules: rules,
            context: context
        )

        try deletePersistedFiles(
            at: Array(changeSet.removedPaths).sorted(),
            context: context
        )

        let persistedFiles = try context.fetch(FetchDescriptor<FileItem>())

        NotificationCenter.default.post(
            name: .automationScanDidPersist,
            object: nil,
            userInfo: [
                AutomationScanNotificationUserInfo.scannedPaths: standardizedUpdatedPaths,
                AutomationScanNotificationUserInfo.updatedPaths: standardizedUpdatedPaths,
                AutomationScanNotificationUserInfo.removedPaths: Array(changeSet.removedPaths).sorted(),
                AutomationScanNotificationUserInfo.scannedRootPaths: scannedRootPaths,
                AutomationScanNotificationUserInfo.replacesAllFiles: false,
                AutomationScanNotificationUserInfo.requiresClusterRefresh: false,
                AutomationScanNotificationUserInfo.errorSummary: pipelineResult.errorSummary as Any
            ]
        )

        return computeAggregateMetrics(
            totalScanned: persistedFiles.count,
            context: context,
            errorSummary: pipelineResult.errorSummary,
            rawErrors: pipelineResult.rawErrors,
            scannedRootPaths: scannedRootPaths
        )
    }

    private func runRootScan(
        baseFolders: [FolderLocation],
        context: ModelContext,
        rules: [Rule]
    ) async -> FileScanPipeline.ScanResult {
        let scanOptions = ScanOptionsResolver.current()
        return await pipeline.scanAndPersist(
            baseFolders: baseFolders,
            scanOptions: scanOptions,
            fileSystemService: fileSystemService,
            ruleEngine: ruleEngine,
            rules: rules,
            context: context
        )
    }

    private func deletePersistedFiles(
        at removedPaths: [String],
        context: ModelContext
    ) throws {
        let removedPathSet = Set(removedPaths.map {
            URL(fileURLWithPath: $0).standardizedFileURL.path
        })
        guard !removedPathSet.isEmpty else { return }

        let descriptor = FetchDescriptor<FileItem>(
            predicate: #Predicate<FileItem> { file in
                removedPathSet.contains(file.path)
            }
        )
        let existingFiles = try context.fetch(descriptor)
        guard !existingFiles.isEmpty else { return }

        for file in existingFiles {
            context.delete(file)
        }

        try context.save()
    }

    private func computeAggregateMetrics(
        totalScanned: Int,
        context: ModelContext,
        errorSummary: String?,
        rawErrors: [String: Error],
        scannedRootPaths: [String]
    ) -> FileScanResult {
        let pendingRaw = FileItem.OrganizationStatus.pending.rawValue
        let readyRaw = FileItem.OrganizationStatus.ready.rawValue
        let completedRaw = FileItem.OrganizationStatus.completed.rawValue
        let skippedRaw = FileItem.OrganizationStatus.skipped.rawValue

        let pendingCount = (try? context.fetchCount(
            FetchDescriptor<FileItem>(
                predicate: #Predicate<FileItem> { file in
                    file.statusRaw == pendingRaw
                }
            )
        )) ?? 0
        let readyCount = (try? context.fetchCount(
            FetchDescriptor<FileItem>(
                predicate: #Predicate<FileItem> { file in
                    file.statusRaw == readyRaw
                }
            )
        )) ?? 0
        let organizedCount = (try? context.fetchCount(
            FetchDescriptor<FileItem>(
                predicate: #Predicate<FileItem> { file in
                    file.statusRaw == completedRaw
                }
            )
        )) ?? 0
        let skippedCount = (try? context.fetchCount(
            FetchDescriptor<FileItem>(
                predicate: #Predicate<FileItem> { file in
                    file.statusRaw == skippedRaw
                }
            )
        )) ?? 0

        var oldestPendingDescriptor = FetchDescriptor<FileItem>(
            predicate: #Predicate<FileItem> { file in
                file.statusRaw == pendingRaw
            },
            sortBy: [SortDescriptor<FileItem>(\.modificationDate, order: .forward)]
        )
        oldestPendingDescriptor.fetchLimit = 1
        let oldestPendingDate = try? context.fetch(oldestPendingDescriptor).first?.modificationDate
        let oldestAgeDays = oldestPendingDate.flatMap { date in
            Int(Date().timeIntervalSince(date) / FormaConfig.Timing.secondsInDay)
        }

        return FileScanResult(
            totalScanned: totalScanned,
            pendingCount: pendingCount,
            readyCount: readyCount,
            organizedCount: organizedCount,
            skippedCount: skippedCount,
            oldestPendingAgeDays: oldestAgeDays,
            errorSummary: errorSummary,
            primaryErrorType: AutomationErrorType.classify(
                scanErrors: rawErrors,
                fallbackSummary: errorSummary
            ),
            scannedRootPaths: scannedRootPaths
        )
    }

    private func postDashboardUpdate(
        updatedPaths: [String],
        removedPaths: [String],
        scannedRootPaths: [String],
        replacesAllFiles: Bool,
        requiresClusterRefresh: Bool,
        errorSummary: String?
    ) {
        NotificationCenter.default.post(
            name: .automationScanDidPersist,
            object: nil,
            userInfo: [
                AutomationScanNotificationUserInfo.scannedPaths: updatedPaths,
                AutomationScanNotificationUserInfo.updatedPaths: updatedPaths,
                AutomationScanNotificationUserInfo.removedPaths: removedPaths,
                AutomationScanNotificationUserInfo.scannedRootPaths: scannedRootPaths,
                AutomationScanNotificationUserInfo.replacesAllFiles: replacesAllFiles,
                AutomationScanNotificationUserInfo.requiresClusterRefresh: requiresClusterRefresh,
                AutomationScanNotificationUserInfo.errorSummary: errorSummary as Any
            ]
        )
    }
    // MARK: - Errors

    enum ScanError: Error, LocalizedError {
        case timeout
        case noFoldersConfigured
        case bookmarkFailure(String)
        case candidateFetchFailed(String)

        var errorDescription: String? {
            switch self {
            case .timeout:
                return "File scan timed out. Try scanning fewer folders."
            case .noFoldersConfigured:
                return "No folders are configured for scanning."
            case .bookmarkFailure(let folder):
                return "Cannot access \(folder). Please re-grant permission in Settings."
            case .candidateFetchFailed(let details):
                return "Unable to load files eligible for auto-organize. \(details)"
            }
        }
    }
}
