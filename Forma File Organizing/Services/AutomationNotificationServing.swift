import Foundation

/// Narrow protocol used by `AutomationEngine` for notification side effects.
///
/// This keeps the engine testable without relying on macOS notification center APIs.
protocol AutomationNotificationServing: AnyObject {
    func notifyAutoOrganizeSummary(successCount: Int, failedCount: Int, skippedCount: Int)
    func notifyBacklogReminder(pendingCount: Int, oldestAgeDays: Int?)
    func notifyAutomationError(type: AutomationErrorType, message: String)
}

extension NotificationService: AutomationNotificationServing {}
