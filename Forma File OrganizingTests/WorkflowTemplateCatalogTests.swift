import XCTest
@testable import Forma_File_Organizing

final class WorkflowTemplateCatalogTests: XCTestCase {
    func testBuiltInCatalog_ExposesStableWorkflowTemplateIDs() {
        let templates = WorkflowTemplateCatalog.shippedTemplates
        let stableIDs = Set(templates.map(\.id))

        XCTAssertEqual(stableIDs.count, 3)
        XCTAssertEqual(
            stableIDs,
            Set([
                "builtin.workflow.receipts.v1",
                "builtin.workflow.screenshots.v1",
                "builtin.workflow.project-drop.v1"
            ])
        )
    }

    func testBuiltInCatalog_AllTemplatesUseRenameTagMoveShape() {
        let templates = WorkflowTemplateCatalog.shippedTemplates

        XCTAssertFalse(templates.isEmpty)
        for template in templates {
            XCTAssertEqual(template.allowedActions, [.rename, .tag, .move])
        }
    }
}
