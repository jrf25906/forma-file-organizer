import XCTest
@testable import Forma_File_Organizing

@MainActor
final class PanelStateManagerTests: XCTestCase {
    func testPresentTrustedScopeRecommendation_PreservesCelebrationPastDismissDelay() async throws {
        let manager = PanelStateManager()

        manager.showCelebrationPanel(message: "Organized to Exports")
        manager.stageTrustedScopeRecommendation(makeRecommendation())
        manager.presentTrustedScopeRecommendation()

        try await Task.sleep(for: .seconds(6))

        guard case .celebration(let message) = manager.rightPanelMode else {
            return XCTFail("Expected celebration to remain visible while the trusted-scope sheet is open.")
        }

        XCTAssertEqual(message, "Organized to Exports")
        XCTAssertTrue(manager.isTrustedScopeRecommendationPresented)
        XCTAssertNotNil(manager.trustedScopeRecommendation)
    }

    func testDismissTrustedScopeRecommendation_ResumesRemainingCelebrationDelay() async throws {
        let manager = PanelStateManager()

        manager.showCelebrationPanel(message: "Organized to Exports")
        manager.stageTrustedScopeRecommendation(makeRecommendation())

        try await Task.sleep(for: .seconds(4))
        manager.presentTrustedScopeRecommendation()

        try await Task.sleep(for: .seconds(2))
        manager.dismissTrustedScopeRecommendation(clearRecommendation: true)
        XCTAssertNil(manager.trustedScopeRecommendation)
        XCTAssertFalse(manager.isTrustedScopeRecommendationPresented)

        try await waitUntil(
            timeout: FormaConfig.Timing.celebrationDurationSec + .seconds(1),
            pollingInterval: .milliseconds(100)
        ) {
            manager.rightPanelMode == .default
        }
    }

    private func makeRecommendation() -> TrustedAutomationScopeRecommendation {
        let destination = Destination.mockFolder("Documents/Exports")
        let snapshot = OrganizationMemorySnapshot(
            fileName: "Report.csv",
            fileExtension: "csv",
            fileTypeCategory: .documents,
            sourceLocation: .downloads,
            scanRootPath: "/Users/example/Downloads",
            relativeParentPath: "Exports",
            suggestionSource: .personalMemory,
            suggestedDestination: destination,
            chosenDestination: destination,
            confidenceScore: 0.94,
            matchedRuleID: nil
        )

        let option = TrustedAutomationScopeRecommendationOption(
            scopeType: .folder,
            scopeKey: "/Users/example/Downloads/Exports",
            displayName: "Exports",
            recommendationSource: .repeatedReviewAcceptance,
            acceptedEvidenceCount: 6,
            overrideEvidenceCount: 0,
            undoEvidenceCount: 0,
            confidenceSnapshot: 0.94,
            rationaleSummary: "You’ve approved this folder pattern 6 times with no recent undo in Exports."
        )

        return TrustedAutomationScopeRecommendation(
            recommendedScope: option,
            alternativeScopes: [],
            snapshot: snapshot
        )
    }

    private func waitUntil(
        timeout: Duration,
        pollingInterval: Duration,
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeInterval(for: timeout))
        while Date() < deadline {
            if condition() {
                return
            }
            try await Task.sleep(for: pollingInterval)
        }

        XCTAssertTrue(condition(), "Condition was not satisfied before the timeout expired.")
    }

    private func timeInterval(for duration: Duration) -> TimeInterval {
        let components = duration.components
        return TimeInterval(components.seconds) + (TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000)
    }
}
