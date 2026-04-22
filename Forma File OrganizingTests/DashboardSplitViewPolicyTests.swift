import XCTest
@testable import Forma_File_Organizing

final class DashboardSplitLayoutConfigurationTests: XCTestCase {
    func testVisibleInspectorUsesThreeColumnArrangement() {
        let configuration = DashboardSplitLayoutConfiguration(
            workspaceDestination: .home,
            isInspectorVisible: true
        )

        XCTAssertEqual(configuration.arrangement, .sidebarContentAndInspector)
        XCTAssertTrue(configuration.usesThreeColumnLayout)
        XCTAssertEqual(configuration.mode, "threeColumn")
    }

    func testHiddenInspectorUsesSidebarAndContentArrangement() {
        let configuration = DashboardSplitLayoutConfiguration(
            workspaceDestination: .home,
            isInspectorVisible: false
        )

        XCTAssertEqual(configuration.arrangement, .sidebarAndContent)
        XCTAssertFalse(configuration.usesThreeColumnLayout)
        XCTAssertEqual(configuration.mode, "twoColumn")
    }

    func testDestinationWorkspaceUsesSidebarAndWorkspaceArrangement() {
        let configuration = DashboardSplitLayoutConfiguration(
            workspaceDestination: .analytics,
            isInspectorVisible: false
        )

        XCTAssertEqual(configuration.arrangement, .sidebarAndWorkspace)
        XCTAssertFalse(configuration.usesThreeColumnLayout)
        XCTAssertEqual(configuration.mode, "twoColumn")
    }
}
