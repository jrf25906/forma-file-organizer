import XCTest
@testable import Forma_File_Organizing

@MainActor
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

    func testWorkflowDispositionText_UsesMetadataUpdatedForMetadataRows() {
        let view = WorkflowRunDetailSheet(runID: UUID())
        let action = WorkflowFileActionRecord(
            runID: UUID(),
            fileIdentity: "resource|diskA|file-123",
            sourcePath: "/Users/example/Projects/Product Spec.pdf",
            destinationPath: "/Users/example/Projects/Product Spec.pdf",
            disposition: .pending,
            metadataDelta: WorkflowFileMetadataDelta(
                addedTags: ["project"],
                resultingProjectAssociation: "Alpha"
            )
        )

        XCTAssertEqual(view.workflowDispositionText(for: action), "Metadata updated")
    }

    func testMetadataSummaryText_DescribesAddedTagsProjectAndWorkflowStatus() {
        let view = WorkflowRunDetailSheet(runID: UUID())
        let action = WorkflowFileActionRecord(
            runID: UUID(),
            fileIdentity: "resource|diskA|file-123",
            sourcePath: "/Users/example/Projects/Product Spec.pdf",
            destinationPath: "/Users/example/Projects/Product Spec.pdf",
            disposition: .pending,
            metadataDelta: WorkflowFileMetadataDelta(
                addedTags: ["project", "intake"],
                resultingProjectAssociation: "Alpha",
                resultingWorkflowStatus: .organized
            )
        )

        let summary = view.metadataSummaryText(for: action)

        XCTAssertEqual(
            summary,
            "Added tags: project, intake • Project: Alpha • Workflow: Organized"
        )
    }

    func testMetadataSummaryText_DescribesRollbackMetadataChanges() {
        let view = WorkflowRunDetailSheet(runID: UUID())
        let action = WorkflowFileActionRecord(
            runID: UUID(),
            fileIdentity: "resource|diskA|file-123",
            sourcePath: "/Users/example/Projects/Product Spec.pdf",
            destinationPath: "/Users/example/Projects/Product Spec.pdf",
            disposition: .restored,
            metadataDelta: WorkflowFileMetadataDelta(
                removedTags: ["project", "intake"],
                previousProjectAssociation: "Alpha",
                resultingProjectAssociation: "Beta",
                previousWorkflowStatus: .organized,
                resultingWorkflowStatus: .queued
            )
        )

        let summary = view.metadataSummaryText(for: action)

        XCTAssertEqual(
            summary,
            "Removed tags: project, intake • Project: Beta • Workflow: Queued"
        )
    }

    func testMetadataSummaryText_DescribesClearedRollbackMetadataChanges() {
        let view = WorkflowRunDetailSheet(runID: UUID())
        let action = WorkflowFileActionRecord(
            runID: UUID(),
            fileIdentity: "resource|diskA|file-123",
            sourcePath: "/Users/example/Projects/Product Spec.pdf",
            destinationPath: "/Users/example/Projects/Product Spec.pdf",
            disposition: .restored,
            metadataDelta: WorkflowFileMetadataDelta(
                removedTags: ["project"],
                previousProjectAssociation: "Alpha",
                previousWorkflowStatus: .organized
            )
        )

        let summary = view.metadataSummaryText(for: action)

        XCTAssertEqual(
            summary,
            "Removed tags: project • Project cleared • Workflow cleared"
        )
    }
}
