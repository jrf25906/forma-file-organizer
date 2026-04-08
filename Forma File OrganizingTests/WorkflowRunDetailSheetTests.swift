import XCTest
@testable import Forma_File_Organizing

final class WorkflowRunDetailSheetTests: XCTestCase {

    func testStepRunTitle_DropsOpaqueRollbackIdentityFragments() {
        let view = WorkflowRunDetailSheet(runID: UUID())

        let title = view.stepRunTitle("rollback|move|resource|diskA|file-123")

        XCTAssertEqual(title, "Move")
    }

    func testWorkflowActionTitle_PrefersHumanReadablePathForRollbackRows() {
        let view = WorkflowRunDetailSheet(runID: UUID())
        let runID = UUID()
        let stepRun = WorkflowStepRunRecord(
            runID: runID,
            stepID: "rollback|move|resource|diskA|file-123",
            status: .succeeded
        )
        let action = WorkflowFileActionRecord(
            runID: runID,
            stepRunID: stepRun.id,
            fileIdentity: "resource|diskA|file-123",
            sourcePath: "/Users/example/Receipts/April Receipt.pdf",
            destinationPath: "/Users/example/Inbox/April Receipt.pdf",
            disposition: .restored
        )

        let title = view.workflowActionTitle(for: action, using: [stepRun.id: stepRun])

        XCTAssertEqual(title, "Move • April Receipt.pdf")
    }
}
