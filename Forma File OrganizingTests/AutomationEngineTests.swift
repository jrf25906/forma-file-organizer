import XCTest
import SwiftData
@testable import Forma_File_Organizing

/// Focused behavior tests for automation helpers.
final class AutomationEngineTests: XCTestCase {

    @MainActor
    private final class SilentNotificationService: AutomationNotificationServing {
        func notifyAutoOrganizeSummary(successCount: Int, failedCount: Int, skippedCount: Int) {}
        func notifyBacklogReminder(pendingCount: Int, oldestAgeDays: Int?) {}
        func notifyAutomationError(type: AutomationErrorType, message: String) {}
        func notifyFolderHealthAlert(
            folderType: BookmarkFolder.FolderType,
            currentBytes: Int64,
            thresholdBytes: Int64
        ) {}
        func notifyStaleRulesAlert(ruleNames: [String], thresholdDays: Int) {}
        func clearFolderHealthAlert(folderType: BookmarkFolder.FolderType) {}
        func clearStaleRulesAlert() {}
    }

    @MainActor
    private final class RecordingNotificationService: AutomationNotificationServing {
        private(set) var scopedAutoOrganizeSummaries: [(
            success: Int,
            failed: Int,
            skipped: Int,
            scopeDisplayName: String?,
            groupedScopeCount: Int
        )] = []

        func notifyAutoOrganizeSummary(successCount: Int, failedCount: Int, skippedCount: Int) {}

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

        func notifyBacklogReminder(pendingCount: Int, oldestAgeDays: Int?) {}
        func notifyAutomationError(type: AutomationErrorType, message: String) {}
        func notifyFolderHealthAlert(
            folderType: BookmarkFolder.FolderType,
            currentBytes: Int64,
            thresholdBytes: Int64
        ) {}
        func notifyStaleRulesAlert(ruleNames: [String], thresholdDays: Int) {}
        func clearFolderHealthAlert(folderType: BookmarkFolder.FolderType) {}
        func clearStaleRulesAlert() {}
    }

    @MainActor
    private final class RecordingOrganizationCoordinator: FileOrganizationCoordinator {
        private(set) var organizedFileBatches: [[String]] = []

        override func organizeMultipleFiles(
            _ files: [FileItem],
            origin: OrganizationRunOrigin = .reviewDriven,
            projectAssociationWriteContext explicitProjectAssociationWriteContext: ProjectAssociationWriteContext? = nil,
            context: ModelContext?,
            onComplete: @escaping (Int, Int, [FileItem], Error?) -> Void
        ) async {
            organizedFileBatches.append(files.map(\.name))
            onComplete(files.count, 0, [], nil)
        }
    }

    @MainActor
    private final class WorkflowExecutionSpy {
        private(set) var plannedTemplateIDs: [String] = []
        private(set) var plannedInvocationContexts: [WorkflowInvocationContext] = []
        private(set) var ranTemplateIDs: [String] = []
        private(set) var lastPlannedFilePaths: [String] = []
        private(set) var lastRunFilePaths: [String] = []
        var runError: Error?
        var onPlan: (() -> Void)?

        lazy var client = WorkflowExecutionClient(
            plan: { [weak self] templateID, files, invocationContext in
                self?.plannedTemplateIDs.append(templateID)
                self?.plannedInvocationContexts.append(invocationContext)
                self?.lastPlannedFilePaths = files.map(\.path)
                self?.onPlan?()
                return WorkflowPlanner().plan(
                    templateID: templateID,
                    files: files,
                    invocationContext: invocationContext
                )
            },
            run: { [weak self] plan, files, scopeID, _ in
                let filePaths = files.map(\.path)
                await MainActor.run {
                    self?.ranTemplateIDs.append(plan.definition.templateID)
                    self?.lastRunFilePaths = filePaths
                }
                if let runError = await MainActor.run(resultType: Error?.self, body: { self?.runError }) {
                    throw runError
                }
                return WorkflowRunRecord(
                    scopeID: scopeID,
                    workflowTemplateID: plan.definition.templateID,
                    primaryStatus: .succeeded,
                    startedAt: Date(timeIntervalSince1970: 1_000),
                    endedAt: Date(timeIntervalSince1970: 1_001)
                )
            }
        )
    }

    private struct WorkflowExecutionFailure: Error {}

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

    // MARK: - Error Classification

    func testAutomationErrorTypeClassifiesBookmarkFailureFromConcreteErrorType() {
        let error = DashboardFileScanProvider.ScanError.bookmarkFailure("Downloads")

        XCTAssertEqual(AutomationErrorType.classify(error: error), .bookmarkInvalid)
    }

