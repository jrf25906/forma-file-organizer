import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class DashboardOrganizationControllerTests: XCTestCase {

    private var modelContainer: ModelContainer!
    private var modelContext: ModelContext!
    private var coordinator: MockFileOrganizationCoordinator!
    private var scanViewModel: FileScanViewModel!
    private var filterViewModel: FilterViewModel!
    private var selectionViewModel: SelectionViewModel!
    private var panelManager: PanelStateManager!
    private var appReviewEligibility: MockAppReviewEligibilityService!

    override func setUp() async throws {
        try await super.setUp()

        let schema = Schema([
            FileItem.self,
            Rule.self,
            ActivityItem.self,
            FileMetadataRecord.self,
            FileOrganizationHistoryEntry.self,
            TrustedAutomationScope.self,
            PersonalMemoryEvent.self,
            PersonalMemoryPreference.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = modelContainer.mainContext

        coordinator = MockFileOrganizationCoordinator()
        scanViewModel = FileScanViewModel(
            fileSystemService: MockFileSystemService(),
            fileScanPipeline: MockFileScanPipeline()
        )
        filterViewModel = FilterViewModel()
        selectionViewModel = SelectionViewModel()
        panelManager = PanelStateManager()
        appReviewEligibility = MockAppReviewEligibilityService()

        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.patternLearning, true)
        FeatureFlagService.shared.setEnabled(.backgroundMonitoring, true)
        FeatureFlagService.shared.setEnabled(.autoOrganize, true)
        FeatureFlagService.shared.setEnabled(.trustedAutomationScopes, true)
    }

    override func tearDown() async throws {
        FeatureFlagService.shared.resetToDefaults()

        await MainActor.run {
            modelContext = nil
            modelContainer = nil
            coordinator = nil
            scanViewModel = nil
            filterViewModel = nil
            selectionViewModel = nil
            panelManager = nil
            appReviewEligibility = nil
        }

        try await super.tearDown()
    }

    func testOrganizeFile_SuccessPublishesTrustedScopeRecommendationWhenFeatureFlagAndEvidenceAllow() async throws {
        let destination = Destination.mockFolder("Documents/Exports")
        let file = FileItem(
            path: "/Users/example/Downloads/Exports/report.csv",
            sizeInBytes: 2_048,
            creationDate: Date(),
            location: .downloads,
            scanRootPath: "/Users/example/Downloads",
            relativeParentPath: "Exports",
            destination: destination,
            status: .ready
        )
        file.originalSuggestedDestination = destination
        modelContext.insert(file)
        try modelContext.save()

        scanViewModel.replaceScannedFiles([file])
        filterViewModel.updateSourceFiles([file])

        let memoryService = PersonalMemoryService(modelContext: modelContext)
        for dayOffset in 0..<3 {
            _ = try memoryService.recordDecision(
                fileName: file.name,
                fileExtension: file.fileExtension,
                fileTypeCategory: FileTypeCategory.category(for: file.fileExtension),
                sourceLocation: file.location,
                scanRootPath: file.scanRootPath,
                relativeParentPath: file.relativeParentPath,
                sourceSurface: .reviewFlow,
                suggestionSource: .personalMemory,
                suggestedDestination: destination,
                chosenDestination: destination,
                confidenceScore: 0.9,
                matchedRuleID: nil,
                eventKind: .acceptedSuggestion,
                timestamp: Date().addingTimeInterval(TimeInterval(dayOffset))
            )
        }

        coordinator.cannedFileAction = FileOrganizationCoordinator.FileActionData(
            filePath: file.path,
            originalPath: file.path,
            originalStatus: .ready,
            originalSuggestedDestination: destination.displayName,
            destinationPath: file.path.replacingOccurrences(of: "Downloads/Exports", with: "Documents/Exports"),
            memorySnapshot: OrganizationMemorySnapshot(
                fileName: file.name,
                fileExtension: file.fileExtension,
                fileTypeCategory: FileTypeCategory.category(for: file.fileExtension),
                sourceLocation: file.location,
                scanRootPath: file.scanRootPath,
                relativeParentPath: file.relativeParentPath,
                suggestionSource: .personalMemory,
                suggestedDestination: destination,
                chosenDestination: destination,
                confidenceScore: 0.9,
                matchedRuleID: nil
            )
        )

        let controller = DashboardOrganizationController(
            coordinator: coordinator,
            scanViewModel: scanViewModel,
            filterViewModel: filterViewModel,
            selectionViewModel: selectionViewModel,
            panelManager: panelManager,
            appReviewEligibility: appReviewEligibility,
            usesTestingFastPath: false
        )

        let recommendationExpectation = expectation(description: "trusted scope recommendation")
        var capturedRecommendation: TrustedAutomationScopeRecommendation?

        controller.onShowTrustedScopeRecommendation = { recommendation in
            capturedRecommendation = recommendation
            recommendationExpectation.fulfill()
        }

        controller.organizeFile(file, context: modelContext, sourceSurface: .reviewFlow)

        await fulfillment(of: [recommendationExpectation], timeout: 1.0)
        XCTAssertEqual(capturedRecommendation?.recommendedScope.scopeType, .folder)
    }

    func testDashboardSkip_UsesCoordinatorPathWhenModelContextAvailable() async throws {
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.durableWorkflowStatus, true)

        let file = FileItem(
            path: "/Users/example/Downloads/skip.pdf",
            sizeInBytes: 2_048,
            creationDate: Date(),
            destination: .mockFolder("Documents"),
            status: .ready
        )
        modelContext.insert(file)

        let record = FileMetadataRecord(
            canonicalIdentity: FileMetadataFoundationService.pathFallbackCanonicalIdentity(for: file.path),
            identityKind: .pathFallback,
            lastKnownPath: file.path,
            displayName: file.name,
            fileExtension: file.fileExtension,
            firstSeenAt: Date(),
            lastSeenAt: Date()
        )
        record.workflowStatus = .queued
        modelContext.insert(record)
        try modelContext.save()

        let controller = DashboardOrganizationController(
            coordinator: coordinator,
            scanViewModel: scanViewModel,
            filterViewModel: filterViewModel,
            selectionViewModel: selectionViewModel,
            panelManager: panelManager,
            appReviewEligibility: appReviewEligibility,
            usesTestingFastPath: false
        )

        controller.skipFile(file, context: modelContext)

        XCTAssertEqual(coordinator.skipFileCallCount, 1)
        XCTAssertTrue(coordinator.lastSkippedFile === file)
        XCTAssertTrue(coordinator.lastSkipContext === modelContext)
        XCTAssertEqual(file.status, .ready)
    }

    func testDashboardSkip_FailedSkipDoesNotApplyFilter() throws {
        let file = FileItem(
            path: "/Users/example/Downloads/failed-skip.pdf",
            sizeInBytes: 2_048,
            creationDate: Date(),
            destination: .mockFolder("Documents"),
            status: .ready
        )
        modelContext.insert(file)
        try modelContext.save()

        scanViewModel.replaceScannedFiles([file])
        filterViewModel.updateSourceFiles([file])
        coordinator.skipFileResult = false

        let controller = DashboardOrganizationController(
            coordinator: coordinator,
            scanViewModel: scanViewModel,
            filterViewModel: filterViewModel,
            selectionViewModel: selectionViewModel,
            panelManager: panelManager,
            appReviewEligibility: appReviewEligibility,
            usesTestingFastPath: false
        )

        controller.skipFile(file, context: modelContext)

        XCTAssertEqual(coordinator.skipFileCallCount, 1)
        XCTAssertEqual(filterViewModel.filteredFiles.count, 1)
        XCTAssertTrue(filterViewModel.filteredFiles.contains { $0 === file })
        XCTAssertEqual(file.status, .ready)
    }

    func testOrganizeFile_UsesWorkflowRunnerWhenWorkflowEngineV2IsEnabled() async throws {
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
            sizeInBytes: 2_048,
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
        scanViewModel.replaceScannedFiles([file])
        filterViewModel.updateSourceFiles([file])

        let workflowExecution = WorkflowExecutionSpy()
        let runExpectation = expectation(description: "workflow runner used")
        workflowExecution.onRun = { runExpectation.fulfill() }

        let controller = DashboardOrganizationController(
            coordinator: coordinator,
            scanViewModel: scanViewModel,
            filterViewModel: filterViewModel,
            selectionViewModel: selectionViewModel,
            panelManager: panelManager,
            appReviewEligibility: appReviewEligibility,
            usesTestingFastPath: false,
            workflowExecution: workflowExecution.client
        )

        controller.organizeFile(
            file,
            context: modelContext,
            sourceSurface: .reviewFlow,
            workflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts
        )

        await fulfillment(of: [runExpectation], timeout: 1.0)
        XCTAssertEqual(workflowExecution.plannedTemplateIDs, [BuiltInWorkflowTemplate.StableID.receipts])
        XCTAssertEqual(workflowExecution.plannedInvocationContexts, [.inspector])
        XCTAssertEqual(workflowExecution.ranTemplateIDs, [BuiltInWorkflowTemplate.StableID.receipts])
        XCTAssertEqual(
            workflowExecution.plannedRequests.map(\.entryPoint),
            [.invocationContext(.inspector)]
        )
        XCTAssertEqual(
            workflowExecution.runRequests.map(\.entryPoint),
            [.invocationContext(.inspector)]
        )
        XCTAssertEqual(
            workflowExecution.runRequests.map(\.scopeID),
            workflowExecution.plannedRequests.map(\.scopeID)
        )
        XCTAssertEqual(workflowExecution.lastPlannedFilePaths, [sourceURL.path])
        XCTAssertEqual(workflowExecution.lastRunFilePaths, [sourceURL.path])
        XCTAssertTrue(try modelContext.fetch(FetchDescriptor<ActivityItem>()).isEmpty)
        XCTAssertEqual(coordinator.organizeFileCallCount, 0)
        XCTAssertFalse(panelManager.celebrationStyle.showsUndo)
    }

    func testOrganizeFile_WorkflowEngineV2PreservesTrustedScopeRecommendationFlow() async throws {
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.workflowEngineV2, true)

        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        let destinationFolder = try tempDirectory.createDirectory(name: "Exports")
        let sourceURL = try tempDirectory.createFile(name: "Inbox/Quarterly Report.csv", contents: "report")
        let destination = try Destination.folder(from: destinationFolder, displayName: "Exports")
        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 2_048,
            creationDate: Date(timeIntervalSince1970: 1_712_620_800),
            modificationDate: Date(timeIntervalSince1970: 1_712_620_800),
            lastAccessedDate: Date(timeIntervalSince1970: 1_712_620_800),
            location: .custom,
            scanRootPath: sourceFolder.path,
            relativeParentPath: "Inbox",
            destination: destination,
            status: .ready
        )
        file.originalSuggestedDestination = destination
        file.suggestionSourceRaw = SuggestionSource.personalMemory.rawValue
        file.confidenceScore = 0.91
        modelContext.insert(file)
        try modelContext.save()

        let memoryService = PersonalMemoryService(modelContext: modelContext)
        for dayOffset in 0..<3 {
            _ = try memoryService.recordDecision(
                fileName: file.name,
                fileExtension: file.fileExtension,
                fileTypeCategory: FileTypeCategory.category(for: file.fileExtension),
                sourceLocation: file.location,
                scanRootPath: file.scanRootPath,
                relativeParentPath: file.relativeParentPath,
                sourceSurface: .reviewFlow,
                suggestionSource: .personalMemory,
                suggestedDestination: destination,
                chosenDestination: destination,
                confidenceScore: 0.91,
                matchedRuleID: nil,
                eventKind: .acceptedSuggestion,
                timestamp: Date().addingTimeInterval(TimeInterval(dayOffset))
            )
        }

        let workflowExecution = WorkflowExecutionSpy()
        let recommendationExpectation = expectation(description: "trusted scope recommendation for workflow v2")
        let controller = DashboardOrganizationController(
            coordinator: coordinator,
            scanViewModel: scanViewModel,
            filterViewModel: filterViewModel,
            selectionViewModel: selectionViewModel,
            panelManager: panelManager,
            appReviewEligibility: appReviewEligibility,
            usesTestingFastPath: false,
            workflowExecution: workflowExecution.client
        )

        var capturedRecommendation: TrustedAutomationScopeRecommendation?
        controller.onShowTrustedScopeRecommendation = { recommendation in
            capturedRecommendation = recommendation
            recommendationExpectation.fulfill()
        }

        controller.organizeFile(
            file,
            context: modelContext,
            sourceSurface: .reviewFlow,
            workflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts
        )

        await fulfillment(of: [recommendationExpectation], timeout: 1.0)
        XCTAssertEqual(capturedRecommendation?.recommendedScope.scopeType, .folder)
    }

    func testOrganizeFile_WorkflowEngineV2RecordsAcceptedPersonalMemoryDecision() async throws {
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.workflowEngineV2, true)

        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        let destinationFolder = try tempDirectory.createDirectory(name: "Exports")
        let sourceURL = try tempDirectory.createFile(name: "Inbox/Accepted Report.csv", contents: "report")
        let destination = try Destination.folder(from: destinationFolder, displayName: "Exports")
        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 2_048,
            creationDate: Date(timeIntervalSince1970: 1_712_620_800),
            modificationDate: Date(timeIntervalSince1970: 1_712_620_800),
            lastAccessedDate: Date(timeIntervalSince1970: 1_712_620_800),
            location: .custom,
            scanRootPath: sourceFolder.path,
            relativeParentPath: "Inbox",
            destination: destination,
            status: .ready
        )
        file.originalSuggestedDestination = destination
        file.suggestionSourceRaw = SuggestionSource.personalMemory.rawValue
        file.confidenceScore = 0.88
        modelContext.insert(file)
        try modelContext.save()

        let workflowExecution = WorkflowExecutionSpy()
        let runExpectation = expectation(description: "workflow runner completes before memory recording assertion")
        workflowExecution.onRun = { runExpectation.fulfill() }

        let controller = DashboardOrganizationController(
            coordinator: coordinator,
            scanViewModel: scanViewModel,
            filterViewModel: filterViewModel,
            selectionViewModel: selectionViewModel,
            panelManager: panelManager,
            appReviewEligibility: appReviewEligibility,
            usesTestingFastPath: false,
            workflowExecution: workflowExecution.client
        )

        controller.organizeFile(
            file,
            context: modelContext,
            sourceSurface: .reviewFlow,
            workflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts
        )

        await fulfillment(of: [runExpectation], timeout: 1.0)
        try await Task.sleep(for: .milliseconds(50))

        let events = try modelContext.fetch(FetchDescriptor<PersonalMemoryEvent>())
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.eventKind, .acceptedSuggestion)
        XCTAssertEqual(events.first?.sourceSurface, .reviewFlow)
        XCTAssertEqual(events.first?.fileName, file.name)
        XCTAssertEqual(events.first?.fileExtension, file.fileExtension)
        XCTAssertEqual(events.first?.suggestionSource, .personalMemory)
        XCTAssertEqual(events.first?.matchedRuleID, nil)
        XCTAssertEqual(events.first?.chosenDestination?.displayName, destination.displayName)
        XCTAssertEqual(events.first?.suggestedDestination?.displayName, destination.displayName)
        XCTAssertEqual(events.first?.relativeParentPath, "Inbox")
        XCTAssertEqual(events.first?.scanRootPath, sourceFolder.path)
    }

    func testOrganizeFile_UsesLegacyCoordinatorWhenWorkflowEngineV2IsDisabled() async throws {
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.workflowEngineV2, false)

        let file = FileItem(
            path: "/Users/example/Downloads/report.pdf",
            sizeInBytes: 2_048,
            creationDate: Date(),
            destination: .mockFolder("Documents"),
            status: .ready
        )
        modelContext.insert(file)
        try modelContext.save()
        scanViewModel.replaceScannedFiles([file])
        filterViewModel.updateSourceFiles([file])

        coordinator.cannedFileAction = FileOrganizationCoordinator.FileActionData(
            filePath: file.path,
            originalPath: file.path,
            originalStatus: .ready,
            originalSuggestedDestination: file.destination?.displayName,
            destinationPath: "/Users/example/Documents/report.pdf",
            memorySnapshot: nil
        )

        let workflowExecution = WorkflowExecutionSpy()
        let controller = DashboardOrganizationController(
            coordinator: coordinator,
            scanViewModel: scanViewModel,
            filterViewModel: filterViewModel,
            selectionViewModel: selectionViewModel,
            panelManager: panelManager,
            appReviewEligibility: appReviewEligibility,
            usesTestingFastPath: false,
            workflowExecution: workflowExecution.client
        )

        controller.organizeFile(
            file,
            context: modelContext,
            sourceSurface: .reviewFlow,
            workflowTemplateID: nil
        )

        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(coordinator.organizeFileCallCount, 1)
        XCTAssertTrue(workflowExecution.plannedTemplateIDs.isEmpty)
        XCTAssertTrue(workflowExecution.ranTemplateIDs.isEmpty)
    }
}

