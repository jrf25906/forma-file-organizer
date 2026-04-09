import Foundation
import SwiftData

@Model
final class ProjectSpaceWorkflowProfile {
    @Attribute(.unique) var normalizedProjectLabel: String
    var preferredWorkflowTemplateID: String?
    var lastWorkflowRunID: UUID?
    var lastWorkflowCompletedAt: Date?
    var updatedAt: Date

    init(
        normalizedProjectLabel: String,
        preferredWorkflowTemplateID: String? = nil,
        lastWorkflowRunID: UUID? = nil,
        lastWorkflowCompletedAt: Date? = nil,
        updatedAt: Date = Date()
    ) {
        self.normalizedProjectLabel = Self.normalizedProjectLabelValue(normalizedProjectLabel)
        self.preferredWorkflowTemplateID = Self.normalizedOptionalText(preferredWorkflowTemplateID)
        self.lastWorkflowRunID = lastWorkflowRunID
        self.lastWorkflowCompletedAt = lastWorkflowCompletedAt
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
}
