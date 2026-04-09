// FormaShadowsTests.swift
import XCTest
@testable import Forma_File_Organizing

final class FormaShadowsTests: XCTestCase {

    // MARK: - Light Mode Values

    func testRestingShadowRadius() {
        let shadow = FormaShadow.resting
        XCTAssertEqual(shadow.radius, 4)
        XCTAssertEqual(shadow.y, 2)
    }

    func testRaisedShadowRadius() {
        let shadow = FormaShadow.raised
        XCTAssertEqual(shadow.radius, 8)
        XCTAssertEqual(shadow.y, 3)
    }

    func testFloatingShadowRadius() {
        let shadow = FormaShadow.floating
        XCTAssertEqual(shadow.radius, 16)
        XCTAssertEqual(shadow.y, 4)
    }

    func testOverlayShadowRadius() {
        let shadow = FormaShadow.overlay
        XCTAssertEqual(shadow.radius, 24)
        XCTAssertEqual(shadow.y, 8)
    }

    func testNoneShadowIsZero() {
        let shadow = FormaShadow.none
        XCTAssertEqual(shadow.radius, 0)
        XCTAssertEqual(shadow.y, 0)
    }

    // MARK: - Dark Mode Intensification

    func testDarkModeRadiusMultiplier() {
        let light = FormaShadow.resting
        let dark = FormaShadow.resting.darkMode
        // Dark mode shadows should be 2-3x more intense
        XCTAssertGreaterThan(dark.radius, light.radius)
        XCTAssertLessThanOrEqual(dark.radius, light.radius * 3)
    }
}
