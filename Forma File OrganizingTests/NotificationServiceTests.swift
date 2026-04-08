import XCTest
@testable import Forma_File_Organizing

final class NotificationServiceTests: XCTestCase {

    func testAutoOrganizeSummaryPayloadUsesProgressToneAndStableIdentifier() {
        let payload = NotificationService.autoOrganizeSummaryPayload(
            successCount: 6,
            failedCount: 0,
            skippedCount: 0,
            scopeDisplayName: nil,
            groupedScopeCount: 0
        )

        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?.category, .progressWin)
        XCTAssertEqual(payload?.identifier, NotificationService.AutomationNotificationID.autoOrganizeSummary)
        XCTAssertEqual(payload?.title, "Auto-Organize Made Progress")
        XCTAssertEqual(payload?.body, "Forma cleared 6 files from your queue based on your rules.")
    }

    func testAutoOrganizeSummaryPayloadUsesScopeNameForSingleScopeRun() {
        let payload = NotificationService.autoOrganizeSummaryPayload(
            successCount: 3,
            failedCount: 0,
            skippedCount: 1,
            scopeDisplayName: "Receipts",
            groupedScopeCount: 1
        )

        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?.category, .progressWin)
        XCTAssertEqual(payload?.identifier, NotificationService.AutomationNotificationID.autoOrganizeSummary)
        XCTAssertEqual(payload?.title, "Receipts Made Progress")
        XCTAssertEqual(
            payload?.body,
            "Forma cleared 3 files from the Receipts trusted scope. 1 is still waiting for review."
        )
    }

    func testAutoOrganizeSummaryPayloadKeepsMultiScopeRunsGrouped() {
        let payload = NotificationService.autoOrganizeSummaryPayload(
            successCount: 5,
            failedCount: 1,
            skippedCount: 0,
            scopeDisplayName: "Receipts",
            groupedScopeCount: 2
        )

        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?.category, .progressWin)
        XCTAssertEqual(payload?.identifier, NotificationService.AutomationNotificationID.autoOrganizeSummary)
        XCTAssertEqual(payload?.title, "Auto-Organize Made Progress")
        XCTAssertEqual(
            payload?.body,
            "Forma cleared 5 files across 2 trusted scopes based on your rules. 1 still needs your attention."
        )
    }

    func testBacklogReminderPayloadFramesNextReviewPassWithoutGuilt() {
        let payload = NotificationService.backlogReminderPayload(
            pendingCount: 12,
            oldestAgeDays: 4
        )

        XCTAssertEqual(payload.category, .reminder)
        XCTAssertEqual(payload.identifier, NotificationService.AutomationNotificationID.backlogReminder)
        XCTAssertEqual(payload.categoryIdentifier, "BACKLOG_REMINDER")
        XCTAssertEqual(payload.title, "Your Next Review Pass Is Ready")
        XCTAssertEqual(payload.body, "12 files are ready for your next review pass. The oldest has been waiting 4 days.")
    }

    func testAgeReminderPayloadAvoidsZeroFileLanguage() {
        let payload = NotificationService.backlogReminderPayload(
            pendingCount: 0,
            oldestAgeDays: 6
        )

        XCTAssertEqual(payload.category, .reminder)
        XCTAssertEqual(payload.identifier, NotificationService.AutomationNotificationID.ageReminder)
        XCTAssertEqual(payload.title, "A Quick Review Pass Would Help")
        XCTAssertEqual(payload.body, "Some files have been waiting 6 days. A quick review pass will get them moving again.")
    }

    func testPermissionErrorPayloadUsesExplicitSupportiveCopyAndStableIdentifier() {
        let payload = NotificationService.automationErrorPayload(
            type: .permissionDenied,
            message: "Access to folder denied"
        )

        XCTAssertEqual(payload.category, .errorOrPermission)
        XCTAssertEqual(
            payload.identifier,
            NotificationService.AutomationNotificationID.error(type: "permissionDenied")
        )
        XCTAssertEqual(payload.title, "Permission Needed")
        XCTAssertEqual(
            payload.body,
            "Forma needs macOS permission before it can keep organizing here. Access to folder denied."
        )
    }
}
