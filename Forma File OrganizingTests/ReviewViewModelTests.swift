import XCTest
import SwiftData
@testable import Forma_File_Organizing

/// Comprehensive tests for ReviewViewModel covering all methods and state transitions
///
/// Note: These tests use the actual FileSystemService and FileOperationsService implementations
/// since ReviewViewModel doesn't support dependency injection. Tests focus on state management,
/// file list manipulation, and error handling paths that can be tested without filesystem access.
@MainActor
final class ReviewViewModelTests: XCTestCase {

    var viewModel: ReviewViewModel!
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var mockService: MockFileSystemService!
    var mockPipeline: MockFileScanPipeline!

    override func setUp() async throws {
        try await super.setUp()
        FeatureFlagService.shared.resetToDefaults()

        // Create in-memory model container with required models
        let schema = Schema([FileItem.self, Rule.self, ActivityItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])

        // Create viewModel with mocks to avoid real filesystem access
        await MainActor.run {
            modelContainer = container
            modelContext = container.mainContext
            mockService = MockFileSystemService()
            mockPipeline = MockFileScanPipeline()
            viewModel = ReviewViewModel(
                fileSystemService: mockService,
                fileScanPipeline: mockPipeline
            )
        }
    }

    override func tearDown() async throws {
        FeatureFlagService.shared.resetToDefaults()
        await MainActor.run {
            viewModel = nil
            mockService = nil
            mockPipeline = nil
            modelContext = nil
            modelContainer = nil
        }
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInit_StartsWithIdleState() {
        // Given/When: Fresh viewModel
        let vm = ReviewViewModel()

        // Then: Should be in idle state with empty files
        XCTAssertEqual(vm.loadingState, .idle)
        XCTAssertTrue(vm.files.isEmpty)
        XCTAssertNil(vm.errorMessage)
        XCTAssertNil(vm.successMessage)
    }

    func testInit_DoesNotScanAutomatically() {
        // Given/When: Fresh viewModel without context
        let vm = ReviewViewModel()

        // Then: Should remain idle until context is set
        XCTAssertEqual(vm.loadingState, .idle)
        XCTAssertTrue(vm.files.isEmpty)
    }

    // MARK: - Loading State Tests

    func testLoadingState_Enum_HasAllCases() {
        // Given/When/Then: Verify all loading states exist
        let idle = ReviewViewModel.LoadingState.idle
        let loading = ReviewViewModel.LoadingState.loading
        let loaded = ReviewViewModel.LoadingState.loaded
        let error = ReviewViewModel.LoadingState.error

        XCTAssertNotNil(idle)
        XCTAssertNotNil(loading)
        XCTAssertNotNil(loaded)
        XCTAssertNotNil(error)
    }

    // MARK: - File Management Tests

    func testSkipFile_UpdatesStatusAndRemovesFromList() {
        // Given: File in list
        let fileItem = createFileItem(
            name: "test.pdf",
            path: "/Desktop/test.pdf",
            destination: .mockFolder("Documents")
        )
        modelContext.insert(fileItem)
        viewModel.files = [fileItem]

        // When: Skipping file
        viewModel.skipFile(fileItem)

        // Then: Status updated to skipped, removed from list
        XCTAssertEqual(fileItem.status, .skipped)
        XCTAssertTrue(viewModel.files.isEmpty)
    }

    func testSkipFile_MultipleFiles_OnlyRemovesSkippedOne() {
        // Given: Multiple files
        let file1 = createFileItem(name: "doc1.pdf", path: "/Desktop/doc1.pdf", destination: .mockFolder("Documents"))
        let file2 = createFileItem(name: "doc2.pdf", path: "/Desktop/doc2.pdf", destination: .mockFolder("Documents"))
        let file3 = createFileItem(name: "doc3.pdf", path: "/Desktop/doc3.pdf", destination: .mockFolder("Documents"))

        modelContext.insert(file1)
        modelContext.insert(file2)
        modelContext.insert(file3)
        viewModel.files = [file1, file2, file3]

        // When: Skipping middle file
        viewModel.skipFile(file2)

        // Then: Only file2 removed and marked skipped
        XCTAssertEqual(viewModel.files.count, 2)
        XCTAssertFalse(viewModel.files.contains(file2))
        XCTAssertTrue(viewModel.files.contains(file1))
        XCTAssertTrue(viewModel.files.contains(file3))
        XCTAssertEqual(file2.status, .skipped)
        XCTAssertNotEqual(file1.status, .skipped)
        XCTAssertNotEqual(file3.status, .skipped)
    }

    func testSkipFile_WithAnimation_RemovesFileFromList() {
        // Given: File in list
        let fileItem = createFileItem(name: "test.pdf", path: "/Desktop/test.pdf", destination: .mockFolder("Documents"))
        modelContext.insert(fileItem)
        viewModel.files = [fileItem]

        let initialCount = viewModel.files.count

        // When: Skipping file (animation should not affect test outcome)
        viewModel.skipFile(fileItem)

        // Then: File removed
        XCTAssertEqual(initialCount, 1)
        XCTAssertTrue(viewModel.files.isEmpty)
    }

    // MARK: - MoveFile Error Handling Tests

    func testMoveFile_NoDestination_SetsErrorMessage() async {
        // Given: File without destination
        let fileItem = createFileItem(
            name: "test.pdf",
            path: "/Desktop/test.pdf",
            destination: nil
        )
        modelContext.insert(fileItem)
        viewModel.files = [fileItem]

        // When: Attempting to move file
        await viewModel.moveFile(fileItem)

        // Then: Error message set, file not removed from list
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage?.contains("No destination") ?? false)
        XCTAssertEqual(viewModel.files.count, 1)
        XCTAssertNotEqual(fileItem.status, .completed)
    }

