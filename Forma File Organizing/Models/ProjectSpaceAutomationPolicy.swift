import Foundation
import SwiftData

enum ProjectSpaceAutomationPolicyState: String, Codable, Sendable, CaseIterable {
    case draft
    case recommended
    case active
    case paused
    case revoked
}

enum ProjectSpaceAutomationTriggerKind: String, Codable, Sendable, CaseIterable {
    case manual
    case folderWatch
    case scheduledSweep
}

enum ProjectSpaceAutomationAdmissionMode: String, Codable, Sendable, CaseIterable {
    case manualReview
    case automatic
}

@Model
final class ProjectSpaceAutomationPolicy {
    var id: UUID
    var profileID: UUID
    private var workflowTemplateIDValue: String
    private var stateRaw: String
    private var admissionModeRaw: String
    private(set) var triggerKindRaws: [String]
    var createdAt: Date
    var updatedAt: Date
    var pausedAt: Date?
    var revokedAt: Date?

    var workflowTemplateID: String {
        get { workflowTemplateIDValue }
        set { workflowTemplateIDValue = Self.normalizedTemplateID(newValue) ?? workflowTemplateIDValue }
    }

    var state: ProjectSpaceAutomationPolicyState {
        get { ProjectSpaceAutomationPolicyState(rawValue: stateRaw) ?? .draft }
        set { stateRaw = newValue.rawValue }
    }

    var admissionMode: ProjectSpaceAutomationAdmissionMode {
        get { ProjectSpaceAutomationAdmissionMode(rawValue: admissionModeRaw) ?? .manualReview }
        set { admissionModeRaw = newValue.rawValue }
    }

    var triggerKinds: [ProjectSpaceAutomationTriggerKind] {
        get { triggerKindRaws.compactMap(ProjectSpaceAutomationTriggerKind.init(rawValue:)) }
        set { triggerKindRaws = Self.normalizedTriggerKindRaws(newValue) }
    }

    init(
        id: UUID = UUID(),
        profileID: UUID,
        workflowTemplateID: String,
        triggerKinds: [ProjectSpaceAutomationTriggerKind],
        admissionMode: ProjectSpaceAutomationAdmissionMode,
        state: ProjectSpaceAutomationPolicyState,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        pausedAt: Date? = nil,
        revokedAt: Date? = nil
    ) {
        self.id = id
        self.profileID = profileID
        self.workflowTemplateIDValue = Self.normalizedTemplateID(workflowTemplateID) ?? workflowTemplateID
        self.stateRaw = state.rawValue
        self.admissionModeRaw = admissionMode.rawValue
        self.triggerKindRaws = Self.normalizedTriggerKindRaws(triggerKinds)
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.pausedAt = pausedAt
        self.revokedAt = revokedAt
    }

    static func normalizedTemplateID(_ value: String?) -> String? {
        ProjectSpaceWorkflowProfile.normalizedOptionalText(value)
    }

    static func normalizedTriggerKindRaws(_ kinds: [ProjectSpaceAutomationTriggerKind]) -> [String] {
        var seen = Set<String>()
        return kinds.compactMap { kind in
            let rawValue = kind.rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawValue.isEmpty, seen.insert(rawValue).inserted else {
                return nil
            }
            return rawValue
        }
    }
}
