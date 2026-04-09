import Foundation

enum WorkflowExecutionEntryPoint: Sendable, Hashable {
    case invocationContext(WorkflowInvocationContext)
    case projectPolicy(
        policyID: UUID,
        triggerKind: ProjectSpaceAutomationTriggerKind,
        projectLabel: String,
        policyName: String
    )

    var invocationContext: WorkflowInvocationContext {
        switch self {
        case .invocationContext(let invocationContext):
            return invocationContext
        case .projectPolicy(_, let triggerKind, let projectLabel, let policyName):
            switch triggerKind {
            case .manual:
                return .projectPolicyManual(projectLabel: projectLabel, policyName: policyName)
            case .folderWatch:
                return .projectPolicyRealtime(projectLabel: projectLabel, policyName: policyName)
            case .scheduledSweep:
                return .projectPolicyScheduled(projectLabel: projectLabel, policyName: policyName)
            }
        }
    }

    var triggerSurface: ActivityItem.WorkflowTriggerSurface {
        invocationContext.triggerSurface
    }

    var auditOwnerDisplayName: String? {
        switch self {
        case .invocationContext(let invocationContext):
            return invocationContext.auditOwnerDisplayName
        case .projectPolicy(_, _, let projectLabel, _):
            return WorkflowRunRecord.normalizedOptionalText(projectLabel)
        }
    }

    var auditPolicyName: String? {
        switch self {
        case .invocationContext(let invocationContext):
            return invocationContext.auditPolicyName
        case .projectPolicy(_, _, _, let policyName):
            return WorkflowRunRecord.normalizedOptionalText(policyName)
        }
    }

    var notificationDisplayName: String? {
        switch self {
        case .invocationContext(let invocationContext):
            return invocationContext.notificationDisplayName
        case .projectPolicy(_, _, let projectLabel, _):
            return WorkflowRunRecord.normalizedOptionalText(projectLabel)
        }
    }

    var projectPolicyID: UUID? {
        guard case .projectPolicy(let policyID, _, _, _) = self else {
            return nil
        }

        return policyID
    }
}

struct WorkflowExecutionRequest: Sendable, Hashable {
    let templateID: String
    let scopeID: UUID
    let entryPoint: WorkflowExecutionEntryPoint

    init(
        templateID: String,
        scopeID: UUID = UUID(),
        invocationContext: WorkflowInvocationContext
    ) {
        self.templateID = templateID
        self.scopeID = scopeID
        self.entryPoint = .invocationContext(invocationContext)
    }

    init(
        templateID: String,
        scopeID: UUID = UUID(),
        entryPoint: WorkflowExecutionEntryPoint
    ) {
        self.templateID = templateID
        self.scopeID = scopeID
        self.entryPoint = entryPoint
    }

    var invocationContext: WorkflowInvocationContext {
        entryPoint.invocationContext
    }

    var triggerSurface: ActivityItem.WorkflowTriggerSurface {
        entryPoint.triggerSurface
    }

    var auditOwnerDisplayName: String? {
        entryPoint.auditOwnerDisplayName
    }

    var auditPolicyName: String? {
        entryPoint.auditPolicyName
    }

    var notificationDisplayName: String? {
        entryPoint.notificationDisplayName
    }

    var projectPolicyID: UUID? {
        entryPoint.projectPolicyID
    }

    func replacingScopeID(_ scopeID: UUID) -> WorkflowExecutionRequest {
        WorkflowExecutionRequest(
            templateID: templateID,
            scopeID: scopeID,
            entryPoint: entryPoint
        )
    }
}
