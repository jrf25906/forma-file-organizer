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
        let scopeDisplayName: String?
        switch context.plan.definition.invocationContext {
        case .reviewAdHoc:
            scopeDisplayName = nil
        case .trustedScopeAutomation(let providedScopeDisplayName):
            scopeDisplayName = providedScopeDisplayName
        }

        let disposition = try await notificationService.notifyWorkflowCompletion(
            templateID: context.plan.definition.templateID,
            scopeDisplayName: scopeDisplayName,
            organizedFileCount: context.affectedFileCount
        )

        return WorkflowRunSideEffectExecutionResult(
            stepStatus: disposition == .skipped ? .skipped : .succeeded,
            disposition: disposition
        )
    }
}
