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

    @discardableResult
    func applyProjectAssociationWithoutSaving(
        for metadataRecord: FileMetadataRecord,
        writeContext: ProjectAssociationWriteContext
    ) -> ProjectAssociationWriteContext.SourceSummaryCategory?

    @discardableResult
    func applyContentTagsWithoutSaving(
        for record: FileMetadataRecord,
        displayName: String,
        fileExtension: String,
        destinationDisplayName: String?,
        matchedRuleID: UUID?
    ) -> [MetadataContentTag]

    @discardableResult
    func applyWorkflowStatusForDiscoveryWithoutSaving(
        to record: FileMetadataRecord,
        wasCreated: Bool,
        timestamp: Date
    ) throws -> Bool
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
    func applyWorkflowStatusForDiscoveryWithoutSaving(
        to record: FileMetadataRecord,
        wasCreated: Bool,
        timestamp: Date
    ) throws -> Bool {
        guard isWorkflowStatusWriteEnabled,
              wasCreated,
              record.workflowStatus != .queued else {
            return false
        }

        record.workflowStatus = .queued
        _ = try appendHistoryEntryWithoutSaving(
            for: record,
            eventKind: .scanned,
            sourceSurface: .scan,
            fromPath: nil,
            toPath: record.lastKnownPath,
            destinationDisplayName: nil,
            matchedRuleID: nil,
            detailsSummary: nil,
            timestamp: timestamp
        )
        return true
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
    func appendIgnoredHistory(
        for metadataRecord: FileMetadataRecord,
        detailsSummary: String?,
        timestamp: Date
    ) throws -> FileOrganizationHistoryEntry? {
        guard isWorkflowStatusWriteEnabled else { return nil }

        do {
            let entry = try appendHistoryEntryWithoutSaving(
                for: metadataRecord,
                eventKind: .ignored,
                sourceSurface: .review,
                fromPath: metadataRecord.lastKnownPath,
                toPath: metadataRecord.lastKnownPath,
                destinationDisplayName: nil,
                matchedRuleID: nil,
                detailsSummary: detailsSummary,
                timestamp: timestamp
            )
            try modelContext.save()
            return entry
        } catch {
            modelContext.rollback()
            throw error
        }
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
        projectAssociationWriteContext: ProjectAssociationWriteContext? = nil,
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

            if let projectAssociationWriteContext {
                _ = applyProjectAssociationWithoutSaving(
                    for: finalRecord,
                    writeContext: projectAssociationWriteContext
                )
            }

            _ = applyContentTagsWithoutSaving(
                for: finalRecord,
                displayName: displayName,
                fileExtension: fileExtension,
                destinationDisplayName: destinationDisplayName,
                matchedRuleID: matchedRuleID
            )

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

    @discardableResult
    func applyContentTagsWithoutSaving(
        for record: FileMetadataRecord,
        displayName: String,
        fileExtension: String,
        destinationDisplayName: String?,
        matchedRuleID: UUID?
    ) -> [MetadataContentTag] {
        guard featureFlags.isEnabled(.metadataFoundation),
              featureFlags.isEnabled(.autoContentTags) else {
            return []
        }

        let resolver = MetadataContentTagResolver()
        let explicitCandidates = explicitContentTagCandidates(
            destinationDisplayName: destinationDisplayName,
            matchedRuleID: matchedRuleID,
            resolver: resolver
        )
        let inferredCandidates = resolver.inferTags(
            fileName: displayName,
            fileExtension: fileExtension,
            fileCategory: FileTypeCategory.category(for: fileExtension)
        )
        let newTags = resolver.resolveNewTags(
            existingRawValues: record.storedTagValuesForDuplicateSuppression(),
            explicitCandidates: explicitCandidates,
            inferredCandidates: inferredCandidates
        )

        record.appendContentTags(newTags)
        return newTags
    }

    func contentTagIndex(for paths: [String]) -> [String: Set<MetadataContentTag>] {
        guard featureFlags.isEnabled(.metadataFoundation),
              featureFlags.isEnabled(.autoContentTags) else {
            return [:]
        }

        var index: [String: Set<MetadataContentTag>] = [:]
        for normalizedPath in Set(paths.map(FileMetadataRecord.normalizedPath)) {
            let identity = resolveIdentity(for: normalizedPath)
            guard let record = try? record(matching: identity.canonicalIdentity) else {
                continue
            }

            let tags = record.builtInContentTags
            guard !tags.isEmpty else { continue }
            index[normalizedPath] = tags
        }

        return index
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

    private var isWorkflowStatusWriteEnabled: Bool {
        featureFlags.isEnabled(.metadataFoundation) &&
        featureFlags.isEnabled(.durableWorkflowStatus)
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
        let shouldExposeWorkflowStatus = featureFlags.isEnabled(.durableWorkflowStatus)
        let workflowStatusSummary = shouldExposeWorkflowStatus
            ? record.workflowStatus.map { "Status: \($0.rawValue)" }
            : nil
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
            workflowStatusSummary: workflowStatusSummary,
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
        case .ignored, .scanned, .rekeyed, .undone, .noted:
            return false
        }
    }

    private func applyWorkflowStatus(
        for record: FileMetadataRecord,
        eventKind: FileOrganizationHistoryEntry.EventKind
    ) {
        guard isWorkflowStatusWriteEnabled else { return }

        switch eventKind {
        case .organized:
            record.workflowStatus = .organized
        case .ignored:
            record.workflowStatus = .ignored
        case .undone:
            record.workflowStatus = .recovered
        case .scanned, .rekeyed, .noted:
            break
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
        guard let storedAssociation = FileMetadataRecord.normalizedOptionalText(record.projectAssociation) else {
            return nil
        }

        let resolver = MetadataProjectAssociationResolver()
        for entry in record.historyEntries.sorted(by: { $0.timestamp > $1.timestamp }) {
            guard entry.eventKind == .organized else {
                continue
            }

            guard let explicitDestinationFolderPath = standardizedDestinationFolderPath(for: entry) else {
                continue
            }

            let writeContext = ProjectAssociationWriteContext(
                resolvedExplicitDestinationFolderPath: explicitDestinationFolderPath,
                explicitSourceMode: false,
                inferredCandidates: []
            )
            guard let resolvedCandidate = resolver.resolveCandidate(from: writeContext),
                  resolvedCandidate.sourceSummaryCategory == .destinationFolder else {
                continue
            }

            return resolvedCandidate.projectAssociation == storedAssociation ? .destinationFolder : nil
        }

        return nil
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

    private func standardizedDestinationFolderPath(for entry: FileOrganizationHistoryEntry) -> String? {
        guard let toPath = entry.toPath else {
            return nil
        }

        return URL(fileURLWithPath: toPath).standardizedFileURL.deletingLastPathComponent().path
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

    private func explicitContentTagCandidates(
        destinationDisplayName: String?,
        matchedRuleID: UUID?,
        resolver: MetadataContentTagResolver
    ) -> [MetadataContentTag] {
        var candidates: [MetadataContentTag] = []

        if let destinationDisplayName,
           let tag = resolver.resolveExplicitTag(forAlias: destinationDisplayName) {
            candidates.append(tag)
        }

        guard let matchedRule = matchedRule(for: matchedRuleID) else {
            return candidates
        }

        if let categoryName = matchedRule.category?.name,
           let tag = resolver.resolveExplicitTag(forAlias: categoryName) {
            candidates.append(tag)
        }

        if let destinationAlias = matchedRule.destination?.displayName,
           let tag = resolver.resolveExplicitTag(forAlias: destinationAlias) {
            candidates.append(tag)
        }

        return candidates
    }

    private func matchedRule(for id: UUID?) -> Rule? {
        guard let id else { return nil }

        var descriptor = FetchDescriptor<Rule>(
            predicate: #Predicate<Rule> { rule in
                rule.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
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
        case .ignored:
            break
        case .undone:
            metadataRecord.latestOrganizationStatus = .undone
        case .rekeyed:
            metadataRecord.latestOrganizationStatus = .rekeyed
        case .scanned, .noted:
            break
        }

        applyWorkflowStatus(for: metadataRecord, eventKind: eventKind)

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
        destinationRecord.appendStoredTagsPreservingExistingOrder(sourceRecord.tags)
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
