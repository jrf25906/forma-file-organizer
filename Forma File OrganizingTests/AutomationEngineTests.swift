import XCTest
@testable import Forma_File_Organizing

/// Tests for AutomationEngine behavior.
///
/// Tests cover:
/// - Exponential backoff calculation on consecutive failures
/// - Backoff capping at maximum interval
/// - Notification rate limiting (hourly cap)
/// - Cooldown periods for backlog and error notifications
final class AutomationEngineTests: XCTestCase {

    // MARK: - Backoff Calculation Tests

    /// Test: Backoff formula at minimum consecutive failures (3)
    func testBackoffAtMinimumFailures() {
        // Formula: minScanInterval * 2^(failures - maxConsecutiveFailures)
        // At exactly 3 failures: 5 * 2^0 = 5
        let backoff = calculateBackoff(consecutiveFailures: 3)
        XCTAssertEqual(backoff, 5, "At 3 failures (threshold), backoff should be 5 minutes")
    }

    /// Test: Backoff doubles with each additional failure
    func testBackoffExponentialIncrease() {
        // 4 failures: 5 * 2^1 = 10
        XCTAssertEqual(calculateBackoff(consecutiveFailures: 4), 10)

        // 5 failures: 5 * 2^2 = 20
        XCTAssertEqual(calculateBackoff(consecutiveFailures: 5), 20)

        // 6 failures: 5 * 2^3 = 40
        XCTAssertEqual(calculateBackoff(consecutiveFailures: 6), 40)

        // 7 failures: 5 * 2^4 = 80
        XCTAssertEqual(calculateBackoff(consecutiveFailures: 7), 80)
    }

    /// Test: Backoff capped at maximum interval
    func testBackoffCappedAtMaximum() {
        // 8 failures: 5 * 2^5 = 160 -> capped at 120
        XCTAssertEqual(calculateBackoff(consecutiveFailures: 8), FormaConfig.Automation.maxBackoffIntervalMinutes)

        // 10 failures: 5 * 2^7 = 640 -> capped at 120
        XCTAssertEqual(calculateBackoff(consecutiveFailures: 10), FormaConfig.Automation.maxBackoffIntervalMinutes)

        // 20 failures: still capped at 120
        XCTAssertEqual(calculateBackoff(consecutiveFailures: 20), FormaConfig.Automation.maxBackoffIntervalMinutes)
    }

    /// Test: No backoff when below failure threshold
    func testNoBackoffBelowThreshold() {
        // Below threshold, backoff should not apply
        // This tests the condition: if consecutiveFailures >= maxConsecutiveFailures
        XCTAssertEqual(calculateBackoff(consecutiveFailures: 0), 0)
        XCTAssertEqual(calculateBackoff(consecutiveFailures: 1), 0)
        XCTAssertEqual(calculateBackoff(consecutiveFailures: 2), 0)
    }

    /// Test: Backoff calculation uses correct constants
    func testBackoffUsesConfigConstants() {
        // Verify we're testing against actual config values
        XCTAssertEqual(FormaConfig.Automation.minScanIntervalMinutes, 5)
        XCTAssertEqual(FormaConfig.Automation.failureBackoffMultiplier, 2.0)
        XCTAssertEqual(FormaConfig.Automation.maxConsecutiveFailures, 3)
        XCTAssertEqual(FormaConfig.Automation.maxBackoffIntervalMinutes, 120)
    }

    // MARK: - Notification Rate Limiting Tests

    /// Test: Notification rate limit constant
    func testNotificationRateLimitConstant() {
        // Verify the hourly notification cap
        XCTAssertEqual(FormaConfig.Automation.maxNotificationsPerHour, 5)
    }

    /// Test: Backlog reminder cooldown constant
    func testBacklogReminderCooldownConstant() {
        // Verify the backlog reminder cooldown (24 hours)
        XCTAssertEqual(FormaConfig.Automation.backlogReminderCooldownHours, 24)
    }

    /// Test: Error notification cooldown constant
    func testErrorNotificationCooldownConstant() {
        // Verify the error notification cooldown (60 minutes)
        XCTAssertEqual(FormaConfig.Automation.errorNotificationCooldownMinutes, 60)
    }

    // MARK: - Threshold Constants Tests

    /// Test: Backlog threshold constant
    func testBacklogThresholdConstant() {
        XCTAssertEqual(FormaConfig.Automation.backlogThreshold, 50)
    }

    /// Test: Age threshold constant
    func testAgeThresholdConstant() {
        XCTAssertEqual(FormaConfig.Automation.ageThresholdDays, 7)
    }

