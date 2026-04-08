import XCTest
@testable import Forma_File_Organizing

@MainActor
final class WorkflowRollbackCoordinatorTests: XCTestCase {
    func testRollbackCoordinator_RollsBackInStrictReverseExecutionOrder() async throws {
        let coordinator = WorkflowRollbackCoordinator()
        var log: [String] = []

        let actions = [
            WorkflowCompensationAction(
                stepKind: .rename,
                fileIdentity: "file-1",
                sourcePath: "/tmp/working-1",
                destinationPath: "/tmp/source-1",
                apply: { log.append("rename-1") }
            ),
            WorkflowCompensationAction(
                stepKind: .tag,
                fileIdentity: "file-1",
                sourcePath: "/tmp/working-1",
                destinationPath: "/tmp/working-1",
                apply: { log.append("tag-1") }
            ),
            WorkflowCompensationAction(
                stepKind: .move,
                fileIdentity: "file-1",
                sourcePath: "/tmp/destination-1",
                destinationPath: "/tmp/working-1",
                apply: { log.append("move-1") }
            ),
            WorkflowCompensationAction(
                stepKind: .rename,
                fileIdentity: "file-2",
                sourcePath: "/tmp/working-2",
                destinationPath: "/tmp/source-2",
                apply: { log.append("rename-2") }
            ),
            WorkflowCompensationAction(
                stepKind: .tag,
                fileIdentity: "file-2",
                sourcePath: "/tmp/working-2",
                destinationPath: "/tmp/working-2",
                apply: { log.append("tag-2") }
            ),
            WorkflowCompensationAction(
                stepKind: .move,
                fileIdentity: "file-2",
                sourcePath: "/tmp/destination-2",
                destinationPath: "/tmp/working-2",
                apply: { log.append("move-2") }
            )
        ]

        let outcomes = await coordinator.rollback(actions)

        XCTAssertEqual(log, ["move-2", "tag-2", "rename-2", "move-1", "tag-1", "rename-1"])
        XCTAssertEqual(outcomes.count, 6)
        XCTAssertTrue(outcomes.allSatisfy(\.succeeded))
    }

    func testRollbackCoordinator_ContinuesAfterIndividualCompensationFailure() async throws {
        struct InjectedFailure: Error {}

        let coordinator = WorkflowRollbackCoordinator()
        var log: [String] = []

        let outcomes = await coordinator.rollback([
            WorkflowCompensationAction(
                stepKind: .move,
                fileIdentity: "file-1",
                sourcePath: "/tmp/destination",
                destinationPath: "/tmp/working",
                apply: { throw InjectedFailure() }
            ),
            WorkflowCompensationAction(
                stepKind: .rename,
                fileIdentity: "file-1",
                sourcePath: "/tmp/working",
                destinationPath: "/tmp/source",
                apply: { log.append("rename") }
            )
        ])

        XCTAssertEqual(log, ["rename"])
        XCTAssertEqual(outcomes.count, 2)
        XCTAssertTrue(outcomes[0].succeeded)
        XCTAssertFalse(outcomes[1].succeeded)
    }
}