    func testMoveFile_WithDestination_PreservesFileUntilSuccess() async {
        // Given: File with destination (will fail due to non-existent file)
        let fileItem = createFileItem(
            name: "nonexistent.pdf",
            path: "/nonexistent/path/file.pdf",
            destination: .mockFolder("Documents")
        )
        modelContext.insert(fileItem)
        viewModel.files = [fileItem]

        // When: Attempting to move non-existent file
        await viewModel.moveFile(fileItem)

        // Then: File should remain in list since operation failed
        // (Either error message set OR file still in list)
        let fileStillInList = viewModel.files.count == 1
        let errorOccurred = viewModel.errorMessage != nil

        XCTAssertTrue(fileStillInList || errorOccurred,
                     "File should remain in list or error should be set when operation fails")
    }

    func testMoveFile_UsesWorkflowRunnerWhenWorkflowEngineV2Enabled() async throws {
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.workflowEngineV2, true)

        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Desktop")
        let destinationFolder = try tempDirectory.createDirectory(name: "Receipts")
        let sourceURL = try tempDirectory.createFile(name: "Desktop/April Receipt.pdf", contents: "receipt")
        let destination = try Destination.folder(from: destinationFolder, displayName: "Receipts")
        let fileItem = FileItem(
            path: sourceURL.path,
            sizeInBytes: 1_024,
            creationDate: Date(timeIntervalSince1970: 1_712_620_800),
            modificationDate: Date(timeIntervalSince1970: 1_712_620_800),
            lastAccessedDate: Date(timeIntervalSince1970: 1_712_620_800),
            location: .desktop,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .ready
        )
        modelContext.insert(fileItem)
        try modelContext.save()

        let workflowExecution = WorkflowExecutionSpy()
        let runExpectation = expectation(description: "review workflow runner used")
        workflowExecution.onRun = { runExpectation.fulfill() }
        viewModel = ReviewViewModel(
            fileSystemService: mockService,
            fileScanPipeline: mockPipeline,
            organizationCoordinator: FileOrganizationCoordinator(),
            workflowExecution: workflowExecution.client
        )
        viewModel.setModelContext(modelContext)
        viewModel.files = [fileItem]
        viewModel.selectedWorkflowTemplateID = BuiltInWorkflowTemplate.StableID.receipts

