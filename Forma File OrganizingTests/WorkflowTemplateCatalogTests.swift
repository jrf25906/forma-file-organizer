import XCTest
@testable import Forma_File_Organizing

final class WorkflowTemplateCatalogTests: XCTestCase {
    func testBuiltInCatalog_ExposesStableWorkflowTemplateIDs() {
        let templates = WorkflowTemplateCatalog.shippedTemplates
        let stableIDs = Set(templates.map(\.id))

        XCTAssertEqual(stableIDs.count, 4)
        XCTAssertEqual(
            stableIDs,
            Set([
                "builtin.workflow.receipts.v1",
                "builtin.workflow.screenshots.v1",
                "builtin.workflow.project-drop.v1",
                "builtin.workflow.dated-archive.v1"
            ])
        )
    }

    func testBuiltInCatalog_UsesExpectedActionShapePerTemplate() throws {
        let templatesByID = Dictionary(
            uniqueKeysWithValues: WorkflowTemplateCatalog.shippedTemplates.map { ($0.id, $0) }
        )

        XCTAssertEqual(
            try XCTUnwrap(templatesByID[BuiltInWorkflowTemplate.StableID.receipts]).allowedActions,
            [.rename, .tag, .move]
        )
        XCTAssertEqual(
            try XCTUnwrap(templatesByID[BuiltInWorkflowTemplate.StableID.screenshots]).allowedActions,
            [.rename, .tag, .move]
        )
        XCTAssertEqual(
            try XCTUnwrap(templatesByID[BuiltInWorkflowTemplate.StableID.projectDrop]).allowedActions,
            [.rename, .tag, .projectAssociation, .workflowStatus, .notesSummary, .move, .notify]
        )
        XCTAssertEqual(
            try XCTUnwrap(templatesByID[BuiltInWorkflowTemplate.StableID.datedArchive]).allowedActions,
            [.rename, .tag, .workflowStatus, .move]
        )
    }

    func testBuiltInCatalog_OnlyProjectDropUsesTrustedScopeNotificationPolicy() {
        let templates = WorkflowTemplateCatalog.shippedTemplates
        let policiesByID = Dictionary(
            uniqueKeysWithValues: templates.map { template in
                let policy = Mirror(reflecting: template).children
                    .first(where: { $0.label == "notificationPolicy" })
                    .map { String(describing: $0.value) }
                return (template.id, policy)
            }
        )

        XCTAssertEqual(policiesByID[BuiltInWorkflowTemplate.StableID.receipts] ?? nil, "never")
        XCTAssertEqual(policiesByID[BuiltInWorkflowTemplate.StableID.screenshots] ?? nil, "never")
        XCTAssertEqual(policiesByID[BuiltInWorkflowTemplate.StableID.projectDrop] ?? nil, "trustedScopeOnly")
        XCTAssertEqual(policiesByID[BuiltInWorkflowTemplate.StableID.datedArchive] ?? nil, "never")
    }
}
