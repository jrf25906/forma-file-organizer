import XCTest
@testable import Forma_File_Organizing

final class DashboardSplitLayoutConfigurationTests: XCTestCase {
    func testVisibleInspectorUsesThreeColumnArrangement() {
        let configuration = DashboardSplitLayoutConfiguration(
            isInspectorVisible: true,
            showsAnalyticsAsPrimaryDetail: false
        )

        XCTAssertEqual(configuration.arrangement, .sidebarContentAndInspector)
        XCTAssertTrue(configuration.usesThreeColumnLayout)
        XCTAssertEqual(configuration.mode, "threeColumn")
    }

    func testHiddenInspectorUsesSidebarAndContentArrangement() {
        let configuration = DashboardSplitLayoutConfiguration(
            isInspectorVisible: false,
            showsAnalyticsAsPrimaryDetail: false
        )

        XCTAssertEqual(configuration.arrangement, .sidebarAndContent)
        XCTAssertFalse(configuration.usesThreeColumnLayout)
        XCTAssertEqual(configuration.mode, "twoColumn")
    }

    func testAnalyticsKeepsSidebarAndRightPanelArrangement() {
        let configuration = DashboardSplitLayoutConfiguration(
            isInspectorVisible: false,
            showsAnalyticsAsPrimaryDetail: true
        )

        XCTAssertEqual(configuration.arrangement, .sidebarAndRightPanel)
        XCTAssertFalse(configuration.usesThreeColumnLayout)
        XCTAssertEqual(configuration.mode, "twoColumn")
    }
}
