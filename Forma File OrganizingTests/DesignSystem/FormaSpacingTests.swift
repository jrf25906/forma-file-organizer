//
//  FormaSpacingTests.swift
//  Forma File OrganizingTests
//

import XCTest
@testable import Forma_File_Organizing

final class FormaSpacingTests: XCTestCase {

    func testNewWindowMinWidth() {
        // Spec: increase from 1200 to 1280 for three-column comfort
        XCTAssertEqual(FormaSpacing.Window.minWidth, 1280)
    }

    func testSidebarConstraints() {
        XCTAssertEqual(FormaSpacing.Column.sidebarMin, 220)
        XCTAssertEqual(FormaSpacing.Column.sidebarIdeal, 260)
        XCTAssertEqual(FormaSpacing.Column.sidebarMax, 320)
    }

    func testCenterConstraints() {
        // Spec: center min drops from 680 to 560
        XCTAssertEqual(FormaSpacing.Column.centerMin, 560)
    }

    func testRightPanelConstraints() {
        XCTAssertEqual(FormaSpacing.Column.rightPanelMin, 280)
        XCTAssertEqual(FormaSpacing.Column.rightPanelIdeal, 340)
        XCTAssertEqual(FormaSpacing.Column.rightPanelMax, 420)
    }

    func testRightPanelLayoutUsesIdealWidthAsCompactBreakpoint() {
        XCTAssertEqual(
            RightPanelLayout(width: FormaSpacing.Column.rightPanelIdeal).widthClass,
            .regular
        )
        XCTAssertEqual(
            RightPanelLayout(width: FormaSpacing.Column.rightPanelIdeal - 1).widthClass,
            .compact
        )
        XCTAssertEqual(
            RightPanelLayout(width: FormaSpacing.Column.rightPanelMax).widthClass,
            .regular
        )
    }

    func testRightPanelLayoutPreservesMeasuredWidth() {
        let layout = RightPanelLayout(width: 312)

        XCTAssertEqual(layout.width, 312, accuracy: 0.001)
        XCTAssertEqual(layout.widthClass, .compact)
    }

    func testFileSurfaceLayoutUses760PointCompactBreakpoint() {
        XCTAssertEqual(
            FileSurfaceLayout(width: FileSurfaceLayout.compactBreakpoint).widthClass,
            .regular
        )
        XCTAssertEqual(
            FileSurfaceLayout(width: FileSurfaceLayout.compactBreakpoint - 1).widthClass,
            .compact
        )
    }

    func testFileSurfaceLayoutPreservesMeasuredWidth() {
        let layout = FileSurfaceLayout(width: 712)

        XCTAssertEqual(layout.width, 712, accuracy: 0.001)
        XCTAssertEqual(layout.widthClass, .compact)
    }
}
