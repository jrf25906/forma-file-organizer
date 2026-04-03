import XCTest
@testable import Forma_File_Organizing

final class MainWindowFrameValidatorTests: XCTestCase {

    func testValidatedFrameLeavesVisibleFrameUnchanged() {
        let visibleFrames = [
            CGRect(x: 0, y: 0, width: 1440, height: 900)
        ]
        let restoredFrame = CGRect(x: 120, y: 80, width: 1120, height: 760)

        let result = MainWindowFrameValidator.validatedFrame(
            restoredFrame,
            visibleFrames: visibleFrames,
            minimumSize: CGSize(width: 960, height: 640)
        )

        XCTAssertEqual(result, restoredFrame)
    }

    func testValidatedFrameShrinksAndClampsOversizedFrameToCurrentDisplay() {
        let visibleFrames = [
            CGRect(x: 0, y: 0, width: 1280, height: 800)
        ]
        let restoredFrame = CGRect(x: 180, y: 60, width: 1600, height: 1000)

        let result = MainWindowFrameValidator.validatedFrame(
            restoredFrame,
            visibleFrames: visibleFrames,
            minimumSize: CGSize(width: 960, height: 640)
        )

        XCTAssertEqual(result, CGRect(x: 0, y: 0, width: 1280, height: 800))
    }

    func testValidatedFrameRecentersOffscreenFrameOntoNearestAvailableDisplay() {
        let visibleFrames = [
            CGRect(x: 0, y: 0, width: 1440, height: 900),
            CGRect(x: 1440, y: 0, width: 1440, height: 900)
        ]
        let restoredFrame = CGRect(x: 3300, y: 120, width: 1200, height: 800)

        let result = MainWindowFrameValidator.validatedFrame(
            restoredFrame,
            visibleFrames: visibleFrames,
            minimumSize: CGSize(width: 960, height: 640)
        )

        XCTAssertEqual(result, CGRect(x: 1560, y: 50, width: 1200, height: 800))
    }

    func testValidatedFramePreservesMultiDisplayFrameWhenFullyVisibleAcrossScreens() {
        let visibleFrames = [
            CGRect(x: 0, y: 0, width: 1440, height: 900),
            CGRect(x: 1440, y: 0, width: 1440, height: 900)
        ]
        let restoredFrame = CGRect(x: 800, y: 80, width: 1600, height: 760)

        let result = MainWindowFrameValidator.validatedFrame(
            restoredFrame,
            visibleFrames: visibleFrames,
            minimumSize: CGSize(width: 960, height: 640)
        )

        XCTAssertEqual(result, restoredFrame)
    }
}
