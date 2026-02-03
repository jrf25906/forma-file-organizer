import XCTest
@testable import Forma_File_Organizing

final class ConfidenceIndicatorTests: XCTestCase {
    func testConfidenceTooltipTextWithoutReason() {
        let text = ConfidenceTooltip.text(for: 0.92, matchReason: nil)
        XCTAssertEqual(text, "Confidence: High (92%)")
    }

    func testConfidenceTooltipTextWithReason() {
        let text = ConfidenceTooltip.text(for: 0.5, matchReason: "Matched rule")
        XCTAssertEqual(text, "Confidence: Low (50%)\n\nMatched rule")
    }
}
