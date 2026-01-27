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

    // MARK: - Call Tracking

    /// Number of times scanAndPersist() was called
    private(set) var scanCallCount = 0

    // MARK: - FileScanPipelineProtocol Conformance

    func scanAndPersist(
        baseFolders: [FolderLocation],
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

    // MARK: - Test Helpers

    /// Resets all call tracking and configuration
    func reset() {
        mockFiles = []
        errorSummary = nil
        timedOut = false
        scanCallCount = 0
    }
}
