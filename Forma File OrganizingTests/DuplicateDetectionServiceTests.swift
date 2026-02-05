import XCTest
@testable import Forma_File_Organizing

@MainActor
final class DuplicateDetectionServiceTests: XCTestCase {
    func testDetectDuplicates_FindsExactDuplicatesByHash() throws {
        let tempDir = try TemporaryDirectory()
        defer { tempDir.cleanup() }

        let payload = String(repeating: "A", count: 2_048)
        let file1URL = try tempDir.createFile(name: "copy-a.txt", contents: payload)
        let file2URL = try tempDir.createFile(name: "copy-b.txt", contents: payload)
        let uniqueURL = try tempDir.createFile(name: "unique.txt", contents: String(repeating: "B", count: 2_048))

        let now = Date()
        let files = [
            FileItem(path: file1URL.path, sizeInBytes: 2_048, creationDate: now, modificationDate: now, lastAccessedDate: now),
            FileItem(path: file2URL.path, sizeInBytes: 2_048, creationDate: now, modificationDate: now, lastAccessedDate: now),
            FileItem(path: uniqueURL.path, sizeInBytes: 2_048, creationDate: now, modificationDate: now, lastAccessedDate: now)
        ]

        let groups = DuplicateDetectionService().detectDuplicates(in: files)
        let exactGroup = groups.first { $0.type == .exactDuplicate }

        XCTAssertNotNil(exactGroup)
        XCTAssertEqual(Set(exactGroup?.files.map(\.path) ?? []), Set([file1URL.path, file2URL.path]))
    }

    func testDetectDuplicates_FindsVersionSeries() {
        let now = Date()
        let files = [
            FileItem(path: "/Users/test/Documents/Proposal_v1.docx", sizeInBytes: 2_048, creationDate: now),
            FileItem(path: "/Users/test/Documents/Proposal_v2.docx", sizeInBytes: 2_048, creationDate: now),
            FileItem(path: "/Users/test/Documents/Proposal_v3.docx", sizeInBytes: 2_048, creationDate: now),
            FileItem(path: "/Users/test/Documents/Unrelated.docx", sizeInBytes: 2_048, creationDate: now)
        ]

        let groups = DuplicateDetectionService().detectDuplicates(in: files)
        let versionGroup = groups.first { $0.type == .versionSeries }

        XCTAssertNotNil(versionGroup)
        XCTAssertEqual(versionGroup?.files.count, 3)
    }

    func testDetectDuplicates_FindsNearDuplicatesWithMinorNameDifference() {
        let now = Date()
        let files = [
            FileItem(path: "/Users/test/Documents/meeting-notes.txt", sizeInBytes: 2_048, creationDate: now),
            FileItem(path: "/Users/test/Documents/meeting-note.txt", sizeInBytes: 2_048, creationDate: now),
            FileItem(path: "/Users/test/Documents/archive.txt", sizeInBytes: 2_048, creationDate: now)
        ]

        let groups = DuplicateDetectionService().detectDuplicates(in: files)
        let nearGroup = groups.first { $0.type == .nearDuplicate }

        XCTAssertNotNil(nearGroup)
        XCTAssertEqual(Set(nearGroup?.files.map(\.path) ?? []), Set([
            "/Users/test/Documents/meeting-notes.txt",
            "/Users/test/Documents/meeting-note.txt"
        ]))
    }
}
