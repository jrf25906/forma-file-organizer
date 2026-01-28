import XCTest
@testable import Forma_File_Organizing

final class FileMetadataTests: XCTestCase {
    func testPreferredInitializerStoresDestination() {
        let destination = Destination.mockFolder("Work")
        let metadata = FileMetadata(
            path: "/tmp/work/report.pdf",
            sizeInBytes: 2048,
            creationDate: Date(),
            destination: destination,
            status: .pending
        )

        XCTAssertEqual(metadata.destination?.displayName, "Work")
        XCTAssertEqual(metadata.name, "report.pdf")
    }

    func testPreferredInitializerMaintainsDestination() {
        let destination = Destination.mockFolder("Photos")
        let metadata = FileMetadata(
            path: "/tmp/photos/image.jpg",
            sizeInBytes: 2_048_000,
            creationDate: Date(),
            destination: destination,
            status: .ready
        )

        XCTAssertEqual(metadata.destination?.displayName, "Photos")
        XCTAssertEqual(metadata.status, .ready)
    }
}