    func testAutomationErrorTypeClassifiesStaleBookmarkCorruptionFromConcreteErrorType() {
        let error = FormaError.data(.corruptedData("Bookmark is stale. Please re-add this folder."))

        XCTAssertEqual(AutomationErrorType.classify(error: error), .bookmarkInvalid)
    }

    func testAutomationErrorTypeClassifiesDestinationValidationFromConcreteErrorType() {
        let error = FormaError.validation(.invalidDestination("/Users/test/Documents"))

        XCTAssertEqual(AutomationErrorType.classify(error: error), .destinationInaccessible)
    }

    func testAutomationErrorTypeClassifiesStructuredScanErrorsBeforeGenericSummary() {
        let errors: [String: Error] = [
            "Downloads": FormaError.fileSystem(.permissionDenied("Downloads"))
        ]

        XCTAssertEqual(
            AutomationErrorType.classify(scanErrors: errors, fallbackSummary: "Failed to scan Downloads"),
            .permissionDenied
        )
    }

    @MainActor
    func testPerformAutoOrganize_OnlyProcessesFilesInsideActiveTrustedScopes() async throws {
        let sourceRoot = try TemporaryDirectory()
        defer { sourceRoot.cleanup() }

        let destinationRoot = try TemporaryDirectory()
        defer { destinationRoot.cleanup() }

        let activeDestinationURL = try destinationRoot.createDirectory(name: "Receipts Archive")
        let pausedDestinationURL = try destinationRoot.createDirectory(name: "Paused Archive")
        let revokedDestinationURL = try destinationRoot.createDirectory(name: "Revoked Archive")
        let activeDestination = try Destination.folder(from: activeDestinationURL, displayName: "Receipts Archive")
        let pausedDestination = try Destination.folder(from: pausedDestinationURL, displayName: "Paused Archive")
        let revokedDestination = try Destination.folder(from: revokedDestinationURL, displayName: "Revoked Archive")

        let container = try makeAutomationContainer()
        let context = container.mainContext
        let scopeService = TrustedAutomationScopeService(modelContext: context)
        let provider = MockFileScanProvider()
        let coordinator = RecordingOrganizationCoordinator()
        let workflowExecution = WorkflowExecutionSpy()
        let engine = makeEngine(workflowExecution: workflowExecution.client)

        let trustedFile = try makeFile(
            sourceRoot: sourceRoot,
            relativeParentPath: "trusted",
            fileName: "Receipt-April.pdf",
            destination: activeDestination
        )
        let outsideScopeFile = try makeFile(
            sourceRoot: sourceRoot,
            relativeParentPath: "outside",
            fileName: "Readme.txt",
            destination: activeDestination
        )
        let pausedFile = try makeFile(
            sourceRoot: sourceRoot,
            relativeParentPath: "paused",
            fileName: "Receipt-May.pdf",
            destination: pausedDestination
        )
        let revokedFile = try makeFile(
            sourceRoot: sourceRoot,
            relativeParentPath: "revoked",
            fileName: "Receipt-June.pdf",
            destination: revokedDestination
        )

        for file in [trustedFile, outsideScopeFile, pausedFile, revokedFile] {
            context.insert(file)
        }

        let activeScope = try makeFolderScope(
            service: scopeService,
            sourceRoot: sourceRoot,
            relativeParentPath: "trusted",
            displayName: "Receipts",
            destination: activeDestination,
            selectedWorkflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts
        )
        let pausedScope = try makeFolderScope(
            service: scopeService,
            sourceRoot: sourceRoot,
            relativeParentPath: "paused",
            displayName: "Paused Receipts",
            destination: pausedDestination
        )
        let revokedScope = try makeFolderScope(
            service: scopeService,
            sourceRoot: sourceRoot,
            relativeParentPath: "revoked",
            displayName: "Revoked Receipts",
            destination: revokedDestination
        )
        try scopeService.pauseScope(id: pausedScope.id)
        try scopeService.removeScope(id: revokedScope.id)

        provider.autoOrganizeCandidates = [trustedFile, outsideScopeFile, pausedFile, revokedFile]
        engine.configure(
            modelContext: context,
            organizationCoordinator: coordinator,
            scanProvider: provider
        )

        await engine.triggerAutoOrganize()

        XCTAssertTrue(coordinator.organizedFileBatches.isEmpty)
        XCTAssertEqual(workflowExecution.plannedTemplateIDs, [BuiltInWorkflowTemplate.StableID.receipts])
        XCTAssertEqual(
            workflowExecution.plannedInvocationContexts,
            [.trustedScopeInspection(scopeDisplayName: "Receipts")]
        )
        XCTAssertEqual(workflowExecution.ranTemplateIDs, [BuiltInWorkflowTemplate.StableID.receipts])
        XCTAssertEqual(workflowExecution.lastRunFilePaths, [trustedFile.path])
        XCTAssertEqual(engine.state.lastPreflightSummary?.eligibleCount, 1)
        XCTAssertEqual(engine.state.lastPreflightSummary?.skippedExcludedFromAutomation, 3)
        XCTAssertEqual(try scopeService.activeScopes().map(\.id), [activeScope.id])
    }