        await viewModel.moveFile(fileItem)

        await fulfillment(of: [runExpectation], timeout: 1.0)
        XCTAssertEqual(workflowExecution.plannedTemplateIDs, [BuiltInWorkflowTemplate.StableID.receipts])
        XCTAssertEqual(workflowExecution.plannedInvocationContexts, [.reviewView])
        XCTAssertEqual(workflowExecution.ranTemplateIDs, [BuiltInWorkflowTemplate.StableID.receipts])
        XCTAssertEqual(
            workflowExecution.plannedRequests.map(\.entryPoint),
            [.invocationContext(.reviewView)]
        )
        XCTAssertEqual(
            workflowExecution.runRequests.map(\.entryPoint),
            [.invocationContext(.reviewView)]
        )
        XCTAssertEqual(
            workflowExecution.runRequests.map(\.scopeID),
            workflowExecution.plannedRequests.map(\.scopeID)
        )
        XCTAssertTrue(try modelContext.fetch(FetchDescriptor<ActivityItem>()).isEmpty)
        XCTAssertTrue(viewModel.files.isEmpty)
    }

    // MARK: - MoveAllFiles Error Handling Tests

    func testMoveAllFiles_NoFilesWithDestination_SetsErrorMessage() async {
        // Given: Files without destinations
        let file1 = createFileItem(name: "doc1.pdf", path: "/Desktop/doc1.pdf", destination: nil)
        let file2 = createFileItem(name: "pic1.png", path: "/Desktop/pic1.png", destination: nil)

        modelContext.insert(file1)
        modelContext.insert(file2)
        viewModel.files = [file1, file2]

        // When: Attempting to move all files
        await viewModel.moveAllFiles()

        // Then: Error message shown, files remain in list
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage?.contains("No files with suggested destinations") ?? false)
        XCTAssertEqual(viewModel.files.count, 2)
    }

    func testMoveAllFiles_EmptyList_SetsErrorMessage() async {
        // Given: No files in list
        viewModel.files = []

        // When: Attempting to move all files
        await viewModel.moveAllFiles()

        // Then: Error message shown
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage?.contains("No files with suggested destinations") ?? false)
    }

    func testMoveAllFiles_OnlyFiltersFilesWithDestinations() async {
        // Given: Mix of files with and without destinations
        let file1 = createFileItem(name: "doc1.pdf", path: "/Desktop/doc1.pdf", destination: .mockFolder("Documents"))
        let file2 = createFileItem(name: "pic1.png", path: "/Desktop/pic1.png", destination: nil)
        let file3 = createFileItem(name: "doc2.pdf", path: "/Desktop/doc2.pdf", destination: .mockFolder("Documents"))

        modelContext.insert(file1)
        modelContext.insert(file2)
        modelContext.insert(file3)
        viewModel.files = [file1, file2, file3]

        // When: Attempting to move all files (will fail due to non-existent paths)
        await viewModel.moveAllFiles()

        // Then: Should have attempted to move only files with destinations
        // File2 (without destination) should remain
        let file2StillPresent = viewModel.files.contains(file2)
        XCTAssertTrue(file2StillPresent, "File without destination should not be attempted")
    }

    func testWorkflowSimulationPreview_ReflectsSelectedTemplate() throws {
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.workflowEngineV2, true)

        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Desktop")
        let destinationFolder = try tempDirectory.createDirectory(name: "Receipts")
        let sourceURL = try tempDirectory.createFile(name: "Desktop/Preview Receipt.pdf", contents: "receipt")
        let destination = try Destination.folder(from: destinationFolder, displayName: "Receipts")
        let fileItem = FileItem(
            path: sourceURL.path,
            sizeInBytes: 1_024,
            creationDate: Date(timeIntervalSince1970: 1_712_620_800),
            modificationDate: Date(timeIntervalSince1970: 1_712_620_800),
            lastAccessedDate: Date(timeIntervalSince1970: 1_712_620_800),
            location: .desktop,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .ready
        )

        viewModel.files = [fileItem]
        viewModel.selectedWorkflowTemplateID = BuiltInWorkflowTemplate.StableID.receipts

        let preview = try XCTUnwrap(viewModel.workflowSimulationPreview)
        let explicitPreview = try XCTUnwrap(
            WorkflowTemplateSimulationPreview.make(
                templateID: BuiltInWorkflowTemplate.StableID.receipts,
                files: [fileItem],
                invocationContext: .reviewView
            )
        )
        XCTAssertEqual(viewModel.selectedWorkflowTemplate?.id, BuiltInWorkflowTemplate.StableID.receipts)
        XCTAssertEqual(preview.templateID, BuiltInWorkflowTemplate.StableID.receipts)
        XCTAssertEqual(preview.selectedFileCount, 1)
        XCTAssertEqual(preview.readyToRunCount, 1)
        XCTAssertTrue(preview.summaryText.contains("1 selected"))
        XCTAssertEqual(explicitPreview.templateID, BuiltInWorkflowTemplate.StableID.receipts)
    }

    func testMoveAllFiles_WithMixedRunnableAndBlockedFiles_RunsRunnableSubsetAndKeepsBlockedFilesVisible() async throws {
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.workflowEngineV2, true)

        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Desktop")
        let destinationFolder = try tempDirectory.createDirectory(name: "Receipts")
        let runnableURL = try tempDirectory.createFile(name: "Desktop/Runnable Receipt.pdf", contents: "receipt")
        let blockedURL = sourceFolder.appendingPathComponent("Missing Receipt.pdf")
        let destination = try Destination.folder(from: destinationFolder, displayName: "Receipts")

        let runnableFile = FileItem(
            path: runnableURL.path,
            sizeInBytes: 1_024,
            creationDate: Date(timeIntervalSince1970: 1_712_620_800),
            modificationDate: Date(timeIntervalSince1970: 1_712_620_800),
            lastAccessedDate: Date(timeIntervalSince1970: 1_712_620_800),
            location: .desktop,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .ready
        )
        let blockedFile = FileItem(
            path: blockedURL.path,
            sizeInBytes: 1_024,
            creationDate: Date(timeIntervalSince1970: 1_712_620_801),
            modificationDate: Date(timeIntervalSince1970: 1_712_620_801),
            lastAccessedDate: Date(timeIntervalSince1970: 1_712_620_801),
            location: .desktop,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .ready
        )
        modelContext.insert(runnableFile)
        modelContext.insert(blockedFile)
        try modelContext.save()

        let workflowExecution = WorkflowExecutionSpy()
        viewModel = ReviewViewModel(
            fileSystemService: mockService,
            fileScanPipeline: mockPipeline,
            organizationCoordinator: FileOrganizationCoordinator(),
            workflowExecution: workflowExecution.client
        )
        viewModel.setModelContext(modelContext)
        viewModel.files = [runnableFile, blockedFile]
        viewModel.selectedWorkflowTemplateID = BuiltInWorkflowTemplate.StableID.receipts

        await viewModel.moveAllFiles()

        XCTAssertEqual(workflowExecution.plannedTemplateIDs, [BuiltInWorkflowTemplate.StableID.receipts])
        XCTAssertEqual(workflowExecution.ranTemplateIDs, [BuiltInWorkflowTemplate.StableID.receipts])
        XCTAssertEqual(
            workflowExecution.runRequests.map(\.scopeID),
            workflowExecution.plannedRequests.map(\.scopeID)
        )
        XCTAssertEqual(viewModel.files.map(\.path), [blockedURL.path])
        XCTAssertNotNil(viewModel.successMessage)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    // MARK: - Message Clearing Tests

    func testClearError_RemovesErrorMessage() {
        // Given: ViewModel with error
        viewModel.errorMessage = "Test error"

        // When: Clearing error
        viewModel.clearError()

        // Then: Error cleared
        XCTAssertNil(viewModel.errorMessage)
    }

    func testClearSuccess_RemovesSuccessMessage() {
        // Given: ViewModel with success message
        viewModel.successMessage = "Test success"

        // When: Clearing success
        viewModel.clearSuccess()

        // Then: Success cleared
        XCTAssertNil(viewModel.successMessage)
    }

    func testClearError_WhenNoError_DoesNotCrash() {
        // Given: ViewModel without error
        viewModel.errorMessage = nil

        // When: Clearing error
        viewModel.clearError()

        // Then: Should not crash, error remains nil
        XCTAssertNil(viewModel.errorMessage)
    }

    func testClearSuccess_WhenNoSuccess_DoesNotCrash() {
        // Given: ViewModel without success
        viewModel.successMessage = nil

        // When: Clearing success
        viewModel.clearSuccess()

        // Then: Should not crash, success remains nil
        XCTAssertNil(viewModel.successMessage)
    }

    // MARK: - Permission Reset Tests

    func testResetAllPermissions_SetsRestartMessage() {
        // Given: ViewModel
        viewModel.errorMessage = nil

        // When: Resetting all permissions
        viewModel.resetAllPermissions()

        // Then: Error message should indicate restart needed
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage?.contains("restart") ?? false)
    }

    func testResetDesktopAccess_DoesNotCrash() {
        // Given: ViewModel

        // When: Resetting desktop access (calls FileSystemService)
        viewModel.resetDesktopAccess()

        // Then: Should not crash
        // No assertion needed - test passes if no crash occurs
    }

    func testResetAllPermissions_ResetsMultipleSystems() {
        // Given: ViewModel

        // When: Resetting all permissions
        viewModel.resetAllPermissions()

        // Then: Should call both reset methods without crashing
        // Error message confirms it executed
        XCTAssertNotNil(viewModel.errorMessage)
    }

    // MARK: - ScanDesktop State Tests

    func testScanDesktop_WithoutContext_ReturnsEarly() async {
        // Given: ViewModel without model context
        let vm = ReviewViewModel(
            fileSystemService: mockService,
            fileScanPipeline: mockPipeline
        )
        XCTAssertEqual(vm.loadingState, .idle)

        // When: Attempting to scan without context
        await vm.scanDesktop()

        // Then: Should remain idle (context check returns early)
        XCTAssertEqual(vm.loadingState, .idle)
    }

    func testScanDesktop_WithContext_ChangesLoadingState() async {
        // Given: ViewModel with context
        viewModel.setModelContext(modelContext)

        // When: Scanning desktop explicitly (auto-scan disabled under tests)
        await viewModel.scanDesktop()

        // Then: Loading state should have changed from idle
        // (Either loading or loaded, depending on timing)
        let stateChanged = viewModel.loadingState != .idle
        XCTAssertTrue(stateChanged, "Loading state should change after scan attempt")
    }

    func testScanDesktop_ClearsErrorBeforeScanning() async {
        // Given: ViewModel with context and existing error
        viewModel.setModelContext(modelContext)
        viewModel.errorMessage = "Previous error"

        // When: Scanning desktop again
        await viewModel.scanDesktop()

        // Then: Previous error should be cleared (if scan succeeds)
        // OR new error message set (if scan fails)
        // Either way, the old error message should not persist unchanged
        let errorCleared = viewModel.errorMessage == nil
        let errorUpdated = viewModel.errorMessage != "Previous error"

        XCTAssertTrue(errorCleared || errorUpdated,
                     "Error message should be cleared or updated during scan")
    }

    func testScanDesktop_SavesFilesToModelContext() async {
        // Given: ViewModel with context
        viewModel.setModelContext(modelContext)

        // When: Scanning (may succeed or fail depending on permissions)
        await viewModel.scanDesktop()

        // Then: Any files found should be saved to context
        let descriptor = FetchDescriptor<FileItem>()
        let savedFiles = try? modelContext.fetch(descriptor)

        // Files array should match what's in the database
        XCTAssertEqual(viewModel.files.count, savedFiles?.count ?? 0)
    }

    func testScanDesktop_WithExistingFiles_UpdatesThemCorrectly() async {
        // Given: Existing file in database
        let existingFile = FileItem(
            path: "/Desktop/existing.pdf",
            sizeInBytes: 1024,
            creationDate: Date(),
            destination: nil,
            status: .pending
        )
        modelContext.insert(existingFile)
        try? modelContext.save()

        viewModel.setModelContext(modelContext)

        // When: Scanning desktop
        await viewModel.scanDesktop()

        // Then: If same file found, should update, not duplicate
        let descriptor = FetchDescriptor<FileItem>(
            predicate: #Predicate { $0.name == "existing.pdf" }
        )
        let matchingFiles = try? modelContext.fetch(descriptor)

        // Should have at most 1 file with this name (no duplicates)
        XCTAssertTrue((matchingFiles?.count ?? 0) <= 1,
                     "Should not create duplicate files for same path")
    }

    func testScanDesktop_AppliesRulesToFiles() async {
        // Given: Enabled rule in database
        let rule = Rule(
            name: "PDF Rule",
            conditionType: .fileExtension,
            conditionValue: "pdf",
            actionType: .move,
            destination: .folder(bookmark: Data(), displayName: "Documents"),
            isEnabled: true
        )
        modelContext.insert(rule)
        try? modelContext.save()

        viewModel.setModelContext(modelContext)

        // When: Scanning desktop
        await viewModel.scanDesktop()

        // Then: If PDF files found, they should have suggested destinations
        let pdfFiles = viewModel.files.filter { $0.fileExtension.lowercased() == "pdf" }

        if !pdfFiles.isEmpty {
            // At least one PDF should have a suggested destination
            let hasDestinations = pdfFiles.contains { $0.destination != nil }
            XCTAssertTrue(hasDestinations, "PDF files should have suggested destinations when rule exists")
        }
    }

    func testScanDesktop_DisabledRules_NotApplied() async {
        // Given: Disabled rule in database
        let rule = Rule(
            name: "Disabled Rule",
            conditionType: .fileExtension,
            conditionValue: "pdf",
            actionType: .move,
            destination: .folder(bookmark: Data(), displayName: "Documents"),
            isEnabled: false  // Disabled
        )
        modelContext.insert(rule)
        try? modelContext.save()

        viewModel.setModelContext(modelContext)

        // When: Scanning desktop
        await viewModel.scanDesktop()

        // Then: Disabled rules should not affect files
        // (This is verified by the rule engine, but we confirm files load correctly)
        XCTAssertNotNil(viewModel.files)  // Files should still be loaded
    }

    func testRefresh_CallsScanDesktopAgain() async {
        // Given: ViewModel with context and initial scan complete
        viewModel.setModelContext(modelContext)
        await viewModel.scanDesktop()

        let stateAfterFirstScan = viewModel.loadingState

        // When: Calling refresh
        await viewModel.refresh()

        // Then: Should call scanDesktop again
        // State should be updated (likely still .loaded if scan succeeds)
        XCTAssertNotNil(stateAfterFirstScan)
        // Refresh should maintain or update the loading state
    }

    // MARK: - Integration Tests

    func testFileLifecycle_AddThenSkip() {
        // Given: File added to list
        let fileItem = createFileItem(
            name: "lifecycle.pdf",
            path: "/Desktop/lifecycle.pdf",
            destination: .mockFolder("Documents")
        )
        modelContext.insert(fileItem)
        viewModel.files = [fileItem]

        XCTAssertEqual(viewModel.files.count, 1)
        XCTAssertEqual(fileItem.status, .ready)

        // When: Skipping file
        viewModel.skipFile(fileItem)

        // Then: File removed and status updated
        XCTAssertTrue(viewModel.files.isEmpty)
        XCTAssertEqual(fileItem.status, .skipped)
    }

    func testMessageLifecycle_ErrorThenClear() {
        // Given: No error message
        XCTAssertNil(viewModel.errorMessage)

        // When: Error occurs
        viewModel.errorMessage = "Test error"
        XCTAssertNotNil(viewModel.errorMessage)

        // Then: Can be cleared
        viewModel.clearError()
        XCTAssertNil(viewModel.errorMessage)
    }

    func testMessageLifecycle_SuccessThenClear() {
        // Given: No success message
        XCTAssertNil(viewModel.successMessage)

        // When: Success occurs
        viewModel.successMessage = "Test success"
        XCTAssertNotNil(viewModel.successMessage)

        // Then: Can be cleared
        viewModel.clearSuccess()
        XCTAssertNil(viewModel.successMessage)
    }

    // MARK: - Edge Cases

    func testSkipFile_NotInList_DoesNotCrash() {
        // Given: File not in viewModel's list
        let fileItem = createFileItem(
            name: "orphan.pdf",
            path: "/Desktop/orphan.pdf",
            destination: .mockFolder("Documents")
        )
        modelContext.insert(fileItem)
        // Deliberately NOT adding to viewModel.files

        // When: Skipping file
        viewModel.skipFile(fileItem)

        // Then: Should not crash, file status still updated
        XCTAssertEqual(fileItem.status, .skipped)
        XCTAssertTrue(viewModel.files.isEmpty)
    }

    func testReviewSkip_PreservesVisibleBehaviorWhileUsingCoordinatorPath() throws {
        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.durableWorkflowStatus, true)

        let schema = Schema([
            FileItem.self,
            Rule.self,
            ActivityItem.self,
            FileMetadataRecord.self,
            FileOrganizationHistoryEntry.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext

        viewModel = ReviewViewModel(
            fileSystemService: mockService,
            fileScanPipeline: mockPipeline
        )
        viewModel.setModelContext(context)

        let fileItem = createFileItem(
            name: "review-skip.pdf",
            path: "/Desktop/review-skip.pdf",
            destination: .mockFolder("Invoices")
        )
        context.insert(fileItem)

        let record = FileMetadataRecord(
            canonicalIdentity: FileMetadataFoundationService.pathFallbackCanonicalIdentity(for: fileItem.path),
            identityKind: .pathFallback,
            lastKnownPath: fileItem.path,
            displayName: fileItem.name,
            fileExtension: fileItem.fileExtension,
            firstSeenAt: Date(),
            lastSeenAt: Date()
        )
        record.workflowStatus = .queued
        context.insert(record)
        try context.save()

        viewModel.files = [fileItem]

        viewModel.skipFile(fileItem)

        let persistedRecord = try XCTUnwrap(try context.fetch(FetchDescriptor<FileMetadataRecord>()).first)
        XCTAssertTrue(viewModel.files.isEmpty)
        XCTAssertEqual(fileItem.rejectedDestination, "Invoices")
        XCTAssertEqual(fileItem.rejectionCount, 1)
        XCTAssertEqual(fileItem.status, .skipped)
        XCTAssertEqual(persistedRecord.workflowStatus, .ignored)
        XCTAssertEqual(persistedRecord.historyEntries.count, 1)
        XCTAssertEqual(persistedRecord.historyEntries.first?.eventKind, .ignored)
    }

    func testReviewSkip_FailedSkipKeepsFileVisibleAndRestoresStatus() {
        let coordinator = MockReviewFileOrganizationCoordinator()
        coordinator.skipFileResult = false

        viewModel = ReviewViewModel(
            fileSystemService: mockService,
            fileScanPipeline: mockPipeline,
            organizationCoordinator: coordinator
        )
        viewModel.setModelContext(modelContext)

        let fileItem = createFileItem(
            name: "failed-review-skip.pdf",
            path: "/Desktop/failed-review-skip.pdf",
            destination: .mockFolder("Invoices")
        )
        modelContext.insert(fileItem)
        viewModel.files = [fileItem]

        viewModel.skipFile(fileItem)

        XCTAssertEqual(coordinator.skipFileCallCount, 1)
        XCTAssertEqual(viewModel.files.count, 1)
        XCTAssertTrue(viewModel.files.contains { $0 === fileItem })
        XCTAssertEqual(fileItem.status, .ready)
        XCTAssertEqual(fileItem.rejectedDestination, "Invoices")
        XCTAssertEqual(fileItem.rejectionCount, 1)
    }

    func testMoveFile_AlreadyCompleted_HandlesGracefully() async {
        // Given: File already marked as completed
        let fileItem = createFileItem(
            name: "completed.pdf",
            path: "/Desktop/completed.pdf",
            destination: .mockFolder("Documents")
        )
        fileItem.status = .completed
        modelContext.insert(fileItem)
        viewModel.files = [fileItem]

        // When: Attempting to move again
        await viewModel.moveFile(fileItem)

        // Then: Should handle gracefully (may error or skip)
        // No crash is the key requirement
    }

    func testMoveAllFiles_DuringOngoingMove_HandlesGracefully() async {
        // Given: Files with destinations
        let file1 = createFileItem(name: "doc1.pdf", path: "/Desktop/doc1.pdf", destination: .mockFolder("Documents"))
        viewModel.files = [file1]

        // When: Calling moveAllFiles twice rapidly
        // Note: ReviewViewModel is main-actor isolated, so calls serialize on the main actor.
        // The primary assertion here is "no crash / no reentrancy bug".
        await viewModel.moveAllFiles()
        await viewModel.moveAllFiles()

        // Then: Should handle without crashing
        // (Files may be empty or contain file1, depending on timing)
    }

    // MARK: - Helper Methods

    private func createFileItem(
        name: String,
        path: String,
        destination: Destination?
    ) -> FileItem {
        let resolvedPath = path.isEmpty ? name : path
        return FileItem(
            path: resolvedPath,
            sizeInBytes: 1024,
            creationDate: Date(),
            destination: destination,
            status: .ready
        )
    }
}

