import Foundation
import SwiftData
import Darwin

@MainActor
protocol FileMetadataFoundationServiceProtocol {
    typealias UpsertResult = (record: FileMetadataRecord, wasCreated: Bool)

    @discardableResult
    func upsertRecordWithoutSaving(
        for path: String,
        displayName: String,
        fileExtension: String,
        timestamp: Date
    ) throws -> FileMetadataRecord?

    @discardableResult
    func upsertRecordForDiscoveryWithoutSaving(
        for path: String,
        displayName: String,
        fileExtension: String,
        timestamp: Date
    ) throws -> UpsertResult?

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

    func admitToProjectSpace(
        canonicalIdentity: String,
        projectLabel: String,
        detailsSummary: String,
        timestamp: Date
    ) throws
}

extension FileMetadataFoundationServiceProtocol {
    func admitToProjectSpace(
        canonicalIdentity: String,
        projectLabel: String,
        detailsSummary: String,
        timestamp: Date
    ) throws {}
}

struct ProjectSpaceAdmissionFileSnapshot: Sendable, Hashable {
    let canonicalIdentity: String?
    let normalizedPath: String
    let projectAssociation: String?
    let sourceFolderHint: String?
}

struct WorkflowProjectAssociationMutationPreview: Sendable, Hashable {
    let previousProjectAssociation: String?
    let targetProjectAssociation: String

    var willChange: Bool {
        previousProjectAssociation != targetProjectAssociation
    }
}

struct WorkflowStatusMutationPreview: Sendable, Hashable {
    let previousWorkflowStatus: MetadataWorkflowStatus?
    let targetWorkflowStatus: MetadataWorkflowStatus

    var willChange: Bool {
        previousWorkflowStatus != targetWorkflowStatus
    }
}

@MainActor
final class FileMetadataFoundationService {
    typealias IgnoredHistoryPreparationResult = (
        record: FileMetadataRecord,
        previousWorkflowStatus: MetadataWorkflowStatus?
    )

    private static let customFolderBookmarkPrefix = "CustomFolder_"
    private static let projectSpaceRecentActivityLimit = 8

    private struct ProjectSpaceMember {
        let normalizedLabel: String
        let normalizedPath: String
        let record: FileMetadataRecord
    }

    private let modelContext: ModelContext
    private let featureFlags: FeatureFlagService

    #if DEBUG
    static var debugRecordTransitionHook: ((String, String, FileOrganizationHistoryEntry.EventKind) throws -> Void)?
    static var debugProjectSpacePathReachabilityHook: ((String, Bool) -> Bool?)?
    static var debugProjectSpaceBookmarkRootLoadHook: (() -> Void)?
    static var debugWorkflowTagSaveHook: (() throws -> Void)?
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

    func projectSpaceAdmissionFileSnapshot(for path: String) -> ProjectSpaceAdmissionFileSnapshot {
        let normalizedPath = FileMetadataRecord.normalizedPath(path)
        let record = try? workflowTagRecord(for: normalizedPath)

        return ProjectSpaceAdmissionFileSnapshot(
            canonicalIdentity: record?.canonicalIdentity,
            normalizedPath: normalizedPath,
            projectAssociation: FileMetadataRecord.normalizedOptionalText(record?.projectAssociation),
            sourceFolderHint: projectSpaceSourceFolderHintRoot(for: normalizedPath)
        )
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
        try upsertRecordForDiscoveryWithoutSaving(
            for: path,
            displayName: displayName,
            fileExtension: fileExtension,
            timestamp: timestamp
        )?.record
    }