    @MainActor
    func testPerformAutoOrganize_PausedAndRevokedScopesDoNotAutoOrganize() async throws {
        let sourceRoot = try TemporaryDirectory()
        defer { sourceRoot.cleanup() }

        let destinationRoot = try TemporaryDirectory()
        defer { destinationRoot.cleanup() }

        let pausedDestination = try Destination.folder(
            from: try destinationRoot.createDirectory(name: "Paused Archive"),
            displayName: "Paused Archive"
        )
        let revokedDestination = try Destination.folder(
            from: try destinationRoot.createDirectory(name: "Revoked Archive"),
            displayName: "Revoked Archive"
        )

        let container = try makeAutomationContainer()
        let context = container.mainContext
        let scopeService = TrustedAutomationScopeService(modelContext: context)
        let provider = MockFileScanProvider()
        let coordinator = RecordingOrganizationCoordinator()
        let engine = makeEngine()

        let pausedFile = try makeFile(
            sourceRoot: sourceRoot,
            relativeParentPath: "paused",
            fileName: "Paused.pdf",
            destination: pausedDestination
        )
        let revokedFile = try makeFile(
            sourceRoot: sourceRoot,
            relativeParentPath: "revoked",
            fileName: "Revoked.pdf",
            destination: revokedDestination
        )
        context.insert(pausedFile)
        context.insert(revokedFile)

        let pausedScope = try makeFolderScope(
            service: scopeService,
            sourceRoot: sourceRoot,
            relativeParentPath: "paused",
            displayName: "Paused Scope",
            destination: pausedDestination
        )
        let revokedScope = try makeFolderScope(
            service: scopeService,
            sourceRoot: sourceRoot,
            relativeParentPath: "revoked",
            displayName: "Revoked Scope",
            destination: revokedDestination
        )
        try scopeService.pauseScope(id: pausedScope.id)
        try scopeService.removeScope(id: revokedScope.id)

        provider.autoOrganizeCandidates = [pausedFile, revokedFile]
        engine.configure(
            modelContext: context,
            organizationCoordinator: coordinator,
            scanProvider: provider
        )

        await engine.triggerAutoOrganize()

        XCTAssertTrue(coordinator.organizedFileBatches.isEmpty)
        XCTAssertEqual(engine.state.lastPreflightSummary?.eligibleCount, 0)
        XCTAssertEqual(engine.state.lastPreflightSummary?.skippedExcludedFromAutomation, 2)
    }

    @MainActor
    func testPerformAutoOrganize_RecordsPerScopeHeldBucketsWhenAccessBreaks() async throws {
        let sourceRoot = try TemporaryDirectory()
        defer { sourceRoot.cleanup() }

        let destinationRoot = try TemporaryDirectory()
        defer { destinationRoot.cleanup() }

        let brokenDestinationURL = try destinationRoot.createDirectory(name: "Broken Archive")
        let brokenDestination = try Destination.folder(from: brokenDestinationURL, displayName: "Broken Archive")

        let container = try makeAutomationContainer()
        let context = container.mainContext
        let scopeService = TrustedAutomationScopeService(modelContext: context)
        let provider = MockFileScanProvider()
        let coordinator = RecordingOrganizationCoordinator()
        let engine = makeEngine()

        let file = try makeFile(
            sourceRoot: sourceRoot,
            relativeParentPath: "trusted",
            fileName: "Receipt-July.pdf",
            destination: brokenDestination
        )
        context.insert(file)

        let scope = try makeFolderScope(
            service: scopeService,
            sourceRoot: sourceRoot,
            relativeParentPath: "trusted",
            displayName: "Receipts",
            destination: brokenDestination
        )
        try FileManager.default.removeItem(at: brokenDestinationURL)

        provider.autoOrganizeCandidates = [file]
        engine.configure(
            modelContext: context,
            organizationCoordinator: coordinator,
            scanProvider: provider
        )

        await engine.triggerAutoOrganize()

        let records = try context.fetch(
            FetchDescriptor<TrustedAutomationScopeRunRecord>(
                sortBy: [SortDescriptor(\.startedAt, order: .forward)]
            )
        ).filter { $0.scopeID == scope.id }

        XCTAssertTrue(coordinator.organizedFileBatches.isEmpty)
        XCTAssertTrue(records.contains(where: { $0.status == .simulated }))

        let heldRecord = try XCTUnwrap(records.first(where: { $0.status == .held }))
        XCTAssertEqual(heldRecord.heldCount, 1)
        XCTAssertEqual(heldRecord.organizedCount, 0)
        XCTAssertEqual(heldRecord.exampleFileNames, [file.name])
        let heldBucket = try XCTUnwrap(heldRecord.heldBuckets.first)
        XCTAssertEqual(heldBucket.count, 1)
        XCTAssertTrue(
            heldBucket.bucket.localizedCaseInsensitiveContains("permission") ||
            heldBucket.bucket.localizedCaseInsensitiveContains("destination")
        )
    }

