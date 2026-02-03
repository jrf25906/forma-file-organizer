import XCTest
@testable import Forma_File_Organizing

/// Focused behavior tests for automation helpers.
final class AutomationEngineTests: XCTestCase {

    // MARK: - Backoff Policy

    func testBackoffBelowThresholdReturnsZero() {
        XCTAssertEqual(AutomationBackoffPolicy.backoffMinutes(consecutiveFailures: 0), 0)
        XCTAssertEqual(AutomationBackoffPolicy.backoffMinutes(consecutiveFailures: 1), 0)
        XCTAssertEqual(AutomationBackoffPolicy.backoffMinutes(consecutiveFailures: 2), 0)
    }

    func testBackoffAtThresholdUsesMinimumInterval() {
        XCTAssertEqual(AutomationBackoffPolicy.backoffMinutes(consecutiveFailures: 3), FormaConfig.Automation.minScanIntervalMinutes)
    }

    func testBackoffExponentiallyIncreasesAndCaps() {
        XCTAssertEqual(AutomationBackoffPolicy.backoffMinutes(consecutiveFailures: 4), 10)
        XCTAssertEqual(AutomationBackoffPolicy.backoffMinutes(consecutiveFailures: 5), 20)
        XCTAssertEqual(AutomationBackoffPolicy.backoffMinutes(consecutiveFailures: 6), 40)
        XCTAssertEqual(AutomationBackoffPolicy.backoffMinutes(consecutiveFailures: 7), 80)
        XCTAssertEqual(AutomationBackoffPolicy.backoffMinutes(consecutiveFailures: 8), FormaConfig.Automation.maxBackoffIntervalMinutes)
        XCTAssertEqual(AutomationBackoffPolicy.backoffMinutes(consecutiveFailures: 10), FormaConfig.Automation.maxBackoffIntervalMinutes)
    }

    // MARK: - AutomationMetrics

    func testAutomationMetricsFromScanResult() {
        let scanResult = FileScanResult(
            totalScanned: 100,
            pendingCount: 25,
            readyCount: 10,
            organizedCount: 60,
            skippedCount: 5,
            oldestPendingAgeDays: 14
        )

        let metrics = AutomationMetrics(from: scanResult)

        XCTAssertEqual(metrics.totalScanned, 100)
        XCTAssertEqual(metrics.pendingCount, 25)
        XCTAssertEqual(metrics.readyCount, 10)
        XCTAssertEqual(metrics.organizedCount, 60)
        XCTAssertEqual(metrics.skippedCount, 5)
        XCTAssertEqual(metrics.oldestPendingAgeDays, 14)
    }

    func testAutomationMetricsDefaults() {
        let metrics = AutomationMetrics()

        XCTAssertEqual(metrics.totalScanned, 0)
        XCTAssertEqual(metrics.pendingCount, 0)
        XCTAssertEqual(metrics.readyCount, 0)
        XCTAssertEqual(metrics.organizedCount, 0)
        XCTAssertEqual(metrics.skippedCount, 0)
        XCTAssertNil(metrics.oldestPendingAgeDays)
    }
}