@MainActor
private final class MockFileOrganizationCoordinator: FileOrganizationCoordinator {
    var cannedFileAction: FileActionData?
    var organizeFileCallCount = 0
    var skipFileCallCount = 0
    var lastSkippedFile: FileItem?
    var lastSkipContext: ModelContext?
    var skipFileResult = true

    override func organizeFile(
        _ file: FileItem,
        context: ModelContext?,
        sourceSurface: PersonalMemorySourceSurface = .reviewFlow,
        onSuccess: @escaping (FileActionData) -> Void,
        onError: @escaping (Error) -> Void
    ) async {
        organizeFileCallCount += 1
        guard let cannedFileAction else {
            onError(MockError.missingAction)
            return
        }

        onSuccess(cannedFileAction)
    }

    override func skipFile(_ file: FileItem, context: ModelContext?) -> Bool {
        skipFileCallCount += 1
        lastSkippedFile = file
        lastSkipContext = context
        return skipFileResult
    }

    private enum MockError: Error {
        case missingAction
    }
}

@MainActor
private final class WorkflowExecutionSpy {
    var plannedTemplateIDs: [String] = []
    var plannedInvocationContexts: [WorkflowInvocationContext] = []
    var plannedRequests: [WorkflowExecutionRequest] = []
    var ranTemplateIDs: [String] = []
    var runRequests: [WorkflowExecutionRequest] = []
    var lastPlannedFilePaths: [String] = []
    var lastRunFilePaths: [String] = []
    var onRun: (() -> Void)?

    lazy var client = WorkflowExecutionClient(
        planRequest: { [weak self] request, files in
            self?.plannedTemplateIDs.append(request.templateID)
            self?.plannedInvocationContexts.append(request.invocationContext)
            self?.plannedRequests.append(request)
            self?.lastPlannedFilePaths = files.map(\.path)
            return WorkflowPlanner().plan(
                templateID: request.templateID,
                files: files,
                invocationContext: request.invocationContext
            )
        },
        runRequest: { [weak self] request, plan, files, _ in
            let templateID = plan.definition.templateID
            let filePaths = files.map(\.path)
            await MainActor.run {
                self?.ranTemplateIDs.append(templateID)
                self?.runRequests.append(request)
                self?.lastRunFilePaths = filePaths
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
