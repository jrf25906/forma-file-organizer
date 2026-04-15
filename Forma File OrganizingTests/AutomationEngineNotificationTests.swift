import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class AutomationEngineNotificationTests: XCTestCase {
    override func tearDown() {
        FeatureFlagService.shared.resetToDefaults()
        super.tearDown()
    }

    func testWorkflowInvocationContext_ProjectPolicyScheduledAllowsNotify() {
        XCTAssertTrue(
            WorkflowInvocationContext.projectPolicyScheduled(
                projectLabel: "Alpha",
                policyName: "Project Drop Zone"
            ).allowsWorkflowNotify
        )
    }

    func testWorkflowInvocationContext_ProjectPolicyManualDoesNotAllowNotify() {
        XCTAssertFalse(
            WorkflowInvocationContext.projectPolicyManual(
                projectLabel: "Alpha",
                policyName: "Project Drop Zone"
            ).allowsWorkflowNotify
        )
    }

    func testWorkflowNotificationPayload_UsesProjectPolicyCopyForScheduledRuns() throws {
        let payload = try XCTUnwrap(
            NotificationService.workflowNotificationPayload(
                templateID: BuiltInWorkflowTemplate.StableID.projectDrop,
                invocationContext: .projectPolicyScheduled(
                    projectLabel: "Alpha",
                    policyName: "Project Drop Zone"
                ),
                organizedFileCount: 2
            )
        )

        XCTAssertEqual(payload.title, "Project Drop Zone Made Progress")
        XCTAssertTrue(payload.body.contains("for Alpha"))
        XCTAssertTrue(payload.body.contains("project policy"))
        XCTAssertFalse(payload.body.localizedCaseInsensitiveContains("trusted scope"))
    }

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
        var onScopedSummary: (() -> Void)?

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
            onScopedSummary?()
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
        private(set) var plannedInvocationContexts: [WorkflowInvocationContext] = []
        private(set) var plannedRequests: [WorkflowExecutionRequest] = []
        var failingFileNames: Set<String> = []
        var runError: Error?

        lazy var client = WorkflowExecutionClient(
            planRequest: { request, files in
                self.plannedInvocationContexts.append(request.invocationContext)
                self.plannedRequests.append(request)
                return WorkflowPlanner().plan(
                    templateID: request.templateID,
                    files: files,
                    invocationContext: request.invocationContext
                )
            },
            runRequest: { [weak self] request, plan, files, _ in
                let fileNames = files.map(\.name)
                let shouldFail = await MainActor.run {
                    fileNames.contains { self?.failingFileNames.contains($0) == true }
                }
                guard shouldFail else {
                    return WorkflowRunRecord(
                        scopeID: request.scopeID,
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
                    scopeID: request.scopeID,
                    workflowTemplateID: plan.definition.templateID,
                    primaryStatus: .completedWithIssues,
                    startedAt: Date(timeIntervalSince1970: 1_000),
                    endedAt: Date(timeIntervalSince1970: 1_001)
                )
            }
        )
    }

    @MainActor
    private final class MockFileMonitor: FileMonitoring {
        private(set) var isMonitoring = false
        private var currentFolders: [WatchedFolderDescriptor] = []
        private var onChange: (@MainActor (WatchedFolderChangeSet) -> Void)?

        func startMonitoring(
            folders: [WatchedFolderDescriptor],
            onChange: @escaping @MainActor (WatchedFolderChangeSet) -> Void
        ) {
            isMonitoring = true
            currentFolders = folders
            self.onChange = onChange
        }

        func updateMonitoredFolders(_ folders: [WatchedFolderDescriptor]) {
            currentFolders = folders
        }

        func stopMonitoring() {
            isMonitoring = false
            currentFolders = []
            onChange = nil
        }

        func simulateChange(_ folders: Set<FolderLocation>) async {
            guard let onChange else { return }
            let touchedRoots = Set(
                currentFolders
                    .filter { folders.contains($0.location) }
                    .map(\.standardizedRootPath)
            )
            await MainActor.run {
                onChange(
                    WatchedFolderChangeSet(
                        touchedRoots: touchedRoots,
                        requiresFallbackRootScan: true
                    )
                )
            }
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

    func testRealtimeProjectPolicyNotifyDoesNotSuppressTrustedScopeSummary() async throws {
        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.autoProjectAssociation, true)
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)
        FeatureFlagService.shared.setEnabled(.projectSpaceMemory, true)
        FeatureFlagService.shared.setEnabled(.workflowEngineV2, true)
        FeatureFlagService.shared.setEnabled(.backgroundMonitoring, true)
        FeatureFlagService.shared.setEnabled(.autoOrganize, true)
        FeatureFlagService.shared.setEnabled(.projectSpaceAutomationBoard, true)

        let sourceRoot = try TemporaryDirectory()
        defer { sourceRoot.cleanup() }

        let destinationRoot = try TemporaryDirectory()
        defer { destinationRoot.cleanup() }

        let trustedDestinationURL = try destinationRoot.createDirectory(name: "Receipts Archive")
        let projectDestinationURL = try destinationRoot.createDirectory(name: "Projects")
        let trustedDestination = try Destination.folder(from: trustedDestinationURL, displayName: "Receipts Archive")
        let projectDestination = try Destination.folder(from: projectDestinationURL, displayName: "Projects")

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
        let summaryExpectation = expectation(description: "trusted summary emitted")
        notificationService.onScopedSummary = {
            summaryExpectation.fulfill()
        }
        let workflowExecution = WorkflowExecutionSpy()
        let fileMonitor = MockFileMonitor()

        let trustedFileURL = try sourceRoot.createFile(name: "receipts/Receipt-June.pdf")
        let trustedFile = FileItem(
            path: trustedFileURL.path,
            sizeInBytes: 128,
            creationDate: Date(timeIntervalSince1970: 1_700_000_000),
            location: .downloads,
            scanRootPath: sourceRoot.url.path,
            relativeParentPath: "receipts",
            destination: trustedDestination,
            originalSuggestedDestination: trustedDestination,
            status: .pending
        )
        trustedFile.confidenceScore = 0.99

        let projectFileURL = try sourceRoot.createFile(name: "projects/brief.md")
        let projectFile = FileItem(
            path: projectFileURL.path,
            sizeInBytes: 128,
            creationDate: Date(timeIntervalSince1970: 1_700_000_000),
            location: .downloads,
            scanRootPath: sourceRoot.url.path,
            relativeParentPath: "projects",
            destination: projectDestination,
            originalSuggestedDestination: projectDestination,
            status: .pending
        )
        projectFile.confidenceScore = 0.99

        let container = try ModelContainer(
            for: FileItem.self,
            Rule.self,
            ActivityItem.self,
            TrustedAutomationScope.self,
            TrustedAutomationScopeRunRecord.self,
            FileMetadataRecord.self,
            FileOrganizationHistoryEntry.self,
            ProjectSpaceWorkflowProfile.self,
            ProjectSpaceAutomationProfile.self,
            ProjectSpaceAutomationPolicy.self,
            ProjectSpaceAutomationRunRecord.self,
            WorkflowRunRecord.self,
            WorkflowStepRunRecord.self,
            WorkflowFileActionRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        context.insert(trustedFile)
        context.insert(projectFile)

        let scopeService = TrustedAutomationScopeService(modelContext: context)
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
                destination: .init(trustedDestination)
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

        let automationService = ProjectSpaceAutomationService(modelContext: context)
        let projectPolicy = try automationService.createOrUpdatePolicy(
            normalizedProjectLabel: "Alpha",
            workflowTemplateID: BuiltInWorkflowTemplate.StableID.projectDrop,
            triggerKinds: [.folderWatch],
            admissionMode: .manualReview,
            state: .active,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )

        let projectSpaceDetail = ProjectSpaceDetail(
            summary: ProjectSpaceSummary(
                normalizedLabel: "Alpha",
                fileCount: 1,
                lastActivityAt: Date(timeIntervalSince1970: 1_700_000_000),
                sourceFolderHints: ["Alpha"]
            ),
            files: [
                ProjectSpaceFileRow(
                    canonicalIdentity: "alpha-existing",
                    path: projectFile.path,
                    displayName: projectFile.name,
                    projectAssociation: "Alpha",
                    sourceFolderHint: "Alpha"
                )
            ],
            overview: ProjectSpaceOverview(
                currentFileCount: 1,
                activeFolderCount: 1,
                activeFolderHints: ["Alpha"]
            ),
            preferredDestinations: [],
            recentActivity: []
        )

        let engine = makeEngine(
            policy: policy,
            notificationService: notificationService,
            workflowExecution: workflowExecution.client,
            fileMonitor: fileMonitor,
            watchedFoldersProvider: {
                [
                    WatchedFolderDescriptor(
                        location: .downloads,
                        rootURL: sourceRoot.url
                    )
                ]
            },
            projectSpaceDetailReader: { _, normalizedProjectLabel in
                normalizedProjectLabel == "Alpha" ? projectSpaceDetail : nil
            }
        )

        let coordinator = RecordingOrganizationCoordinator()
        let provider = MockFileScanProvider()
        provider.autoOrganizeCandidates = [trustedFile, projectFile]
        engine.configure(
            modelContext: context,
            organizationCoordinator: coordinator,
            scanProvider: provider
        )
        engine.start()

        await fileMonitor.simulateChange([.downloads])
        await fulfillment(of: [summaryExpectation], timeout: 1.0)

        XCTAssertEqual(notificationService.scopedAutoOrganizeSummaries.count, 1)
        XCTAssertEqual(notificationService.scopedAutoOrganizeSummaries.first?.scopeDisplayName, "Receipts")
        XCTAssertEqual(notificationService.scopedAutoOrganizeSummaries.first?.groupedScopeCount, 1)
        XCTAssertTrue(
            workflowExecution.plannedInvocationContexts.contains(
                .projectPolicyRealtime(projectLabel: "Alpha", policyName: "Project Drop Zone")
            )
        )
        let request = try XCTUnwrap(
            workflowExecution.plannedRequests.first(where: {
                if case .projectPolicy = $0.entryPoint { return true }
                return false
            })
        )
        guard case let .projectPolicy(policyID, triggerKind, projectLabel, policyName) = request.entryPoint else {
            XCTFail("Expected realtime project-policy execution request")
            return
        }
        XCTAssertEqual(policyID, projectPolicy.id)
        XCTAssertEqual(triggerKind, .folderWatch)
        XCTAssertEqual(projectLabel, "Alpha")
        XCTAssertEqual(policyName, "Project Drop Zone")
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
        workflowExecution: WorkflowExecutionClient = .live,
        fileMonitor: FileMonitoring = FileMonitorService(),
        watchedFoldersProvider: (@MainActor () -> [WatchedFolderDescriptor])? = nil,
        projectSpaceDetailReader: (@MainActor (ModelContext, String) -> ProjectSpaceDetail?)? = nil
    ) -> AutomationEngine {
        AutomationEngine(
            notificationService: notificationService,
            clock: FixedClock(now: Date(timeIntervalSince1970: 1_700_000_000)),
            policyResolver: { policy },
            fileMonitor: fileMonitor,
            watchedFoldersProvider: watchedFoldersProvider,
            workflowExecution: workflowExecution,
            projectSpaceDetailReader: projectSpaceDetailReader
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