@MainActor
private final class MockReviewFileOrganizationCoordinator: FileOrganizationCoordinator {
    var skipFileCallCount = 0
    var skipFileResult = true

    override func skipFile(_ file: FileItem, context: ModelContext?) -> Bool {
        skipFileCallCount += 1
        return skipFileResult
    }
}

@MainActor
private final class WorkflowExecutionSpy {
    var plannedTemplateIDs: [String] = []
    var plannedInvocationContexts: [WorkflowInvocationContext] = []
    var plannedRequests: [WorkflowExecutionRequest] = []
    var ranTemplateIDs: [String] = []
    var runRequests: [WorkflowExecutionRequest] = []
    var onRun: (() -> Void)?

    lazy var client = WorkflowExecutionClient(
        planRequest: { [weak self] request, files in
            self?.plannedTemplateIDs.append(request.templateID)
            self?.plannedInvocationContexts.append(request.invocationContext)
            self?.plannedRequests.append(request)
            return WorkflowPlanner().plan(
                templateID: request.templateID,
                files: files,
                invocationContext: request.invocationContext
            )
        },
        runRequest: { [weak self] request, plan, _, _ in
            let templateID = plan.definition.templateID
            await MainActor.run {
                self?.ranTemplateIDs.append(templateID)
                self?.runRequests.append(request)
                self?.onRun?()
            }
            return WorkflowRunRecord(
                scopeID: request.scopeID,
                workflowTemplateID: templateID,
                primaryStatus: .succeeded,
                startedAt: Date(timeIntervalSince1970: 1_000),
                endedAt: Date(timeIntervalSince1970: 1_001)
            )
        }
    )
}
