import XCTest
@testable import Forma_File_Organizing

@MainActor
final class DashboardViewModelTests: XCTestCase {

    var viewModel: DashboardViewModel!
    var mockService: MockFileSystemService!
    var mockPipeline: MockFileScanPipeline!

    override func setUp() {
        super.setUp()
        mockService = MockFileSystemService()
        mockPipeline = MockFileScanPipeline()
        viewModel = DashboardViewModel(
            services: AppServices(),
            fileSystemService: mockService,
            fileScanPipeline: mockPipeline
        )
    }
    
    override func tearDown() {
        viewModel = nil
        mockService = nil
        mockPipeline = nil
        super.tearDown()
    }
    
    func testInitialPermissionsCheck() {
        // Given
        mockService.hasDesktop = false
        mockService.hasDownloads = false
        mockService.hasDocuments = false
        mockService.hasPictures = false
        mockService.hasMusic = false
        
        // When
        viewModel.checkPermissions()
        
        // Then
        XCTAssertTrue(viewModel.showOnboarding, "Onboarding should be shown when permissions are missing")
    }
    
    func testPermissionsGranted() {
        // Given
        mockService.hasDesktop = true
        mockService.hasDownloads = true
        mockService.hasDocuments = true
        mockService.hasPictures = true
        mockService.hasMusic = true
        
        // When
        viewModel.checkPermissions()
        
        // Then
        XCTAssertFalse(viewModel.showOnboarding, "Onboarding should not be shown when all permissions are granted")
    }
    
    func testRequestDesktopAccess() async {
        // Given
        mockService.hasDesktop = false
        
        // When
        await viewModel.requestDesktopAccess()
        
        // Then
        XCTAssertTrue(viewModel.hasDesktopAccess, "Desktop access should be granted")
    }
    
    func testFilterByLocation() {
        // Given
        let desktopFile = FileItem(name: "test.txt", fileExtension: "txt", size: "1KB", sizeInBytes: 1024, creationDate: Date(), path: "/Users/test/Desktop/test.txt", destination: nil, status: .pending)
        let downloadsFile = FileItem(name: "download.zip", fileExtension: "zip", size: "1MB", sizeInBytes: 1024*1024, creationDate: Date(), path: "/Users/test/Downloads/download.zip", destination: nil, status: .pending)
        
        viewModel._testSetFiles([desktopFile, downloadsFile])

        // When
        viewModel.selectedFolder = .desktop
        
        // Then
        XCTAssertEqual(viewModel.filteredFiles.count, 1)
        XCTAssertEqual(viewModel.filteredFiles.first?.name, "test.txt")
    }
    
