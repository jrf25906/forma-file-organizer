import Foundation

enum WorkflowInvocationContext: Sendable, Hashable, CustomStringConvertible {
    case dashboardReview
    case reviewView
    case inspector
    case bulkOrganize
    case projectSpace(projectLabel: String)
    case trustedScopeScheduled(scopeDisplayName: String?)
    case trustedScopeRealtime(scopeDisplayName: String?)
    case trustedScopeInspection(scopeDisplayName: String?)

    // Compatibility shims for older call sites and tests that still reference the
    // original coarse contexts while the rest of the workflow engine migrates.
    static let reviewAdHoc: Self = .dashboardReview

    static func trustedScopeAutomation(scopeDisplayName: String?) -> Self {
        .trustedScopeScheduled(scopeDisplayName: scopeDisplayName)
    }

    var triggerSurface: ActivityItem.WorkflowTriggerSurface {
        switch self {
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
        case .trustedScopeScheduled, .trustedScopeRealtime:
            return true
        case .dashboardReview, .reviewView, .inspector, .bulkOrganize, .projectSpace, .trustedScopeInspection:
            return false
        }
    }

    var notificationDisplayName: String? {
        switch self {
        case .projectSpace(let projectLabel):
            return projectLabel
        case .trustedScopeScheduled(let scopeDisplayName),
             .trustedScopeRealtime(let scopeDisplayName),
             .trustedScopeInspection(let scopeDisplayName):
            return scopeDisplayName
        case .dashboardReview, .reviewView, .inspector, .bulkOrganize:
            return nil
        }
    }

    var description: String {
        switch self {
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
        case .trustedScopeScheduled(let scopeDisplayName):
            return "trustedScopeScheduled(scopeDisplayName: \(scopeDisplayName.map { "\"\($0)\"" } ?? "nil"))"
        case .trustedScopeRealtime(let scopeDisplayName):
            return "trustedScopeRealtime(scopeDisplayName: \(scopeDisplayName.map { "\"\($0)\"" } ?? "nil"))"
        case .trustedScopeInspection(let scopeDisplayName):
            return "trustedScopeInspection(scopeDisplayName: \(scopeDisplayName.map { "\"\($0)\"" } ?? "nil"))"
        }
    }
}
