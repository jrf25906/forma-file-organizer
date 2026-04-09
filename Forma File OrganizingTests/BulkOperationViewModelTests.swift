import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class BulkOperationViewModelTests: XCTestCase {
    private var modelContainer: ModelContainer!
    private var modelContext: ModelContext!
    private var coordinator: MockBulkFileOrganizationCoordinator!
    private var viewModel: BulkOperationViewModel!
    private var workflowExecution: WorkflowExecutionSpy!

    override func setUp() async throws {
        try await super.setUp()

        let schema = Schema([
            ActivityItem.self,
            FileItem.self,
            Rule.self,
            FileMetadataRecord.self,
            FileOrganizationHistoryEntry.self,
            WorkflowRunRecord.self,
            WorkflowStepRunRecord.self,
            WorkflowFileActionRecord.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = modelContainer.mainContext
        coordinator = MockBulkFileOrganizationCoordinator()
        workflowExecution = WorkflowExecutionSpy()
        FeatureFlagService.shared.resetToDefaults()

        viewModel = BulkOperationViewModel(
            organizationCoordinator: coordinator,
            notificationService: .shared,
            workflowExecution: workflowExecution.client
        )
    }

    override func tearDown() async throws {
        FeatureFlagService.shared.resetToDefaults()
        await MainActor.run {
            viewModel = nil
            coordinator = nil
            workflowExecution = nil
            modelContext = nil
            modelContainer = nil
        }
        try await super.tearDown()
    }

    func testOrganizeSelectedFiles_RequiresExplicitTemplateSelection() async throws {
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.workflowEngineV2, true)

        let file = FileItem(
            path: "/Users/example/Downloads/receipt.pdf",
            sizeInBytes: 1_024,
            creationDate: Date(),
            destination: .mockFolder("Documents"),
            status: .ready
        )
        modelContext.insert(file)
        try modelContext.save()

        var capturedToast: (String, Bool)?
        viewModel.onShowToast = { message, isSuccess in
            capturedToast = (message, isSuccess)
        }

        await viewModel.organizeSelectedFiles([file], context: modelContext, workflowTemplateID: nil)

        XCTAssertEqual(capturedToast?.0, "Choose a built-in workflow template before organizing with Workflow Engine v2.")
        XCTAssertEqual(capturedToast?.1, false)
        XCTAssertEqual(coordinator.organizeMultipleFilesCallCount, 0)
    }

    func testOrganizeSelectedFiles_UsesWorkflowRunnerWhenWorkflowEngineV2IsEnabled() async throws {
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.workflowEngineV2, true)

        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        let destinationFolder = try tempDirectory.createDirectory(name: "Receipts")
        let sourceURL = try tempDirectory.createFile(name: "Inbox/April Receipt.pdf", contents: "receipt")
        let destination = try Destination.folder(from: destinationFolder, displayName: "Receipts")
        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 1_024,
            creationDate: Date(timeIntervalSince1970: 1_712_620_800),
            modificationDate: Date(timeIntervalSince1970: 1_712_620_800),
            lastAccessedDate: Date(timeIntervalSince1970: 1_712_620_800),
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .ready
        )
        modelContext.insert(file)
        try modelContext.save()

        let runExpectation = expectation(description: "workflow runner used for bulk organize")
        workflowExecution.onRun = { runExpectation.fulfill() }
        viewModel = BulkOperationViewModel(
            organizationCoordinator: coordinator,
            notificationService: .shared,
            workflowExecution: workflowExecution.client
        )

        await viewModel.organizeSelectedFiles(
            [file],
            context: modelContext,
            workflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts
        )

        await fulfillment(of: [runExpectation], timeout: 1.0)
        XCTAssertEqual(workflowExecution.plannedTemplateIDs, [BuiltInWorkflowTemplate.StableID.receipts])
        XCTAssertEqual(workflowExecution.plannedInvocationContexts, [.reviewAdHoc])
        XCTAssertEqual(workflowExecution.ranTemplateIDs, [BuiltInWorkflowTemplate.StableID.receipts])
        XCTAssertEqual(workflowExecution.lastRunFilePaths, [sourceURL.path])
        XCTAssertTrue(try modelContext.fetch(FetchDescriptor<ActivityItem>()).isEmpty)
        XCTAssertEqual(coordinator.organizeMultipleFilesCallCount, 0)
    }

    func testOrganizeSelectedFiles_WithMixedRunnableAndBlockedFiles_DoesNotOfferUndoForWorkflowToast() async throws {
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.workflowEngineV2, true)

        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        let destinationFolder = try tempDirectory.createDirectory(name: "Receipts")
        let runnableURL = try tempDirectory.createFile(name: "Inbox/Runnable Receipt.pdf", contents: "receipt")
        let blockedURL = sourceFolder.appendingPathComponent("Missing Receipt.pdf")
        let destination = try Destination.folder(from: destinationFolder, displayName: "Receipts")

        let runnableFile = FileItem(
            path: runnableURL.path,
            sizeInBytes: 1_024,
            creationDate: Date(timeIntervalSince1970: 1_712_620_800),
            modificationDate: Date(timeIntervalSince1970: 1_712_620_800),
            lastAccessedDate: Date(timeIntervalSince1970: 1_712_620_800),
            location: .custom,
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
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .ready
        )
        modelContext.insert(runnableFile)
        modelContext.insert(blockedFile)
        try modelContext.save()

        var capturedToast: (String, Bool)?
        viewModel.onShowToast = { message, isSuccess in
            capturedToast = (message, isSuccess)
        }

        await viewModel.organizeSelectedFiles(
            [runnableFile, blockedFile],
            context: modelContext,
            workflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts
        )

        XCTAssertEqual(workflowExecution.plannedTemplateIDs, [BuiltInWorkflowTemplate.StableID.receipts])
        XCTAssertEqual(workflowExecution.ranTemplateIDs, [BuiltInWorkflowTemplate.StableID.receipts])
        XCTAssertEqual(workflowExecution.lastRunFilePaths, [runnableURL.path])
        XCTAssertEqual(viewModel.lastBatchFailedFiles.map(\.path), [blockedURL.path])
        XCTAssertTrue(viewModel.showFailedFilesSheet)
        XCTAssertEqual(capturedToast?.0, "Organized 1 of 2. Open failed files for details.")
        XCTAssertEqual(capturedToast?.1, false)
        XCTAssertEqual(coordinator.organizeMultipleFilesCallCount, 0)
    }

    func testRetryFailedFiles_UsesWorkflowEngineWhenWorkflowEngineV2IsEnabled() async throws {
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.workflowEngineV2, true)

        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        let destinationFolder = try tempDirectory.createDirectory(name: "Receipts")
        let blockedURL = sourceFolder.appendingPathComponent("Still Missing.pdf")
        let destination = try Destination.folder(from: destinationFolder, displayName: "Receipts")
        let blockedFile = FileItem(
            path: blockedURL.path,
            sizeInBytes: 1_024,
            creationDate: Date(timeIntervalSince1970: 1_712_620_800),
            modificationDate: Date(timeIntervalSince1970: 1_712_620_800),
            lastAccessedDate: Date(timeIntervalSince1970: 1_712_620_800),
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .ready
        )
        modelContext.insert(blockedFile)
        try modelContext.save()

        viewModel.lastBatchFailedFiles = [blockedFile]
        viewModel.showFailedFilesSheet = true

        await viewModel.retryFailedFiles(
            context: modelContext,
            workflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts
        )

        XCTAssertEqual(workflowExecution.plannedTemplateIDs, [BuiltInWorkflowTemplate.StableID.receipts])
        XCTAssertTrue(workflowExecution.ranTemplateIDs.isEmpty)
        XCTAssertEqual(coordinator.organizeMultipleFilesCallCount, 0)
    }
}

