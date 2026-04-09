import Foundation

enum WorkflowInvocationContext: Sendable, Hashable {
    case reviewAdHoc
    case trustedScopeAutomation(scopeDisplayName: String?)
}
