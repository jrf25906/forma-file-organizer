import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class WorkflowEntryPointOrganizerTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.workflowEngineV2, true)

        let schema = Schema([FileItem.self, WorkflowRunRecord.self, WorkflowStepRunRecord.self, WorkflowFileActionRecord.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = container.mainContext
    }

    override func tearDown() async throws {
        FeatureFlagService.shared.resetToDefaults()
        context = nil
        container = nil
        try await super.tearDown()
    }

    func testExecute_MenuBarBuildsWorkflowRequestAndMarksRunnableFilesCompleted() async throws {
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Downloads")
        let destinationFolder = try tempDirectory.createDirectory(name: "Screenshots")
        let sourceURL = try tempDirectory.createFile(name: "Downloads/Screen Shot 2026-04-09 at 9.41.00 AM.png", contents: "image")
        let destination = try Destination.folder(from: destinationFolder, displayName: "Screenshots")
        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 4_096,
            creationDate: Date(timeIntervalSince1970: 1_712_620_800),
            modificationDate: Date(timeIntervalSince1970: 1_712_620_800),
            lastAccessedDate: Date(timeIntervalSince1970: 1_712_620_800),
            location: .downloads,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .ready
        )
        context.insert(file)
        try context.save()

        let workflowExecution = WorkflowExecutionSpy()
        let organizer = WorkflowEntryPointOrganizer(workflowExecution: workflowExecution.client)

        let outcome = try await organizer.execute(
            files: [file],
            template: WorkflowTemplateCatalog.template(for: BuiltInWorkflowTemplate.StableID.screenshots)!,
            invocationContext: .menuBar,
            modelContext: context
        )

        XCTAssertEqual(outcome.runnableFiles, [file])
        XCTAssertTrue(outcome.blockedFiles.isEmpty)
        XCTAssertEqual(file.status, .completed)
        XCTAssertEqual(workflowExecution.plannedTemplateIDs, [BuiltInWorkflowTemplate.StableID.screenshots])
        XCTAssertEqual(workflowExecution.plannedInvocationContexts, [.menuBar])
        XCTAssertEqual(workflowExecution.runRequests.map(\.entryPoint), [.invocationContext(.menuBar)])
    }

    func testExecute_BlockedFilesDoNotRunWorkflow() async throws {
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Downloads")
        let sourceURL = try tempDirectory.createFile(name: "Downloads/Blocked.png", contents: "image")
        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 2_048,
            creationDate: Date(timeIntervalSince1970: 1_712_620_800),
            modificationDate: Date(timeIntervalSince1970: 1_712_620_800),
            lastAccessedDate: Date(timeIntervalSince1970: 1_712_620_800),
            location: .downloads,
            scanRootPath: sourceFolder.path,
            destination: nil,
            status: .ready
        )
        context.insert(file)
        try context.save()

        let workflowExecution = WorkflowExecutionSpy()
        let organizer = WorkflowEntryPointOrganizer(workflowExecution: workflowExecution.client)

        let outcome = try await organizer.execute(
            files: [file],
            template: WorkflowTemplateCatalog.template(for: BuiltInWorkflowTemplate.StableID.screenshots)!,
            invocationContext: .appIntent,
            modelContext: context
        )

        XCTAssertTrue(outcome.runnableFiles.isEmpty)
        XCTAssertEqual(outcome.blockedFiles, [file])
        XCTAssertTrue(workflowExecution.runRequests.isEmpty)
        XCTAssertEqual(file.status, .ready)
        XCTAssertNil(outcome.runRecord)
    }
}

@MainActor
private final class WorkflowExecutionSpy {
    var plannedTemplateIDs: [String] = []
    var plannedInvocationContexts: [WorkflowInvocationContext] = []
    var runRequests: [WorkflowExecutionRequest] = []

    lazy var client = WorkflowExecutionClient(
        planRequest: { [weak self] request, files in
            self?.plannedTemplateIDs.append(request.templateID)
            self?.plannedInvocationContexts.append(request.invocationContext)
            return WorkflowPlanner().plan(
                templateID: request.templateID,
                files: files,
                invocationContext: request.invocationContext
            )
        },
        runRequest: { [weak self] request, plan, _, _ in
            self?.runRequests.append(request)
            return WorkflowRunRecord(
                scopeID: request.scopeID,
                workflowTemplateID: plan.definition.templateID,
                triggerSurface: request.triggerSurface,
                primaryStatus: .succeeded,
                startedAt: Date(timeIntervalSince1970: 1_000),
                endedAt: Date(timeIntervalSince1970: 1_001)
            )
        }
    )
}
