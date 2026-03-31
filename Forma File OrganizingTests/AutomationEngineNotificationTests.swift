import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class AutomationEngineNotificationTests: XCTestCase {

    private final class MockNotificationService: AutomationNotificationServing {
        private(set) var autoOrganizeSummaries: [(success: Int, failed: Int, skipped: Int)] = []
        private(set) var backlogReminders: [(pendingCount: Int, oldestAgeDays: Int?)] = []
        private(set) var automationErrors: [(type: AutomationErrorType, message: String)] = []
        private(set) var folderHealthAlerts: [(folderType: BookmarkFolder.FolderType, currentBytes: Int64, thresholdBytes: Int64)] = []
        private(set) var staleRuleAlerts: [(ruleNames: [String], thresholdDays: Int)] = []
        var clearedFolderHealthAlerts: [BookmarkFolder.FolderType] = []
        var clearedStaleRuleAlertCount = 0

        func notifyAutoOrganizeSummary(successCount: Int, failedCount: Int, skippedCount: Int) {
            autoOrganizeSummaries.append((successCount, failedCount, skippedCount))
        }

        func notifyBacklogReminder(pendingCount: Int, oldestAgeDays: Int?) {
            backlogReminders.append((pendingCount, oldestAgeDays))
        }

        func notifyAutomationError(type: AutomationErrorType, message: String) {
            automationErrors.append((type, message))
        }

        func notifyFolderHealthAlert(
            folderType: BookmarkFolder.FolderType,
            currentBytes: Int64,
            thresholdBytes: Int64
        ) {
            folderHealthAlerts.append((folderType, currentBytes, thresholdBytes))
        }

        func notifyStaleRulesAlert(ruleNames: [String], thresholdDays: Int) {
            staleRuleAlerts.append((ruleNames, thresholdDays))
        }

        func clearFolderHealthAlert(folderType: BookmarkFolder.FolderType) {
            clearedFolderHealthAlerts.append(folderType)
        }

        func clearStaleRulesAlert() {
            clearedStaleRuleAlertCount += 1
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
        XCTAssertEqual(notificationService.automationErrors.first?.type, .scanFailed)
        XCTAssertTrue(notificationService.automationErrors.first?.message.contains("Auto-organize preflight failed") == true)
    }

    func testManualScanSendsFolderHealthAlertNotificationWhenThresholdExceeded() async throws {
        let downloadsRoot = try TemporaryDirectory()
        defer { downloadsRoot.cleanup() }
        let store = try makeBookmarkStore(for: [(.downloads, downloadsRoot.url)])

        try await BookmarkStoreProvider.$override.withValue(store) {
            let policy = makePolicy(
                notificationsEnabled: true,
                folderHealthAlerts: FolderHealthAlertSettings(
                    folderSizeThresholdBytesByFolder: [.downloads: 10 * 1024 * 1024 * 1024],
                    staleRuleThresholdDays: nil
                )
            )
            let notificationService = MockNotificationService()
            let engine = makeEngine(policy: policy, notificationService: notificationService)

            let container = try ModelContainer(
                for: FileItem.self, Rule.self, ActivityItem.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            let provider = MockFileScanProvider()
            engine.configure(
                modelContext: container.mainContext,
                organizationCoordinator: FileOrganizationCoordinator(),
                scanProvider: provider
            )

            container.mainContext.insert(
                FileItem(
                    path: downloadsRoot.url.appendingPathComponent("archive.zip").path,
                    sizeInBytes: 12 * 1024 * 1024 * 1024,
                    creationDate: Date(timeIntervalSince1970: 1_700_000_000),
                    location: .downloads,
                    scanRootPath: downloadsRoot.url.path
                )
            )
            try container.mainContext.save()

            await engine.triggerManualScan()

            XCTAssertEqual(notificationService.folderHealthAlerts.count, 1)
            XCTAssertEqual(notificationService.folderHealthAlerts.first?.folderType, .downloads)
        }
    }

    func testManualScanDoesNotAlertForDisabledFolders() async throws {
        let downloadsRoot = try TemporaryDirectory()
        defer { downloadsRoot.cleanup() }
        let store = try makeBookmarkStore(for: [(.downloads, downloadsRoot.url)])

        let folder = BookmarkFolder(folderType: .downloads)
        let originalEnabled = folder.isEnabled
        var mutableFolder = folder
        mutableFolder.isEnabled = false
        defer {
            var resetFolder = folder
            resetFolder.isEnabled = originalEnabled
        }

        try await BookmarkStoreProvider.$override.withValue(store) {
            let policy = makePolicy(
                notificationsEnabled: true,
                folderHealthAlerts: FolderHealthAlertSettings(
                    folderSizeThresholdBytesByFolder: [.downloads: 10 * 1024 * 1024 * 1024],
                    staleRuleThresholdDays: nil
                )
            )
            let notificationService = MockNotificationService()
            let engine = makeEngine(policy: policy, notificationService: notificationService)

            let container = try ModelContainer(
                for: FileItem.self, Rule.self, ActivityItem.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            let provider = MockFileScanProvider()
            engine.configure(
                modelContext: container.mainContext,
                organizationCoordinator: FileOrganizationCoordinator(),
                scanProvider: provider
            )

            container.mainContext.insert(
                FileItem(
                    path: downloadsRoot.url.appendingPathComponent("archive.zip").path,
                    sizeInBytes: 12 * 1024 * 1024 * 1024,
                    creationDate: Date(timeIntervalSince1970: 1_700_000_000),
                    location: .downloads,
                    scanRootPath: downloadsRoot.url.path
                )
            )
            try container.mainContext.save()

            await engine.triggerManualScan()

            XCTAssertTrue(notificationService.folderHealthAlerts.isEmpty)
        }
    }

    func testManualScanDoesNotAlertForCorruptFolderBookmarks() async throws {
        let store = InMemoryBookmarkStore()
        try store.saveBookmark(Data([0x01, 0x02, 0x03]), forKey: FormaConfig.Security.downloadsBookmarkKey)

        try await BookmarkStoreProvider.$override.withValue(store) {
            let policy = makePolicy(
                notificationsEnabled: true,
                folderHealthAlerts: FolderHealthAlertSettings(
                    folderSizeThresholdBytesByFolder: [.downloads: 10 * 1024 * 1024 * 1024],
                    staleRuleThresholdDays: nil
                )
            )
            let notificationService = MockNotificationService()
            let engine = makeEngine(policy: policy, notificationService: notificationService)

            let container = try ModelContainer(
                for: FileItem.self, Rule.self, ActivityItem.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            let provider = MockFileScanProvider()
            engine.configure(
                modelContext: container.mainContext,
                organizationCoordinator: FileOrganizationCoordinator(),
                scanProvider: provider
            )

            container.mainContext.insert(
                FileItem(
                    path: "/tmp/downloads-corrupt/archive.zip",
                    sizeInBytes: 12 * 1024 * 1024 * 1024,
                    creationDate: Date(timeIntervalSince1970: 1_700_000_000),
                    location: .downloads,
                    scanRootPath: "/tmp/downloads-corrupt"
                )
            )
            try container.mainContext.save()

            await engine.triggerManualScan()

            XCTAssertTrue(notificationService.folderHealthAlerts.isEmpty)
        }
    }

    func testManualScanSendsStaleRulesNotificationSummary() async throws {
        let policy = makePolicy(
            notificationsEnabled: true,
            folderHealthAlerts: FolderHealthAlertSettings(
                folderSizeThresholdBytesByFolder: [:],
                staleRuleThresholdDays: 30
            )
        )
        let notificationService = MockNotificationService()
        let engine = makeEngine(policy: policy, notificationService: notificationService)

        let container = try ModelContainer(
            for: FileItem.self, Rule.self, ActivityItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let provider = MockFileScanProvider()
        engine.configure(
            modelContext: container.mainContext,
            organizationCoordinator: FileOrganizationCoordinator(),
            scanProvider: provider
        )

        let staleRule = Rule(
            name: "Old Cleanup Rule",
            conditionType: .nameContains,
            conditionValue: "cleanup",
            actionType: .delete,
            destination: .trash
        )
        staleRule.lastTriggeredDate = Date(timeIntervalSince1970: 1_700_000_000 - (45 * 86_400))
        container.mainContext.insert(staleRule)
        try container.mainContext.save()

        await engine.triggerManualScan()

        XCTAssertEqual(notificationService.staleRuleAlerts.count, 1)
        XCTAssertEqual(notificationService.staleRuleAlerts.first?.ruleNames, ["Old Cleanup Rule"])
    }

    func testManualScanClearsResolvedFolderHealthNotifications() async throws {
        let downloadsRoot = try TemporaryDirectory()
        defer { downloadsRoot.cleanup() }
        let store = try makeBookmarkStore(for: [(.downloads, downloadsRoot.url)])

        try await BookmarkStoreProvider.$override.withValue(store) {
            let policy = makePolicy(
                notificationsEnabled: true,
                folderHealthAlerts: FolderHealthAlertSettings(
                    folderSizeThresholdBytesByFolder: [.downloads: 10 * 1024 * 1024 * 1024],
                    staleRuleThresholdDays: 30
                )
            )
            let notificationService = MockNotificationService()
            let engine = makeEngine(policy: policy, notificationService: notificationService)

            let container = try ModelContainer(
                for: FileItem.self, Rule.self, ActivityItem.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            let provider = MockFileScanProvider()
            engine.configure(
                modelContext: container.mainContext,
                organizationCoordinator: FileOrganizationCoordinator(),
                scanProvider: provider
            )

            notificationService.clearedFolderHealthAlerts.removeAll()
            notificationService.clearedStaleRuleAlertCount = 0

            await engine.triggerManualScan()

            XCTAssertEqual(notificationService.clearedFolderHealthAlerts, [.downloads])
            XCTAssertEqual(notificationService.clearedStaleRuleAlertCount, 1)
        }
    }

    func testRefreshPolicyClearsResolvedFolderHealthNotificationsWhenThresholdRises() async throws {
        let downloadsRoot = try TemporaryDirectory()
        defer { downloadsRoot.cleanup() }
        let store = try makeBookmarkStore(for: [(.downloads, downloadsRoot.url)])

        try await BookmarkStoreProvider.$override.withValue(store) {
            var policy = makePolicy(
                notificationsEnabled: true,
                folderHealthAlerts: FolderHealthAlertSettings(
                    folderSizeThresholdBytesByFolder: [.downloads: 10 * 1024 * 1024 * 1024],
                    staleRuleThresholdDays: nil
                )
            )
            let notificationService = MockNotificationService()
            let engine = AutomationEngine(
                notificationService: notificationService,
                clock: FixedClock(now: Date(timeIntervalSince1970: 1_700_000_000)),
                policyResolver: { policy }
            )

            let container = try ModelContainer(
                for: FileItem.self, Rule.self, ActivityItem.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            let provider = MockFileScanProvider()
            engine.configure(
                modelContext: container.mainContext,
                organizationCoordinator: FileOrganizationCoordinator(),
                scanProvider: provider
            )

            container.mainContext.insert(
                FileItem(
                    path: downloadsRoot.url.appendingPathComponent("archive.zip").path,
                    sizeInBytes: 12 * 1024 * 1024 * 1024,
                    creationDate: Date(timeIntervalSince1970: 1_700_000_000),
                    location: .downloads,
                    scanRootPath: downloadsRoot.url.path
                )
            )
            try container.mainContext.save()

            await engine.triggerManualScan()
            XCTAssertEqual(notificationService.folderHealthAlerts.count, 1)

            policy = makePolicy(
                notificationsEnabled: true,
                folderHealthAlerts: FolderHealthAlertSettings(
                    folderSizeThresholdBytesByFolder: [.downloads: 20 * 1024 * 1024 * 1024],
                    staleRuleThresholdDays: nil
                )
            )

            engine.refreshPolicy()

            XCTAssertEqual(notificationService.clearedFolderHealthAlerts.last, .downloads)
        }
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

    private func makePolicy(
        notificationsEnabled: Bool,
        folderHealthAlerts: FolderHealthAlertSettings
    ) -> AutomationPolicy {
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
            errorNotificationCooldownMinutes: FormaConfig.Automation.errorNotificationCooldownMinutes,
            folderHealthAlerts: folderHealthAlerts
        )
    }

    private func makeBookmarkStore(
        for folders: [(BookmarkFolder.FolderType, URL)]
    ) throws -> InMemoryBookmarkStore {
        let store = InMemoryBookmarkStore()

        for (folderType, url) in folders {
            let destination = try Destination.folder(from: url, displayName: folderType.displayName)
            try store.saveBookmark(
                try XCTUnwrap(destination.bookmarkData),
                forKey: folderType.bookmarkKey
            )
        }

        return store
    }
}