    @MainActor
    func testAutomationEngine_UsesWorkflowRunnerForEligibleTrustedScopeBatch() async throws {
        let sourceRoot = try TemporaryDirectory()
        defer { sourceRoot.cleanup() }

        let destinationRoot = try TemporaryDirectory()
        defer { destinationRoot.cleanup() }

        let destination = try Destination.folder(
            from: try destinationRoot.createDirectory(name: "Receipts Archive"),
            displayName: "Receipts Archive"
        )

        let container = try makeAutomationContainer()
        let context = container.mainContext
        let scopeService = TrustedAutomationScopeService(modelContext: context)
        let provider = MockFileScanProvider()
        let coordinator = RecordingOrganizationCoordinator()
        let workflowExecution = WorkflowExecutionSpy()
        let engine = makeEngine(workflowExecution: workflowExecution.client)

        let file = try makeFile(
            sourceRoot: sourceRoot,
            relativeParentPath: "trusted",
            fileName: "Receipt-August.pdf",
            destination: destination
        )
        context.insert(file)

        let scope = try makeFolderScope(
            service: scopeService,
            sourceRoot: sourceRoot,
            relativeParentPath: "trusted",
            displayName: "Receipts",
            destination: destination,
            selectedWorkflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts
        )

        provider.autoOrganizeCandidates = [file]
        engine.configure(
            modelContext: context,
            organizationCoordinator: coordinator,
            scanProvider: provider
        )

        await engine.triggerAutoOrganize()

        XCTAssertTrue(coordinator.organizedFileBatches.isEmpty)
        XCTAssertEqual(workflowExecution.plannedTemplateIDs, [BuiltInWorkflowTemplate.StableID.receipts])
        XCTAssertEqual(workflowExecution.ranTemplateIDs, [BuiltInWorkflowTemplate.StableID.receipts])
        XCTAssertEqual(workflowExecution.lastPlannedFilePaths, [file.path])
        XCTAssertEqual(workflowExecution.lastRunFilePaths, [file.path])

        let records = try context.fetch(
            FetchDescriptor<TrustedAutomationScopeRunRecord>(
                sortBy: [SortDescriptor(\.startedAt, order: .forward)]
            )
        ).filter { $0.scopeID == scope.id }

        XCTAssertEqual(records.map(\.status), [.simulated, .executed])

        let executedRecord = try XCTUnwrap(records.last)
        XCTAssertEqual(executedRecord.organizedCount, 1)
        XCTAssertEqual(executedRecord.heldCount, 0)
        XCTAssertEqual(executedRecord.failedCount, 0)
        XCTAssertEqual(executedRecord.exampleFileNames, [file.name])

        let activities = try context.fetch(FetchDescriptor<ActivityItem>())
        let autoOrganizeActivity = try XCTUnwrap(
            activities.last(where: { $0.activityType == .automationAutoOrganized })
        )
        XCTAssertTrue(autoOrganizeActivity.details.contains("Automatic changes are final"))
        XCTAssertFalse(autoOrganizeActivity.details.contains("Undo available"))
    }

