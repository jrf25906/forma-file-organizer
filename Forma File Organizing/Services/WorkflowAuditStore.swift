import Foundation
import SwiftData

@MainActor
final class WorkflowAuditStore {
    struct RunLookupResult {
        let run: WorkflowRunRecord
        let fileIdentity: String
    }

    enum StoreError: LocalizedError {
        case runNotFound(UUID)
        case stepRunNotFound(UUID)
        case invalidStepID
        case invalidFileIdentity

        var errorDescription: String? {
            switch self {
            case .runNotFound(let id):
                return "Workflow run \(id.uuidString) was not found."
            case .stepRunNotFound(let id):
                return "Workflow step run \(id.uuidString) was not found."
            case .invalidStepID:
                return "Workflow step ID cannot be empty."
            case .invalidFileIdentity:
                return "Workflow file identity cannot be empty."
            }
        }
    }

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    @discardableResult
    func createRun(
        scopeID: UUID,
        workflowTemplateID: String?,
        triggerSurface: ActivityItem.WorkflowTriggerSurface? = nil,
        ownerDisplayName: String? = nil,
        policyName: String? = nil,
        startedAt: Date = Date(),
        primaryStatus: WorkflowRunPrimaryStatus = .running,
        rollbackStatus: WorkflowRunRollbackStatus = .notRequested
    ) throws -> WorkflowRunRecord {
        let run = WorkflowRunRecord(
            scopeID: scopeID,
            workflowTemplateID: workflowTemplateID,
            triggerSurface: triggerSurface,
            ownerDisplayName: ownerDisplayName,
            policyName: policyName,
            primaryStatus: primaryStatus,
            rollbackStatus: rollbackStatus,
            startedAt: startedAt
        )
        modelContext.insert(run)
        try modelContext.save()
        return run
    }

    func updateRunStatus(
        runID: UUID,
        primaryStatus: WorkflowRunPrimaryStatus,
        endedAt: Date? = nil,
        updatedAt: Date = Date()
    ) throws {
        let run = try requireRun(id: runID)
        run.primaryStatus = primaryStatus
        if let endedAt {
            run.endedAt = endedAt
        }
        run.updatedAt = max(run.updatedAt, updatedAt, run.endedAt ?? updatedAt)
        try modelContext.save()
    }

    func updateRollbackStatus(
        runID: UUID,
        rollbackStatus: WorkflowRunRollbackStatus,
        rollbackReason: String? = nil,
        rollbackRequestedAt: Date? = nil,
        rollbackCompletedAt: Date? = nil,
        updatedAt: Date = Date()
    ) throws {
        let run = try requireRun(id: runID)
        run.rollbackStatus = rollbackStatus
        if let rollbackReason {
            run.rollbackReason = WorkflowRunRecord.normalizedOptionalText(rollbackReason)
        }
        if let rollbackRequestedAt {
            run.rollbackRequestedAt = rollbackRequestedAt
        }
        if let rollbackCompletedAt {
            run.rollbackCompletedAt = rollbackCompletedAt
        }
        run.updatedAt = max(run.updatedAt, updatedAt, rollbackCompletedAt ?? rollbackRequestedAt ?? updatedAt)
        try modelContext.save()
    }

    @discardableResult
    func recordStepStatus(
        runID: UUID,
        stepID: String,
        status: WorkflowStepStatus,
        startedAt: Date? = nil,
        endedAt: Date? = nil,
        errorMessage: String? = nil,
        recordedAt: Date = Date()
    ) throws -> WorkflowStepRunRecord {
        let normalizedStepID = WorkflowStepRunRecord.normalizedRequiredText(stepID)
        guard !normalizedStepID.isEmpty else {
            throw StoreError.invalidStepID
        }

        _ = try requireRun(id: runID)

        let stepRecord = WorkflowStepRunRecord(
            runID: runID,
            stepID: normalizedStepID,
            status: status,
            startedAt: startedAt,
            endedAt: endedAt,
            errorMessage: errorMessage,
            recordedAt: recordedAt
        )
        modelContext.insert(stepRecord)
        try modelContext.save()
        return stepRecord
    }

    @discardableResult
    func recordFileAction(
        runID: UUID,
        stepRunID: UUID? = nil,
        fileIdentity: String,
        sourcePath: String? = nil,
        destinationPath: String? = nil,
        disposition: WorkflowFileDisposition,
        compensationStatus: WorkflowCompensationStatus = .notNeeded,
        compensationPayload: [String: String]? = nil,
        metadataDelta: WorkflowFileMetadataDelta? = nil,
        failureReason: String? = nil,
        recordedAt: Date = Date()
    ) throws -> WorkflowFileActionRecord {
        let normalizedIdentity = WorkflowFileActionRecord.normalizedRequiredText(fileIdentity)
        guard !normalizedIdentity.isEmpty else {
            throw StoreError.invalidFileIdentity
        }

        _ = try requireRun(id: runID)
        if let stepRunID {
            _ = try requireStepRun(id: stepRunID, runID: runID)
        }

        let actionRecord = WorkflowFileActionRecord(
            runID: runID,
            stepRunID: stepRunID,
            fileIdentity: normalizedIdentity,
            sourcePath: sourcePath,
            destinationPath: destinationPath,
            disposition: disposition,
            compensationStatus: compensationStatus,
            compensationPayload: compensationPayload,
            metadataDelta: metadataDelta,
            failureReason: failureReason,
            recordedAt: recordedAt
        )
        modelContext.insert(actionRecord)
        try modelContext.save()
        return actionRecord
    }

