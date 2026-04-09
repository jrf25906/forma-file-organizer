// FormaEasingTests.swift
import XCTest
@testable import Forma_File_Organizing

final class FormaEasingTests: XCTestCase {

    func testDurationScale() {
        // Durations must be strictly increasing
        XCTAssertLessThan(FormaEasing.Duration.micro, FormaEasing.Duration.fast)
        XCTAssertLessThan(FormaEasing.Duration.fast, FormaEasing.Duration.standard)
        XCTAssertLessThan(FormaEasing.Duration.standard, FormaEasing.Duration.slow)
        XCTAssertLessThan(FormaEasing.Duration.slow, FormaEasing.Duration.entrance)
    }

    func testMicroDurationValue() {
        XCTAssertEqual(FormaEasing.Duration.micro, 0.15)
    }

    func testStandardDurationValue() {
        XCTAssertEqual(FormaEasing.Duration.standard, 0.25)
    }

    func testReducedMotionDurationIsHalved() {
        XCTAssertEqual(
            FormaEasing.Duration.reducedMotion(FormaEasing.Duration.standard),
            0.125,
            accuracy: 0.001
        )
    }
}