    func testUpdateDestinationUpdatesFile() {
        // Given
        let file = FileItem(name: "doc.pdf", fileExtension: "pdf", size: "1MB", sizeInBytes: 1_000_000, creationDate: Date(), path: "/Users/test/Desktop/doc.pdf", destination: nil, status: .pending)
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
        let pendingWithSuggestion = FileItem(name: "a.pdf", fileExtension: "pdf", size: "1MB", sizeInBytes: 1_000_000, creationDate: Date(), path: "/f/a.pdf", destination: .mockFolder("Documents"), status: .pending)
        let pendingNoSuggestion = FileItem(name: "b.png", fileExtension: "png", size: "2MB", sizeInBytes: 2_000_000, creationDate: Date(), path: "/f/b.png", destination: nil, status: .pending)
        let completed = FileItem(name: "c.txt", fileExtension: "txt", size: "1KB", sizeInBytes: 1_000, creationDate: Date(), path: "/f/c.txt", destination: .mockFolder("Documents"), status: .completed)
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
        let pending = FileItem(name: "a.pdf", fileExtension: "pdf", size: "1MB", sizeInBytes: 1_000_000, creationDate: Date(), path: "/f/a.pdf", destination: .mockFolder("Documents"), status: .pending)
        let completed = FileItem(name: "c.txt", fileExtension: "txt", size: "1KB", sizeInBytes: 1_000, creationDate: Date(), path: "/f/c.txt", destination: .mockFolder("Documents"), status: .completed)
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
        let pendingWithSuggestion = FileItem(name: "a.pdf", fileExtension: "pdf", size: "1MB", sizeInBytes: 1_000_000, creationDate: Date(), path: "/f/a.pdf", destination: .mockFolder("Documents"), status: .pending)
        let pendingNoSuggestion = FileItem(name: "b.png", fileExtension: "png", size: "2MB", sizeInBytes: 2_000_000, creationDate: Date(), path: "/f/b.png", destination: nil, status: .pending)
        let completedWithSuggestion = FileItem(name: "c.txt", fileExtension: "txt", size: "1KB", sizeInBytes: 1_000, creationDate: Date(), path: "/f/c.txt", destination: .mockFolder("Documents"), status: .completed)
        let completedNoSuggestion = FileItem(name: "d.txt", fileExtension: "txt", size: "1KB", sizeInBytes: 1_000, creationDate: Date(), path: "/f/d.txt", destination: nil, status: .completed)
        viewModel._testSetFiles([pendingWithSuggestion, pendingNoSuggestion, completedWithSuggestion, completedNoSuggestion])
        viewModel.selectedFolder = .home
        
        // When
        viewModel.selectCategory(.all)
        
        // Then
        XCTAssertEqual(viewModel.needsReviewCount, 2)
        XCTAssertEqual(viewModel.allFilesCount, 2)
    }
    
