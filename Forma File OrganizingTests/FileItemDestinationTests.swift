import XCTest
@testable import Forma_File_Organizing

final class FileItemDestinationTests: XCTestCase {
    func testInitializerStoresDestination() {
        let destination = Destination.mockFolder("Documents")
        let item = FileItem(
            path: "/tmp/test.pdf",
            sizeInBytes: 1_024_000,
            creationDate: Date(),
            destination: destination,
            status: .pending
        )

        XCTAssertEqual(item.destination?.displayName, "Documents")
    }

    func testSettingDestinationUpdatesComputedProperty() {
        let item = FileItem(
            path: "/tmp/test.pdf",
            sizeInBytes: 1_024_000,
            creationDate: Date(),
            destination: nil,
            status: .pending
        )

        item.destination = Destination.mockFolder("Archive")
        XCTAssertEqual(item.destination?.displayName, "Archive")

        item.destination = Destination.trash
        if case .trash = item.destination {
            // success
        } else {
            XCTFail("Destination should be .trash")
        }

        item.destination = nil
        XCTAssertNil(item.destination)
    }
}
