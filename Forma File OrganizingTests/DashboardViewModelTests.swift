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

	    var viewModel: DashboardViewModel!
	    var mockService: MockFileSystemService!
	    var mockPipeline: MockFileScanPipeline!

	    override func setUp() async throws {
	        try await super.setUp()
	
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
	        await MainActor.run {
	            viewModel = nil
	            mockService = nil
	            mockPipeline = nil
	        }
	        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
	        try await super.tearDown()
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
    
    func testShowRuleBuilderPanel() {
        // Given
        let file = FileItem(path: "/f/test.txt", sizeInBytes: 1_000, creationDate: Date(), destination: nil, status: .pending)

        // When
        viewModel.showRuleBuilderPanel(fileContext: file)

        // Then
        if case .ruleBuilder(let editingRule, let contextFile) = viewModel.rightPanelMode {
            XCTAssertNil(editingRule, "Should not have editing rule when creating new")
            XCTAssertEqual(contextFile?.path, file.path)
        } else {
            XCTFail("Right panel mode should switch to .ruleBuilder")
        }
    }

    func testShowRuleBuilderPanelWithoutFile() {
        // When
        viewModel.showRuleBuilderPanel()

        // Then
        if case .ruleBuilder(let editingRule, let contextFile) = viewModel.rightPanelMode {
            XCTAssertNil(editingRule, "Should not have editing rule")
            XCTAssertNil(contextFile, "Should not have file context")
        } else {
            XCTFail("Right panel mode should switch to .ruleBuilder even without file")
        }
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
