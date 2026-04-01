import Foundation
import Testing
import SwiftData
@testable import Forma_File_Organizing

/// Integration tests for the Automation v1.4 feature.
///
/// Tests the full flow from scan → auto-organize → undo to ensure
/// all components work together correctly.
///
/// Uses Swift Testing framework for better @MainActor support with SwiftData.
@Suite(.serialized)
struct AutomationIntegrationTests {

    private func requireIntegration() -> Bool {
        TestGating.isIntegrationEnabled
    }

    // MARK: - Activity Logging Tests

    @Test
    func automationActivityType_ClassifiesToneBuckets() {
        #expect(ActivityItem.ActivityType.automationAutoOrganized.toneCategory == .progressWin)
        #expect(ActivityItem.ActivityType.automationScanCompleted.toneCategory == .reminder)
        #expect(ActivityItem.ActivityType.automationError.toneCategory == .errorOrPermission)
    }

    /// Test: Automation scan completed is logged correctly
    @Test @MainActor
    func activityLogging_ScanCompleted() async throws {
        guard requireIntegration() else { return }
        // Given: Activity logging service with fresh container
        let container = try ModelContainer(
            for: ActivityItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let loggingService = ActivityLoggingService(modelContext: context)

        // When: Logging a scan completion
        loggingService.logAutomationScanCompleted(filesScanned: 100, newPending: 5)
        try context.save()

        // Then: Activity should be recorded
        let descriptor = FetchDescriptor<ActivityItem>()
        let activities = try context.fetch(descriptor)
        let scanActivities = activities.filter { $0.activityType == .automationScanCompleted }

        #expect(scanActivities.count == 1)
        #expect(scanActivities.first?.fileName == "100 files")
        #expect(scanActivities.first?.details == "Queued 5 new files for your next review pass.")
    }

    /// Test: Auto-organize batch is logged with correct counts
    @Test @MainActor
    func activityLogging_AutoOrganizeBatch() async throws {
        guard requireIntegration() else { return }
        // Given: Activity logging service with fresh container
        let container = try ModelContainer(
            for: ActivityItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let loggingService = ActivityLoggingService(modelContext: context)

        // When: Logging an auto-organize batch
        loggingService.logAutoOrganizeBatch(successCount: 10, failedCount: 2, skippedCount: 3)
        try context.save()

        // Then: Activity should be recorded with correct details
        let descriptor = FetchDescriptor<ActivityItem>()
        let activities = try context.fetch(descriptor)
        let batchActivities = activities.filter { $0.activityType == .automationAutoOrganized }

        #expect(batchActivities.count == 1)
        #expect(batchActivities.first?.details == "Cleared 10 files from the queue automatically. 2 still need attention. 3 are still waiting for review. Automatic changes are final.")
    }

    @Test @MainActor
    func activityLogging_AutoOrganizeBatch_ExplainsWhyAndUndo() throws {
        guard requireIntegration() else { return }

        let container = try ModelContainer(
            for: ActivityItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let loggingService = ActivityLoggingService(modelContext: context)

        loggingService.logAutoOrganizeBatch(
            successCount: 3,
            failedCount: 1,
            skippedCount: 2,
            skippedMissingDestination: 1,
            skippedPermissionIssues: 1,
            skippedConfidenceThreshold: 0,
            undoAvailable: true
        )

        let activities = try context.fetch(FetchDescriptor<ActivityItem>())
        let batch = try #require(activities.first { $0.activityType == .automationAutoOrganized })
        #expect(batch.details.contains("automatic"))
        #expect(batch.details.contains("Undo available"))
        #expect(batch.details.contains("missing destination"))
        #expect(batch.details.contains("permission"))
    }

    @Test @MainActor
    func activityLogging_AutoOrganizeBatch_IncludesExcludedFromAutomationReason() throws {
        guard requireIntegration() else { return }

        let container = try ModelContainer(
            for: ActivityItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let loggingService = ActivityLoggingService(modelContext: context)

        loggingService.logAutoOrganizeBatch(
            successCount: 2,
            failedCount: 0,
            skippedCount: 2,
            skippedMissingDestination: 1,
            skippedPermissionIssues: 0,
            skippedConfidenceThreshold: 0,
            skippedExcludedFromAutomation: 1,
            undoAvailable: false
        )

        let activities = try context.fetch(FetchDescriptor<ActivityItem>())
        let batch = try #require(activities.first { $0.activityType == .automationAutoOrganized })
        #expect(batch.details.contains("held back before the automatic pass"))
        #expect(batch.details.contains("missing destination"))
        #expect(batch.details.contains("excluded from automation"))
    }

    /// Test: Automation error is logged correctly
    @Test @MainActor
    func activityLogging_AutomationError() async throws {
        guard requireIntegration() else { return }
        // Given: Activity logging service with fresh container
        let container = try ModelContainer(
            for: ActivityItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let loggingService = ActivityLoggingService(modelContext: context)

        // When: Logging an automation error
        loggingService.logAutomationError(type: .permissionDenied, message: "Access to folder denied")
        try context.save()

        // Then: Activity should be recorded
        let descriptor = FetchDescriptor<ActivityItem>()
        let activities = try context.fetch(descriptor)
        let errorActivities = activities.filter { $0.activityType == .automationError }

        #expect(errorActivities.count == 1)
        #expect(errorActivities.first?.fileName == "Permission Needed")
        #expect(errorActivities.first?.details == "Forma needs macOS permission before it can keep organizing here. Access to folder denied.")
    }

    /// Test: Automation paused/resumed is logged correctly
    @Test @MainActor
    func activityLogging_PauseResume() async throws {
        guard requireIntegration() else { return }
        // Given: Activity logging service with fresh container
        let container = try ModelContainer(
            for: ActivityItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let loggingService = ActivityLoggingService(modelContext: context)

        // When: Logging pause and resume
        loggingService.logAutomationPaused(reason: "User requested pause")
        loggingService.logAutomationResumed()
        try context.save()

        // Then: Both activities should be recorded
        let descriptor = FetchDescriptor<ActivityItem>()
        let activities = try context.fetch(descriptor)
        let pauseActivities = activities.filter { $0.activityType == .automationPaused }
        let resumeActivities = activities.filter { $0.activityType == .automationResumed }

        #expect(pauseActivities.count == 1)
        #expect(resumeActivities.count == 1)
        #expect(pauseActivities.first?.details == "User requested pause")
    }

    @Test
    func activityAuditBadges_PauseResumeRemainManual() {
        let pause = ActivityItem(
            activityType: .automationPaused,
            fileName: "Automation",
            details: "Paused by user"
        )
        let resume = ActivityItem(
            activityType: .automationResumed,
            fileName: "Automation",
            details: "Resumed by user"
        )
        let automatic = ActivityItem(
            activityType: .automationAutoOrganized,
            fileName: "Auto-Organize",
            details: "Cleared 3 files from the queue automatically. Undo available for the last automatic batch."
        )

        #expect(ActivityAuditBadgeClassifier.titles(for: pause).contains("Automatic") == false)
        #expect(ActivityAuditBadgeClassifier.titles(for: resume).contains("Automatic") == false)
        #expect(ActivityAuditBadgeClassifier.titles(for: automatic) == ["Automatic", "Undo Available"])
    }

    // MARK: - Trust Infrastructure Tests

    @Test
    func ruleSimulation_DoesNotMutateOriginalFileState() throws {
        guard requireIntegration() else { return }

        let engine = RuleEngine()
        let rule = TestRule(
            conditionType: .fileExtension,
            conditionValue: "pdf",
            destination: .mockFolder("Finance")
        )
        let original = TestFileItem(
            name: "invoice.pdf",
            fileExtension: "pdf",
            path: "/tmp/invoice.pdf",
            destination: nil,
            status: .pending,
            matchReason: nil,
            confidenceScore: nil
        )

        let summary = engine.simulateRule(rule, across: [original], exampleLimit: 3)

        #expect(summary.matchCount == 1)
        #expect(summary.examples.count == 1)
        #expect(original.destination == nil)
        #expect(original.status == .pending)
        #expect(original.matchReason == nil)
        #expect(original.confidenceScore == nil)
    }

    @Test
    func fileInspectorRuleSimulationRefreshToken_ChangesWhenFileSetChangesWithoutCountChange() {
        let selected = TestFileItem(
            path: "/tmp/invoice.pdf",
            destination: .mockFolder("Finance"),
            status: .pending,
            confidenceScore: 0.9,
            sizeInBytes: 10
        )
        let unchangedCompanion = TestFileItem(path: "/tmp/notes.txt", sizeInBytes: 20)
        let changedCompanion = TestFileItem(
            name: "receipt.pdf",
            fileExtension: "pdf",
            path: "/tmp/receipt.pdf",
            destination: .mockFolder("Finance"),
            status: .pending,
            confidenceScore: 0.92,
            sizeInBytes: 25
        )
        let rule = TestRule(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000111") ?? UUID(),
            conditionType: .fileExtension,
            conditionValue: "pdf",
            destination: .mockFolder("Finance")
        )

        let first = FileInspectorRuleSimulationRefreshToken(
            selectedFiles: [selected],
            matchingRule: rule,
            allFiles: [selected, unchangedCompanion]
        )
        let second = FileInspectorRuleSimulationRefreshToken(
            selectedFiles: [selected],
            matchingRule: rule,
            allFiles: [selected, changedCompanion]
        )

        #expect(first != second)
    }

    @Test
    func fileInspectorRuleSimulationRefreshToken_ChangesWhenRuleDestinationChanges() {
        let selected = TestFileItem(
            path: "/tmp/invoice.pdf",
            destination: .mockFolder("Finance"),
            status: .pending,
            confidenceScore: 0.9,
            sizeInBytes: 10
        )
        let companion = TestFileItem(path: "/tmp/receipt.pdf", sizeInBytes: 20)
        let ruleID = UUID(uuidString: "00000000-0000-0000-0000-000000000222") ?? UUID()
        let financeRule = TestRule(
            id: ruleID,
            conditionType: .fileExtension,
            conditionValue: "pdf",
            destination: .mockFolder("Finance")
        )
        let archiveRule = TestRule(
            id: ruleID,
            conditionType: .fileExtension,
            conditionValue: "pdf",
            destination: .mockFolder("Archive")
        )

        let first = FileInspectorRuleSimulationRefreshToken(
            selectedFiles: [selected],
            matchingRule: financeRule,
            allFiles: [selected, companion]
        )
        let second = FileInspectorRuleSimulationRefreshToken(
            selectedFiles: [selected],
            matchingRule: archiveRule,
            allFiles: [selected, companion]
        )

        #expect(first != second)
    }

    @Test @MainActor
    func automationPreflight_CategorizesSkippedItems() throws {
        guard requireIntegration() else { return }

        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }
        let docsURL = try tempDirectory.createDirectory(name: "Docs")
        let docsDestination = try Destination.folder(from: docsURL, displayName: "Docs")

        let container = try ModelContainer(
            for: FileItem.self, Rule.self, ActivityItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )

        let eligible = FileItem(
            path: "/tmp/eligible.pdf",
            sizeInBytes: 1_024,
            creationDate: Date(),
            destination: docsDestination,
            status: .ready
        )
        eligible.confidenceScore = 0.96

        let missingDestination = FileItem(
            path: "/tmp/missing.pdf",
            sizeInBytes: 1_024,
            creationDate: Date(),
            destination: nil,
            status: .ready
        )
        missingDestination.confidenceScore = 0.96

        let blocked = FileItem(
            path: "/tmp/blocked.pdf",
            sizeInBytes: 1_024,
            creationDate: Date(),
            destination: .folder(bookmark: Data(), displayName: "Archive"),
            status: .ready
        )
        blocked.confidenceScore = 0.96

        let lowConfidence = FileItem(
            path: "/tmp/maybe.pdf",
            sizeInBytes: 1_024,
            creationDate: Date(),
            destination: docsDestination,
            status: .ready
        )
        lowConfidence.confidenceScore = 0.42

        let excluded = FileItem(
            path: "/tmp/excluded.pdf",
            sizeInBytes: 1_024,
            creationDate: Date(),
            destination: docsDestination,
            status: .ready
        )
        excluded.confidenceScore = 0.96
        excluded.location = .desktop

        var desktopFolder = BookmarkFolder(folderType: .desktop)
        let originalDesktopExclusion = desktopFolder.isExcludedFromAutomation
        desktopFolder.isExcludedFromAutomation = true
        defer { desktopFolder.isExcludedFromAutomation = originalDesktopExclusion }

        [eligible, missingDestination, blocked, lowConfidence, excluded].forEach(container.mainContext.insert)

        let summary = AutomationEngine.buildPreflightSummary(
            candidates: [eligible, missingDestination, blocked, lowConfidence, excluded],
            confidenceThreshold: 0.9
        )

        #expect(summary.eligibleCount == 1)
        #expect(summary.skippedMissingDestination == 1)
        #expect(summary.skippedPermissionIssues == 1)
        #expect(summary.skippedConfidenceThreshold == 1)
        #expect(summary.skippedExcludedFromAutomation == 1)
    }

    // MARK: - Undo Entry Tests

    /// Test: BulkMoveCommand stores all necessary data for undo
    @Test
    func undoEntry_BulkMoveCommand_StoresRequiredData()  throws {
        guard requireIntegration() else { return }
        // Given: Multiple file move operations
        let operations: [(fileID: String, fromPath: String, toPath: String, originalStatus: FileItem.OrganizationStatus)] = [
            (fileID: "/Desktop/doc1.pdf", fromPath: "/Desktop/doc1.pdf", toPath: "/Documents/doc1.pdf", originalStatus: .ready),
            (fileID: "/Desktop/doc2.pdf", fromPath: "/Desktop/doc2.pdf", toPath: "/Documents/doc2.pdf", originalStatus: .ready),
            (fileID: "/Desktop/doc3.pdf", fromPath: "/Desktop/doc3.pdf", toPath: "/Documents/doc3.pdf", originalStatus: .pending)
        ]

        // When: Creating a BulkMoveCommand
        let command = BulkMoveCommand(
            id: UUID(),
            timestamp: Date(),
            operations: operations
        )

        // Then: Command should store all operations with correct data
        #expect(command.operations.count == 3)
        #expect(command.operations[0].fromPath == "/Desktop/doc1.pdf")
        #expect(command.operations[0].toPath == "/Documents/doc1.pdf")
        #expect(command.operations[2].originalStatus == .pending)
        #expect(command.description == "Move 3 files")
    }

    /// Test: Single file undo command preserves original state
    @Test
    func undoEntry_MoveFileCommand_PreservesOriginalState()  throws {
        guard requireIntegration() else { return }
        // Given: Original file state
        let originalDestination = Destination.mockFolder("Work")

        // When: Creating a MoveFileCommand
        let command = MoveFileCommand(
            id: UUID(),
            timestamp: Date(),
            fileID: "/Desktop/report.pdf",
            fromPath: "/Desktop/report.pdf",
            toPath: "/Documents/Work/report.pdf",
            originalStatus: .ready,
            originalDestination: originalDestination
        )

        // Then: Command should preserve all original state
        #expect(command.fileID == "/Desktop/report.pdf")
        #expect(command.originalStatus == .ready)
        #expect(command.originalDestination?.displayName == "Work")
    }

    // MARK: - AutomationMetrics Tests

    /// Test: AutomationMetrics correctly converts from FileScanResult
    @Test
    func automationMetrics_FromFileScanResult()  throws {
        guard requireIntegration() else { return }
        // Given: A FileScanResult
        let scanResult = FileScanResult(
            totalScanned: 500,
            pendingCount: 50,
            readyCount: 25,
            organizedCount: 400,
            skippedCount: 25,
            oldestPendingAgeDays: 14
        )

        // When: Creating metrics from result
        let metrics = AutomationMetrics(from: scanResult)

        // Then: All values should be correctly copied
        #expect(metrics.totalScanned == 500)
        #expect(metrics.pendingCount == 50)
        #expect(metrics.readyCount == 25)
        #expect(metrics.organizedCount == 400)
        #expect(metrics.skippedCount == 25)
        #expect(metrics.oldestPendingAgeDays == 14)
    }

    /// Test: AutomationMetrics backlog detection
    @Test
    func automationMetrics_BacklogDetection()  throws {
        guard requireIntegration() else { return }
        // Given: Metrics with backlog above threshold
        let metricsWithBacklog = AutomationMetrics(
            totalScanned: 100,
            pendingCount: 60,  // Above threshold of 50
            readyCount: 10,
            organizedCount: 30,
            skippedCount: 0,
            oldestPendingAgeDays: 10
        )

        let metricsNormal = AutomationMetrics(
            totalScanned: 100,
            pendingCount: 30,  // Below threshold
            readyCount: 10,
            organizedCount: 60,
            skippedCount: 0,
            oldestPendingAgeDays: 3
        )

        // Then: Backlog should be detectable via threshold comparison
        #expect(metricsWithBacklog.pendingCount > FormaConfig.Automation.backlogThreshold)
        #expect(metricsNormal.pendingCount < FormaConfig.Automation.backlogThreshold)
    }

    // MARK: - Coordinator Undo Stack Tests

    /// Test: Coordinator starts with empty undo stack
    @Test @MainActor
    func coordinator_StartsWithEmptyUndoStack() async throws {
        guard requireIntegration() else { return }
        // Given/When: Fresh coordinator
        let coordinator = FileOrganizationCoordinator()

        // Then: Undo stack should be empty
        #expect(coordinator.canUndo() == false)
    }

    /// Test: Skip file creates undo entry
    @Test @MainActor
    func coordinator_SkipFile_CreatesUndoEntry() async throws {
        guard requireIntegration() else { return }
        // Given: Fresh coordinator and container
        let container = try ModelContainer(
            for: FileItem.self, Rule.self, ActivityItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let coordinator = FileOrganizationCoordinator()

        let file = FileItem(
            path: "/Desktop/test.pdf",
            sizeInBytes: 1024,
            creationDate: Date(),
            destination: .mockFolder("Documents"),
            status: .ready
        )
        context.insert(file)

        // When: Skipping the file
        coordinator.skipFile(file, context: context)

        // Then: Undo should be available
        #expect(coordinator.canUndo() == true)
        #expect(file.status == .skipped)
    }

    /// Test: Multiple skips can all be undone
    @Test @MainActor
    func coordinator_MultipleSkips_AllUndoable() async throws {
        guard requireIntegration() else { return }
        // Given: Fresh coordinator and container
        let container = try ModelContainer(
            for: FileItem.self, Rule.self, ActivityItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let coordinator = FileOrganizationCoordinator()

        var files: [FileItem] = []
        for i in 1...3 {
            let file = FileItem(
                path: "/Desktop/file\(i).pdf",
                sizeInBytes: 1024,
                creationDate: Date(),
                destination: .mockFolder("Documents"),
                status: .ready
            )
            context.insert(file)
            files.append(file)
        }

        // When: Skipping all files
        for file in files {
            coordinator.skipFile(file, context: context)
        }

        // Then: Should be able to undo 3 times
        #expect(coordinator.canUndo() == true)

        // Undo all 3
        var undoCount = 0
        while coordinator.canUndo() && undoCount < 10 {  // Safety limit
            coordinator.undoLastAction(allFiles: files, context: nil) { }
            undoCount += 1
        }

        #expect(undoCount == 3)

        // All files should be back to ready status
        for file in files {
            #expect(file.status == .ready)
        }
    }

    /// Test: BulkMoveCommand creates single undo entry for multiple files
    ///
    /// This verifies that auto-batch operations (e.g., auto-organize 10 files)
    /// create ONE undo entry that reverts all files, not 10 separate entries.
    @Test
    func bulkMove_CreatesSingleUndoEntry_ForMultipleFiles()  throws {
        guard requireIntegration() else { return }
        // Given: A bulk move with 5 file operations
        let operations: [(fileID: String, fromPath: String, toPath: String, originalStatus: FileItem.OrganizationStatus)] = (1...5).map { i in
            (fileID: "/Desktop/file\(i).pdf",
             fromPath: "/Desktop/file\(i).pdf",
             toPath: "/Documents/file\(i).pdf",
             originalStatus: .ready)
        }

        // When: Creating a single BulkMoveCommand
        let command = BulkMoveCommand(
            id: UUID(),
            timestamp: Date(),
            operations: operations
        )

        // Then: Single command holds all 5 operations
        #expect(command.operations.count == 5)
        #expect(command.description == "Move 5 files")

        // Each operation preserves its original data for undo
        for (index, op) in command.operations.enumerated() {
            #expect(op.fromPath == "/Desktop/file\(index + 1).pdf")
            #expect(op.toPath == "/Documents/file\(index + 1).pdf")
            #expect(op.originalStatus == .ready)
        }
    }

    /// Test: BulkMoveCommand preserves mixed status operations
    ///
    /// Auto-organize may process files with different original statuses.
    /// Undo must restore each file's original status, not a single shared status.
    @Test
    func bulkMove_PreservesMixedOriginalStatuses()  throws {
        guard requireIntegration() else { return }
        // Given: Files with different original statuses
        let operations: [(fileID: String, fromPath: String, toPath: String, originalStatus: FileItem.OrganizationStatus)] = [
            ("/Desktop/pending.pdf", "/Desktop/pending.pdf", "/Docs/pending.pdf", .pending),
            ("/Desktop/ready.pdf", "/Desktop/ready.pdf", "/Docs/ready.pdf", .ready),
            ("/Desktop/another.pdf", "/Desktop/another.pdf", "/Docs/another.pdf", .pending)
        ]

        // When: Creating bulk move command
        let command = BulkMoveCommand(
            id: UUID(),
            timestamp: Date(),
            operations: operations
        )

        // Then: Each operation retains its original status for proper undo
        #expect(command.operations[0].originalStatus == .pending)
        #expect(command.operations[1].originalStatus == .ready)
        #expect(command.operations[2].originalStatus == .pending)
    }

    @Test @MainActor
    func coordinator_AutomationBulkRun_PublishesUndoableBatchSummaryAndLogsUndo() async throws {
        guard requireIntegration() else { return }

        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }
        let sourceURL = try tempDirectory.createDirectory(name: "Inbox")
        let destinationURL = try tempDirectory.createDirectory(name: "Archive")
        let fileURL = try tempDirectory.createFile(name: "Inbox/invoice.pdf", contents: "invoice")

        let container = try ModelContainer(
            for: FileItem.self, Rule.self, ActivityItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let file = FileItem(
            path: fileURL.path,
            sizeInBytes: 1_024,
            creationDate: Date(),
            modificationDate: Date(),
            lastAccessedDate: Date(),
            location: .custom,
            scanRootPath: sourceURL.path,
            destination: try Destination.folder(from: destinationURL, displayName: "Archive"),
            status: .ready
        )
        context.insert(file)
        try context.save()

        let coordinator = FileOrganizationCoordinator()
        var successCount = 0
        var failedCount = 0
        var completionError: Error?

        await coordinator.organizeMultipleFiles([file], origin: .automation, context: context) { success, failed, _, error in
            successCount = success
            failedCount = failed
            completionError = error
        }

        #expect(successCount == 1)
        #expect(failedCount == 0)
        #expect(completionError == nil)
        #expect(coordinator.latestUndoableBatchSummary?.origin == .automation)
        #expect(coordinator.latestUndoableBatchSummary?.affectedFileCount == 1)

        var undoCompleted = false
        coordinator.undoLastAction(allFiles: [file], context: context) {
            undoCompleted = true
        }

        #expect(undoCompleted)
        #expect(coordinator.latestUndoableBatchSummary == nil)

        let activities = try context.fetch(FetchDescriptor<ActivityItem>())
        let undone = try #require(activities.first { $0.activityType == .bulkUndone })
        #expect(undone.details.contains("automatic"))
    }

    // MARK: - Feature Flag Tests

    /// Test: auto-organize is effectively disabled unless background monitoring is enabled
    @Test
    func featureFlag_AutoOrganizeDependsOnBackgroundMonitoring()  throws {
        guard requireIntegration() else { return }
        let featureFlags = FeatureFlagService.shared
        featureFlags.resetToDefaults()
        defer { featureFlags.resetToDefaults() }

        featureFlags.masterAIEnabled = true
        featureFlags.setEnabled(.autoOrganize, true)
        featureFlags.setEnabled(.backgroundMonitoring, false)

        #expect(featureFlags.getRawValue(.autoOrganize) == true)
        #expect(featureFlags.isEnabled(.autoOrganize) == false)

        featureFlags.setEnabled(.backgroundMonitoring, true)
        #expect(featureFlags.isEnabled(.autoOrganize) == true)
    }

    /// Test: resolved policy applies mode downgrade and interval clamping behavior
    @Test
    func automationPolicy_AppliesDowngradeAndClamping()  throws {
        guard requireIntegration() else { return }
        let featureFlags = FeatureFlagService.shared
        featureFlags.resetToDefaults()
        defer { featureFlags.resetToDefaults() }

        let userSettings = AutomationUserSettings(
            mode: .scanAndOrganize,
            scanIntervalMinutes: 99_999,
            scanOnLaunch: true,
            notificationsEnabled: true
        )

        featureFlags.setEnabled(.autoOrganize, false)
        let downgraded = AutomationPolicy.resolve(flags: featureFlags, userSettings: userSettings)
        #expect(downgraded.effectiveMode == .scanOnly)
        #expect(downgraded.scanIntervalMinutes == FormaConfig.Automation.maxScanIntervalMinutes)

        featureFlags.masterAIEnabled = false
        let disabled = AutomationPolicy.resolve(flags: featureFlags, userSettings: userSettings)
        #expect(disabled.effectiveMode == .off)
        #expect(disabled.scanIntervalMinutes == 0)
    }

    /// Test: notification policy requires both user opt-in and reminders flag
    @Test
    func automationPolicy_NotificationEnablementRequiresUserAndFlag()  throws {
        guard requireIntegration() else { return }
        let featureFlags = FeatureFlagService.shared
        featureFlags.resetToDefaults()
        defer { featureFlags.resetToDefaults() }

        let userOn = AutomationUserSettings(
            mode: .scanOnly,
            scanIntervalMinutes: 30,
            scanOnLaunch: true,
            notificationsEnabled: true
        )
        let userOff = AutomationUserSettings(
            mode: .scanOnly,
            scanIntervalMinutes: 30,
            scanOnLaunch: true,
            notificationsEnabled: false
        )

        featureFlags.setEnabled(.automationReminders, false)
        #expect(AutomationPolicy.resolve(flags: featureFlags, userSettings: userOn).notificationsEnabled == false)

        featureFlags.setEnabled(.automationReminders, true)
        #expect(AutomationPolicy.resolve(flags: featureFlags, userSettings: userOff).notificationsEnabled == false)
        #expect(AutomationPolicy.resolve(flags: featureFlags, userSettings: userOn).notificationsEnabled == true)
    }

    // MARK: - Activity Type Renderability Tests

    /// Test: persisted automation activities remain renderable for timeline UI
    @Test @MainActor
    func activityType_AutomationActivities_RoundTripAndRenderable() async throws {
        guard requireIntegration() else { return }

        let container = try ModelContainer(
            for: ActivityItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let loggingService = ActivityLoggingService(modelContext: context)

        loggingService.logAutomationScanCompleted(filesScanned: 10, newPending: 2)
        loggingService.logAutoOrganizeBatch(successCount: 3, failedCount: 1, skippedCount: 0)
        loggingService.logAutomationError(type: .scanFailed, message: "simulated")
        loggingService.logAutomationPaused(reason: "test")
        loggingService.logAutomationResumed()
        try context.save()

        let descriptor = FetchDescriptor<ActivityItem>()
        let activities = try context.fetch(descriptor)
        let automationActivities = activities.filter {
            [
                ActivityItem.ActivityType.automationScanCompleted,
                .automationAutoOrganized,
                .automationError,
                .automationPaused,
                .automationResumed
            ].contains($0.activityType)
        }

        #expect(automationActivities.count == 5)
        for activity in automationActivities {
            #expect(!activity.activityType.iconName.isEmpty)
            #expect(!activity.activityType.displayName.isEmpty)
        }
    }
}