    @MainActor
    func testAutomationEngine_DoesNotRunScopeWithoutAssignedTemplate() async throws {
        let sourceRoot = try TemporaryDirectory()
        defer { sourceRoot.cleanup() }

        let destinationRoot = try TemporaryDirectory()
        defer { destinationRoot.cleanup() }

        let destination = try Destination.folder(
            from: try destinationRoot.createDirectory(name: "Receipts Archive"),
            displayName: "Receipts Archive"
        )

        let container = try makeAutomationContainer()
        let context = container.mainContext
        let scopeService = TrustedAutomationScopeService(modelContext: context)
        let provider = MockFileScanProvider()
        let coordinator = RecordingOrganizationCoordinator()
        let workflowExecution = WorkflowExecutionSpy()
        let engine = makeEngine(workflowExecution: workflowExecution.client)

        let file = try makeFile(
            sourceRoot: sourceRoot,
            relativeParentPath: "trusted",
            fileName: "Receipt-September.pdf",
            destination: destination
        )
        context.insert(file)

        let scope = try makeFolderScope(
            service: scopeService,
            sourceRoot: sourceRoot,
            relativeParentPath: "trusted",
            displayName: "Receipts",
            destination: destination
        )

        provider.autoOrganizeCandidates = [file]
        engine.configure(
            modelContext: context,
            organizationCoordinator: coordinator,
            scanProvider: provider
        )

        await engine.triggerAutoOrganize()

        XCTAssertTrue(coordinator.organizedFileBatches.isEmpty)
        XCTAssertTrue(workflowExecution.plannedTemplateIDs.isEmpty)
        XCTAssertTrue(workflowExecution.ranTemplateIDs.isEmpty)

        let records = try context.fetch(
            FetchDescriptor<TrustedAutomationScopeRunRecord>(
                sortBy: [SortDescriptor(\.startedAt, order: .forward)]
            )
        ).filter { $0.scopeID == scope.id }

        XCTAssertEqual(records.map(\.status), [.simulated, .held])
        XCTAssertEqual(engine.state.lastRunSkippedCount, 1)

        let heldRecord = try XCTUnwrap(records.last)
        XCTAssertEqual(heldRecord.eligibleCount, 1)
        XCTAssertEqual(heldRecord.organizedCount, 0)
        XCTAssertEqual(heldRecord.heldCount, 1)
        XCTAssertEqual(heldRecord.exampleFileNames, [file.name])
        XCTAssertTrue(heldRecord.summaryText?.localizedCaseInsensitiveContains("template") == true)
        XCTAssertTrue(heldRecord.heldBuckets.contains { $0.bucket.localizedCaseInsensitiveContains("template") && $0.count == 1 })
    }

    @MainActor
    func testAutomationEngine_PostPreflightSkippedCountFeedsNotificationSummary() async throws {
        let sourceRoot = try TemporaryDirectory()
        defer { sourceRoot.cleanup() }

        let destinationRoot = try TemporaryDirectory()
        defer { destinationRoot.cleanup() }

        let destination = try Destination.folder(
            from: try destinationRoot.createDirectory(name: "Receipts Archive"),
            displayName: "Receipts Archive"
        )

        let container = try makeAutomationContainer()
        let context = container.mainContext
        let scopeService = TrustedAutomationScopeService(modelContext: context)
        let provider = MockFileScanProvider()
        let coordinator = RecordingOrganizationCoordinator()
        let workflowExecution = WorkflowExecutionSpy()
        let notificationService = RecordingNotificationService()
        let engine = makeEngine(
            workflowExecution: workflowExecution.client,
            notificationService: notificationService,
            notificationsEnabled: true
        )

        let templatedFile = try makeFile(
            sourceRoot: sourceRoot,
            relativeParentPath: "templated",
            fileName: "Receipt-Template.pdf",
            destination: destination
        )
        let untemplatedFile = try makeFile(
            sourceRoot: sourceRoot,
            relativeParentPath: "legacy",
            fileName: "Receipt-Legacy.pdf",
            destination: destination
        )
        context.insert(templatedFile)
        context.insert(untemplatedFile)

        _ = try makeFolderScope(
            service: scopeService,
            sourceRoot: sourceRoot,
            relativeParentPath: "templated",
            displayName: "Templated Receipts",
            destination: destination,
            selectedWorkflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts
        )
        _ = try makeFolderScope(
            service: scopeService,
            sourceRoot: sourceRoot,
            relativeParentPath: "legacy",
            displayName: "Legacy Receipts",
            destination: destination
        )

        provider.autoOrganizeCandidates = [templatedFile, untemplatedFile]
        engine.configure(
            modelContext: context,
            organizationCoordinator: coordinator,
            scanProvider: provider
        )

        await engine.triggerAutoOrganize()

        let summary = try XCTUnwrap(notificationService.scopedAutoOrganizeSummaries.first)
        XCTAssertEqual(summary.success, 1)
        XCTAssertEqual(summary.failed, 0)
        XCTAssertEqual(summary.skipped, 1)
        XCTAssertEqual(summary.groupedScopeCount, 2)
    }

