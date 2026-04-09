import Foundation

struct ProjectSpaceAutomationRecommendation: Sendable, Hashable {
    let workflowTemplateID: String
    let triggerKinds: [ProjectSpaceAutomationTriggerKind]
    let admissionMode: ProjectSpaceAutomationAdmissionMode
    let reasonSummary: String
}

struct ProjectSpaceAutomationRecommendationService {
    private static let dominantThreshold = 0.60
    private static let minimumDominantEvents = 2
    private static let recencyWindow: TimeInterval = 30 * 24 * 60 * 60
    private static let qualifyingActivityKinds: Set<FileOrganizationHistoryEntry.EventKind> = [
        .organized,
        .rekeyed
    ]

    func recommendedPolicies(
        for detail: ProjectSpaceDetail,
        now: Date
    ) -> [ProjectSpaceAutomationRecommendation] {
        guard let normalizedProjectLabel = normalized(detail.projectLabel),
              let dominantDestination = dominantDestination(for: detail, now: now),
              normalized(dominantDestination.destinationDisplayName) == normalizedProjectLabel else {
            return []
        }

        let supportingActivity = detail.recentActivity.filter { row in
            guard let destinationDisplayName = normalized(row.destinationDisplayName) else {
                return false
            }

            return destinationDisplayName == normalizedProjectLabel &&
                Self.qualifyingActivityKinds.contains(row.eventKind)
        }

        guard supportingActivity.count >= Self.minimumDominantEvents else {
            return []
        }

        return [
            ProjectSpaceAutomationRecommendation(
                workflowTemplateID: BuiltInWorkflowTemplate.StableID.projectDrop,
                triggerKinds: [.manual],
                admissionMode: .automatic,
                reasonSummary: "Recent project activity consistently moved files into \(normalizedProjectLabel)."
            )
        ]
    }

    private func dominantDestination(
        for detail: ProjectSpaceDetail,
        now: Date
    ) -> ProjectSpacePreferredDestination? {
        guard let first = detail.preferredDestinations.first else {
            return nil
        }

        let totalEvents = detail.preferredDestinations.reduce(0) { $0 + $1.eventCount }
        guard first.eventCount >= Self.minimumDominantEvents,
              totalEvents > 0,
              now >= first.lastUsedAt,
              now.timeIntervalSince(first.lastUsedAt) <= Self.recencyWindow else {
            return nil
        }

        let dominance = Double(first.eventCount) / Double(totalEvents)
        guard dominance >= Self.dominantThreshold else {
            return nil
        }

        return first
    }

    private func normalized(_ value: String?) -> String? {
        FileMetadataRecord.normalizedOptionalText(value)
    }
}
