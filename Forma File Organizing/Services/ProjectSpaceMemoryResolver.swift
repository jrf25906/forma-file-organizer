import Foundation

@MainActor
struct ProjectSpaceMemoryResolver {
    struct MemberContext {
        let record: FileMetadataRecord
        let normalizedPath: String
    }

    private struct DestinationAggregate {
        let destinationDisplayName: String
        let destinationFolderPath: String?
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

    private func resolvedMembers(from memberContexts: [MemberContext]) -> [MemberContext] {
        memberContexts.compactMap { context in
            guard let normalizedPath = standardizedResolvablePath(for: context.normalizedPath),
                  FileManager.default.fileExists(atPath: normalizedPath),
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

        let grouped = Dictionary(grouping: qualifyingEvents, by: \.destinationDisplayName)

        return grouped.compactMap { _, group in
            guard let first = group.max(by: { lhs, rhs in
                if lhs.lastUsedAt != rhs.lastUsedAt {
                    return lhs.lastUsedAt < rhs.lastUsedAt
                }
                return (lhs.destinationFolderPath ?? "") < (rhs.destinationFolderPath ?? "")
            }) else {
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

    private func standardizedResolvablePath(for path: String) -> String? {
        guard let trimmed = FileMetadataRecord.normalizedOptionalText(path),
              (trimmed as NSString).isAbsolutePath else {
            return nil
        }

        return FileMetadataRecord.normalizedPath(trimmed)
    }
}