    @discardableResult
    func upsertRecordForDiscoveryWithoutSaving(
        for path: String,
        displayName: String,
        fileExtension: String,
        timestamp: Date
    ) throws -> UpsertResult? {
        guard isEnabled else { return nil }

        let identity = resolveIdentity(for: path)
        if let existing = try record(matching: identity.canonicalIdentity) {
            existing.lastKnownPath = identity.normalizedPath
            existing.displayName = FileMetadataRecord.normalizedDisplayName(displayName)
            existing.fileExtension = fileExtension.lowercased()
            existing.lastSeenAt = timestamp
            return (existing, false)
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
        return (record, true)
    }

    @discardableResult
    func applyWorkflowStatusForDiscoveryWithoutSaving(
        to record: FileMetadataRecord,
        wasCreated: Bool,
        timestamp: Date
    ) throws -> Bool {
        guard isWorkflowStatusWriteEnabled,
              wasCreated,
              record.workflowStatus == nil else {
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
    func prepareIgnoredHistoryWithoutSaving(
        for path: String,
        detailsSummary: String?,
        timestamp: Date
    ) throws -> IgnoredHistoryPreparationResult? {
        guard isWorkflowStatusWriteEnabled else { return nil }

        let normalizedPath = FileMetadataRecord.normalizedPath(path)
        var descriptor = FetchDescriptor<FileMetadataRecord>(
            predicate: #Predicate<FileMetadataRecord> { record in
                record.lastKnownPath == normalizedPath
            }
        )
        descriptor.fetchLimit = 1

        guard let record = try modelContext.fetch(descriptor).first else {
            return nil
        }

        let previousWorkflowStatus = record.workflowStatus

        _ = try appendHistoryEntryWithoutSaving(
            for: record,
            eventKind: .ignored,
            sourceSurface: .review,
            fromPath: record.lastKnownPath,
            toPath: record.lastKnownPath,
            destinationDisplayName: nil,
            matchedRuleID: nil,
            detailsSummary: detailsSummary,
            timestamp: timestamp
        )
        return (record, previousWorkflowStatus)
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

        return try recordTransition(
            from: sourcePath,
            to: destinationPath,
            displayName: displayName,
            fileExtension: fileExtension,
            eventKind: eventKind,
            sourceSurface: sourceSurface,
            destinationDisplayName: destinationDisplayName,
            projectAssociationWriteContext: projectAssociationWriteContext,
            matchedRuleID: matchedRuleID,
            detailsSummary: detailsSummary,
            timestamp: timestamp,
            shouldApplyContentTags: true
        )
    }

    @discardableResult
    func recordWorkflowTransition(
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

        return try recordTransition(
            from: sourcePath,
            to: destinationPath,
            displayName: displayName,
            fileExtension: fileExtension,
            eventKind: eventKind,
            sourceSurface: sourceSurface,
            destinationDisplayName: destinationDisplayName,
            projectAssociationWriteContext: projectAssociationWriteContext,
            matchedRuleID: matchedRuleID,
            detailsSummary: detailsSummary,
            timestamp: timestamp,
            shouldApplyContentTags: false
        )
    }

    @discardableResult
    func recordWorkflowRollbackTransition(
        from sourcePath: String,
        to destinationPath: String,
        displayName: String,
        fileExtension: String,
        detailsSummary: String? = nil,
        timestamp: Date
    ) throws -> FileMetadataRecord? {
        guard isEnabled else { return nil }

        return try recordTransition(
            from: sourcePath,
            to: destinationPath,
            displayName: displayName,
            fileExtension: fileExtension,
            eventKind: .noted,
            sourceSurface: .undo,
            destinationDisplayName: nil,
            projectAssociationWriteContext: nil,
            matchedRuleID: nil,
            detailsSummary: detailsSummary
                ?? "Workflow rollback restored the original file path.",
            timestamp: timestamp,
            shouldApplyContentTags: false
        )
    }

    @discardableResult
    private func recordTransition(
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
        timestamp: Date,
        shouldApplyContentTags: Bool
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

            if shouldApplyContentTags {
                _ = applyContentTagsWithoutSaving(
                    for: finalRecord,
                    displayName: displayName,
                    fileExtension: fileExtension,
                    destinationDisplayName: destinationDisplayName,
                    matchedRuleID: matchedRuleID
                )
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
            applyWorkflowStatus(for: finalRecord, eventKind: eventKind)

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

    @discardableResult
    func applyWorkflowTags(
        path: String,
        displayName: String,
        fileExtension: String,
        tags: [String],
        timestamp: Date
    ) throws -> [String] {
        guard isEnabled else { return [] }

        let normalizedPath = FileMetadataRecord.normalizedPath(path)
        let requestedTags = uniqueNormalizedTags(tags)
        guard !requestedTags.isEmpty else { return [] }

        do {
            guard let record = try upsertWorkflowTagRecordWithoutSaving(
                for: normalizedPath,
                displayName: displayName,
                fileExtension: fileExtension,
                timestamp: timestamp
            ) else {
                return []
            }

            let existingTagKeys = Set(
                record
                    .storedTagValuesForDuplicateSuppression()
                    .map { FileMetadataRecord.normalizedTag($0).lowercased() }
            )
            let appendedTags = requestedTags.filter { !existingTagKeys.contains($0.lowercased()) }
            record.appendStoredTagsPreservingExistingOrder(appendedTags)
            #if DEBUG
            try Self.debugWorkflowTagSaveHook?()
            #endif
            try modelContext.save()
            return appendedTags
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func previewWorkflowTags(
        path: String,
        tags: [String]
    ) throws -> [String] {
        guard isEnabled else { return [] }

        let requestedTags = uniqueNormalizedTags(tags)
        guard !requestedTags.isEmpty else { return [] }

        let normalizedPath = FileMetadataRecord.normalizedPath(path)
        let existingTagKeys = Set(
            (try workflowTagRecord(for: normalizedPath))?
                .storedTagValuesForDuplicateSuppression()
                .map { FileMetadataRecord.normalizedTag($0).lowercased() } ?? []
        )

        return requestedTags.filter { !existingTagKeys.contains($0.lowercased()) }
    }

    @discardableResult
    func removeWorkflowTags(
        path: String,
        tags: [String]
    ) throws -> [String] {
        guard isEnabled else { return [] }

        let requestedTags = uniqueNormalizedTags(tags)
        guard !requestedTags.isEmpty else { return [] }

        let normalizedPath = FileMetadataRecord.normalizedPath(path)
        do {
            guard let record = try workflowTagRecord(for: normalizedPath) else {
                return []
            }

            let resolver = MetadataContentTagResolver()
            let requestedKeys = Set(requestedTags.map { $0.lowercased() })
            let requestedBuiltIns = Set(requestedTags.compactMap {
                MetadataContentTag(rawValue: $0.lowercased()) ?? resolver.resolveExplicitTag(forAlias: $0)
            })
            var removedKeys = Set<String>()

            record.tags.removeAll { rawValue in
                let normalized = FileMetadataRecord.normalizedTag(rawValue)
                let normalizedKey = normalized.lowercased()
                if requestedKeys.contains(normalizedKey) {
                    removedKeys.insert(normalizedKey)
                    return true
                }

                if let builtIn = MetadataContentTag(rawValue: normalizedKey) ?? resolver.resolveExplicitTag(forAlias: normalized),
                   requestedBuiltIns.contains(builtIn) {
                    removedKeys.insert(builtIn.rawValue)
                    return true
                }

                return false
            }

            #if DEBUG
            try Self.debugWorkflowTagSaveHook?()
            #endif
            try modelContext.save()
            return requestedTags.filter { removedKeys.contains($0.lowercased()) }
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func previewWorkflowProjectAssociation(
        path: String,
        targetProjectAssociation: String
    ) throws -> WorkflowProjectAssociationMutationPreview? {
        guard isProjectSpaceWriteEnabled,
              let normalizedTarget = FileMetadataRecord.normalizedOptionalText(targetProjectAssociation) else {
            return nil
        }

        let identity = resolveIdentity(for: path)
        let previousProjectAssociation = try record(matching: identity.canonicalIdentity)
            .flatMap { FileMetadataRecord.normalizedOptionalText($0.projectAssociation) }

        return WorkflowProjectAssociationMutationPreview(
            previousProjectAssociation: previousProjectAssociation,
            targetProjectAssociation: normalizedTarget
        )
    }

    @discardableResult
    func applyWorkflowProjectAssociation(
        path: String,
        displayName: String,
        fileExtension: String,
        targetProjectAssociation: String,
        timestamp: Date
    ) throws -> WorkflowProjectAssociationMutationPreview? {
        guard isProjectSpaceWriteEnabled,
              let normalizedTarget = FileMetadataRecord.normalizedOptionalText(targetProjectAssociation) else {
            return nil
        }

        let normalizedPath = FileMetadataRecord.normalizedPath(path)

        do {
            guard let record = try upsertRecordWithoutSaving(
                for: normalizedPath,
                displayName: displayName,
                fileExtension: fileExtension,
                timestamp: timestamp
            ) else {
                return nil
            }

            let preview = WorkflowProjectAssociationMutationPreview(
                previousProjectAssociation: FileMetadataRecord.normalizedOptionalText(record.projectAssociation),
                targetProjectAssociation: normalizedTarget
            )

            guard preview.willChange else {
                return preview
            }

            record.projectAssociation = normalizedTarget
            _ = try appendHistoryEntryWithoutSaving(
                for: record,
                eventKind: .noted,
                sourceSurface: .organize,
                fromPath: normalizedPath,
                toPath: normalizedPath,
                destinationDisplayName: nil,
                matchedRuleID: nil,
                detailsSummary: workflowProjectAssociationDetailsSummary(
                    from: preview.previousProjectAssociation,
                    to: normalizedTarget,
                    isRollback: false
                ),
                timestamp: timestamp
            )
            try modelContext.save()
            return preview
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    @discardableResult
    func restoreWorkflowProjectAssociation(
        canonicalIdentity: String,
        path: String,
        previousProjectAssociation: String?,
        timestamp: Date
    ) throws -> Bool {
        guard isProjectSpaceWriteEnabled else { return false }

        let normalizedPath = FileMetadataRecord.normalizedPath(path)
        let normalizedPreviousProjectAssociation = FileMetadataRecord.normalizedOptionalText(previousProjectAssociation)

        do {
            guard let record = try record(matching: canonicalIdentity) else {
                return false
            }

            let currentProjectAssociation = FileMetadataRecord.normalizedOptionalText(record.projectAssociation)
            guard currentProjectAssociation != normalizedPreviousProjectAssociation else {
                return false
            }

            record.projectAssociation = normalizedPreviousProjectAssociation
            _ = try appendHistoryEntryWithoutSaving(
                for: record,
                eventKind: .noted,
                sourceSurface: .undo,
                fromPath: normalizedPath,
                toPath: normalizedPath,
                destinationDisplayName: nil,
                matchedRuleID: nil,
                detailsSummary: workflowProjectAssociationDetailsSummary(
                    from: currentProjectAssociation,
                    to: normalizedPreviousProjectAssociation,
                    isRollback: true
                ),
                timestamp: timestamp
            )
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func previewWorkflowStatus(
        path: String,
        targetWorkflowStatus: MetadataWorkflowStatus
    ) throws -> WorkflowStatusMutationPreview? {
        guard isWorkflowStatusWriteEnabled else { return nil }

        let identity = resolveIdentity(for: path)
        let previousWorkflowStatus = try record(matching: identity.canonicalIdentity)?.workflowStatus

        return WorkflowStatusMutationPreview(
            previousWorkflowStatus: previousWorkflowStatus,
            targetWorkflowStatus: targetWorkflowStatus
        )
    }

    @discardableResult
    func applyWorkflowStatus(
        path: String,
        displayName: String,
        fileExtension: String,
        targetWorkflowStatus: MetadataWorkflowStatus,
        timestamp: Date
    ) throws -> WorkflowStatusMutationPreview? {
        guard isWorkflowStatusWriteEnabled else { return nil }

        let normalizedPath = FileMetadataRecord.normalizedPath(path)

        do {
            guard let record = try upsertRecordWithoutSaving(
                for: normalizedPath,
                displayName: displayName,
                fileExtension: fileExtension,
                timestamp: timestamp
            ) else {
                return nil
            }

            let preview = WorkflowStatusMutationPreview(
                previousWorkflowStatus: record.workflowStatus,
                targetWorkflowStatus: targetWorkflowStatus
            )

            guard preview.willChange else {
                return preview
            }

            record.workflowStatus = targetWorkflowStatus
            _ = try appendHistoryEntryWithoutSaving(
                for: record,
                eventKind: .noted,
                sourceSurface: .organize,
                fromPath: normalizedPath,
                toPath: normalizedPath,
                destinationDisplayName: nil,
                matchedRuleID: nil,
                detailsSummary: workflowStatusDetailsSummary(
                    from: preview.previousWorkflowStatus,
                    to: targetWorkflowStatus,
                    isRollback: false
                ),
                timestamp: timestamp
            )
            try modelContext.save()
            return preview
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    @discardableResult
    func restoreWorkflowStatus(
        canonicalIdentity: String,
        path: String,
        previousWorkflowStatus: MetadataWorkflowStatus?,
        timestamp: Date
    ) throws -> Bool {
        guard isWorkflowStatusWriteEnabled else { return false }

        let normalizedPath = FileMetadataRecord.normalizedPath(path)

        do {
            guard let record = try record(matching: canonicalIdentity) else {
                return false
            }

            let currentWorkflowStatus = record.workflowStatus
            guard currentWorkflowStatus != previousWorkflowStatus else {
                return false
            }

            record.workflowStatus = previousWorkflowStatus
            _ = try appendHistoryEntryWithoutSaving(
                for: record,
                eventKind: .noted,
                sourceSurface: .undo,
                fromPath: normalizedPath,
                toPath: normalizedPath,
                destinationDisplayName: nil,
                matchedRuleID: nil,
                detailsSummary: workflowStatusDetailsSummary(
                    from: currentWorkflowStatus,
                    to: previousWorkflowStatus,
                    isRollback: true
                ),
                timestamp: timestamp
            )
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func fetchProjectSpaceSummaries() -> [ProjectSpaceSummary] {
        guard isProjectSpaceReadEnabled else { return [] }

        let descriptor = FetchDescriptor<FileMetadataRecord>()
        guard let records = try? modelContext.fetch(descriptor) else {
            return []
        }

        let bookmarkBackedRootURLs = Self.projectSpaceBookmarkBackedRootURLs()
        let recordsByLabel = projectSpaceRecordsByLabel(
            from: records,
            bookmarkBackedRootURLs: bookmarkBackedRootURLs
        )

        return recordsByLabel
            .map { label, members in
                return ProjectSpaceSummary(
                    normalizedLabel: label,
                    fileCount: members.count,
                    lastActivityAt: lastActivityAt(for: members.map(\.record)),
                    sourceFolderHints: sourceFolderHints(for: members)
                )
            }
            .sorted(by: projectSpaceSummarySortOrder(_:_:))
    }

    func fetchProjectSpaceDetail(for normalizedProjectLabel: String) -> ProjectSpaceDetail? {
        guard isProjectSpaceReadEnabled,
              let selectedLabel = FileMetadataRecord.normalizedOptionalText(normalizedProjectLabel) else {
            return nil
        }

        let descriptor = FetchDescriptor<FileMetadataRecord>()
        guard let records = try? modelContext.fetch(descriptor) else {
            return nil
        }

        let bookmarkBackedRootURLs = Self.projectSpaceBookmarkBackedRootURLs()
        let members = projectSpaceMembers(
            from: records,
            bookmarkBackedRootURLs: bookmarkBackedRootURLs
        )
            .filter { $0.normalizedLabel == selectedLabel }
        let uniqueMembers = coalescedProjectSpaceMembers(members)

        guard !uniqueMembers.isEmpty else { return nil }

        let memberContexts = uniqueMembers.map { member in
            ProjectSpaceMemoryResolver.MemberContext(
                record: member.record,
                normalizedPath: member.normalizedPath
            )
        }
        let memoryResolver = ProjectSpaceMemoryResolver()
        let fallbackSourceFolderHints = sourceFolderHints(for: uniqueMembers)
        let overview: ProjectSpaceOverview = if isProjectSpaceMemoryEnabled {
            memoryResolver.buildOverview(for: memberContexts)
        } else {
            ProjectSpaceOverview(
                currentFileCount: uniqueMembers.count,
                activeFolderCount: fallbackSourceFolderHints.count,
                activeFolderHints: fallbackSourceFolderHints
            )
        }

        let summary = ProjectSpaceSummary(
            normalizedLabel: selectedLabel,
            fileCount: uniqueMembers.count,
            lastActivityAt: lastActivityAt(for: uniqueMembers.map(\.record)),
            sourceFolderHints: fallbackSourceFolderHints
        )
        let files = uniqueMembers
            .map { member in
                ProjectSpaceFileRow(
                    canonicalIdentity: member.record.canonicalIdentity,
                    path: member.normalizedPath,
                    displayName: member.record.displayName,
                    fileExtension: member.record.fileExtension,
                    lastActivityAt: lastActivityAt(for: member.record),
                    workflowStatus: member.record.workflowStatus,
                    tags: member.record.tags,
                    projectAssociation: FileMetadataRecord.normalizedOptionalText(member.record.projectAssociation),
                    sourceFolderHint: projectSpaceSourceFolderHintRoot(for: member.normalizedPath)
                )
            }
            .sorted(by: projectSpaceFileSortOrder(_:_:))

        let preferredDestinations = isProjectSpaceMemoryEnabled
            ? memoryResolver.buildPreferredDestinations(for: memberContexts)
            : []
        let recentActivity = isProjectSpaceMemoryEnabled
            ? Array(memoryResolver.buildRecentActivityRows(for: memberContexts).prefix(Self.projectSpaceRecentActivityLimit))
            : []

        return ProjectSpaceDetail(
            summary: summary,
            files: files,
            overview: overview,
            preferredDestinations: preferredDestinations,
            recentActivity: recentActivity
        )
    }

    @discardableResult
    func correctProjectAssociation(
        forCanonicalIdentity canonicalIdentity: String,
        to updatedProjectLabel: String,
        timestamp: Date
    ) throws -> Bool {
        guard isProjectSpaceWriteEnabled,
              let normalizedUpdatedLabel = FileMetadataRecord.normalizedOptionalText(updatedProjectLabel),
              let metadataRecord = try record(matching: canonicalIdentity) else {
            return false
        }

        let existingLabel = FileMetadataRecord.normalizedOptionalText(metadataRecord.projectAssociation)
        guard existingLabel != normalizedUpdatedLabel else {
            return false
        }

        metadataRecord.projectAssociation = normalizedUpdatedLabel
        let detailsSummary: String
        if let existingLabel {
            detailsSummary = "Corrected project association from \(existingLabel) to \(normalizedUpdatedLabel)."
        } else {
            detailsSummary = "Corrected project association to \(normalizedUpdatedLabel)."
        }

        do {
            _ = try appendHistoryEntryWithoutSaving(
                for: metadataRecord,
                eventKind: .noted,
                sourceSurface: .review,
                fromPath: metadataRecord.lastKnownPath,
                toPath: metadataRecord.lastKnownPath,
                destinationDisplayName: nil,
                matchedRuleID: nil,
                detailsSummary: detailsSummary,
                timestamp: timestamp
            )
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func admitToProjectSpace(
        canonicalIdentity: String,
        projectLabel: String,
        detailsSummary: String,
        timestamp: Date
    ) throws {
        guard isProjectSpaceWriteEnabled,
              let normalizedProjectLabel = FileMetadataRecord.normalizedOptionalText(projectLabel),
              let metadataRecord = try record(matching: canonicalIdentity) else {
            return
        }

        let existingLabel = FileMetadataRecord.normalizedOptionalText(metadataRecord.projectAssociation)
        guard existingLabel != normalizedProjectLabel else {
            return
        }

        metadataRecord.projectAssociation = normalizedProjectLabel
        let normalizedSummary = FileMetadataRecord.normalizedOptionalText(detailsSummary)
            ?? "Admitted to project space \(normalizedProjectLabel)."

        do {
            _ = try appendHistoryEntryWithoutSaving(
                for: metadataRecord,
                eventKind: .noted,
                sourceSurface: .organize,
                fromPath: metadataRecord.lastKnownPath,
                toPath: metadataRecord.lastKnownPath,
                destinationDisplayName: nil,
                matchedRuleID: nil,
                detailsSummary: normalizedSummary,
                timestamp: timestamp
            )
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
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

    private var isProjectSpaceReadEnabled: Bool {
        featureFlags.isEnabled(.metadataFoundation) &&
        featureFlags.isEnabled(.projectSpaces)
    }

    private var isProjectSpaceWriteEnabled: Bool {
        isProjectSpaceReadEnabled
    }

    private var isProjectSpaceMemoryEnabled: Bool {
        featureFlags.isEnabled(.metadataFoundation) &&
        featureFlags.isEnabled(.projectSpaces) &&
        featureFlags.isEnabled(.projectSpaceMemory)
    }

    private var isWorkflowStatusWriteEnabled: Bool {
        featureFlags.isEnabled(.metadataFoundation) &&
        featureFlags.isEnabled(.durableWorkflowStatus)
    }

    private func workflowProjectAssociationDetailsSummary(
        from previousProjectAssociation: String?,
        to nextProjectAssociation: String?,
        isRollback: Bool
    ) -> String {
        if isRollback {
            switch (previousProjectAssociation, nextProjectAssociation) {
            case let (current?, previous?):
                return "Workflow restored project association from \(current) to \(previous)."
            case let (current?, nil):
                return "Workflow cleared project association \(current)."
            case let (nil, previous?):
                return "Workflow restored project association to \(previous)."
            case (nil, nil):
                return "Workflow project association rollback made no changes."
            }
        }

        switch (previousProjectAssociation, nextProjectAssociation) {
        case let (previous?, next?):
            return "Workflow set project association from \(previous) to \(next)."
        case (nil, let next?):
            return "Workflow set project association to \(next)."
        default:
            return "Workflow project association step made no changes."
        }
    }

    private func workflowStatusDetailsSummary(
        from previousWorkflowStatus: MetadataWorkflowStatus?,
        to nextWorkflowStatus: MetadataWorkflowStatus?,
        isRollback: Bool
    ) -> String {
        if isRollback {
            switch (previousWorkflowStatus, nextWorkflowStatus) {
            case let (current?, previous?):
                return "Workflow restored status from \(current.rawValue) to \(previous.rawValue)."
            case let (current?, nil):
                return "Workflow cleared status \(current.rawValue)."
            case (nil, let previous?):
                return "Workflow restored status to \(previous.rawValue)."
            case (nil, nil):
                return "Workflow status rollback made no changes."
            }
        }

        switch (previousWorkflowStatus, nextWorkflowStatus) {
        case let (previous?, next?):
            return "Workflow set status from \(previous.rawValue) to \(next.rawValue)."
        case (nil, let next?):
            return "Workflow set status to \(next.rawValue)."
        default:
            return "Workflow status step made no changes."
        }
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

    private func workflowTagRecord(for normalizedPath: String) throws -> FileMetadataRecord? {
        if let pathRecord = try pathFallbackRecord(lastKnownPath: normalizedPath) {
            return pathRecord
        }

        if let matchingPathRecord = try firstRecord(lastKnownPath: normalizedPath) {
            return matchingPathRecord
        }

        let identity = resolveIdentity(for: normalizedPath)
        return try record(matching: identity.canonicalIdentity)
    }

    @discardableResult
    private func upsertWorkflowTagRecordWithoutSaving(
        for normalizedPath: String,
        displayName: String,
        fileExtension: String,
        timestamp: Date
    ) throws -> FileMetadataRecord? {
        if let existing = try workflowTagRecord(for: normalizedPath) {
            existing.lastKnownPath = normalizedPath
            existing.displayName = FileMetadataRecord.normalizedDisplayName(displayName)
            existing.fileExtension = fileExtension.lowercased()
            existing.lastSeenAt = timestamp
            return existing
        }

        return try upsertRecordWithoutSaving(
            for: normalizedPath,
            displayName: displayName,
            fileExtension: fileExtension,
            timestamp: timestamp
        )
    }

    private func pathFallbackRecord(lastKnownPath normalizedPath: String) throws -> FileMetadataRecord? {
        try records(lastKnownPath: normalizedPath)
            .first(where: { $0.identityKind == .pathFallback })
    }

    private func firstRecord(lastKnownPath normalizedPath: String) throws -> FileMetadataRecord? {
        try records(lastKnownPath: normalizedPath).first
    }

    private func records(lastKnownPath normalizedPath: String) throws -> [FileMetadataRecord] {
        let descriptor = FetchDescriptor<FileMetadataRecord>(
            predicate: #Predicate<FileMetadataRecord> { record in
                record.lastKnownPath == normalizedPath
            }
        )

        let matches: [FileMetadataRecord] = try modelContext.fetch(descriptor)
        return matches.sorted { lhs, rhs in
            lhs.canonicalIdentity < rhs.canonicalIdentity
        }
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

    private func lastActivityAt(for records: [FileMetadataRecord]) -> Date {
        records
            .map(lastActivityAt(for:))
            .max() ?? .distantPast
    }

    private func lastActivityAt(for record: FileMetadataRecord) -> Date {
        if let durableHistoryAt = record.historyEntries
            .compactMap({ entry -> Date? in
                switch entry.eventKind {
                case .organized, .rekeyed, .undone, .ignored, .noted:
                    return entry.timestamp
                case .scanned:
                    return nil
                }
            })
            .max() {
            return durableHistoryAt
        }

        if let lastOrganizedAt = record.lastOrganizedAt {
            return lastOrganizedAt
        }

        if record.lastSeenAt >= record.firstSeenAt {
            return record.lastSeenAt
        }

        return record.firstSeenAt
    }

    private func projectSpaceSummarySortOrder(
        _ lhs: ProjectSpaceSummary,
        _ rhs: ProjectSpaceSummary
    ) -> Bool {
        if lhs.lastActivityAt != rhs.lastActivityAt {
            return lhs.lastActivityAt > rhs.lastActivityAt
        }

        if lhs.fileCount != rhs.fileCount {
            return lhs.fileCount > rhs.fileCount
        }

        let caseInsensitiveComparison = lhs.normalizedLabel.localizedCaseInsensitiveCompare(rhs.normalizedLabel)
        if caseInsensitiveComparison != .orderedSame {
            return caseInsensitiveComparison == .orderedAscending
        }

        if lhs.normalizedLabel != rhs.normalizedLabel {
            return lhs.normalizedLabel < rhs.normalizedLabel
        }

        return false
    }

    private func projectSpaceFileSortOrder(
        _ lhs: ProjectSpaceFileRow,
        _ rhs: ProjectSpaceFileRow
    ) -> Bool {
        if lhs.lastActivityAt != rhs.lastActivityAt {
            return lhs.lastActivityAt > rhs.lastActivityAt
        }

        let displayNameComparison = lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
        if displayNameComparison != .orderedSame {
            return displayNameComparison == .orderedAscending
        }

        return lhs.canonicalIdentity < rhs.canonicalIdentity
    }

    private func projectSpaceRecordsByLabel(
        from records: [FileMetadataRecord],
        bookmarkBackedRootURLs: [URL]
    ) -> [String: [ProjectSpaceMember]] {
        Dictionary(
            grouping: projectSpaceMembers(
                from: records,
                bookmarkBackedRootURLs: bookmarkBackedRootURLs
            ),
            by: \.normalizedLabel
        )
    }

    private func projectSpaceMembers(
        from records: [FileMetadataRecord],
        bookmarkBackedRootURLs: [URL]
    ) -> [ProjectSpaceMember] {
        records.compactMap { projectSpaceMember(for: $0, bookmarkBackedRootURLs: bookmarkBackedRootURLs) }
    }

    private func projectSpaceMember(
        for record: FileMetadataRecord,
        bookmarkBackedRootURLs: [URL]
    ) -> ProjectSpaceMember? {
        guard let normalizedLabel = FileMetadataRecord.normalizedOptionalText(record.projectAssociation),
              let normalizedPath = normalizedResolvablePath(
                for: record,
                bookmarkBackedRootURLs: bookmarkBackedRootURLs
              ) else {
            return nil
        }

        return ProjectSpaceMember(
            normalizedLabel: normalizedLabel,
            normalizedPath: normalizedPath,
            record: record
        )
    }

    private func normalizedResolvablePath(
        for record: FileMetadataRecord,
        bookmarkBackedRootURLs: [URL]
    ) -> String? {
        let rawStoredPath = record.lastKnownPath
        return Self.normalizedResolvablePath(
            for: rawStoredPath,
            bookmarkBackedRootURLs: bookmarkBackedRootURLs
        )
    }

    private func sourceFolderHints(for members: [ProjectSpaceMember]) -> [String] {
        projectSpaceSourceFolderHints(for: members.map(\.normalizedPath))
    }

    private func coalescedProjectSpaceMembers(
        _ members: [ProjectSpaceMember]
    ) -> [ProjectSpaceMember] {
        Dictionary(grouping: members, by: \.normalizedPath)
            .values
            .compactMap { group in
                group.max { lhs, rhs in
                    projectSpaceMemberPreference(lhs) < projectSpaceMemberPreference(rhs)
                }
            }
            .sorted { lhs, rhs in
                if lhs.normalizedPath != rhs.normalizedPath {
                    return lhs.normalizedPath < rhs.normalizedPath
                }
                return lhs.record.canonicalIdentity < rhs.record.canonicalIdentity
            }
    }

    private func projectSpaceMemberPreference(
        _ member: ProjectSpaceMember
    ) -> (Int, Date, String) {
        let identityRank = member.record.identityKind == .resourceIdentifier ? 1 : 0
        return (identityRank, lastActivityAt(for: member.record), member.record.canonicalIdentity)
    }

    func projectSpaceSourceFolderHints(
        for paths: [String],
        homePath: String? = nil
    ) -> [String] {
        let counts = paths.reduce(into: [String: Int]()) { partialResult, path in
            guard let root = projectSpaceSourceFolderHintRoot(for: path, homePath: homePath) else {
                return
            }
            partialResult[root, default: 0] += 1
        }

        return counts
            .sorted { lhs, rhs in
                if lhs.value != rhs.value {
                    return lhs.value > rhs.value
                }
                return lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
            }
            .prefix(3)
            .map(\.key)
    }

    func projectSpaceSourceFolderHintRoot(
        for normalizedPath: String,
        homePath: String? = nil
    ) -> String? {
        let standardizedPath = URL(fileURLWithPath: normalizedPath).standardizedFileURL.path
        let resolvedHomePath = homePath ?? projectSpaceRealHomeDirectoryPath()
        let homePrefix = resolvedHomePath.hasSuffix("/") ? resolvedHomePath : "\(resolvedHomePath)/"

        if standardizedPath.hasPrefix(homePrefix) {
            let relativePath = String(standardizedPath.dropFirst(homePrefix.count))
            let components = relativePath
                .split(separator: "/")
                .map(String.init)
            guard let firstComponent = components.first else {
                return nil
            }

            if let standardFolderDisplayName = projectSpaceStandardFolderDisplayName(for: firstComponent) {
                return standardFolderDisplayName
            } else {
                return firstComponent
            }
        }

        let pathComponents = URL(fileURLWithPath: standardizedPath).pathComponents
            .filter { $0 != "/" && !$0.isEmpty }
        guard !pathComponents.isEmpty else {
            return nil
        }

        if pathComponents.first == "Volumes", pathComponents.count > 1 {
            return pathComponents[1]
        }

        return pathComponents.first
    }

    func projectSpaceStandardFolderDisplayName(for component: String) -> String? {
        BookmarkFolder.FolderType.allCases.first(where: { $0.displayName == component })?.displayName
    }

    private func projectSpaceRealHomeDirectoryPath() -> String {
        if let pw = getpwuid(getuid()) {
            return URL(fileURLWithPath: String(cString: pw.pointee.pw_dir))
                .standardizedFileURL
                .path
        }

        return FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
    }

    static func normalizedResolvablePath(
        for rawStoredPath: String,
        bookmarkBackedRootURLs: [URL]
    ) -> String? {
        guard rawStoredPath == rawStoredPath.trimmingCharacters(in: .whitespacesAndNewlines),
              let storedPath = FileMetadataRecord.normalizedOptionalText(rawStoredPath) else {
            return nil
        }

        guard (storedPath as NSString).isAbsolutePath else {
            return nil
        }

        let normalizedPath = FileMetadataRecord.normalizedPath(storedPath)
        if Self.isProjectSpacePathReachable(
            normalizedPath,
            bookmarkBackedRootURLs: bookmarkBackedRootURLs
        ) {
            return normalizedPath
        }

        return nil
    }

    static func isProjectSpacePathReachable(
        _ normalizedPath: String,
        bookmarkBackedRootURLs: [URL]
    ) -> Bool {
        if Self.projectSpacePathExists(at: normalizedPath, usingSecurityScopedAccess: false) {
            return true
        }

        for rootURL in bookmarkBackedRootURLs {
            let resolvedRootPath = rootURL.standardizedFileURL.path
            guard Self.isPath(normalizedPath, withinRootPath: resolvedRootPath),
                  rootURL.startAccessingSecurityScopedResource() else {
                continue
            }

            defer {
                rootURL.stopAccessingSecurityScopedResource()
            }

            if Self.projectSpacePathExists(at: normalizedPath, usingSecurityScopedAccess: true) {
                return true
            }
        }

        return false
    }

    static func projectSpacePathExists(
        at normalizedPath: String,
        usingSecurityScopedAccess: Bool
    ) -> Bool {
        #if DEBUG
        if let override = Self.debugProjectSpacePathReachabilityHook,
           let result = override(normalizedPath, usingSecurityScopedAccess) {
            return result
        }
        #endif

        return FileManager.default.fileExists(atPath: normalizedPath)
    }

    static func projectSpaceBookmarkBackedRootURLs() -> [URL] {
        #if DEBUG
        Self.debugProjectSpaceBookmarkRootLoadHook?()
        #endif

        var rootURLs: [URL] = []
        var seenPaths: Set<String> = []

        func appendRootURL(_ url: URL) {
            let standardizedPath = url.standardizedFileURL.path
            guard seenPaths.insert(standardizedPath).inserted else {
                return
            }

            rootURLs.append(url)
        }

        for folderType in BookmarkFolder.FolderType.allCases {
            guard let resolvedURL = BookmarkFolder(folderType: folderType).resolveURL()?.url else {
                continue
            }

            appendRootURL(resolvedURL)
        }

        for key in BookmarkStoreProvider.shared.listAllBookmarkKeys()
        where key.hasPrefix(Self.customFolderBookmarkPrefix) {
            guard let bookmarkData = BookmarkStoreProvider.shared.loadBookmark(forKey: key) else {
                continue
            }

            var isStale = false
            guard let resolvedURL = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else {
                continue
            }

            appendRootURL(resolvedURL)
        }

        return rootURLs
    }

    static func isPath(_ path: String, withinRootPath rootPath: String) -> Bool {
        let standardizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        let standardizedRootPath = URL(fileURLWithPath: rootPath).standardizedFileURL.path
        let rootPrefix = standardizedRootPath.hasSuffix("/") ? standardizedRootPath : "\(standardizedRootPath)/"
        return standardizedPath == standardizedRootPath || standardizedPath.hasPrefix(rootPrefix)
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
            mergePathFallbackRecordWithoutSaving(destinationRecord, into: sourceRecord, timestamp: timestamp)
            sourceRecord.canonicalIdentity = newIdentity.canonicalIdentity
            sourceRecord.lastKnownPath = newIdentity.normalizedPath
            sourceRecord.lastSeenAt = timestamp
            sourceRecord.latestOrganizationStatus = .rekeyed
            return sourceRecord
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
        if destinationRecord.workflowStatus == nil, sourceRecord.workflowStatus != nil {
            destinationRecord.workflowStatus = sourceRecord.workflowStatus
        }

        if destinationRecord.displayName.isEmpty, !sourceRecord.displayName.isEmpty {
            destinationRecord.displayName = sourceRecord.displayName
        }
        if destinationRecord.fileExtension.isEmpty, !sourceRecord.fileExtension.isEmpty {
            destinationRecord.fileExtension = sourceRecord.fileExtension
        }
        destinationRecord.tags = mergedStoredTags(
            preferredTags: sourceRecord.tags,
            fallbackTags: destinationRecord.tags
        )
        if destinationRecord.projectAssociation == nil {
            destinationRecord.projectAssociation = sourceRecord.projectAssociation
        }
        if destinationRecord.notesSummary == nil {
            destinationRecord.notesSummary = sourceRecord.notesSummary
        }

        modelContext.delete(sourceRecord)
    }

    private func mergedStoredTags(
        preferredTags: [String],
        fallbackTags: [String]
    ) -> [String] {
        let resolver = MetadataContentTagResolver()
        var mergedTags: [String] = []
        var seenNormalizedValues = Set<String>()
        var seenBuiltInTags = Set<MetadataContentTag>()

        func append(_ rawValue: String) {
            let normalized = FileMetadataRecord.normalizedTag(rawValue)
            guard !normalized.isEmpty else { return }

            let normalizedKey = normalized.lowercased()
            guard !seenNormalizedValues.contains(normalizedKey) else {
                return
            }

            if let builtInTag = MetadataContentTag(rawValue: normalizedKey)
                ?? resolver.resolveExplicitTag(forAlias: normalized) {
                guard !seenBuiltInTags.contains(builtInTag) else {
                    return
                }
                seenBuiltInTags.insert(builtInTag)
            }

            mergedTags.append(normalized)
            seenNormalizedValues.insert(normalizedKey)
        }

        preferredTags.forEach(append)
        fallbackTags.forEach(append)
        return mergedTags
    }

    private func uniqueNormalizedTags(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for tag in tags {
            let normalized = FileMetadataRecord.normalizedTag(tag)
            let key = normalized.lowercased()
            guard !normalized.isEmpty, seen.insert(key).inserted else {
                continue
            }
            result.append(normalized)
        }

        return result
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
