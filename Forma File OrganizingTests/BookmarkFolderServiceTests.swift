import XCTest
@testable import Forma_File_Organizing

@MainActor
final class BookmarkFolderServiceTests: XCTestCase {
    private let downloadsEnabledKey = "BookmarkFolder.isEnabled.\(FormaConfig.Security.downloadsBookmarkKey)"
    private let downloadsExcludedKey = "BookmarkFolder.excludeAutomation.\(FormaConfig.Security.downloadsBookmarkKey)"

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: downloadsEnabledKey)
        UserDefaults.standard.removeObject(forKey: downloadsExcludedKey)
        super.tearDown()
    }

    func testSaveBookmarkPublishesFolderAndPreservesStoredPreferences() throws {
        let store = InMemoryBookmarkStore()
        let bookmarkData = Data([0x10, 0x20, 0x30])

        UserDefaults.standard.set(false, forKey: downloadsEnabledKey)
        UserDefaults.standard.set(true, forKey: downloadsExcludedKey)

        try BookmarkStoreProvider.$override.withValue(store) {
            let service = BookmarkFolderService()

            XCTAssertFalse(service.hasAccess(to: .downloads))

            service.saveBookmark(bookmarkData, for: .downloads)

            let folder = try XCTUnwrap(service.folder(for: .downloads))
            XCTAssertEqual(store.loadBookmark(forKey: FormaConfig.Security.downloadsBookmarkKey), bookmarkData)
            XCTAssertEqual(service.availableFolders.map(\.folderType), [.downloads])
            XCTAssertFalse(folder.isEnabled)
            XCTAssertTrue(folder.isExcludedFromAutomation)
        }
    }
}
