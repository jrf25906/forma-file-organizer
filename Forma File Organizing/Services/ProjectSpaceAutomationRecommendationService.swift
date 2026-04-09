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
    private static let minimumWorkflowSuccesses = 2
    private static let recencyWindow: TimeInterval = 30 * 24 * 60 * 60
    private static let qualifyingActivityKinds: Set<FileOrganizationHistoryEntry.EventKind> = [
        .organized,
        .rekeyed
    ]

    func recommendedPolicies(
        for detail: ProjectSpaceDetail,
        now: Date
    ) -> [ProjectSpaceAutomationRecommendation] {
        if let workflowMemory = detail.workflowMemory,
           workflowMemory.state != .destinationFallback {
            return workflowBackedRecommendation(
                for: workflowMemory,
                now: now
            )
        }

        return dominantDestinationFallbackRecommendation(for: detail, now: now)
    }

    func dominantDestination(
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

    private func workflowBackedRecommendation(
        for workflowMemory: ProjectSpaceWorkflowMemoryProjection,
        now: Date
    ) -> [ProjectSpaceAutomationRecommendation] {
        guard workflowMemory.state == .stable,
              let templateID = normalized(workflowMemory.successfulTemplateID),
              workflowMemory.successfulTemplateCount >= Self.minimumWorkflowSuccesses,
              let lastSucceededAt = workflowMemory.successfulTemplateLastSucceededAt,
              now >= lastSucceededAt,
              now.timeIntervalSince(lastSucceededAt) <= Self.recencyWindow else {
            return []
        }

        let triggerKinds = workflowMemory.dominantTriggerKind.map { [$0] } ?? [.manual]
        let recencyText = relativeTimeText(for: lastSucceededAt, now: now)
        let triggerPatternText = triggerPatternText(for: workflowMemory.dominantTriggerKind)
        let templateDisplayName = WorkflowTemplateCatalog.template(for: templateID)?.displayName ?? templateID

        return [
            ProjectSpaceAutomationRecommendation(
                workflowTemplateID: templateID,
                triggerKinds: triggerKinds,
                admissionMode: .automatic,
                reasonSummary: "Workflow memory is stable: \(templateDisplayName) has \(workflowMemory.successfulTemplateCount) successful runs, last \(recencyText), mostly \(triggerPatternText)."
            )
        ]
    }

    private func dominantDestinationFallbackRecommendation(
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
                reasonSummary: "Workflow memory is unavailable, so recommendations fall back to destination history that consistently moved files into \(normalizedProjectLabel)."
            )
        ]
    }

    private func triggerPatternText(for triggerKind: ProjectSpaceAutomationTriggerKind?) -> String {
        switch triggerKind {
        case .manual:
            return "manual runs"
        case .folderWatch:
            return "realtime triggers"
        case .scheduledSweep:
            return "scheduled sweeps"
        case .none:
            return "mixed triggers"
        }
    }

    private func relativeTimeText(for date: Date, now: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: now)
    }
}
