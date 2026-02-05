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
}
