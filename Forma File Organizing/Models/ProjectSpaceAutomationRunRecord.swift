import Foundation
import SwiftData

enum ProjectSpaceAutomationRunStatus: String, Codable, Sendable, CaseIterable {
    case queued
    case running
    case succeeded
    case failed
    case revoked
}

@Model
final class ProjectSpaceAutomationRunRecord {
    var id: UUID
    var policyID: UUID
    private var workflowTemplateIDValue: String
    private var triggerKindRaw: String
    private var statusRaw: String
    var startedAt: Date
    var endedAt: Date?
    var createdAt: Date

    var workflowTemplateID: String {
        get { workflowTemplateIDValue }
        set { workflowTemplateIDValue = ProjectSpaceAutomationPolicy.normalizedTemplateID(newValue) ?? workflowTemplateIDValue }
    }

    var triggerKind: ProjectSpaceAutomationTriggerKind {
        get { ProjectSpaceAutomationTriggerKind(rawValue: triggerKindRaw) ?? .manual }
        set { triggerKindRaw = newValue.rawValue }
    }

    var status: ProjectSpaceAutomationRunStatus {
        get { ProjectSpaceAutomationRunStatus(rawValue: statusRaw) ?? .succeeded }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        policyID: UUID,
        workflowTemplateID: String,
        triggerKind: ProjectSpaceAutomationTriggerKind,
        status: ProjectSpaceAutomationRunStatus = .succeeded,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.policyID = policyID
        self.workflowTemplateIDValue = ProjectSpaceAutomationPolicy.normalizedTemplateID(workflowTemplateID) ?? workflowTemplateID
        self.triggerKindRaw = triggerKind.rawValue
        self.statusRaw = status.rawValue
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.createdAt = createdAt ?? startedAt
    }
}
