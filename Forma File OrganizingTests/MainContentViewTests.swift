import XCTest
@testable import Forma_File_Organizing

@MainActor
final class MainContentViewTests: XCTestCase {

    func testRecoverToReady_ClearsLastOrganizeError() {
        let file = FileItem(
            path: "/test/failed.pdf",
            sizeInBytes: 2_048,
            creationDate: Date(),
            destination: .mockFolder("Documents/Old"),
            status: .pending
        )
        file.lastOrganizeError = "Destination no longer exists"

        FileRecoveryState.recoverToReady(file, destination: .mockFolder("Documents/New"))

        XCTAssertEqual(file.destination?.displayName, "Documents/New")
        XCTAssertEqual(file.status, .ready)
        XCTAssertNil(file.lastOrganizeError)
    }

    func testClearErrorIfRecovered_OnlyClearsReadyFilesWithDestination() {
        let recovered = FileItem(
            path: "/test/recovered.pdf",
            sizeInBytes: 2_048,
            creationDate: Date(),
            destination: .mockFolder("Documents/Ready"),
            status: .ready
        )
        recovered.lastOrganizeError = "Previous failure"

        let stillFailed = FileItem(
            path: "/test/still-failed.pdf",
            sizeInBytes: 2_048,
            creationDate: Date(),
            destination: nil,
            status: .pending
        )
        stillFailed.lastOrganizeError = "Still failing"

        FileRecoveryState.clearErrorIfRecovered(recovered)
        FileRecoveryState.clearErrorIfRecovered(stillFailed)

        XCTAssertNil(recovered.lastOrganizeError)
        XCTAssertEqual(stillFailed.lastOrganizeError, "Still failing")
    }

    func testClearErrorIfRecovered_ClearsSameDestinationRuleRecoveryWhenFileIsReady() {
        let destination = Destination.mockFolder("Documents/Ready")
        let file = FileItem(
            path: "/test/recovered-again.pdf",
            sizeInBytes: 2_048,
            creationDate: Date(),
            destination: destination,
            status: .ready
        )
        file.lastOrganizeError = "Previous move failed"

        FileRecoveryState.clearErrorIfRecovered(
            file,
            previousDestination: destination,
            previousStatus: .ready,
            recoveredDestination: destination
        )

        XCTAssertNil(file.lastOrganizeError)
    }

    func testClearErrorIfRecovered_DoesNotClearUnresolvedErrorWhenFileIsNotReady() {
        let destination = Destination.mockFolder("Documents/Ready")
        let file = FileItem(
            path: "/test/still-failing.pdf",
            sizeInBytes: 2_048,
            creationDate: Date(),
            destination: destination,
            status: .pending
        )
        file.lastOrganizeError = "Move still failing"

        FileRecoveryState.clearErrorIfRecovered(
            file,
            previousDestination: destination,
            previousStatus: .ready,
            recoveredDestination: destination
        )

        XCTAssertEqual(file.lastOrganizeError, "Move still failing")
    }
}
