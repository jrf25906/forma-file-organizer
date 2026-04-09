// FormaBordersTests.swift
import XCTest
@testable import Forma_File_Organizing

final class FormaBordersTests: XCTestCase {

    func testBorderWidthScale() {
        XCTAssertEqual(FormaBorderWidth.hairline, 0.5)
        XCTAssertEqual(FormaBorderWidth.thin, 1.0)
        XCTAssertEqual(FormaBorderWidth.medium, 1.5)
        XCTAssertEqual(FormaBorderWidth.thick, 2.0)
    }

    func testInnerLightEdgePresent() {
        // Inner light edge is the second layer in the two-layer border system
        let innerEdge = FormaBorderStyle.innerLightEdge
        XCTAssertEqual(innerEdge.width, FormaBorderWidth.hairline)
    }
}
