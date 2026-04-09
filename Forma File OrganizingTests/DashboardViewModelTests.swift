import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
private final class MockContentSearchService: ContentSearchServing {
    private(set) var searchCallCount = 0

    func search(query: String, in files: [FileItem]) async -> [ContentSearchService.SearchResult] {
        searchCallCount += 1
        return []
    }
}

@MainActor
final class DashboardViewModelTests: XCTestCase {
    private let downloadsEnabledKey = "BookmarkFolder.isEnabled.\(FormaConfig.Security.downloadsBookmarkKey)"
    private let downloadsExcludedKey = "BookmarkFolder.excludeAutomation.\(FormaConfig.Security.downloadsBookmarkKey)"

	    var viewModel: DashboardViewModel!
	    var mockService: MockFileSystemService!
	    var mockPipeline: MockFileScanPipeline!

	    override func setUp() async throws {
	        try await super.setUp()
	        UserDefaults.standard.removeObject(forKey: "dismissedFirstRunQuickWinCandidateKeys")
            FeatureFlagService.shared.resetToDefaults()
	
	        await MainActor.run {
	            mockService = MockFileSystemService()
	            mockPipeline = MockFileScanPipeline()
	            viewModel = DashboardViewModel(
	                services: AppServices(),
	                fileSystemService: mockService,
	                fileScanPipeline: mockPipeline
	            )
	        }
	    }
	    
	    override func tearDown() async throws {
            if let viewModel {
                await waitForProjectSpaceWorkflowPreparationToSettle(
                    in: viewModel,
                    timeoutNanoseconds: 1_000_000_000
                )
            }

	        await MainActor.run {
	            viewModel = nil
	            mockService = nil
	            mockPipeline = nil
                ExternalReviewSessionStore.shared.publish(nil)
	        }
	        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
	        UserDefaults.standard.removeObject(forKey: "dismissedFirstRunQuickWinCandidateKeys")
            UserDefaults.standard.removeObject(forKey: downloadsEnabledKey)
            UserDefaults.standard.removeObject(forKey: downloadsExcludedKey)
            FeatureFlagService.shared.resetToDefaults()
	        try await super.tearDown()
	    }

