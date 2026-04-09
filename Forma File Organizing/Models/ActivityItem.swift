import Foundation
import SwiftData

@Model
final class ActivityItem {
    #Index<ActivityItem>([\.timestamp])

    var id: UUID
    var timestamp: Date

    /// Raw storage for activity type.
    /// SwiftData cannot reliably persist nested enums directly, so we store as String.
    /// Use the `activityType` computed property for type-safe access.
    private var activityTypeRaw: String

    /// Type-safe accessor for activity type
    var activityType: ActivityType {
        get { ActivityType(rawValue: activityTypeRaw) ?? .fileScanned }
        set { activityTypeRaw = newValue.rawValue }
    }

    var fileName: String
    var details: String
    var fileExtension: String?

    // Analytics tracking fields (v1.2.0)
    /// The UUID of the rule that was applied, if this is a ruleApplied activity.
    var ruleID: UUID?
    /// Number of files affected by the operation (for ruleApplied and bulkOrganized).
    var affectedFileCount: Int?
    var workflowRunID: UUID?
    var workflowTemplateID: String?
    private var workflowTriggerSurfaceRaw: String?
    private var workflowPrimaryStatusRaw: String?
    private var workflowRollbackStatusRaw: String?

    var workflowTriggerSurface: WorkflowTriggerSurface? {
        get {
            guard let workflowTriggerSurfaceRaw else { return nil }
            return WorkflowTriggerSurface(rawValue: workflowTriggerSurfaceRaw)
        }
        set {
            workflowTriggerSurfaceRaw = newValue?.rawValue
        }
    }

    var workflowPrimaryStatus: WorkflowRunPrimaryStatus? {
        get {
            guard let workflowPrimaryStatusRaw else { return nil }
            return WorkflowRunPrimaryStatus(rawValue: workflowPrimaryStatusRaw)
        }
        set {
            workflowPrimaryStatusRaw = newValue?.rawValue
        }
    }

    var workflowRollbackStatus: WorkflowRunRollbackStatus? {
        get {
            guard let workflowRollbackStatusRaw else { return nil }
            return WorkflowRunRollbackStatus(rawValue: workflowRollbackStatusRaw)
        }
        set {
            workflowRollbackStatusRaw = newValue?.rawValue
        }
    }

    var workflowProjection: WorkflowActivityProjection? {
        guard let workflowRunID,
              let workflowPrimaryStatus else {
            return nil
        }

        return WorkflowActivityProjection(
            runID: workflowRunID,
            templateID: workflowTemplateID,
            templateDisplayName: WorkflowTemplateCatalog.template(for: workflowTemplateID)?.displayName ?? fileName,
            triggerSurfaceLabel: Self.workflowTriggerSurfaceLabel(workflowTriggerSurface),
            fileCount: affectedFileCount ?? 0,
            statusText: Self.workflowStatusText(
                primaryStatus: workflowPrimaryStatus,
                rollbackStatus: workflowRollbackStatus ?? .notRequested
            ),
            rollbackText: Self.workflowRollbackText(
                primaryStatus: workflowPrimaryStatus,
                rollbackStatus: workflowRollbackStatus ?? .notRequested
            )
        )
    }

    init(
        activityType: ActivityType,
        fileName: String,
        details: String,
        fileExtension: String? = nil,
        ruleID: UUID? = nil,
        affectedFileCount: Int? = nil,
        workflowRunID: UUID? = nil,
        workflowTemplateID: String? = nil,
        workflowTriggerSurface: WorkflowTriggerSurface? = nil,
        workflowPrimaryStatus: WorkflowRunPrimaryStatus? = nil,
        workflowRollbackStatus: WorkflowRunRollbackStatus? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.activityTypeRaw = activityType.rawValue
        self.fileName = fileName
        self.details = details
        self.fileExtension = fileExtension
        self.ruleID = ruleID
        self.affectedFileCount = affectedFileCount
        self.workflowRunID = workflowRunID
        self.workflowTemplateID = workflowTemplateID
        self.workflowTriggerSurfaceRaw = workflowTriggerSurface?.rawValue
        self.workflowPrimaryStatusRaw = workflowPrimaryStatus?.rawValue
        self.workflowRollbackStatusRaw = workflowRollbackStatus?.rawValue
    }

    enum ActivityType: String, Codable {
        // File operations
        case fileScanned
        case fileOrganized
        case fileMoved
        case fileSkipped
        case fileDeleted
        case operationFailed

        // Rule operations
        case ruleCreated
        case ruleApplied
        case ruleDeleted
        case ruleUpdated

        // Onboarding & setup
        case onboardingCompleted
        case folderAccessGranted

        // Duplicate handling
        case duplicatesDetected
        case duplicateDeleted
        case duplicateKept