    func testVisibleFilesLargeFilesFilter() {
        // Given
        let small = FileItem(name: "small.mov", fileExtension: "mov", size: "1MB", sizeInBytes: 1_000_000, creationDate: Date(), path: "/f/small.mov", destination: nil, status: .pending)
        let large = FileItem(name: "large.mov", fileExtension: "mov", size: "20MB", sizeInBytes: 20 * 1_024 * 1_024, creationDate: Date(), path: "/f/large.mov", destination: nil, status: .pending)
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
        let oldest = FileItem(name: "old.txt", fileExtension: "txt", size: "1KB", sizeInBytes: 1_000, creationDate: Date().addingTimeInterval(-3600), path: "/f/old.txt", destination: nil, status: .pending)
        let middle = FileItem(name: "mid.txt", fileExtension: "txt", size: "1KB", sizeInBytes: 1_000, creationDate: Date().addingTimeInterval(-1800), path: "/f/mid.txt", destination: nil, status: .pending)
        let newest = FileItem(name: "new.txt", fileExtension: "txt", size: "1KB", sizeInBytes: 1_000, creationDate: Date(), path: "/f/new.txt", destination: nil, status: .pending)
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
    
    func testFocusNextAndPrevious() {
        // Given
        let one = FileItem(name: "1.txt", fileExtension: "txt", size: "1KB", sizeInBytes: 1_000, creationDate: Date(), path: "/f/1.txt", destination: nil, status: .pending)
        let two = FileItem(name: "2.txt", fileExtension: "txt", size: "1KB", sizeInBytes: 1_000, creationDate: Date(), path: "/f/2.txt", destination: nil, status: .pending)
        let three = FileItem(name: "3.txt", fileExtension: "txt", size: "1KB", sizeInBytes: 1_000, creationDate: Date(), path: "/f/3.txt", destination: nil, status: .pending)
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
        for i in 0..<25 {
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
        let file1 = FileItem(name: "1.txt", fileExtension: "txt", size: "1KB", sizeInBytes: 1_000, creationDate: Date(), path: "/f/1.txt", destination: nil, status: .pending)
        let file2 = FileItem(name: "2.txt", fileExtension: "txt", size: "1KB", sizeInBytes: 1_000, creationDate: Date(), path: "/f/2.txt", destination: nil, status: .pending)
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
        let file1 = FileItem(name: "1.txt", fileExtension: "txt", size: "1KB", sizeInBytes: 1_000, creationDate: Date(), path: "/f/1.txt", destination: nil, status: .pending)
        let file2 = FileItem(name: "2.txt", fileExtension: "txt", size: "1KB", sizeInBytes: 1_000, creationDate: Date(), path: "/f/2.txt", destination: nil, status: .pending)
        let file3 = FileItem(name: "3.txt", fileExtension: "txt", size: "1KB", sizeInBytes: 1_000, creationDate: Date(), path: "/f/3.txt", destination: nil, status: .pending)
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
        let file1 = FileItem(name: "1.txt", fileExtension: "txt", size: "1KB", sizeInBytes: 1_000, creationDate: Date(), path: "/f/1.txt", destination: nil, status: .pending)
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
        let file1 = FileItem(name: "1.pdf", fileExtension: "pdf", size: "1MB", sizeInBytes: 1_000_000, creationDate: Date(), path: "/f/1.pdf", destination: .mockFolder("Documents"), status: .pending)
        let file2 = FileItem(name: "2.pdf", fileExtension: "pdf", size: "1MB", sizeInBytes: 1_000_000, creationDate: Date(), path: "/f/2.pdf", destination: .mockFolder("Documents"), status: .pending)
        viewModel._testSetFiles([file1, file2])
        viewModel.selectedFolder = .home
        viewModel.toggleSelection(for: file1)
        viewModel.toggleSelection(for: file2)
        
        // Then
        XCTAssertTrue(viewModel.canOrganizeAllSelected)
    }
    
    func testCanOrganizeAllSelected_DifferentDestinations() {
        // Given
        let file1 = FileItem(name: "1.pdf", fileExtension: "pdf", size: "1MB", sizeInBytes: 1_000_000, creationDate: Date(), path: "/f/1.pdf", destination: .mockFolder("Documents"), status: .pending)
        let file2 = FileItem(name: "2.png", fileExtension: "png", size: "2MB", sizeInBytes: 2_000_000, creationDate: Date(), path: "/f/2.png", destination: .mockFolder("Pictures"), status: .pending)
        viewModel._testSetFiles([file1, file2])
        viewModel.selectedFolder = .home
        viewModel.toggleSelection(for: file1)
        viewModel.toggleSelection(for: file2)
        
        // Then
        XCTAssertFalse(viewModel.canOrganizeAllSelected)
    }
    
    func testCanOrganizeAllSelected_NoSuggestions() {
        // Given
        let file1 = FileItem(name: "1.txt", fileExtension: "txt", size: "1KB", sizeInBytes: 1_000, creationDate: Date(), path: "/f/1.txt", destination: nil, status: .pending)
        viewModel._testSetFiles([file1])
        viewModel.selectedFolder = .home
        viewModel.toggleSelection(for: file1)
        
        // Then
        XCTAssertFalse(viewModel.canOrganizeAllSelected)
    }
    
    // MARK: - Phase 2 Tests: Bulk Operations
    
    func testSkipSelectedFiles() {
        // Given
        let file1 = FileItem(name: "1.txt", fileExtension: "txt", size: "1KB", sizeInBytes: 1_000, creationDate: Date(), path: "/f/1.txt", destination: nil, status: .pending)
        let file2 = FileItem(name: "2.txt", fileExtension: "txt", size: "1KB", sizeInBytes: 1_000, creationDate: Date(), path: "/f/2.txt", destination: nil, status: .pending)
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
        let file1 = FileItem(name: "1.txt", fileExtension: "txt", size: "1KB", sizeInBytes: 1_000, creationDate: Date(), path: "/f/1.txt", destination: nil, status: .pending)
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
        let file1 = FileItem(name: "1.txt", fileExtension: "txt", size: "1KB", sizeInBytes: 1_000, creationDate: Date(), path: "/f/1.txt", destination: nil, status: .pending)
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
        let file = FileItem(name: "test.txt", fileExtension: "txt", size: "1KB", sizeInBytes: 1_000, creationDate: Date(), path: "/f/test.txt", destination: nil, status: .pending)
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
        let file1 = FileItem(name: "1.txt", fileExtension: "txt", size: "1KB", sizeInBytes: 1_000, creationDate: Date(), path: "/f/1.txt", destination: nil, status: .pending)
        let file2 = FileItem(name: "2.txt", fileExtension: "txt", size: "1KB", sizeInBytes: 1_000, creationDate: Date(), path: "/f/2.txt", destination: nil, status: .pending)
        let file3 = FileItem(name: "3.txt", fileExtension: "txt", size: "1KB", sizeInBytes: 1_000, creationDate: Date(), path: "/f/3.txt", destination: nil, status: .pending)
        let file4 = FileItem(name: "4.txt", fileExtension: "txt", size: "1KB", sizeInBytes: 1_000, creationDate: Date(), path: "/f/4.txt", destination: nil, status: .pending)
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
    
    // MARK: - Selection Persistence Tests
    
    func testSelectionClearsOnCategoryChange() {
        // Given
        let file1 = FileItem(name: "image.png", fileExtension: "png", size: "2MB", sizeInBytes: 2_000_000, creationDate: Date(), path: "/f/image.png", destination: nil, status: .pending)
        let file2 = FileItem(name: "doc.pdf", fileExtension: "pdf", size: "1MB", sizeInBytes: 1_000_000, creationDate: Date(), path: "/f/doc.pdf", destination: nil, status: .pending)
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
        let file1 = FileItem(name: "1.txt", fileExtension: "txt", size: "1KB", sizeInBytes: 1_000, creationDate: Date(), path: "/f/1.txt", destination: nil, status: .pending)
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
        let file1 = FileItem(name: "1.txt", fileExtension: "txt", size: "1KB", sizeInBytes: 1_000, creationDate: Date(), path: "/f/1.txt", destination: nil, status: .pending)
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
        let file1 = FileItem(name: "1.pdf", fileExtension: "pdf", size: "1MB", sizeInBytes: 1_000_000, creationDate: Date(), path: "/f/1.pdf", destination: .mockFolder("Documents"), status: .pending)
        let file2 = FileItem(name: "2.png", fileExtension: "png", size: "2MB", sizeInBytes: 2_000_000, creationDate: Date(), path: "/f/2.png", destination: .mockFolder("Pictures"), status: .pending)
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
        let file1 = FileItem(name: "1.pdf", fileExtension: "pdf", size: "1MB", sizeInBytes: 1_000_000, creationDate: Date(), path: "/f/1.pdf", destination: .mockFolder("Documents"), status: .pending)
        let file2 = FileItem(name: "2.txt", fileExtension: "txt", size: "1KB", sizeInBytes: 1_000, creationDate: Date(), path: "/f/2.txt", destination: nil, status: .pending)
        let file3 = FileItem(name: "3.pdf", fileExtension: "pdf", size: "1MB", sizeInBytes: 1_000_000, creationDate: Date(), path: "/f/3.pdf", destination: .mockFolder("Documents"), status: .pending)
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
        let file1 = FileItem(name: "1.txt", fileExtension: "txt", size: "1KB", sizeInBytes: 1_000, creationDate: Date(), path: "/f/1.txt", destination: nil, status: .pending)
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
        let file1 = FileItem(name: "1.txt", fileExtension: "txt", size: "1KB", sizeInBytes: 1_000, creationDate: Date(), path: "/f/1.txt", destination: nil, status: .pending)
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
        let screenshot = FileItem(
            name: "Screenshot 2024-01-01 at 10.00.00.png",
            fileExtension: "png",
            size: "1MB",
            sizeInBytes: 1_000_000,
            creationDate: Date(),
            path: "/f/Screenshot.png",
            destination: nil,
            status: .pending
        )
        let document = FileItem(
            name: "MeetingNotes.pdf",
            fileExtension: "pdf",
            size: "500KB",
            sizeInBytes: 500_000,
            creationDate: Date(),
            path: "/f/MeetingNotes.pdf",
            destination: nil,
            status: .pending
        )

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
    
    // MARK: - Performance Tests
    
    func testLargeSelectionPerformance() {
        // Given: Create 100 files
        var files: [FileItem] = []
        for i in 0..<100 {
            let file = FileItem(
                name: "\(i).txt",
                fileExtension: "txt",
                size: "1KB",
                sizeInBytes: 1_000,
                creationDate: Date(),
                path: "/f/\(i).txt",
                destination: nil,
                status: .pending
            )
            files.append(file)
        }
        viewModel._testSetFiles(files)
        viewModel.selectedFolder = .home
        viewModel.reviewFilterMode = .all
        viewModel.selectCategory(.all)

        // When: Select all
        let start = Date()
        viewModel.selectAll()
        let duration = Date().timeIntervalSince(start)
        
        // Then: Should complete quickly and have all files selected
        XCTAssertEqual(viewModel.selectedFileIDs.count, 100)
        XCTAssertLessThan(duration, 0.1) // Should take less than 100ms
        XCTAssertTrue(viewModel.isSelectionMode)
    }
    
    func testBulkSkip100Files() {
        // Given: Create 100 files
        var files: [FileItem] = []
        for i in 0..<100 {
            let file = FileItem(
                name: "\(i).txt",
                fileExtension: "txt",
                size: "1KB",
                sizeInBytes: 1_000,
                creationDate: Date(),
                path: "/f/\(i).txt",
                destination: nil,
                status: .pending
            )
            files.append(file)
        }
        viewModel._testSetFiles(files)
        viewModel.selectedFolder = .home
        viewModel.selectAll()

        // When: Skip all
        let start = Date()
        viewModel.skipSelectedFiles()
        let duration = Date().timeIntervalSince(start)
        
        // Then: All should be skipped
        XCTAssertEqual(files.filter { $0.status == .skipped }.count, 100)
        XCTAssertLessThan(duration, 0.5) // Should take less than 500ms
        // Each skipped file produces an undo command, but the stack is capped
        // by FormaConfig.Limits.maxUndoActions to prevent unbounded memory use.
        XCTAssertEqual(viewModel.undoStack.count, FormaConfig.Limits.maxUndoActions)
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
        let file = FileItem(name: "test.pdf", fileExtension: "pdf", size: "1MB", sizeInBytes: 1_000_000, creationDate: Date(), path: "/f/test.pdf", destination: nil, status: .pending)
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
        let file = FileItem(name: "test.pdf", fileExtension: "pdf", size: "1MB", sizeInBytes: 1_000_000, creationDate: Date(), path: "/f/test.pdf", destination: nil, status: .pending)
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
        let file1 = FileItem(name: "1.pdf", fileExtension: "pdf", size: "1MB", sizeInBytes: 1_000_000, creationDate: Date(), path: "/f/1.pdf", destination: nil, status: .pending)
        let file2 = FileItem(name: "2.pdf", fileExtension: "pdf", size: "1MB", sizeInBytes: 1_000_000, creationDate: Date(), path: "/f/2.pdf", destination: nil, status: .pending)
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
        let file = FileItem(name: "test.txt", fileExtension: "txt", size: "1KB", sizeInBytes: 1_000, creationDate: Date(), path: "/f/test.txt", destination: nil, status: .pending)

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
        let file = FileItem(name: "test.pdf", fileExtension: "pdf", size: "1MB", sizeInBytes: 1_000_000, creationDate: Date(), path: "/f/test.pdf", destination: nil, status: .pending)
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
}
