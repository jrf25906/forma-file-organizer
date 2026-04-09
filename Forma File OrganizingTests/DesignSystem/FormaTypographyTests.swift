// FormaTypographyTests.swift
import XCTest
import SwiftUI
@testable import Forma_File_Organizing

final class FormaTypographyTests: XCTestCase {

    func testCalloutFontExists() {
        // formaCallout bridges the gap between Body(13pt) and H3(17pt)
        let _ = Font.formaCallout
        XCTAssertTrue(true, "formaCallout font exists")
    }

    func testTabularBodyExists() {
        let _ = Font.formaBodyTabular
        XCTAssertTrue(true, "formaBodyTabular font exists")
    }

    func testTabularSmallExists() {
        let _ = Font.formaSmallTabular
        XCTAssertTrue(true, "formaSmallTabular font exists")
    }

    func testTabularCompactExists() {
        let _ = Font.formaCompactTabular
        XCTAssertTrue(true, "formaCompactTabular font exists")
    }
}
