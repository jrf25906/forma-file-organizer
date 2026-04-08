import Foundation

enum WorkflowTemplateCatalog {
    static let shippedTemplates: [BuiltInWorkflowTemplate] = [
        BuiltInWorkflowTemplate(
            id: BuiltInWorkflowTemplate.StableID.receipts,
            displayName: "Receipt Intake",
            summaryText: "Rename incoming receipts, apply finance tags, and move them into your receipts archive.",
            renamePreset: .keepBaseNameWithDatePrefix,
            tagPolicy: .financialDocuments,
            allowedActions: BuiltInWorkflowTemplate.requiredActionShape
        ),
        BuiltInWorkflowTemplate(
            id: BuiltInWorkflowTemplate.StableID.screenshots,
            displayName: "Screenshot Cleanup",
            summaryText: "Rename screenshots with capture context, apply visual-reference tags, and move them out of Downloads.",
            renamePreset: .screenshotTimestamp,
            tagPolicy: .visualReference,
            allowedActions: BuiltInWorkflowTemplate.requiredActionShape
        ),
        BuiltInWorkflowTemplate(
            id: BuiltInWorkflowTemplate.StableID.projectDrop,
            displayName: "Project Drop Zone",
            summaryText: "Rename project intake files, apply project tags, and move them into the active project drop folder.",
            renamePreset: .projectIntakeSlug,
            tagPolicy: .projectContext,
            allowedActions: BuiltInWorkflowTemplate.requiredActionShape
        )
    ]

    static func template(for id: String?) -> BuiltInWorkflowTemplate? {
        guard let id else {
            return nil
        }
        return shippedTemplates.first(where: { $0.id == id })
    }
}
