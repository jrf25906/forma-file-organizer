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

struct ProjectSpaceAdmissionEvidence: Sendable, Hashable {
    let existingProjectAssociation: String?
    let dominantDestinationProjectLabel: String?
    let dominantDestinationIsGenericHint: Bool
    let sourceFolderProjectLabel: String?
    let relatedFileProjectLabel: String?
}

enum ProjectSpaceAdmissionSignal: String, Sendable, Hashable {
    case existingProjectAssociation
    case dominantDestination
    case genericDestinationHint
    case sourceFolder
    case relatedFile
}

struct ProjectSpaceAdmissionEvidenceSnapshot: Sendable, Hashable {
    let projectLabel: String
    let existingProjectAssociation: String?
    let alignedSignalCount: Int
    let genericHintCount: Int
    let conflictingProjectLabels: [String]
    let supportingSignals: [ProjectSpaceAdmissionSignal]

    var isUnambiguous: Bool {
        conflictingProjectLabels.isEmpty
    }
}

enum ProjectSpaceAdmissionDecision: Sendable, Hashable {
    case existingMember(ProjectSpaceAdmissionEvidenceSnapshot)
    case strongConfirmed(ProjectSpaceAdmissionEvidenceSnapshot)
    case insufficient(ProjectSpaceAdmissionEvidenceSnapshot)

    var snapshot: ProjectSpaceAdmissionEvidenceSnapshot {
        switch self {
        case let .existingMember(snapshot),
             let .strongConfirmed(snapshot),
             let .insufficient(snapshot):
            return snapshot
        }
    }
}

struct ProjectAutomationTrustedScopeOwner: Sendable, Hashable {
    let id: UUID
    let scopeType: TrustedAutomationScopeType
    let displayName: String
    let status: TrustedAutomationScopeStatus
}

enum ProjectAutomationOwnerDecision: Sendable, Hashable {
    case projectPolicy(ProjectSpaceAdmissionEvidenceSnapshot)
    case trustedScope(ProjectAutomationTrustedScopeOwner)
    case none
}
