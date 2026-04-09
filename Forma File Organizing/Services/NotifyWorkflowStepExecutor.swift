import Foundation

@MainActor
struct NotifyWorkflowStepExecutor: WorkflowRunSideEffectExecutor {
    let stepKind: WorkflowStepKind = .notify

    private let notificationService: WorkflowNotificationServing

    init(notificationService: WorkflowNotificationServing = NotificationService.shared) {
        self.notificationService = notificationService
    }

    func execute(
        context: WorkflowRunSideEffectExecutionContext
    ) async throws -> WorkflowRunSideEffectExecutionResult {
        let disposition = try await notificationService.notifyWorkflowCompletion(
            templateID: context.plan.definition.templateID,
            invocationContext: context.plan.definition.invocationContext,
            organizedFileCount: context.affectedFileCount
        )

        return WorkflowRunSideEffectExecutionResult(
            stepStatus: disposition == .skipped ? .skipped : .succeeded,
            disposition: disposition
        )
    }
}
