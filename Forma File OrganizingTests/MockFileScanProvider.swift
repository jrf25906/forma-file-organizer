import Foundation
import SwiftData
@testable import Forma_File_Organizing

/// Mock implementation of FileScanProvider for isolated engine testing.
///
/// This mock allows tests to:
/// - Configure scan results without actual file system access
/// - Verify scan calls were made
/// - Simulate error conditions
/// - Test backoff behavior by controlling consecutive failures
final class MockFileScanProvider: FileScanProvider, @unchecked Sendable {

    // MARK: - Configurable Results

    /// The result to return from scanFiles()
    var scanResult: FileScanResult = FileScanResult(
        totalScanned: 0,
        pendingCount: 0,
        readyCount: 0,
        organizedCount: 0,
        skippedCount: 0,
        oldestPendingAgeDays: nil
    )

    /// Files to return from getAutoOrganizeEligibleFiles()
    var autoOrganizeEligibleFiles: [FileItem] = []

    /// Error to throw from scanFiles() (if set)
    var scanError: Error?

    // MARK: - Call Tracking

    /// Number of times scanFiles() was called
    private(set) var scanFilesCallCount = 0

    /// Number of times getAutoOrganizeEligibleFiles() was called
    private(set) var getEligibleFilesCallCount = 0

    /// Timestamps of each scan call (for verifying intervals)
    private(set) var scanCallTimestamps: [Date] = []

    /// The confidence thresholds passed to getAutoOrganizeEligibleFiles()
    private(set) var requestedConfidenceThresholds: [Double] = []

    // MARK: - FileScanProvider Conformance

    func scanFiles(context: ModelContext) async throws -> FileScanResult {
        scanFilesCallCount += 1
        scanCallTimestamps.append(Date())

        if let error = scanError {
            throw error
        }

        return scanResult
    }

    func getAutoOrganizeEligibleFiles(
        context: ModelContext,
        confidenceThreshold: Double
    ) async -> [FileItem] {
        getEligibleFilesCallCount += 1
        requestedConfidenceThresholds.append(confidenceThreshold)

        return autoOrganizeEligibleFiles
    }

    // MARK: - Test Helpers

    /// Resets all call tracking state
    func reset() {
        scanFilesCallCount = 0
        getEligibleFilesCallCount = 0
        scanCallTimestamps = []
        requestedConfidenceThresholds = []
        scanError = nil
    }

    /// Configures a successful scan result with specified counts
    func configureScanResult(
        totalScanned: Int = 100,
        pendingCount: Int = 10,
        readyCount: Int = 5,
        organizedCount: Int = 80,
        skippedCount: Int = 5,
        oldestPendingAgeDays: Int? = nil
    ) {
        scanResult = FileScanResult(
            totalScanned: totalScanned,
            pendingCount: pendingCount,
            readyCount: readyCount,
            organizedCount: organizedCount,
            skippedCount: skippedCount,
            oldestPendingAgeDays: oldestPendingAgeDays
        )
    }

    /// Configures a backlog scenario that should trigger notifications
    func configureBacklogScenario(pendingCount: Int = 60, oldestAgeDays: Int = 10) {
        configureScanResult(
            totalScanned: 100,
            pendingCount: pendingCount,
            readyCount: 0,
            organizedCount: 40 - pendingCount,
            skippedCount: 0,
            oldestPendingAgeDays: oldestAgeDays
        )
    }

    /// Configures an error scenario for testing backoff
    func configureError(_ error: Error) {
        scanError = error
    }
}

// MARK: - Test Error Types

/// Errors that can be injected for testing
enum MockScanError: Error, LocalizedError {
    case permissionDenied
    case networkFailure
    case bookmarkStale
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Access to folder denied"
        case .networkFailure:
            return "Network connection failed"
        case .bookmarkStale:
            return "Security-scoped bookmark is no longer valid"
        case .unknown(let message):
            return message
        }
    }
}
