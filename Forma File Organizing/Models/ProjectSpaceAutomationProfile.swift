import Foundation
import SwiftData

@Model
final class ProjectSpaceAutomationProfile {
    @Attribute(.unique) var normalizedProjectLabel: String

    var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var lastLegacyBootstrapAt: Date?

    init(
        id: UUID = UUID(),
        normalizedProjectLabel: String,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        lastLegacyBootstrapAt: Date? = nil
    ) {
        self.id = id
        self.normalizedProjectLabel = Self.normalizedProjectLabelValue(normalizedProjectLabel)
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.lastLegacyBootstrapAt = lastLegacyBootstrapAt
    }

    static func normalizedProjectLabelValue(_ value: String) -> String {
        ProjectSpaceWorkflowProfile.normalizedProjectLabelValue(value)
    }

    static func normalizedProjectLabelValue(_ value: String?) -> String? {
        ProjectSpaceWorkflowProfile.normalizedProjectLabelValue(value)
    }
}
