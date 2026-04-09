import Foundation

struct WorkflowMemoryAttributionRequest: Sendable, Hashable {
    let normalizedProjectLabel: String
    let templateID: String
    let triggerSurface: ActivityItem.WorkflowTriggerSurface
    let ownerDisplayName: String?
    let policyName: String?
}

enum WorkflowExecutionEntryPoint: Sendable, Hashable {
    case invocationContext(WorkflowInvocationContext)
    case projectPolicy(
        policyID: UUID,
        triggerKind: ProjectSpaceAutomationTriggerKind,
        projectLabel: String,
        policyName: String
    )
    case trustedScope(
        scopeID: UUID,
        triggerSource: TrustedAutomationScopeRunTriggerSource,
        scopeDisplayName: String?
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
        case .trustedScope(_, let triggerSource, let scopeDisplayName):
            switch triggerSource {
            case .promotionPreview, .manualRefreshInspection:
                return .trustedScopeInspection(scopeDisplayName: scopeDisplayName)
            case .scheduledAutomationPass:
                return .trustedScopeScheduled(scopeDisplayName: scopeDisplayName)
            case .realtimeAutomationPass:
                return .trustedScopeRealtime(scopeDisplayName: scopeDisplayName)
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
        case .trustedScope(_, _, let scopeDisplayName):
            return WorkflowRunRecord.normalizedOptionalText(scopeDisplayName)
        }
    }

    var auditPolicyName: String? {
        switch self {
        case .invocationContext(let invocationContext):
            return invocationContext.auditPolicyName
        case .projectPolicy(_, _, _, let policyName):
            return WorkflowRunRecord.normalizedOptionalText(policyName)
        case .trustedScope:
            return nil
        }
    }

    var notificationDisplayName: String? {
        switch self {
        case .invocationContext(let invocationContext):
            return invocationContext.notificationDisplayName
        case .projectPolicy(_, _, let projectLabel, _):
            return WorkflowRunRecord.normalizedOptionalText(projectLabel)
        case .trustedScope(_, _, let scopeDisplayName):
            return WorkflowRunRecord.normalizedOptionalText(scopeDisplayName)
        }
    }

    var projectPolicyID: UUID? {
        guard case .projectPolicy(let policyID, _, _, _) = self else {
            return nil
        }

        return policyID
    }

    var trustedScopeID: UUID? {
        guard case .trustedScope(let scopeID, _, _) = self else {
            return nil
        }

        return scopeID
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

    var trustedScopeID: UUID? {
        entryPoint.trustedScopeID
    }

    var workflowMemoryAttribution: WorkflowMemoryAttributionRequest? {
        guard let normalizedProjectLabel = ProjectSpaceWorkflowProfile
            .normalizedProjectLabelValue(invocationContext.workflowProjectLabel) else {
            return nil
        }

        return WorkflowMemoryAttributionRequest(
            normalizedProjectLabel: normalizedProjectLabel,
            templateID: templateID,
            triggerSurface: triggerSurface,
            ownerDisplayName: auditOwnerDisplayName,
            policyName: auditPolicyName
        )
    }

    func replacingScopeID(_ scopeID: UUID) -> WorkflowExecutionRequest {
        WorkflowExecutionRequest(
            templateID: templateID,
            scopeID: scopeID,
            entryPoint: entryPoint
        )
    }
}
