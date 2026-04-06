import XCTest
@testable import Forma_File_Organizing

@MainActor
final class FileFilterManagerTests: XCTestCase {

    func testDesktopFilter_UsesLocationKindWhenAvailable() {
        // Given: one desktop file with explicit location and one downloads file
        let now = Date()
        let desktopFile = FileItem(
            path: "/Volumes/External/WeirdLocation/a.txt",
            sizeInBytes: 1_000,
            creationDate: now,
            modificationDate: now,
            lastAccessedDate: now,
            location: .desktop,
            destination: nil,
            status: .pending
        )
        let downloadsFile = FileItem(
            path: "/Users/test/Downloads/b.txt",
            sizeInBytes: 1_000,
            creationDate: now,
            modificationDate: now,
            lastAccessedDate: now,
            location: .downloads,
            destination: nil,
            status: .pending
        )

        let manager = FileFilterManager()
        manager.selectedFolder = .desktop

        // When
        manager.updateSourceFiles([desktopFile, downloadsFile])

        // Then: Only the desktop file should be included, even though its path doesn't contain "/Desktop/"
        XCTAssertEqual(manager.filteredFiles.count, 1)
        XCTAssertEqual(manager.filteredFiles.first?.path, desktopFile.path)
    }

    func testDesktopFilter_FallsBackToLegacyPathWhenLocationUnknown() {
        // Given: a legacy file with unknown location but Desktop in the path
        let now = Date()
        let legacyDesktop = FileItem(
            path: "/Users/test/Desktop/legacy.txt",
            sizeInBytes: 1_000,
            creationDate: now,
            modificationDate: now,
            lastAccessedDate: now,
            location: .unknown,
            destination: nil,
            status: .pending
        )
        let legacyDownloads = FileItem(
            path: "/Users/test/Downloads/legacy.txt",
            sizeInBytes: 1_000,
            creationDate: now,
            modificationDate: now,
            lastAccessedDate: now,
            location: .unknown,
            destination: nil,
            status: .pending
        )

        let manager = FileFilterManager()
        manager.selectedFolder = .desktop

        // When
        manager.updateSourceFiles([legacyDesktop, legacyDownloads])

        // Then: Only the Desktop-path file should be included via legacy substring match
        XCTAssertEqual(manager.filteredFiles.count, 1)
        XCTAssertEqual(manager.filteredFiles.first?.path, legacyDesktop.path)
    }

    func testSearchCache_InvalidatesWhenContentMatchedPathsChange() {
        let now = Date()
        let contentOnlyMatch = FileItem(
            path: "/Users/test/Documents/alpha.txt",
            sizeInBytes: 1_000,
            creationDate: now,
            modificationDate: now,
            lastAccessedDate: now,
            location: .documents,
            destination: nil,
            status: .pending
        )
        let unrelated = FileItem(
            path: "/Users/test/Documents/bravo.txt",
            sizeInBytes: 1_000,
            creationDate: now,
            modificationDate: now,
            lastAccessedDate: now,
            location: .documents,
            destination: nil,
            status: .pending
        )

        let manager = FileFilterManager()
        manager.searchText = "needle"

        // Seed cache with a non-empty search result from content matches.
        manager.contentMatchedPaths = [contentOnlyMatch.path]
        manager.applyFilterImmediately(to: [contentOnlyMatch, unrelated])
        XCTAssertEqual(manager.filteredFiles.map(\.path), [contentOnlyMatch.path])

        // Changing content matches should invalidate cached search output.
        manager.contentMatchedPaths = []
        manager.applyFilterImmediately(to: [contentOnlyMatch, unrelated])
        XCTAssertTrue(manager.filteredFiles.isEmpty)
    }

    func testContentTagQuickFilters_UsesAnyMatchSemanticsAcrossSelectedTags() {
        let now = Date()
        let invoice = FileItem(
            path: "/Users/test/Documents/invoice.pdf",
            sizeInBytes: 1_000,
            creationDate: now,
            modificationDate: now,
            lastAccessedDate: now,
            location: .documents,
            destination: nil,
            status: .pending
        )
        let receipt = FileItem(
            path: "/Users/test/Documents/receipt.pdf",
            sizeInBytes: 1_000,
            creationDate: now.addingTimeInterval(1),
            modificationDate: now.addingTimeInterval(1),
            lastAccessedDate: now.addingTimeInterval(1),
            location: .documents,
            destination: nil,
            status: .pending
        )
        let deck = FileItem(
            path: "/Users/test/Documents/deck.pptx",
            sizeInBytes: 1_000,
            creationDate: now.addingTimeInterval(2),
            modificationDate: now.addingTimeInterval(2),
            lastAccessedDate: now.addingTimeInterval(2),
            location: .documents,
            destination: nil,
            status: .pending
        )

        let manager = FileFilterManager()
        manager.contentTagIndex = [
            invoice.path: [.invoice],
            receipt.path: [.receipt],
            deck.path: [.presentation]
        ]
        manager.selectedContentTags = [.invoice, .receipt]

        manager.updateSourceFiles([invoice, receipt, deck])

        XCTAssertEqual(
            Set(manager.visibleFiles.map(\.path)),
            Set([invoice.path, receipt.path])
        )
    }