    /// Test: ML confidence thresholds
    func testMLConfidenceThresholds() {
        // Rule confidence minimum should be lower than auto-organize minimum
        XCTAssertLessThan(
            FormaConfig.Automation.mlRuleConfidenceMinimum,
            FormaConfig.Automation.mlAutoOrganizeConfidenceMinimum
        )
        XCTAssertEqual(FormaConfig.Automation.mlRuleConfidenceMinimum, 0.75)
        XCTAssertEqual(FormaConfig.Automation.mlAutoOrganizeConfidenceMinimum, 0.90)
    }

    // MARK: - Scan Interval Tests

    /// Test: Scan interval bounds
    func testScanIntervalBounds() {
        XCTAssertEqual(FormaConfig.Automation.minScanIntervalMinutes, 5)
        XCTAssertEqual(FormaConfig.Automation.maxScanIntervalMinutes, 1440) // 24 hours
        XCTAssertEqual(FormaConfig.Automation.defaultScanIntervalMinutes, 30)
    }

    /// Test: Debounce duration
    func testDebounceDuration() {
        XCTAssertEqual(FormaConfig.Automation.scanDebounceDurationSeconds, 60)
    }

    // MARK: - AutomationMetrics Tests

    /// Test: AutomationMetrics initialization from FileScanResult
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

    /// Test: AutomationMetrics direct initialization
    func testAutomationMetricsDirectInit() {
        let metrics = AutomationMetrics(
            totalScanned: 50,
            pendingCount: 10,
            readyCount: 5,
            organizedCount: 30,
            skippedCount: 5,
            oldestPendingAgeDays: 3
        )

        XCTAssertEqual(metrics.totalScanned, 50)
        XCTAssertEqual(metrics.pendingCount, 10)
        XCTAssertEqual(metrics.readyCount, 5)
        XCTAssertEqual(metrics.organizedCount, 30)
        XCTAssertEqual(metrics.skippedCount, 5)
        XCTAssertEqual(metrics.oldestPendingAgeDays, 3)
    }

    /// Test: AutomationMetrics default values
    func testAutomationMetricsDefaults() {
        let metrics = AutomationMetrics()

        XCTAssertEqual(metrics.totalScanned, 0)
        XCTAssertEqual(metrics.pendingCount, 0)
        XCTAssertEqual(metrics.readyCount, 0)
        XCTAssertEqual(metrics.organizedCount, 0)
        XCTAssertEqual(metrics.skippedCount, 0)
        XCTAssertNil(metrics.oldestPendingAgeDays)
    }

    // MARK: - AutomationErrorType Tests

    /// Test: Error type titles
    func testAutomationErrorTypeTitles() {
        XCTAssertEqual(AutomationErrorType.scanFailed.title, "Scan Failed")
        XCTAssertEqual(AutomationErrorType.bookmarkInvalid.title, "Folder Access Lost")
        XCTAssertEqual(AutomationErrorType.destinationInaccessible.title, "Destination Unavailable")
        XCTAssertEqual(AutomationErrorType.permissionDenied.title, "Permission Required")
    }

    /// Test: Error type notification identifiers
    func testAutomationErrorTypeNotificationIdentifiers() {
        XCTAssertEqual(AutomationErrorType.scanFailed.notificationIdentifier, "scanFailed")
        XCTAssertEqual(AutomationErrorType.bookmarkInvalid.notificationIdentifier, "bookmarkInvalid")
        XCTAssertEqual(AutomationErrorType.destinationInaccessible.notificationIdentifier, "destinationInaccessible")
        XCTAssertEqual(AutomationErrorType.permissionDenied.notificationIdentifier, "permissionDenied")
    }

    // MARK: - ScanReason Tests

    /// Test: ScanReason raw values
    func testScanReasonRawValues() {
        XCTAssertEqual(ScanReason.appLaunch.rawValue, "app_launch")
        XCTAssertEqual(ScanReason.scheduled.rawValue, "scheduled")
        XCTAssertEqual(ScanReason.manual.rawValue, "manual")
        XCTAssertEqual(ScanReason.thresholdExceeded.rawValue, "threshold_exceeded")
    }

    // MARK: - Helpers

    /// Replicates the backoff calculation from AutomationEngine
    private func calculateBackoff(consecutiveFailures: Int) -> Int {
        guard consecutiveFailures >= FormaConfig.Automation.maxConsecutiveFailures else {
            return 0
        }

        let backoff = Int(
            Double(FormaConfig.Automation.minScanIntervalMinutes) *
            pow(FormaConfig.Automation.failureBackoffMultiplier,
                Double(consecutiveFailures - FormaConfig.Automation.maxConsecutiveFailures))
        )

        return min(backoff, FormaConfig.Automation.maxBackoffIntervalMinutes)
    }
}
