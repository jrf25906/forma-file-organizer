import XCTest
@testable import Forma_File_Organizing

final class MenuBarWorkflowGuidanceTests: XCTestCase {
    func testMake_ReturnsTemplateSelectionWarningWhenWorkflowTemplateIsMissing() {
        let guidance = MenuBarWorkflowActionGuidance.make(
            workflowEngineEnabled: true,
            selectedTemplateID: nil,
            preview: nil
        )

        XCTAssertEqual(guidance, .warning("Choose a workflow template to organize from the menu bar."))
    }

    func testMake_ReturnsBlockedWarningWhenAllSelectedFilesAreBlocked() {
        let guidance = MenuBarWorkflowActionGuidance.make(
            workflowEngineEnabled: true,
            selectedTemplateID: BuiltInWorkflowTemplate.StableID.receipts,
            preview: WorkflowTemplateSimulationPreview(
                templateID: BuiltInWorkflowTemplate.StableID.receipts,
                templateDisplayName: "Receipt Intake",
                selectedFileCount: 2,
                readyToRunCount: 0,
                blockedCount: 2,
                exampleFileNames: ["receipt-1.pdf", "receipt-2.pdf"]
            )
        )

        XCTAssertEqual(guidance, .warning("All selected files are blocked in workflow simulation."))
    }

    func testMake_ReturnsPartialWarningWhenSomeFilesAreBlocked() {
        let guidance = MenuBarWorkflowActionGuidance.make(
            workflowEngineEnabled: true,
            selectedTemplateID: BuiltInWorkflowTemplate.StableID.receipts,
            preview: WorkflowTemplateSimulationPreview(
                templateID: BuiltInWorkflowTemplate.StableID.receipts,
                templateDisplayName: "Receipt Intake",
                selectedFileCount: 3,
                readyToRunCount: 2,
                blockedCount: 1,
                exampleFileNames: ["receipt-1.pdf", "receipt-2.pdf"]
            )
        )

        XCTAssertEqual(guidance, .warning("1 selected file is blocked in simulation. Forma will run the ready items only."))
    }
}