    func testContentTagQuickFilters_AvailableTagsDeriveFromBaseScopeBeforeTagFiltering() {
        let now = Date()
        let invoice = FileItem(
            path: "/Users/test/Documents/invoice.pdf",
            sizeInBytes: 1_000,
            creationDate: now,
            modificationDate: now,
            lastAccessedDate: now,
            location: .documents,
            destination: nil,
            status: .pending
        )
        let receipt = FileItem(
            path: "/Users/test/Documents/receipt.pdf",
            sizeInBytes: 1_000,
            creationDate: now.addingTimeInterval(1),
            modificationDate: now.addingTimeInterval(1),
            lastAccessedDate: now.addingTimeInterval(1),
            location: .documents,
            destination: nil,
            status: .pending
        )
        let screenshot = FileItem(
            path: "/Users/test/Pictures/screenshot.png",
            sizeInBytes: 1_000,
            creationDate: now.addingTimeInterval(2),
            modificationDate: now.addingTimeInterval(2),
            lastAccessedDate: now.addingTimeInterval(2),
            location: .pictures,
            destination: nil,
            status: .pending
        )

        let manager = FileFilterManager()
        manager.selectedCategory = .documents
        manager.contentTagIndex = [
            invoice.path: [.invoice],
            receipt.path: [.receipt],
            screenshot.path: [.screenshot]
        ]
        manager.selectedContentTags = [.invoice]

        manager.updateSourceFiles([invoice, receipt, screenshot])

        XCTAssertEqual(manager.visibleFiles.map(\.path), [invoice.path])
        XCTAssertEqual(
            Set(manager.availableContentTags),
            Set<MetadataContentTag>([.invoice, .receipt])
        )
    }

    func testExternalReviewScope_FiltersToRequestedPathsOnly() {
        let now = Date()
        let requestedA = FileItem(
            path: "/Users/test/Documents/requested-a.txt",
            sizeInBytes: 1_000,
            creationDate: now,
            modificationDate: now,
            lastAccessedDate: now,
            location: .documents,
            destination: nil,
            status: .pending
        )
        let unrelated = FileItem(
            path: "/Users/test/Documents/unrelated.txt",
            sizeInBytes: 1_000,
            creationDate: now,
            modificationDate: now,
            lastAccessedDate: now,
            location: .documents,
            destination: nil,
            status: .pending
        )
        let requestedB = FileItem(
            path: "/Users/test/Documents/requested-b.txt",
            sizeInBytes: 1_000,
            creationDate: now,
            modificationDate: now,
            lastAccessedDate: now,
            location: .documents,
            destination: nil,
            status: .ready
        )

        let manager = FileFilterManager()
        manager.setExternalReviewPaths([requestedA.path, requestedB.path])
        manager.updateSourceFiles([requestedA, unrelated, requestedB])

        XCTAssertEqual(
            Set(manager.filteredFiles.map(\.path)),
            Set([requestedA.path, requestedB.path])
        )
        XCTAssertTrue(manager.hasExternalReviewScope)

        manager.clearExternalReviewPaths()
        manager.applyFilterImmediately(to: [requestedA, unrelated, requestedB])
        XCTAssertEqual(manager.filteredFiles.count, 3)
        XCTAssertFalse(manager.hasExternalReviewScope)
    }

    func testNestedFolderFilter_ExactFolderOnly() {
        let now = Date()
        let inSelectedFolder = FileItem(
            path: "/Users/test/Desktop/Projects/Forma/readme.md",
            sizeInBytes: 1_000,
            creationDate: now,
            modificationDate: now,
            lastAccessedDate: now,
            location: .desktop,
            scanRootPath: "/Users/test/Desktop",
            relativeParentPath: "Projects/Forma",
            destination: nil,
            status: .pending
        )
        let inChildFolder = FileItem(
            path: "/Users/test/Desktop/Projects/Forma/Assets/icon.png",
            sizeInBytes: 1_000,
            creationDate: now,
            modificationDate: now,
            lastAccessedDate: now,
            location: .desktop,
            scanRootPath: "/Users/test/Desktop",
            relativeParentPath: "Projects/Forma/Assets",
            destination: nil,
            status: .pending
        )
        let outsideFolder = FileItem(
            path: "/Users/test/Desktop/Projects/Other/notes.txt",
            sizeInBytes: 1_000,
            creationDate: now,
            modificationDate: now,
            lastAccessedDate: now,
            location: .desktop,
            scanRootPath: "/Users/test/Desktop",
            relativeParentPath: "Projects/Other",
            destination: nil,
            status: .pending
        )

        let manager = FileFilterManager()
        manager.selectedFolder = .desktop
        manager.selectedRelativeFolderPath = "Projects/Forma"
        manager.includeNestedSubfolders = false

        manager.updateSourceFiles([inSelectedFolder, inChildFolder, outsideFolder])

        XCTAssertEqual(manager.filteredFiles.map(\.path), [inSelectedFolder.path])
    }