@MainActor
private final class MockBulkFileOrganizationCoordinator: FileOrganizationCoordinator {
    var organizeMultipleFilesCallCount = 0

    override func organizeMultipleFiles(
        _ files: [FileItem],
        origin: OrganizationRunOrigin = .reviewDriven,
        projectAssociationWriteContext explicitProjectAssociationWriteContext: ProjectAssociationWriteContext? = nil,
        context: ModelContext?,
        onComplete: @escaping (Int, Int, [FileItem], (any Error)?) -> Void
    ) async {
        organizeMultipleFilesCallCount += 1
        onComplete(files.count, 0, [], nil)
    }
}

@MainActor
private final class WorkflowExecutionSpy {
    var plannedTemplateIDs: [String] = []
    var plannedInvocationContexts: [WorkflowInvocationContext] = []
    var ranTemplateIDs: [String] = []
    var lastRunFilePaths: [String] = []
    var onRun: (() -> Void)?

    lazy var client = WorkflowExecutionClient(
        plan: { [weak self] templateID, files, invocationContext in
            self?.plannedTemplateIDs.append(templateID)
            self?.plannedInvocationContexts.append(invocationContext)
            return WorkflowPlanner().plan(
                templateID: templateID,
                files: files,
                invocationContext: invocationContext
            )
        },
        run: { [weak self] plan, files, _, _ in
            let templateID = plan.definition.templateID
            let filePaths = files.map(\.path)
            await MainActor.run {
                self?.ranTemplateIDs.append(templateID)
                self?.lastRunFilePaths = filePaths
                self?.onRun?()
            }
        }
    )
}
