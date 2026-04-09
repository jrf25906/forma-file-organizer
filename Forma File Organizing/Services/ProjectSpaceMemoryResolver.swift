import Foundation

@MainActor
struct ProjectSpaceMemoryResolver {
    struct MemberContext {
        let record: FileMetadataRecord
        let normalizedPath: String
    }

    private struct DestinationAggregate {
        let destinationDisplayName: String
        let destinationFolderPath: String
        let eventCount: Int
        let lastUsedAt: Date
    }

    private static let qualifyingDestinationKinds: Set<FileOrganizationHistoryEntry.EventKind> = [
        .organized,
        .rekeyed
    ]

    private static let qualifyingActivityKinds: Set<FileOrganizationHistoryEntry.EventKind> = [
        .organized,
        .rekeyed,
        .undone,
        .ignored,
        .noted
    ]

    private static let dominantSuggestionThreshold = 0.60
    private static let dominantSuggestionMinimumCount = 2
    private static let dominantSuggestionWindow: TimeInterval = 30 * 24 * 60 * 60
    private static let staleWorkflowWindow: TimeInterval = 30 * 24 * 60 * 60

    func buildOverview(
        for memberContexts: [MemberContext],
        now: Date = Date()
    ) -> ProjectSpaceOverview {
        let resolvedMembers = resolvedMembers(from: memberContexts)
        let preferredDestinations = buildPreferredDestinations(for: resolvedMembers, now: now)
        let recentActivityRows = buildRecentActivityRows(for: resolvedMembers)
        let folderHints = activeFolderHints(for: resolvedMembers)

        return ProjectSpaceOverview(
            currentFileCount: resolvedMembers.count,
            activeFolderCount: folderHints.count,
            activeFolderHints: folderHints,
            preferredDestinationCount: preferredDestinations.count,
            recentActivityCount: recentActivityRows.count,
            lastActivityAt: recentActivityRows.first?.timestamp
        )
    }

    func buildPreferredDestinations(
        for memberContexts: [MemberContext],
        now: Date = Date()
    ) -> [ProjectSpacePreferredDestination] {
        let resolvedMembers = resolvedMembers(from: memberContexts)
        let aggregates = destinationAggregates(for: resolvedMembers)

        return aggregates
            .map { aggregate in
                ProjectSpacePreferredDestination(
                    destinationDisplayName: aggregate.destinationDisplayName,
                    eventCount: aggregate.eventCount,
                    lastUsedAt: aggregate.lastUsedAt
                )
            }
            .sorted { lhs, rhs in
                if lhs.eventCount != rhs.eventCount {
                    return lhs.eventCount > rhs.eventCount
                }

                if lhs.lastUsedAt != rhs.lastUsedAt {
                    return lhs.lastUsedAt > rhs.lastUsedAt
                }

                return lhs.destinationDisplayName.localizedCaseInsensitiveCompare(rhs.destinationDisplayName) == .orderedAscending
            }
    }

    func buildRecentActivityRows(for memberContexts: [MemberContext]) -> [ProjectSpaceRecentActivityRow] {
        let resolvedMembers = resolvedMembers(from: memberContexts)

        var rows: [ProjectSpaceRecentActivityRow] = []
        for member in resolvedMembers {
            for entry in Array(member.record.historyEntries) {
                guard Self.qualifyingActivityKinds.contains(entry.eventKind) else {
                    continue
                }

                rows.append(
                    ProjectSpaceRecentActivityRow(
                        canonicalIdentity: member.record.canonicalIdentity,
                        fileDisplayName: member.record.displayName,
                        eventKind: entry.eventKind,
                        timestamp: entry.timestamp,
                        destinationDisplayName: destinationDisplayName(for: entry),
                        detailsSummary: entry.detailsSummary
                    )
                )
            }
        }

        return rows.sorted { lhs, rhs in
            if lhs.timestamp != rhs.timestamp {
                return lhs.timestamp > rhs.timestamp
            }

            return lhs.canonicalIdentity < rhs.canonicalIdentity
        }
    }