    func testNestedFolderFilter_IncludesSubfoldersWhenEnabled() {
        let now = Date()
        let inSelectedFolder = FileItem(
            path: "/Users/test/Desktop/Projects/Forma/readme.md",
            sizeInBytes: 1_000,
            creationDate: now,
            modificationDate: now,
            lastAccessedDate: now,
            location: .desktop,
            scanRootPath: "/Users/test/Desktop",
            relativeParentPath: "Projects/Forma",
            destination: nil,
            status: .pending
        )
        let inChildFolder = FileItem(
            path: "/Users/test/Desktop/Projects/Forma/Assets/icon.png",
            sizeInBytes: 1_000,
            creationDate: now,
            modificationDate: now,
            lastAccessedDate: now,
            location: .desktop,
            scanRootPath: "/Users/test/Desktop",
            relativeParentPath: "Projects/Forma/Assets",
            destination: nil,
            status: .ready
        )
        let outsideFolder = FileItem(
            path: "/Users/test/Desktop/Projects/Other/notes.txt",
            sizeInBytes: 1_000,
            creationDate: now,
            modificationDate: now,
            lastAccessedDate: now,
            location: .desktop,
            scanRootPath: "/Users/test/Desktop",
            relativeParentPath: "Projects/Other",
            destination: nil,
            status: .pending
        )

        let manager = FileFilterManager()
        manager.selectedFolder = .desktop
        manager.selectedRelativeFolderPath = "Projects/Forma"
        manager.includeNestedSubfolders = true

        manager.updateSourceFiles([inSelectedFolder, inChildFolder, outsideFolder])

        XCTAssertEqual(
            Set(manager.filteredFiles.map(\.path)),
            Set([inSelectedFolder.path, inChildFolder.path])
        )
    }

    func testNestedFolderContext_SuppressesReadyFilesAlreadyTargetingSelectedFolder() {
        let now = Date()
        let alreadyTargetingScope = FileItem(
            path: "/Users/test/Desktop/Screenshots/shot-1.png",
            sizeInBytes: 2_000,
            creationDate: now,
            modificationDate: now,
            lastAccessedDate: now,
            location: .desktop,
            scanRootPath: "/Users/test/Desktop",
            relativeParentPath: "Screenshots",
            destination: .folder(bookmark: Data([1]), displayName: "Pictures/Screenshots"),
            status: .ready
        )
        let differentDestination = FileItem(
            path: "/Users/test/Desktop/Screenshots/shot-2.png",
            sizeInBytes: 2_000,
            creationDate: now,
            modificationDate: now,
            lastAccessedDate: now,
            location: .desktop,
            scanRootPath: "/Users/test/Desktop",
            relativeParentPath: "Screenshots",
            destination: .folder(bookmark: Data([2]), displayName: "Pictures/Archive"),
            status: .ready
        )

        let manager = FileFilterManager()
        manager.selectedFolder = .desktop
        manager.selectedRelativeFolderPath = "Screenshots"
        manager.includeNestedSubfolders = false

        manager.updateSourceFiles([alreadyTargetingScope, differentDestination])

        // Base folder-scope filtering should still include both.
        XCTAssertEqual(Set(manager.filteredFiles.map(\.path)), Set([alreadyTargetingScope.path, differentDestination.path]))

        // But actionable caches should hide the one already targeting the selected nested scope.
        XCTAssertEqual(manager.cachedNeedsReviewCount, 1)
        XCTAssertEqual(manager.cachedReviewableFiles.map(\.path), [differentDestination.path])
        XCTAssertEqual(manager.visibleFiles.map(\.path), [differentDestination.path])
    }

    func testNestedFolderContext_DoesNotSuppressPendingFilesWithoutDestination() {
        let now = Date()
        let pendingWithoutDestination = FileItem(
            path: "/Users/test/Desktop/Screenshots/shot-3.png",
            sizeInBytes: 2_000,
            creationDate: now,
            modificationDate: now,
            lastAccessedDate: now,
            location: .desktop,
            scanRootPath: "/Users/test/Desktop",
            relativeParentPath: "Screenshots",
            destination: nil,
            status: .pending
        )

        let manager = FileFilterManager()
        manager.selectedFolder = .desktop
        manager.selectedRelativeFolderPath = "Screenshots"
        manager.includeNestedSubfolders = false

        manager.updateSourceFiles([pendingWithoutDestination])

        XCTAssertEqual(manager.cachedNeedsReviewCount, 1)
        XCTAssertEqual(manager.cachedReviewableFiles.map(\.path), [pendingWithoutDestination.path])
        XCTAssertEqual(manager.visibleFiles.map(\.path), [pendingWithoutDestination.path])
    }
}