    @MainActor
    func testPerformAutoOrganize_SuppressesGenericSummaryWhenPlannedWorkflowNotifyExists() async throws {
        let sourceRoot = try TemporaryDirectory()
        defer { sourceRoot.cleanup() }

        let destinationRoot = try TemporaryDirectory()
        defer { destinationRoot.cleanup() }

        let destination = try Destination.folder(
            from: try destinationRoot.createDirectory(name: "Project Archive"),
            displayName: "Project Archive"
        )

        let container = try makeAutomationContainer()
        let context = container.mainContext
        let scopeService = TrustedAutomationScopeService(modelContext: context)
        let provider = MockFileScanProvider()
        let coordinator = RecordingOrganizationCoordinator()
        let workflowExecution = WorkflowExecutionSpy()
        let notificationService = RecordingNotificationService()
        let planExpectation = expectation(description: "scheduled notify-eligible workflow plan")
        workflowExecution.onPlan = { planExpectation.fulfill() }
        let scheduledPolicy = AutomationPolicy(
            userMode: .scanAndOrganize,
            effectiveMode: .scanAndOrganize,
            scanIntervalMinutes: 30,
            scanOnLaunch: true,
            backlogThreshold: FormaConfig.Automation.backlogThreshold,
            ageThresholdDays: FormaConfig.Automation.ageThresholdDays,
            mlConfidenceThreshold: FormaConfig.Automation.mlAutoOrganizeConfidenceMinimum,
            maxConsecutiveFailures: FormaConfig.Automation.maxConsecutiveFailures,
            notificationsEnabled: true,
            backlogReminderCooldownHours: FormaConfig.Automation.backlogReminderCooldownHours,
            errorNotificationCooldownMinutes: FormaConfig.Automation.errorNotificationCooldownMinutes
        )
        let engine = AutomationEngine(
            notificationService: notificationService,
            clock: FixedClock(now: Date(timeIntervalSince1970: 1_700_000_000)),
            policyResolver: { scheduledPolicy },
            workflowExecution: workflowExecution.client
        )

        let file = try makeFile(
            sourceRoot: sourceRoot,
            relativeParentPath: "project-drop",
            fileName: "UI Kit.sketch",
            destination: destination
        )
        context.insert(file)

        let scope = try makeFolderScope(
            service: scopeService,
            sourceRoot: sourceRoot,
            relativeParentPath: "project-drop",
            displayName: "Design Assets",
            destination: destination,
            selectedWorkflowTemplateID: BuiltInWorkflowTemplate.StableID.projectDrop
        )

        provider.autoOrganizeCandidates = [file]
        engine.configure(
            modelContext: context,
            organizationCoordinator: coordinator,
            scanProvider: provider
        )

        engine.start()
        await fulfillment(of: [planExpectation], timeout: 1.0)

        let scheduledRecordsDeadline = Date().addingTimeInterval(1.0)
        while Date() < scheduledRecordsDeadline {
            let records = try context.fetch(
                FetchDescriptor<TrustedAutomationScopeRunRecord>(
                    sortBy: [SortDescriptor(\.startedAt, order: .forward)]
                )
            ).filter { $0.scopeID == scope.id }

            if records.count >= 2 {
                XCTAssertEqual(records.map(\.status), [.simulated, .executed])
                break
            }

            try await Task.sleep(for: .milliseconds(10))
        }

        let finalScheduledRecords = try context.fetch(
            FetchDescriptor<TrustedAutomationScopeRunRecord>(
                sortBy: [SortDescriptor(\.startedAt, order: .forward)]
            )
        ).filter { $0.scopeID == scope.id }
        XCTAssertEqual(finalScheduledRecords.map(\.status), [.simulated, .executed])

        XCTAssertEqual(workflowExecution.plannedTemplateIDs, [BuiltInWorkflowTemplate.StableID.projectDrop])
        XCTAssertEqual(
            workflowExecution.plannedInvocationContexts,
            [.trustedScopeScheduled(scopeDisplayName: "Design Assets")]
        )
        XCTAssertTrue(notificationService.scopedAutoOrganizeSummaries.isEmpty)
        engine.stop()
    }

    @MainActor
    func testWorkflowInvocationContext_MapsTrustedScopeTriggerSources() {
        let engine = makeEngine()

        XCTAssertEqual(
            engine.workflowInvocationContext(
                for: .scheduledAutomationPass,
                scopeDisplayName: "Receipts"
            ),
            .trustedScopeScheduled(scopeDisplayName: "Receipts")
        )
        XCTAssertEqual(
            engine.workflowInvocationContext(
                for: .realtimeAutomationPass,
                scopeDisplayName: "Receipts"
            ),
            .trustedScopeRealtime(scopeDisplayName: "Receipts")
        )
        XCTAssertEqual(
            engine.workflowInvocationContext(
                for: .manualRefreshInspection,
                scopeDisplayName: "Receipts"
            ),
            .trustedScopeInspection(scopeDisplayName: "Receipts")
        )
    }

