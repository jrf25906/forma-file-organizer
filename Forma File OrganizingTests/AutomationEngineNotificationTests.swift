import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class AutomationEngineNotificationTests: XCTestCase {

    private final class MockNotificationService: AutomationNotificationServing {
        private(set) var autoOrganizeSummaries: [(success: Int, failed: Int, skipped: Int)] = []
        private(set) var backlogReminders: [(pendingCount: Int, oldestAgeDays: Int?)] = []
        private(set) var automationErrors: [(type: AutomationErrorType, message: String)] = []

        func notifyAutoOrganizeSummary(successCount: Int, failedCount: Int, skippedCount: Int) {
            autoOrganizeSummaries.append((successCount, failedCount, skippedCount))
        }

        func notifyBacklogReminder(pendingCount: Int, oldestAgeDays: Int?) {
            backlogReminders.append((pendingCount, oldestAgeDays))
        }

        func notifyAutomationError(type: AutomationErrorType, message: String) {
            automationErrors.append((type, message))
        }
    }

    func testBacklogThresholdSendsReminderWhenNotificationsEnabled() {
        let policy = makePolicy(notificationsEnabled: true)
        let notificationService = MockNotificationService()
        let engine = makeEngine(policy: policy, notificationService: notificationService)

        let metrics = AutomationMetrics(
            totalScanned: 100,
            pendingCount: policy.backlogThreshold,
            readyCount: 0,
            organizedCount: 0,
            skippedCount: 0,
            oldestPendingAgeDays: nil
        )

        engine.checkThresholds(metrics: metrics)

        XCTAssertEqual(notificationService.backlogReminders.count, 1)
        XCTAssertEqual(notificationService.backlogReminders.first?.pendingCount, policy.backlogThreshold)
    }

    func testBacklogReminderRespectsCooldown() {
        let policy = makePolicy(notificationsEnabled: true)
        let notificationService = MockNotificationService()
        let engine = makeEngine(policy: policy, notificationService: notificationService)

        let metrics = AutomationMetrics(
            totalScanned: 100,
            pendingCount: policy.backlogThreshold + 10,
            readyCount: 0,
            organizedCount: 0,
            skippedCount: 0,
            oldestPendingAgeDays: nil
        )

        engine.checkThresholds(metrics: metrics)
        engine.checkThresholds(metrics: metrics)

        XCTAssertEqual(
            notificationService.backlogReminders.count,
            1,
            "Second reminder should be suppressed by backlog reminder cooldown"
        )
    }

    func testBacklogReminderNotSentWhenNotificationsDisabled() {
        let policy = makePolicy(notificationsEnabled: false)
        let notificationService = MockNotificationService()
        let engine = makeEngine(policy: policy, notificationService: notificationService)

        let metrics = AutomationMetrics(
            totalScanned: 100,
            pendingCount: policy.backlogThreshold + 1,
            readyCount: 0,
            organizedCount: 0,
            skippedCount: 0,
            oldestPendingAgeDays: nil
        )

        engine.checkThresholds(metrics: metrics)

        XCTAssertTrue(notificationService.backlogReminders.isEmpty)
    }

    func testAgeThresholdUsesReminderFlow() {
        let policy = makePolicy(notificationsEnabled: true)
        let notificationService = MockNotificationService()
        let engine = makeEngine(policy: policy, notificationService: notificationService)

        let metrics = AutomationMetrics(
            totalScanned: 100,
            pendingCount: 0,
            readyCount: 0,
            organizedCount: 0,
            skippedCount: 0,
            oldestPendingAgeDays: policy.ageThresholdDays
        )

        engine.checkThresholds(metrics: metrics)

        XCTAssertEqual(notificationService.backlogReminders.count, 1)
        XCTAssertEqual(notificationService.backlogReminders.first?.pendingCount, 0)
        XCTAssertEqual(notificationService.backlogReminders.first?.oldestAgeDays, policy.ageThresholdDays)
    }

    func testAutoOrganizeCandidateFetchFailureSendsErrorNotification() async throws {
        let policy = AutomationPolicy(
            userMode: .scanAndOrganize,
            effectiveMode: .scanAndOrganize,
            scanIntervalMinutes: 30,
            scanOnLaunch: false,
            backlogThreshold: FormaConfig.Automation.backlogThreshold,
            ageThresholdDays: FormaConfig.Automation.ageThresholdDays,
            mlConfidenceThreshold: FormaConfig.Automation.mlAutoOrganizeConfidenceMinimum,
            maxConsecutiveFailures: FormaConfig.Automation.maxConsecutiveFailures,
            notificationsEnabled: true,
            backlogReminderCooldownHours: FormaConfig.Automation.backlogReminderCooldownHours,
            errorNotificationCooldownMinutes: FormaConfig.Automation.errorNotificationCooldownMinutes
        )
        let notificationService = MockNotificationService()
        let engine = makeEngine(policy: policy, notificationService: notificationService)

        let container = try ModelContainer(
            for: FileItem.self, Rule.self, ActivityItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let provider = MockFileScanProvider()
        provider.autoOrganizeEligibleFilesError = MockScanError.permissionDenied
        engine.configure(
            modelContext: container.mainContext,
            organizationCoordinator: FileOrganizationCoordinator(),
            scanProvider: provider
        )

        await engine.triggerAutoOrganize()

        XCTAssertEqual(notificationService.automationErrors.count, 1)
        XCTAssertEqual(notificationService.automationErrors.first?.type, .permissionDenied)
        XCTAssertEqual(notificationService.automationErrors.first?.message, "Access to folder denied")
    }

    func testScanSummaryUsesStructuredErrorTypeInsteadOfGenericSummaryText() async throws {
        let policy = makePolicy(notificationsEnabled: true)
        let notificationService = MockNotificationService()
        let engine = makeEngine(policy: policy, notificationService: notificationService)

        let container = try ModelContainer(
            for: FileItem.self, Rule.self, ActivityItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let provider = MockFileScanProvider()
        provider.scanResult = FileScanResult(
            totalScanned: 20,
            pendingCount: 3,
            readyCount: 1,
            organizedCount: 16,
            skippedCount: 0,
            oldestPendingAgeDays: 2,
            errorSummary: "Failed to scan Downloads",
            primaryErrorType: .permissionDenied
        )
        engine.configure(
            modelContext: container.mainContext,
            organizationCoordinator: FileOrganizationCoordinator(),
            scanProvider: provider
        )

        await engine.triggerManualScan()

        XCTAssertEqual(notificationService.automationErrors.count, 1)
        XCTAssertEqual(notificationService.automationErrors.first?.type, .permissionDenied)
        XCTAssertEqual(notificationService.automationErrors.first?.message, "Failed to scan Downloads")
    }

    // MARK: - Helpers

    private func makeEngine(
        policy: AutomationPolicy,
        notificationService: AutomationNotificationServing
    ) -> AutomationEngine {
        AutomationEngine(
            notificationService: notificationService,
            clock: FixedClock(now: Date(timeIntervalSince1970: 1_700_000_000)),
            policyResolver: { policy }
        )
    }

    private func makePolicy(notificationsEnabled: Bool) -> AutomationPolicy {
        AutomationPolicy(
            userMode: .scanOnly,
            effectiveMode: .scanOnly,
            scanIntervalMinutes: 30,
            scanOnLaunch: false,
            backlogThreshold: FormaConfig.Automation.backlogThreshold,
            ageThresholdDays: FormaConfig.Automation.ageThresholdDays,
            mlConfidenceThreshold: FormaConfig.Automation.mlAutoOrganizeConfidenceMinimum,
            maxConsecutiveFailures: FormaConfig.Automation.maxConsecutiveFailures,
            notificationsEnabled: notificationsEnabled,
            backlogReminderCooldownHours: FormaConfig.Automation.backlogReminderCooldownHours,
            errorNotificationCooldownMinutes: FormaConfig.Automation.errorNotificationCooldownMinutes
        )
    }
}
