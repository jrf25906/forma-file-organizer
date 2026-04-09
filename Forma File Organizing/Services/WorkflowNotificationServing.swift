import Foundation

/// Narrow workflow-native notification boundary used by workflow step execution.
@MainActor
protocol WorkflowNotificationServing: AnyObject {
    func notifyWorkflowCompletion(
        templateID: String,
        scopeDisplayName: String?,
        organizedFileCount: Int
    ) async throws -> WorkflowFileDisposition
}