    @MainActor
    func testPerformAutoOrganize_KeepsGenericSummaryWhenTemplateDoesNotPlanNotify() async throws {
        let sourceRoot = try TemporaryDirectory()
        defer { sourceRoot.cleanup() }

        let destinationRoot = try TemporaryDirectory()
        defer { destinationRoot.cleanup() }

        let destination = try Destination.folder(
            from: try destinationRoot.createDirectory(name: "Receipts Archive"),
            displayName: "Receipts Archive"
        )

        let container = try makeAutomationContainer()
        let context = container.mainContext
        let scopeService = TrustedAutomationScopeService(modelContext: context)
        let provider = MockFileScanProvider()
        let coordinator = RecordingOrganizationCoordinator()
        let workflowExecution = WorkflowExecutionSpy()
        let notificationService = RecordingNotificationService()
        let engine = makeEngine(
            workflowExecution: workflowExecution.client,
            notificationService: notificationService,
            notificationsEnabled: true
        )

        let file = try makeFile(
            sourceRoot: sourceRoot,
            relativeParentPath: "receipts",
            fileName: "Receipt-October.pdf",
            destination: destination
        )
        context.insert(file)

        _ = try makeFolderScope(
            service: scopeService,
            sourceRoot: sourceRoot,
            relativeParentPath: "receipts",
            displayName: "Receipts",
            destination: destination,
            selectedWorkflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts
        )

        provider.autoOrganizeCandidates = [file]
        engine.configure(
            modelContext: context,
            organizationCoordinator: coordinator,
            scanProvider: provider
        )

        await engine.triggerAutoOrganize()

        let summary = try XCTUnwrap(notificationService.scopedAutoOrganizeSummaries.first)
        XCTAssertEqual(summary.success, 1)
        XCTAssertEqual(summary.failed, 0)
        XCTAssertEqual(summary.skipped, 0)
        XCTAssertEqual(summary.scopeDisplayName, "Receipts")
        XCTAssertEqual(summary.groupedScopeCount, 1)
    }

    @MainActor
    func testAutomationEngine_WorkflowSuccessWithPreflightHeldFilesRecordsExecutedStatus() async throws {
        let sourceRoot = try TemporaryDirectory()
        defer { sourceRoot.cleanup() }

        let destinationRoot = try TemporaryDirectory()
        defer { destinationRoot.cleanup() }

        let destination = try Destination.folder(
            from: try destinationRoot.createDirectory(name: "Receipts Archive"),
            displayName: "Receipts Archive"
        )

        let container = try makeAutomationContainer()
        let context = container.mainContext
        let scopeService = TrustedAutomationScopeService(modelContext: context)
        let provider = MockFileScanProvider()
        let coordinator = RecordingOrganizationCoordinator()
        let workflowExecution = WorkflowExecutionSpy()
        let engine = makeEngine(workflowExecution: workflowExecution.client)

        let readyFile = try makeFile(
            sourceRoot: sourceRoot,
            relativeParentPath: "trusted",
            fileName: "Receipt-October.pdf",
            destination: destination
        )
        let heldFile = try makeFile(
            sourceRoot: sourceRoot,
            relativeParentPath: "trusted",
            fileName: "Receipt-LowConfidence.pdf",
            destination: destination,
            confidenceScore: 0.20
        )
        context.insert(readyFile)
        context.insert(heldFile)

        let scope = try makeFolderScope(
            service: scopeService,
            sourceRoot: sourceRoot,
            relativeParentPath: "trusted",
            displayName: "Receipts",
            destination: destination,
            selectedWorkflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts
        )

        provider.autoOrganizeCandidates = [readyFile, heldFile]
        engine.configure(
            modelContext: context,
            organizationCoordinator: coordinator,
            scanProvider: provider
        )

        await engine.triggerAutoOrganize()

        let records = try context.fetch(
            FetchDescriptor<TrustedAutomationScopeRunRecord>(
                sortBy: [SortDescriptor(\.startedAt, order: .forward)]
            )
        ).filter { $0.scopeID == scope.id }

        XCTAssertEqual(records.map(\.status), [.simulated, .executed])

        let executedRecord = try XCTUnwrap(records.last)
        XCTAssertEqual(executedRecord.organizedCount, 1)
        XCTAssertEqual(executedRecord.heldCount, 1)
        XCTAssertEqual(executedRecord.failedCount, 0)
    }

