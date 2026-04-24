import AppIntents
import XCTest
@testable import Forma_File_Organizing

@MainActor
final class FormaAppIntentsTests: XCTestCase {
    override func tearDown() async throws {
        FormaIntentRuntime.resetForTesting()
        UserDefaults.standard.removeObject(forKey: AutomationUserSettings.Keys.mode)
        try await super.tearDown()
    }

    func testScanFilesIntent_ThrowsNotConfiguredBeforeScanning() async {
        FormaIntentRuntime.isFullyConfiguredOverride = false
        let intent = ScanFilesIntent()

        await assertThrowsIntentError(.notConfigured) {
            _ = try await intent.perform()
        }
    }

    func testOrganizeFilesIntent_ThrowsNotConfiguredBeforeOrganizing() async {
        FormaIntentRuntime.isFullyConfiguredOverride = false
        let intent = OrganizeFilesIntent()

        await assertThrowsIntentError(.notConfigured) {
            _ = try await intent.perform()
        }
    }

    func testGetPendingCountIntent_ThrowsNotConfiguredBeforeReadingCounts() async {
        FormaIntentRuntime.isFullyConfiguredOverride = false
        let intent = GetPendingCountIntent()

        await assertThrowsIntentError(.notConfigured) {
            _ = try await intent.perform()
        }
    }

    func testOrganizeSelectionIntent_ThrowsNotConfiguredBeforeDispatch() async {
        FormaIntentRuntime.isFullyConfiguredOverride = false
        let intent = OrganizeSelectionIntent()
        intent.item = IntentFile(fileURL: URL(fileURLWithPath: "/tmp/forma-unconfigured.txt"))

        await assertThrowsIntentError(.notConfigured) {
            _ = try await intent.perform()
        }
    }

    func testOrganizeSelectionIntent_RejectsUnauthorizedFileURLBeforeDispatch() async {
        FormaIntentRuntime.isFullyConfiguredOverride = true
        FormaIntentRuntime.selectionAccessOverride = { _ in false }
        let intent = OrganizeSelectionIntent()
        intent.item = IntentFile(fileURL: URL(fileURLWithPath: "/tmp/forma-unauthorized.txt"))

        await assertThrowsIntentError(.selectionUnauthorized) {
            _ = try await intent.perform()
        }
    }

    func testReviewSelectionIntent_ThrowsNotConfiguredBeforeDispatch() async {
        FormaIntentRuntime.isFullyConfiguredOverride = false
        let intent = ReviewSelectionIntent()
        intent.items = [IntentFile(fileURL: URL(fileURLWithPath: "/tmp/forma-unconfigured-a.txt"))]

        await assertThrowsIntentError(.notConfigured) {
            _ = try await intent.perform()
        }
    }

    func testReviewSelectionIntent_RejectsAnyUnauthorizedFileURLBeforeDispatch() async {
        FormaIntentRuntime.isFullyConfiguredOverride = true
        FormaIntentRuntime.selectionAccessOverride = { url in
            url.lastPathComponent == "allowed.txt"
        }
        let intent = ReviewSelectionIntent()
        intent.items = [
            IntentFile(fileURL: URL(fileURLWithPath: "/tmp/allowed.txt")),
            IntentFile(fileURL: URL(fileURLWithPath: "/tmp/blocked.txt"))
        ]

        await assertThrowsIntentError(.selectionUnauthorized) {
            _ = try await intent.perform()
        }
    }

    func testToggleAutomationIntent_ThrowsNotConfiguredBeforePrompting() async {
        FormaIntentRuntime.isFullyConfiguredOverride = false
        var didPrompt = false
        FormaIntentRuntime.toggleAutomationConfirmationOverride = { _, _ in
            didPrompt = true
        }
        let intent = ToggleAutomationIntent()

        await assertThrowsIntentError(.notConfigured) {
            _ = try await intent.perform()
        }

        XCTAssertFalse(didPrompt)
    }

    func testToggleAutomationIntent_RequestsExplicitCurrentToNextConfirmationBeforeMutating() async throws {
        FormaIntentRuntime.isFullyConfiguredOverride = true
        UserDefaults.standard.set(AutomationMode.off.rawValue, forKey: AutomationUserSettings.Keys.mode)
        var promptedTransition: (current: AutomationMode, next: AutomationMode)?
        FormaIntentRuntime.toggleAutomationConfirmationOverride = { currentMode, nextMode in
            promptedTransition = (currentMode, nextMode)
        }
        let intent = ToggleAutomationIntent()

        _ = try await intent.perform()

        XCTAssertEqual(promptedTransition?.current, .off)
        XCTAssertEqual(promptedTransition?.next, .scanOnly)
        XCTAssertEqual(
            ToggleAutomationIntent.confirmationMessage(currentMode: .off, nextMode: .scanOnly),
            "Change Forma automation from Off to Scan Only?"
        )
        XCTAssertEqual(AutomationUserSettings.current.mode, .scanOnly)
    }

    func testGetAutomationStatusIntent_ThrowsNotConfiguredBeforeReadingStatus() async {
        FormaIntentRuntime.isFullyConfiguredOverride = false
        let intent = GetAutomationStatusIntent()

        await assertThrowsIntentError(.notConfigured) {
            _ = try await intent.perform()
        }
    }

    func testOpenFormaIntent_ThrowsNotConfiguredWhenAppIsStillUnavailable() async {
        FormaIntentRuntime.isFullyConfiguredOverride = false
        let intent = OpenFormaIntent()

        await assertThrowsIntentError(.notConfigured) {
            _ = try await intent.perform()
        }
    }

    func testIntentSelectionAccess_AllowsBookmarkBackedSelection() {
        let url = URL(fileURLWithPath: "/tmp/forma-bookmarked.txt")

        let isAuthorized = FormaIntentRuntime.hasAuthorizedSelectionAccess(
            to: url,
            createBookmarkData: { _ in Data([0x01]) },
            scopeRootPaths: { [] }
        )

        XCTAssertTrue(isAuthorized)
    }

    func testIntentSelectionAccess_AllowsSelectionInsideExistingBookmarkedScope() {
        let url = URL(fileURLWithPath: "/tmp/FormaScope/Nested/file.txt")

        let isAuthorized = FormaIntentRuntime.hasAuthorizedSelectionAccess(
            to: url,
            createBookmarkData: { _ in nil },
            scopeRootPaths: { ["/tmp/FormaScope"] }
        )

        XCTAssertTrue(isAuthorized)
    }

    func testIntentSelectionAccess_RejectsSelectionWithoutBookmarkOrExistingScope() {
        let url = URL(fileURLWithPath: "/tmp/FormaOther/file.txt")

        let isAuthorized = FormaIntentRuntime.hasAuthorizedSelectionAccess(
            to: url,
            createBookmarkData: { _ in nil },
            scopeRootPaths: { ["/tmp/FormaScope"] }
        )

        XCTAssertFalse(isAuthorized)
    }

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

private enum ExpectedFormaIntentError {
    case notConfigured
    case selectionUnauthorized
}

private func assertThrowsIntentError(
    _ expected: ExpectedFormaIntentError,
    operation: () async throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await operation()
        XCTFail("Expected FormaIntentError.\(expected)", file: file, line: line)
    } catch let error as FormaIntentError {
        switch (expected, error) {
        case (.notConfigured, .notConfigured),
             (.selectionUnauthorized, .selectionUnauthorized):
            return
        default:
            XCTFail("Unexpected FormaIntentError: \(error)", file: file, line: line)
        }
    } catch {
        XCTFail("Unexpected error: \(error)", file: file, line: line)
    }
}