    func resolveWorkflowMemoryProjection(
        for detail: ProjectSpaceDetail,
        profile: ProjectSpaceWorkflowProfile?,
        now: Date = Date()
    ) -> ProjectSpaceWorkflowMemoryProjection? {
        if let profileProjection = workflowBackedProjection(profile: profile, now: now) {
            return profileProjection
        }

        guard let normalizedProjectLabel = normalized(detail.projectLabel),
              let dominantDestination = dominantDestination(for: detail, now: now),
              normalized(dominantDestination.destinationDisplayName) == normalizedProjectLabel else {
            return nil
        }

        let totalMoves = max(1, detail.preferredDestinations.reduce(0) { $0 + $1.eventCount })
        let summaryText = "Workflow memory is unavailable, so recommendations fall back to destination history favoring \(dominantDestination.destinationDisplayName) in \(dominantDestination.eventCount) of \(totalMoves) moves."

        return ProjectSpaceWorkflowMemoryProjection(
            state: .destinationFallback,
            successfulTemplateID: nil,
            successfulTemplateCount: 0,
            successfulTemplateLastSucceededAt: nil,
            dominantTriggerKind: nil,
            summaryText: summaryText
        )
    }

    func suggestDominantDestination(
        for memberContexts: [MemberContext],
        now: Date = Date()
    ) -> ProjectSpaceMemorySuggestion? {
        let resolvedMembers = resolvedMembers(from: memberContexts)
        let aggregates = destinationAggregates(for: resolvedMembers)
        guard let candidate = aggregates.first else {
            return nil
        }

        let totalQualifyingEvents = aggregates.reduce(0) { $0 + $1.eventCount }
        guard candidate.eventCount >= Self.dominantSuggestionMinimumCount else {
            return nil
        }

        let confidence = Double(candidate.eventCount) / Double(totalQualifyingEvents)
        guard confidence > Self.dominantSuggestionThreshold else {
            return nil
        }

        guard now >= candidate.lastUsedAt,
              now.timeIntervalSince(candidate.lastUsedAt) <= Self.dominantSuggestionWindow else {
            return nil
        }

        return ProjectSpaceMemorySuggestion(
            destinationDisplayName: candidate.destinationDisplayName,
            destinationFolderPath: candidate.destinationFolderPath,
            confidence: confidence,
            reasonSummary: "Most recent project activity favored \(candidate.destinationDisplayName) in \(candidate.eventCount) of \(totalQualifyingEvents) moves.",
            lastUsedAt: candidate.lastUsedAt
        )
    }

    func resolveDestination(for suggestion: ProjectSpaceMemorySuggestion) -> Destination? {
        guard let destinationFolderPath = suggestion.destinationFolderPath else {
            return nil
        }

        let bookmarkBackedRootURLs = FileMetadataFoundationService.projectSpaceBookmarkBackedRootURLs()
        guard let normalizedFolderPath = FileMetadataFoundationService.normalizedResolvablePath(
            for: destinationFolderPath,
            bookmarkBackedRootURLs: bookmarkBackedRootURLs
        ) else {
            return nil
        }

        let folderURL = URL(fileURLWithPath: normalizedFolderPath).standardizedFileURL
        let displayName = FileMetadataRecord.normalizedOptionalText(suggestion.destinationDisplayName)
            ?? folderURL.lastPathComponent
        guard !displayName.isEmpty else {
            return nil
        }

        return try? Destination.folder(from: folderURL, displayName: displayName)
    }

