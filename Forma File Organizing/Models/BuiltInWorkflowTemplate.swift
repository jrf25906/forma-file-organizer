import Foundation

struct BuiltInWorkflowTemplate: Identifiable, Sendable, Hashable {
    enum StableID {
        static let receipts = "builtin.workflow.receipts.v1"
        static let screenshots = "builtin.workflow.screenshots.v1"
        static let projectDrop = "builtin.workflow.project-drop.v1"

        static let all: [String] = [
            receipts,
            screenshots,
            projectDrop
        ]
    }

    enum RenamePreset: String, Sendable, CaseIterable {
        case keepBaseNameWithDatePrefix
        case screenshotTimestamp
        case projectIntakeSlug
    }

    enum TagPolicy: String, Sendable, CaseIterable {
        case financialDocuments
        case visualReference
        case projectContext
    }

    enum NotificationPolicy: String, Sendable, CaseIterable {
        case never
        case trustedScopeOnly
    }

    enum ProjectAssociationPolicy: String, Sendable, CaseIterable {
        case invocationProjectLabel
    }

    enum WorkflowStatusPolicy: String, Sendable, CaseIterable {
        case organized
    }

    static let requiredActionShape: [TrustedAutomationAllowedAction] = [.rename, .tag, .move]

    let id: String
    let displayName: String
    let summaryText: String
    let renamePreset: RenamePreset
    let tagPolicy: TagPolicy
    let notificationPolicy: NotificationPolicy
    let projectAssociationPolicy: ProjectAssociationPolicy?
    let workflowStatusPolicy: WorkflowStatusPolicy?
    let allowedActions: [TrustedAutomationAllowedAction]
}
