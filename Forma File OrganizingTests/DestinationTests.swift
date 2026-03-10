import XCTest
@testable import Forma_File_Organizing

final class DestinationTests: XCTestCase {
    func testFolderFactoryCreatesResolvableDestination() throws {
        let tempDir = try TemporaryDirectory()
        defer { tempDir.cleanup() }

        let destination = try Destination.folder(from: tempDir.url)

        XCTAssertEqual(destination.displayName, tempDir.url.lastPathComponent)
        let resolved = destination.resolve()
        XCTAssertEqual(
            resolved?.url.resolvingSymlinksInPath().path,
            tempDir.url.resolvingSymlinksInPath().path
        )
        XCTAssertEqual(resolved?.isStale, false)
        XCTAssertEqual(destination.bookmarkData?.isEmpty, false)
    }

    func testValidateDetectsMissingFolder() throws {
        let tempDir = try TemporaryDirectory()
        let destination = try Destination.folder(from: tempDir.url)
        tempDir.cleanup()

        let result = destination.validate()
        switch result {
        case .invalid(let reason):
            XCTAssertTrue(reason.contains("no longer exists") || reason.contains("Cannot access"))
        default:
            XCTFail("Expected invalid result when folder is missing")
        }
    }

    func testCodableRoundTrip() throws {
        let folderDestination = Destination.mockFolder("Docs")
        let trashDestination = Destination.trash

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let encodedFolder = try encoder.encode(folderDestination)
        let encodedTrash = try encoder.encode(trashDestination)

        let decodedFolder = try decoder.decode(Destination.self, from: encodedFolder)
        let decodedTrash = try decoder.decode(Destination.self, from: encodedTrash)

        XCTAssertEqual(decodedFolder, folderDestination)
        XCTAssertEqual(decodedTrash, trashDestination)
    }

    func testResolverMaterializesPlaceholderWithinBookmarkedRoot() throws {
        let tempDir = try TemporaryDirectory()
        defer { tempDir.cleanup() }

        let documentsRoot = try Destination.folder(from: tempDir.url, displayName: "Documents")
        let store = InMemoryBookmarkStore()
        try store.saveBookmark(
            try XCTUnwrap(documentsRoot.bookmarkData),
            forKey: FormaConfig.Security.documentsBookmarkKey
        )

        try BookmarkStoreProvider.$override.withValue(store) {
            let placeholder = Destination.folder(bookmark: Data(), displayName: "Documents/Areas/Health")
            let resolved = try XCTUnwrap(DestinationResolver().materializeForExplicitSave(placeholder))
            let resolvedURL = try XCTUnwrap(resolved.resolve()?.url)

            XCTAssertEqual(resolved.displayName, "Documents/Areas/Health")
            XCTAssertEqual(
                resolvedURL.standardizedFileURL.path,
                tempDir.url.appendingPathComponent("Areas/Health").standardizedFileURL.path
            )
            XCTAssertTrue(FileManager.default.fileExists(atPath: resolvedURL.path))
        }
    }

    func testResolverNormalizesLegacyAbsoluteHomePathToCanonicalDisplayName() throws {
        let tempDir = try TemporaryDirectory()
        defer { tempDir.cleanup() }

        let documentsRoot = try Destination.folder(from: tempDir.url, displayName: "Documents")
        let store = InMemoryBookmarkStore()
        try store.saveBookmark(
            try XCTUnwrap(documentsRoot.bookmarkData),
            forKey: FormaConfig.Security.documentsBookmarkKey
        )

        let realHomePath = getpwuid(getuid()).map { String(cString: $0.pointee.pw_dir) }
            ?? NSHomeDirectory()
        let legacyPath = URL(fileURLWithPath: realHomePath)
            .appendingPathComponent("Documents/Areas/Health")
            .path

        try BookmarkStoreProvider.$override.withValue(store) {
            let placeholder = Destination.folder(bookmark: Data(), displayName: legacyPath)
            let resolved = try XCTUnwrap(DestinationResolver().materializeForExplicitSave(placeholder))
            let resolvedURL = try XCTUnwrap(resolved.resolve()?.url)

            XCTAssertEqual(resolved.displayName, "Documents/Areas/Health")
            XCTAssertEqual(
                resolvedURL.standardizedFileURL.path,
                tempDir.url.appendingPathComponent("Areas/Health").standardizedFileURL.path
            )
        }
    }
}