    private func resolvedMembers(from memberContexts: [MemberContext]) -> [MemberContext] {
        let bookmarkBackedRootURLs = FileMetadataFoundationService.projectSpaceBookmarkBackedRootURLs()

        return memberContexts.compactMap { (context: MemberContext) -> MemberContext? in
            guard let normalizedPath = FileMetadataFoundationService.normalizedResolvablePath(
                for: context.normalizedPath,
                bookmarkBackedRootURLs: bookmarkBackedRootURLs
            ),
                  FileMetadataRecord.normalizedOptionalText(context.record.projectAssociation) != nil else {
                return nil
            }

            return MemberContext(record: context.record, normalizedPath: normalizedPath)
        }
    }

    private func activeFolderHints(for memberContexts: [MemberContext]) -> [String] {
        let counts = resolvedMembers(from: memberContexts).reduce(into: [String: Int]()) { partialResult, member in
            guard let folderName = parentFolderDisplayName(for: member.normalizedPath) else {
                return
            }

            partialResult[folderName, default: 0] += 1
        }

        return counts
            .sorted { lhs, rhs in
                if lhs.value != rhs.value {
                    return lhs.value > rhs.value
                }

                return lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
            }
            .map(\.key)
    }

    private func destinationAggregates(for memberContexts: [MemberContext]) -> [DestinationAggregate] {
        var qualifyingEvents: [DestinationAggregate] = []
        for member in resolvedMembers(from: memberContexts) {
            for entry in Array(member.record.historyEntries) {
                guard Self.qualifyingDestinationKinds.contains(entry.eventKind),
                      let destinationDisplayName = destinationDisplayName(for: entry),
                      let destinationFolderPath = destinationFolderPath(for: entry) else {
                    continue
                }

                qualifyingEvents.append(
                    DestinationAggregate(
                        destinationDisplayName: destinationDisplayName,
                        destinationFolderPath: destinationFolderPath,
                        eventCount: 1,
                        lastUsedAt: entry.timestamp
                    )
                )
            }
        }

        let grouped = Dictionary(grouping: qualifyingEvents, by: \.destinationFolderPath)

        return grouped.compactMap { _, group in
            let representative = group.sorted { lhs, rhs in
                if lhs.lastUsedAt != rhs.lastUsedAt {
                    return lhs.lastUsedAt > rhs.lastUsedAt
                }

                return lhs.destinationDisplayName.localizedCaseInsensitiveCompare(rhs.destinationDisplayName) == .orderedAscending
            }.first

            guard let first = representative else {
                return nil
            }

            return DestinationAggregate(
                destinationDisplayName: first.destinationDisplayName,
                destinationFolderPath: first.destinationFolderPath,
                eventCount: group.count,
                lastUsedAt: group.map(\.lastUsedAt).max() ?? first.lastUsedAt
            )
        }
        .sorted { lhs, rhs in
            if lhs.eventCount != rhs.eventCount {
                return lhs.eventCount > rhs.eventCount
            }

            if lhs.lastUsedAt != rhs.lastUsedAt {
                return lhs.lastUsedAt > rhs.lastUsedAt
            }

            return lhs.destinationDisplayName.localizedCaseInsensitiveCompare(rhs.destinationDisplayName) == .orderedAscending
        }
    }

    private func destinationDisplayName(for entry: FileOrganizationHistoryEntry) -> String? {
        if let explicit = FileMetadataRecord.normalizedOptionalText(entry.destinationDisplayName) {
            return explicit
        }

        guard let toPath = entry.toPath else {
            return nil
        }

        return parentFolderDisplayName(for: toPath)
    }

    private func destinationFolderPath(for entry: FileOrganizationHistoryEntry) -> String? {
        guard let toPath = entry.toPath else {
            return nil
        }

        return URL(fileURLWithPath: toPath).standardizedFileURL.deletingLastPathComponent().path
    }

    private func parentFolderDisplayName(for path: String) -> String? {
        let folderURL = URL(fileURLWithPath: path).standardizedFileURL.deletingLastPathComponent()
        let folderName = folderURL.lastPathComponent
        guard !folderName.isEmpty, folderName != "/" else {
            return nil
        }

        return folderName
    }

