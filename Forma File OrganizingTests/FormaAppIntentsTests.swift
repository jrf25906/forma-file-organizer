import XCTest
@testable import Forma_File_Organizing

@MainActor
final class FormaAppIntentsTests: XCTestCase {
    func testOrganizeSelectionIntentFeedback_AppendsReviewFollowUpWhenReviewIsNeeded() {
        let result = ExternalIngressResult(
            autoOrganizedCount: 1,
            needsReviewPaths: ["/Users/test/Downloads/review.txt"],
            skippedItems: [],
            didRequireOnboarding: false,
            summary: ExternalIngressOutcomeSummary(
                source: .spotlightIntent,
                workflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts,
                autoOrganizedCount: 1,
                reviewCount: 1,
                skippedCount: 0,
                reauthorizationRequiredCount: 0
            ),
            scannedPaths: ["/Users/test/Downloads/review.txt"],
            scannedRootPaths: ["/Users/test/Downloads"]
        )

        let message = OrganizeSelectionIntentFeedback.message(for: .processed(result))

        XCTAssertEqual(message, "Forma organized 1 item, 1 need review. Finish review in Forma.")
    }

    func testOrganizeSelectionIntentFeedback_UsesImmediateSuccessSummaryWhenNoReviewIsNeeded() {
        let result = ExternalIngressResult(
            autoOrganizedCount: 1,
            needsReviewPaths: [],
            skippedItems: [],
            didRequireOnboarding: false,
            summary: ExternalIngressOutcomeSummary(
                source: .spotlightIntent,
                workflowTemplateID: nil,
                autoOrganizedCount: 1,
                reviewCount: 0,
                skippedCount: 0,
                reauthorizationRequiredCount: 0
            ),
            scannedPaths: ["/Users/test/Downloads/receipt.pdf"],
            scannedRootPaths: ["/Users/test/Downloads"]
        )

        let message = OrganizeSelectionIntentFeedback.message(for: .processed(result))

        XCTAssertEqual(message, "Forma organized 1 item.")
    }

    func testOrganizeSelectionIntentFeedback_UsesOnboardingResumeMessage() {
        let request = ExternalIngressRequest(
            id: UUID(),
            createdAt: Date(),
            source: .spotlightIntent,
            items: [],
            workflowTemplateID: nil
        )

        let message = OrganizeSelectionIntentFeedback.message(for: .needsOnboarding(request))

        XCTAssertEqual(message, "Finish Forma setup in the app, then the selected item will resume automatically.")
    }

    func testReviewSelectionIntentFeedback_AppendsOpenedForReviewMessageWhenReviewIsNeeded() {
        let result = ExternalIngressResult(
            autoOrganizedCount: 1,
            needsReviewPaths: [
                "/Users/test/Downloads/review-a.txt",
                "/Users/test/Downloads/review-b.txt"
            ],
            skippedItems: [],
            didRequireOnboarding: false,
            summary: ExternalIngressOutcomeSummary(
                source: .spotlightIntent,
                workflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts,
                autoOrganizedCount: 1,
                reviewCount: 2,
                skippedCount: 0,
                reauthorizationRequiredCount: 0
            ),
            scannedPaths: [
                "/Users/test/Downloads/review-a.txt",
                "/Users/test/Downloads/review-b.txt"
            ],
            scannedRootPaths: ["/Users/test/Downloads"]
        )

        let message = ReviewSelectionIntentFeedback.message(for: .processed(result))

        XCTAssertEqual(message, "Forma organized 1 item, 2 need review. Forma opened for review.")
    }

    func testReviewSelectionIntentFeedback_UsesSuccessSummaryWhenEverythingFinishesImmediately() {
        let result = ExternalIngressResult(
            autoOrganizedCount: 2,
            needsReviewPaths: [],
            skippedItems: [],
            didRequireOnboarding: false,
            summary: ExternalIngressOutcomeSummary(
                source: .spotlightIntent,
                workflowTemplateID: nil,
                autoOrganizedCount: 2,
                reviewCount: 0,
                skippedCount: 0,
                reauthorizationRequiredCount: 0
            ),
            scannedPaths: [
                "/Users/test/Downloads/receipt-a.pdf",
                "/Users/test/Downloads/receipt-b.pdf"
            ],
            scannedRootPaths: ["/Users/test/Downloads"]
        )

        let message = ReviewSelectionIntentFeedback.message(for: .processed(result))

        XCTAssertEqual(message, "Forma organized 2 items.")
    }

    func testReviewSelectionIntentFeedback_UsesRecoverySummaryWithoutImplyingTheAppOpened() {
        let result = ExternalIngressResult(
            autoOrganizedCount: 0,
            needsReviewPaths: [],
            skippedItems: [
                ExternalIngressSkippedItem(
                    path: "/Users/test/Downloads/Locked.pdf",
                    reason: .inaccessibleSelection,
                    message: "Forma needs you to run Organize with Forma again to restore access to this item."
                )
            ],
            didRequireOnboarding: false,
            summary: ExternalIngressOutcomeSummary(
                source: .spotlightIntent,
                workflowTemplateID: nil,
                autoOrganizedCount: 0,
                reviewCount: 0,
                skippedCount: 1,
                reauthorizationRequiredCount: 1
            ),
            scannedPaths: [],
            scannedRootPaths: []
        )

        let message = ReviewSelectionIntentFeedback.message(for: .processed(result))

        XCTAssertEqual(message, "Forma needs you to run Organize with Forma again to restore access to the selected items.")
    }

    func testReviewSelectionIntentFeedback_UsesPluralOnboardingResumeMessage() {
        let request = ExternalIngressRequest(
            id: UUID(),
            createdAt: Date(),
            source: .spotlightIntent,
            items: [],
            workflowTemplateID: nil,
            executionMode: .reviewFirst
        )

        let message = ReviewSelectionIntentFeedback.message(for: .needsOnboarding(request))

        XCTAssertEqual(message, "Finish Forma setup in the app, then the selected items will resume automatically.")
    }
}
