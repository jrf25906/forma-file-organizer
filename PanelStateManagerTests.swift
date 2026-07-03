import XCTest
@testable import Forma_File_Organizing

@MainActor
final class PanelStateManagerTests: XCTestCase {
    func testCelebrationWithTrustedScopeRecommendationDoesNotAutoDismiss() async throws {
        let manager = PanelStateManager()

        manager.showCelebrationPanel(message: "Organized to Documents")
        manager.stageTrustedScopeRecommendation(makeRecommendation())

        try await Task.sleep(for: .seconds(6))

        guard case .celebration(let message) = manager.rightPanelMode else {
            return XCTFail("Expected celebration panel to remain visible while a trusted-scope recommendation is staged.")
        }

        XCTAssertEqual(message, "Organized to Documents")
        XCTAssertNotNil(manager.trustedScopeRecommendation)
    }

    private func makeRecommendation() -> TrustedAutomationScopeRecommendation {
        let destination = Destination.mockFolder("Documents/Receipts")
        let snapshot = OrganizationMemorySnapshot(
            fileName: "Receipt.pdf",
            fileExtension: "pdf",
            fileTypeCategory: .documents,
            sourceLocation: .downloads,
            scanRootPath: "/Users/example/Downloads",
            relativeParentPath: nil,
            suggestionSource: .personalMemory,
            suggestedDestination: destination,
            chosenDestination: destination,
            confidenceScore: 0.94,
            matchedRuleID: nil
        )

        let option = TrustedAutomationScopeRecommendationOption(
            scopeType: .folder,
            scopeKey: "/Users/example/Downloads",
            displayName: "Downloads",
            recommendationSource: .repeatedReviewAcceptance,
            acceptedEvidenceCount: 6,
            overrideEvidenceCount: 0,
            undoEvidenceCount: 0,
            confidenceSnapshot: 0.94,
            rationaleSummary: "You’ve approved this folder pattern 6 times with no recent undo in Downloads."
        )

        return TrustedAutomationScopeRecommendation(
            recommendedScope: option,
            alternativeScopes: [],
            snapshot: snapshot
        )
    }
}
