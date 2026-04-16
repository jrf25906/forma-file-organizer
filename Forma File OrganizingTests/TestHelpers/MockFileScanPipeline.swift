import Foundation
import SwiftData
@testable import Forma_File_Organizing

/// Mock implementation of FileScanPipelineProtocol for testing DashboardViewModel
/// and other components that depend on file scanning.
///
/// Provides configurable results without actual file system access.
final class MockFileScanPipeline: FileScanPipelineProtocol {

    // MARK: - Configurable Results

    /// Files to return from scanAndPersist()
    var mockFiles: [FileItem] = []

    /// Error summary to return (nil = success)
    var errorSummary: String?

    /// Whether to simulate a timeout
    var timedOut: Bool = false
    var explicitSelectionResult = FileScanPipeline.ScanResult(
        files: [],
        errorSummary: nil,
        rawErrors: [:]
    )
    var onEvaluateExplicitFiles: (([FileMetadata], [String], Bool, ModelContext) -> Void)?

    // MARK: - Call Tracking

    /// Number of times scanAndPersist() was called
    private(set) var scanCallCount = 0
    private(set) var explicitScanCallCount = 0
    private(set) var lastExplicitFiles: [FileMetadata] = []
    private(set) var lastExplicitScannedRootPaths: [String] = []
    private(set) var lastExplicitReconcileMissingFiles: Bool?

    // MARK: - FileScanPipelineProtocol Conformance

    func scanAndPersist(
        baseFolders: [FolderLocation],
        scanOptions: FileScanOptions,
        fileSystemService: FileSystemServiceProtocol,
        ruleEngine: RuleEngine,
        rules: [Rule],
        context: ModelContext
    ) async -> FileScanPipeline.ScanResult {
        scanCallCount += 1
        return FileScanPipeline.ScanResult(
            files: mockFiles,
            errorSummary: errorSummary,
            rawErrors: [:],
            timedOut: timedOut
        )
    }

    func evaluateAndPersistExplicitFiles(
        files: [FileMetadata],
        scannedRootPaths: [String],
        reconcileMissingFiles: Bool,
        ruleEngine: RuleEngine,
        rules: [Rule],
        context: ModelContext
    ) async -> FileScanPipeline.ScanResult {
        explicitScanCallCount += 1
        lastExplicitFiles = files
        lastExplicitScannedRootPaths = scannedRootPaths
        lastExplicitReconcileMissingFiles = reconcileMissingFiles
        onEvaluateExplicitFiles?(files, scannedRootPaths, reconcileMissingFiles, context)
        return explicitSelectionResult
    }

    // MARK: - Test Helpers

    /// Resets all call tracking and configuration
    func reset() {
        mockFiles = []
        errorSummary = nil
        timedOut = false
        scanCallCount = 0
        explicitScanCallCount = 0
        lastExplicitFiles = []
        lastExplicitScannedRootPaths = []
        lastExplicitReconcileMissingFiles = nil
        onEvaluateExplicitFiles = nil
        explicitSelectionResult = FileScanPipeline.ScanResult(
            files: [],
            errorSummary: nil,
            rawErrors: [:]
        )
    }
}
