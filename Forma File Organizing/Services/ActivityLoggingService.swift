import Foundation
import SwiftData

/// Centralized service for logging user activities to SwiftData.
///
/// Provides a unified API for tracking user actions across the app:
/// - File operations (organize, move, delete, skip)
/// - Rule management (create, update, delete)
/// - Onboarding and setup milestones
/// - Duplicate handling
/// - AI/ML interactions
/// - Bulk operations
///
/// Activity logging is intentionally non-blocking; failures are logged
/// but never propagated to callers since tracking is non-critical.
@MainActor
final class ActivityLoggingService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Core Logging

    /// Log a generic activity. Prefer using the specialized methods below.
    func log(
        _ type: ActivityItem.ActivityType,
        name: String,
        details: String,
        fileExtension: String? = nil,
        ruleID: UUID? = nil,
        affectedFileCount: Int? = nil
    ) {
        let activity = ActivityItem(
            activityType: type,
            fileName: name,
            details: details,
            fileExtension: fileExtension,
            ruleID: ruleID,
            affectedFileCount: affectedFileCount
        )
        modelContext.insert(activity)
        save()
    }

    // MARK: - File Operations

    func logFileOrganized(fileName: String, destination: String, fileExtension: String?) {
        log(.fileOrganized, name: fileName, details: "Moved to \(destination)", fileExtension: fileExtension)
    }

    func logFileMoved(fileName: String, from source: String, to destination: String, fileExtension: String?) {
        log(.fileMoved, name: fileName, details: "From \(source) to \(destination)", fileExtension: fileExtension)
    }

    func logFileSkipped(fileName: String, reason: String, fileExtension: String?) {
        log(.fileSkipped, name: fileName, details: reason, fileExtension: fileExtension)
    }

    func logFileDeleted(fileName: String, fileExtension: String?) {
        log(.fileDeleted, name: fileName, details: "Permanently removed", fileExtension: fileExtension)
    }

    func logOperationFailed(fileName: String, operation: String, errorMessage: String, fileExtension: String?) {
        log(.operationFailed, name: fileName, details: "\(operation) failed: \(errorMessage)", fileExtension: fileExtension)
    }

    // MARK: - Rule Operations

    func logRuleCreated(ruleName: String, conditionSummary: String) {
        log(.ruleCreated, name: ruleName, details: conditionSummary)
    }

    func logRuleUpdated(ruleName: String, changeDescription: String) {
        log(.ruleUpdated, name: ruleName, details: changeDescription)
    }

    /// Log rule update without specifying changes (for simple save operations)
    func logRuleUpdated(ruleName: String) {
        log(.ruleUpdated, name: ruleName, details: "Rule saved")
    }

    func logRuleDeleted(ruleName: String) {
        log(.ruleDeleted, name: ruleName, details: "Rule removed")
    }

    func logBulkRulesCreated(count: Int, source: String) {
        log(.ruleCreated, name: "\(count) rules", details: source)
    }

    func logBulkRulesDeleted(count: Int) {
        log(.ruleDeleted, name: "\(count) rules", details: "Bulk deletion")
    }

    func logRuleApplied(ruleName: String, ruleID: UUID, matchCount: Int) {
        log(
            .ruleApplied,
            name: ruleName,
            details: "Applied to \(matchCount) file(s)",
            ruleID: ruleID,
            affectedFileCount: matchCount
        )
    }

    func logRulePrioritiesUpdated(count: Int) {
        log(.ruleUpdated, name: "\(count) rules", details: "Priority order updated")
    }

    // MARK: - Onboarding & Setup

    func logOnboardingCompleted(templateName: String? = nil) {
        let details = templateName.map { "Template: \($0)" } ?? "Setup completed"
        log(.onboardingCompleted, name: "Forma Setup", details: details)
    }

    func logFolderAccessGranted(folderName: String) {
        log(.folderAccessGranted, name: folderName, details: "Access granted")
    }

    // MARK: - Duplicate Handling

    func logDuplicatesDetected(count: Int, totalSize: String) {
        log(.duplicatesDetected, name: "\(count) duplicates", details: "Total size: \(totalSize)")
    }

    func logDuplicateDeleted(fileName: String, savedSpace: String, fileExtension: String?) {
        log(.duplicateDeleted, name: fileName, details: "Freed \(savedSpace)", fileExtension: fileExtension)
    }

    func logDuplicateKept(fileName: String, fileExtension: String?) {
        log(.duplicateKept, name: fileName, details: "Marked as original", fileExtension: fileExtension)
    }

    // MARK: - AI & Learning

    func logPatternLearned(patternDescription: String, confidence: Double) {
        let confidencePercent = Int(confidence * 100)
        log(.patternLearned, name: "New Pattern", details: "\(patternDescription) (\(confidencePercent)% confidence)")
    }

    func logPatternApplied(patternDescription: String, fileName: String, fileExtension: String?) {
        log(.patternApplied, name: fileName, details: "Pattern: \(patternDescription)", fileExtension: fileExtension)
    }

    func logAISuggestionAccepted(fileName: String, suggestion: String, fileExtension: String?) {
        log(.aiSuggestionAccepted, name: fileName, details: suggestion, fileExtension: fileExtension)
    }

    func logAISuggestionRejected(fileName: String, suggestion: String, fileExtension: String?) {
        log(.aiSuggestionRejected, name: fileName, details: suggestion, fileExtension: fileExtension)
    }

    // MARK: - Bulk Operations

    func logBulkOrganized(count: Int, destination: String? = nil) {
        let details = destination.map { "Moved to \($0)" } ?? "Multiple destinations"
        log(.bulkOrganized, name: "\(count) files", details: details, affectedFileCount: count)
    }

    func logBulkUndone(count: Int) {
        log(.bulkUndone, name: "\(count) files", details: "Restored to original locations")
    }

    func logBulkPartialFailure(successCount: Int, failedCount: Int, firstError: String?) {
        let errorDetail = firstError.map { " (\($0))" } ?? ""
        log(.bulkPartialFailure, name: "\(failedCount) of \(successCount + failedCount) files", details: "Failed to organize\(errorDetail)")
    }

    // MARK: - Automation (v1.4)

    /// Log completion of an automated scan cycle.
    ///
    /// - Parameters:
    ///   - filesScanned: Total number of files scanned
    ///   - newPending: Number of new files requiring review
    func logAutomationScanCompleted(filesScanned: Int, newPending: Int) {
        let details = newPending > 0
            ? "Found \(newPending) new file\(newPending == 1 ? "" : "s") to review"
            : "No new files found"
        log(.automationScanCompleted, name: "\(filesScanned) files", details: details, affectedFileCount: filesScanned)
    }

    /// Log an auto-organize batch operation.
    ///
    /// - Parameters:
    ///   - successCount: Number of files successfully organized
    ///   - failedCount: Number of files that failed to organize
    ///   - skippedCount: Number of files skipped (didn't meet confidence threshold)
    func logAutoOrganizeBatch(successCount: Int, failedCount: Int, skippedCount: Int = 0) {
        var details = "Organized \(successCount) file\(successCount == 1 ? "" : "s")"
        if failedCount > 0 {
            details += ", \(failedCount) failed"
        }
        if skippedCount > 0 {
            details += ", \(skippedCount) skipped"
        }
        log(.automationAutoOrganized, name: "Auto-Organize", details: details, affectedFileCount: successCount)
    }

    /// Log an automation error.
    ///
    /// - Parameters:
    ///   - type: Type of automation error
    ///   - message: Descriptive error message
    func logAutomationError(type: AutomationErrorType, message: String) {
        log(.automationError, name: type.title, details: message)
    }

    /// Log automation being paused by the user.
    ///
    /// - Parameter reason: Optional reason for pausing
    func logAutomationPaused(reason: String? = nil) {
        let details = reason ?? "Paused by user"
        log(.automationPaused, name: "Automation", details: details)
    }

    /// Log automation being resumed.
    func logAutomationResumed() {
        log(.automationResumed, name: "Automation", details: "Resumed by user")
    }

    // MARK: - Private

    private func save() {
        do {
            try modelContext.save()
        } catch {
            Log.error("Failed to save activity: \(error.localizedDescription)", category: .analytics)
        }
    }
}

// MARK: - Convenience Extension for Optional Context

extension ActivityLoggingService {
    /// Factory method for optional context scenarios.
    /// Returns nil if context is nil, allowing optional chaining: `service?.logFileOrganized(...)`
    static func create(from context: ModelContext?) -> ActivityLoggingService? {
        guard let context = context else { return nil }
        return ActivityLoggingService(modelContext: context)
    }
}
