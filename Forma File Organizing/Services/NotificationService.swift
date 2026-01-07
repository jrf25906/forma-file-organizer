import Foundation
import UserNotifications

/// Service responsible for managing macOS system notifications
final class NotificationService: Sendable {

    static let shared = NotificationService()

    private init() {
        // Request notification authorization on init
        Task {
            await requestAuthorization()
        }
    }

    // MARK: - Authorization

    /// Requests authorization to display notifications
    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                Log.info("Notification authorization granted", category: .ui)
            } else {
                Log.warning("Notification authorization denied", category: .ui)
            }
        } catch {
            Log.error("Error requesting notification authorization: \(error)", category: .ui)
        }
    }

    // MARK: - Notification Methods

    /// Shows a notification for a single file being organized
    /// - Parameters:
    ///   - fileName: Name of the file that was moved
    ///   - destination: Destination folder where the file was moved
    func notifyFileOrganized(fileName: String, destination: String) {
        // Check user preference
        guard UserDefaults.standard.bool(forKey: "showNotifications") else {
            Log.info("Notifications disabled in settings", category: .ui)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "File Organized"
        content.body = "Moved \(fileName) to \(destination)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Show immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Log.error("Error showing notification: \(error)", category: .ui)
            } else {
                Log.info("Notification shown: \(fileName) -> \(destination)", category: .ui)
            }
        }
    }

    /// Shows a notification for multiple files being organized
    /// - Parameters:
    ///   - count: Number of files that were successfully moved
    ///   - totalCount: Total number of files that were attempted to be moved
    func notifyBatchOrganized(successCount: Int, totalCount: Int) {
        // Check user preference
        guard UserDefaults.standard.bool(forKey: "showNotifications") else {
            Log.info("Notifications disabled in settings", category: .ui)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Files Organized"

        if successCount == totalCount {
            // All files succeeded
            content.body = "Successfully organized \(successCount) file\(successCount == 1 ? "" : "s")"
        } else if successCount > 0 {
            // Partial success
            content.body = "Organized \(successCount) of \(totalCount) files"
        } else {
            // All failed - don't show a notification for complete failure
            return
        }

        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Show immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Log.error("Error showing batch notification: \(error)", category: .ui)
            } else {
                Log.info("Batch notification shown: \(successCount)/\(totalCount) files", category: .ui)
            }
        }
    }

    /// Shows a generic notification with custom title and message
    /// - Parameters:
    ///   - title: Notification title
    ///   - message: Notification message body
    func showNotification(title: String, message: String) {
        // Check user preference
        guard UserDefaults.standard.bool(forKey: "showNotifications") else {
            Log.info("Notifications disabled in settings", category: .ui)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Show immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Log.error("Error showing notification: \(error)", category: .ui)
            } else {
                Log.info("Notification shown: \(title) - \(message)", category: .ui)
            }
        }
    }
    
    /// Clears all delivered notifications
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }

    /// Removes specific notification by identifier
    func removeNotification(withIdentifier identifier: String) {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    // MARK: - Automation Notifications

    /// Notification identifiers for automation features.
    /// Use these to clear specific notification types.
    enum AutomationNotificationID {
        static let autoOrganizeSummary = "forma.automation.organize-summary"
        static let backlogReminder = "forma.automation.backlog-reminder"
        static let ageReminder = "forma.automation.age-reminder"
        static let ruleHighlight = "forma.automation.rule-highlight"
        static let errorPrefix = "forma.automation.error"

        static func error(type: String) -> String {
            "\(errorPrefix).\(type)"
        }

        static func ruleHighlight(ruleID: String) -> String {
            "\(ruleHighlight).\(ruleID)"
        }
    }

    /// Shows a summary notification for auto-organized files.
    ///
    /// - Parameters:
    ///   - successCount: Number of files successfully organized
    ///   - failedCount: Number of files that failed to organize
    ///   - skippedCount: Number of files skipped (didn't meet criteria)
    func notifyAutoOrganizeSummary(successCount: Int, failedCount: Int, skippedCount: Int) {
        guard UserDefaults.standard.bool(forKey: "showNotifications") else { return }
        guard successCount > 0 || failedCount > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Auto-Organize Complete"
        content.sound = .default

        if failedCount == 0 && skippedCount == 0 {
            content.body = "Automatically organized \(successCount) file\(successCount == 1 ? "" : "s") based on your rules."
        } else if failedCount > 0 {
            content.body = "Organized \(successCount) file\(successCount == 1 ? "" : "s"). \(failedCount) couldn't be moved."
        } else {
            content.body = "Organized \(successCount) file\(successCount == 1 ? "" : "s"). \(skippedCount) skipped."
        }

        // Use fixed identifier so subsequent summaries replace the previous one
        let request = UNNotificationRequest(
            identifier: AutomationNotificationID.autoOrganizeSummary,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Log.error("Error showing auto-organize notification: \(error)", category: .automation)
            } else {
                Log.info("Auto-organize notification shown: \(successCount) success, \(failedCount) failed", category: .automation)
            }
        }
    }

    /// Shows a reminder notification when file backlog exceeds thresholds.
    ///
    /// - Parameters:
    ///   - pendingCount: Number of files waiting for review
    ///   - oldestAgeDays: Age of the oldest pending file in days (optional)
    func notifyBacklogReminder(pendingCount: Int, oldestAgeDays: Int?) {
        guard UserDefaults.standard.bool(forKey: "showNotifications") else { return }

        let content = UNMutableNotificationContent()
        content.title = "Files Need Attention"
        content.sound = .default

        var body = "You have \(pendingCount) file\(pendingCount == 1 ? "" : "s") waiting for review."
        if let days = oldestAgeDays, days > 0 {
            body += " Some have been waiting \(days) day\(days == 1 ? "" : "s")."
        }
        content.body = body

        // Determine identifier based on trigger type
        let identifier = oldestAgeDays != nil && pendingCount == 0
            ? AutomationNotificationID.ageReminder
            : AutomationNotificationID.backlogReminder

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Log.error("Error showing backlog reminder: \(error)", category: .automation)
            } else {
                Log.info("Backlog reminder shown: \(pendingCount) files, oldest \(oldestAgeDays ?? 0) days", category: .automation)
            }
        }
    }

    /// Shows a notification highlighting when a rule matched multiple files.
    ///
    /// - Parameters:
    ///   - ruleName: Name of the rule that matched
    ///   - matchCount: Number of files that matched the rule
    ///   - ruleID: Unique identifier of the rule (for notification deduplication)
    func notifyRuleHighlights(ruleName: String, matchCount: Int, ruleID: String) {
        guard UserDefaults.standard.bool(forKey: "showNotifications") else { return }
        guard matchCount > 1 else { return } // Only notify for multiple matches

        let content = UNMutableNotificationContent()
        content.title = "Rule Match: \(ruleName)"
        content.body = "\(matchCount) files matched this rule and are ready to organize."
        content.sound = .default

        // Use rule-specific identifier so each rule gets its own notification
        let request = UNNotificationRequest(
            identifier: AutomationNotificationID.ruleHighlight(ruleID: ruleID),
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Log.error("Error showing rule highlight notification: \(error)", category: .automation)
            } else {
                Log.info("Rule highlight notification shown: \(ruleName) matched \(matchCount) files", category: .automation)
            }
        }
    }

    /// Shows an error notification for automation failures.
    ///
    /// - Parameters:
    ///   - type: Type of error that occurred
    ///   - message: Descriptive error message
    func notifyAutomationError(type: AutomationErrorType, message: String) {
        guard UserDefaults.standard.bool(forKey: "showNotifications") else { return }

        let content = UNMutableNotificationContent()
        content.title = type.title
        content.body = message
        content.sound = .default

        // Use error-type-specific identifier so we can clear by type
        let identifier = AutomationNotificationID.error(type: type.notificationIdentifier)

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Log.error("Error showing automation error notification: \(error)", category: .automation)
            } else {
                Log.info("Automation error notification shown: \(type) - \(message)", category: .automation)
            }
        }
    }

    /// Clears automation-related notifications when issues are resolved.
    ///
    /// - Parameter types: Types of notifications to clear
    func clearAutomationNotifications(types: Set<AutomationNotificationType>) {
        var identifiers: [String] = []

        for type in types {
            switch type {
            case .autoOrganizeSummary:
                identifiers.append(AutomationNotificationID.autoOrganizeSummary)
            case .backlogReminder:
                identifiers.append(AutomationNotificationID.backlogReminder)
            case .ageReminder:
                identifiers.append(AutomationNotificationID.ageReminder)
            case .allErrors:
                // Clear all error notifications - need to enumerate
                identifiers.append(contentsOf: [
                    AutomationNotificationID.error(type: "scanFailed"),
                    AutomationNotificationID.error(type: "bookmarkInvalid"),
                    AutomationNotificationID.error(type: "destinationInaccessible"),
                    AutomationNotificationID.error(type: "permissionDenied")
                ])
            }
        }

        if !identifiers.isEmpty {
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiers)
            Log.info("Cleared automation notifications: \(types)", category: .automation)
        }
    }
}

// MARK: - Automation Notification Types

/// Types of automation notifications that can be cleared.
enum AutomationNotificationType: Hashable {
    case autoOrganizeSummary
    case backlogReminder
    case ageReminder
    case allErrors
}

// MARK: - AutomationErrorType Extension

extension AutomationErrorType {
    /// Identifier suffix used for notification management.
    var notificationIdentifier: String {
        switch self {
        case .scanFailed: return "scanFailed"
        case .bookmarkInvalid: return "bookmarkInvalid"
        case .destinationInaccessible: return "destinationInaccessible"
        case .permissionDenied: return "permissionDenied"
        }
    }
}