        // AI & learning
        case patternLearned
        case patternApplied
        case aiSuggestionAccepted
        case aiSuggestionRejected

        // Bulk operations
        case bulkOrganized
        case bulkUndone
        case bulkPartialFailure

        // Automation (v1.4)
        case automationScanCompleted
        case automationAutoOrganized
        case automationError
        case automationPaused
        case automationResumed
        case trustedAutomationScopePromoted
        case trustedAutomationScopePaused
        case trustedAutomationScopeResumed
        case trustedAutomationScopeRevoked
        case trustedAutomationScopeRunSummary
        case trustedAutomationScopeAttentionNeeded
        case workflowRunCompleted
        case workflowRunAttentionNeeded

        enum ToneCategory: String, Codable {
            case neutral
            case progressWin
            case reminder
            case errorOrPermission
        }

        var iconName: String {
            switch self {
            case .fileScanned: return "doc.badge.plus"
            case .fileOrganized: return "checkmark.circle.fill"
            case .fileMoved: return "arrow.right.circle.fill"
            case .fileSkipped: return "xmark.circle"
            case .fileDeleted: return "trash.fill"
            case .operationFailed: return "exclamationmark.triangle.fill"
            case .ruleCreated: return "plus.circle.fill"
            case .ruleApplied: return "wand.and.stars"
            case .ruleDeleted: return "trash.circle"
            case .ruleUpdated: return "pencil.circle.fill"
            case .onboardingCompleted: return "party.popper.fill"
            case .folderAccessGranted: return "folder.badge.plus"
            case .duplicatesDetected: return "doc.on.doc"
            case .duplicateDeleted: return "doc.badge.minus"
            case .duplicateKept: return "doc.badge.checkmark"
            case .patternLearned: return "brain"
            case .patternApplied: return "brain.head.profile"
            case .aiSuggestionAccepted: return "hand.thumbsup.fill"
            case .aiSuggestionRejected: return "hand.thumbsdown"
            case .bulkOrganized: return "square.stack.3d.up.fill"
            case .bulkUndone: return "arrow.uturn.backward.circle.fill"
            case .bulkPartialFailure: return "exclamationmark.circle.fill"
            case .automationScanCompleted: return "arrow.triangle.2.circlepath"
            case .automationAutoOrganized: return "wand.and.stars.inverse"
            case .automationError: return "exclamationmark.triangle.fill"
            case .automationPaused: return "pause.circle.fill"
            case .automationResumed: return "play.circle.fill"
            case .trustedAutomationScopePromoted: return "checkmark.shield.fill"
            case .trustedAutomationScopePaused: return "pause.badge.shield.fill"
            case .trustedAutomationScopeResumed: return "play.badge.shield.fill"
            case .trustedAutomationScopeRevoked: return "xmark.shield.fill"
            case .trustedAutomationScopeRunSummary: return "list.bullet.rectangle.portrait.fill"
            case .trustedAutomationScopeAttentionNeeded: return "exclamationmark.shield.fill"
            case .workflowRunCompleted: return "square.stack.3d.down.forward.fill"
            case .workflowRunAttentionNeeded: return "exclamationmark.square.fill"
            }
        }

        var displayName: String {
            switch self {
            case .fileScanned: return "Scanned"
            case .fileOrganized: return "Organized"
            case .fileMoved: return "Moved"
            case .fileSkipped: return "Skipped"
            case .fileDeleted: return "Deleted"
            case .operationFailed: return "Failed"
            case .ruleCreated: return "Rule Created"
            case .ruleApplied: return "Rule Applied"
            case .ruleDeleted: return "Rule Deleted"
            case .ruleUpdated: return "Rule Updated"
            case .onboardingCompleted: return "Setup Complete"
            case .folderAccessGranted: return "Access Granted"
            case .duplicatesDetected: return "Duplicates Found"
            case .duplicateDeleted: return "Duplicate Removed"
            case .duplicateKept: return "Original Kept"
            case .patternLearned: return "Pattern Learned"
            case .patternApplied: return "Pattern Applied"
            case .aiSuggestionAccepted: return "Suggestion Accepted"
            case .aiSuggestionRejected: return "Suggestion Rejected"
            case .bulkOrganized: return "Bulk Organized"
            case .bulkUndone: return "Bulk Undone"
            case .bulkPartialFailure: return "Partial Failure"
            case .automationScanCompleted: return "Review Queue Updated"
            case .automationAutoOrganized: return "Auto-Organize Progress"
            case .automationError: return "Automation Needs Attention"
            case .automationPaused: return "Automation Paused"
            case .automationResumed: return "Automation Resumed"
            case .trustedAutomationScopePromoted: return "Trusted Scope Enabled"
            case .trustedAutomationScopePaused: return "Trusted Scope Paused"
            case .trustedAutomationScopeResumed: return "Trusted Scope Resumed"
            case .trustedAutomationScopeRevoked: return "Trusted Scope Revoked"
            case .trustedAutomationScopeRunSummary: return "Trusted Scope Run"
            case .trustedAutomationScopeAttentionNeeded: return "Trusted Scope Needs Attention"
            case .workflowRunCompleted: return "Workflow Run"
            case .workflowRunAttentionNeeded: return "Workflow Needs Attention"
            }
        }

