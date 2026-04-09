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

    func logBulkOrganized(
        count: Int,
        destination: String? = nil,
        origin: OrganizationRunOrigin = .reviewDriven,
        undoAvailable: Bool = true
    ) {
        var segments = [destination.map { "Moved to \($0)" } ?? "Multiple destinations"]
        segments.append(origin == .automation ? "Automatic pass" : "Review pass")
        segments.append(undoAvailable ? "Undo available" : "Final")
        let details = segments.joined(separator: ". ")
        log(.bulkOrganized, name: "\(count) files", details: details, affectedFileCount: count)
    }

    func logBulkUndone(count: Int, origin: OrganizationRunOrigin = .reviewDriven) {
        let details = origin == .automation
            ? "Restored to original locations from the last automatic pass."
            : "Restored to original locations from the last review pass."
        log(.bulkUndone, name: "\(count) files", details: details)
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
            ? "Queued \(newPending) new file\(newPending == 1 ? "" : "s") for your next review pass."
            : "No new files were added to your review queue."
        log(.automationScanCompleted, name: "\(filesScanned) files", details: details, affectedFileCount: filesScanned)
    }

    /// Log an auto-organize batch operation.
    ///
    /// - Parameters:
    ///   - successCount: Number of files successfully organized
    ///   - failedCount: Number of files that failed to organize
    ///   - skippedCount: Number of files skipped during preflight
    func logAutoOrganizeBatch(
        successCount: Int,
        failedCount: Int,
        skippedCount: Int = 0,
        skippedMissingDestination: Int = 0,
        skippedPermissionIssues: Int = 0,
        skippedConfidenceThreshold: Int = 0,
        skippedExcludedFromAutomation: Int = 0,
        undoAvailable: Bool = false
    ) {
        var segments = [
            successCount > 0
                ? "Cleared \(successCount) file\(successCount == 1 ? "" : "s") from the queue automatically"
                : "No files were cleared from the queue automatically"
        ]
        if failedCount > 0 {
            segments.append("\(failedCount) still need\(failedCount == 1 ? "s" : "") attention")
        }
        if skippedCount > 0 {
            let reasons = skipReasonDetails(
                missingDestination: skippedMissingDestination,
                permissionIssues: skippedPermissionIssues,
                confidenceThreshold: skippedConfidenceThreshold,
                excludedFromAutomation: skippedExcludedFromAutomation
            )
            if reasons.isEmpty {
                segments.append("\(skippedCount) \(skippedCount == 1 ? "is" : "are") still waiting for review")
            } else {
                segments.append(
                    "\(skippedCount) held back before the automatic pass: \(reasons.joined(separator: ", "))"
                )
            }
        }
        segments.append(undoAvailable ? "Undo available for the last automatic pass" : "Automatic changes are final")
        let details = segments.joined(separator: ". ") + "."
        log(.automationAutoOrganized, name: "Auto-Organize", details: details, affectedFileCount: successCount)
    }

    /// Log an automation error.
    ///
    /// - Parameters:
    ///   - type: Type of automation error
    ///   - message: Descriptive error message
    func logAutomationError(type: AutomationErrorType, message: String) {
        log(.automationError, name: type.title, details: type.supportiveMessage(detail: message))
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

    func logTrustedAutomationScopePromoted(scopeName: String, scopeType: TrustedAutomationScopeType) {
        log(
            .trustedAutomationScopePromoted,
            name: scopeName,
            details: "\(scopeType.displayName) scope is now trusted for automatic moves."
        )
    }

    func logTrustedAutomationScopePaused(scopeName: String) {
        log(
            .trustedAutomationScopePaused,
            name: scopeName,
            details: "Automatic moves are paused for this trusted scope."
        )
    }

    func logTrustedAutomationScopeResumed(scopeName: String) {
        log(
            .trustedAutomationScopeResumed,
            name: scopeName,
            details: "Automatic moves resumed for this trusted scope."
        )
    }

    func logTrustedAutomationScopeRevoked(scopeName: String) {
        log(
            .trustedAutomationScopeRevoked,
            name: scopeName,
            details: "This trusted scope will stay review-first until you enable it again."
        )
    }

    func logTrustedAutomationScopeRunSummary(
        scopeName: String,
        summary: String,
        affectedFileCount: Int?
    ) {
        log(
            .trustedAutomationScopeRunSummary,
            name: scopeName,
            details: summary,
            affectedFileCount: affectedFileCount
        )
    }

    func logTrustedAutomationScopeAttentionNeeded(
        scopeName: String,
        summary: String,
        affectedFileCount: Int?
    ) {
        log(
            .trustedAutomationScopeAttentionNeeded,
            name: scopeName,
            details: summary,
            affectedFileCount: affectedFileCount
        )
    }

    func logWorkflowRunSummary(
        run: WorkflowRunRecord,
        triggerSurface: ActivityItem.WorkflowTriggerSurface,
        affectedFileCount: Int
    ) {
        let triggerSurfaceLabel = ActivityItem.workflowTriggerSurfaceLabel(triggerSurface)
        let fileSummary = "\(affectedFileCount) file\(affectedFileCount == 1 ? "" : "s")"
        let isSuccessful = run.primaryStatus == .succeeded && run.rollbackStatus != .failed
        let statusSummary: String
        switch run.primaryStatus {
        case .queued:
            statusSummary = "queued"
        case .running:
            statusSummary = "running"
        case .succeeded:
            statusSummary = "succeeded"
        case .completedWithIssues:
            statusSummary = "completed with issues"
        case .failed:
            statusSummary = "failed"
        case .canceled:
            statusSummary = "canceled"
        }
        let ownershipContext = [run.ownerDisplayName, run.policyName]
            .compactMap { value -> String? in
                guard let value else { return nil }
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
        let ownershipSummary = ownershipContext.isEmpty
            ? ""
            : " (\(ownershipContext.joined(separator: " • ")))"
        let details = [
            "\(triggerSurfaceLabel) workflow run \(statusSummary) for \(fileSummary)\(ownershipSummary)",
            ActivityItem.workflowRollbackText(
                primaryStatus: run.primaryStatus,
                rollbackStatus: run.rollbackStatus
            )
        ].joined(separator: ". ") + "."

        let activity = ActivityItem(
            activityType: isSuccessful ? .workflowRunCompleted : .workflowRunAttentionNeeded,
            fileName: WorkflowTemplateCatalog.template(for: run.workflowTemplateID)?.displayName ?? "Workflow",
            details: details,
            affectedFileCount: affectedFileCount,
            workflowRunID: run.id,
            workflowTemplateID: run.workflowTemplateID,
            workflowTriggerSurface: triggerSurface,
            workflowPrimaryStatus: run.primaryStatus,
            workflowRollbackStatus: run.rollbackStatus
        )
        modelContext.insert(activity)
        save()
    }

    // MARK: - Private

    private func save() {
        do {
            try modelContext.save()
        } catch {
            Log.error("Failed to save activity: \(error.localizedDescription)", category: .analytics)
        }
    }

    private func skipReasonDetails(
        missingDestination: Int,
        permissionIssues: Int,
        confidenceThreshold: Int,
        excludedFromAutomation: Int
    ) -> [String] {
        var reasons: [String] = []
        if missingDestination > 0 {
            reasons.append("\(missingDestination) missing destination")
        }
        if permissionIssues > 0 {
            reasons.append("\(permissionIssues) permission issue\(permissionIssues == 1 ? "" : "s")")
        }
        if confidenceThreshold > 0 {
            reasons.append("\(confidenceThreshold) below confidence threshold")
        }
        if excludedFromAutomation > 0 {
            reasons.append("\(excludedFromAutomation) excluded from automation")
        }
        return reasons
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
