import Foundation
import UserNotifications

enum AutomationNotificationToneCategory: Equatable {
    case progressWin
    case reminder
    case errorOrPermission
}

struct AutomationNotificationPayload: Equatable {
    let category: AutomationNotificationToneCategory
    let identifier: String
    let title: String
    let body: String
    let categoryIdentifier: String?
}

/// Service responsible for managing macOS system notifications
final class NotificationService: Sendable {

    static let shared = NotificationService()

    private init() {
        let env = ProcessInfo.processInfo.environment
        let isRunningTests = env["XCTestConfigurationFilePath"] != nil ||
            env["XCTestBundlePath"] != nil ||
            env["XCTestSessionIdentifier"] != nil ||
            env["XCInjectBundleInto"] != nil
        let isUITesting = CommandLine.arguments.contains("--uitesting")

        guard !isRunningTests && !isUITesting else {
            return
        }

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

    /// Registers notification categories with actions for interactive notifications.
    func registerCategories() {
        let reviewAction = UNNotificationAction(
            identifier: "REVIEW_ACTION",
            title: "Review",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: "BACKLOG_REMINDER",
            actions: [reviewAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
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
        static let folderHealthPrefix = "forma.automation.folder-health"
        static let staleRules = "forma.automation.stale-rules"
        static let ruleHighlight = "forma.automation.rule-highlight"
        static let errorPrefix = "forma.automation.error"

        static func error(type: String) -> String {
            "\(errorPrefix).\(type)"
        }

        static func ruleHighlight(ruleID: String) -> String {
            "\(ruleHighlight).\(ruleID)"
        }

        static func folderHealth(folderType: BookmarkFolder.FolderType) -> String {
            "\(folderHealthPrefix).\(folderType.rawValue)"
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
        guard let payload = Self.autoOrganizeSummaryPayload(
            successCount: successCount,
            failedCount: failedCount,
            skippedCount: skippedCount
        ) else { return }

        enqueue(payload) { error in
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

        let payload = Self.backlogReminderPayload(pendingCount: pendingCount, oldestAgeDays: oldestAgeDays)

        enqueue(payload) { error in
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
        guard let payload = Self.ruleHighlightPayload(ruleName: ruleName, matchCount: matchCount, ruleID: ruleID) else {
            return
        }

        enqueue(payload) { error in
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

        let payload = Self.automationErrorPayload(type: type, message: message)

        enqueue(payload) { error in
            if let error = error {
                Log.error("Error showing automation error notification: \(error)", category: .automation)
            } else {
                Log.info("Automation error notification shown: \(type) - \(message)", category: .automation)
            }
        }
    }

    func notifyFolderHealthAlert(
        folderType: BookmarkFolder.FolderType,
        currentBytes: Int64,
        thresholdBytes: Int64
    ) {
        guard UserDefaults.standard.bool(forKey: "showNotifications") else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(folderType.displayName) Is Over Limit"
        content.body = "\(folderType.displayName) is using \(ByteCountFormatter.string(fromByteCount: currentBytes, countStyle: .file)), above your \(ByteCountFormatter.string(fromByteCount: thresholdBytes, countStyle: .file)) alert threshold."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: AutomationNotificationID.folderHealth(folderType: folderType),
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Log.error("Error showing folder health alert notification: \(error)", category: .automation)
            } else {
                Log.info("Folder health alert notification shown for \(folderType.displayName)", category: .automation)
            }
        }
    }

    func notifyStaleRulesAlert(ruleNames: [String], thresholdDays: Int) {
        guard UserDefaults.standard.bool(forKey: "showNotifications") else { return }
        guard !ruleNames.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = ruleNames.count == 1 ? "Rule Needs Attention" : "\(ruleNames.count) Rules Need Attention"
        content.sound = .default

        let previewNames = Array(ruleNames.prefix(2))
        if ruleNames.count == 1, let ruleName = ruleNames.first {
            content.body = "\"\(ruleName)\" hasn't matched in \(thresholdDays) days."
        } else if ruleNames.count == 2 {
            content.body = "\(previewNames.joined(separator: " and ")) haven't matched in \(thresholdDays) days."
        } else {
            content.body = "\(previewNames.joined(separator: ", ")) and \(ruleNames.count - 2) more haven't matched in \(thresholdDays) days."
        }

        let request = UNNotificationRequest(
            identifier: AutomationNotificationID.staleRules,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Log.error("Error showing stale rules alert notification: \(error)", category: .automation)
            } else {
                Log.info("Stale rules alert notification shown for \(ruleNames.count) rules", category: .automation)
            }
        }
    }

    func clearFolderHealthAlert(folderType: BookmarkFolder.FolderType) {
        UNUserNotificationCenter.current().removeDeliveredNotifications(
            withIdentifiers: [AutomationNotificationID.folderHealth(folderType: folderType)]
        )
    }

    func clearStaleRulesAlert() {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [AutomationNotificationID.staleRules])
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

    static func autoOrganizeSummaryPayload(
        successCount: Int,
        failedCount: Int,
        skippedCount: Int
    ) -> AutomationNotificationPayload? {
        guard successCount > 0 || failedCount > 0 else { return nil }

        var sentences = ["Forma cleared \(successCount) file\(successCount == 1 ? "" : "s") from your queue based on your rules"]
        if failedCount > 0 {
            sentences.append("\(failedCount) still need\(failedCount == 1 ? "s" : "") your attention")
        }
        if skippedCount > 0 {
            sentences.append("\(skippedCount) \(skippedCount == 1 ? "is" : "are") still waiting for review")
        }

        return AutomationNotificationPayload(
            category: .progressWin,
            identifier: AutomationNotificationID.autoOrganizeSummary,
            title: "Auto-Organize Made Progress",
            body: sentences.joined(separator: ". ").ensureTrailingPeriod(),
            categoryIdentifier: nil
        )
    }

    static func backlogReminderPayload(
        pendingCount: Int,
        oldestAgeDays: Int?
    ) -> AutomationNotificationPayload {
        let identifier = oldestAgeDays != nil && pendingCount == 0
            ? AutomationNotificationID.ageReminder
            : AutomationNotificationID.backlogReminder

        let title: String
        let body: String
        if pendingCount > 0 {
            title = "Your Next Review Pass Is Ready"
            let fileLabel = "\(pendingCount) file\(pendingCount == 1 ? "" : "s")"
            var sentences = ["\(fileLabel) \(pendingCount == 1 ? "is" : "are") ready for your next review pass"]
            if let days = oldestAgeDays, days > 0 {
                sentences.append("The oldest has been waiting \(days) day\(days == 1 ? "" : "s")")
            }
            body = sentences.joined(separator: ". ").ensureTrailingPeriod()
        } else if let days = oldestAgeDays, days > 0 {
            title = "A Quick Review Pass Would Help"
            body = "Some files have been waiting \(days) day\(days == 1 ? "" : "s"). A quick review pass will get them moving again."
        } else {
            title = "Your Next Review Pass Is Ready"
            body = "A quick review pass will help keep your queue moving."
        }

        return AutomationNotificationPayload(
            category: .reminder,
            identifier: identifier,
            title: title,
            body: body,
            categoryIdentifier: "BACKLOG_REMINDER"
        )
    }

    static func ruleHighlightPayload(
        ruleName: String,
        matchCount: Int,
        ruleID: String
    ) -> AutomationNotificationPayload? {
        guard matchCount > 1 else { return nil }

        return AutomationNotificationPayload(
            category: .progressWin,
            identifier: AutomationNotificationID.ruleHighlight(ruleID: ruleID),
            title: "Rule Match: \(ruleName)",
            body: "\(matchCount) files matched this rule and are ready to organize.",
            categoryIdentifier: nil
        )
    }

    static func automationErrorPayload(
        type: AutomationErrorType,
        message: String
    ) -> AutomationNotificationPayload {
        AutomationNotificationPayload(
            category: .errorOrPermission,
            identifier: AutomationNotificationID.error(type: type.notificationIdentifier),
            title: type.title,
            body: type.supportiveMessage(detail: message),
            categoryIdentifier: nil
        )
    }

    private func enqueue(
        _ payload: AutomationNotificationPayload,
        completion: @escaping @Sendable (Error?) -> Void
    ) {
        let request = UNNotificationRequest(
            identifier: payload.identifier,
            content: Self.notificationContent(from: payload),
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: completion)
    }

    private static func notificationContent(from payload: AutomationNotificationPayload) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = payload.title
        content.body = payload.body
        content.sound = .default
        if let categoryIdentifier = payload.categoryIdentifier {
            content.categoryIdentifier = categoryIdentifier
        }
        return content
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

private extension String {
    func ensureTrailingPeriod() -> String {
        guard let last else { return self }
        if last == "." || last == "!" || last == "?" {
            return self
        }
        return self + "."
    }
}
