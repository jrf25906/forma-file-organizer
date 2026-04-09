import Foundation
import SwiftData

@Model
final class ProjectSpaceWorkflowProfile {
    @Attribute(.unique) var normalizedProjectLabel: String
    var preferredWorkflowTemplateID: String?
    var lastWorkflowRunID: UUID?
    var lastWorkflowCompletedAt: Date?
    var successfulTemplateID: String?
    var successfulTemplateCount: Int
    var successfulTemplateLastSucceededAt: Date?
    private var dominantTriggerSurfaceRaw: String?
    var dominantTriggerSurfaceCount: Int
    var dominantTriggerSurfaceLastSeenAt: Date?
    var latestSuccessfulDestinationSignal: String?
    var latestSuccessfulDestinationAt: Date?
    private var workflowMemoryStatusRaw: String
    var updatedAt: Date

    var dominantTriggerSurface: ActivityItem.WorkflowTriggerSurface? {
        get {
            guard let dominantTriggerSurfaceRaw else { return nil }
            return ActivityItem.WorkflowTriggerSurface(rawValue: dominantTriggerSurfaceRaw)
        }
        set {
            dominantTriggerSurfaceRaw = Self.normalizedTriggerSurfaceSignal(newValue)?.rawValue
        }
    }

    var workflowMemoryStatus: WorkflowMemoryStatus {
        get { WorkflowMemoryStatus(rawValue: workflowMemoryStatusRaw) ?? .stable }
        set { workflowMemoryStatusRaw = newValue.rawValue }
    }

    init(
        normalizedProjectLabel: String,
        preferredWorkflowTemplateID: String? = nil,
        lastWorkflowRunID: UUID? = nil,
        lastWorkflowCompletedAt: Date? = nil,
        successfulTemplateID: String? = nil,
        successfulTemplateCount: Int = 0,
        successfulTemplateLastSucceededAt: Date? = nil,
        dominantTriggerSurface: ActivityItem.WorkflowTriggerSurface? = nil,
        dominantTriggerSurfaceCount: Int = 0,
        dominantTriggerSurfaceLastSeenAt: Date? = nil,
        latestSuccessfulDestinationSignal: String? = nil,
        latestSuccessfulDestinationAt: Date? = nil,
        workflowMemoryStatus: WorkflowMemoryStatus = .stable,
        updatedAt: Date = Date()
    ) {
        self.normalizedProjectLabel = Self.normalizedProjectLabelValue(normalizedProjectLabel)
        self.preferredWorkflowTemplateID = Self.normalizedTemplateSignal(preferredWorkflowTemplateID)
        self.lastWorkflowRunID = lastWorkflowRunID
        self.lastWorkflowCompletedAt = lastWorkflowCompletedAt
        self.successfulTemplateID = Self.normalizedTemplateSignal(successfulTemplateID)
        self.successfulTemplateCount = max(0, successfulTemplateCount)
        self.successfulTemplateLastSucceededAt = successfulTemplateLastSucceededAt
        self.dominantTriggerSurfaceRaw = Self.normalizedTriggerSurfaceSignal(dominantTriggerSurface)?.rawValue
        self.dominantTriggerSurfaceCount = max(0, dominantTriggerSurfaceCount)
        self.dominantTriggerSurfaceLastSeenAt = dominantTriggerSurfaceLastSeenAt
        self.latestSuccessfulDestinationSignal = Self.normalizedDestinationSignal(latestSuccessfulDestinationSignal)
        self.latestSuccessfulDestinationAt = latestSuccessfulDestinationAt
        self.workflowMemoryStatusRaw = workflowMemoryStatus.rawValue
        self.updatedAt = updatedAt
    }

    static func normalizedProjectLabelValue(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedProjectLabelValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = normalizedProjectLabelValue(value)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func normalizedOptionalText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func normalizedTemplateSignal(_ value: String?) -> String? {
        WorkflowRunRecord.normalizedWorkflowMemoryTemplateSignal(value)
    }

    static func normalizedTriggerSurfaceSignal(
        _ value: ActivityItem.WorkflowTriggerSurface?
    ) -> ActivityItem.WorkflowTriggerSurface? {
        WorkflowRunRecord.normalizedWorkflowMemoryTriggerSurface(value)
    }

    static func normalizedDestinationSignal(_ value: String?) -> String? {
        WorkflowFileActionRecord.normalizedWorkflowMemoryDestinationSignal(value)
    }
}