    @MainActor
    func testAutomationEngine_WorkflowFailureWithPreflightHeldFilesRecordsFailedStatus() async throws {
        let sourceRoot = try TemporaryDirectory()
        defer { sourceRoot.cleanup() }

        let destinationRoot = try TemporaryDirectory()
        defer { destinationRoot.cleanup() }

        let destination = try Destination.folder(
            from: try destinationRoot.createDirectory(name: "Receipts Archive"),
            displayName: "Receipts Archive"
        )

        let container = try makeAutomationContainer()
        let context = container.mainContext
        let scopeService = TrustedAutomationScopeService(modelContext: context)
        let provider = MockFileScanProvider()
        let coordinator = RecordingOrganizationCoordinator()
        let workflowExecution = WorkflowExecutionSpy()
        workflowExecution.runError = WorkflowExecutionFailure()
        let engine = makeEngine(workflowExecution: workflowExecution.client)

        let readyFile = try makeFile(
            sourceRoot: sourceRoot,
            relativeParentPath: "trusted",
            fileName: "Receipt-November.pdf",
            destination: destination
        )
        let heldFile = try makeFile(
            sourceRoot: sourceRoot,
            relativeParentPath: "trusted",
            fileName: "Receipt-LowConfidence-2.pdf",
            destination: destination,
            confidenceScore: 0.20
        )
        context.insert(readyFile)
        context.insert(heldFile)

        let scope = try makeFolderScope(
            service: scopeService,
            sourceRoot: sourceRoot,
            relativeParentPath: "trusted",
            displayName: "Receipts",
            destination: destination,
            selectedWorkflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts
        )

        provider.autoOrganizeCandidates = [readyFile, heldFile]
        engine.configure(
            modelContext: context,
            organizationCoordinator: coordinator,
            scanProvider: provider
        )

        await engine.triggerAutoOrganize()

        let records = try context.fetch(
            FetchDescriptor<TrustedAutomationScopeRunRecord>(
                sortBy: [SortDescriptor(\.startedAt, order: .forward)]
            )
        ).filter { $0.scopeID == scope.id }

        XCTAssertEqual(records.map(\.status), [.simulated, .failed])

        let failedRecord = try XCTUnwrap(records.last)
        XCTAssertEqual(failedRecord.organizedCount, 0)
        XCTAssertEqual(failedRecord.heldCount, 1)
        XCTAssertEqual(failedRecord.failedCount, 1)
        XCTAssertTrue(failedRecord.summaryText?.localizedCaseInsensitiveContains("failed") == true)
        XCTAssertFalse(failedRecord.summaryText?.contains("Organized 0") == true)
    }

    @MainActor
    private func makeEngine(
        workflowExecution: WorkflowExecutionClient = .live,
        notificationService: AutomationNotificationServing = SilentNotificationService(),
        notificationsEnabled: Bool = false
    ) -> AutomationEngine {
        AutomationEngine(
            notificationService: notificationService,
            clock: FixedClock(now: Date(timeIntervalSince1970: 1_700_000_000)),
            policyResolver: { self.makePolicy(notificationsEnabled: notificationsEnabled) },
            workflowExecution: workflowExecution
        )
    }

    private func makePolicy(notificationsEnabled: Bool = false) -> AutomationPolicy {
        AutomationPolicy(
            userMode: .scanAndOrganize,
            effectiveMode: .scanAndOrganize,
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

    private func makeAutomationContainer() throws -> ModelContainer {
        try ModelContainer(
            for: FileItem.self,
            Rule.self,
            ActivityItem.self,
            TrustedAutomationScope.self,
            TrustedAutomationScopeRunRecord.self,
            WorkflowRunRecord.self,
            WorkflowStepRunRecord.self,
            WorkflowFileActionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeFile(
        sourceRoot: TemporaryDirectory,
        relativeParentPath: String,
        fileName: String,
        destination: Destination,
        confidenceScore: Double = 0.99
    ) throws -> FileItem {
        let sourceURL = try sourceRoot.createFile(name: "\(relativeParentPath)/\(fileName)")
        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 512,
            creationDate: Date(timeIntervalSince1970: 1_700_000_000),
            location: .downloads,
            scanRootPath: sourceRoot.url.path,
            relativeParentPath: relativeParentPath,
            destination: destination,
            originalSuggestedDestination: destination,
            status: .pending
        )
        file.confidenceScore = confidenceScore
        return file
    }

    @MainActor
    private func makeFolderScope(
        service: TrustedAutomationScopeService,
        sourceRoot: TemporaryDirectory,
        relativeParentPath: String,
        displayName: String,
        destination: Destination,
        selectedWorkflowTemplateID: String? = nil
    ) throws -> TrustedAutomationScope {
        try service.createOrReactivateScope(
            scopeType: .folder,
            scopeKey: "\(sourceRoot.url.path)|\(relativeParentPath)",
            displayName: displayName,
            boundaryDescriptor: .folder(
                source: .init(
                    sourceLocation: .downloads,
                    scanRootPath: sourceRoot.url.path,
                    relativeParentPath: relativeParentPath
                ),
                destination: .init(destination)
            ),
            promotionSource: .reviewFlow,
            recommendationSource: .repeatedReviewAcceptance,
            acceptedEvidenceCount: 4,
            overrideEvidenceCount: 0,
            undoEvidenceCount: 0,
            confidenceSnapshot: 0.93,
            rationaleSummary: "Repeated trusted review decisions.",
            allowedActions: [.move],
            selectedWorkflowTemplateID: selectedWorkflowTemplateID
        )
    }
}