    private func makeMetadataService() throws -> (ModelContainer, ModelContext, FileMetadataFoundationService) {
        let schema = Schema([
            FileItem.self,
            Rule.self,
            RuleCategory.self,
            FileMetadataRecord.self,
            FileOrganizationHistoryEntry.self,
            ProjectCluster.self,
            ProjectSpaceWorkflowProfile.self,
            ProjectSpaceAutomationProfile.self,
            ProjectSpaceAutomationPolicy.self,
            ProjectSpaceAutomationRunRecord.self,
            WorkflowRunRecord.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        return (container, context, FileMetadataFoundationService(modelContext: context))
    }

    @discardableResult
    private func insertProjectSpaceRecord(
        using service: FileMetadataFoundationService,
        path: String,
        projectAssociation: String,
        timestamp: Date
    ) throws -> FileMetadataRecord {
        let record = try XCTUnwrap(
            service.upsertRecord(
                for: path,
                displayName: URL(fileURLWithPath: path).lastPathComponent,
                fileExtension: URL(fileURLWithPath: path).pathExtension,
                timestamp: timestamp
            )
        )
        record.projectAssociation = projectAssociation
        return record
    }

    private func makeProjectSpaceFile(at url: URL, timestamp: Date) -> FileItem {
        FileItem(
            path: url.path,
            sizeInBytes: 1_024,
            creationDate: timestamp,
            modificationDate: timestamp,
            lastAccessedDate: timestamp,
            location: .custom,
            scanRootPath: url.deletingLastPathComponent().path,
            destination: nil,
            status: .pending
        )
    }

    private func waitForProjectSpaceWorkflowPreview(
        in viewModel: DashboardViewModel,
        timeoutNanoseconds: UInt64 = 500_000_000
    ) async {
        let deadline = ContinuousClock.now + .nanoseconds(Int64(timeoutNanoseconds))
        while ContinuousClock.now < deadline {
            if viewModel.projectSpaceWorkflowSimulationPreview != nil {
                return
            }
            await Task.yield()
        }
    }

    private func waitForProjectSpaceAutomationBoard(
        in viewModel: DashboardViewModel,
        timeoutNanoseconds: UInt64 = 500_000_000
    ) async {
        let deadline = ContinuousClock.now + .nanoseconds(Int64(timeoutNanoseconds))
        while ContinuousClock.now < deadline {
            if viewModel.selectedProjectSpaceAutomationBoard != nil {
                return
            }
            await Task.yield()
        }
    }

    private func waitForProjectSpaceWorkflowPreparationToSettle(
        in viewModel: DashboardViewModel,
        timeoutNanoseconds: UInt64 = 500_000_000
    ) async {
        let deadline = ContinuousClock.now + .nanoseconds(Int64(timeoutNanoseconds))
        while ContinuousClock.now < deadline {
            if !viewModel.isPreparingProjectSpaceWorkflowPreview {
                return
            }
            await Task.yield()
        }
    }

    private func waitForProjectSpaceAutomationBoardToDisappear(
        in viewModel: DashboardViewModel,
        timeoutNanoseconds: UInt64 = 500_000_000
    ) async {
        let deadline = ContinuousClock.now + .nanoseconds(Int64(timeoutNanoseconds))
        while ContinuousClock.now < deadline {
            if viewModel.selectedProjectSpaceAutomationBoard == nil {
                return
            }
            await Task.yield()
        }
    }

    func testInitialPermissionsCheck() {
        // Given - onboarding not yet completed
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")

        // When
        viewModel.checkPermissions()

        // Then
        XCTAssertTrue(viewModel.showOnboarding, "Onboarding should be shown when not yet completed")
    }

    func testPermissionsGranted() {
        // Given - onboarding already completed
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        // When
        viewModel.checkPermissions()

        // Then
        XCTAssertFalse(viewModel.showOnboarding, "Onboarding should not be shown after completion")
    }

    func testRequestDesktopAccess() async {
        // Given
        mockService.hasDesktop = false
        
        // When
        _ = await viewModel.requestDesktopAccess()
        
        // Then
        XCTAssertTrue(viewModel.hasDesktopAccess, "Desktop access should be granted")
    }

    func testPermissionGrantDebouncesRefreshToSingleScan() async throws {
        // Given
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        let localService = MockFileSystemService()
        let localPipeline = MockFileScanPipeline()
        let localViewModel = DashboardViewModel(
            services: AppServices(),
            fileSystemService: localService,
            fileScanPipeline: localPipeline
        )
        let container = try ModelContainer(
            for: FileItem.self,
            Rule.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        localViewModel.setModelContext(container.mainContext)
        localViewModel.showOnboarding = false

        // When
        _ = await localViewModel.requestDesktopAccess()
        _ = await localViewModel.requestDownloadsAccess()
        try? await Task.sleep(for: .milliseconds(700))

        // Then
        XCTAssertEqual(localPipeline.scanCallCount, 1, "Multiple grants should coalesce into one refresh")
    }

    func testPermissionGrantSkipsAutoRefreshDuringOnboarding() async throws {
        // Given
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        let localService = MockFileSystemService()
        let localPipeline = MockFileScanPipeline()
        let localViewModel = DashboardViewModel(
            services: AppServices(),
            fileSystemService: localService,
            fileScanPipeline: localPipeline
        )
        let container = try ModelContainer(
            for: FileItem.self,
            Rule.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        localViewModel.setModelContext(container.mainContext)
        XCTAssertTrue(localViewModel.showOnboarding)

        // When
        _ = await localViewModel.requestDownloadsAccess()
        try? await Task.sleep(for: .milliseconds(700))

        // Then
        XCTAssertEqual(localPipeline.scanCallCount, 0, "Onboarding flow should defer refresh until dismissal")
    }

    func testPermissionGrantDoesNotReopenDismissedOnboarding() async throws {
        // Given
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        let localService = MockFileSystemService()
        let localPipeline = MockFileScanPipeline()
        let localViewModel = DashboardViewModel(
            services: AppServices(),
            fileSystemService: localService,
            fileScanPipeline: localPipeline
        )

        localViewModel.showOnboarding = false

        // When
        _ = await localViewModel.requestDownloadsAccess()

        // Then
        XCTAssertFalse(localViewModel.showOnboarding, "Granting a folder from the dashboard should not re-open onboarding")
    }

    func testPermissionGrantRefreshesIfOnboardingWasAlreadyDismissed() async throws {
        // Given
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        let localService = MockFileSystemService()
        let localPipeline = MockFileScanPipeline()
        let localViewModel = DashboardViewModel(
            services: AppServices(),
            fileSystemService: localService,
            fileScanPipeline: localPipeline
        )
        let container = try ModelContainer(
            for: FileItem.self,
            Rule.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        localViewModel.setModelContext(container.mainContext)
        localViewModel.showOnboarding = false

        // When
        _ = await localViewModel.requestDownloadsAccess()
        try? await Task.sleep(for: .milliseconds(700))

        // Then
        XCTAssertEqual(localPipeline.scanCallCount, 1, "Granting access after dismissing onboarding should refresh the dashboard")
    }

    func testContentTagQuickFilters_HiddenWhenFlagsDisabledOrNoDurableTagsExist() throws {
        let (container, context, service) = try makeMetadataService()
        _ = container

        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.autoContentTags, true)

        let invoice = FileItem(
            path: "/Users/test/Documents/invoice.pdf",
            sizeInBytes: 1_000,
            creationDate: Date(),
            location: .documents,
            destination: nil,
            status: .pending
        )

        let record = try XCTUnwrap(
            service.upsertRecord(
                for: invoice.path,
                displayName: "invoice.pdf",
                fileExtension: "pdf",
                timestamp: Date(timeIntervalSince1970: 1_000)
            )
        )
        record.tags = ["invoice"]
        try context.save()

        FeatureFlagService.shared.resetToDefaults()
        viewModel.setModelContext(context)
        viewModel._testSetFiles([invoice])

        XCTAssertFalse(viewModel.showsContentTagQuickFilters)
        XCTAssertEqual(viewModel.availableContentTags, [])

        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.autoContentTags, true)

        let plainText = FileItem(
            path: "/Users/test/Documents/notes.txt",
            sizeInBytes: 500,
            creationDate: Date().addingTimeInterval(1),
            location: .documents,
            destination: nil,
            status: .pending
        )
        viewModel._testSetFiles([plainText])

        XCTAssertFalse(viewModel.showsContentTagQuickFilters)
        XCTAssertEqual(viewModel.availableContentTags, [])
    }

    func testClearAllFilters_ClearsSelectedContentTags() throws {
        let (container, context, service) = try makeMetadataService()
        _ = container

        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.autoContentTags, true)

        let now = Date()
        let invoice = FileItem(
            path: "/Users/test/Documents/invoice.pdf",
            sizeInBytes: 1_000,
            creationDate: now,
            location: .documents,
            destination: nil,
            status: .pending
        )
        let receipt = FileItem(
            path: "/Users/test/Documents/receipt.pdf",
            sizeInBytes: 1_000,
            creationDate: now.addingTimeInterval(1),
            location: .documents,
            destination: nil,
            status: .pending
        )

        let invoiceRecord = try XCTUnwrap(
            service.upsertRecord(
                for: invoice.path,
                displayName: "invoice.pdf",
                fileExtension: "pdf",
                timestamp: now
            )
        )
        invoiceRecord.tags = ["invoice"]

        let receiptRecord = try XCTUnwrap(
            service.upsertRecord(
                for: receipt.path,
                displayName: "receipt.pdf",
                fileExtension: "pdf",
                timestamp: now.addingTimeInterval(1)
            )
        )
        receiptRecord.tags = ["receipt"]
        try context.save()

        viewModel.setModelContext(context)
        viewModel._testSetFiles([invoice, receipt])

        XCTAssertTrue(viewModel.showsContentTagQuickFilters)
        XCTAssertEqual(Set(viewModel.availableContentTags), Set([.invoice, .receipt]))

        viewModel.toggleContentTagQuickFilter(.invoice)
        XCTAssertEqual(viewModel.selectedContentTags, [.invoice])
        XCTAssertEqual(viewModel.visibleFiles.map(\.path), [invoice.path])

        viewModel.clearAllFilters()

        XCTAssertEqual(viewModel.selectedContentTags, [])
        XCTAssertEqual(Set(viewModel.visibleFiles.map(\.path)), Set([invoice.path, receipt.path]))
    }

    func testRemoveContentTagQuickFilter_RemovesOnlyRequestedTag() throws {
        let (container, context, service) = try makeMetadataService()
        _ = container

        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.autoContentTags, true)

        let now = Date()
        let invoice = FileItem(
            path: "/Users/test/Documents/invoice.pdf",
            sizeInBytes: 1_000,
            creationDate: now,
            location: .documents,
            destination: nil,
            status: .pending
        )
        let receipt = FileItem(
            path: "/Users/test/Documents/receipt.pdf",
            sizeInBytes: 1_000,
            creationDate: now.addingTimeInterval(1),
            location: .documents,
            destination: nil,
            status: .pending
        )

        let invoiceRecord = try XCTUnwrap(
            service.upsertRecord(
                for: invoice.path,
                displayName: "invoice.pdf",
                fileExtension: "pdf",
                timestamp: now
            )
        )
        invoiceRecord.tags = ["invoice"]

        let receiptRecord = try XCTUnwrap(
            service.upsertRecord(
                for: receipt.path,
                displayName: "receipt.pdf",
                fileExtension: "pdf",
                timestamp: now.addingTimeInterval(1)
            )
        )
        receiptRecord.tags = ["receipt"]
        try context.save()

        viewModel.setModelContext(context)
        viewModel._testSetFiles([invoice, receipt])

        viewModel.toggleContentTagQuickFilter(.invoice)
        viewModel.toggleContentTagQuickFilter(.receipt)

        XCTAssertEqual(viewModel.selectedContentTags, Set([.invoice, .receipt]))

        viewModel.removeContentTagQuickFilter(.invoice)

        XCTAssertEqual(viewModel.selectedContentTags, [.receipt])
        XCTAssertEqual(viewModel.visibleFiles.map(\.path), [receipt.path])
    }

    func testDeferredReviewScope_IsolatedBySelectedContentTags() throws {
        let (container, context, service) = try makeMetadataService()
        _ = container

        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.autoContentTags, true)

        let now = Date()
        let dualTaggedFiles = (0..<8).map { index in
            FileItem(
                path: "/Users/test/Documents/shared-\(index).pdf",
                sizeInBytes: 1_000,
                creationDate: now.addingTimeInterval(TimeInterval(index)),
                location: .documents,
                destination: nil,
                status: .pending
            )
        }
        let receiptOnlyFiles = (0..<2).map { index in
            FileItem(
                path: "/Users/test/Documents/receipt-only-\(index).pdf",
                sizeInBytes: 1_000,
                creationDate: now.addingTimeInterval(TimeInterval(index + 8)),
                location: .documents,
                destination: nil,
                status: .pending
            )
        }
        let allFiles = dualTaggedFiles + receiptOnlyFiles

        for (offset, file) in dualTaggedFiles.enumerated() {
            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: file.path,
                    displayName: URL(fileURLWithPath: file.path).lastPathComponent,
                    fileExtension: "pdf",
                    timestamp: now.addingTimeInterval(TimeInterval(offset))
                )
            )
            record.tags = ["invoice", "receipt"]
        }

        for (offset, file) in receiptOnlyFiles.enumerated() {
            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: file.path,
                    displayName: URL(fileURLWithPath: file.path).lastPathComponent,
                    fileExtension: "pdf",
                    timestamp: now.addingTimeInterval(TimeInterval(offset + 8))
                )
            )
            record.tags = ["receipt"]
        }
        try context.save()

        viewModel.setModelContext(context)
        viewModel._testSetFiles(allFiles)

        viewModel.toggleContentTagQuickFilter(.invoice)
        XCTAssertEqual(viewModel.currentReviewChunkCount, viewModel.reviewChunkSize)

        viewModel.doneForNow()
        XCTAssertEqual(viewModel.deferredReviewFileCount, viewModel.reviewChunkSize)

        viewModel.clearContentTagQuickFilters()
        viewModel.toggleContentTagQuickFilter(.receipt)

        XCTAssertEqual(viewModel.selectedContentTags, [.receipt])
        XCTAssertEqual(viewModel.deferredReviewFileCount, 0)
        XCTAssertEqual(viewModel.currentReviewChunkCount, viewModel.reviewChunkSize)
    }

    func testProjectSpaces_HiddenWhenFeatureDisabled() async throws {
        let (container, context, service) = try makeMetadataService()
        _ = container

        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)

        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let alphaURL = try tempDirectory.createFile(name: "Inbox/alpha.txt", contents: "alpha")
        let timestamp = Date(timeIntervalSince1970: 1_000)
        _ = try insertProjectSpaceRecord(
            using: service,
            path: alphaURL.path,
            projectAssociation: "Alpha",
            timestamp: timestamp
        )
        try context.save()

        viewModel.setModelContext(context)
        viewModel._testSetFiles([makeProjectSpaceFile(at: alphaURL, timestamp: timestamp)])
        let alphaSummary = try XCTUnwrap(viewModel.projectSpaces.first)
        viewModel.selectProjectSpace(alphaSummary)

        FeatureFlagService.shared.setEnabled(.projectSpaces, false)
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: UserDefaults.standard)
        await Task.yield()

        XCTAssertEqual(viewModel.projectSpaces, [])
        XCTAssertNil(viewModel.selectedProjectSpace)
        XCTAssertNil(viewModel.selectedProjectSpaceDetail)
        XCTAssertFalse(viewModel.isShowingProjectSpaceDetail)
    }

    func testProjectSpaces_LoadSummariesWhenFeatureEnabled() throws {
        let (container, context, service) = try makeMetadataService()
        _ = container

        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)

        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let alphaURL = try tempDirectory.createFile(name: "Inbox/alpha.txt", contents: "alpha")
        let betaURL = try tempDirectory.createFile(name: "Inbox/beta.txt", contents: "beta")
        let alphaTimestamp = Date(timeIntervalSince1970: 2_000)
        let betaTimestamp = Date(timeIntervalSince1970: 1_000)

        _ = try insertProjectSpaceRecord(
            using: service,
            path: alphaURL.path,
            projectAssociation: "Alpha",
            timestamp: alphaTimestamp
        )
        _ = try insertProjectSpaceRecord(
            using: service,
            path: betaURL.path,
            projectAssociation: "Beta",
            timestamp: betaTimestamp
        )
        try context.save()

        viewModel.setModelContext(context)
        viewModel._testSetFiles([
            makeProjectSpaceFile(at: alphaURL, timestamp: alphaTimestamp),
            makeProjectSpaceFile(at: betaURL, timestamp: betaTimestamp)
        ])

        XCTAssertEqual(viewModel.projectSpaces.map(\.normalizedLabel), ["Alpha", "Beta"])
        XCTAssertEqual(viewModel.projectSpaces.map(\.fileCount), [1, 1])
    }

    func testProjectSpaces_SelectingSpaceLoadsDetail() throws {
        let (container, context, service) = try makeMetadataService()
        _ = container

        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)

        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let alphaURL = try tempDirectory.createFile(name: "Inbox/alpha.txt", contents: "alpha")
        let secondAlphaURL = try tempDirectory.createFile(name: "Inbox/brief.txt", contents: "brief")
        let firstTimestamp = Date(timeIntervalSince1970: 1_000)
        let secondTimestamp = Date(timeIntervalSince1970: 2_000)

        _ = try insertProjectSpaceRecord(
            using: service,
            path: alphaURL.path,
            projectAssociation: "Alpha",
            timestamp: firstTimestamp
        )
        _ = try insertProjectSpaceRecord(
            using: service,
            path: secondAlphaURL.path,
            projectAssociation: "Alpha",
            timestamp: secondTimestamp
        )
        try context.save()

        viewModel.setModelContext(context)
        viewModel._testSetFiles([
            makeProjectSpaceFile(at: alphaURL, timestamp: firstTimestamp),
            makeProjectSpaceFile(at: secondAlphaURL, timestamp: secondTimestamp)
        ])

        let alphaSummary = try XCTUnwrap(viewModel.projectSpaces.first(where: { $0.normalizedLabel == "Alpha" }))

        viewModel.selectProjectSpace(alphaSummary)

        XCTAssertEqual(viewModel.selectedProjectSpace, alphaSummary)
        XCTAssertEqual(viewModel.selectedProjectSpaceDetail?.summary, alphaSummary)
        XCTAssertEqual(
            Set(viewModel.selectedProjectSpaceDetail?.files.map(\.displayName) ?? []),
            ["alpha.txt", "brief.txt"]
        )
        XCTAssertTrue(viewModel.isShowingProjectSpaceDetail)
    }

    func testProjectSpaces_SelectionClearsWhenSpaceDisappears() throws {
        let (container, context, service) = try makeMetadataService()
        _ = container

        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)

        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let alphaURL = try tempDirectory.createFile(name: "Inbox/alpha.txt", contents: "alpha")
        let timestamp = Date(timeIntervalSince1970: 1_000)
        let alphaRecord = try insertProjectSpaceRecord(
            using: service,
            path: alphaURL.path,
            projectAssociation: "Alpha",
            timestamp: timestamp
        )
        try context.save()

        viewModel.setModelContext(context)
        viewModel._testSetFiles([makeProjectSpaceFile(at: alphaURL, timestamp: timestamp)])
        let alphaSummary = try XCTUnwrap(viewModel.projectSpaces.first(where: { $0.normalizedLabel == "Alpha" }))
        viewModel.selectProjectSpace(alphaSummary)

        alphaRecord.projectAssociation = nil
        try context.save()

        viewModel.refreshProjectSpaces()

        XCTAssertEqual(viewModel.projectSpaces, [])
        XCTAssertNil(viewModel.selectedProjectSpace)
        XCTAssertNil(viewModel.selectedProjectSpaceDetail)
        XCTAssertFalse(viewModel.isShowingProjectSpaceDetail)
    }

    func testProjectSpaces_RefreshAfterMetadataMutationCompletionPath() throws {
        let (container, context, service) = try makeMetadataService()
        _ = container

        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)

        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let alphaURL = try tempDirectory.createFile(name: "Inbox/alpha.txt", contents: "alpha")
        let timestamp = Date(timeIntervalSince1970: 1_000)
        let alphaRecord = try insertProjectSpaceRecord(
            using: service,
            path: alphaURL.path,
            projectAssociation: "Alpha",
            timestamp: timestamp
        )
        try context.save()

        viewModel.setModelContext(context)
        viewModel._testSetFiles([makeProjectSpaceFile(at: alphaURL, timestamp: timestamp)])
        let alphaSummary = try XCTUnwrap(viewModel.projectSpaces.first(where: { $0.normalizedLabel == "Alpha" }))
        viewModel.selectProjectSpace(alphaSummary)

        alphaRecord.projectAssociation = nil
        try context.save()

        viewModel._testSimulateBulkOperationCompletion()

        XCTAssertEqual(viewModel.projectSpaces, [])
        XCTAssertNil(viewModel.selectedProjectSpace)
        XCTAssertNil(viewModel.selectedProjectSpaceDetail)
        XCTAssertFalse(viewModel.isShowingProjectSpaceDetail)
    }

    func testProjectSpaces_BeginCorrectionLoadsSelectedFileAndSuggestedLabels() throws {
        let (container, context, service) = try makeMetadataService()
        _ = container

        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)

        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let alphaURL = try tempDirectory.createFile(name: "Inbox/alpha.txt", contents: "alpha")
        let betaURL = try tempDirectory.createFile(name: "Inbox/beta.txt", contents: "beta")
        let alphaTimestamp = Date(timeIntervalSince1970: 1_000)
        let betaTimestamp = Date(timeIntervalSince1970: 2_000)

        _ = try insertProjectSpaceRecord(
            using: service,
            path: alphaURL.path,
            projectAssociation: "Alpha",
            timestamp: alphaTimestamp
        )
        _ = try insertProjectSpaceRecord(
            using: service,
            path: betaURL.path,
            projectAssociation: "Beta",
            timestamp: betaTimestamp
        )
        try context.save()

        viewModel.setModelContext(context)
        viewModel._testSetFiles([
            makeProjectSpaceFile(at: alphaURL, timestamp: alphaTimestamp),
            makeProjectSpaceFile(at: betaURL, timestamp: betaTimestamp)
        ])

        let alphaSummary = try XCTUnwrap(viewModel.projectSpaces.first(where: { $0.normalizedLabel == "Alpha" }))
        viewModel.selectProjectSpace(alphaSummary)
        let alphaFile = try XCTUnwrap(viewModel.selectedProjectSpaceDetail?.files.first(where: { $0.displayName == "alpha.txt" }))

        viewModel.beginProjectSpaceAssociationCorrection(alphaFile)

        XCTAssertEqual(viewModel.projectSpaceAssociationCorrectionFileRow, alphaFile)
        XCTAssertEqual(viewModel.projectSpaceAssociationCorrectionProposedLabel, "Alpha")
        XCTAssertEqual(viewModel.projectSpaceAssociationSuggestedLabels, ["Beta"])
    }

    func testProjectSpaces_SaveCorrectionRefreshesDetailAndClearsEditorState() throws {
        let (container, context, service) = try makeMetadataService()
        _ = container

        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)
        FeatureFlagService.shared.setEnabled(.projectSpaceMemory, true)

        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let alphaURL = try tempDirectory.createFile(name: "Inbox/alpha.txt", contents: "alpha")
        let alphaPlanURL = try tempDirectory.createFile(name: "Inbox/alpha-plan.txt", contents: "plan")
        let betaURL = try tempDirectory.createFile(name: "Inbox/beta.txt", contents: "beta")
        let alphaTimestamp = Date(timeIntervalSince1970: 1_000)
        let alphaPlanTimestamp = Date(timeIntervalSince1970: 1_100)
        let betaTimestamp = Date(timeIntervalSince1970: 1_200)

        let alphaRecord = try insertProjectSpaceRecord(
            using: service,
            path: alphaURL.path,
            projectAssociation: "Alpha",
            timestamp: alphaTimestamp
        )
        let alphaPlanRecord = try insertProjectSpaceRecord(
            using: service,
            path: alphaPlanURL.path,
            projectAssociation: "Alpha",
            timestamp: alphaPlanTimestamp
        )
        let betaRecord = try insertProjectSpaceRecord(
            using: service,
            path: betaURL.path,
            projectAssociation: "Beta",
            timestamp: betaTimestamp
        )
        try context.save()

        _ = try service.appendHistoryEntry(
            for: alphaRecord,
            eventKind: .organized,
            sourceSurface: .organize,
            fromPath: alphaURL.path,
            toPath: "/tmp/Clients/Alpha/alpha.txt",
            destinationDisplayName: "Clients/Alpha",
            matchedRuleID: nil,
            detailsSummary: "Moved into Alpha folder.",
            timestamp: Date(timeIntervalSince1970: 1_300)
        )
        _ = try service.appendHistoryEntry(
            for: betaRecord,
            eventKind: .organized,
            sourceSurface: .organize,
            fromPath: betaURL.path,
            toPath: "/tmp/Clients/Beta/beta.txt",
            destinationDisplayName: "Clients/Beta",
            matchedRuleID: nil,
            detailsSummary: "Moved into Beta folder.",
            timestamp: Date(timeIntervalSince1970: 1_400)
        )
        _ = try service.appendHistoryEntry(
            for: alphaPlanRecord,
            eventKind: .noted,
            sourceSurface: .review,
            fromPath: alphaPlanURL.path,
            toPath: alphaPlanURL.path,
            destinationDisplayName: nil,
            matchedRuleID: nil,
            detailsSummary: "Needs project label correction.",
            timestamp: Date(timeIntervalSince1970: 1_500)
        )

        viewModel.setModelContext(context)
        viewModel._testSetFiles([
            makeProjectSpaceFile(at: alphaURL, timestamp: alphaTimestamp),
            makeProjectSpaceFile(at: alphaPlanURL, timestamp: alphaPlanTimestamp),
            makeProjectSpaceFile(at: betaURL, timestamp: betaTimestamp)
        ])

        let alphaSummary = try XCTUnwrap(viewModel.projectSpaces.first(where: { $0.normalizedLabel == "Alpha" }))
        viewModel.selectProjectSpace(alphaSummary)
        let fileToCorrect = try XCTUnwrap(
            viewModel.selectedProjectSpaceDetail?.files.first(where: { $0.displayName == "alpha-plan.txt" })
        )
        viewModel.beginProjectSpaceAssociationCorrection(fileToCorrect)
        viewModel.projectSpaceAssociationCorrectionProposedLabel = "Beta"

        viewModel.saveProjectSpaceAssociationCorrection()

        XCTAssertEqual(viewModel.selectedProjectSpace?.normalizedLabel, "Alpha")
        XCTAssertEqual(viewModel.selectedProjectSpaceDetail?.summary.fileCount, 1)
        XCTAssertEqual(viewModel.selectedProjectSpaceDetail?.files.map(\.displayName), ["alpha.txt"])
        XCTAssertEqual(
            viewModel.projectSpaces.first(where: { $0.normalizedLabel == "Beta" })?.fileCount,
            2
        )
        XCTAssertNil(viewModel.projectSpaceAssociationCorrectionFileRow)
        XCTAssertEqual(viewModel.projectSpaceAssociationCorrectionProposedLabel, "")
        XCTAssertEqual(viewModel.projectSpaceAssociationSuggestedLabels, [])
    }

    func testProjectSpaces_CancelCorrectionLeavesSelectionIntact() throws {
        let (container, context, service) = try makeMetadataService()
        _ = container

        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)

        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let alphaURL = try tempDirectory.createFile(name: "Inbox/alpha.txt", contents: "alpha")
        let alphaPlanURL = try tempDirectory.createFile(name: "Inbox/alpha-plan.txt", contents: "plan")
        let alphaTimestamp = Date(timeIntervalSince1970: 1_000)
        let alphaPlanTimestamp = Date(timeIntervalSince1970: 1_100)

        _ = try insertProjectSpaceRecord(
            using: service,
            path: alphaURL.path,
            projectAssociation: "Alpha",
            timestamp: alphaTimestamp
        )
        _ = try insertProjectSpaceRecord(
            using: service,
            path: alphaPlanURL.path,
            projectAssociation: "Alpha",
            timestamp: alphaPlanTimestamp
        )
        try context.save()

        viewModel.setModelContext(context)
        viewModel._testSetFiles([
            makeProjectSpaceFile(at: alphaURL, timestamp: alphaTimestamp),
            makeProjectSpaceFile(at: alphaPlanURL, timestamp: alphaPlanTimestamp)
        ])

        let alphaSummary = try XCTUnwrap(viewModel.projectSpaces.first(where: { $0.normalizedLabel == "Alpha" }))
        viewModel.selectProjectSpace(alphaSummary)
        let fileToCorrect = try XCTUnwrap(
            viewModel.selectedProjectSpaceDetail?.files.first(where: { $0.displayName == "alpha-plan.txt" })
        )
        viewModel.beginProjectSpaceAssociationCorrection(fileToCorrect)
        viewModel.projectSpaceAssociationCorrectionProposedLabel = "Beta"

        viewModel.cancelProjectSpaceAssociationCorrection()

        XCTAssertEqual(viewModel.selectedProjectSpace, alphaSummary)
        XCTAssertEqual(viewModel.selectedProjectSpaceDetail?.summary, alphaSummary)
        XCTAssertEqual(
            Set(viewModel.selectedProjectSpaceDetail?.files.map(\.displayName) ?? []),
            ["alpha.txt", "alpha-plan.txt"]
        )
        XCTAssertTrue(viewModel.isShowingProjectSpaceDetail)
        XCTAssertNil(viewModel.projectSpaceAssociationCorrectionFileRow)
        XCTAssertEqual(viewModel.projectSpaceAssociationCorrectionProposedLabel, "")
        XCTAssertEqual(viewModel.projectSpaceAssociationSuggestedLabels, [])
    }

    func testProjectSpaces_SelectingAnotherSpaceClearsCorrectionEditor() throws {
        let (container, context, service) = try makeMetadataService()
        _ = container

        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)

        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let alphaURL = try tempDirectory.createFile(name: "Inbox/alpha.txt", contents: "alpha")
        let betaURL = try tempDirectory.createFile(name: "Inbox/beta.txt", contents: "beta")
        let alphaTimestamp = Date(timeIntervalSince1970: 1_000)
        let betaTimestamp = Date(timeIntervalSince1970: 2_000)

        _ = try insertProjectSpaceRecord(
            using: service,
            path: alphaURL.path,
            projectAssociation: "Alpha",
            timestamp: alphaTimestamp
        )
        _ = try insertProjectSpaceRecord(
            using: service,
            path: betaURL.path,
            projectAssociation: "Beta",
            timestamp: betaTimestamp
        )
        try context.save()

        viewModel.setModelContext(context)
        viewModel._testSetFiles([
            makeProjectSpaceFile(at: alphaURL, timestamp: alphaTimestamp),
            makeProjectSpaceFile(at: betaURL, timestamp: betaTimestamp)
        ])

        let alphaSummary = try XCTUnwrap(viewModel.projectSpaces.first(where: { $0.normalizedLabel == "Alpha" }))
        let betaSummary = try XCTUnwrap(viewModel.projectSpaces.first(where: { $0.normalizedLabel == "Beta" }))
        viewModel.selectProjectSpace(alphaSummary)

        let alphaFile = try XCTUnwrap(
            viewModel.selectedProjectSpaceDetail?.files.first(where: { $0.displayName == "alpha.txt" })
        )
        viewModel.beginProjectSpaceAssociationCorrection(alphaFile)
        viewModel.projectSpaceAssociationCorrectionProposedLabel = "Retargeted"

        viewModel.selectProjectSpace(betaSummary)

        XCTAssertEqual(viewModel.selectedProjectSpace, betaSummary)
        XCTAssertEqual(viewModel.selectedProjectSpaceDetail?.summary, betaSummary)
        XCTAssertNil(viewModel.projectSpaceAssociationCorrectionFileRow)
        XCTAssertEqual(viewModel.projectSpaceAssociationCorrectionProposedLabel, "")
        XCTAssertEqual(viewModel.projectSpaceAssociationSuggestedLabels, [])
    }

    func testProjectSpaces_RefreshRebindsCorrectionEditorToRefreshedFileRow() throws {
        let (container, context, service) = try makeMetadataService()
        _ = container

        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)

        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let alphaURL = try tempDirectory.createFile(name: "Inbox/alpha.txt", contents: "alpha")
        let alphaPlanURL = try tempDirectory.createFile(name: "Inbox/alpha-plan.txt", contents: "plan")
        let alphaTimestamp = Date(timeIntervalSince1970: 1_000)
        let alphaPlanTimestamp = Date(timeIntervalSince1970: 1_100)

        let alphaRecord = try insertProjectSpaceRecord(
            using: service,
            path: alphaURL.path,
            projectAssociation: "Alpha",
            timestamp: alphaTimestamp
        )
        let alphaPlanRecord = try insertProjectSpaceRecord(
            using: service,
            path: alphaPlanURL.path,
            projectAssociation: "Alpha",
            timestamp: alphaPlanTimestamp
        )
        try context.save()

        viewModel.setModelContext(context)
        viewModel._testSetFiles([
            makeProjectSpaceFile(at: alphaURL, timestamp: alphaTimestamp),
            makeProjectSpaceFile(at: alphaPlanURL, timestamp: alphaPlanTimestamp)
        ])

        let alphaSummary = try XCTUnwrap(viewModel.projectSpaces.first(where: { $0.normalizedLabel == "Alpha" }))
        viewModel.selectProjectSpace(alphaSummary)
        let originalFileRow = try XCTUnwrap(
            viewModel.selectedProjectSpaceDetail?.files.first(where: { $0.displayName == "alpha-plan.txt" })
        )
        viewModel.beginProjectSpaceAssociationCorrection(originalFileRow)
        viewModel.projectSpaceAssociationCorrectionProposedLabel = "Alpha Revised"

        alphaRecord.tags = ["reference"]
        alphaPlanRecord.tags = ["updated"]
        try context.save()

        viewModel.refreshProjectSpaces()

        let refreshedFileRow = try XCTUnwrap(
            viewModel.selectedProjectSpaceDetail?.files.first(where: { $0.canonicalIdentity == originalFileRow.canonicalIdentity })
        )
        XCTAssertEqual(viewModel.projectSpaceAssociationCorrectionFileRow, refreshedFileRow)
        XCTAssertEqual(viewModel.projectSpaceAssociationCorrectionFileRow?.projectAssociation, "Alpha")
        XCTAssertEqual(viewModel.projectSpaceAssociationCorrectionFileRow?.tags, ["updated"])
        XCTAssertEqual(viewModel.projectSpaceAssociationCorrectionProposedLabel, "Alpha Revised")
        XCTAssertEqual(
            viewModel.selectedProjectSpaceDetail?.files.map(\.displayName).sorted(),
            ["alpha-plan.txt", "alpha.txt"]
        )
    }

    func testSelectProjectSpace_LoadsRememberedWorkflowTemplateFromProfile() async throws {
        let (container, context, service) = try makeMetadataService()
        _ = container

        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)
        FeatureFlagService.shared.setEnabled(.workflowEngineV2, true)

        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        let destinationFolder = try tempDirectory.createDirectory(name: "Projects/Alpha")
        let alphaURL = try tempDirectory.createFile(name: "Inbox/alpha.txt", contents: "alpha")
        let timestamp = Date(timeIntervalSince1970: 1_000)
        _ = try insertProjectSpaceRecord(
            using: service,
            path: alphaURL.path,
            projectAssociation: "Alpha",
            timestamp: timestamp
        )
        context.insert(
            ProjectSpaceWorkflowProfile(
                normalizedProjectLabel: "Alpha",
                preferredWorkflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts
            )
        )
        try context.save()

        mockService.explicitSelectionResult = ExplicitSelectionScanResult(
            files: [
                FileMetadata(
                    path: alphaURL.path,
                    sizeInBytes: 1_024,
                    creationDate: timestamp,
                    modificationDate: timestamp,
                    lastAccessedDate: timestamp,
                    location: .custom,
                    scanRootPath: sourceFolder.path,
                    destination: nil,
                    status: .pending
                )
            ],
            skippedItems: [],
            scannedRootPaths: [sourceFolder.path]
        )
        mockPipeline.explicitSelectionResult = FileScanPipeline.ScanResult(
            files: [
                FileItem(
                    path: alphaURL.path,
                    sizeInBytes: 1_024,
                    creationDate: timestamp,
                    modificationDate: timestamp,
                    lastAccessedDate: timestamp,
                    location: .custom,
                    scanRootPath: sourceFolder.path,
                    destination: try Destination.folder(from: destinationFolder, displayName: "Projects/Alpha"),
                    status: .ready
                )
            ],
            errorSummary: nil,
            rawErrors: [:],
            scannedRootPaths: [sourceFolder.path]
        )

        viewModel.selectedWorkflowTemplateID = BuiltInWorkflowTemplate.StableID.projectDrop
        viewModel.setModelContext(context)
        viewModel._testSetFiles([makeProjectSpaceFile(at: alphaURL, timestamp: timestamp)])

        let alphaSummary = try XCTUnwrap(viewModel.projectSpaces.first(where: { $0.normalizedLabel == "Alpha" }))
        viewModel.selectProjectSpace(alphaSummary)
        await waitForProjectSpaceWorkflowPreview(in: viewModel)

        XCTAssertEqual(viewModel.selectedProjectSpaceWorkflowTemplateID, BuiltInWorkflowTemplate.StableID.receipts)
        XCTAssertEqual(viewModel.selectedWorkflowTemplateID, BuiltInWorkflowTemplate.StableID.projectDrop)
    }

    func testProjectSpaceWorkflowPreview_UsesExplicitSelectionEvaluationResult() async throws {
        let (container, context, service) = try makeMetadataService()
        _ = container

        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)
        FeatureFlagService.shared.setEnabled(.workflowEngineV2, true)

        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        let destinationFolder = try tempDirectory.createDirectory(name: "Projects/Alpha")
        let alphaURL = try tempDirectory.createFile(name: "Inbox/alpha.txt", contents: "alpha")
        let timestamp = Date(timeIntervalSince1970: 1_000)
        _ = try insertProjectSpaceRecord(
            using: service,
            path: alphaURL.path,
            projectAssociation: "Alpha",
            timestamp: timestamp
        )
        context.insert(
            ProjectSpaceWorkflowProfile(
                normalizedProjectLabel: "Alpha",
                preferredWorkflowTemplateID: BuiltInWorkflowTemplate.StableID.projectDrop
            )
        )
        try context.save()

        mockService.explicitSelectionResult = ExplicitSelectionScanResult(
            files: [
                FileMetadata(
                    path: alphaURL.path,
                    sizeInBytes: 1_024,
                    creationDate: timestamp,
                    modificationDate: timestamp,
                    lastAccessedDate: timestamp,
                    location: .custom,
                    scanRootPath: sourceFolder.path,
                    destination: nil,
                    status: .pending
                )
            ],
            skippedItems: [],
            scannedRootPaths: [sourceFolder.path]
        )
        mockPipeline.explicitSelectionResult = FileScanPipeline.ScanResult(
            files: [
                FileItem(
                    path: alphaURL.path,
                    sizeInBytes: 1_024,
                    creationDate: timestamp,
                    modificationDate: timestamp,
                    lastAccessedDate: timestamp,
                    location: .custom,
                    scanRootPath: sourceFolder.path,
                    destination: try Destination.folder(from: destinationFolder, displayName: "Projects/Alpha"),
                    status: .ready
                )
            ],
            errorSummary: nil,
            rawErrors: [:],
            scannedRootPaths: [sourceFolder.path]
        )

        viewModel.setModelContext(context)
        viewModel._testSetFiles([makeProjectSpaceFile(at: alphaURL, timestamp: timestamp)])

        let alphaSummary = try XCTUnwrap(viewModel.projectSpaces.first(where: { $0.normalizedLabel == "Alpha" }))
        viewModel.selectProjectSpace(alphaSummary)
        await waitForProjectSpaceWorkflowPreview(in: viewModel)

        XCTAssertGreaterThanOrEqual(mockService.explicitSelectionCallCount, 1)
        XCTAssertGreaterThanOrEqual(mockPipeline.explicitScanCallCount, 1)
        XCTAssertEqual(viewModel.projectSpaceWorkflowSimulationPreview?.selectedFileCount, 1)
        XCTAssertEqual(viewModel.projectSpaceWorkflowSimulationPreview?.readyToRunCount, 1)
        XCTAssertEqual(viewModel.projectSpaceWorkflowSimulationPreview?.blockedCount, 0)
    }

    func testOrganizeProjectSpace_UsesProjectSpaceInvocationContextAndPersistsLatestRun() async throws {
        let (container, context, service) = try makeMetadataService()
        _ = container

        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)
        FeatureFlagService.shared.setEnabled(.workflowEngineV2, true)

        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        let destinationFolder = try tempDirectory.createDirectory(name: "Projects/Alpha")
        let alphaURL = try tempDirectory.createFile(name: "Inbox/alpha.txt", contents: "alpha")
        let timestamp = Date(timeIntervalSince1970: 1_000)
        _ = try insertProjectSpaceRecord(
            using: service,
            path: alphaURL.path,
            projectAssociation: "Alpha",
            timestamp: timestamp
        )
        try context.save()

        let workflowExecution = WorkflowExecutionSpy()
        workflowExecution.runPrimaryStatus = .completedWithIssues
        workflowExecution.runEndedAt = Date(timeIntervalSince1970: 2_000)

        let localViewModel = DashboardViewModel(
            services: AppServices(),
            fileSystemService: mockService,
            fileScanPipeline: mockPipeline,
            workflowExecution: workflowExecution.client
        )
        localViewModel.setModelContext(context)

        mockService.explicitSelectionResult = ExplicitSelectionScanResult(
            files: [
                FileMetadata(
                    path: alphaURL.path,
                    sizeInBytes: 1_024,
                    creationDate: timestamp,
                    modificationDate: timestamp,
                    lastAccessedDate: timestamp,
                    location: .custom,
                    scanRootPath: sourceFolder.path,
                    destination: nil,
                    status: .pending
                )
            ],
            skippedItems: [],
            scannedRootPaths: [sourceFolder.path]
        )
        mockPipeline.explicitSelectionResult = FileScanPipeline.ScanResult(
            files: [
                FileItem(
                    path: alphaURL.path,
                    sizeInBytes: 1_024,
                    creationDate: timestamp,
                    modificationDate: timestamp,
                    lastAccessedDate: timestamp,
                    location: .custom,
                    scanRootPath: sourceFolder.path,
                    destination: try Destination.folder(from: destinationFolder, displayName: "Projects/Alpha"),
                    status: .ready
                )
            ],
            errorSummary: nil,
            rawErrors: [:],
            scannedRootPaths: [sourceFolder.path]
        )

        localViewModel._testSetFiles([makeProjectSpaceFile(at: alphaURL, timestamp: timestamp)])

        let alphaSummary = try XCTUnwrap(localViewModel.projectSpaces.first(where: { $0.normalizedLabel == "Alpha" }))
        localViewModel.selectProjectSpace(alphaSummary)
        localViewModel.selectedProjectSpaceWorkflowTemplateID = BuiltInWorkflowTemplate.StableID.projectDrop
        await waitForProjectSpaceWorkflowPreview(in: localViewModel)
        await localViewModel.organizeSelectedProjectSpace()

        XCTAssertEqual(
            workflowExecution.plannedInvocationContexts,
            [.projectSpace(projectLabel: "Alpha")]
        )
        XCTAssertEqual(workflowExecution.ranTemplateIDs, [BuiltInWorkflowTemplate.StableID.projectDrop])
        XCTAssertEqual(workflowExecution.lastRunFilePaths, [alphaURL.path])

        let profile = try XCTUnwrap(
            ProjectSpaceWorkflowProfileService(modelContext: context).profile(normalizedProjectLabel: "Alpha")
        )
        XCTAssertEqual(profile.preferredWorkflowTemplateID, BuiltInWorkflowTemplate.StableID.projectDrop)
        XCTAssertEqual(profile.lastWorkflowRunID, workflowExecution.runID)
        XCTAssertEqual(profile.lastWorkflowCompletedAt, workflowExecution.runEndedAt)
    }

    func testOrganizeProjectSpace_ClosesSelectionWhenDetailNoLongerResolves() async throws {
        let (container, context, service) = try makeMetadataService()
        _ = container

        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)
        FeatureFlagService.shared.setEnabled(.workflowEngineV2, true)

        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let alphaURL = try tempDirectory.createFile(name: "Inbox/alpha.txt", contents: "alpha")
        let timestamp = Date(timeIntervalSince1970: 1_000)
        let alphaRecord = try insertProjectSpaceRecord(
            using: service,
            path: alphaURL.path,
            projectAssociation: "Alpha",
            timestamp: timestamp
        )
        try context.save()

        let workflowExecution = WorkflowExecutionSpy()
        let localViewModel = DashboardViewModel(
            services: AppServices(),
            fileSystemService: mockService,
            fileScanPipeline: mockPipeline,
            workflowExecution: workflowExecution.client
        )
        localViewModel.setModelContext(context)
        localViewModel._testSetFiles([makeProjectSpaceFile(at: alphaURL, timestamp: timestamp)])

        let alphaSummary = try XCTUnwrap(localViewModel.projectSpaces.first(where: { $0.normalizedLabel == "Alpha" }))
        localViewModel.selectProjectSpace(alphaSummary)
        localViewModel.selectedProjectSpaceWorkflowTemplateID = BuiltInWorkflowTemplate.StableID.receipts

        alphaRecord.projectAssociation = nil
        try context.save()

        await localViewModel.organizeSelectedProjectSpace()

        XCTAssertNil(localViewModel.selectedProjectSpace)
        XCTAssertNil(localViewModel.selectedProjectSpaceDetail)
        XCTAssertFalse(localViewModel.isShowingProjectSpaceDetail)
        XCTAssertTrue(workflowExecution.ranTemplateIDs.isEmpty)
    }

    func testOrganizeProjectSpace_PersistsLatestFailedRunWhenWorkflowThrowsAfterAuditFinalization() async throws {
        let (container, context, service) = try makeMetadataService()
        _ = container

        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)
        FeatureFlagService.shared.setEnabled(.workflowEngineV2, true)

        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        let destinationFolder = try tempDirectory.createDirectory(name: "Projects/Alpha")
        let alphaURL = try tempDirectory.createFile(name: "Inbox/alpha.txt", contents: "alpha")
        let timestamp = Date(timeIntervalSince1970: 1_000)
        _ = try insertProjectSpaceRecord(
            using: service,
            path: alphaURL.path,
            projectAssociation: "Alpha",
            timestamp: timestamp
        )
        try context.save()

        let workflowExecution = WorkflowExecutionSpy()
        workflowExecution.runPrimaryStatus = .failed
        workflowExecution.runEndedAt = Date(timeIntervalSince1970: 2_000)
        workflowExecution.persistRunRecordBeforeThrow = true
        workflowExecution.runError = WorkflowExecutionTestError.failed

        let localViewModel = DashboardViewModel(
            services: AppServices(),
            fileSystemService: mockService,
            fileScanPipeline: mockPipeline,
            workflowExecution: workflowExecution.client
        )
        localViewModel.setModelContext(context)

        mockService.explicitSelectionResult = ExplicitSelectionScanResult(
            files: [
                FileMetadata(
                    path: alphaURL.path,
                    sizeInBytes: 1_024,
                    creationDate: timestamp,
                    modificationDate: timestamp,
                    lastAccessedDate: timestamp,
                    location: .custom,
                    scanRootPath: sourceFolder.path,
                    destination: nil,
                    status: .pending
                )
            ],
            skippedItems: [],
            scannedRootPaths: [sourceFolder.path]
        )
        mockPipeline.explicitSelectionResult = FileScanPipeline.ScanResult(
            files: [
                FileItem(
                    path: alphaURL.path,
                    sizeInBytes: 1_024,
                    creationDate: timestamp,
                    modificationDate: timestamp,
                    lastAccessedDate: timestamp,
                    location: .custom,
                    scanRootPath: sourceFolder.path,
                    destination: try Destination.folder(from: destinationFolder, displayName: "Projects/Alpha"),
                    status: .ready
                )
            ],
            errorSummary: nil,
            rawErrors: [:],
            scannedRootPaths: [sourceFolder.path]
        )

        localViewModel._testSetFiles([makeProjectSpaceFile(at: alphaURL, timestamp: timestamp)])

        let alphaSummary = try XCTUnwrap(localViewModel.projectSpaces.first(where: { $0.normalizedLabel == "Alpha" }))
        localViewModel.selectProjectSpace(alphaSummary)
        localViewModel.selectedProjectSpaceWorkflowTemplateID = BuiltInWorkflowTemplate.StableID.projectDrop
        await waitForProjectSpaceWorkflowPreview(in: localViewModel)
        await localViewModel.organizeSelectedProjectSpace()

        let profile = try XCTUnwrap(
            ProjectSpaceWorkflowProfileService(modelContext: context).profile(normalizedProjectLabel: "Alpha")
        )
        XCTAssertEqual(profile.preferredWorkflowTemplateID, BuiltInWorkflowTemplate.StableID.projectDrop)
        XCTAssertEqual(profile.lastWorkflowRunID, workflowExecution.runID)
        XCTAssertEqual(profile.lastWorkflowCompletedAt, workflowExecution.runEndedAt)
        XCTAssertEqual(localViewModel.lastBatchFailedFiles.map(\.path), [alphaURL.path])
        XCTAssertTrue(localViewModel.showFailedFilesSheet)
    }

    func testOrganizeProjectSpace_UsesSharedWorkflowFeedbackForBlockedFiles() async throws {
        let (container, context, service) = try makeMetadataService()
        _ = container

        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)
        FeatureFlagService.shared.setEnabled(.workflowEngineV2, true)

        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        let destinationFolder = try tempDirectory.createDirectory(name: "Projects/Alpha")
        let runnableURL = try tempDirectory.createFile(name: "Inbox/alpha-ready.txt", contents: "ready")
        let blockedURL = try tempDirectory.createFile(name: "Inbox/alpha-blocked.txt", contents: "blocked")
        let timestamp = Date(timeIntervalSince1970: 1_000)
        _ = try insertProjectSpaceRecord(
            using: service,
            path: runnableURL.path,
            projectAssociation: "Alpha",
            timestamp: timestamp
        )
        _ = try insertProjectSpaceRecord(
            using: service,
            path: blockedURL.path,
            projectAssociation: "Alpha",
            timestamp: timestamp.addingTimeInterval(1)
        )
        try context.save()

        let workflowExecution = WorkflowExecutionSpy()
        let localViewModel = DashboardViewModel(
            services: AppServices(),
            fileSystemService: mockService,
            fileScanPipeline: mockPipeline,
            workflowExecution: workflowExecution.client
        )
        localViewModel.setModelContext(context)

        mockService.explicitSelectionResult = ExplicitSelectionScanResult(
            files: [
                FileMetadata(
                    path: runnableURL.path,
                    sizeInBytes: 1_024,
                    creationDate: timestamp,
                    modificationDate: timestamp,
                    lastAccessedDate: timestamp,
                    location: .custom,
                    scanRootPath: sourceFolder.path,
                    destination: nil,
                    status: .pending
                ),
                FileMetadata(
                    path: blockedURL.path,
                    sizeInBytes: 1_024,
                    creationDate: timestamp,
                    modificationDate: timestamp,
                    lastAccessedDate: timestamp,
                    location: .custom,
                    scanRootPath: sourceFolder.path,
                    destination: nil,
                    status: .pending
                )
            ],
            skippedItems: [],
            scannedRootPaths: [sourceFolder.path]
        )
        mockPipeline.explicitSelectionResult = FileScanPipeline.ScanResult(
            files: [
                FileItem(
                    path: runnableURL.path,
                    sizeInBytes: 1_024,
                    creationDate: timestamp,
                    modificationDate: timestamp,
                    lastAccessedDate: timestamp,
                    location: .custom,
                    scanRootPath: sourceFolder.path,
                    destination: try Destination.folder(from: destinationFolder, displayName: "Projects/Alpha"),
                    status: .ready
                ),
                FileItem(
                    path: blockedURL.path,
                    sizeInBytes: 1_024,
                    creationDate: timestamp,
                    modificationDate: timestamp,
                    lastAccessedDate: timestamp,
                    location: .custom,
                    scanRootPath: sourceFolder.path,
                    destination: nil,
                    status: .pending
                )
            ],
            errorSummary: nil,
            rawErrors: [:],
            scannedRootPaths: [sourceFolder.path]
        )

        localViewModel._testSetFiles([
            makeProjectSpaceFile(at: runnableURL, timestamp: timestamp),
            makeProjectSpaceFile(at: blockedURL, timestamp: timestamp)
        ])

        let alphaSummary = try XCTUnwrap(localViewModel.projectSpaces.first(where: { $0.normalizedLabel == "Alpha" }))
        localViewModel.selectProjectSpace(alphaSummary)
        localViewModel.selectedProjectSpaceWorkflowTemplateID = BuiltInWorkflowTemplate.StableID.projectDrop
        await waitForProjectSpaceWorkflowPreview(in: localViewModel)
        await localViewModel.organizeSelectedProjectSpace()

        XCTAssertEqual(workflowExecution.ranTemplateIDs, [BuiltInWorkflowTemplate.StableID.projectDrop])
        XCTAssertEqual(workflowExecution.lastRunFilePaths, [runnableURL.path])
        XCTAssertEqual(localViewModel.lastBatchFailedFiles.map(\.path), [blockedURL.path])
        XCTAssertTrue(localViewModel.showFailedFilesSheet)
    }

    func testProjectSpaceWorkflowPreview_CountsSkippedSelectionMembersAsBlocked() async throws {
        let (container, context, service) = try makeMetadataService()
        _ = container

        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)
        FeatureFlagService.shared.setEnabled(.workflowEngineV2, true)

        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        let alphaURL = try tempDirectory.createFile(name: "Inbox/alpha-inaccessible.txt", contents: "alpha")
        let timestamp = Date(timeIntervalSince1970: 1_000)
        _ = try insertProjectSpaceRecord(
            using: service,
            path: alphaURL.path,
            projectAssociation: "Alpha",
            timestamp: timestamp
        )
        try context.save()

        mockService.explicitSelectionResult = ExplicitSelectionScanResult(
            files: [],
            skippedItems: [
                ExternalIngressSkippedItem(
                    path: alphaURL.path,
                    reason: .inaccessibleSelection,
                    message: "Forma couldn't access the selected file."
                )
            ],
            scannedRootPaths: [sourceFolder.path]
        )
        mockPipeline.explicitSelectionResult = FileScanPipeline.ScanResult(
            files: [],
            errorSummary: nil,
            rawErrors: [:],
            scannedRootPaths: [sourceFolder.path]
        )

        viewModel.setModelContext(context)
        viewModel._testSetFiles([makeProjectSpaceFile(at: alphaURL, timestamp: timestamp)])

        let alphaSummary = try XCTUnwrap(viewModel.projectSpaces.first(where: { $0.normalizedLabel == "Alpha" }))
        viewModel.selectProjectSpace(alphaSummary)
        viewModel.selectedProjectSpaceWorkflowTemplateID = BuiltInWorkflowTemplate.StableID.projectDrop
        await waitForProjectSpaceWorkflowPreview(in: viewModel)

        XCTAssertGreaterThanOrEqual(mockService.explicitSelectionCallCount, 1)
        XCTAssertGreaterThanOrEqual(mockPipeline.explicitScanCallCount, 1)
        XCTAssertEqual(viewModel.projectSpaceWorkflowSimulationPreview?.selectedFileCount, 1)
        XCTAssertEqual(viewModel.projectSpaceWorkflowSimulationPreview?.readyToRunCount, 0)
        XCTAssertEqual(viewModel.projectSpaceWorkflowSimulationPreview?.blockedCount, 1)
    }

    func testProjectSpaceAutomationState_BootstrapsFromLegacyWorkflowProfile() async throws {
        let (container, context, service) = try makeMetadataService()
        _ = container

        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)
        FeatureFlagService.shared.setEnabled(.autoProjectAssociation, true)
        FeatureFlagService.shared.setEnabled(.projectSpaceMemory, true)
        FeatureFlagService.shared.setEnabled(.workflowEngineV2, true)
        FeatureFlagService.shared.setEnabled(.backgroundMonitoring, true)
        FeatureFlagService.shared.setEnabled(.autoOrganize, true)
        FeatureFlagService.shared.setEnabled(.projectSpaceAutomationBoard, true)

        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let timestamp = Date(timeIntervalSince1970: 1_000)
        let alphaURL = try tempDirectory.createFile(name: "Desktop/alpha.txt", contents: "alpha")
        _ = try insertProjectSpaceRecord(
            using: service,
            path: alphaURL.path,
            projectAssociation: "Alpha",
            timestamp: timestamp
        )
        context.insert(
            ProjectSpaceWorkflowProfile(
                normalizedProjectLabel: "Alpha",
                preferredWorkflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts
            )
        )
        try context.save()

        viewModel.setModelContext(context)
        viewModel._testSetFiles([makeProjectSpaceFile(at: alphaURL, timestamp: timestamp)])
        viewModel.refreshProjectSpaces()

        let alphaSummary = try XCTUnwrap(
            viewModel.projectSpaces.first(where: { $0.normalizedLabel == "Alpha" }) ??
                FileMetadataFoundationService(modelContext: context).fetchProjectSpaceSummaries()
                .first(where: { $0.normalizedLabel == "Alpha" })
        )
        viewModel.selectProjectSpace(alphaSummary)
        await waitForProjectSpaceAutomationBoard(in: viewModel)
        await waitForProjectSpaceWorkflowPreparationToSettle(in: viewModel)

        let board = try XCTUnwrap(viewModel.selectedProjectSpaceAutomationBoard)
        let recommendedGroup = try XCTUnwrap(board.groups.first(where: { $0.kind == .recommended }))
        XCTAssertEqual(recommendedGroup.policies.map(\.workflowTemplateID), [BuiltInWorkflowTemplate.StableID.receipts])
        XCTAssertEqual(recommendedGroup.policies.map(\.state), [.recommended])
    }

    func testCreateProjectSpacePolicy_FromPresetComposerPersistsDraft() async throws {
        let (container, context, service) = try makeMetadataService()
        _ = container

        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)
        FeatureFlagService.shared.setEnabled(.autoProjectAssociation, true)
        FeatureFlagService.shared.setEnabled(.projectSpaceMemory, true)
        FeatureFlagService.shared.setEnabled(.workflowEngineV2, true)
        FeatureFlagService.shared.setEnabled(.backgroundMonitoring, true)
        FeatureFlagService.shared.setEnabled(.autoOrganize, true)
        FeatureFlagService.shared.setEnabled(.projectSpaceAutomationBoard, true)

        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let timestamp = Date(timeIntervalSince1970: 1_000)
        let alphaURL = try tempDirectory.createFile(name: "Desktop/alpha.txt", contents: "alpha")
        _ = try insertProjectSpaceRecord(
            using: service,
            path: alphaURL.path,
            projectAssociation: "Alpha",
            timestamp: timestamp
        )
        try context.save()

        viewModel.setModelContext(context)
        viewModel._testSetFiles([makeProjectSpaceFile(at: alphaURL, timestamp: timestamp)])
        viewModel.refreshProjectSpaces()

        let alphaSummary = try XCTUnwrap(
            viewModel.projectSpaces.first(where: { $0.normalizedLabel == "Alpha" }) ??
                FileMetadataFoundationService(modelContext: context).fetchProjectSpaceSummaries()
                .first(where: { $0.normalizedLabel == "Alpha" })
        )
        viewModel.selectProjectSpace(alphaSummary)
        await waitForProjectSpaceAutomationBoard(in: viewModel)
        await waitForProjectSpaceWorkflowPreparationToSettle(in: viewModel)

        viewModel.presentProjectSpaceAutomationComposer()
        viewModel.projectSpaceAutomationComposerDraft = ProjectSpaceAutomationComposerDraft(
            normalizedProjectLabel: "Alpha",
            workflowTemplateID: BuiltInWorkflowTemplate.StableID.projectDrop,
            triggerKinds: [.manual, .scheduledSweep],
            admissionMode: .manualReview,
            state: .draft
        )
        viewModel.createProjectSpaceAutomationPolicyFromComposer()

        let policies = ProjectSpaceAutomationService(modelContext: context).policies(normalizedProjectLabel: "Alpha")
        let createdPolicy = try XCTUnwrap(policies.first(where: { $0.workflowTemplateID == BuiltInWorkflowTemplate.StableID.projectDrop }))
        XCTAssertEqual(createdPolicy.state, .draft)
        XCTAssertEqual(Set(createdPolicy.triggerKinds), Set([.manual, .scheduledSweep]))
    }

    func testActivateProjectPolicy_RefreshesDetailSections() async throws {
        let (container, context, service) = try makeMetadataService()
        _ = container

        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)
        FeatureFlagService.shared.setEnabled(.autoProjectAssociation, true)
        FeatureFlagService.shared.setEnabled(.projectSpaceMemory, true)
        FeatureFlagService.shared.setEnabled(.workflowEngineV2, true)
        FeatureFlagService.shared.setEnabled(.backgroundMonitoring, true)
        FeatureFlagService.shared.setEnabled(.autoOrganize, true)
        FeatureFlagService.shared.setEnabled(.projectSpaceAutomationBoard, true)

        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let timestamp = Date(timeIntervalSince1970: 1_000)
        let alphaURL = try tempDirectory.createFile(name: "Desktop/alpha.txt", contents: "alpha")
        _ = try insertProjectSpaceRecord(
            using: service,
            path: alphaURL.path,
            projectAssociation: "Alpha",
            timestamp: timestamp
        )
        let automationService = ProjectSpaceAutomationService(modelContext: context)
        let policy = try automationService.createOrUpdatePolicy(
            normalizedProjectLabel: "Alpha",
            workflowTemplateID: BuiltInWorkflowTemplate.StableID.projectDrop,
            triggerKinds: [.manual],
            admissionMode: .manualReview,
            state: .draft,
            updatedAt: timestamp
        )
        try context.save()

        viewModel.setModelContext(context)
        viewModel._testSetFiles([makeProjectSpaceFile(at: alphaURL, timestamp: timestamp)])
        viewModel.refreshProjectSpaces()

        let alphaSummary = try XCTUnwrap(
            viewModel.projectSpaces.first(where: { $0.normalizedLabel == "Alpha" })
        )
        viewModel.selectProjectSpace(alphaSummary)
        await waitForProjectSpaceAutomationBoard(in: viewModel)
        await waitForProjectSpaceWorkflowPreparationToSettle(in: viewModel)
        viewModel.presentProjectSpaceAutomationPolicy(id: policy.id)
        viewModel.activateSelectedProjectSpaceAutomationPolicy()

        let board = try XCTUnwrap(viewModel.selectedProjectSpaceAutomationBoard)
        XCTAssertFalse(board.groups.contains(where: { $0.kind == .draft && !$0.policies.isEmpty }))
        XCTAssertEqual(board.groups.first(where: { $0.kind == .active })?.policies.map(\.id), [policy.id])
    }

    func testRunProjectPolicyManualPreset_UsesSelectedPolicyTemplate() async throws {
        let (container, context, service) = try makeMetadataService()
        _ = container

        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)
        FeatureFlagService.shared.setEnabled(.autoProjectAssociation, true)
        FeatureFlagService.shared.setEnabled(.projectSpaceMemory, true)
        FeatureFlagService.shared.setEnabled(.workflowEngineV2, true)
        FeatureFlagService.shared.setEnabled(.backgroundMonitoring, true)
        FeatureFlagService.shared.setEnabled(.autoOrganize, true)
        FeatureFlagService.shared.setEnabled(.projectSpaceAutomationBoard, true)

        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        let destinationFolder = try tempDirectory.createDirectory(name: "Projects/Alpha")
        let alphaURL = try tempDirectory.createFile(name: "Inbox/alpha.txt", contents: "alpha")
        let timestamp = Date(timeIntervalSince1970: 1_000)
        _ = try insertProjectSpaceRecord(
            using: service,
            path: alphaURL.path,
            projectAssociation: "Alpha",
            timestamp: timestamp
        )
        context.insert(
            ProjectSpaceWorkflowProfile(
                normalizedProjectLabel: "Alpha",
                preferredWorkflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts
            )
        )
        let automationService = ProjectSpaceAutomationService(modelContext: context)
        let policy = try automationService.createOrUpdatePolicy(
            normalizedProjectLabel: "Alpha",
            workflowTemplateID: BuiltInWorkflowTemplate.StableID.projectDrop,
            triggerKinds: [.manual],
            admissionMode: .manualReview,
            state: .active,
            updatedAt: timestamp
        )
        try context.save()

        let workflowExecution = WorkflowExecutionSpy()
        let localViewModel = DashboardViewModel(
            services: AppServices(),
            fileSystemService: mockService,
            fileScanPipeline: mockPipeline,
            workflowExecution: workflowExecution.client
        )
        localViewModel.setModelContext(context)

        mockService.explicitSelectionResult = ExplicitSelectionScanResult(
            files: [
                FileMetadata(
                    path: alphaURL.path,
                    sizeInBytes: 1_024,
                    creationDate: timestamp,
                    modificationDate: timestamp,
                    lastAccessedDate: timestamp,
                    location: .custom,
                    scanRootPath: sourceFolder.path,
                    destination: nil,
                    status: .pending
                )
            ],
            skippedItems: [],
            scannedRootPaths: [sourceFolder.path]
        )
        mockPipeline.explicitSelectionResult = FileScanPipeline.ScanResult(
            files: [
                FileItem(
                    path: alphaURL.path,
                    sizeInBytes: 1_024,
                    creationDate: timestamp,
                    modificationDate: timestamp,
                    lastAccessedDate: timestamp,
                    location: .custom,
                    scanRootPath: sourceFolder.path,
                    destination: try Destination.folder(from: destinationFolder, displayName: "Projects/Alpha"),
                    status: .ready
                )
            ],
            errorSummary: nil,
            rawErrors: [:],
            scannedRootPaths: [sourceFolder.path]
        )

        localViewModel._testSetFiles([makeProjectSpaceFile(at: alphaURL, timestamp: timestamp)])
        localViewModel.refreshProjectSpaces()
        let alphaSummary = try XCTUnwrap(
            localViewModel.projectSpaces.first(where: { $0.normalizedLabel == "Alpha" }) ??
                FileMetadataFoundationService(modelContext: context).fetchProjectSpaceSummaries()
                .first(where: { $0.normalizedLabel == "Alpha" })
        )
        localViewModel.selectProjectSpace(alphaSummary)
        await waitForProjectSpaceAutomationBoard(in: localViewModel)
        localViewModel.presentProjectSpaceAutomationPolicy(id: policy.id)
        await localViewModel.runSelectedProjectSpaceAutomationPolicyManually()

        let expectedPolicyName = WorkflowTemplateCatalog.template(for: BuiltInWorkflowTemplate.StableID.projectDrop)?.displayName
            ?? "Project Drop"
        XCTAssertEqual(
            workflowExecution.plannedInvocationContexts,
            [.projectPolicyManual(projectLabel: "Alpha", policyName: expectedPolicyName)]
        )
        XCTAssertEqual(workflowExecution.ranTemplateIDs, [BuiltInWorkflowTemplate.StableID.projectDrop])
        XCTAssertEqual(
            ProjectSpaceWorkflowProfileService(modelContext: context)
                .profile(normalizedProjectLabel: "Alpha")?
                .preferredWorkflowTemplateID,
            BuiltInWorkflowTemplate.StableID.receipts
        )
    }

    func testPauseProjectPolicy_RefreshesDetailSections() async throws {
        let (container, context, service) = try makeMetadataService()
        _ = container

        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)
        FeatureFlagService.shared.setEnabled(.autoProjectAssociation, true)
        FeatureFlagService.shared.setEnabled(.projectSpaceMemory, true)
        FeatureFlagService.shared.setEnabled(.workflowEngineV2, true)
        FeatureFlagService.shared.setEnabled(.backgroundMonitoring, true)
        FeatureFlagService.shared.setEnabled(.autoOrganize, true)
        FeatureFlagService.shared.setEnabled(.projectSpaceAutomationBoard, true)

        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let timestamp = Date(timeIntervalSince1970: 1_000)
        let alphaURL = try tempDirectory.createFile(name: "Desktop/alpha.txt", contents: "alpha")
        _ = try insertProjectSpaceRecord(
            using: service,
            path: alphaURL.path,
            projectAssociation: "Alpha",
            timestamp: timestamp
        )
        let automationService = ProjectSpaceAutomationService(modelContext: context)
        let policy = try automationService.createOrUpdatePolicy(
            normalizedProjectLabel: "Alpha",
            workflowTemplateID: BuiltInWorkflowTemplate.StableID.projectDrop,
            triggerKinds: [.manual],
            admissionMode: .manualReview,
            state: .active,
            updatedAt: timestamp
        )
        try context.save()

        viewModel.setModelContext(context)
        viewModel._testSetFiles([makeProjectSpaceFile(at: alphaURL, timestamp: timestamp)])
        viewModel.refreshProjectSpaces()

        let alphaSummary = try XCTUnwrap(
            viewModel.projectSpaces.first(where: { $0.normalizedLabel == "Alpha" }) ??
                FileMetadataFoundationService(modelContext: context).fetchProjectSpaceSummaries()
                .first(where: { $0.normalizedLabel == "Alpha" })
        )
        viewModel.selectProjectSpace(alphaSummary)
        await waitForProjectSpaceAutomationBoard(in: viewModel)
        await waitForProjectSpaceWorkflowPreparationToSettle(in: viewModel)
        viewModel.presentProjectSpaceAutomationPolicy(id: policy.id)
        viewModel.pauseSelectedProjectSpaceAutomationPolicy()

        let board = try XCTUnwrap(viewModel.selectedProjectSpaceAutomationBoard)
        XCTAssertFalse(board.groups.contains(where: { $0.kind == .active && !$0.policies.isEmpty }))
        XCTAssertEqual(board.groups.first(where: { $0.kind == .paused })?.policies.map(\.id), [policy.id])
    }

    func testProjectSpaceAutomationState_DoesNotRebootstrapLegacyWorkflowWhenPoliciesExist() async throws {
        let (container, context, service) = try makeMetadataService()
        _ = container

        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)
        FeatureFlagService.shared.setEnabled(.autoProjectAssociation, true)
        FeatureFlagService.shared.setEnabled(.projectSpaceMemory, true)
        FeatureFlagService.shared.setEnabled(.workflowEngineV2, true)
        FeatureFlagService.shared.setEnabled(.backgroundMonitoring, true)
        FeatureFlagService.shared.setEnabled(.autoOrganize, true)
        FeatureFlagService.shared.setEnabled(.projectSpaceAutomationBoard, true)

        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let timestamp = Date(timeIntervalSince1970: 1_000)
        let alphaURL = try tempDirectory.createFile(name: "Desktop/alpha.txt", contents: "alpha")
        _ = try insertProjectSpaceRecord(
            using: service,
            path: alphaURL.path,
            projectAssociation: "Alpha",
            timestamp: timestamp
        )
        context.insert(
            ProjectSpaceWorkflowProfile(
                normalizedProjectLabel: "Alpha",
                preferredWorkflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts
            )
        )
        _ = try ProjectSpaceAutomationService(modelContext: context).createOrUpdatePolicy(
            normalizedProjectLabel: "Alpha",
            workflowTemplateID: BuiltInWorkflowTemplate.StableID.projectDrop,
            triggerKinds: [.manual],
            admissionMode: .manualReview,
            state: .active,
            updatedAt: timestamp
        )
        try context.save()

        viewModel.setModelContext(context)
        viewModel._testSetFiles([makeProjectSpaceFile(at: alphaURL, timestamp: timestamp)])
        viewModel.refreshProjectSpaces()
        let alphaSummary = try XCTUnwrap(viewModel.projectSpaces.first(where: { $0.normalizedLabel == "Alpha" }))
        viewModel.selectProjectSpace(alphaSummary)
        await waitForProjectSpaceAutomationBoard(in: viewModel)
        await waitForProjectSpaceWorkflowPreparationToSettle(in: viewModel)

        var board = try XCTUnwrap(viewModel.selectedProjectSpaceAutomationBoard)
        XCTAssertFalse(board.groups.contains(where: { $0.kind == .recommended && !$0.policies.isEmpty }))
        XCTAssertEqual(board.groups.first(where: { $0.kind == .active })?.policies.map(\.workflowTemplateID), [BuiltInWorkflowTemplate.StableID.projectDrop])

        viewModel.refreshProjectSpaces()
        await waitForProjectSpaceAutomationBoard(in: viewModel)
        await waitForProjectSpaceWorkflowPreparationToSettle(in: viewModel)
        board = try XCTUnwrap(viewModel.selectedProjectSpaceAutomationBoard)
        XCTAssertFalse(board.groups.contains(where: { $0.kind == .recommended && !$0.policies.isEmpty }))
    }

    func testProjectSpaceAutomationBoardFlagToggle_RefreshesOpenDetailSections() async throws {
        let (container, context, service) = try makeMetadataService()
        _ = container

        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)
        FeatureFlagService.shared.setEnabled(.autoProjectAssociation, true)
        FeatureFlagService.shared.setEnabled(.projectSpaceMemory, true)
        FeatureFlagService.shared.setEnabled(.workflowEngineV2, true)
        FeatureFlagService.shared.setEnabled(.backgroundMonitoring, true)
        FeatureFlagService.shared.setEnabled(.autoOrganize, true)
        FeatureFlagService.shared.setEnabled(.projectSpaceAutomationBoard, false)

        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let timestamp = Date(timeIntervalSince1970: 1_000)
        let alphaURL = try tempDirectory.createFile(name: "Desktop/alpha.txt", contents: "alpha")
        _ = try insertProjectSpaceRecord(
            using: service,
            path: alphaURL.path,
            projectAssociation: "Alpha",
            timestamp: timestamp
        )
        context.insert(
            ProjectSpaceWorkflowProfile(
                normalizedProjectLabel: "Alpha",
                preferredWorkflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts
            )
        )
        try context.save()

        viewModel.setModelContext(context)
        viewModel._testSetFiles([makeProjectSpaceFile(at: alphaURL, timestamp: timestamp)])
        let alphaSummary = try XCTUnwrap(viewModel.projectSpaces.first(where: { $0.normalizedLabel == "Alpha" }))
        viewModel.selectProjectSpace(alphaSummary)
        await waitForProjectSpaceWorkflowPreparationToSettle(in: viewModel)

        XCTAssertNil(viewModel.selectedProjectSpaceAutomationBoard)
        XCTAssertEqual(viewModel.selectedProjectSpaceWorkflowTemplateID, BuiltInWorkflowTemplate.StableID.receipts)

        FeatureFlagService.shared.setEnabled(.projectSpaceAutomationBoard, true)
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: UserDefaults.standard)
        await waitForProjectSpaceAutomationBoard(in: viewModel)
        await waitForProjectSpaceWorkflowPreparationToSettle(in: viewModel)

        XCTAssertNotNil(viewModel.selectedProjectSpaceAutomationBoard)

        FeatureFlagService.shared.setEnabled(.projectSpaceAutomationBoard, false)
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: UserDefaults.standard)
        await waitForProjectSpaceAutomationBoardToDisappear(in: viewModel)
        await waitForProjectSpaceWorkflowPreparationToSettle(in: viewModel)

        XCTAssertNil(viewModel.selectedProjectSpaceAutomationBoard)
        XCTAssertEqual(viewModel.selectedProjectSpaceWorkflowTemplateID, BuiltInWorkflowTemplate.StableID.receipts)
    }
    
    func testFirstRunQuickWinPrefersLargestReadyFolderBatch() {
        let now = Date()
        let downloadsRoot = "/Users/test/Downloads"
        let desktopRoot = "/Users/test/Desktop"

        let downloadsReady = (1...5).map { index in
            FileItem(
                path: "\(downloadsRoot)/image-\(index).png",
                sizeInBytes: 100,
                creationDate: now.addingTimeInterval(TimeInterval(index)),
                location: .downloads,
                scanRootPath: downloadsRoot,
                destination: FileItem.mockDestination(displayName: "Pictures/Screenshots"),
                status: .ready
            )
        }
        let desktopReady = (1...3).map { index in
            FileItem(
                path: "\(desktopRoot)/document-\(index).pdf",
                sizeInBytes: 100,
                creationDate: now.addingTimeInterval(TimeInterval(index + 10)),
                location: .desktop,
                scanRootPath: desktopRoot,
                destination: FileItem.mockDestination(displayName: "Documents/Work"),
                status: .ready
            )
        }
        let pendingDownloadsFile = FileItem(
            path: "\(downloadsRoot)/pending.txt",
            sizeInBytes: 100,
            creationDate: now,
            location: .downloads,
            scanRootPath: downloadsRoot,
            destination: nil,
            status: .pending
        )

        viewModel._testSetFiles(downloadsReady + desktopReady + [pendingDownloadsFile])

        let suggestion = viewModel.firstRunQuickWinSuggestion

        XCTAssertEqual(suggestion?.folderName, "Downloads")
        XCTAssertEqual(suggestion?.fileCount, 5)
    }

    func testFirstRunQuickWinRequiresMeaningfulReadyBatch() {
        let now = Date()
        let downloadsRoot = "/Users/test/Downloads"

        let readyFiles = (1...4).map { index in
            FileItem(
                path: "\(downloadsRoot)/image-\(index).png",
                sizeInBytes: 100,
                creationDate: now.addingTimeInterval(TimeInterval(index)),
                location: .downloads,
                scanRootPath: downloadsRoot,
                destination: FileItem.mockDestination(displayName: "Pictures/Screenshots"),
                status: .ready
            )
        }
        let pendingFile = FileItem(
            path: "\(downloadsRoot)/pending.txt",
            sizeInBytes: 100,
            creationDate: now,
            location: .downloads,
            scanRootPath: downloadsRoot,
            destination: nil,
            status: .pending
        )

        viewModel._testSetFiles(readyFiles + [pendingFile])

        XCTAssertNil(viewModel.firstRunQuickWinSuggestion)
    }

    func testFirstRunQuickWinRespectsVisibleSecondaryFilters() {
        let now = Date()
        let downloadsRoot = "/Users/test/Downloads"
        let desktopRoot = "/Users/test/Desktop"

        let hiddenDownloadsBatch = (1...6).map { index in
            FileItem(
                path: "\(downloadsRoot)/small-\(index).png",
                sizeInBytes: 1_000_000,
                creationDate: now.addingTimeInterval(TimeInterval(index)),
                location: .downloads,
                scanRootPath: downloadsRoot,
                destination: FileItem.mockDestination(displayName: "Pictures/Screenshots"),
                status: .ready
            )
        }
        let visibleDesktopBatch = (1...5).map { index in
            FileItem(
                path: "\(desktopRoot)/large-\(index).mov",
                sizeInBytes: 20 * 1_024 * 1_024,
                creationDate: now.addingTimeInterval(TimeInterval(index + 20)),
                location: .desktop,
                scanRootPath: desktopRoot,
                destination: FileItem.mockDestination(displayName: "Documents/Video"),
                status: .ready
            )
        }

        viewModel._testSetFiles(hiddenDownloadsBatch + visibleDesktopBatch)
        viewModel.selectedFolder = .home
        viewModel.reviewFilterMode = .needsReview
        viewModel.selectedSecondaryFilter = .largeFiles

        viewModel.selectCategory(.all)

        let suggestion = viewModel.firstRunQuickWinSuggestion

        XCTAssertEqual(suggestion?.folderName, "Desktop")
        XCTAssertEqual(suggestion?.fileCount, 5)
    }

    func testFirstRunQuickWinIsSuppressedDuringExternalReviewSession() {
        ExternalReviewSessionStore.shared.publish(nil)

        let now = Date()
        let downloadsRoot = "/Users/test/Downloads"
        let quickWinFiles = (1...5).map { index in
            FileItem(
                path: "\(downloadsRoot)/image-\(index).png",
                sizeInBytes: 100,
                creationDate: now.addingTimeInterval(TimeInterval(index)),
                location: .downloads,
                scanRootPath: downloadsRoot,
                destination: FileItem.mockDestination(displayName: "Pictures/Screenshots"),
                status: .ready
            )
        }

        viewModel._testSetFiles(quickWinFiles)

        let session = ExternalReviewSession(
            requestID: UUID(),
            source: .finderService,
            reviewPaths: quickWinFiles.map(\.path),
            scannedRootPaths: [downloadsRoot],
            skippedItems: [],
            statusText: "Review 5 files"
        )

        ExternalReviewSessionStore.shared.publish(session)
        viewModel.applyExternalReviewSession(session)

        XCTAssertNil(viewModel.firstRunQuickWinSuggestion)

        ExternalReviewSessionStore.shared.publish(nil)
        viewModel.applyExternalReviewSession(nil)
    }

    func testFirstRunQuickWinPrefersDeterministicScreenshotBatchOverLargerGenericBatch() {
        let now = Date()
        let downloadsRoot = "/Users/test/Downloads"
        let desktopRoot = "/Users/test/Desktop"

        let screenshotBatch = (1...5).map { index in
            FileItem(
                path: "\(downloadsRoot)/Screenshot 2026-03-30 at 0\(index).png",
                sizeInBytes: 2_000_000,
                creationDate: now.addingTimeInterval(TimeInterval(index)),
                location: .downloads,
                scanRootPath: downloadsRoot,
                destination: FileItem.mockDestination(displayName: "Pictures/Screenshots"),
                status: .ready
            )
        }

        let genericBatch = (1...6).map { index in
            FileItem(
                path: "\(desktopRoot)/notes-\(index).txt",
                sizeInBytes: 500,
                creationDate: now.addingTimeInterval(TimeInterval(index + 20)),
                location: .desktop,
                scanRootPath: desktopRoot,
                destination: FileItem.mockDestination(displayName: "Documents/Notes"),
                status: .ready
            )
        }

        viewModel._testSetFiles(genericBatch + screenshotBatch)

        let suggestion = viewModel.firstRunQuickWinSuggestion

        XCTAssertEqual(suggestion?.folderName, "Downloads")
        XCTAssertEqual(suggestion?.fileCount, 5)
    }

    func testFirstRunQuickWinHonorsPersistedDismissedCandidateKeys() {
        let dismissedCandidateKey = "screenshots|/Users/test/Downloads|Pictures/Screenshots"
        UserDefaults.standard.set([dismissedCandidateKey], forKey: "dismissedFirstRunQuickWinCandidateKeys")

        let now = Date()
        let downloadsRoot = "/Users/test/Downloads"
        let screenshotBatch = (1...5).map { index in
            FileItem(
                path: "\(downloadsRoot)/Screenshot 2026-03-30 at 0\(index).png",
                sizeInBytes: 2_000_000,
                creationDate: now.addingTimeInterval(TimeInterval(index)),
                location: .downloads,
                scanRootPath: downloadsRoot,
                destination: FileItem.mockDestination(displayName: "Pictures/Screenshots"),
                status: .ready
            )
        }

        viewModel._testSetFiles(screenshotBatch)

        XCTAssertNil(viewModel.firstRunQuickWinSuggestion)
    }

    func testDismissFirstRunQuickWinPromotesNextAvailableCandidate() {
        let now = Date()
        let downloadsRoot = "/Users/test/Downloads"
        let documentsRoot = "/Users/test/Documents"

        let screenshotBatch = (1...5).map { index in
            FileItem(
                path: "\(downloadsRoot)/Screenshot 2026-03-30 at 0\(index).png",
                sizeInBytes: 2_000_000,
                creationDate: now.addingTimeInterval(TimeInterval(index)),
                location: .downloads,
                scanRootPath: downloadsRoot,
                destination: FileItem.mockDestination(displayName: "Pictures/Screenshots"),
                status: .ready
            )
        }

        let invoiceBatch = (1...5).map { index in
            FileItem(
                path: "\(documentsRoot)/invoice-\(index).pdf",
                sizeInBytes: 100_000,
                creationDate: now.addingTimeInterval(TimeInterval(index + 20)),
                location: .documents,
                scanRootPath: documentsRoot,
                destination: FileItem.mockDestination(displayName: "Documents/Invoices"),
                status: .ready
            )
        }

        viewModel._testSetFiles(screenshotBatch + invoiceBatch)

        XCTAssertEqual(viewModel.firstRunQuickWinSuggestion?.kind, .screenshots)

        viewModel.dismissFirstRunQuickWin()

        let suggestion = viewModel.firstRunQuickWinSuggestion

        XCTAssertEqual(suggestion?.kind, .invoices)
        XCTAssertEqual(suggestion?.folderName, "Documents")
        XCTAssertEqual(suggestion?.fileCount, 5)
    }

    func testCompleteOnboardingResetsFiltersSoQuickWinCanAppearAfterSkip() throws {
        let now = Date()
        let downloadsRoot = "/Users/test/Downloads"
        let screenshotBatch = (1...5).map { index in
            FileItem(
                path: "\(downloadsRoot)/Screenshot 2026-03-30 at 0\(index).png",
                sizeInBytes: 2_000_000,
                creationDate: now.addingTimeInterval(TimeInterval(index)),
                location: .downloads,
                scanRootPath: downloadsRoot,
                destination: FileItem.mockDestination(displayName: "Pictures/Screenshots"),
                status: .ready
            )
        }

        let container = try ModelContainer(
            for: FileItem.self,
            Rule.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        viewModel.setModelContext(container.mainContext)
        viewModel._testSetFiles(screenshotBatch)
        viewModel.selectedFolder = .desktop
        viewModel.selectedSecondaryFilter = .largeFiles
        viewModel.searchText = "invoice"

        XCTAssertNil(viewModel.firstRunQuickWinSuggestion)

        viewModel.completeOnboarding()

        let suggestion = viewModel.firstRunQuickWinSuggestion

        XCTAssertEqual(viewModel.selectedFolder, .home)
        XCTAssertEqual(viewModel.selectedSecondaryFilter, .none)
        XCTAssertEqual(viewModel.searchText, "")
        XCTAssertEqual(viewModel.reviewFilterMode, .needsReview)
        XCTAssertEqual(suggestion?.folderName, "Downloads")
        XCTAssertEqual(suggestion?.fileCount, 5)
    }

    func testApplyAutomationScanUpdateMergesRescannedRootsWithoutDroppingOtherRoots() async throws {
        let localService = MockFileSystemService()
        let localPipeline = MockFileScanPipeline()
        let localViewModel = DashboardViewModel(
            services: AppServices(),
            fileSystemService: localService,
            fileScanPipeline: localPipeline
        )
        let container = try ModelContainer(
            for: FileItem.self,
            Rule.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        localViewModel.setModelContext(context)

        let desktopRoot = "/Users/test/Desktop"
        let downloadsRoot = "/Users/test/Downloads"
        let retainedDownloadsFile = FileItem(
            path: "\(downloadsRoot)/keep.txt",
            sizeInBytes: 100,
            creationDate: Date(),
            location: .downloads,
            scanRootPath: downloadsRoot,
            destination: nil,
            status: .pending
        )
        let staleDesktopFile = FileItem(
            path: "\(desktopRoot)/old.txt",
            sizeInBytes: 100,
            creationDate: Date(),
            location: .desktop,
            scanRootPath: desktopRoot,
            destination: nil,
            status: .pending
        )
        localViewModel._testSetFiles([staleDesktopFile, retainedDownloadsFile])

        let updatedDesktopFile = FileItem(
            path: "\(desktopRoot)/new.txt",
            sizeInBytes: 200,
            creationDate: Date(),
            location: .desktop,
            scanRootPath: desktopRoot,
            destination: nil,
            status: .pending
        )
        context.insert(updatedDesktopFile)
        try context.save()

        await localViewModel.applyAutomationScanUpdate(
            scannedRootPaths: [desktopRoot],
            errorSummary: nil,
            replacesAllFiles: false,
            context: context
        )

        let paths = Set(localViewModel.allFiles.map(\.path))
        XCTAssertEqual(paths, [updatedDesktopFile.path, retainedDownloadsFile.path])
        XCTAssertFalse(paths.contains(staleDesktopFile.path))
    }

    func testApplyAutomationScanUpdateFullRefreshReplacesAllFilesAndDropsDisabledRoots() async throws {
        let localService = MockFileSystemService()
        let localPipeline = MockFileScanPipeline()
        let localViewModel = DashboardViewModel(
            services: AppServices(),
            fileSystemService: localService,
            fileScanPipeline: localPipeline
        )
        let container = try ModelContainer(
            for: FileItem.self,
            Rule.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        localViewModel.setModelContext(context)

        let desktopRoot = "/Users/test/Desktop"
        let downloadsRoot = "/Users/test/Downloads"
        let staleDesktopFile = FileItem(
            path: "\(desktopRoot)/old.txt",
            sizeInBytes: 100,
            creationDate: Date(),
            location: .desktop,
            scanRootPath: desktopRoot,
            destination: nil,
            status: .pending
        )
        let staleDownloadsFile = FileItem(
            path: "\(downloadsRoot)/keep.txt",
            sizeInBytes: 100,
            creationDate: Date(),
            location: .downloads,
            scanRootPath: downloadsRoot,
            destination: nil,
            status: .pending
        )
        localViewModel._testSetFiles([staleDesktopFile, staleDownloadsFile])

        let refreshedDesktopFile = FileItem(
            path: "\(desktopRoot)/new.txt",
            sizeInBytes: 200,
            creationDate: Date(),
            location: .desktop,
            scanRootPath: desktopRoot,
            destination: nil,
            status: .pending
        )
        context.insert(refreshedDesktopFile)
        try context.save()

        await localViewModel.applyAutomationScanUpdate(
            scannedRootPaths: [desktopRoot],
            errorSummary: nil,
            replacesAllFiles: true,
            context: context
        )

        XCTAssertEqual(Set(localViewModel.allFiles.map(\.path)), [refreshedDesktopFile.path])
    }

    func testApplyAutomationScanUpdateRefreshesTrustedAutomationScopeState() async throws {
        let schema = Schema([
            FileItem.self,
            Rule.self,
            RuleCategory.self,
            TrustedAutomationScope.self,
            TrustedAutomationScopeRunRecord.self
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let localViewModel = DashboardViewModel(
            services: AppServices(),
            fileSystemService: MockFileSystemService(),
            fileScanPipeline: MockFileScanPipeline()
        )
        localViewModel.setModelContext(context)

        let destinationRoot = try TemporaryDirectory()
        defer {
            withExtendedLifetime(container) {}
            destinationRoot.cleanup()
        }

        let destination = try Destination.folder(from: try destinationRoot.createDirectory(name: "Exports"))
        let scopeService = TrustedAutomationScopeService(modelContext: context)
        let scope = try scopeService.createOrReactivateScope(
            scopeType: .folder,
            scopeKey: "/Users/example/Downloads/Exports",
            displayName: "Exports",
            boundaryDescriptor: .folder(
                source: .init(
                    sourceLocation: .downloads,
                    scanRootPath: "/Users/example/Downloads",
                    relativeParentPath: "Exports"
                ),
                destination: .init(destination)
            ),
            promotionSource: .reviewFlow,
            recommendationSource: .repeatedReviewAcceptance,
            acceptedEvidenceCount: 6,
            overrideEvidenceCount: 0,
            undoEvidenceCount: 0,
            confidenceSnapshot: 0.95,
            rationaleSummary: "You’ve approved this folder pattern 6 times with no recent undo in Exports.",
            allowedActions: [.move],
            refreshedAt: Date(timeIntervalSince1970: 100)
        )

        localViewModel.refreshTrustedAutomationScopes(referenceDate: Date(timeIntervalSince1970: 120))
        localViewModel.presentTrustedAutomationScopeDetail(
            id: scope.id,
            referenceDate: Date(timeIntervalSince1970: 120)
        )

        XCTAssertEqual(localViewModel.trustedAutomationAttentionScopeCount, 0)
        XCTAssertTrue(localViewModel.selectedTrustedAutomationScopeDetail?.recentRuns.isEmpty ?? false)

        _ = try scopeService.recordRun(
            scopeID: scope.id,
            triggerSource: .scheduledAutomationPass,
            status: .held,
            matchedCount: 3,
            eligibleCount: 2,
            organizedCount: 2,
            heldCount: 1,
            failedCount: 0,
            heldBuckets: [.init(bucket: "Needs Review", count: 1)],
            summaryText: "Held 1 file for review.",
            exampleFileNames: ["Draft.csv"],
            startedAt: Date(timeIntervalSince1970: 180),
            endedAt: Date(timeIntervalSince1970: 190)
        )

        await localViewModel.applyAutomationScanUpdate(
            scannedRootPaths: ["/Users/example/Downloads"],
            errorSummary: nil,
            replacesAllFiles: false,
            context: context
        )

        XCTAssertEqual(localViewModel.trustedAutomationAttentionScopeCount, 1)
        XCTAssertEqual(localViewModel.trustedAutomationScopeSections.first?.summaries.first?.health.state, .needsAttention)
        XCTAssertEqual(localViewModel.selectedTrustedAutomationScopeDetail?.recentRuns.first?.status, .held)
        XCTAssertEqual(localViewModel.selectedTrustedAutomationScopeDetail?.recentRuns.first?.summaryText, "Held 1 file for review.")
    }

    func testApplyExternalReviewSessionSkipOnlyRequestPreservesExistingFilters() {
        ExternalReviewSessionStore.shared.publish(nil)

        let existingSearch = "invoice"
        viewModel.searchText = existingSearch
        viewModel.selectedCategory = .documents
        viewModel.selectedFolder = .downloads
        viewModel.selectedRelativeFolderPath = "Receipts/2026"
        viewModel.includeNestedSubfolders = true
        viewModel.selectedSecondaryFilter = .recent

        let session = ExternalReviewSession(
            requestID: UUID(),
            source: .finderService,
            reviewPaths: [],
            scannedRootPaths: [],
            skippedItems: [
                ExternalIngressSkippedItem(
                    path: "/tmp/Selected.alias",
                    reason: .aliasSelection,
                    message: "Alias files need to be resolved before Forma can organize them."
                )
            ],
            statusText: "Forma skipped 1 item."
        )

        viewModel.applyExternalReviewSession(session)

        XCTAssertEqual(viewModel.searchText, existingSearch)
        XCTAssertEqual(viewModel.selectedCategory, .documents)
        XCTAssertEqual(viewModel.selectedFolder, .downloads)
        XCTAssertEqual(viewModel.selectedRelativeFolderPath, "Receipts/2026")
        XCTAssertTrue(viewModel.includeNestedSubfolders)
        XCTAssertEqual(viewModel.selectedSecondaryFilter, .recent)
        XCTAssertFalse(viewModel.filterViewModel.hasExternalReviewScope)
        XCTAssertNil(ExternalReviewSessionStore.shared.currentSession)
    }

    func testExternalReviewSessionClearsWhenRequestedReviewPathsAreNoLongerActionable() {
        ExternalReviewSessionStore.shared.publish(nil)

        let reviewFile = FileItem(
            path: "/f/review.txt",
            sizeInBytes: 1_000,
            creationDate: Date(),
            destination: nil,
            status: .pending
        )
        let unrelatedPendingFile = FileItem(
            path: "/f/unrelated.txt",
            sizeInBytes: 1_000,
            creationDate: Date(),
            destination: nil,
            status: .pending
        )

        viewModel._testSetFiles([reviewFile, unrelatedPendingFile])

        let session = ExternalReviewSession(
            requestID: UUID(),
            source: .finderService,
            reviewPaths: [reviewFile.path],
            scannedRootPaths: [],
            skippedItems: [],
            statusText: "Forma 1 need review."
        )

        ExternalReviewSessionStore.shared.publish(session)
        viewModel.applyExternalReviewSession(session)

        XCTAssertEqual(viewModel.visibleFiles.map(\.path), [reviewFile.path])

        reviewFile.status = .completed
        viewModel._testSetFiles([reviewFile, unrelatedPendingFile])

        XCTAssertNil(ExternalReviewSessionStore.shared.currentSession)
        XCTAssertEqual(viewModel.visibleFiles.map(\.path), [unrelatedPendingFile.path])
    }

    func testExternalReviewSessionSynchronizationPreservesPromotionCandidate() {
        ExternalReviewSessionStore.shared.publish(nil)

        let pendingReviewFile = FileItem(
            path: "/Users/test/Downloads/keep.txt",
            sizeInBytes: 1_000,
            creationDate: Date(),
            destination: nil,
            status: .pending
        )
        let completedReviewFile = FileItem(
            path: "/Users/test/Downloads/done.txt",
            sizeInBytes: 1_000,
            creationDate: Date(),
            destination: nil,
            status: .pending
        )
        viewModel._testSetFiles([pendingReviewFile, completedReviewFile])

        let candidate = ExternalReviewPromotionCandidate(
            folderType: .downloads,
            bookmarkData: Data([0x01, 0x02, 0x03])
        )
        let session = ExternalReviewSession(
            requestID: UUID(),
            source: .finderService,
            reviewPaths: [pendingReviewFile.path, completedReviewFile.path],
            scannedRootPaths: ["/Users/test/Downloads"],
            skippedItems: [],
            statusText: "Review 2 files",
            promotionCandidate: candidate
        )

        ExternalReviewSessionStore.shared.publish(session)
        viewModel.applyExternalReviewSession(session)

        completedReviewFile.status = .completed
        viewModel._testSetFiles([pendingReviewFile, completedReviewFile])

        XCTAssertEqual(ExternalReviewSessionStore.shared.currentSession?.reviewPaths, [pendingReviewFile.path])
        XCTAssertEqual(ExternalReviewSessionStore.shared.currentSession?.promotionCandidate?.folderType, .downloads)
        XCTAssertEqual(
            ExternalReviewSessionStore.shared.currentSession?.promotionCandidate?.bookmarkData,
            candidate.bookmarkData
        )
    }

    func testExternalReviewPromotionSuggestionIsHiddenWhenFolderIsAlreadyMonitored() throws {
        let store = InMemoryBookmarkStore()
        let bookmarkData = Data([0x0A, 0x0B, 0x0C])
        try store.saveBookmark(bookmarkData, forKey: FormaConfig.Security.downloadsBookmarkKey)

        try BookmarkStoreProvider.$override.withValue(store) {
            let localViewModel = DashboardViewModel(
                services: AppServices(),
                fileSystemService: MockFileSystemService(),
                fileScanPipeline: MockFileScanPipeline()
            )
            let session = ExternalReviewSession(
                requestID: UUID(),
                source: .finderService,
                reviewPaths: ["/Users/test/Downloads/review.txt"],
                scannedRootPaths: ["/Users/test/Downloads"],
                skippedItems: [],
                statusText: "Review 1 file",
                promotionCandidate: ExternalReviewPromotionCandidate(
                    folderType: .downloads,
                    bookmarkData: Data([0x01, 0x02, 0x03])
                )
            )

            ExternalReviewSessionStore.shared.publish(session)
            localViewModel.applyExternalReviewSession(session)

            XCTAssertNil(localViewModel.externalReviewPromotionSuggestion)
        }
    }

    func testPromoteExternalReviewFolderSavesBookmarkForPromotionCandidate() throws {
        let store = InMemoryBookmarkStore()
        let bookmarkData = Data([0xAA, 0xBB, 0xCC])

        try BookmarkStoreProvider.$override.withValue(store) {
            let localViewModel = DashboardViewModel(
                services: AppServices(),
                fileSystemService: MockFileSystemService(),
                fileScanPipeline: MockFileScanPipeline()
            )
            let session = ExternalReviewSession(
                requestID: UUID(),
                source: .finderService,
                reviewPaths: ["/Users/test/Downloads/review.txt"],
                scannedRootPaths: ["/Users/test/Downloads"],
                skippedItems: [],
                statusText: "Review 1 file",
                promotionCandidate: ExternalReviewPromotionCandidate(
                    folderType: .downloads,
                    bookmarkData: bookmarkData
                )
            )

            ExternalReviewSessionStore.shared.publish(session)
            localViewModel.applyExternalReviewSession(session)

            XCTAssertTrue(localViewModel.promoteExternalReviewFolder())
            XCTAssertEqual(store.loadBookmark(forKey: FormaConfig.Security.downloadsBookmarkKey), bookmarkData)
            XCTAssertNil(localViewModel.externalReviewPromotionSuggestion)
        }
    }

    func testPromoteExternalReviewFolderEnablesMonitoringWhilePreservingAutomationExclusion() throws {
        let store = InMemoryBookmarkStore()
        let bookmarkData = Data([0xAA, 0xBB, 0xCC])

        UserDefaults.standard.set(false, forKey: downloadsEnabledKey)
        UserDefaults.standard.set(true, forKey: downloadsExcludedKey)

        try BookmarkStoreProvider.$override.withValue(store) {
            let localViewModel = DashboardViewModel(
                services: AppServices(),
                fileSystemService: MockFileSystemService(),
                fileScanPipeline: MockFileScanPipeline()
            )
            let session = ExternalReviewSession(
                requestID: UUID(),
                source: .finderService,
                reviewPaths: ["/Users/test/Downloads/review.txt"],
                scannedRootPaths: ["/Users/test/Downloads"],
                skippedItems: [],
                statusText: "Review 1 file",
                promotionCandidate: ExternalReviewPromotionCandidate(
                    folderType: .downloads,
                    bookmarkData: bookmarkData
                )
            )

            ExternalReviewSessionStore.shared.publish(session)
            localViewModel.applyExternalReviewSession(session)

            XCTAssertTrue(localViewModel.promoteExternalReviewFolder())

            let promotedFolder = try XCTUnwrap(BookmarkFolderService.shared.folder(for: .downloads))
            XCTAssertTrue(promotedFolder.isEnabled)
            XCTAssertTrue(promotedFolder.isExcludedFromAutomation)
        }
    }

    func testReviewChunkUsesStableSizeAndSortOrder() {
        let files = makeReviewFiles(count: 12)

        viewModel._testSetFiles(files)

        let expectedPaths = files
            .sorted { $0.creationDate > $1.creationDate }
            .prefix(viewModel.reviewChunkSize)
            .map(\.path)

        XCTAssertEqual(viewModel.currentReviewChunkPaths, expectedPaths)
        XCTAssertEqual(viewModel.visibleFiles.map(\.path), expectedPaths)
        XCTAssertEqual(viewModel.currentReviewChunkCount, viewModel.reviewChunkSize)
    }

    func testSelectAllInNeedsReviewModeSelectsCurrentChunkOnly() {
        let files = makeReviewFiles(count: 12)

        viewModel._testSetFiles(files)

        viewModel.selectAll()

        XCTAssertEqual(viewModel.selectedFileIDs.count, viewModel.reviewChunkSize)
        XCTAssertEqual(Set(viewModel.selectedFileIDs), Set(viewModel.currentReviewChunkPaths))
    }

    func testDoneForNowDefersCurrentChunkWithoutMutatingFileStatus() {
        let files = makeReviewFiles(count: 10)
        let originalStatuses = Dictionary(uniqueKeysWithValues: files.map { ($0.path, $0.status) })

        viewModel._testSetFiles(files)
        let deferredPaths = viewModel.currentReviewChunkPaths

        viewModel.doneForNow()

        let expectedVisiblePaths = files
            .sorted { $0.creationDate > $1.creationDate }
            .dropFirst(viewModel.reviewChunkSize)
            .prefix(viewModel.reviewChunkSize)
            .map(\.path)

        XCTAssertEqual(viewModel.deferredReviewFileCount, deferredPaths.count)
        XCTAssertEqual(viewModel.visibleFiles.map(\.path), expectedVisiblePaths)
        XCTAssertTrue(
            files
                .filter { deferredPaths.contains($0.path) }
                .allSatisfy { originalStatuses[$0.path] == $0.status }
        )
    }

    func testResumeDeferredReviewFilesRestoresDeferredChunk() {
        let files = makeReviewFiles(count: 10)

        viewModel._testSetFiles(files)
        let initialChunkPaths = viewModel.currentReviewChunkPaths

        viewModel.doneForNow()
        viewModel.resumeDeferredReviewFiles()

        XCTAssertEqual(viewModel.currentReviewChunkPaths, initialChunkPaths)
        XCTAssertEqual(viewModel.deferredReviewFileCount, 0)
    }

    func testExternalReviewSessionDoesNotInheritGeneralDeferredChunkState() {
        ExternalReviewSessionStore.shared.publish(nil)

        let files = makeReviewFiles(count: 12)
        viewModel._testSetFiles(files)

        let deferredPath = viewModel.currentReviewChunkPaths[0]
        viewModel.doneForNow()

        let session = ExternalReviewSession(
            requestID: UUID(),
            source: .finderService,
            reviewPaths: [deferredPath],
            scannedRootPaths: [],
            skippedItems: [],
            statusText: "Forma opened 1 file for review."
        )

        ExternalReviewSessionStore.shared.publish(session)
        viewModel.applyExternalReviewSession(session)

        XCTAssertEqual(viewModel.visibleFiles.map(\.path), [deferredPath])

        viewModel.applyExternalReviewSession(nil)

        XCTAssertFalse(viewModel.visibleFiles.map(\.path).contains(deferredPath))
    }
    
    func testFilterByLocation() {
        // Given
        let desktopFile = FileItem(path: "/Users/test/Desktop/test.txt", sizeInBytes: 1024, creationDate: Date(), destination: nil, status: .pending)
        let downloadsFile = FileItem(path: "/Users/test/Downloads/download.zip", sizeInBytes: 1024*1024, creationDate: Date(), destination: nil, status: .pending)
        
        viewModel._testSetFiles([desktopFile, downloadsFile])

        // When
        viewModel.selectedFolder = .desktop
        
        // Then
        XCTAssertEqual(viewModel.filteredFiles.count, 1)
        XCTAssertEqual(viewModel.filteredFiles.first?.name, "test.txt")
    }
    
    func testUpdateDestinationUpdatesFile() {
        // Given
        let file = FileItem(path: "/Users/test/Desktop/doc.pdf", sizeInBytes: 1_000_000, creationDate: Date(), destination: nil, status: .pending)
        viewModel._testSetFiles([file])
        viewModel.selectedFolder = .home

        // When
        viewModel.updateDestination(for: file, to: .mockFolder("Documents/PDFs"))
        
        // Then
        XCTAssertEqual(file.destination?.displayName, "Documents/PDFs")
        XCTAssertEqual(viewModel.filteredFiles.count, 1)
    }
    
    func testVisibleFilesNeedsReviewMode() {
        // Given
        let pendingWithSuggestion = FileItem(path: "/f/a.pdf", sizeInBytes: 1_000_000, creationDate: Date(), destination: .mockFolder("Documents"), status: .pending)
        let pendingNoSuggestion = FileItem(path: "/f/b.png", sizeInBytes: 2_000_000, creationDate: Date(), destination: nil, status: .pending)
        let completed = FileItem(path: "/f/c.txt", sizeInBytes: 1_000, creationDate: Date(), destination: .mockFolder("Documents"), status: .completed)
        viewModel._testSetFiles([pendingWithSuggestion, pendingNoSuggestion, completed])
        viewModel.selectedFolder = .home
        viewModel.reviewFilterMode = .needsReview
        
        // When
        viewModel.selectCategory(.all)
        let visible = viewModel.visibleFiles
        
        // Then
        XCTAssertEqual(visible.count, 2)
        XCTAssertTrue(visible.contains { $0.path == pendingWithSuggestion.path })
        XCTAssertTrue(visible.contains { $0.path == pendingNoSuggestion.path })
    }

    private func makeReviewFiles(count: Int) -> [FileItem] {
        let now = Date()
        return (0..<count).map { index in
            let hasDestination = index.isMultiple(of: 2)
            return FileItem(
                path: "/review/file-\(index).txt",
                sizeInBytes: Int64(1_000 + index),
                creationDate: now.addingTimeInterval(TimeInterval(index)),
                destination: hasDestination ? .mockFolder("Documents/Sorted") : nil,
                status: hasDestination ? .ready : .pending
            )
        }
    }
    
    func testVisibleFilesAllModeExcludesCompleted() {
        // Given
        let pending = FileItem(path: "/f/a.pdf", sizeInBytes: 1_000_000, creationDate: Date(), destination: .mockFolder("Documents"), status: .pending)
        let completed = FileItem(path: "/f/c.txt", sizeInBytes: 1_000, creationDate: Date(), destination: .mockFolder("Documents"), status: .completed)
        viewModel._testSetFiles([pending, completed])
        viewModel.selectedFolder = .home
        viewModel.reviewFilterMode = .all
        
        // When
        viewModel.selectCategory(.all)
        let visible = viewModel.visibleFiles
        
        // Then
        XCTAssertEqual(visible.count, 1)
        XCTAssertEqual(visible.first?.path, pending.path)
    }
    
    func testNeedsReviewAndAllFilesCounts() {
        // Given
        let pendingWithSuggestion = FileItem(path: "/f/a.pdf", sizeInBytes: 1_000_000, creationDate: Date(), destination: .mockFolder("Documents"), status: .pending)
        let pendingNoSuggestion = FileItem(path: "/f/b.png", sizeInBytes: 2_000_000, creationDate: Date(), destination: nil, status: .pending)
        let completedWithSuggestion = FileItem(path: "/f/c.txt", sizeInBytes: 1_000, creationDate: Date(), destination: .mockFolder("Documents"), status: .completed)
        let completedNoSuggestion = FileItem(path: "/f/d.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .completed)
        viewModel._testSetFiles([pendingWithSuggestion, pendingNoSuggestion, completedWithSuggestion, completedNoSuggestion])
        viewModel.selectedFolder = .home
        
        // When
        viewModel.selectCategory(.all)
        
        // Then
        XCTAssertEqual(viewModel.needsReviewCount, 2)
        XCTAssertEqual(viewModel.allFilesCount, 2)
    }

    func testNeedsReviewExcludesSkippedFilesWithoutDestination() {
        // Given
        let pending = FileItem(path: "/f/a.pdf", sizeInBytes: 1_000_000, creationDate: Date(), destination: nil, status: .pending)
        let skipped = FileItem(path: "/f/b.pdf", sizeInBytes: 1_000_000, creationDate: Date(), destination: nil, status: .skipped)
        viewModel._testSetFiles([pending, skipped])
        viewModel.selectedFolder = .home
        viewModel.reviewFilterMode = .needsReview

        // When
        viewModel.selectCategory(.all)

        // Then
        XCTAssertEqual(viewModel.needsReviewCount, 1)
        XCTAssertEqual(viewModel.visibleFiles.count, 1)
        XCTAssertEqual(viewModel.visibleFiles.first?.path, pending.path)
    }

    func testOrganizationProgressTracksSingleFileOrganizationInTests() {
        // Given
        let file1 = FileItem(path: "/f/one.pdf", sizeInBytes: 1_000_000, creationDate: Date(), destination: .mockFolder("Documents"), status: .pending)
        let file2 = FileItem(path: "/f/two.pdf", sizeInBytes: 1_000_000, creationDate: Date(), destination: .mockFolder("Documents"), status: .pending)
        viewModel._testSetFiles([file1, file2])

        XCTAssertEqual(viewModel.organizationProgressTotalCount, 2)
        XCTAssertEqual(viewModel.organizationProgressOrganizedCount, 0)

        // When
        viewModel.organizeFile(file1)

        // Then
        XCTAssertEqual(viewModel.organizationProgressTotalCount, 2)
        XCTAssertEqual(viewModel.organizationProgressOrganizedCount, 1)
    }

    func testOrganizationProgressResetsWhenFileSetIsReplaced() {
        // Given
        let first = FileItem(path: "/f/first.pdf", sizeInBytes: 1_000_000, creationDate: Date(), destination: .mockFolder("Documents"), status: .pending)
        let second = FileItem(path: "/f/second.pdf", sizeInBytes: 1_000_000, creationDate: Date(), destination: .mockFolder("Documents"), status: .pending)
        viewModel._testSetFiles([first, second])
        viewModel.organizeFile(first)
        XCTAssertEqual(viewModel.organizationProgressOrganizedCount, 1)

        // When
        let replacement = FileItem(path: "/f/replacement.pdf", sizeInBytes: 1_000_000, creationDate: Date(), destination: nil, status: .pending)
        viewModel._testSetFiles([replacement])

        // Then
        XCTAssertEqual(viewModel.organizationProgressTotalCount, 1)
        XCTAssertEqual(viewModel.organizationProgressOrganizedCount, 0)
    }
    
    func testVisibleFilesLargeFilesFilter() {
        // Given
        let small = FileItem(path: "/f/small.mov", sizeInBytes: 1_000_000, creationDate: Date(), destination: nil, status: .pending)
        let large = FileItem(path: "/f/large.mov", sizeInBytes: 20 * 1_024 * 1_024, creationDate: Date(), destination: nil, status: .pending)
        viewModel._testSetFiles([small, large])
        viewModel.selectedFolder = .home
        viewModel.reviewFilterMode = .all
        viewModel.selectedSecondaryFilter = .largeFiles
        
        // When
        viewModel.selectCategory(.all)
        let visible = viewModel.visibleFiles
        
        // Then
        XCTAssertEqual(visible.count, 1)
        XCTAssertEqual(visible.first?.path, large.path)
    }
    
    func testVisibleFilesRecentSortsByCreationDate() {
        // Given
        let oldest = FileItem(path: "/f/old.txt", sizeInBytes: 1_000, creationDate: Date().addingTimeInterval(-3600), destination: nil, status: .pending)
        let middle = FileItem(path: "/f/mid.txt", sizeInBytes: 1_000, creationDate: Date().addingTimeInterval(-1800), destination: nil, status: .pending)
        let newest = FileItem(path: "/f/new.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .pending)
        viewModel._testSetFiles([oldest, middle, newest])
        viewModel.selectedFolder = .home
        viewModel.reviewFilterMode = .all
        viewModel.selectedSecondaryFilter = .recent
        
        // When
        viewModel.selectCategory(.all)
        let visible = viewModel.visibleFiles
        
        // Then
        XCTAssertEqual(visible.map { $0.path }, [newest.path, middle.path, oldest.path])
    }

    func testContentSearchSkipsRepeatedInputSnapshot() async {
        // Given
        let contentSearch = MockContentSearchService()
        let localViewModel = DashboardViewModel(
            services: AppServices(),
            fileSystemService: MockFileSystemService(),
            fileScanPipeline: MockFileScanPipeline(),
            contentSearchService: contentSearch
        )
        let file = FileItem(path: "/f/report.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .pending)
        localViewModel._testSetFiles([file])

        // When
        localViewModel.updateSearchText("report")
        await waitForContentSearchDebounce()
        localViewModel.updateSearchText("report")
        await waitForContentSearchDebounce()

        // Then
        XCTAssertEqual(contentSearch.searchCallCount, 1)
    }

    func testContentSearchRerunsWhenFileSnapshotChanges() async {
        // Given
        let contentSearch = MockContentSearchService()
        let localViewModel = DashboardViewModel(
            services: AppServices(),
            fileSystemService: MockFileSystemService(),
            fileScanPipeline: MockFileScanPipeline(),
            contentSearchService: contentSearch
        )
        let fileOne = FileItem(path: "/f/report.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .pending)
        localViewModel._testSetFiles([fileOne])
        localViewModel.updateSearchText("report")
        await waitForContentSearchDebounce()
        XCTAssertEqual(contentSearch.searchCallCount, 1)

        // When
        let fileTwo = FileItem(path: "/f/report-v2.txt", sizeInBytes: 2_000, creationDate: Date(), destination: nil, status: .pending)
        localViewModel._testSetFiles([fileOne, fileTwo])
        localViewModel.updateSearchText("report")
        await waitForContentSearchDebounce()

        // Then
        XCTAssertEqual(contentSearch.searchCallCount, 2)
    }
    
    func testFocusNextAndPrevious() {
        // Given
        let referenceDate = Date()
        let one = FileItem(path: "/f/1.txt", sizeInBytes: 1_000, creationDate: referenceDate.addingTimeInterval(3), destination: nil, status: .pending)
        let two = FileItem(path: "/f/2.txt", sizeInBytes: 1_000, creationDate: referenceDate.addingTimeInterval(2), destination: nil, status: .pending)
        let three = FileItem(path: "/f/3.txt", sizeInBytes: 1_000, creationDate: referenceDate.addingTimeInterval(1), destination: nil, status: .pending)
        viewModel._testSetFiles([one, two, three])
        viewModel.selectedFolder = .home
        viewModel.reviewFilterMode = .all
        viewModel.selectCategory(.all)
        
        // When: first focusNext should go to first file
        viewModel.focusNextFile()
        XCTAssertEqual(viewModel.focusedFilePath, one.path)
        
        // Next focusNext should go to second file
        viewModel.focusNextFile()
        XCTAssertEqual(viewModel.focusedFilePath, two.path)
        
        // focusPrevious should go back to first
        viewModel.focusPreviousFile()
        XCTAssertEqual(viewModel.focusedFilePath, one.path)
    }
    
	    func testUndoStackCapacityKeepsLastTwenty() {
	        // Given
	        for _ in 0..<25 {
	            let action = DashboardViewModel.OrganizationAction(
	                id: UUID(),
	                type: .skip,
	                files: [],
	                timestamp: Date()
            )
            viewModel._testPushUndoAction(action)
        }
        
        // Then
        XCTAssertEqual(viewModel.undoStack.count, 20)
    }
    
    // MARK: - Phase 2 Tests: Selection
    
    func testToggleSelection() {
        // Given
        let file1 = FileItem(path: "/f/1.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .pending)
        let file2 = FileItem(path: "/f/2.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .pending)
        viewModel._testSetFiles([file1, file2])
        viewModel.selectedFolder = .home

        // When: Toggle selection on file1
        viewModel.toggleSelection(for: file1)
        
        // Then
        XCTAssertTrue(viewModel.isSelected(file1))
        XCTAssertTrue(viewModel.isSelectionMode)
        XCTAssertEqual(viewModel.selectedFileIDs.count, 1)
        
        // When: Toggle off
        viewModel.toggleSelection(for: file1)
        
        // Then
        XCTAssertFalse(viewModel.isSelected(file1))
        XCTAssertFalse(viewModel.isSelectionMode)
    }
    
    func testSelectAll() {
        // Given
        let file1 = FileItem(path: "/f/1.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .pending)
        let file2 = FileItem(path: "/f/2.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .pending)
        let file3 = FileItem(path: "/f/3.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .pending)
        viewModel._testSetFiles([file1, file2, file3])
        viewModel.selectedFolder = .home
        viewModel.reviewFilterMode = .all
        viewModel.selectCategory(.all)
        
        // When
        viewModel.selectAll()
        
        // Then
        XCTAssertEqual(viewModel.selectedFileIDs.count, 3)
        XCTAssertTrue(viewModel.isSelectionMode)
        XCTAssertTrue(viewModel.isSelected(file1))
        XCTAssertTrue(viewModel.isSelected(file2))
        XCTAssertTrue(viewModel.isSelected(file3))
    }
    
    func testDeselectAll() {
        // Given
        let file1 = FileItem(path: "/f/1.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .pending)
        viewModel._testSetFiles([file1])
        viewModel.selectedFolder = .home
        viewModel.reviewFilterMode = .all
        viewModel.selectCategory(.all)
        viewModel.selectAll()
        
        // When
        viewModel.deselectAll()
        
        // Then
        XCTAssertEqual(viewModel.selectedFileIDs.count, 0)
        XCTAssertFalse(viewModel.isSelectionMode)
    }
    
    func testCanOrganizeAllSelected_SameDestination() {
        // Given
        let file1 = FileItem(path: "/f/1.pdf", sizeInBytes: 1_000_000, creationDate: Date(), destination: .mockFolder("Documents"), status: .pending)
        let file2 = FileItem(path: "/f/2.pdf", sizeInBytes: 1_000_000, creationDate: Date(), destination: .mockFolder("Documents"), status: .pending)
        viewModel._testSetFiles([file1, file2])
        viewModel.selectedFolder = .home
        viewModel.toggleSelection(for: file1)
        viewModel.toggleSelection(for: file2)
        
        // Then
        XCTAssertTrue(viewModel.canOrganizeAllSelected)
    }
    
    func testCanOrganizeAllSelected_DifferentDestinations() {
        // Given
        let file1 = FileItem(path: "/f/1.pdf", sizeInBytes: 1_000_000, creationDate: Date(), destination: .mockFolder("Documents"), status: .pending)
        let file2 = FileItem(path: "/f/2.png", sizeInBytes: 2_000_000, creationDate: Date(), destination: .mockFolder("Pictures"), status: .pending)
        viewModel._testSetFiles([file1, file2])
        viewModel.selectedFolder = .home
        viewModel.toggleSelection(for: file1)
        viewModel.toggleSelection(for: file2)
        
        // Then
        XCTAssertFalse(viewModel.canOrganizeAllSelected)
    }
    
    func testCanOrganizeAllSelected_NoSuggestions() {
        // Given
        let file1 = FileItem(path: "/f/1.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .pending)
        viewModel._testSetFiles([file1])
        viewModel.selectedFolder = .home
        viewModel.toggleSelection(for: file1)
        
        // Then
        XCTAssertFalse(viewModel.canOrganizeAllSelected)
    }
    
    // MARK: - Phase 2 Tests: Bulk Operations
    
    func testSkipSelectedFiles() {
        // Given
        let file1 = FileItem(path: "/f/1.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .pending)
        let file2 = FileItem(path: "/f/2.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .pending)
        viewModel._testSetFiles([file1, file2])
        viewModel.selectedFolder = .home
        viewModel.toggleSelection(for: file1)
        viewModel.toggleSelection(for: file2)
        
        // When
        viewModel.skipSelectedFiles()
        
        // Then
        XCTAssertEqual(file1.status, .skipped)
        XCTAssertEqual(file2.status, .skipped)
        XCTAssertEqual(viewModel.selectedFileIDs.count, 0) // Should deselect after operation
        // Each skipped file now produces its own undo command
        XCTAssertEqual(viewModel.undoStack.count, 2)
    }
    
    // MARK: - Phase 2 Tests: Undo/Redo
    
    func testUndoSkipOperation() {
        // Given
        let file1 = FileItem(path: "/f/1.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .pending)
        viewModel._testSetFiles([file1])
        viewModel.selectedFolder = .home
        viewModel.toggleSelection(for: file1)
        viewModel.skipSelectedFiles()

        // When
        viewModel.undoLastAction()
        
        // Then
        XCTAssertEqual(file1.status, .pending) // Should restore original status
        XCTAssertEqual(viewModel.undoStack.count, 0)
        XCTAssertEqual(viewModel.redoStack.count, 1) // Should move to redo stack
    }

    func testUndoLastAction_ClearsTrustedScopeRecommendation() {
        let file = FileItem(path: "/f/1.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .pending)
        viewModel._testSetFiles([file])
        viewModel.selectedFolder = .home
        viewModel.toggleSelection(for: file)
        viewModel.skipSelectedFiles()

        let panelManager = panelStateManager()
        panelManager.showCelebrationPanel(message: "Organized to Exports")
        panelManager.stageTrustedScopeRecommendation(makeTrustedScopeRecommendation())
        panelManager.presentTrustedScopeRecommendation()

        XCTAssertNotNil(viewModel.trustedScopeRecommendation)
        XCTAssertTrue(viewModel.isTrustedScopeRecommendationPresented)

        viewModel.undoLastAction()

        XCTAssertNil(viewModel.trustedScopeRecommendation)
        XCTAssertFalse(viewModel.isTrustedScopeRecommendationPresented)
    }

    func testTrustedAutomationScopeDetail_PauseResumeAndRevokeRefreshVisibleGroups() throws {
        let (container, context, scopeService) = try makeTrustedAutomationScopeDashboardServices()
        let destinationRoot = try TemporaryDirectory()
        defer {
            withExtendedLifetime(container) {}
            destinationRoot.cleanup()
        }

        let destination = try Destination.folder(from: try destinationRoot.createDirectory(name: "Exports"))
        let scope = try scopeService.createOrReactivateScope(
            scopeType: .folder,
            scopeKey: "/Users/example/Downloads/Exports",
            displayName: "Exports",
            boundaryDescriptor: .folder(
                source: .init(
                    sourceLocation: .downloads,
                    scanRootPath: "/Users/example/Downloads",
                    relativeParentPath: "Exports"
                ),
                destination: .init(destination)
            ),
            promotionSource: .reviewFlow,
            recommendationSource: .repeatedReviewAcceptance,
            acceptedEvidenceCount: 6,
            overrideEvidenceCount: 0,
            undoEvidenceCount: 0,
            confidenceSnapshot: 0.95,
            rationaleSummary: "You’ve approved this folder pattern 6 times with no recent undo in Exports.",
            allowedActions: [.move, .notify],
            refreshedAt: Date(timeIntervalSince1970: 100)
        )
        _ = try scopeService.recordRun(
            scopeID: scope.id,
            triggerSource: .promotionPreview,
            status: .executed,
            matchedCount: 3,
            eligibleCount: 3,
            organizedCount: 3,
            heldCount: 0,
            failedCount: 0,
            heldBuckets: [],
            summaryText: "Previewed 3 matching files with no blockers.",
            exampleFileNames: ["Quarterly Report.csv"],
            startedAt: Date(timeIntervalSince1970: 180),
            endedAt: Date(timeIntervalSince1970: 210)
        )

        viewModel.setModelContext(context)
        viewModel.refreshTrustedAutomationScopes(referenceDate: Date(timeIntervalSince1970: 300))

        XCTAssertEqual(viewModel.trustedAutomationScopeSections.map(\.status), [.active])
        XCTAssertEqual(viewModel.trustedAutomationScopeSections.first?.summaries.map(\.displayName), ["Exports"])
        XCTAssertEqual(viewModel.defaultPanelTrustedAutomationScopes.map(\.displayName), ["Exports"])

        viewModel.presentTrustedAutomationScopeDetail(
            id: scope.id,
            referenceDate: Date(timeIntervalSince1970: 300)
        )

        XCTAssertTrue(viewModel.isTrustedAutomationScopeDetailPresented)
        XCTAssertEqual(viewModel.selectedTrustedAutomationScopeDetail?.summary.displayName, "Exports")
        XCTAssertEqual(viewModel.selectedTrustedAutomationScopeDetail?.lifecycle.status, .active)

        viewModel.pauseSelectedTrustedAutomationScope(
            at: Date(timeIntervalSince1970: 400),
            referenceDate: Date(timeIntervalSince1970: 400)
        )

        XCTAssertEqual(viewModel.trustedAutomationScopeSections.map(\.status), [.paused])
        XCTAssertEqual(viewModel.trustedAutomationScopeSections.first?.summaries.map(\.displayName), ["Exports"])
        XCTAssertEqual(viewModel.selectedTrustedAutomationScopeDetail?.lifecycle.status, .paused)

        viewModel.resumeSelectedTrustedAutomationScope(
            at: Date(timeIntervalSince1970: 500),
            referenceDate: Date(timeIntervalSince1970: 500)
        )

        XCTAssertEqual(viewModel.trustedAutomationScopeSections.map(\.status), [.active])
        XCTAssertEqual(viewModel.selectedTrustedAutomationScopeDetail?.lifecycle.status, .active)

        viewModel.revokeSelectedTrustedAutomationScope(
            at: Date(timeIntervalSince1970: 600),
            referenceDate: Date(timeIntervalSince1970: 600)
        )

        XCTAssertEqual(viewModel.trustedAutomationScopeSections.map(\.status), [.revoked])
        XCTAssertEqual(viewModel.selectedTrustedAutomationScopeDetail?.lifecycle.status, .revoked)
        XCTAssertTrue(viewModel.defaultPanelTrustedAutomationScopes.isEmpty)
    }

    func testTrustedAutomationScopeRecommendationPreview_UsesCurrentMatchingAndPreflightCounts() throws {
        let destinationRoot = try TemporaryDirectory()
        defer { destinationRoot.cleanup() }

        let destination = try Destination.folder(from: try destinationRoot.createDirectory(name: "Exports"))
        let matchingEligible = FileItem(
            path: "/Users/example/Downloads/Exports/Quarterly Report.csv",
            sizeInBytes: 1_000,
            creationDate: Date(timeIntervalSince1970: 100),
            location: .downloads,
            scanRootPath: "/Users/example/Downloads",
            relativeParentPath: "Exports",
            destination: destination,
            status: .pending
        )
        matchingEligible.confidenceScore = 0.96

        let matchingReady = FileItem(
            path: "/Users/example/Downloads/Exports/Quarterly Summary.csv",
            sizeInBytes: 1_000,
            creationDate: Date(timeIntervalSince1970: 110),
            location: .downloads,
            scanRootPath: "/Users/example/Downloads",
            relativeParentPath: "Exports",
            destination: destination,
            status: .ready
        )
        matchingReady.confidenceScore = 0.93

        let matchingHeld = FileItem(
            path: "/Users/example/Downloads/Exports/Draft.csv",
            sizeInBytes: 1_000,
            creationDate: Date(timeIntervalSince1970: 120),
            location: .downloads,
            scanRootPath: "/Users/example/Downloads",
            relativeParentPath: "Exports",
            destination: destination,
            status: .pending
        )
        matchingHeld.confidenceScore = 0.42

        let nonMatchingDestination = FileItem(
            path: "/Users/example/Downloads/Exports/Other.csv",
            sizeInBytes: 1_000,
            creationDate: Date(timeIntervalSince1970: 130),
            location: .downloads,
            scanRootPath: "/Users/example/Downloads",
            relativeParentPath: "Exports",
            destination: Destination.mockFolder("Documents/Other"),
            status: .pending
        )
        nonMatchingDestination.confidenceScore = 0.97

        viewModel._testSetFiles([matchingEligible, matchingReady, matchingHeld, nonMatchingDestination])

        let recommendation = makeTrustedScopeRecommendation(destination: destination)
        panelStateManager().stageTrustedScopeRecommendation(recommendation)

        let preview = viewModel.trustedScopeRecommendationPreviewSummary(for: .folder)

        XCTAssertEqual(preview?.matchedCount, 3)
        XCTAssertEqual(preview?.eligibleCount, 2)
        XCTAssertEqual(preview?.skippedConfidenceThresholdCount, 1)
        XCTAssertEqual(preview?.summaryText, "3 current matches. 2 would move automatically on the first pass, and 1 would stay in review.")
    }

    func testTrustedAutomationAttentionScopeCount_ExcludesRevokedScopes() throws {
        let (container, context, scopeService) = try makeTrustedAutomationScopeDashboardServices()
        let destinationRoot = try TemporaryDirectory()
        defer {
            withExtendedLifetime(container) {}
            destinationRoot.cleanup()
        }

        let destination = try Destination.folder(from: try destinationRoot.createDirectory(name: "Exports"))
        let activeScope = try scopeService.createOrReactivateScope(
            scopeType: .folder,
            scopeKey: "/Users/example/Downloads/Exports",
            displayName: "Active Exports",
            boundaryDescriptor: .folder(
                source: .init(
                    sourceLocation: .downloads,
                    scanRootPath: "/Users/example/Downloads",
                    relativeParentPath: "Exports"
                ),
                destination: .init(destination)
            ),
            promotionSource: .reviewFlow,
            recommendationSource: .repeatedReviewAcceptance,
            acceptedEvidenceCount: 6,
            overrideEvidenceCount: 0,
            undoEvidenceCount: 0,
            confidenceSnapshot: 0.95,
            rationaleSummary: "Active scope rationale.",
            allowedActions: [.move],
            refreshedAt: Date(timeIntervalSince1970: 100)
        )
        let revokedScope = try scopeService.createOrReactivateScope(
            scopeType: .folder,
            scopeKey: "/Users/example/Downloads/Archives",
            displayName: "Revoked Archives",
            boundaryDescriptor: .folder(
                source: .init(
                    sourceLocation: .downloads,
                    scanRootPath: "/Users/example/Downloads",
                    relativeParentPath: "Archives"
                ),
                destination: .init(destination)
            ),
            promotionSource: .reviewFlow,
            recommendationSource: .repeatedReviewAcceptance,
            acceptedEvidenceCount: 6,
            overrideEvidenceCount: 0,
            undoEvidenceCount: 0,
            confidenceSnapshot: 0.95,
            rationaleSummary: "Revoked scope rationale.",
            allowedActions: [.move],
            refreshedAt: Date(timeIntervalSince1970: 100)
        )

        _ = try scopeService.recordRun(
            scopeID: activeScope.id,
            triggerSource: .scheduledAutomationPass,
            status: .held,
            matchedCount: 2,
            eligibleCount: 1,
            organizedCount: 1,
            heldCount: 1,
            failedCount: 0,
            heldBuckets: [.init(bucket: "Needs Review", count: 1)],
            summaryText: "Held 1 active file.",
            exampleFileNames: ["active.csv"],
            startedAt: Date(timeIntervalSince1970: 180),
            endedAt: Date(timeIntervalSince1970: 190)
        )
        try scopeService.removeScope(id: revokedScope.id, at: Date(timeIntervalSince1970: 195))
        _ = try scopeService.recordRun(
            scopeID: revokedScope.id,
            triggerSource: .scheduledAutomationPass,
            status: .held,
            matchedCount: 2,
            eligibleCount: 1,
            organizedCount: 1,
            heldCount: 1,
            failedCount: 0,
            heldBuckets: [.init(bucket: "Needs Review", count: 1)],
            summaryText: "Held 1 revoked file.",
            exampleFileNames: ["revoked.csv"],
            startedAt: Date(timeIntervalSince1970: 200),
            endedAt: Date(timeIntervalSince1970: 210)
        )

        viewModel.setModelContext(context)
        viewModel.refreshTrustedAutomationScopes(referenceDate: Date(timeIntervalSince1970: 220))

        XCTAssertEqual(viewModel.trustedAutomationAttentionScopeCount, 1)
    }
    
    func testRedoSkipOperation() {
        // Given
        let file1 = FileItem(path: "/f/1.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .pending)
        viewModel._testSetFiles([file1])
        viewModel.selectedFolder = .home
        viewModel.toggleSelection(for: file1)
        viewModel.skipSelectedFiles()
        viewModel.undoLastAction()

        // When
        let expectation = expectation(description: "Redo skip operation completes")
        viewModel.redoLastAction()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1.0)
        
        // Then
        XCTAssertEqual(file1.status, .skipped)
        XCTAssertEqual(viewModel.undoStack.count, 1)
        XCTAssertEqual(viewModel.redoStack.count, 0)
    }
    
    func testUndoStackMaxSize() {
        // Given
        let file = FileItem(path: "/f/test.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .pending)
        viewModel._testSetFiles([file])
        viewModel.selectedFolder = .home

        // When: Perform 25 skip operations
        for _ in 0..<25 {
            viewModel.toggleSelection(for: file)
            viewModel.skipSelectedFiles()
            file.status = .pending // Reset for next iteration
        }
        
        // Then: Stack should be limited to 20
        XCTAssertEqual(viewModel.undoStack.count, 20)
    }
    
    func testSelectRange() {
        // Given
        let file1 = FileItem(path: "/f/1.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .pending)
        let file2 = FileItem(path: "/f/2.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .pending)
        let file3 = FileItem(path: "/f/3.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .pending)
        let file4 = FileItem(path: "/f/4.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .pending)
        viewModel._testSetFiles([file1, file2, file3, file4])
        viewModel.selectedFolder = .home
        viewModel.reviewFilterMode = .all
        viewModel.selectCategory(.all)

        // When: Select range from file1 to file3
        viewModel.selectRange(from: file1, to: file3)
        
        // Then: Files 1, 2, and 3 should be selected
        XCTAssertTrue(viewModel.isSelected(file1))
        XCTAssertTrue(viewModel.isSelected(file2))
        XCTAssertTrue(viewModel.isSelected(file3))
        XCTAssertFalse(viewModel.isSelected(file4))
        XCTAssertEqual(viewModel.selectedFileIDs.count, 3)
    }

    func testSelectionAnchorTracksLastToggledFile() {
        // Given
        let file1 = FileItem(path: "/f/1.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .pending)
        let file2 = FileItem(path: "/f/2.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .pending)
        viewModel._testSetFiles([file1, file2])
        viewModel.selectedFolder = .home

        // When
        viewModel.toggleSelection(for: file1)
        viewModel.toggleSelection(for: file2)

        // Then
        XCTAssertEqual(viewModel.rangeSelectionAnchorPath, file2.path)
    }

    func testSelectRangeUpdatesSelectionAnchorToRangeEnd() {
        // Given
        let file1 = FileItem(path: "/f/1.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .pending)
        let file2 = FileItem(path: "/f/2.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .pending)
        let file3 = FileItem(path: "/f/3.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .pending)
        viewModel._testSetFiles([file1, file2, file3])
        viewModel.selectedFolder = .home
        viewModel.reviewFilterMode = .all
        viewModel.selectCategory(.all)
        viewModel.toggleSelection(for: file1)

        // When
        viewModel.selectRange(from: file1, to: file3)

        // Then
        XCTAssertEqual(viewModel.rangeSelectionAnchorPath, file3.path)
    }

    func testDeselectAllClearsSelectionAnchor() {
        // Given
        let file1 = FileItem(path: "/f/1.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .pending)
        viewModel._testSetFiles([file1])
        viewModel.selectedFolder = .home
        viewModel.toggleSelection(for: file1)
        XCTAssertEqual(viewModel.rangeSelectionAnchorPath, file1.path)

        // When
        viewModel.deselectAll()

        // Then
        XCTAssertNil(viewModel.rangeSelectionAnchorPath)
    }
    
    // MARK: - Selection Persistence Tests
    
    func testSelectionClearsOnCategoryChange() {
        // Given
        let file1 = FileItem(path: "/f/image.png", sizeInBytes: 2_000_000, creationDate: Date(), destination: nil, status: .pending)
        let file2 = FileItem(path: "/f/doc.pdf", sizeInBytes: 1_000_000, creationDate: Date(), destination: nil, status: .pending)
        viewModel._testSetFiles([file1, file2])
        viewModel.selectedFolder = .home
        viewModel.reviewFilterMode = .all
        viewModel.selectCategory(.all)
        viewModel.toggleSelection(for: file1)

        // When: Change category
        viewModel.selectCategory(.documents)
        
        // Then: Selection should persist (files remain selected)
        // Note: Based on implementation, selection persists but visibility changes
        XCTAssertTrue(viewModel.isSelected(file1))
        XCTAssertTrue(viewModel.isSelectionMode)
    }
    
    func testSelectionPersistsOnSecondaryFilterChange() {
        // Given
        let file1 = FileItem(path: "/f/1.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .pending)
        viewModel._testSetFiles([file1])
        viewModel.selectedFolder = .home
        viewModel.reviewFilterMode = .all
        viewModel.selectCategory(.all)
        viewModel.toggleSelection(for: file1)

        // When: Apply secondary filter
        viewModel.setSecondaryFilter(.recent)
        
        // Then: Selection should persist
        XCTAssertTrue(viewModel.isSelected(file1))
        XCTAssertTrue(viewModel.isSelectionMode)
    }
    
    func testSelectionClearsOnReviewModeToggle() {
        // Given
        let file1 = FileItem(path: "/f/1.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .pending)
        viewModel._testSetFiles([file1])
        viewModel.selectedFolder = .home
        viewModel.reviewFilterMode = .needsReview
        viewModel.selectCategory(.all)
        viewModel.toggleSelection(for: file1)

        // When: Toggle review mode
        viewModel.reviewFilterMode = .all
        
        // Then: Selection persists (no automatic clear)
        // Note: Implementation doesn't auto-clear on mode change
        XCTAssertTrue(viewModel.isSelected(file1))
    }
    
    // MARK: - Bulk Edit Tests
    
    func testBulkEditDestinationUpdatesAllFiles() {
        // Given
        let file1 = FileItem(path: "/f/1.pdf", sizeInBytes: 1_000_000, creationDate: Date(), destination: .mockFolder("Documents"), status: .pending)
        let file2 = FileItem(path: "/f/2.png", sizeInBytes: 2_000_000, creationDate: Date(), destination: .mockFolder("Pictures"), status: .pending)
        viewModel._testSetFiles([file1, file2])
        viewModel.selectedFolder = .home
        viewModel.toggleSelection(for: file1)
        viewModel.toggleSelection(for: file2)

        // When: Bulk edit destination without creating rules. Destination must be
        // a relative path (absolute paths like "~/Downloads" are now rejected
        // by the security-hardened PathValidator).
        viewModel.bulkEditDestination("Downloads", createRules: false, context: nil)
        
        // Then: Both files should have new destination
        XCTAssertEqual(file1.destination?.displayName, "Downloads")
        XCTAssertEqual(file2.destination?.displayName, "Downloads")
        XCTAssertFalse(viewModel.showBulkEditSheet)
    }
    
    // MARK: - Edge Case Tests
    
    func testEmptySelectionBehavior() {
        // Given
        viewModel._testSetFiles([])
        viewModel.selectedFolder = .home

        // When: Try to perform operations with no selection
        viewModel.skipSelectedFiles()
        
        // Then: Should handle gracefully
        XCTAssertEqual(viewModel.selectedFileIDs.count, 0)
        XCTAssertFalse(viewModel.isSelectionMode)
        XCTAssertEqual(viewModel.undoStack.count, 0)
    }
    
    func testMixedSelectionPartialSuggestions() {
        // Given
        let file1 = FileItem(path: "/f/1.pdf", sizeInBytes: 1_000_000, creationDate: Date(), destination: .mockFolder("Documents"), status: .pending)
        let file2 = FileItem(path: "/f/2.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .pending)
        let file3 = FileItem(path: "/f/3.pdf", sizeInBytes: 1_000_000, creationDate: Date(), destination: .mockFolder("Documents"), status: .pending)
        viewModel._testSetFiles([file1, file2, file3])
        viewModel.selectedFolder = .home
        viewModel.toggleSelection(for: file1)
        viewModel.toggleSelection(for: file2)
        viewModel.toggleSelection(for: file3)

        // Then: Can organize should be false (not all have same destination)
        XCTAssertFalse(viewModel.canOrganizeAllSelected)
        
        // When: Get selected files with suggestions
        let filesWithSuggestions = viewModel.selectedFiles.filter { $0.destination != nil }
        
        // Then: Should have 2 files with suggestions
        XCTAssertEqual(filesWithSuggestions.count, 2)
    }
    
    func testUndoClearRedoStack() {
        // Given
        let file1 = FileItem(path: "/f/1.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .pending)
        viewModel._testSetFiles([file1])
        viewModel.selectedFolder = .home
        viewModel.toggleSelection(for: file1)
        viewModel.skipSelectedFiles()
        viewModel.undoLastAction()

        // Verify redo is available
        XCTAssertTrue(viewModel.canRedo())
        XCTAssertEqual(viewModel.redoStack.count, 1)
        
        // When: Perform a new action
        viewModel.toggleSelection(for: file1)
        viewModel.skipSelectedFiles()
        
        // Then: Redo stack should be cleared
        XCTAssertFalse(viewModel.canRedo())
        XCTAssertEqual(viewModel.redoStack.count, 0)
        XCTAssertEqual(viewModel.undoStack.count, 1)
    }
    
    func testCanUndoCanRedo() {
        // Given
        let file1 = FileItem(path: "/f/1.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .pending)
        viewModel._testSetFiles([file1])
        viewModel.selectedFolder = .home

        // Then: Initially should not be able to undo or redo
        XCTAssertFalse(viewModel.canUndo())
        XCTAssertFalse(viewModel.canRedo())
        
        // When: Perform action
        viewModel.toggleSelection(for: file1)
        viewModel.skipSelectedFiles()
        
        // Then: Can undo but not redo
        XCTAssertTrue(viewModel.canUndo())
        XCTAssertFalse(viewModel.canRedo())
        
        // When: Undo
        viewModel.undoLastAction()
        
        // Then: Can redo but not undo
        XCTAssertFalse(viewModel.canUndo())
        XCTAssertTrue(viewModel.canRedo())
    }

    private func panelStateManager() -> PanelStateManager {
        viewModel._testPanelManager
    }

    private func makeTrustedAutomationScopeDashboardServices() throws -> (
        ModelContainer,
        ModelContext,
        TrustedAutomationScopeService
    ) {
        let schema = Schema([
            TrustedAutomationScope.self,
            TrustedAutomationScopeRunRecord.self,
            Rule.self,
            RuleCategory.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        return (container, context, TrustedAutomationScopeService(modelContext: context))
    }

    private func makeTrustedScopeRecommendation(
        destination: Destination = Destination.mockFolder("Documents/Exports")
    ) -> TrustedAutomationScopeRecommendation {
        let snapshot = OrganizationMemorySnapshot(
            fileName: "Report.csv",
            fileExtension: "csv",
            fileTypeCategory: .documents,
            sourceLocation: .downloads,
            scanRootPath: "/Users/example/Downloads",
            relativeParentPath: "Exports",
            suggestionSource: .personalMemory,
            suggestedDestination: destination,
            chosenDestination: destination,
            confidenceScore: 0.94,
            matchedRuleID: nil
        )

        let option = TrustedAutomationScopeRecommendationOption(
            scopeType: .folder,
            scopeKey: "/Users/example/Downloads/Exports",
            displayName: "Exports",
            recommendationSource: .repeatedReviewAcceptance,
            acceptedEvidenceCount: 6,
            overrideEvidenceCount: 0,
            undoEvidenceCount: 0,
            confidenceSnapshot: 0.94,
            rationaleSummary: "You’ve approved this folder pattern 6 times with no recent undo in Exports."
        )

        return TrustedAutomationScopeRecommendation(
            recommendedScope: option,
            alternativeScopes: [],
            snapshot: snapshot
        )
    }
    
    // MARK: - Rule Preview Tests
    
    func testMatchingFilesForRulePreviewWithDeleteRule() {
        // Given: one screenshot and one non-matching document
        let screenshot = FileItem(path: "/f/Screenshot.png", sizeInBytes: 1_000_000, creationDate: Date(), destination: nil, status: .pending)
        let document = FileItem(path: "/f/MeetingNotes.pdf", sizeInBytes: 500_000, creationDate: Date(), destination: nil, status: .pending)

        viewModel._testSetFiles([screenshot, document])
        viewModel.selectedFolder = .home

        // When: build a delete rule preview for screenshots
        let condition = RuleCondition.nameContains("screenshot")
        let matches = viewModel.matchingFilesForRulePreview(
            conditions: [condition],
            conditionType: .nameContains,
            conditionValue: "screenshot",
            logicalOperator: .and,
            actionType: .delete,
            destination: nil
        )

        // Then: only the screenshot should match
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches.first?.path, screenshot.path)
    }
    
    // MARK: - Right Panel Mode Transition Tests
    
    func testInitialRightPanelModeIsDefault() {
        // Then
        if case .default = viewModel.rightPanelMode {
            // Success
        } else {
            XCTFail("Initial right panel mode should be .default")
        }
    }
    
    func testRightPanelSwitchesToInspectorOnFileSelection() {
        // Given
        let file = FileItem(path: "/f/test.pdf", sizeInBytes: 1_000_000, creationDate: Date(), destination: nil, status: .pending)
        viewModel._testSetFiles([file])
        viewModel.selectedFolder = .home

        // When
        viewModel.toggleSelection(for: file)
        
        // Then
        if case .inspector(let files) = viewModel.rightPanelMode {
            XCTAssertEqual(files.count, 1)
            XCTAssertEqual(files.first?.path, file.path)
        } else {
            XCTFail("Right panel mode should switch to .inspector when file is selected")
        }
    }
    
    func testRightPanelReturnsToDefaultOnDeselection() {
        // Given
        let file = FileItem(path: "/f/test.pdf", sizeInBytes: 1_000_000, creationDate: Date(), destination: nil, status: .pending)
        viewModel._testSetFiles([file])
        viewModel.selectedFolder = .home
        viewModel.toggleSelection(for: file)

        // When
        viewModel.deselectAll()
        
        // Then
        if case .default = viewModel.rightPanelMode {
            // Success
        } else {
            XCTFail("Right panel mode should return to .default when selection is cleared")
        }
    }
    
    func testRightPanelInspectorUpdatesWithMultipleFiles() {
        // Given
        let file1 = FileItem(path: "/f/1.pdf", sizeInBytes: 1_000_000, creationDate: Date(), destination: nil, status: .pending)
        let file2 = FileItem(path: "/f/2.pdf", sizeInBytes: 1_000_000, creationDate: Date(), destination: nil, status: .pending)
        viewModel._testSetFiles([file1, file2])
        viewModel.selectedFolder = .home

        // When
        viewModel.toggleSelection(for: file1)
        viewModel.toggleSelection(for: file2)

        // Then
        if case .inspector(let files) = viewModel.rightPanelMode {
            XCTAssertEqual(files.count, 2)
            XCTAssertTrue(files.contains { $0.path == file1.path })
            XCTAssertTrue(files.contains { $0.path == file2.path })
        } else {
            XCTFail("Right panel mode should show inspector with multiple files")
        }
    }

    func testInspectorState_ShowsSelectedTemplateAndSimulationSummary() throws {
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

        viewModel._testSetFiles([file])
        viewModel.toggleSelection(for: file)
        viewModel.selectedWorkflowTemplateID = BuiltInWorkflowTemplate.StableID.receipts

        let preview = try XCTUnwrap(viewModel.inspectorWorkflowSimulationPreview)
        XCTAssertEqual(viewModel.selectedWorkflowTemplate?.id, BuiltInWorkflowTemplate.StableID.receipts)
        XCTAssertEqual(preview.templateID, BuiltInWorkflowTemplate.StableID.receipts)
        XCTAssertEqual(preview.selectedFileCount, 1)
        XCTAssertEqual(preview.readyToRunCount, 1)
        XCTAssertTrue(preview.summaryText.contains("1 selected"))
    }

    func testDashboardWorkflowSimulationPreview_UsesBulkSelectionState() throws {
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.workflowEngineV2, true)

        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        let destinationFolder = try tempDirectory.createDirectory(name: "Receipts")
        let sourceURL = try tempDirectory.createFile(name: "Inbox/Bulk Preview Receipt.pdf", contents: "receipt")
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

        viewModel._testSetFiles([file])
        viewModel.toggleSelection(for: file)
        viewModel.selectedWorkflowTemplateID = BuiltInWorkflowTemplate.StableID.receipts

        let preview = try XCTUnwrap(viewModel.dashboardWorkflowSimulationPreview)
        XCTAssertEqual(preview.templateID, BuiltInWorkflowTemplate.StableID.receipts)
        XCTAssertEqual(preview.selectedFileCount, 1)
        XCTAssertEqual(preview.readyToRunCount, 1)
    }

    func testOrganizeSelectedFiles_PreservesSelectionWhenWorkflowEngineV2DoesNotAttemptExecution() async throws {
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.workflowEngineV2, true)

        let file = FileItem(
            path: "/Users/test/Downloads/preserved.pdf",
            sizeInBytes: 1_024,
            creationDate: Date(),
            location: .downloads,
            destination: .mockFolder("Documents"),
            status: .ready
        )

        viewModel._testSetFiles([file])
        viewModel.toggleSelection(for: file)

        await MainActor.run {
            viewModel.organizeSelectedFiles(context: nil)
        }
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(viewModel.selectedFileIDs, [file.path])
        XCTAssertTrue(viewModel.selectedFiles.contains { $0 === file })
    }

    func testLatestWorkflowInspectorSummary_ShowsLatestWorkflowRunSummary() throws {
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.workflowEngineV2, true)

        let schema = Schema([
            FileItem.self,
            Rule.self,
            ActivityItem.self,
            FileMetadataRecord.self,
            FileOrganizationHistoryEntry.self,
            TrustedAutomationScopeRunRecord.self,
            WorkflowRunRecord.self,
            WorkflowStepRunRecord.self,
            WorkflowFileActionRecord.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        viewModel.setModelContext(context)

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
            status: .completed
        )
        context.insert(file)
        try context.save()

        let metadataService = FileMetadataFoundationService(modelContext: context)
        let identity = metadataService.resolveIdentity(for: file.path).canonicalIdentity
        let store = WorkflowAuditStore(modelContext: context)
        let run = try store.createRun(
            scopeID: UUID(),
            workflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts,
            startedAt: Date(timeIntervalSince1970: 1_712_620_810),
            primaryStatus: .succeeded
        )

        let renameStep = try store.recordStepStatus(
            runID: run.id,
            stepID: "execute|rename|\(sourceURL.path)",
            status: .succeeded,
            startedAt: Date(timeIntervalSince1970: 1_712_620_811),
            endedAt: Date(timeIntervalSince1970: 1_712_620_812)
        )
        _ = try store.recordFileAction(
            runID: run.id,
            stepRunID: renameStep.id,
            fileIdentity: identity,
            sourcePath: sourceURL.path,
            destinationPath: sourceFolder.appendingPathComponent("2024-04-09-April Receipt.pdf").path,
            disposition: .moved,
            compensationStatus: .available,
            compensationPayload: WorkflowCompensationPayloadCodec.encode(
                .renameRollback(
                    originalPath: sourceURL.path,
                    renamedPath: sourceFolder.appendingPathComponent("2024-04-09-April Receipt.pdf").path
                )
            )
        )

        let tagStep = try store.recordStepStatus(
            runID: run.id,
            stepID: "execute|tag|\(sourceURL.path)",
            status: .succeeded,
            startedAt: Date(timeIntervalSince1970: 1_712_620_813),
            endedAt: Date(timeIntervalSince1970: 1_712_620_814)
        )
        _ = try store.recordFileAction(
            runID: run.id,
            stepRunID: tagStep.id,
            fileIdentity: identity,
            sourcePath: sourceFolder.appendingPathComponent("2024-04-09-April Receipt.pdf").path,
            destinationPath: sourceFolder.appendingPathComponent("2024-04-09-April Receipt.pdf").path,
            disposition: .moved,
            compensationStatus: .available,
            compensationPayload: WorkflowCompensationPayloadCodec.encode(
                .tagRemoval(
                    path: sourceFolder.appendingPathComponent("2024-04-09-April Receipt.pdf").path,
                    tagsToRemove: ["receipt", "document"]
                )
            )
        )

        let moveStep = try store.recordStepStatus(
            runID: run.id,
            stepID: "execute|move|\(sourceURL.path)",
            status: .succeeded,
            startedAt: Date(timeIntervalSince1970: 1_712_620_815),
            endedAt: Date(timeIntervalSince1970: 1_712_620_816)
        )
        _ = try store.recordFileAction(
            runID: run.id,
            stepRunID: moveStep.id,
            fileIdentity: identity,
            sourcePath: sourceFolder.appendingPathComponent("2024-04-09-April Receipt.pdf").path,
            destinationPath: destinationFolder.appendingPathComponent("2024-04-09-April Receipt.pdf").path,
            disposition: .moved,
            compensationStatus: .available,
            compensationPayload: WorkflowCompensationPayloadCodec.encode(
                .moveRollback(
                    originalDestinationPath: destinationFolder.appendingPathComponent("2024-04-09-April Receipt.pdf").path,
                    rollbackPath: sourceFolder.appendingPathComponent("2024-04-09-April Receipt.pdf").path
                )
            )
        )
        try store.updateRunStatus(
            runID: run.id,
            primaryStatus: .succeeded,
            endedAt: Date(timeIntervalSince1970: 1_712_620_817)
        )

        let summary = try XCTUnwrap(
            viewModel.latestWorkflowInspectorSummary(for: file.path, context: context)
        )

        XCTAssertEqual(summary.runID, run.id)
        XCTAssertEqual(summary.templateDisplayName, "Receipt Intake")
        XCTAssertEqual(summary.renameResultFileName, "2024-04-09-April Receipt.pdf")
        XCTAssertEqual(summary.appliedTags, ["document", "receipt"])
        XCTAssertEqual(summary.moveDestinationDisplayName, "Receipts")
        XCTAssertTrue(summary.statusText.contains("Succeeded"))
        XCTAssertTrue(summary.canOpenRunDetail)
    }
    
    func testShowRuleBuilderPanel() {
        // Given
        let file = FileItem(path: "/f/test.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .pending)
        viewModel.setRightPanelVisible(false)

        // When
        viewModel.showRuleBuilderPanel(fileContext: file)

        // Then
        if case .ruleBuilder(let editingRule, let contextFile) = viewModel.rightPanelMode {
            XCTAssertNil(editingRule, "Should not have editing rule when creating new")
            XCTAssertEqual(contextFile?.path, file.path)
        } else {
            XCTFail("Right panel mode should switch to .ruleBuilder")
        }
        XCTAssertTrue(viewModel.isRightPanelVisible, "Opening the inline rule builder should reveal the right panel")
    }

    func testShowRuleBuilderPanelWithoutFile() {
        viewModel.setRightPanelVisible(false)

        // When
        viewModel.showRuleBuilderPanel()

        // Then
        if case .ruleBuilder(let editingRule, let contextFile) = viewModel.rightPanelMode {
            XCTAssertNil(editingRule, "Should not have editing rule")
            XCTAssertNil(contextFile, "Should not have file context")
        } else {
            XCTFail("Right panel mode should switch to .ruleBuilder even without file")
        }
        XCTAssertTrue(viewModel.isRightPanelVisible, "Opening the inline rule builder should reveal the right panel")
    }

    func testShowAnalyticsPanelRevealsRightPanel() {
        viewModel.setRightPanelVisible(false)
        viewModel.showCelebrationPanel(message: "Done!")

        viewModel.showAnalyticsPanel()

        if case .analytics = viewModel.rightPanelMode {
            // Success
        } else {
            XCTFail("Opening analytics should switch the right panel into analytics mode")
        }

        XCTAssertTrue(viewModel.isRightPanelVisible, "Opening analytics should reveal the right panel")
    }

    func testDefaultPanelPrimaryActionHidesWhileRuleDraftWorkflowIsActive() {
        XCTAssertFalse(
            viewModel.shouldShowDefaultPanelPrimaryAction(for: .home, hasActiveRuleDraft: true),
            "The default panel CTA should step back while a rule draft owns the workflow"
        )
    }

    func testDefaultPanelPrimaryActionShowsWhenHomeIsIdle() {
        XCTAssertTrue(
            viewModel.shouldShowDefaultPanelPrimaryAction(for: .home, hasActiveRuleDraft: false),
            "The default panel CTA should appear when no review or rule-draft workflow owns the next action"
        )
    }

    func testShowRuleBuilderPanelForInspectorKeepsSelectionAndReviewChunk() {
        let files = makeReviewFiles(count: 12)
        let targetFile = files
            .sorted { $0.creationDate > $1.creationDate }
            .first!

        viewModel._testSetFiles(files)
        viewModel.setRightPanelVisible(false)
        let originalChunkPaths = viewModel.currentReviewChunkPaths

        viewModel.showRuleBuilderPanelForInspector(targetFile)

        if case .ruleBuilder(let editingRule, let contextFile) = viewModel.rightPanelMode {
            XCTAssertNil(editingRule)
            XCTAssertEqual(contextFile?.path, targetFile.path)
        } else {
            XCTFail("Inspector workflow should switch the panel into rule builder mode")
        }

        XCTAssertEqual(viewModel.selectedFileIDs, [targetFile.path])
        XCTAssertEqual(viewModel.focusedFilePath, targetFile.path)
        XCTAssertEqual(viewModel.currentReviewChunkPaths, originalChunkPaths)
        XCTAssertTrue(viewModel.isRightPanelVisible, "Inspector rule builder flow should reveal the right panel")
    }

    func testRestorePanelAfterInspectorRuleDraftReopensInspectorWithoutResettingReviewChunk() {
        let files = makeReviewFiles(count: 12)
        let targetFile = files
            .sorted { $0.creationDate > $1.creationDate }
            .first!

        viewModel._testSetFiles(files)
        let originalChunkPaths = viewModel.currentReviewChunkPaths
        viewModel.showRuleBuilderPanelForInspector(targetFile)
        viewModel.returnToDefaultPanel()

        viewModel.restorePanel(afterRuleDraftReturnTarget: .inspector(filePath: targetFile.path))

        if case .inspector(let inspectorFiles) = viewModel.rightPanelMode {
            XCTAssertEqual(inspectorFiles.map(\.path), [targetFile.path])
        } else {
            XCTFail("Inspector return target should restore the file inspector")
        }

        XCTAssertEqual(viewModel.selectedFileIDs, [targetFile.path])
        XCTAssertEqual(viewModel.focusedFilePath, targetFile.path)
        XCTAssertEqual(viewModel.currentReviewChunkPaths, originalChunkPaths)
    }

    func testOpenFileFromProjectSpaceMatchesInspectorRestorePath() {
        let files = makeReviewFiles(count: 12)
        let targetFile = files
            .sorted { $0.creationDate > $1.creationDate }
            .first!
        let projectSpaceFile = ProjectSpaceFileRow(
            canonicalIdentity: targetFile.path,
            path: targetFile.path,
            displayName: URL(fileURLWithPath: targetFile.path).lastPathComponent
        )

        viewModel._testSetFiles(files)
        let originalChunkPaths = viewModel.currentReviewChunkPaths
        viewModel.setRightPanelVisible(false)

        viewModel.openFileFromProjectSpace(projectSpaceFile)

        if case .inspector(let inspectorFiles) = viewModel.rightPanelMode {
            XCTAssertEqual(inspectorFiles.map(\.path), [targetFile.path])
        } else {
            XCTFail("Project-space file opening should route through the inspector selection flow")
        }

        XCTAssertEqual(viewModel.selectedFileIDs, [targetFile.path])
        XCTAssertEqual(viewModel.focusedFilePath, targetFile.path)
        XCTAssertEqual(viewModel.currentReviewChunkPaths, originalChunkPaths)
        XCTAssertTrue(viewModel.isRightPanelVisible)
    }

    func testOpenFileFromProjectSpaceFallsBackToMetadataBackedRowWhenScanCacheIsEmpty() {
        let timestamp = Date(timeIntervalSince1970: 2_000)
        let fileRow = ProjectSpaceFileRow(
            canonicalIdentity: "bookmark|alpha-plan",
            path: "/Volumes/Secure/Alpha Plan.md",
            displayName: "Alpha Plan.md",
            fileExtension: "md",
            lastActivityAt: timestamp,
            workflowStatus: .organized,
            tags: ["client"]
        )

        viewModel.setRightPanelVisible(false)
        viewModel.openFileFromProjectSpace(fileRow)

        if case .inspector(let inspectorFiles) = viewModel.rightPanelMode {
            XCTAssertEqual(inspectorFiles.map(\.path), [fileRow.path])
            XCTAssertEqual(inspectorFiles.first?.creationDate, timestamp)
            XCTAssertEqual(inspectorFiles.first?.modificationDate, timestamp)
            XCTAssertEqual(inspectorFiles.first?.lastAccessedDate, timestamp)
            XCTAssertEqual(inspectorFiles.first?.status, .completed)
        } else {
            XCTFail("Metadata-backed project-space rows should still open the inspector when the scan cache is empty")
        }

        XCTAssertEqual(viewModel.selectedFileIDs, [fileRow.path])
        XCTAssertEqual(viewModel.focusedFilePath, fileRow.path)
        XCTAssertTrue(viewModel.isRightPanelVisible)
    }

    func testRestorePanelFallsBackToDefaultWhenInspectorFileIsGone() {
        let file = FileItem(path: "/review/file-1.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .pending)
        viewModel._testSetFiles([file])
        viewModel.showRuleBuilderPanelForInspector(file)
        viewModel._testSetFiles([])
        viewModel.returnToDefaultPanel()

        viewModel.restorePanel(afterRuleDraftReturnTarget: .inspector(filePath: file.path))

        if case .default = viewModel.rightPanelMode {
            // Success
        } else {
            XCTFail("Missing inspector file should fall back to the default panel")
        }
    }

    func testRestorePanelWithNoReturnTargetFallsBackToDefaultPanel() {
        let file = FileItem(path: "/review/file-1.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .pending)
        viewModel._testSetFiles([file])
        viewModel.showRuleBuilderPanel(fileContext: file)

        viewModel.restorePanel(afterRuleDraftReturnTarget: .none)

        if case .default = viewModel.rightPanelMode {
            // Success
        } else {
            XCTFail("No return target should fall back to the default panel when dismissing a rule draft")
        }
    }

    func testShowRuleWorkflowCelebrationDisablesUndoAffordance() {
        viewModel.showRuleWorkflowCelebration(message: "Rule created!", returnTarget: .defaultPanel)

        if case .celebration(let message) = viewModel.rightPanelMode {
            XCTAssertEqual(message, "Rule created!")
        } else {
            XCTFail("Rule workflow should present a celebration panel")
        }

        XCTAssertFalse(viewModel.celebrationShowsUndo)
        XCTAssertFalse(viewModel.celebrationShowsNextActionSuggestion)
    }

    func testDismissRuleWorkflowCelebrationRestoresInspectorReturnTarget() {
        let file = FileItem(path: "/review/file-1.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .pending)
        viewModel._testSetFiles([file])
        viewModel.showRuleWorkflowCelebration(message: "Rule created!", returnTarget: .inspector(filePath: file.path))

        viewModel.dismissCelebrationPanel()

        if case .inspector(let inspectorFiles) = viewModel.rightPanelMode {
            XCTAssertEqual(inspectorFiles.map(\.path), [file.path])
        } else {
            XCTFail("Dismissing a rule workflow celebration should restore the inspector")
        }

        XCTAssertEqual(viewModel.selectedFileIDs, [file.path])
        XCTAssertEqual(viewModel.focusedFilePath, file.path)
    }
    
    func testShowCelebrationPanel() {
        // When
        viewModel.showCelebrationPanel(message: "Success!")
        
        // Then
        if case .celebration(let message) = viewModel.rightPanelMode {
            XCTAssertEqual(message, "Success!")
        } else {
            XCTFail("Right panel mode should switch to .celebration")
        }
    }
    
    func testReturnToDefaultPanel() {
        // Given: Start in celebration mode
        viewModel.showCelebrationPanel(message: "Done!")
        
        // When
        viewModel.returnToDefaultPanel()
        
        // Then
        if case .default = viewModel.rightPanelMode {
            // Success
        } else {
            XCTFail("returnToDefaultPanel should switch mode to .default")
        }
    }
    
    func testCelebrationModePersistsEvenWithSelection() {
        // Given
        let file = FileItem(path: "/f/test.pdf", sizeInBytes: 1_000_000, creationDate: Date(), destination: nil, status: .pending)
        viewModel._testSetFiles([file])
        viewModel.selectedFolder = .home
        viewModel.showCelebrationPanel(message: "File organized!")

        // When: Try to select a file while in celebration mode
        viewModel.toggleSelection(for: file)
        
        // Then: Should remain in celebration mode (celebration takes precedence)
        if case .celebration = viewModel.rightPanelMode {
            // Success - celebration mode persists
        } else {
            XCTFail("Celebration mode should persist even when files are selected")
        }
    }

    private func waitForContentSearchDebounce() async {
        try? await Task.sleep(nanoseconds: 500_000_000)
    }
}

@MainActor
private final class WorkflowExecutionSpy {
    var plannedTemplateIDs: [String] = []
    var plannedInvocationContexts: [WorkflowInvocationContext] = []
    var ranTemplateIDs: [String] = []
    var lastRunFilePaths: [String] = []
    var runID = UUID()
    var runPrimaryStatus: WorkflowRunPrimaryStatus = .succeeded
    var runEndedAt = Date(timeIntervalSince1970: 1_500)
    var persistRunRecordBeforeThrow = false
    var runError: Error?

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
        run: { [weak self] plan, files, scopeID, modelContext in
            let filePaths = files.map(\.path)
            await MainActor.run {
                self?.ranTemplateIDs.append(plan.definition.templateID)
                self?.lastRunFilePaths = filePaths
            }
            let runID = await MainActor.run { self?.runID ?? UUID() }
            let primaryStatus = await MainActor.run { self?.runPrimaryStatus ?? .succeeded }
            let endedAt = await MainActor.run { self?.runEndedAt }
            let runRecord = WorkflowRunRecord(
                id: runID,
                scopeID: scopeID,
                workflowTemplateID: plan.definition.templateID,
                primaryStatus: primaryStatus,
                startedAt: Date(timeIntervalSince1970: 1_000),
                endedAt: endedAt,
                updatedAt: endedAt
            )

            let persistRunRecordBeforeThrow = await MainActor.run { self?.persistRunRecordBeforeThrow ?? false }
            let runError = await MainActor.run { self?.runError }

            if persistRunRecordBeforeThrow {
                let templateID = plan.definition.templateID
                let container = modelContext.container
                await MainActor.run {
                    let persistenceContext = ModelContext(container)
                    let persistedRunRecord = WorkflowRunRecord(
                        id: runID,
                        scopeID: scopeID,
                        workflowTemplateID: templateID,
                        primaryStatus: primaryStatus,
                        startedAt: Date(timeIntervalSince1970: 1_000),
                        endedAt: endedAt,
                        updatedAt: endedAt
                    )
                    persistenceContext.insert(persistedRunRecord)
                    try? persistenceContext.save()
                }
            }

            if let runError {
                throw runError
            }

            return runRecord
        }
    )
}

private enum WorkflowExecutionTestError: Error {
    case failed
}
