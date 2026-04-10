import XCTest
import SwiftUI
@testable import Forma_File_Organizing

final class DashboardSplitViewPolicyTests: XCTestCase {
    func testVisibleInspectorUsesAllColumns() {
        XCTAssertEqual(
            DashboardSplitViewPolicy.visibility(for: true),
            .all
        )
    }

    func testHiddenInspectorUsesDoubleColumn() {
        XCTAssertEqual(
            DashboardSplitViewPolicy.visibility(for: false),
            .doubleColumn
        )
    }

    func testDoubleColumnVisibilityMapsToHiddenInspector() {
        XCTAssertFalse(
            DashboardSplitViewPolicy.isInspectorVisible(for: .doubleColumn)
        )
    }

    func testAllVisibilityMapsToVisibleInspector() {
        XCTAssertTrue(
            DashboardSplitViewPolicy.isInspectorVisible(for: .all)
        )
    }

    func testExplicitInspectorVisibilityTreatsAutomaticAsHiddenFallback() {
        XCTAssertFalse(
            DashboardSplitViewPolicy.explicitInspectorVisibility(for: .automatic) ?? true
        )
    }

    func testExplicitInspectorVisibilityIgnoresDetailOnlyVisibility() {
        XCTAssertNil(
            DashboardSplitViewPolicy.explicitInspectorVisibility(for: .detailOnly)
        )
    }
}
