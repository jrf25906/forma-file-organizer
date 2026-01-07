import XCTest
@testable import Forma_File_Organizing

final class FileItemDestinationTests: XCTestCase {
    func testInitializerStoresDestination() {
        let destination = Destination.mockFolder("Documents")
        let item = FileItem(
            name: "test.pdf",
            fileExtension: "pdf",
            size: "1 MB",
            sizeInBytes: 1_024_000,
            creationDate: Date(),
            path: "/tmp/test.pdf",
            destination: destination,
            status: .pending
        )

        XCTAssertEqual(item.destination?.displayName, "Documents")
    }

    func testSettingDestinationUpdatesComputedProperty() {
        let item = FileItem(
            name: "test.pdf",
            fileExtension: "pdf",
            size: "1 MB",
            sizeInBytes: 1_024_000,
            creationDate: Date(),
            path: "/tmp/test.pdf",
            destination: nil,
            status: .pending
        )

        item.destination = .mockFolder("Archive")
        XCTAssertEqual(item.destination?.displayName, "Archive")

        item.destination = .trash
        if case .trash = item.destination {
            // success
        } else {
            XCTFail("Destination should be .trash")
        }

        item.destination = nil
        XCTAssertNil(item.destination)
    }
}
