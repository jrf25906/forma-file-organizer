import Foundation

enum WorkflowInvocationContext: Sendable, Hashable, CustomStringConvertible {
    case menuBar
    case appIntent
    case finderService
    case spotlightIntent
    case dashboardReview
    case reviewView
    case inspector
    case bulkOrganize
    case projectSpace(projectLabel: String)
    case projectPolicyManual(projectLabel: String, policyName: String)
    case projectPolicyScheduled(projectLabel: String, policyName: String)
    case projectPolicyRealtime(projectLabel: String, policyName: String)
    case trustedScopeScheduled(scopeDisplayName: String?)
    case trustedScopeRealtime(scopeDisplayName: String?)
    case trustedScopeInspection(scopeDisplayName: String?)

    var triggerSurface: ActivityItem.WorkflowTriggerSurface {
        switch self {
        case .menuBar:
            return .menuBar
        case .appIntent:
            return .appIntent
        case .finderService:
            return .finderService
        case .spotlightIntent:
            return .spotlightIntent
        case .dashboardReview:
            return .reviewFlow
        case .reviewView:
            return .reviewView
        case .inspector:
            return .inspector
        case .bulkOrganize:
            return .bulkOrganize
        case .projectSpace:
            return .projectSpace
        case .projectPolicyManual:
            return .projectPolicyManual
        case .projectPolicyScheduled:
            return .projectPolicyScheduled
        case .projectPolicyRealtime:
            return .projectPolicyRealtime
        case .trustedScopeScheduled:
            return .scheduledAutomationPass
        case .trustedScopeRealtime:
            return .realtimeAutomationPass
        case .trustedScopeInspection:
            return .manualRefreshInspection
        }
    }

    var allowsWorkflowNotify: Bool {
        switch self {
        case .projectPolicyScheduled, .projectPolicyRealtime, .trustedScopeScheduled, .trustedScopeRealtime:
            return true
        case .menuBar,
             .appIntent,
             .finderService,
             .spotlightIntent,
             .dashboardReview,
             .reviewView,
             .inspector,
             .bulkOrganize,
             .projectSpace,
             .projectPolicyManual,
             .trustedScopeInspection:
            return false
        }
    }

    var notificationDisplayName: String? {
        switch self {
        case .projectSpace(let projectLabel):
            return projectLabel
        case .projectPolicyManual(let projectLabel, _),
             .projectPolicyScheduled(let projectLabel, _),
             .projectPolicyRealtime(let projectLabel, _):
            return projectLabel
        case .trustedScopeScheduled(let scopeDisplayName),
             .trustedScopeRealtime(let scopeDisplayName),
             .trustedScopeInspection(let scopeDisplayName):
            return scopeDisplayName
        case .menuBar, .appIntent, .finderService, .spotlightIntent, .dashboardReview, .reviewView, .inspector, .bulkOrganize:
            return nil
        }
    }

    var auditOwnerDisplayName: String? {
        notificationDisplayName
    }

    var notificationPolicyName: String? {
        switch self {
        case .projectPolicyManual(_, let policyName),
             .projectPolicyScheduled(_, let policyName),
             .projectPolicyRealtime(_, let policyName):
            return policyName
        case .menuBar,
             .appIntent,
             .finderService,
             .spotlightIntent,
             .dashboardReview,
             .reviewView,
             .inspector,
             .bulkOrganize,
             .projectSpace,
             .trustedScopeScheduled,
             .trustedScopeRealtime,
             .trustedScopeInspection:
            return nil
        }
    }

    var auditPolicyName: String? {
        notificationPolicyName
    }

    var supportsProjectContextMetadataSteps: Bool {
        switch self {
        case .projectSpace,
             .projectPolicyManual,
             .projectPolicyScheduled,
             .projectPolicyRealtime:
            return true
        case .menuBar,
             .appIntent,
             .finderService,
             .spotlightIntent,
             .dashboardReview,
             .reviewView,
             .inspector,
             .bulkOrganize,
             .trustedScopeScheduled,
             .trustedScopeRealtime,
             .trustedScopeInspection:
            return false
        }
    }

    var workflowProjectLabel: String? {
        let rawValue: String?

        switch self {
        case .projectSpace(let projectLabel),
             .projectPolicyManual(let projectLabel, _),
             .projectPolicyScheduled(let projectLabel, _),
             .projectPolicyRealtime(let projectLabel, _):
            rawValue = projectLabel
        case .menuBar,
             .appIntent,
             .finderService,
             .spotlightIntent,
             .dashboardReview,
             .reviewView,
             .inspector,
             .bulkOrganize,
             .trustedScopeScheduled,
             .trustedScopeRealtime,
             .trustedScopeInspection:
            rawValue = nil
        }

        guard let rawValue else {
            return nil
        }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var workflowNotesSummaryTarget: String? {
        guard let projectLabel = workflowProjectLabel else {
            return nil
        }

        if let policyName = auditPolicyName {
            return "Project: \(projectLabel) | Policy: \(policyName)"
        }

        return "Project: \(projectLabel)"
    }

    var description: String {
        switch self {
        case .menuBar:
            return "menuBar"
        case .appIntent:
            return "appIntent"
        case .finderService:
            return "finderService"
        case .spotlightIntent:
            return "spotlightIntent"
        case .dashboardReview:
            return "dashboardReview"
        case .reviewView:
            return "reviewView"
        case .inspector:
            return "inspector"
        case .bulkOrganize:
            return "bulkOrganize"
        case .projectSpace(let projectLabel):
            return "projectSpace(projectLabel: \"\(projectLabel)\")"
        case .projectPolicyManual(let projectLabel, let policyName):
            return "projectPolicyManual(projectLabel: \"\(projectLabel)\", policyName: \"\(policyName)\")"
        case .projectPolicyScheduled(let projectLabel, let policyName):
            return "projectPolicyScheduled(projectLabel: \"\(projectLabel)\", policyName: \"\(policyName)\")"
        case .projectPolicyRealtime(let projectLabel, let policyName):
            return "projectPolicyRealtime(projectLabel: \"\(projectLabel)\", policyName: \"\(policyName)\")"
        case .trustedScopeScheduled(let scopeDisplayName):
            return "trustedScopeScheduled(scopeDisplayName: \(scopeDisplayName.map { "\"\($0)\"" } ?? "nil"))"
        case .trustedScopeRealtime(let scopeDisplayName):
            return "trustedScopeRealtime(scopeDisplayName: \(scopeDisplayName.map { "\"\($0)\"" } ?? "nil"))"
        case .trustedScopeInspection(let scopeDisplayName):
            return "trustedScopeInspection(scopeDisplayName: \(scopeDisplayName.map { "\"\($0)\"" } ?? "nil"))"
        }
    }
}
