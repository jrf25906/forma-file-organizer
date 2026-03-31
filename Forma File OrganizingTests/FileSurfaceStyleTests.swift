import XCTest
@testable import Forma_File_Organizing

final class FileSurfaceStyleTests: XCTestCase {
    func testResolve_prefersErrorOverEveryOtherState() {
        let style = FileSurfaceStyle.resolve(
            .init(
                kind: .listRow,
                isHovered: true,
                isSelected: true,
                isFocused: true,
                activity: .error
            )
        )

        XCTAssertEqual(style.state, .error)
        XCTAssertEqual(style.fillToken, .listRowBackground)
        XCTAssertEqual(style.overlayToken, .error)
        XCTAssertEqual(style.borderToken, .error)
    }

    func testResolve_prefersProcessingOverPendingAndFocus() {
        let style = FileSurfaceStyle.resolve(
            .init(
                kind: .card,
                isHovered: true,
                isSelected: true,
                isFocused: true,
                activity: .processing
            )
        )

        XCTAssertEqual(style.state, .processing)
        XCTAssertEqual(style.fillToken, .cardBackground)
        XCTAssertEqual(style.overlayToken, .processing)
        XCTAssertEqual(style.borderToken, .processing)
    }

    func testResolve_prefersPendingOverFocusedSelectionAndHover() {
        let style = FileSurfaceStyle.resolve(
            .init(
                kind: .card,
                isHovered: true,
                isSelected: true,
                isFocused: true,
                activity: .pending
            )
        )

        XCTAssertEqual(style.state, .pending)
        XCTAssertEqual(style.overlayToken, .pending)
        XCTAssertEqual(style.borderToken, .pending)
    }

    func testResolve_prefersFocusedOverSelectionAndHover() {
        let style = FileSurfaceStyle.resolve(
            .init(
                kind: .listRow,
                isHovered: true,
                isSelected: true,
                isFocused: true
            )
        )

        XCTAssertEqual(style.state, .focused)
        XCTAssertEqual(style.overlayToken, .selected)
        XCTAssertEqual(style.borderToken, .focused)
    }

    func testResolve_prefersSelectedOverHover() {
        let style = FileSurfaceStyle.resolve(
            .init(
                kind: .listRow,
                isHovered: true,
                isSelected: true
            )
        )

        XCTAssertEqual(style.state, .selected)
        XCTAssertEqual(style.overlayToken, .selected)
        XCTAssertEqual(style.borderToken, .selected)
    }

    func testResolve_restStateUsesBaseTokensOnly() {
        let style = FileSurfaceStyle.resolve(.init(kind: .card))

        XCTAssertEqual(style.state, .rest)
        XCTAssertEqual(style.fillToken, .cardBackground)
        XCTAssertNil(style.overlayToken)
        XCTAssertEqual(style.borderToken, .rest)
    }
}
