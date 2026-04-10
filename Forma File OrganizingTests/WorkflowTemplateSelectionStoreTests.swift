import XCTest
@testable import Forma_File_Organizing

final class WorkflowTemplateSelectionStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "WorkflowTemplateSelectionStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        if let suiteName {
            defaults.removePersistentDomain(forName: suiteName)
        }
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testSelectedTemplateID_PersistsValidTemplateIDs() {
        let store = WorkflowTemplateSelectionStore(defaults: defaults)

        store.selectedTemplateID = BuiltInWorkflowTemplate.StableID.receipts

        XCTAssertEqual(store.selectedTemplateID, BuiltInWorkflowTemplate.StableID.receipts)
    }

    func testSelectedTemplateID_DropsInvalidStoredValues() {
        defaults.set("builtin.workflow.invalid", forKey: WorkflowTemplateSelectionStore.Keys.manualTemplateID)
        let store = WorkflowTemplateSelectionStore(defaults: defaults)

        XCTAssertNil(store.selectedTemplateID)
        XCTAssertNil(defaults.string(forKey: WorkflowTemplateSelectionStore.Keys.manualTemplateID))
    }

    func testResolvedTemplateID_FallsBackToPersistedSelectionWhenExplicitTemplateMissing() {
        let store = WorkflowTemplateSelectionStore(defaults: defaults)
        store.selectedTemplateID = BuiltInWorkflowTemplate.StableID.projectDrop

        XCTAssertEqual(
            store.resolvedTemplateID(explicitTemplateID: nil),
            BuiltInWorkflowTemplate.StableID.projectDrop
        )
    }
}