    private func workflowBackedProjection(
        profile: ProjectSpaceWorkflowProfile?,
        now: Date
    ) -> ProjectSpaceWorkflowMemoryProjection? {
        guard let profile,
              let successfulTemplateID = normalized(profile.successfulTemplateID) else {
            return nil
        }

        let successfulTemplateCount = max(0, profile.successfulTemplateCount)
        let dominantTriggerKind = triggerKind(for: profile.dominantTriggerSurface)
        let state = workflowState(for: profile, now: now)
        let templateDisplayName = WorkflowTemplateCatalog.template(for: successfulTemplateID)?.displayName ?? successfulTemplateID
        let summaryText: String

        switch state {
        case .stable:
            let recencyText = relativeTimeText(
                for: profile.successfulTemplateLastSucceededAt ?? profile.updatedAt,
                now: now
            )
            let triggerText = triggerPatternText(for: dominantTriggerKind)
            summaryText = "Workflow memory is stable: \(templateDisplayName) succeeded \(successfulTemplateCount) times, most recently \(recencyText), mostly through \(triggerText)."
        case .stale:
            let recencyText = relativeTimeText(
                for: profile.successfulTemplateLastSucceededAt ?? profile.updatedAt,
                now: now
            )
            summaryText = "Workflow memory is stale: \(templateDisplayName) was successful \(successfulTemplateCount) times but last succeeded \(recencyText)."
        case .conflicted:
            summaryText = "Workflow memory is conflicted: latest successful template is \(templateDisplayName), but recent outcomes disagree."
        case .destinationFallback:
            return nil
        }

        return ProjectSpaceWorkflowMemoryProjection(
            state: state,
            successfulTemplateID: successfulTemplateID,
            successfulTemplateCount: successfulTemplateCount,
            successfulTemplateLastSucceededAt: profile.successfulTemplateLastSucceededAt,
            dominantTriggerKind: dominantTriggerKind,
            summaryText: summaryText
        )
    }

    private func workflowState(
        for profile: ProjectSpaceWorkflowProfile,
        now: Date
    ) -> ProjectSpaceWorkflowMemoryProjectionState {
        if profile.workflowMemoryStatus == .conflicted {
            return .conflicted
        }

        if profile.workflowMemoryStatus == .stale {
            return .stale
        }

        if let lastSucceededAt = profile.successfulTemplateLastSucceededAt,
           now >= lastSucceededAt,
           now.timeIntervalSince(lastSucceededAt) > Self.staleWorkflowWindow {
            return .stale
        }

        return .stable
    }

    private func dominantDestination(
        for detail: ProjectSpaceDetail,
        now: Date
    ) -> ProjectSpacePreferredDestination? {
        guard let first = detail.preferredDestinations.first else {
            return nil
        }

        let totalEvents = detail.preferredDestinations.reduce(0) { $0 + $1.eventCount }
        guard first.eventCount >= Self.dominantSuggestionMinimumCount,
              totalEvents > 0,
              now >= first.lastUsedAt,
              now.timeIntervalSince(first.lastUsedAt) <= Self.dominantSuggestionWindow else {
            return nil
        }

        let dominance = Double(first.eventCount) / Double(totalEvents)
        guard dominance >= Self.dominantSuggestionThreshold else {
            return nil
        }

        return first
    }

    private func triggerKind(
        for surface: ActivityItem.WorkflowTriggerSurface?
    ) -> ProjectSpaceAutomationTriggerKind? {
        switch surface {
        case .projectPolicyScheduled, .scheduledAutomationPass:
            return .scheduledSweep
        case .projectPolicyRealtime, .realtimeAutomationPass:
            return .folderWatch
        case .reviewFlow,
             .inspector,
             .bulkOrganize,
             .reviewView,
             .projectSpace,
             .projectPolicyManual,
             .manualRefreshInspection:
            return .manual
        case .none:
            return nil
        }
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

    private func normalized(_ value: String?) -> String? {
        FileMetadataRecord.normalizedOptionalText(value)
    }
}
