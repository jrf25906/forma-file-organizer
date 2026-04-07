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
}

@MainActor
private final class MockFileOrganizationCoordinator: FileOrganizationCoordinator {
    var cannedFileAction: FileActionData?
    var skipFileCallCount = 0
    var lastSkippedFile: FileItem?
    var lastSkipContext: ModelContext?

    override func organizeFile(
        _ file: FileItem,
        context: ModelContext?,
        sourceSurface: PersonalMemorySourceSurface = .reviewFlow,
        onSuccess: @escaping (FileActionData) -> Void,
        onError: @escaping (Error) -> Void
    ) async {
        guard let cannedFileAction else {
            onError(MockError.missingAction)
            return
        }

        onSuccess(cannedFileAction)
    }

    override func skipFile(_ file: FileItem, context: ModelContext?) {
        skipFileCallCount += 1
        lastSkippedFile = file
        lastSkipContext = context
    }

    private enum MockError: Error {
        case missingAction
    }
}
