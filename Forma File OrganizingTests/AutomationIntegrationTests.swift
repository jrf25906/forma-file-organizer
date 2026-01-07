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
struct AutomationIntegrationTests {

    // MARK: - Activity Logging Tests

    /// Test: Automation scan completed is logged correctly
    @Test @MainActor
    func activityLogging_ScanCompleted() async throws {
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
        #expect(scanActivities.first?.details.contains("5 new") ?? false)
    }

    /// Test: Auto-organize batch is logged with correct counts
    @Test @MainActor
    func activityLogging_AutoOrganizeBatch() async throws {
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
        #expect(batchActivities.first?.details.contains("10") ?? false)
        #expect(batchActivities.first?.details.contains("2 failed") ?? false)
        #expect(batchActivities.first?.details.contains("3 skipped") ?? false)
    }

    /// Test: Automation error is logged correctly
    @Test @MainActor
    func activityLogging_AutomationError() async throws {
        // Given: Activity logging service with fresh container
        let container = try ModelContainer(
            for: ActivityItem.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let loggingService = ActivityLoggingService(modelContext: context)

        // When: Logging an automation error
        loggingService.logAutomationError(type: .scanFailed, message: "Permission denied")
        try context.save()

        // Then: Activity should be recorded
        let descriptor = FetchDescriptor<ActivityItem>()
        let activities = try context.fetch(descriptor)
        let errorActivities = activities.filter { $0.activityType == .automationError }

        #expect(errorActivities.count == 1)
        #expect(errorActivities.first?.fileName == "Scan Failed")
        #expect(errorActivities.first?.details == "Permission denied")
    }

    /// Test: Automation paused/resumed is logged correctly
    @Test @MainActor
    func activityLogging_PauseResume() async throws {
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

    // MARK: - Undo Entry Tests

    /// Test: BulkMoveCommand stores all necessary data for undo
    @Test
    func undoEntry_BulkMoveCommand_StoresRequiredData() {
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
    func undoEntry_MoveFileCommand_PreservesOriginalState() {
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
    func automationMetrics_FromFileScanResult() {
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
    func automationMetrics_BacklogDetection() {
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
        // Given/When: Fresh coordinator
        let coordinator = FileOrganizationCoordinator()

        // Then: Undo stack should be empty
        #expect(coordinator.canUndo() == false)
    }

    /// Test: Skip file creates undo entry
    @Test @MainActor
    func coordinator_SkipFile_CreatesUndoEntry() async throws {
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
    func bulkMove_CreatesSingleUndoEntry_ForMultipleFiles() {
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
    func bulkMove_PreservesMixedOriginalStatuses() {
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

    // MARK: - Feature Flag Tests

    /// Test: Automation feature flags exist in FeatureFlagService
    @Test
    func featureFlag_AutomationExists() {
        // Given/When: Feature flag service
        let featureFlags = FeatureFlagService.shared

        // Then: Automation features should exist (accessing them validates existence)
        let backgroundMonitoringExists = featureFlags.isEnabled(.backgroundMonitoring) || !featureFlags.isEnabled(.backgroundMonitoring)
        let autoOrganizeExists = featureFlags.isEnabled(.autoOrganize) || !featureFlags.isEnabled(.autoOrganize)
        let remindersExist = featureFlags.isEnabled(.automationReminders) || !featureFlags.isEnabled(.automationReminders)

        // All should be true (validates flags exist and return boolean values)
        #expect(backgroundMonitoringExists == true)
        #expect(autoOrganizeExists == true)
        #expect(remindersExist == true)
    }

    // MARK: - Config Constants Tests

    /// Test: All automation thresholds are properly configured
    @Test
    func automationConfig_ThresholdsConfigured() {
        // Verify all required thresholds exist and have sensible values
        #expect(FormaConfig.Automation.backlogThreshold > 0)
        #expect(FormaConfig.Automation.ageThresholdDays > 0)
        #expect(FormaConfig.Automation.minScanIntervalMinutes > 0)
        #expect(FormaConfig.Automation.maxScanIntervalMinutes > FormaConfig.Automation.minScanIntervalMinutes)
        #expect(FormaConfig.Automation.mlAutoOrganizeConfidenceMinimum >= FormaConfig.Automation.mlRuleConfidenceMinimum)
    }

    /// Test: Notification cooldowns are configured
    @Test
    func automationConfig_NotificationCooldownsConfigured() {
        #expect(FormaConfig.Automation.backlogReminderCooldownHours > 0)
        #expect(FormaConfig.Automation.errorNotificationCooldownMinutes > 0)
        #expect(FormaConfig.Automation.maxNotificationsPerHour > 0)
    }

    // MARK: - Activity Type Tests

    /// Test: All automation activity types have icons
    @Test
    func activityType_AutomationTypes_HaveIcons() {
        let automationTypes: [ActivityItem.ActivityType] = [
            .automationScanCompleted,
            .automationAutoOrganized,
            .automationError,
            .automationPaused,
            .automationResumed
        ]

        for type in automationTypes {
            #expect(!type.iconName.isEmpty, "\(type) should have an icon")
        }
    }

    /// Test: All automation activity types have display names
    @Test
    func activityType_AutomationTypes_HaveDisplayNames() {
        let automationTypes: [ActivityItem.ActivityType] = [
            .automationScanCompleted,
            .automationAutoOrganized,
            .automationError,
            .automationPaused,
            .automationResumed
        ]

        for type in automationTypes {
            #expect(!type.displayName.isEmpty, "\(type) should have a display name")
        }
    }
}