        var toneCategory: ToneCategory {
            switch self {
            case .automationAutoOrganized,
                 .automationResumed,
                 .trustedAutomationScopePromoted,
                 .trustedAutomationScopeResumed,
                 .trustedAutomationScopeRunSummary,
                 .workflowRunCompleted:
                return .progressWin
            case .automationScanCompleted,
                 .automationPaused,
                 .trustedAutomationScopePaused,
                 .trustedAutomationScopeRevoked:
                return .reminder
            case .automationError,
                 .trustedAutomationScopeAttentionNeeded,
                 .workflowRunAttentionNeeded:
                return .errorOrPermission
            default:
                return .neutral
            }
        }
    }

    enum WorkflowTriggerSurface: String, Codable {
        case reviewFlow
        case inspector
        case bulkOrganize
        case reviewView
        case projectSpace
        case projectPolicyManual
        case projectPolicyScheduled
        case projectPolicyRealtime
        case scheduledAutomationPass
        case realtimeAutomationPass
        case manualRefreshInspection
    }

    static func workflowTriggerSurfaceLabel(_ surface: WorkflowTriggerSurface?) -> String {
        switch surface {
        case .reviewFlow:
            return "Review"
        case .inspector:
            return "Inspector"
        case .bulkOrganize:
            return "Bulk organize"
        case .reviewView:
            return "Review view"
        case .projectSpace:
            return "Project space"
        case .projectPolicyManual:
            return "Project policy manual run"
        case .projectPolicyScheduled:
            return "Scheduled project policy"
        case .projectPolicyRealtime:
            return "Realtime project policy"
        case .scheduledAutomationPass:
            return "Scheduled trusted scope"
        case .realtimeAutomationPass:
            return "Realtime trusted scope"
        case .manualRefreshInspection:
            return "Trusted scope inspection"
        case .none:
            return "Workflow"
        }
    }

    static func workflowStatusText(
        primaryStatus: WorkflowRunPrimaryStatus,
        rollbackStatus: WorkflowRunRollbackStatus
    ) -> String {
        switch primaryStatus {
        case .queued:
            return "Queued"
        case .running:
            return "Running"
        case .succeeded:
            return "Succeeded"
        case .completedWithIssues:
            return "Completed with issues"
        case .failed:
            if rollbackStatus == .succeeded {
                return "Failed, changes rolled back"
            }
            return "Failed"
        case .canceled:
            return "Canceled"
        }
    }

    static func workflowRollbackText(
        primaryStatus: WorkflowRunPrimaryStatus,
        rollbackStatus: WorkflowRunRollbackStatus
    ) -> String {
        switch rollbackStatus {
        case .notRequested:
            return primaryStatus == .succeeded || primaryStatus == .completedWithIssues
                ? "Rollback available"
                : "Rollback unavailable"
        case .requested:
            return "Rollback requested"
        case .inProgress:
            return "Rollback in progress"
        case .succeeded:
            return "Rollback completed"
        case .failed:
            return "Rollback failed"
        }
    }

    var relativeTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

// Mock Data
extension ActivityItem {
    static var mocks: [ActivityItem] {
        [
            ActivityItem(
                activityType: .fileOrganized,
                fileName: "Invoice_2025_01.pdf",
                details: "Moved to Documents/Finance",
                fileExtension: "pdf"
            ),
            ActivityItem(
                activityType: .fileScanned,
                fileName: "Screenshot 2025-11-18.png",
                details: "Added from Desktop",
                fileExtension: "png"
            ),
            ActivityItem(
                activityType: .ruleCreated,
                fileName: "Screenshot Sweeper",
                details: "New rule for organizing screenshots"
            ),
            ActivityItem(
                activityType: .fileMoved,
                fileName: "Project_Proposal.docx",
                details: "Moved to Documents/Work",
                fileExtension: "docx"
            ),
            ActivityItem(
                activityType: .fileSkipped,
                fileName: "temp_file.txt",
                details: "Skipped by user",
                fileExtension: "txt"
            )
        ]
    }
}

struct WorkflowActivityProjection: Equatable {
    let runID: UUID
    let templateID: String?
    let templateDisplayName: String
    let triggerSurfaceLabel: String
    let fileCount: Int
    let statusText: String
    let rollbackText: String

    var canOpenRunDetail: Bool { true }
}
