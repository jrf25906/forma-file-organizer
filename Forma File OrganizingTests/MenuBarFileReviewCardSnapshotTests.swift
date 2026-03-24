import XCTest
@testable import Forma_File_Organizing

@MainActor
final class MenuBarFileReviewCardSnapshotTests: XCTestCase {
    func testSnapshotForFileWithDestinationUsesInlineDestinationSummary() {
        let file = FileItem(
            path: "/Users/test/Downloads/Quarterly Report.pdf",
            sizeInBytes: 3_200_000,
            creationDate: Date(),
            destination: .mockFolder("Documents/Finance"),
            status: .ready
        )
        file.matchReason = "Matched by quarterly finance rule"

        let snapshot = MenuBarFileReviewCard.Snapshot(file: file)

        XCTAssertEqual(snapshot.destinationTitle, "Destination")
        XCTAssertEqual(snapshot.destinationName, "Documents/Finance")
        XCTAssertEqual(snapshot.destinationDetail, "Ready to move now")
        XCTAssertEqual(snapshot.destinationIconName, "arrow.turn.down.right")
        XCTAssertEqual(snapshot.matchReason, "Matched by quarterly finance rule")
    }

    func testSnapshotForFileWithoutDestinationKeepsDestinationSectionInline() {
        let file = FileItem(
            path: "/Users/test/Desktop/Rive Early Access.zip",
            sizeInBytes: 64_200_000,
            creationDate: Date(),
            destination: nil,
            status: .pending
        )

        let snapshot = MenuBarFileReviewCard.Snapshot(file: file)

        XCTAssertEqual(snapshot.destinationTitle, "Destination")
        XCTAssertEqual(snapshot.destinationName, "No destination assigned")
        XCTAssertEqual(snapshot.destinationDetail, "Set a destination in the main app to organize this file.")
        XCTAssertEqual(snapshot.destinationIconName, "arrow.turn.down.right")
        XCTAssertNil(snapshot.matchReason)
    }
}
