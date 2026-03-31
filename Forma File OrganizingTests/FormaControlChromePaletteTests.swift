import XCTest
import AppKit
import SwiftUI
@testable import Forma_File_Organizing

@MainActor
final class FormaControlChromePaletteTests: XCTestCase {
    func testActiveFill_lightModeWithTintUsesSolidTintedSelectionFill() {
        let color = FormaControlChromePalette.activeFill(.light, tint: .formaSteelBlue)

        XCTAssertColor(
            color,
            matches: Color.formaSteelBlue.blend(with: .formaBoneWhite, ratio: 0.76)
        )
    }

    func testSelectedForeground_lightModeWithTintUsesTintAwareContrast() {
        let color = FormaControlChromePalette.selectedForeground(.light, tint: .formaSteelBlue)

        XCTAssertColor(
            color,
            matches: Color.formaSteelBlue.blend(with: .formaObsidian, ratio: 0.40)
        )
    }

    func testSidebarGlassStyle_reduceTransparencyRemovesSheenAndEdgeHighlights() {
        let style = FormaControlChromePalette.sidebarGlassStyle(
            .light,
            isWindowActive: true,
            reduceTransparency: true
        )

        XCTAssertEqual(style.sheenTopOpacity, 0)
        XCTAssertEqual(style.sheenBottomOpacity, 0)
        XCTAssertEqual(style.edgeOpacity, 0)
    }

    private func XCTAssertColor(
        _ color: Color,
        matches expected: Color,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let lhs = NSColor(color).usingColorSpace(.deviceRGB)
        let rhs = NSColor(expected).usingColorSpace(.deviceRGB)

        XCTAssertNotNil(lhs, file: file, line: line)
        XCTAssertNotNil(rhs, file: file, line: line)

        guard let lhs, let rhs else { return }

        XCTAssertEqual(lhs.redComponent, rhs.redComponent, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(lhs.greenComponent, rhs.greenComponent, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(lhs.blueComponent, rhs.blueComponent, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(lhs.alphaComponent, rhs.alphaComponent, accuracy: 0.001, file: file, line: line)
    }
}