    func latestRunSummary(scopeID: UUID, workflowTemplateID: String?) throws -> WorkflowRunRecord? {
        let descriptor = FetchDescriptor<WorkflowRunRecord>(
            predicate: #Predicate { $0.scopeID == scopeID }
        )
        let runs = try modelContext.fetch(descriptor)
        let normalizedTemplateID = WorkflowRunRecord.normalizedOptionalText(workflowTemplateID)

        let filtered = runs.filter { run in
            guard let normalizedTemplateID else { return true }
            return run.workflowTemplateID == normalizedTemplateID
        }
        return filtered.max(by: Self.runSortOrder)
    }

    func latestRunForFile(fileIdentity: String) throws -> WorkflowRunRecord? {
        let normalizedIdentity = WorkflowFileActionRecord.normalizedRequiredText(fileIdentity)
        guard !normalizedIdentity.isEmpty else {
            throw StoreError.invalidFileIdentity
        }

        let actions = try modelContext.fetch(FetchDescriptor<WorkflowFileActionRecord>())
        guard let latestAction = actions
            .filter({ $0.fileIdentity == normalizedIdentity })
            .max(by: { lhs, rhs in lhs.recordedAt < rhs.recordedAt }) else {
            return nil
        }

        return try run(id: latestAction.runID)
    }

    func latestRunForPath(_ path: String) throws -> WorkflowRunRecord? {
        try latestRunLookup(forPath: path)?.run
    }

    func latestRunLookup(forPath path: String) throws -> RunLookupResult? {
        let normalizedPath = FileMetadataRecord.normalizedPath(path)
        let metadataRecords = try modelContext.fetch(FetchDescriptor<FileMetadataRecord>())
            .filter { $0.lastKnownPath == normalizedPath }
        let resolvedIdentity = FileMetadataFoundationService(modelContext: modelContext)
            .resolveIdentity(for: normalizedPath)
            .canonicalIdentity
        let pathFallbackIdentity = FileMetadataFoundationService.pathFallbackCanonicalIdentity(for: normalizedPath)

        var candidateIdentities = Set(metadataRecords.map(\.canonicalIdentity))
        candidateIdentities.insert(resolvedIdentity)
        candidateIdentities.insert(pathFallbackIdentity)

        guard let latestAction = try modelContext.fetch(FetchDescriptor<WorkflowFileActionRecord>())
            .filter({
                candidateIdentities.contains($0.fileIdentity) ||
                $0.sourcePath == normalizedPath ||
                $0.destinationPath == normalizedPath
            })
            .max(by: Self.fileActionSortOrder),
              let run = try run(id: latestAction.runID) else {
            return nil
        }

        return RunLookupResult(run: run, fileIdentity: latestAction.fileIdentity)
    }

    func stepRuns(runID: UUID) throws -> [WorkflowStepRunRecord] {
        try modelContext.fetch(FetchDescriptor<WorkflowStepRunRecord>())
            .filter { $0.runID == runID }
            .sorted { lhs, rhs in
                if lhs.recordedAt == rhs.recordedAt {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.recordedAt < rhs.recordedAt
            }
    }

    func fileActions(runID: UUID) throws -> [WorkflowFileActionRecord] {
        try modelContext.fetch(FetchDescriptor<WorkflowFileActionRecord>())
            .filter { $0.runID == runID }
            .sorted { lhs, rhs in
                if lhs.recordedAt == rhs.recordedAt {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.recordedAt < rhs.recordedAt
            }
    }

    func run(id: UUID) throws -> WorkflowRunRecord? {
        try modelContext.fetch(FetchDescriptor<WorkflowRunRecord>()).first(where: { $0.id == id })
    }

    private func requireRun(id: UUID) throws -> WorkflowRunRecord {
        if let run = try run(id: id) {
            return run
        }
        throw StoreError.runNotFound(id)
    }

    private func requireStepRun(id: UUID, runID: UUID) throws -> WorkflowStepRunRecord {
        if let stepRun = try modelContext
            .fetch(FetchDescriptor<WorkflowStepRunRecord>())
            .first(where: { $0.id == id && $0.runID == runID }) {
            return stepRun
        }
        throw StoreError.stepRunNotFound(id)
    }

    private static func runSortOrder(_ lhs: WorkflowRunRecord, _ rhs: WorkflowRunRecord) -> Bool {
        if lhs.startedAt == rhs.startedAt {
            return lhs.updatedAt < rhs.updatedAt
        }
        return lhs.startedAt < rhs.startedAt
    }

    private static func fileActionSortOrder(_ lhs: WorkflowFileActionRecord, _ rhs: WorkflowFileActionRecord) -> Bool {
        if lhs.recordedAt == rhs.recordedAt {
            return lhs.id.uuidString < rhs.id.uuidString
        }
        return lhs.recordedAt < rhs.recordedAt
    }
}
