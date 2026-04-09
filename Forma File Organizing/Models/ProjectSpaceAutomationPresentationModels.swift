import Foundation

struct ProjectSpaceAutomationPolicySummary: Identifiable, Sendable, Hashable {
    let id: UUID
    let workflowTemplateID: String
    let workflowTemplateDisplayName: String
    let state: ProjectSpaceAutomationPolicyState
    let triggerKinds: [ProjectSpaceAutomationTriggerKind]
    let admissionMode: ProjectSpaceAutomationAdmissionMode
}

struct ProjectSpaceAutomationProfileSummary: Identifiable, Sendable, Hashable {
    let id: UUID
    let normalizedProjectLabel: String
    let policies: [ProjectSpaceAutomationPolicySummary]
}

struct ProjectSpaceAutomationBoardSnapshot: Sendable, Hashable {
    let profiles: [ProjectSpaceAutomationProfileSummary]
    let generatedAt: Date
}
