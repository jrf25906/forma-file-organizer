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

    func scanFiles(context: ModelContext) async throws -> FileScanResult {
        Log.info("DashboardFileScanProvider: Starting scan", category: .automation)

        // Fetch current rules
        let rules = try fetchRules(context: context)

        // Determine which base folders to scan based on BookmarkFolderService
        let baseFolders = BookmarkFolderService.shared.enabledFolderLocations

        // Perform the scan
        let result = await pipeline.scanAndPersist(
            baseFolders: baseFolders,
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
        let metrics = computeMetrics(from: result.files, context: context, errorSummary: result.errorSummary)

        Log.info("DashboardFileScanProvider: Scan complete - \(result.files.count) files, \(metrics.pendingCount) pending", category: .automation)

        return metrics
    }

    func getAutoOrganizeEligibleFiles(
        context: ModelContext,
        confidenceThreshold: Double
    ) async -> [FileItem] {
        Log.info("DashboardFileScanProvider: Finding eligible files (threshold: \(confidenceThreshold))", category: .automation)

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

        guard let candidates = try? context.fetch(descriptor) else {
            Log.warning("DashboardFileScanProvider: Failed to fetch candidates", category: .automation)
            return []
        }

        // Cache destination validation results to avoid repeated bookmark resolution
        // (each validate() call triggers URL(resolvingBookmarkData:) which causes SecCodeCopySelf)
        var destinationValidationCache: [Data: Bool] = [:]

        // Filter to eligible files
        let eligible = candidates.filter { file in
            isEligibleForAutoOrganize(file, confidenceThreshold: confidenceThreshold, validationCache: &destinationValidationCache)
        }

        Log.info("DashboardFileScanProvider: Found \(eligible.count) eligible files from \(candidates.count) candidates", category: .automation)

        return eligible
    }

    // MARK: - Private Helpers

    private func fetchRules(context: ModelContext) throws -> [Rule] {
        let descriptor = FetchDescriptor<Rule>(
            predicate: #Predicate { $0.isEnabled },
            sortBy: [SortDescriptor<Rule>(\.sortOrder, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }


    private func computeMetrics(from files: [FileItem], context: ModelContext, errorSummary: String?) -> FileScanResult {
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
            oldestPendingAgeDays: oldestAgeDays
        )
    }

    /// Determines if a file is eligible for automatic organization.
    ///
    /// Eligibility requires ALL of the following:
    /// 1. File has a destination assigned
    /// 2. Destination is valid and accessible
    /// 3. If ML-predicted, confidence meets threshold
    /// 4. Source folder is not excluded from automation
    ///
    /// - Parameter validationCache: Cache of bookmark Data -> isUsable to avoid repeated validation calls.
    ///   This prevents excessive SecCodeCopySelf calls when many files share the same destination.
    private func isEligibleForAutoOrganize(
        _ file: FileItem,
        confidenceThreshold: Double,
        validationCache: inout [Data: Bool]
    ) -> Bool {
        // Must have a destination
        guard let destination = file.destination else {
            return false
        }

        // Extract bookmark data for cache key
        let bookmarkData: Data?
        switch destination {
        case .folder(let bookmark, _):
            bookmarkData = bookmark
        case .trash:
            bookmarkData = nil // Trash doesn't use bookmarks
        }

        // Check destination validity with caching
        let isDestinationUsable: Bool
        if let bookmark = bookmarkData, let cached = validationCache[bookmark] {
            // Use cached result
            isDestinationUsable = cached
        } else {
            // Validate and cache the result
            let result = destination.validate().isUsable
            if let bookmark = bookmarkData {
                validationCache[bookmark] = result
            }
            isDestinationUsable = result
        }

        guard isDestinationUsable else {
            Log.debug("DashboardFileScanProvider: File '\(file.name)' - destination invalid", category: .automation)
            return false
        }

        // Check ML confidence if this is an ML prediction
        if let confidence = file.confidenceScore {
            if confidence < confidenceThreshold {
                Log.debug("DashboardFileScanProvider: File '\(file.name)' - confidence \(confidence) < \(confidenceThreshold)", category: .automation)
                return false
            }
        }

        // If there's a matched rule, use the lower rule threshold
        // (Rule matches are more reliable than pure ML predictions)
        if file.matchedRuleID != nil {
            let ruleThreshold = FormaConfig.Automation.mlRuleConfidenceMinimum
            if let confidence = file.confidenceScore, confidence < ruleThreshold {
                Log.debug("DashboardFileScanProvider: File '\(file.name)' - rule match confidence \(confidence) < \(ruleThreshold)", category: .automation)
                return false
            }
        }

        // TODO: Check if source folder is excluded from automation
        // This would require BookmarkFolder.excludeFromAutomation property

        return true
    }

    // MARK: - Errors

    enum ScanError: Error, LocalizedError {
        case timeout
        case noFoldersConfigured
        case bookmarkFailure(String)

        var errorDescription: String? {
            switch self {
            case .timeout:
                return "File scan timed out. Try scanning fewer folders."
            case .noFoldersConfigured:
                return "No folders are configured for scanning."
            case .bookmarkFailure(let folder):
                return "Cannot access \(folder). Please re-grant permission in Settings."
            }
        }
    }
}

