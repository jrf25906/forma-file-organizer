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

    func scanFiles(context: ModelContext, baseFolders: [FolderLocation]?) async throws -> FileScanResult {
        Log.info("DashboardFileScanProvider: Starting scan", category: .automation)
        let replacesAllFiles = baseFolders == nil

        // Fetch current rules
        let rules = try fetchRules(context: context)

        // Determine which base folders to scan based on BookmarkFolderService
        let selectedBaseFolders = baseFolders ?? BookmarkFolderService.shared.enabledFolderLocations
        let scanOptions = ScanOptionsResolver.current()

        // Perform the scan
        let result = await pipeline.scanAndPersist(
            baseFolders: selectedBaseFolders,
            scanOptions: scanOptions,
            fileSystemService: fileSystemService,
            ruleEngine: ruleEngine,
            rules: rules,
            context: context
        )

        // Handle timeout as an error
        if result.timedOut {
            throw ScanError.timeout
        }

        // Handle other errors
        if let errorSummary = result.errorSummary, !result.rawErrors.isEmpty {
            Log.warning("DashboardFileScanProvider: Scan completed with errors - \(errorSummary)", category: .automation)
        }

        // Compute metrics from the scan result
        let metrics = computeMetrics(
            from: result.files,
            context: context,
            errorSummary: result.errorSummary,
            rawErrors: result.rawErrors,
            scannedRootPaths: result.scannedRootPaths
        )

        // Notify dashboard surfaces that rely on in-memory file lists.
        NotificationCenter.default.post(
            name: .automationScanDidPersist,
            object: nil,
            userInfo: [
                AutomationScanNotificationUserInfo.scannedPaths: result.files.map(\.path),
                AutomationScanNotificationUserInfo.scannedRootPaths: result.scannedRootPaths,
                AutomationScanNotificationUserInfo.replacesAllFiles: replacesAllFiles,
                AutomationScanNotificationUserInfo.errorSummary: result.errorSummary as Any
            ]
        )

        Log.info("DashboardFileScanProvider: Scan complete - \(result.files.count) files, \(metrics.pendingCount) pending", category: .automation)

        return metrics
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


    private func computeMetrics(
        from files: [FileItem],
        context: ModelContext,
        errorSummary: String?,
        rawErrors: [String: Error],
        scannedRootPaths: [String]
    ) -> FileScanResult {
        var pendingCount = 0
        var readyCount = 0
        var organizedCount = 0
        var skippedCount = 0
        var oldestPendingDate: Date?

        for file in files {
            switch file.status {
            case .pending:
                pendingCount += 1
                // modificationDate is not optional, use it directly
                let fileDate = file.modificationDate
                if oldestPendingDate == nil || fileDate < oldestPendingDate! {
                    oldestPendingDate = fileDate
                }
            case .ready:
                readyCount += 1
            case .completed:
                organizedCount += 1
            case .skipped:
                skippedCount += 1
            }
        }

        // Calculate oldest pending age in days
        let oldestAgeDays: Int? = oldestPendingDate.map { date in
            Int(Date().timeIntervalSince(date) / FormaConfig.Timing.secondsInDay)
        }

        return FileScanResult(
            totalScanned: files.count,
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
