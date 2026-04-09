import Foundation

struct WorkflowCompensationAction {
    let stepKind: WorkflowStepKind
    let fileIdentity: String
    let sourcePath: String?
    let destinationPath: String?
    let metadataDelta: WorkflowFileMetadataDelta?
    let apply: @MainActor () throws -> Void
}

struct WorkflowCompensationOutcome {
    let action: WorkflowCompensationAction
    let error: Error?

    var succeeded: Bool {
        error == nil
    }
}

@MainActor
final class WorkflowRollbackCoordinator {
    func rollback(_ actions: [WorkflowCompensationAction]) async -> [WorkflowCompensationOutcome] {
        var outcomes: [WorkflowCompensationOutcome] = []
        outcomes.reserveCapacity(actions.count)

        for action in actions.reversed() {
            do {
                try action.apply()
                outcomes.append(WorkflowCompensationOutcome(action: action, error: nil))
            } catch {
                outcomes.append(WorkflowCompensationOutcome(action: action, error: error))
            }
        }

        return outcomes
    }
}
