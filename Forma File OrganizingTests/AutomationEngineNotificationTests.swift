import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class AutomationEngineNotificationTests: XCTestCase {

    private final class MockNotificationService: AutomationNotificationServing {
        private(set) var autoOrganizeSummaries: [(success: Int, failed: Int, skipped: Int)] = []
        private(set) var scopedAutoOrganizeSummaries: [(
            success: Int,
            failed: Int,
            skipped: Int,
            scopeDisplayName: String?,
            groupedScopeCount: Int
        )] = []
        private(set) var trustedScopeAttentionNotifications: [(
            scopeDisplayName: String?,
            groupedScopeCount: Int,
            reason: String
        )] = []
        private(set) var backlogReminders: [(pendingCount: Int, oldestAgeDays: Int?)] = []
        private(set) var automationErrors: [(type: AutomationErrorType, message: String)] = []
        private(set) var folderHealthAlerts: [(folderType: BookmarkFolder.FolderType, currentBytes: Int64, thresholdBytes: Int64)] = []
        private(set) var staleRuleAlerts: [(ruleNames: [String], thresholdDays: Int)] = []
        var clearedFolderHealthAlerts: [BookmarkFolder.FolderType] = []
        var clearedStaleRuleAlertCount = 0

        func notifyAutoOrganizeSummary(successCount: Int, failedCount: Int, skippedCount: Int) {
            autoOrganizeSummaries.append((successCount, failedCount, skippedCount))
        }

        func notifyAutoOrganizeSummary(
            successCount: Int,
            failedCount: Int,
            skippedCount: Int,
            scopeDisplayName: String?,
            groupedScopeCount: Int
        ) {
            scopedAutoOrganizeSummaries.append((
                successCount,
                failedCount,
                skippedCount,
                scopeDisplayName,
                groupedScopeCount
            ))
        }

        func notifyTrustedAutomationScopeAttention(scopeDisplayName: String, reason: String) {
            trustedScopeAttentionNotifications.append((scopeDisplayName, 1, reason))
        }

        func notifyTrustedAutomationScopeAttention(
            scopeDisplayName: String?,
            groupedScopeCount: Int,
            reason: String
        ) {
            trustedScopeAttentionNotifications.append((scopeDisplayName, groupedScopeCount, reason))
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

    @MainActor
    private final class WorkflowExecutionSpy {
        var failingFileNames: Set<String> = []
        var runError: Error?

        lazy var client = WorkflowExecutionClient(
            plan: { templateID, files, invocationContext in
                WorkflowPlanner().plan(
                    templateID: templateID,
                    files: files,
                    invocationContext: invocationContext
                )
            },
            run: { [weak self] plan, files, scopeID, _ in
                let fileNames = files.map(\.name)
                let shouldFail = await MainActor.run {
                    fileNames.contains { self?.failingFileNames.contains($0) == true }
                }
                guard shouldFail else {
                    return WorkflowRunRecord(
                        scopeID: scopeID,
                        workflowTemplateID: plan.definition.templateID,
                        primaryStatus: .succeeded,
                        startedAt: Date(timeIntervalSince1970: 1_000),
                        endedAt: Date(timeIntervalSince1970: 1_001)
                    )
                }

                if let runError = await MainActor.run(resultType: Error?.self, body: { self?.runError }) {
                    throw runError
                }

                return WorkflowRunRecord(
                    scopeID: scopeID,
                    workflowTemplateID: plan.definition.templateID,
                    primaryStatus: .completedWithIssues,
                    startedAt: Date(timeIntervalSince1970: 1_000),
                    endedAt: Date(timeIntervalSince1970: 1_001)
                )
            }
        )
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

    func testAutoOrganizeSummaryUsesScopeNameForSingleTrustedScopeRun() async throws {
        let sourceRoot = try TemporaryDirectory()
        defer { sourceRoot.cleanup() }

        let destinationRoot = try TemporaryDirectory()
        defer { destinationRoot.cleanup() }

        let destinationURL = try destinationRoot.createDirectory(name: "Receipts Archive")
        let destination = try Destination.folder(from: destinationURL, displayName: "Receipts Archive")

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
        let workflowExecution = WorkflowExecutionSpy()
        let engine = makeEngine(
            policy: policy,
            notificationService: notificationService,
            workflowExecution: workflowExecution.client
        )

        let container = try ModelContainer(
            for: FileItem.self,
            Rule.self,
            ActivityItem.self,
            TrustedAutomationScope.self,
            TrustedAutomationScopeRunRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let coordinator = RecordingOrganizationCoordinator()
        let provider = MockFileScanProvider()

        let fileURL = try sourceRoot.createFile(name: "trusted/Receipt-April.pdf")
        let file = FileItem(
            path: fileURL.path,
            sizeInBytes: 128,
            creationDate: Date(timeIntervalSince1970: 1_700_000_000),
            location: .downloads,
            scanRootPath: sourceRoot.url.path,
            relativeParentPath: "trusted",
            destination: destination,
            originalSuggestedDestination: destination,
            status: .pending
        )
        file.confidenceScore = 0.99
        container.mainContext.insert(file)

        let scopeService = TrustedAutomationScopeService(modelContext: container.mainContext)
        _ = try scopeService.createOrReactivateScope(
            scopeType: .folder,
            scopeKey: "\(sourceRoot.url.path)|trusted",
            displayName: "Receipts",
            boundaryDescriptor: .folder(
                source: .init(
                    sourceLocation: .downloads,
                    scanRootPath: sourceRoot.url.path,
                    relativeParentPath: "trusted"
                ),
                destination: .init(destination)
            ),
            promotionSource: .reviewFlow,
            recommendationSource: .repeatedReviewAcceptance,
            acceptedEvidenceCount: 4,
            overrideEvidenceCount: 0,
            undoEvidenceCount: 0,
            confidenceSnapshot: 0.95,
            rationaleSummary: "Trusted after repeated review approvals.",
            allowedActions: [.move],
            selectedWorkflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts
        )

        provider.autoOrganizeCandidates = [file]
        engine.configure(
            modelContext: container.mainContext,
            organizationCoordinator: coordinator,
            scanProvider: provider
        )

        await engine.triggerAutoOrganize()

        XCTAssertEqual(notificationService.scopedAutoOrganizeSummaries.count, 1)
        XCTAssertEqual(notificationService.scopedAutoOrganizeSummaries.first?.scopeDisplayName, "Receipts")
        XCTAssertEqual(notificationService.scopedAutoOrganizeSummaries.first?.groupedScopeCount, 1)
    }

    func testMixedScopeRunKeepsSummaryGroupedAndStillSendsGroupedAttentionNotification() async throws {
        let sourceRoot = try TemporaryDirectory()
        defer { sourceRoot.cleanup() }

        let destinationRoot = try TemporaryDirectory()
        defer { destinationRoot.cleanup() }

        let successDestinationURL = try destinationRoot.createDirectory(name: "Receipts Archive")
        let heldDestinationURL = try destinationRoot.createDirectory(name: "Invoices Archive")
        let successDestination = try Destination.folder(from: successDestinationURL, displayName: "Receipts Archive")
        let heldDestination = try Destination.folder(from: heldDestinationURL, displayName: "Invoices Archive")

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
        let workflowExecution = WorkflowExecutionSpy()
        let engine = makeEngine(
            policy: policy,
            notificationService: notificationService,
            workflowExecution: workflowExecution.client
        )

        let container = try ModelContainer(
            for: FileItem.self,
            Rule.self,
            ActivityItem.self,
            TrustedAutomationScope.self,
            TrustedAutomationScopeRunRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let coordinator = RecordingOrganizationCoordinator()
        let provider = MockFileScanProvider()

        let successFileURL = try sourceRoot.createFile(name: "receipts/Receipt-April.pdf")
        let successFile = FileItem(
            path: successFileURL.path,
            sizeInBytes: 128,
            creationDate: Date(timeIntervalSince1970: 1_700_000_000),
            location: .downloads,
            scanRootPath: sourceRoot.url.path,
            relativeParentPath: "receipts",
            destination: successDestination,
            originalSuggestedDestination: successDestination,
            status: .pending
        )
        successFile.confidenceScore = 0.99

        let heldFileURL = try sourceRoot.createFile(name: "invoices/Invoice-April.pdf")
        let heldFile = FileItem(
            path: heldFileURL.path,
            sizeInBytes: 128,
            creationDate: Date(timeIntervalSince1970: 1_700_000_000),
            location: .downloads,
            scanRootPath: sourceRoot.url.path,
            relativeParentPath: "invoices",
            destination: heldDestination,
            originalSuggestedDestination: heldDestination,
            status: .pending
        )
        heldFile.confidenceScore = 0.99

        container.mainContext.insert(successFile)
        container.mainContext.insert(heldFile)

        let scopeService = TrustedAutomationScopeService(modelContext: container.mainContext)
        _ = try scopeService.createOrReactivateScope(
            scopeType: .folder,
            scopeKey: "\(sourceRoot.url.path)|receipts",
            displayName: "Receipts",
            boundaryDescriptor: .folder(
                source: .init(
                    sourceLocation: .downloads,
                    scanRootPath: sourceRoot.url.path,
                    relativeParentPath: "receipts"
                ),
                destination: .init(successDestination)
            ),
            promotionSource: .reviewFlow,
            recommendationSource: .repeatedReviewAcceptance,
            acceptedEvidenceCount: 4,
            overrideEvidenceCount: 0,
            undoEvidenceCount: 0,
            confidenceSnapshot: 0.95,
            rationaleSummary: "Trusted after repeated review approvals.",
            allowedActions: [.move],
            selectedWorkflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts
        )
        _ = try scopeService.createOrReactivateScope(
            scopeType: .folder,
            scopeKey: "\(sourceRoot.url.path)|invoices",
            displayName: "Invoices",
            boundaryDescriptor: .folder(
                source: .init(
                    sourceLocation: .downloads,
                    scanRootPath: sourceRoot.url.path,
                    relativeParentPath: "invoices"
                ),
                destination: .init(heldDestination)
            ),
            promotionSource: .reviewFlow,
            recommendationSource: .repeatedReviewAcceptance,
            acceptedEvidenceCount: 4,
            overrideEvidenceCount: 0,
            undoEvidenceCount: 0,
            confidenceSnapshot: 0.95,
            rationaleSummary: "Trusted after repeated review approvals.",
            allowedActions: [.move],
            selectedWorkflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts
        )

        try FileManager.default.removeItem(at: heldDestinationURL)

        provider.autoOrganizeCandidates = [successFile, heldFile]
        engine.configure(
            modelContext: container.mainContext,
            organizationCoordinator: coordinator,
            scanProvider: provider
        )

        await engine.triggerAutoOrganize()

        XCTAssertEqual(notificationService.scopedAutoOrganizeSummaries.count, 1)
        XCTAssertNil(notificationService.scopedAutoOrganizeSummaries.first?.scopeDisplayName)
        XCTAssertEqual(notificationService.scopedAutoOrganizeSummaries.first?.groupedScopeCount, 2)

        XCTAssertEqual(notificationService.trustedScopeAttentionNotifications.count, 1)
        XCTAssertNil(notificationService.trustedScopeAttentionNotifications.first?.scopeDisplayName)
        XCTAssertEqual(notificationService.trustedScopeAttentionNotifications.first?.groupedScopeCount, 2)
    }

    func testExecutionFailureStillSendsGroupedAttentionNotificationForMixedScopeRun() async throws {
        let sourceRoot = try TemporaryDirectory()
        defer { sourceRoot.cleanup() }

        let destinationRoot = try TemporaryDirectory()
        defer { destinationRoot.cleanup() }

        let successDestinationURL = try destinationRoot.createDirectory(name: "Receipts Archive")
        let failingDestinationURL = try destinationRoot.createDirectory(name: "Invoices Archive")
        let successDestination = try Destination.folder(from: successDestinationURL, displayName: "Receipts Archive")
        let failingDestination = try Destination.folder(from: failingDestinationURL, displayName: "Invoices Archive")

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
        let workflowExecution = WorkflowExecutionSpy()
        let engine = makeEngine(
            policy: policy,
            notificationService: notificationService,
            workflowExecution: workflowExecution.client
        )

        let container = try ModelContainer(
            for: FileItem.self,
            Rule.self,
            ActivityItem.self,
            TrustedAutomationScope.self,
            TrustedAutomationScopeRunRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let provider = MockFileScanProvider()

        let successFileURL = try sourceRoot.createFile(name: "receipts/Receipt-May.pdf")
        let successFile = FileItem(
            path: successFileURL.path,
            sizeInBytes: 128,
            creationDate: Date(timeIntervalSince1970: 1_700_000_000),
            location: .downloads,
            scanRootPath: sourceRoot.url.path,
            relativeParentPath: "receipts",
            destination: successDestination,
            originalSuggestedDestination: successDestination,
            status: .pending
        )
        successFile.confidenceScore = 0.99

        let failingFileURL = try sourceRoot.createFile(name: "invoices/Invoice-May.pdf")
        let failingFile = FileItem(
            path: failingFileURL.path,
            sizeInBytes: 128,
            creationDate: Date(timeIntervalSince1970: 1_700_000_000),
            location: .downloads,
            scanRootPath: sourceRoot.url.path,
            relativeParentPath: "invoices",
            destination: failingDestination,
            originalSuggestedDestination: failingDestination,
            status: .pending
        )
        failingFile.confidenceScore = 0.99
        workflowExecution.failingFileNames = [failingFile.name]
        workflowExecution.runError = FormaError.fileSystem(.permissionDenied("Invoices Archive"))

        container.mainContext.insert(successFile)
        container.mainContext.insert(failingFile)

        let scopeService = TrustedAutomationScopeService(modelContext: container.mainContext)
        _ = try scopeService.createOrReactivateScope(
            scopeType: .folder,
            scopeKey: "\(sourceRoot.url.path)|receipts",
            displayName: "Receipts",
            boundaryDescriptor: .folder(
                source: .init(
                    sourceLocation: .downloads,
                    scanRootPath: sourceRoot.url.path,
                    relativeParentPath: "receipts"
                ),
                destination: .init(successDestination)
            ),
            promotionSource: .reviewFlow,
            recommendationSource: .repeatedReviewAcceptance,
            acceptedEvidenceCount: 4,
            overrideEvidenceCount: 0,
            undoEvidenceCount: 0,
            confidenceSnapshot: 0.95,
            rationaleSummary: "Trusted after repeated review approvals.",
            allowedActions: [.move],
            selectedWorkflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts
        )
        _ = try scopeService.createOrReactivateScope(
            scopeType: .folder,
            scopeKey: "\(sourceRoot.url.path)|invoices",
            displayName: "Invoices",
            boundaryDescriptor: .folder(
                source: .init(
                    sourceLocation: .downloads,
                    scanRootPath: sourceRoot.url.path,
                    relativeParentPath: "invoices"
                ),
                destination: .init(failingDestination)
            ),
            promotionSource: .reviewFlow,
            recommendationSource: .repeatedReviewAcceptance,
            acceptedEvidenceCount: 4,
            overrideEvidenceCount: 0,
            undoEvidenceCount: 0,
            confidenceSnapshot: 0.95,
            rationaleSummary: "Trusted after repeated review approvals.",
            allowedActions: [.move],
            selectedWorkflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts
        )

        let coordinator = RecordingOrganizationCoordinator()
        provider.autoOrganizeCandidates = [successFile, failingFile]
        engine.configure(
            modelContext: container.mainContext,
            organizationCoordinator: coordinator,
            scanProvider: provider
        )

        await engine.triggerAutoOrganize()

        XCTAssertEqual(notificationService.scopedAutoOrganizeSummaries.count, 1)
        XCTAssertNil(notificationService.scopedAutoOrganizeSummaries.first?.scopeDisplayName)
        XCTAssertEqual(notificationService.scopedAutoOrganizeSummaries.first?.groupedScopeCount, 2)

        XCTAssertEqual(notificationService.trustedScopeAttentionNotifications.count, 1)
        XCTAssertNil(notificationService.trustedScopeAttentionNotifications.first?.scopeDisplayName)
        XCTAssertEqual(notificationService.trustedScopeAttentionNotifications.first?.groupedScopeCount, 2)
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
        notificationService: AutomationNotificationServing,
        workflowExecution: WorkflowExecutionClient = .live
    ) -> AutomationEngine {
        AutomationEngine(
            notificationService: notificationService,
            clock: FixedClock(now: Date(timeIntervalSince1970: 1_700_000_000)),
            policyResolver: { policy },
            workflowExecution: workflowExecution
        )
    }

    @MainActor
    private final class RecordingOrganizationCoordinator: FileOrganizationCoordinator {
        override func organizeMultipleFiles(
            _ files: [FileItem],
            origin: OrganizationRunOrigin = .reviewDriven,
            projectAssociationWriteContext explicitProjectAssociationWriteContext: ProjectAssociationWriteContext? = nil,
            context: ModelContext?,
            onComplete: @escaping (Int, Int, [FileItem], Error?) -> Void
        ) async {
            onComplete(files.count, 0, [], nil)
        }
    }

    @MainActor
    private final class SelectiveFailingOrganizationCoordinator: FileOrganizationCoordinator {
        private let failingFileNames: Set<String>
        private let error: Error

        init(failingFileNames: Set<String>, error: Error) {
            self.failingFileNames = failingFileNames
            self.error = error
        }

        override func organizeMultipleFiles(
            _ files: [FileItem],
            origin: OrganizationRunOrigin = .reviewDriven,
            projectAssociationWriteContext explicitProjectAssociationWriteContext: ProjectAssociationWriteContext? = nil,
            context: ModelContext?,
            onComplete: @escaping (Int, Int, [FileItem], Error?) -> Void
        ) async {
            if files.contains(where: { failingFileNames.contains($0.name) }) {
                onComplete(0, files.count, files, error)
                return
            }

            onComplete(files.count, 0, [], nil)
        }
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
