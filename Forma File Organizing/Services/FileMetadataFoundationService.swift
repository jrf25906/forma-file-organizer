import Foundation
import SwiftData

@MainActor
protocol FileMetadataFoundationServiceProtocol {
    @discardableResult
    func upsertRecordWithoutSaving(
        for path: String,
        displayName: String,
        fileExtension: String,
        timestamp: Date
    ) throws -> FileMetadataRecord?
}

@MainActor
final class FileMetadataFoundationService {
    private let modelContext: ModelContext
    private let featureFlags: FeatureFlagService

    #if DEBUG
    static var debugRecordTransitionHook: ((String, String, FileOrganizationHistoryEntry.EventKind) throws -> Void)?
    #endif

    private static let inspectorFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss 'UTC'"
        return formatter
    }()

    init(modelContext: ModelContext, featureFlags: FeatureFlagService = .shared) {
        self.modelContext = modelContext
        self.featureFlags = featureFlags
    }

    static func pathFallbackCanonicalIdentity(for path: String) -> String {
        FileMetadataRecord.Identity.pathFallback(path: path).canonicalIdentity
    }

    func resolveIdentity(for path: String) -> FileMetadataRecord.Identity {
        let normalizedPath = FileMetadataRecord.normalizedPath(path)
        let url = URL(fileURLWithPath: normalizedPath)

        do {
            let values = try url.resourceValues(forKeys: [
                .fileResourceIdentifierKey,
                .volumeIdentifierKey
            ])

            if let resourceIdentifier = values.fileResourceIdentifier,
               let volumeIdentifier = values.volumeIdentifier {
                return FileMetadataRecord.Identity.resourceBacked(
                    resourceIdentifier: Self.stringRepresentation(for: resourceIdentifier),
                    volumeIdentifier: Self.stringRepresentation(for: volumeIdentifier),
                    path: normalizedPath
                )
            }
        } catch {
            _ = error
        }

        return FileMetadataRecord.Identity.pathFallback(path: normalizedPath)
    }

    @discardableResult
    func upsertRecord(
        for path: String,
        displayName: String,
        fileExtension: String,
        timestamp: Date
    ) throws -> FileMetadataRecord? {
        let record = try upsertRecordWithoutSaving(
            for: path,
            displayName: displayName,
            fileExtension: fileExtension,
            timestamp: timestamp
        )
        try modelContext.save()
        return record
    }

    @discardableResult
    func upsertRecordWithoutSaving(
        for path: String,
        displayName: String,
        fileExtension: String,
        timestamp: Date
    ) throws -> FileMetadataRecord? {
        guard isEnabled else { return nil }

        let identity = resolveIdentity(for: path)
        if let existing = try record(matching: identity.canonicalIdentity) {
            existing.lastKnownPath = identity.normalizedPath
            existing.displayName = FileMetadataRecord.normalizedDisplayName(displayName)
            existing.fileExtension = fileExtension.lowercased()
            existing.lastSeenAt = timestamp
            return existing
        }

        let record = FileMetadataRecord(
            canonicalIdentity: identity.canonicalIdentity,
            identityKind: identity.kind,
            lastKnownPath: identity.normalizedPath,
            displayName: displayName,
            fileExtension: fileExtension,
            firstSeenAt: timestamp,
            lastSeenAt: timestamp
        )
        modelContext.insert(record)
        return record
    }

    @discardableResult
    func rekeyPathFallbackRecord(
        oldPath: String,
        newPath: String,
        timestamp: Date
    ) throws -> FileMetadataRecord? {
        guard isEnabled else { return nil }

        let record = try rekeyPathFallbackRecordWithoutSaving(
            oldPath: oldPath,
            newPath: newPath,
            timestamp: timestamp
        )
        try modelContext.save()
        return record
    }

    @discardableResult
    func appendHistoryEntry(
        for metadataRecord: FileMetadataRecord,
        eventKind: FileOrganizationHistoryEntry.EventKind,
        sourceSurface: FileOrganizationHistoryEntry.SourceSurface,
        fromPath: String?,
        toPath: String?,
        destinationDisplayName: String?,
        matchedRuleID: UUID?,
        detailsSummary: String?,
        timestamp: Date
    ) throws -> FileOrganizationHistoryEntry? {
        guard isEnabled else { return nil }

        let entry = try appendHistoryEntryWithoutSaving(
            for: metadataRecord,
            eventKind: eventKind,
            sourceSurface: sourceSurface,
            fromPath: fromPath,
            toPath: toPath,
            destinationDisplayName: destinationDisplayName,
            matchedRuleID: matchedRuleID,
            detailsSummary: detailsSummary,
            timestamp: timestamp
        )
        try modelContext.save()
        return entry
    }

    @discardableResult
    func recordTransition(
        from sourcePath: String,
        to destinationPath: String,
        displayName: String,
        fileExtension: String,
        eventKind: FileOrganizationHistoryEntry.EventKind,
        sourceSurface: FileOrganizationHistoryEntry.SourceSurface,
        destinationDisplayName: String? = nil,
        matchedRuleID: UUID? = nil,
        detailsSummary: String? = nil,
        timestamp: Date
    ) throws -> FileMetadataRecord? {
        guard isEnabled else { return nil }

        do {
            let normalizedSourcePath = FileMetadataRecord.normalizedPath(sourcePath)
            let normalizedDestinationPath = FileMetadataRecord.normalizedPath(destinationPath)

            let rekeyedRecord = try rekeyPathFallbackRecordWithoutSaving(
                oldPath: normalizedSourcePath,
                newPath: normalizedDestinationPath,
                timestamp: timestamp
            )

            let finalRecord: FileMetadataRecord
            if let rekeyedRecord {
                rekeyedRecord.lastKnownPath = normalizedDestinationPath
                rekeyedRecord.displayName = FileMetadataRecord.normalizedDisplayName(displayName)
                rekeyedRecord.fileExtension = fileExtension.lowercased()
                rekeyedRecord.lastSeenAt = timestamp
                finalRecord = rekeyedRecord
            } else if let destinationRecord = try upsertRecordWithoutSaving(
                for: normalizedDestinationPath,
                displayName: displayName,
                fileExtension: fileExtension,
                timestamp: timestamp
            ) {
                finalRecord = destinationRecord
            } else {
                return nil
            }

            _ = try appendHistoryEntryWithoutSaving(
                for: finalRecord,
                eventKind: eventKind,
                sourceSurface: sourceSurface,
                fromPath: normalizedSourcePath,
                toPath: normalizedDestinationPath,
                destinationDisplayName: destinationDisplayName,
                matchedRuleID: matchedRuleID,
                detailsSummary: detailsSummary,
                timestamp: timestamp
            )

            #if DEBUG
            if let debugRecordTransitionHook = Self.debugRecordTransitionHook {
                try debugRecordTransitionHook(normalizedSourcePath, normalizedDestinationPath, eventKind)
            }
            #endif

            try modelContext.save()
            return finalRecord
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    @discardableResult
    func applyProjectAssociationWithoutSaving(
        for metadataRecord: FileMetadataRecord,
        writeContext: ProjectAssociationWriteContext
    ) -> ProjectAssociationWriteContext.SourceSummaryCategory? {
        guard featureFlags.isEnabled(.metadataFoundation),
              featureFlags.isEnabled(.autoProjectAssociation) else {
            return nil
        }

        let resolver = MetadataProjectAssociationResolver()
        guard let resolvedCandidate = resolver.resolveCandidate(from: writeContext) else {
            return nil
        }

        switch resolvedCandidate.sourceSummaryCategory {
        case .destinationFolder:
            metadataRecord.projectAssociation = resolvedCandidate.projectAssociation
        case .relatedFilePattern:
            if FileMetadataRecord.normalizedOptionalText(metadataRecord.projectAssociation) == nil {
                metadataRecord.projectAssociation = resolvedCandidate.projectAssociation
            }
        }

        return resolvedCandidate.sourceSummaryCategory
    }

    func inspectorSummary(for path: String) -> FileMetadataInspectorSummary? {
        guard isEnabled else { return nil }

        let identity = resolveIdentity(for: path)
        guard let record = try? record(matching: identity.canonicalIdentity) else {
            return nil
        }

        return makeInspectorSummary(for: record)
    }

    private var isEnabled: Bool {
        featureFlags.isEnabled(.metadataFoundation)
    }

    private func record(matching canonicalIdentity: String) throws -> FileMetadataRecord? {
        var descriptor = FetchDescriptor<FileMetadataRecord>(
            predicate: #Predicate<FileMetadataRecord> { record in
                record.canonicalIdentity == canonicalIdentity
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func makeInspectorSummary(for record: FileMetadataRecord) -> FileMetadataInspectorSummary {
        let historyRows = record.historyEntries
            .sorted(by: { $0.timestamp > $1.timestamp })
            .map { entry in
                FileMetadataInspectorSummary.HistoryRow(
                    id: entry.id,
                    timestampSummary: Self.inspectorFormatter.string(from: entry.timestamp),
                    eventKind: entry.eventKind.rawValue,
                    sourceSurface: entry.sourceSurface.rawValue,
                    fromPath: entry.fromPath,
                    toPath: entry.toPath,
                    destinationDisplayName: entry.destinationDisplayName,
                    matchedRuleID: entry.matchedRuleID,
                    detailsSummary: entry.detailsSummary
                )
            }

        let shouldExposeProjectAssociation = featureFlags.isEnabled(.autoProjectAssociation)
        let projectAssociationSummary = shouldExposeProjectAssociation
            ? (FileMetadataRecord.normalizedOptionalText(record.projectAssociation) ?? "")
            : ""
        let projectAssociationSourceSummary = shouldExposeProjectAssociation
            ? projectAssociationSourceSummary(for: record)?.inspectorCopy
            : nil
        let tagsSummary = record.tags
            .map(FileMetadataRecord.normalizedTag)
            .filter { !$0.isEmpty }
            .joined(separator: ", ")

        let lastOrganizedSummary: String = {
            guard let lastOrganizedAt = record.lastOrganizedAt else {
                return "Last organized: never"
            }
            return "Last organized: \(Self.inspectorFormatter.string(from: lastOrganizedAt))"
        }()

        return FileMetadataInspectorSummary(
            firstSeenSummary: "First seen: \(Self.inspectorFormatter.string(from: record.firstSeenAt))",
            lastOrganizedSummary: lastOrganizedSummary,
            organizationCountSummary: Self.organizationCountSummary(for: record.organizationCount),
            tagsSummary: tagsSummary,
            projectAssociationSummary: projectAssociationSummary,
            projectAssociationSourceSummary: projectAssociationSourceSummary,
            recentHistoryRows: historyRows
        )
    }

    private static func organizationCountSummary(for count: Int) -> String {
        "\(count) organization\(count == 1 ? "" : "s")"
    }

    private static func isOrganizationLifecycleEvent(_ eventKind: FileOrganizationHistoryEntry.EventKind) -> Bool {
        switch eventKind {
        case .organized:
            return true
        case .scanned, .rekeyed, .undone, .noted:
            return false
        }
    }

    private func projectAssociationSourceSummary(
        for record: FileMetadataRecord
    ) -> ProjectAssociationWriteContext.SourceSummaryCategory? {
        if let explicit = explicitProjectAssociationSourceSummary(for: record) {
            return explicit
        }

        return inferredProjectAssociationSourceSummary(for: record)
    }

    private func explicitProjectAssociationSourceSummary(
        for record: FileMetadataRecord
    ) -> ProjectAssociationWriteContext.SourceSummaryCategory? {
        guard let storedAssociation = FileMetadataRecord.normalizedOptionalText(record.projectAssociation),
              let latestDestinationLabel = latestDestinationBackedProjectAssociationLabel(for: record),
              latestDestinationLabel == storedAssociation else {
            return nil
        }

        return .destinationFolder
    }

    private func inferredProjectAssociationSourceSummary(
        for record: FileMetadataRecord
    ) -> ProjectAssociationWriteContext.SourceSummaryCategory? {
        guard let storedAssociation = FileMetadataRecord.normalizedOptionalText(record.projectAssociation),
              let resolvedCandidate = resolveRelatedProjectAssociationCandidate(for: record),
              resolvedCandidate.projectAssociation == storedAssociation else {
            return nil
        }

        return resolvedCandidate.sourceSummaryCategory
    }

    private func latestDestinationBackedProjectAssociationLabel(
        for record: FileMetadataRecord
    ) -> String? {
        let sortedHistoryEntries = record.historyEntries.sorted(by: { $0.timestamp > $1.timestamp })
        for entry in sortedHistoryEntries {
            guard let label = destinationBackedProjectAssociationLabel(for: entry) else {
                continue
            }
            return label
        }

        return nil
    }

    private func destinationBackedProjectAssociationLabel(
        for entry: FileOrganizationHistoryEntry
    ) -> String? {
        if let destinationDisplayName = FileMetadataRecord.normalizedOptionalText(entry.destinationDisplayName) {
            return destinationDisplayName
        }

        guard let toPath = entry.toPath else {
            return nil
        }

        let destinationURL = URL(fileURLWithPath: toPath).standardizedFileURL
        let destinationFolderName = destinationURL.deletingLastPathComponent().lastPathComponent
        let normalizedLabel = MetadataProjectAssociationResolver().normalizeLabel(destinationFolderName)
        return normalizedLabel.isEmpty ? nil : normalizedLabel
    }

    private func resolveRelatedProjectAssociationCandidate(
        for record: FileMetadataRecord
    ) -> MetadataProjectAssociationResolver.ResolvedCandidate? {
        let descriptor = FetchDescriptor<ProjectCluster>(
            predicate: #Predicate<ProjectCluster> { !$0.isDismissed && !$0.isOrganized }
        )
        let clusters = (try? modelContext.fetch(descriptor)) ?? []
        let inferredCandidates = clusters.compactMap { cluster -> ProjectAssociationWriteContext.InferredCandidate? in
            guard cluster.filePaths.contains(record.lastKnownPath) else {
                return nil
            }

            return ProjectAssociationWriteContext.InferredCandidate(
                suggestedFolderName: cluster.suggestedFolderName,
                normalizedLabel: cluster.suggestedFolderName,
                confidence: cluster.confidenceScore
            )
        }

        let writeContext = ProjectAssociationWriteContext(
            resolvedExplicitDestinationFolderPath: nil,
            explicitSourceMode: false,
            inferredCandidates: inferredCandidates
        )
        return MetadataProjectAssociationResolver().resolveCandidate(from: writeContext)
    }

    @discardableResult
    private func rekeyPathFallbackRecordWithoutSaving(
        oldPath: String,
        newPath: String,
        timestamp: Date
    ) throws -> FileMetadataRecord? {
        let oldIdentity = FileMetadataRecord.Identity.pathFallback(path: oldPath)
        guard let sourceRecord = try record(matching: oldIdentity.canonicalIdentity),
              sourceRecord.identityKind == .pathFallback else {
            return nil
        }

        let newIdentity = FileMetadataRecord.Identity.pathFallback(path: newPath)
        if let destinationRecord = try record(matching: newIdentity.canonicalIdentity),
           destinationRecord !== sourceRecord {
            mergePathFallbackRecordWithoutSaving(sourceRecord, into: destinationRecord, timestamp: timestamp)
            return destinationRecord
        }

        sourceRecord.canonicalIdentity = newIdentity.canonicalIdentity
        sourceRecord.lastKnownPath = newIdentity.normalizedPath
        sourceRecord.lastSeenAt = timestamp
        sourceRecord.latestOrganizationStatus = .rekeyed
        return sourceRecord
    }

    @discardableResult
    private func appendHistoryEntryWithoutSaving(
        for metadataRecord: FileMetadataRecord,
        eventKind: FileOrganizationHistoryEntry.EventKind,
        sourceSurface: FileOrganizationHistoryEntry.SourceSurface,
        fromPath: String?,
        toPath: String?,
        destinationDisplayName: String?,
        matchedRuleID: UUID?,
        detailsSummary: String?,
        timestamp: Date
    ) throws -> FileOrganizationHistoryEntry? {
        let entry = FileOrganizationHistoryEntry(
            timestamp: timestamp,
            metadataRecord: metadataRecord,
            fileIdentitySnapshot: metadataRecord.canonicalIdentity,
            eventKind: eventKind,
            sourceSurface: sourceSurface,
            fromPath: fromPath,
            toPath: toPath,
            destinationDisplayName: destinationDisplayName,
            matchedRuleID: matchedRuleID,
            detailsSummary: detailsSummary
        )
        modelContext.insert(entry)

        if Self.isOrganizationLifecycleEvent(eventKind) {
            metadataRecord.organizationCount += 1
            metadataRecord.lastOrganizedAt = timestamp
        }
        switch eventKind {
        case .organized:
            metadataRecord.latestOrganizationStatus = .organized
        case .undone:
            metadataRecord.latestOrganizationStatus = .undone
        case .rekeyed:
            metadataRecord.latestOrganizationStatus = .rekeyed
        case .scanned, .noted:
            break
        }

        return entry
    }

    private func mergePathFallbackRecord(
        _ sourceRecord: FileMetadataRecord,
        into destinationRecord: FileMetadataRecord,
        timestamp: Date
    ) {
        mergePathFallbackRecordWithoutSaving(sourceRecord, into: destinationRecord, timestamp: timestamp)
    }

    private func mergePathFallbackRecordWithoutSaving(
        _ sourceRecord: FileMetadataRecord,
        into destinationRecord: FileMetadataRecord,
        timestamp: Date
    ) {
        let sourceHistoryEntries = sourceRecord.historyEntries
        for entry in sourceHistoryEntries {
            entry.metadataRecord = destinationRecord
        }

        destinationRecord.firstSeenAt = min(destinationRecord.firstSeenAt, sourceRecord.firstSeenAt)
        destinationRecord.lastSeenAt = max(destinationRecord.lastSeenAt, sourceRecord.lastSeenAt, timestamp)
        destinationRecord.lastKnownPath = FileMetadataRecord.normalizedPath(destinationRecord.lastKnownPath)
        destinationRecord.organizationCount += sourceRecord.organizationCount
        destinationRecord.lastOrganizedAt = Self.latestDate(
            destinationRecord.lastOrganizedAt,
            sourceRecord.lastOrganizedAt
        )
        destinationRecord.latestOrganizationStatus = .rekeyed

        if destinationRecord.displayName.isEmpty, !sourceRecord.displayName.isEmpty {
            destinationRecord.displayName = sourceRecord.displayName
        }
        if destinationRecord.fileExtension.isEmpty, !sourceRecord.fileExtension.isEmpty {
            destinationRecord.fileExtension = sourceRecord.fileExtension
        }
        if destinationRecord.tags.isEmpty, !sourceRecord.tags.isEmpty {
            destinationRecord.tags = sourceRecord.tags
        }
        if destinationRecord.projectAssociation == nil {
            destinationRecord.projectAssociation = sourceRecord.projectAssociation
        }
        if destinationRecord.notesSummary == nil {
            destinationRecord.notesSummary = sourceRecord.notesSummary
        }

        modelContext.delete(sourceRecord)
    }

    private static func latestDate(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            return max(lhs, rhs)
        case let (lhs?, nil):
            return lhs
        case let (nil, rhs?):
            return rhs
        case (nil, nil):
            return nil
        }
    }

    private static func stringRepresentation(for value: Any) -> String {
        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        case let data as Data:
            return data.base64EncodedString()
        case let uuid as UUID:
            return uuid.uuidString
        case let url as URL:
            return url.standardizedFileURL.path
        default:
            return String(describing: value)
        }
    }
}

extension FileMetadataFoundationService: FileMetadataFoundationServiceProtocol {}
