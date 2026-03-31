import XCTest
import AppKit
import SwiftUI
@testable import Forma_File_Organizing

final class FileSurfaceStyleTests: XCTestCase {
    func testResolve_keepsFocusedInteractionAlongsideErrorActivity() {
        let style = FileSurfaceStyle.resolve(
            .init(
                kind: .listRow,
                isHovered: true,
                isSelected: true,
                isFocused: true,
                activity: .error
            )
        )

        XCTAssertEqual(style.interactionState, .focused)
        XCTAssertEqual(style.activityState, .error)
        XCTAssertEqual(style.fillToken, .listRowBackground)
        XCTAssertEqual(style.overlayTokens, [.selected, .error])
        XCTAssertEqual(style.primaryBorderToken, .focused)
        XCTAssertEqual(style.accentBorderToken, .error)
    }

    func testResolve_keepsFocusedInteractionAlongsideProcessingActivity() {
        let style = FileSurfaceStyle.resolve(
            .init(
                kind: .card,
                isHovered: true,
                isSelected: true,
                isFocused: true,
                activity: .processing
            )
        )

        XCTAssertEqual(style.interactionState, .focused)
        XCTAssertEqual(style.activityState, .processing)
        XCTAssertEqual(style.fillToken, .cardBackground)
        XCTAssertEqual(style.overlayTokens, [.selected, .processing])
        XCTAssertEqual(style.primaryBorderToken, .focused)
        XCTAssertEqual(style.accentBorderToken, .processing)
    }

    func testResolve_usesActivityBorderWhenNoInteractionIsPresent() {
        let style = FileSurfaceStyle.resolve(
            .init(
                kind: .card,
                activity: .pending
            )
        )

        XCTAssertEqual(style.interactionState, .rest)
        XCTAssertEqual(style.activityState, .pending)
        XCTAssertEqual(style.overlayTokens, [.pending])
        XCTAssertEqual(style.primaryBorderToken, .pending)
        XCTAssertNil(style.accentBorderToken)
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

        XCTAssertEqual(style.interactionState, .focused)
        XCTAssertEqual(style.activityState, .none)
        XCTAssertEqual(style.overlayTokens, [.selected])
        XCTAssertEqual(style.primaryBorderToken, .focused)
        XCTAssertNil(style.accentBorderToken)
    }

    func testResolve_prefersSelectedOverHover() {
        let style = FileSurfaceStyle.resolve(
            .init(
                kind: .listRow,
                isHovered: true,
                isSelected: true
            )
        )

        XCTAssertEqual(style.interactionState, .selected)
        XCTAssertEqual(style.activityState, .none)
        XCTAssertEqual(style.overlayTokens, [.selected])
        XCTAssertEqual(style.primaryBorderToken, .selected)
        XCTAssertNil(style.accentBorderToken)
    }

    func testResolve_hoverStateUsesHoverTokens() {
        let style = FileSurfaceStyle.resolve(
            .init(
                kind: .listRow,
                isHovered: true
            )
        )

        XCTAssertEqual(style.interactionState, .hover)
        XCTAssertEqual(style.activityState, .none)
        XCTAssertEqual(style.overlayTokens, [.hover])
        XCTAssertEqual(style.primaryBorderToken, .hover)
        XCTAssertNil(style.accentBorderToken)
    }

    func testResolve_restStateUsesBaseTokensOnly() {
        let style = FileSurfaceStyle.resolve(.init(kind: .card))

        XCTAssertEqual(style.interactionState, .rest)
        XCTAssertEqual(style.activityState, .none)
        XCTAssertEqual(style.fillToken, .cardBackground)
        XCTAssertEqual(style.overlayTokens, [])
        XCTAssertEqual(style.primaryBorderToken, .rest)
        XCTAssertNil(style.accentBorderToken)
    }

    func testResolve_colorAccessorsMapTokensToSemanticColors() {
        let style = FileSurfaceStyle.resolve(
            .init(
                kind: .card,
                isFocused: true,
                activity: .processing
            )
        )

        XCTAssertEqual(style.overlayColors.count, 2)
        XCTAssertColor(style.fillColor, matches: .formaCardBackground)
        XCTAssertColor(style.overlayColors[0], matches: .formaFileSurfaceSelectionOverlay)
        XCTAssertColor(style.overlayColors[1], matches: .formaFileSurfaceProcessingOverlay)
        XCTAssertColor(style.primaryBorderColor, matches: .formaFileSurfaceFocusedBorder)
        XCTAssertNotNil(style.accentBorderColor)
        if let accentBorderColor = style.accentBorderColor {
            XCTAssertColor(accentBorderColor, matches: .formaFileSurfaceProcessingBorder)
        }
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
