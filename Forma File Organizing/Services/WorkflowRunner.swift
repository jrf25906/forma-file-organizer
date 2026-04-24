import Foundation
import SwiftData

@MainActor
protocol WorkflowStepExecutor {
    var stepKind: WorkflowStepKind { get }

    func simulate(plannedFile: WorkflowPlannedFile) -> WorkflowSimulatedStep

    func prepareExecution(
        file: FileItem,
        plannedFile: WorkflowPlannedFile,
        modelContext: ModelContext
    ) throws -> WorkflowPreparedStepExecution

    func execute(
        file: FileItem,
        plannedFile: WorkflowPlannedFile,
        modelContext: ModelContext
    ) async throws -> WorkflowStepExecutionResult

    func makeCompensationAction(
        fileIdentity: String,
        compensationPayload: [String: String]?,
        file: FileItem,
        modelContext: ModelContext
    ) throws -> WorkflowCompensationAction?
}

struct WorkflowPreparedStepExecution {
    let sourcePath: String?
    let destinationPath: String?
    let compensationStatus: WorkflowCompensationStatus
    let compensationPayloadDescriptor: WorkflowCompensationPayloadDescriptor?
    let compensationAuditPayload: [String: String]?
    let metadataDelta: WorkflowFileMetadataDelta?

    init(
        sourcePath: String?,
        destinationPath: String?,
        compensationStatus: WorkflowCompensationStatus,
        compensationPayloadDescriptor: WorkflowCompensationPayloadDescriptor?,
        compensationAuditPayload: [String: String]? = nil,
        metadataDelta: WorkflowFileMetadataDelta? = nil
    ) {
        self.sourcePath = sourcePath
        self.destinationPath = destinationPath
        self.compensationStatus = compensationStatus
        self.compensationPayloadDescriptor = compensationPayloadDescriptor
        self.compensationAuditPayload = compensationAuditPayload
            ?? WorkflowCompensationPayloadCodec.encode(compensationPayloadDescriptor)
        self.metadataDelta = metadataDelta?.isEmpty == false ? metadataDelta : nil
    }
}

struct WorkflowStepExecutionResult {
    let sourcePath: String?
    let destinationPath: String?
    let disposition: WorkflowFileDisposition
    let compensationStatus: WorkflowCompensationStatus
    let compensationPayloadDescriptor: WorkflowCompensationPayloadDescriptor?
    let compensationAuditPayload: [String: String]?
    let metadataDelta: WorkflowFileMetadataDelta?

    init(
        sourcePath: String?,
        destinationPath: String?,
        disposition: WorkflowFileDisposition,
        compensationStatus: WorkflowCompensationStatus,
        compensationPayloadDescriptor: WorkflowCompensationPayloadDescriptor?,
        compensationAuditPayload: [String: String]? = nil,
        metadataDelta: WorkflowFileMetadataDelta? = nil
    ) {
        self.sourcePath = sourcePath
        self.destinationPath = destinationPath
        self.disposition = disposition
        self.compensationStatus = compensationStatus
        self.compensationPayloadDescriptor = compensationPayloadDescriptor
        self.compensationAuditPayload = compensationAuditPayload
            ?? WorkflowCompensationPayloadCodec.encode(compensationPayloadDescriptor)
        self.metadataDelta = metadataDelta?.isEmpty == false ? metadataDelta : nil
    }
}

struct WorkflowStepExecutionFailure: Error, LocalizedError {
    let underlyingError: Error
    let sourcePath: String?
    let destinationPath: String?
    let compensationStatus: WorkflowCompensationStatus
    let compensationPayloadDescriptor: WorkflowCompensationPayloadDescriptor?
    let compensationAuditPayload: [String: String]?
    let metadataDelta: WorkflowFileMetadataDelta?

    var errorDescription: String? {
        underlyingError.localizedDescription
    }
}

enum WorkflowCompensationPayloadCodec {
    private static let kindKey = "kind"
    private static let originalPathKey = "originalPath"
    private static let renamedPathKey = "renamedPath"
    private static let pathKey = "path"
    private static let tagsJSONKey = "tagsJSON"
    private static let previousProjectAssociationKey = "previousProjectAssociation"
    private static let previousWorkflowStatusKey = "previousWorkflowStatus"
    private static let previousNotesSummaryKey = "previousNotesSummary"
    private static let originalDestinationPathKey = "originalDestinationPath"
    private static let rollbackPathKey = "rollbackPath"

    static func encode(_ descriptor: WorkflowCompensationPayloadDescriptor?) -> [String: String]? {
        guard let descriptor else { return nil }

        switch descriptor {
        case .renameRollback(let originalPath, let renamedPath):
            return [
                kindKey: WorkflowStepKind.rename.rawValue,
                originalPathKey: originalPath,
                renamedPathKey: renamedPath
            ]
        case .tagRemoval(let path, let tagsToRemove):
            let tagsJSON = String(
                data: (try? JSONEncoder().encode(tagsToRemove)) ?? Data("[]".utf8),
                encoding: .utf8
            ) ?? "[]"

            return [
                kindKey: WorkflowStepKind.tag.rawValue,
                pathKey: path,
                tagsJSONKey: tagsJSON
            ]
        case .projectAssociationRestore(let path, let previousProjectAssociation):
            var payload = [
                kindKey: WorkflowStepKind.projectAssociation.rawValue,
                pathKey: path
            ]
            payload[previousProjectAssociationKey] = previousProjectAssociation
            return payload
        case .workflowStatusRestore(let path, let previousWorkflowStatus):
            var payload = [
                kindKey: WorkflowStepKind.workflowStatus.rawValue,
                pathKey: path
            ]
            payload[previousWorkflowStatusKey] = previousWorkflowStatus?.rawValue
            return payload
        case .notesSummaryRestore(let path, let previousNotesSummary):
            var payload = [
                kindKey: WorkflowStepKind.notesSummary.rawValue,
                pathKey: path
            ]
            payload[previousNotesSummaryKey] = previousNotesSummary
            return payload
        case .moveRollback(let originalDestinationPath, let rollbackPath):
            return [
                kindKey: WorkflowStepKind.move.rawValue,
                originalDestinationPathKey: originalDestinationPath,
                rollbackPathKey: rollbackPath
            ]
        }
    }

    static func decode(_ payload: [String: String]?) -> WorkflowCompensationPayloadDescriptor? {
        guard let payload,
              let kind = payload[kindKey] else {
            return nil
        }

        switch kind {
        case WorkflowStepKind.rename.rawValue:
            guard let originalPath = payload[originalPathKey],
                  let renamedPath = payload[renamedPathKey] else {
                return nil
            }
            return .renameRollback(originalPath: originalPath, renamedPath: renamedPath)
        case WorkflowStepKind.tag.rawValue:
            guard let path = payload[pathKey],
                  let tagsData = payload[tagsJSONKey]?.data(using: .utf8),
                  let tags = try? JSONDecoder().decode([String].self, from: tagsData) else {
                return nil
            }
            return .tagRemoval(path: path, tagsToRemove: tags)
        case WorkflowStepKind.projectAssociation.rawValue:
            guard let path = payload[pathKey] else {
                return nil
            }
            return .projectAssociationRestore(
                path: path,
                previousProjectAssociation: payload[previousProjectAssociationKey]
            )
        case WorkflowStepKind.workflowStatus.rawValue:
            guard let path = payload[pathKey] else {
                return nil
            }
            let previousWorkflowStatus = payload[previousWorkflowStatusKey]
                .flatMap(MetadataWorkflowStatus.init(rawValue:))
            return .workflowStatusRestore(
                path: path,
                previousWorkflowStatus: previousWorkflowStatus
            )
        case WorkflowStepKind.notesSummary.rawValue:
            guard let path = payload[pathKey] else {
                return nil
            }
            return .notesSummaryRestore(
                path: path,
                previousNotesSummary: payload[previousNotesSummaryKey]
            )
        case WorkflowStepKind.move.rawValue:
            guard let originalDestinationPath = payload[originalDestinationPathKey],
                  let rollbackPath = payload[rollbackPathKey] else {
                return nil
            }
            return .moveRollback(
                originalDestinationPath: originalDestinationPath,
                rollbackPath: rollbackPath
            )
        default:
            return nil
        }
    }
}

@MainActor
final class WorkflowRunner {
    struct AuditStepStatusRequest {
        let runID: UUID
        let stepID: String
        let status: WorkflowStepStatus
        let startedAt: Date?
        let endedAt: Date?
        let errorMessage: String?
        let recordedAt: Date
    }

    struct AuditFileActionRequest {
        let runID: UUID
        let stepRunID: UUID?
        let fileIdentity: String
        let sourcePath: String?
        let destinationPath: String?
        let disposition: WorkflowFileDisposition
        let compensationStatus: WorkflowCompensationStatus
        let compensationPayload: [String: String]?
        let metadataDelta: WorkflowFileMetadataDelta?
        let failureReason: String?
        let recordedAt: Date
    }

    struct UpdateRunStatusRequest {
        let runID: UUID
        let primaryStatus: WorkflowRunPrimaryStatus
        let endedAt: Date?
    }

    struct UpdateRollbackStatusRequest {
        let runID: UUID
        let rollbackStatus: WorkflowRunRollbackStatus
        let rollbackReason: String?
        let rollbackRequestedAt: Date?
        let rollbackCompletedAt: Date?
        let updatedAt: Date
    }

    struct AuditOperations {
        typealias UpdateRunStatusHandler = @MainActor (UpdateRunStatusRequest) throws -> Void
        typealias UpdateRunStatusOverride = @MainActor (
            UpdateRunStatusRequest,
            UpdateRunStatusHandler
        ) throws -> Void
        typealias UpdateRollbackStatusHandler = @MainActor (UpdateRollbackStatusRequest) throws -> Void
        typealias UpdateRollbackStatusOverride = @MainActor (
            UpdateRollbackStatusRequest,
            UpdateRollbackStatusHandler
        ) throws -> Void
        typealias RecordFileActionHandler = @MainActor (
            AuditFileActionRequest
        ) throws -> WorkflowFileActionRecord
        typealias RecordFileActionOverride = @MainActor (
            AuditFileActionRequest,
            RecordFileActionHandler
        ) throws -> WorkflowFileActionRecord

        private var createRunImpl: @MainActor (
            _ scopeID: UUID,
            _ workflowTemplateID: String?,
            _ triggerSurface: ActivityItem.WorkflowTriggerSurface?,
            _ ownerDisplayName: String?,
            _ policyName: String?,
            _ startedAt: Date,
            _ primaryStatus: WorkflowRunPrimaryStatus
        ) throws -> WorkflowRunRecord
        private var updateRunStatusImpl: @MainActor (
            _ runID: UUID,
            _ primaryStatus: WorkflowRunPrimaryStatus,
            _ endedAt: Date?
        ) throws -> Void
        private var updateRollbackStatusImpl: @MainActor (
            _ runID: UUID,
            _ rollbackStatus: WorkflowRunRollbackStatus,
            _ rollbackReason: String?,
            _ rollbackRequestedAt: Date?,
            _ rollbackCompletedAt: Date?,
            _ updatedAt: Date
        ) throws -> Void
        private var recordStepStatusImpl: @MainActor (
            _ request: AuditStepStatusRequest
        ) throws -> WorkflowStepRunRecord
        private var recordFileActionImpl: @MainActor (
            _ request: AuditFileActionRequest
        ) throws -> WorkflowFileActionRecord

        static func live(store: WorkflowAuditStore) -> AuditOperations {
            AuditOperations(
                createRunImpl: { scopeID, workflowTemplateID, triggerSurface, ownerDisplayName, policyName, startedAt, primaryStatus in
                    try store.createRun(
                        scopeID: scopeID,
                        workflowTemplateID: workflowTemplateID,
                        triggerSurface: triggerSurface,
                        ownerDisplayName: ownerDisplayName,
                        policyName: policyName,
                        startedAt: startedAt,
                        primaryStatus: primaryStatus
                    )
                },
                updateRunStatusImpl: { runID, primaryStatus, endedAt in
                    try store.updateRunStatus(runID: runID, primaryStatus: primaryStatus, endedAt: endedAt)
                },
                updateRollbackStatusImpl: { runID, rollbackStatus, rollbackReason, rollbackRequestedAt, rollbackCompletedAt, updatedAt in
                    try store.updateRollbackStatus(
                        runID: runID,
                        rollbackStatus: rollbackStatus,
                        rollbackReason: rollbackReason,
                        rollbackRequestedAt: rollbackRequestedAt,
                        rollbackCompletedAt: rollbackCompletedAt,
                        updatedAt: updatedAt
                    )
                },
                recordStepStatusImpl: { request in
                    try store.recordStepStatus(
                        runID: request.runID,
                        stepID: request.stepID,
                        status: request.status,
                        startedAt: request.startedAt,
                        endedAt: request.endedAt,
                        errorMessage: request.errorMessage,
                        recordedAt: request.recordedAt
                    )
                },
                recordFileActionImpl: { request in
                    try store.recordFileAction(
                        runID: request.runID,
                        stepRunID: request.stepRunID,
                        fileIdentity: request.fileIdentity,
                        sourcePath: request.sourcePath,
                        destinationPath: request.destinationPath,
                        disposition: request.disposition,
                        compensationStatus: request.compensationStatus,
                        compensationPayload: request.compensationPayload,
                        metadataDelta: request.metadataDelta,
                        failureReason: request.failureReason,
                        recordedAt: request.recordedAt
                    )
                }
            )
        }

        @MainActor
        func createRun(
            scopeID: UUID,
            workflowTemplateID: String?,
            triggerSurface: ActivityItem.WorkflowTriggerSurface?,
            ownerDisplayName: String?,
            policyName: String?,
            startedAt: Date,
            primaryStatus: WorkflowRunPrimaryStatus
        ) throws -> WorkflowRunRecord {
            try createRunImpl(
                scopeID,
                workflowTemplateID,
                triggerSurface,
                ownerDisplayName,
                policyName,
                startedAt,
                primaryStatus
            )
        }

        @MainActor
        func updateRunStatus(
            runID: UUID,
            primaryStatus: WorkflowRunPrimaryStatus,
            endedAt: Date? = nil
        ) throws {
            try updateRunStatusImpl(runID, primaryStatus, endedAt)
        }

        @MainActor
        func updateRollbackStatus(
            runID: UUID,
            rollbackStatus: WorkflowRunRollbackStatus,
            rollbackReason: String? = nil,
            rollbackRequestedAt: Date? = nil,
            rollbackCompletedAt: Date? = nil,
            updatedAt: Date
        ) throws {
            try updateRollbackStatusImpl(
                runID,
                rollbackStatus,
                rollbackReason,
                rollbackRequestedAt,
                rollbackCompletedAt,
                updatedAt
            )
        }

        @MainActor
        func recordStepStatus(_ request: AuditStepStatusRequest) throws -> WorkflowStepRunRecord {
            try recordStepStatusImpl(request)
        }

        @MainActor
        func recordFileAction(_ request: AuditFileActionRequest) throws -> WorkflowFileActionRecord {
            try recordFileActionImpl(request)
        }

        func with(
            updateRunStatus: UpdateRunStatusOverride? = nil,
            updateRollbackStatus: UpdateRollbackStatusOverride? = nil,
            recordFileAction: RecordFileActionOverride? = nil
        ) -> AuditOperations {
            var copy = self

            if let updateRunStatus {
                let base: UpdateRunStatusHandler = { request in
                    try self.updateRunStatus(
                        runID: request.runID,
                        primaryStatus: request.primaryStatus,
                        endedAt: request.endedAt
                    )
                }
                copy.updateRunStatusImpl = { runID, primaryStatus, endedAt in
                    try updateRunStatus(
                        UpdateRunStatusRequest(
                            runID: runID,
                            primaryStatus: primaryStatus,
                            endedAt: endedAt
                        ),
                        base
                    )
                }
            }

            if let updateRollbackStatus {
                let base: UpdateRollbackStatusHandler = { request in
                    try self.updateRollbackStatus(
                        runID: request.runID,
                        rollbackStatus: request.rollbackStatus,
                        rollbackReason: request.rollbackReason,
                        rollbackRequestedAt: request.rollbackRequestedAt,
                        rollbackCompletedAt: request.rollbackCompletedAt,
                        updatedAt: request.updatedAt
                    )
                }
                copy.updateRollbackStatusImpl = { runID, rollbackStatus, rollbackReason, rollbackRequestedAt, rollbackCompletedAt, updatedAt in
                    try updateRollbackStatus(
                        UpdateRollbackStatusRequest(
                            runID: runID,
                            rollbackStatus: rollbackStatus,
                            rollbackReason: rollbackReason,
                            rollbackRequestedAt: rollbackRequestedAt,
                            rollbackCompletedAt: rollbackCompletedAt,
                            updatedAt: updatedAt
                        ),
                        base
                    )
                }
            }

            if let recordFileAction {
                let base = self.recordFileActionImpl
                copy.recordFileActionImpl = { request in
                    try recordFileAction(request, base)
                }
            }

            return copy
        }
    }

    enum RunnerError: LocalizedError {
        case blockedPlan([WorkflowPlanBlockerReason])
        case missingExecutor(WorkflowStepKind)
        case missingFile(String)
        case missingCompensationRecord(UUID)
        case missingCompensationPayload(UUID)

        var errorDescription: String? {
            switch self {
            case .blockedPlan(let blockers):
                return "Workflow plan is blocked: \(blockers.map { String(describing: $0) }.joined(separator: ", "))"
            case .missingExecutor(let stepKind):
                return "Missing executor for workflow step \(stepKind.rawValue)."
            case .missingFile(let path):
                return "Workflow runner could not find a file item for \(path)."
            case .missingCompensationRecord(let id):
                return "Workflow runner could not find persisted compensation action \(id.uuidString)."
            case .missingCompensationPayload(let id):
                return "Workflow runner could not find a persisted compensation payload for action \(id.uuidString)."
            }
        }
    }

    private struct ExecutedFileAction {
        let stepKind: WorkflowStepKind
        let file: FileItem
        let fileIdentity: String
        let compensationRecordID: UUID
        let rollbackMetadataDelta: WorkflowFileMetadataDelta?
    }

    private enum WorkflowMemoryOutcome {
        case durableSuccess
        case blockedPreflightOnly
        case conflictedFailure
    }

    private let auditOperations: AuditOperations
    private let rollbackCoordinator: WorkflowRollbackCoordinator
    private let executorsByKind: [WorkflowStepKind: any WorkflowStepExecutor]
    private let sideEffectExecutorsByKind: [WorkflowStepKind: any WorkflowRunSideEffectExecutor]
    private let clock: () -> Date

    private static let abandonedAfterUpstreamFailureReason = "abandonedAfterUpstreamFailure"

    init(
        auditStore: WorkflowAuditStore,
        rollbackCoordinator: WorkflowRollbackCoordinator = WorkflowRollbackCoordinator(),
        executorsByKind: [WorkflowStepKind: any WorkflowStepExecutor]? = nil,
        sideEffectExecutorsByKind: [WorkflowStepKind: any WorkflowRunSideEffectExecutor]? = nil,
        clock: @escaping () -> Date = Date.init,
        auditOperations: AuditOperations? = nil
    ) {
        self.auditOperations = auditOperations ?? AuditOperations.live(store: auditStore)
        self.rollbackCoordinator = rollbackCoordinator
        self.executorsByKind = executorsByKind ?? [
            .rename: RenameWorkflowStepExecutor(),
            .tag: TagWorkflowStepExecutor(),
            .projectAssociation: ProjectAssociationWorkflowStepExecutor(),
            .workflowStatus: WorkflowStatusWorkflowStepExecutor(),
            .notesSummary: NotesSummaryWorkflowStepExecutor(),
            .move: MoveWorkflowStepExecutor()
        ]
        self.sideEffectExecutorsByKind = sideEffectExecutorsByKind ?? [
            .log: LogWorkflowStepExecutor(),
            .notify: NotifyWorkflowStepExecutor()
        ]
        self.clock = clock
    }

    @discardableResult
    func run(
        request: WorkflowExecutionRequest,
        plan: WorkflowPlan,
        files: [FileItem],
        modelContext: ModelContext
    ) async throws -> WorkflowRunRecord {
        let runRecord = try auditOperations.createRun(
            scopeID: request.scopeID,
            workflowTemplateID: request.templateID,
            triggerSurface: request.triggerSurface,
            ownerDisplayName: request.auditOwnerDisplayName,
            policyName: request.auditPolicyName,
            startedAt: clock(),
            primaryStatus: .running
        )

        recordPreflightAudit(runID: runRecord.id, plan: plan)

        guard !plan.hasBlockers else {
            try auditOperations.updateRunStatus(
                runID: runRecord.id,
                primaryStatus: .failed,
                endedAt: clock()
            )
            recordWorkflowMemoryOutcome(
                request: request,
                runRecord: runRecord,
                outcome: .blockedPreflightOnly,
                modelContext: modelContext
            )
            throw RunnerError.blockedPlan(plan.files.flatMap(\.blockers))
        }

        let fileLookup = Dictionary(uniqueKeysWithValues: files.map {
            (FileMetadataRecord.normalizedPath($0.path), $0)
        })
        let metadataService = FileMetadataFoundationService(
            modelContext: ModelContext(modelContext.container)
        )
        var executedActions: [ExecutedFileAction] = []
        var terminalError: Error?
        var firstAbandonedFileIndex: Int?

        fileLoop: for (plannedFileIndex, plannedFile) in plan.files.enumerated() {
            guard let file = fileLookup[FileMetadataRecord.normalizedPath(plannedFile.sourcePath)] else {
                throw RunnerError.missingFile(plannedFile.sourcePath)
            }

            let fileIdentity = metadataService.resolveIdentity(for: plannedFile.sourcePath).canonicalIdentity

            for plannedStep in plannedFile.steps
            where plannedStep.disposition == .planned && !Self.isSideEffectStep(plannedStep.kind) {
                guard let executor = executorsByKind[plannedStep.kind] else {
                    throw RunnerError.missingExecutor(plannedStep.kind)
                }

                let startedAt = clock()
                let stepID = Self.stepID(
                    phase: "execute",
                    stepKind: plannedStep.kind,
                    filePath: plannedFile.sourcePath
                )
                var preparedAction: WorkflowFileActionRecord?

                do {
                    let prepared = try executor.prepareExecution(
                        file: file,
                        plannedFile: plannedFile,
                        modelContext: modelContext
                    )
                    preparedAction = try auditOperations.recordFileAction(
                        AuditFileActionRequest(
                            runID: runRecord.id,
                            stepRunID: nil,
                            fileIdentity: fileIdentity,
                            sourcePath: prepared.sourcePath,
                            destinationPath: prepared.destinationPath,
                            disposition: .pending,
                            compensationStatus: prepared.compensationStatus,
                            compensationPayload: prepared.compensationAuditPayload,
                            metadataDelta: prepared.metadataDelta,
                            failureReason: nil,
                            recordedAt: startedAt
                        )
                    )

                    let result = try await executor.execute(
                        file: file,
                        plannedFile: plannedFile,
                        modelContext: modelContext
                    )
                    let endedAt = clock()
                    if let executedAction = executedAction(
                        stepKind: plannedStep.kind,
                        file: file,
                        fileIdentity: fileIdentity,
                        compensationStatus: result.compensationStatus,
                        compensationRecordID: preparedAction?.id,
                        metadataDelta: result.metadataDelta
                    ) {
                        executedActions.append(executedAction)
                    }

                    recordSuccessfulStepAudit(
                        runID: runRecord.id,
                        stepID: stepID,
                        fileIdentity: fileIdentity,
                        result: result,
                        startedAt: startedAt,
                        endedAt: endedAt,
                        metadataDelta: result.metadataDelta
                    )
                } catch let failure as WorkflowStepExecutionFailure {
                    if let executedAction = executedAction(
                        stepKind: plannedStep.kind,
                        file: file,
                        fileIdentity: fileIdentity,
                        compensationStatus: failure.compensationStatus,
                        compensationRecordID: preparedAction?.id,
                        metadataDelta: failure.metadataDelta
                    ) {
                        executedActions.append(executedAction)
                    }

                    let endedAt = clock()
                    recordFailureAudit(
                        runID: runRecord.id,
                        stepID: stepID,
                        fileIdentity: fileIdentity,
                        sourcePath: failure.sourcePath,
                        destinationPath: failure.destinationPath,
                        compensationStatus: failure.compensationStatus,
                        compensationPayload: failure.compensationAuditPayload,
                        metadataDelta: failure.metadataDelta,
                        failureReason: failure.localizedDescription,
                        startedAt: startedAt,
                        endedAt: endedAt
                    )

                    try await handleFailure(
                        error: failure.underlyingError,
                        runID: runRecord.id,
                        executedActions: executedActions,
                        modelContext: modelContext
                    )
                    terminalError = failure.underlyingError
                    firstAbandonedFileIndex = plannedFileIndex + 1
                    break fileLoop
                } catch {
                    let endedAt = clock()
                    recordFailureAudit(
                        runID: runRecord.id,
                        stepID: stepID,
                        fileIdentity: fileIdentity,
                        sourcePath: file.path,
                        destinationPath: file.path,
                        compensationStatus: .notNeeded,
                        compensationPayload: nil,
                        metadataDelta: nil,
                        failureReason: error.localizedDescription,
                        startedAt: startedAt,
                        endedAt: endedAt
                    )

                    try await handleFailure(
                        error: error,
                        runID: runRecord.id,
                        executedActions: executedActions,
                        modelContext: modelContext
                    )
                    terminalError = error
                    firstAbandonedFileIndex = plannedFileIndex + 1
                    break fileLoop
                }
            }
        }

        if let firstAbandonedFileIndex,
           firstAbandonedFileIndex < plan.files.count {
            recordAbandonedFileAudits(
                runID: runRecord.id,
                plannedFiles: plan.files[firstAbandonedFileIndex...],
                fileLookup: fileLookup,
                metadataService: metadataService
            )
        }

        var finalPrimaryStatus: WorkflowRunPrimaryStatus
        if terminalError == nil {
            finalPrimaryStatus = .succeeded
            do {
                try auditOperations.updateRunStatus(
                    runID: runRecord.id,
                    primaryStatus: .succeeded,
                    endedAt: clock()
                )
            } catch {
                // Filesystem mutations already completed successfully.
            }
        } else {
            finalPrimaryStatus = .failed
        }

        finalPrimaryStatus = try await executeSideEffectSteps(
            runRecord: runRecord,
            plan: plan,
            files: files,
            currentPrimaryStatus: finalPrimaryStatus,
            modelContext: modelContext
        )

        recordWorkflowMemoryOutcome(
            request: request,
            runRecord: runRecord,
            outcome: terminalError == nil ? .durableSuccess : .conflictedFailure,
            modelContext: modelContext
        )

        if let terminalError {
            throw terminalError
        }

        return runRecord
    }

    @discardableResult
    func run(
        plan: WorkflowPlan,
        files: [FileItem],
        scopeID: UUID,
        modelContext: ModelContext
    ) async throws -> WorkflowRunRecord {
        try await run(
            request: WorkflowExecutionRequest(
                templateID: plan.definition.templateID,
                scopeID: scopeID,
                invocationContext: plan.definition.invocationContext
            ),
            plan: plan,
            files: files,
            modelContext: modelContext
        )
    }

    private func handleFailure(
        error: Error,
        runID: UUID,
        executedActions: [ExecutedFileAction],
        modelContext: ModelContext
    ) async throws {
        let endedAt = clock()
        do {
            try auditOperations.updateRunStatus(
                runID: runID,
                primaryStatus: .failed,
                endedAt: endedAt
            )
        } catch {
            // Rollback must continue when audit status persistence fails.
        }

        let compensationActions: [WorkflowCompensationAction] = try executedActions.compactMap { executedAction in
            guard let executor = executorsByKind[executedAction.stepKind] else {
                throw RunnerError.missingExecutor(executedAction.stepKind)
            }

            let compensationPayload = try persistedCompensationPayload(
                for: executedAction.compensationRecordID,
                modelContext: modelContext
            )
            guard let compensationAction = try executor.makeCompensationAction(
                fileIdentity: executedAction.fileIdentity,
                compensationPayload: compensationPayload,
                file: executedAction.file,
                modelContext: modelContext
            ) else {
                return nil
            }

            return WorkflowCompensationAction(
                stepKind: compensationAction.stepKind,
                fileIdentity: compensationAction.fileIdentity,
                sourcePath: compensationAction.sourcePath,
                destinationPath: compensationAction.destinationPath,
                metadataDelta: executedAction.rollbackMetadataDelta ?? compensationAction.metadataDelta,
                apply: compensationAction.apply
            )
        }

        guard !compensationActions.isEmpty else {
            return
        }

        let rollbackRequestedAt = clock()
        do {
            try auditOperations.updateRollbackStatus(
                runID: runID,
                rollbackStatus: .requested,
                rollbackReason: error.localizedDescription,
                rollbackRequestedAt: rollbackRequestedAt,
                updatedAt: rollbackRequestedAt
            )
        } catch {
            // Rollback must continue when audit status persistence fails.
        }
        do {
            try auditOperations.updateRollbackStatus(
                runID: runID,
                rollbackStatus: .inProgress,
                updatedAt: rollbackRequestedAt
            )
        } catch {
            // Rollback must continue when audit status persistence fails.
        }

        let outcomes = await rollbackCoordinator.rollback(compensationActions)
        for outcome in outcomes {
            recordRollbackOutcomeAudit(runID: runID, outcome: outcome)
        }

        let rollbackCompletedAt = clock()
        do {
            try auditOperations.updateRollbackStatus(
                runID: runID,
                rollbackStatus: outcomes.allSatisfy { $0.succeeded } ? .succeeded : .failed,
                rollbackReason: error.localizedDescription,
                rollbackCompletedAt: rollbackCompletedAt,
                updatedAt: rollbackCompletedAt
            )
        } catch {
            // The original execution failure remains the surfaced error.
        }
    }

    private func executeSideEffectSteps(
        runRecord: WorkflowRunRecord,
        plan: WorkflowPlan,
        files: [FileItem],
        currentPrimaryStatus: WorkflowRunPrimaryStatus,
        modelContext: ModelContext
    ) async throws -> WorkflowRunPrimaryStatus {
        var resolvedPrimaryStatus = currentPrimaryStatus

        for stepKind in orderedSideEffectStepKinds(from: plan.definition.stepKinds) {
            if stepKind == .notify && resolvedPrimaryStatus == .failed {
                continue
            }

            guard let executor = sideEffectExecutorsByKind[stepKind] else {
                throw RunnerError.missingExecutor(stepKind)
            }

            let startedAt = clock()
            let stepID = Self.finalizeStepID(stepKind)
            let context = WorkflowRunSideEffectExecutionContext(
                run: runRecord,
                plan: plan,
                files: files,
                modelContext: modelContext
            )

            do {
                let result = try await executor.execute(context: context)
                let endedAt = clock()
                recordSideEffectAudit(
                    runID: runRecord.id,
                    stepID: stepID,
                    files: files,
                    stepStatus: result.stepStatus,
                    disposition: result.disposition,
                    startedAt: startedAt,
                    endedAt: endedAt,
                    modelContext: modelContext
                )
            } catch {
                let endedAt = clock()
                recordSideEffectFailureAudit(
                    runID: runRecord.id,
                    stepID: stepID,
                    files: files,
                    failureReason: error.localizedDescription,
                    startedAt: startedAt,
                    endedAt: endedAt,
                    modelContext: modelContext
                )

                if resolvedPrimaryStatus != .failed {
                    resolvedPrimaryStatus = .completedWithIssues
                    do {
                        try auditOperations.updateRunStatus(
                            runID: runRecord.id,
                            primaryStatus: .completedWithIssues,
                            endedAt: endedAt
                        )
                    } catch {
                        // Side-effect failure should not recast durable success as a thrown error.
                    }
                }
            }
        }

        return resolvedPrimaryStatus
    }

    private func recordWorkflowMemoryOutcome(
        request: WorkflowExecutionRequest,
        runRecord: WorkflowRunRecord,
        outcome: WorkflowMemoryOutcome,
        modelContext: ModelContext
    ) {
        guard let memoryAttribution = request.workflowMemoryAttribution else {
            return
        }

        runRecord.workflowTemplateID = WorkflowRunRecord.normalizedOptionalText(
            runRecord.workflowTemplateID ?? memoryAttribution.templateID
        )
        runRecord.triggerSurface = runRecord.triggerSurface ?? memoryAttribution.triggerSurface
        runRecord.ownerDisplayName = WorkflowRunRecord.normalizedOptionalText(
            runRecord.ownerDisplayName ?? memoryAttribution.ownerDisplayName
        )
        runRecord.policyName = WorkflowRunRecord.normalizedOptionalText(
            runRecord.policyName ?? memoryAttribution.policyName
        )

        let runMemoryOutcome: ProjectSpaceWorkflowProfileService.RunMemoryOutcome
        switch outcome {
        case .durableSuccess:
            runMemoryOutcome = .durableSuccess
        case .blockedPreflightOnly:
            runMemoryOutcome = .blockedPreflightOnly
        case .conflictedFailure:
            runMemoryOutcome = .conflictedFailure
        }

        do {
            try ProjectSpaceWorkflowProfileService(modelContext: modelContext).recordLatestRun(
                runRecord,
                for: memoryAttribution.normalizedProjectLabel,
                at: clock(),
                outcome: runMemoryOutcome
            )
        } catch {
            // Workflow memory persistence should not recast execution outcomes.
        }
    }

    private func recordPreflightAudit(runID: UUID, plan: WorkflowPlan) {
        let recordedAt = clock()

        for plannedFile in plan.files {
            for plannedStep in plannedFile.steps where !Self.isSideEffectStep(plannedStep.kind) {
                do {
                    _ = try auditOperations.recordStepStatus(
                        AuditStepStatusRequest(
                            runID: runID,
                            stepID: Self.stepID(
                                phase: "execute",
                                stepKind: plannedStep.kind,
                                filePath: plannedFile.sourcePath
                            ),
                            status: Self.preflightStatus(for: plannedStep.disposition),
                            startedAt: nil,
                            endedAt: recordedAt,
                            errorMessage: plannedStep.blocker.map { String(describing: $0) },
                            recordedAt: recordedAt
                        )
                    )
                } catch {
                    // Preflight audit failures must not block execution or rollback.
                }
            }
        }
    }

    private func recordAbandonedFileAudits(
        runID: UUID,
        plannedFiles: ArraySlice<WorkflowPlannedFile>,
        fileLookup: [String: FileItem],
        metadataService: FileMetadataFoundationService
    ) {
        for plannedFile in plannedFiles {
            let file = fileLookup[FileMetadataRecord.normalizedPath(plannedFile.sourcePath)]
            let sourcePath = file?.path ?? plannedFile.sourcePath
            let fileIdentity = metadataService.resolveIdentity(for: sourcePath).canonicalIdentity
            let recordedAt = clock()
            var firstStepRunID: UUID?

            for plannedStep in plannedFile.steps
            where plannedStep.disposition == .planned && !Self.isSideEffectStep(plannedStep.kind) {
                do {
                    let stepRun = try auditOperations.recordStepStatus(
                        AuditStepStatusRequest(
                            runID: runID,
                            stepID: Self.stepID(
                                phase: "execute",
                                stepKind: plannedStep.kind,
                                filePath: plannedFile.sourcePath
                            ),
                            status: .skipped,
                            startedAt: nil,
                            endedAt: recordedAt,
                            errorMessage: Self.abandonedAfterUpstreamFailureReason,
                            recordedAt: recordedAt
                        )
                    )
                    firstStepRunID = firstStepRunID ?? stepRun.id
                } catch {
                    // Abandoned-file audit rows should not mask the original execution failure.
                }
            }

            do {
                _ = try auditOperations.recordFileAction(
                    AuditFileActionRequest(
                        runID: runID,
                        stepRunID: firstStepRunID,
                        fileIdentity: fileIdentity,
                        sourcePath: sourcePath,
                        destinationPath: sourcePath,
                        disposition: .skipped,
                        compensationStatus: .notNeeded,
                        compensationPayload: nil,
                        metadataDelta: nil,
                        failureReason: Self.abandonedAfterUpstreamFailureReason,
                        recordedAt: recordedAt
                    )
                )
            } catch {
                // The terminal execution failure remains the surfaced error.
            }
        }
    }

    private func recordSuccessfulStepAudit(
        runID: UUID,
        stepID: String,
        fileIdentity: String,
        result: WorkflowStepExecutionResult,
        startedAt: Date,
        endedAt: Date,
        metadataDelta: WorkflowFileMetadataDelta?
    ) {
        do {
            let stepRun = try auditOperations.recordStepStatus(
                AuditStepStatusRequest(
                    runID: runID,
                    stepID: stepID,
                    status: .succeeded,
                    startedAt: startedAt,
                    endedAt: endedAt,
                    errorMessage: nil,
                    recordedAt: endedAt
                )
            )
            _ = try auditOperations.recordFileAction(
                AuditFileActionRequest(
                    runID: runID,
                    stepRunID: stepRun.id,
                    fileIdentity: fileIdentity,
                    sourcePath: result.sourcePath,
                    destinationPath: result.destinationPath,
                    disposition: result.disposition,
                    compensationStatus: result.compensationStatus,
                    compensationPayload: result.compensationAuditPayload,
                    metadataDelta: metadataDelta,
                    failureReason: nil,
                    recordedAt: endedAt
                )
            )
        } catch {
            // Successful filesystem work must not be recast as a workflow failure.
        }
    }

    private func recordSideEffectAudit(
        runID: UUID,
        stepID: String,
        files: [FileItem],
        stepStatus: WorkflowStepStatus,
        disposition: WorkflowFileDisposition,
        startedAt: Date,
        endedAt: Date,
        modelContext: ModelContext
    ) {
        do {
            let stepRun = try auditOperations.recordStepStatus(
                AuditStepStatusRequest(
                    runID: runID,
                    stepID: stepID,
                    status: stepStatus,
                    startedAt: startedAt,
                    endedAt: endedAt,
                    errorMessage: nil,
                    recordedAt: endedAt
                )
            )
            let metadataService = FileMetadataFoundationService(
                modelContext: ModelContext(modelContext.container)
            )
            for file in files {
                let fileIdentity = metadataService.resolveIdentity(for: file.path).canonicalIdentity
                _ = try auditOperations.recordFileAction(
                    AuditFileActionRequest(
                        runID: runID,
                        stepRunID: stepRun.id,
                        fileIdentity: fileIdentity,
                        sourcePath: file.path,
                        destinationPath: file.path,
                    disposition: disposition,
                    compensationStatus: .notNeeded,
                    compensationPayload: nil,
                    metadataDelta: nil,
                    failureReason: nil,
                    recordedAt: endedAt
                )
            )
            }
        } catch {
            // Side-effect audit failures must not surface as workflow execution failures.
        }
    }

    private func recordRollbackOutcomeAudit(
        runID: UUID,
        outcome: WorkflowCompensationOutcome
    ) {
        let recordedAt = clock()

        do {
            let stepRun = try auditOperations.recordStepStatus(
                AuditStepStatusRequest(
                    runID: runID,
                    stepID: Self.stepID(
                        phase: "rollback",
                        stepKind: outcome.action.stepKind,
                        filePath: outcome.action.fileIdentity
                    ),
                    status: outcome.succeeded ? .succeeded : .failed,
                    startedAt: recordedAt,
                    endedAt: recordedAt,
                    errorMessage: outcome.error?.localizedDescription,
                    recordedAt: recordedAt
                )
            )
            _ = try auditOperations.recordFileAction(
                AuditFileActionRequest(
                    runID: runID,
                    stepRunID: stepRun.id,
                    fileIdentity: outcome.action.fileIdentity,
                    sourcePath: outcome.action.sourcePath,
                    destinationPath: outcome.action.destinationPath,
                    disposition: outcome.succeeded ? .restored : .failed,
                    compensationStatus: outcome.succeeded ? .applied : .failed,
                    compensationPayload: nil,
                    metadataDelta: rollbackMetadataDelta(for: outcome),
                    failureReason: outcome.error?.localizedDescription,
                    recordedAt: recordedAt
                )
            )
        } catch {
            // Rollback is already complete; retain the original execution failure.
        }
    }

    private func recordSideEffectFailureAudit(
        runID: UUID,
        stepID: String,
        files: [FileItem],
        failureReason: String,
        startedAt: Date,
        endedAt: Date,
        modelContext: ModelContext
    ) {
        do {
            let stepRun = try auditOperations.recordStepStatus(
                AuditStepStatusRequest(
                    runID: runID,
                    stepID: stepID,
                    status: .failed,
                    startedAt: startedAt,
                    endedAt: endedAt,
                    errorMessage: failureReason,
                    recordedAt: endedAt
                )
            )
            let metadataService = FileMetadataFoundationService(
                modelContext: ModelContext(modelContext.container)
            )
            for file in files {
                let fileIdentity = metadataService.resolveIdentity(for: file.path).canonicalIdentity
                _ = try auditOperations.recordFileAction(
                    AuditFileActionRequest(
                        runID: runID,
                        stepRunID: stepRun.id,
                        fileIdentity: fileIdentity,
                        sourcePath: file.path,
                        destinationPath: file.path,
                    disposition: .failed,
                    compensationStatus: .notNeeded,
                    compensationPayload: nil,
                    metadataDelta: nil,
                    failureReason: failureReason,
                    recordedAt: endedAt
                )
            )
            }
        } catch {
            // Side-effect audit failures must not surface as workflow execution failures.
        }
    }

    private static func stepID(
        phase: String,
        stepKind: WorkflowStepKind,
        filePath: String
    ) -> String {
        "\(phase)|\(stepKind.rawValue)|\(filePath)"
    }

    private static func finalizeStepID(_ stepKind: WorkflowStepKind) -> String {
        "finalize|\(stepKind.rawValue)"
    }

    private static func isSideEffectStep(_ stepKind: WorkflowStepKind) -> Bool {
        stepKind == .log || stepKind == .notify
    }

    private static func preflightStatus(for disposition: WorkflowStepDisposition) -> WorkflowStepStatus {
        switch disposition {
        case .planned:
            return .planned
        case .blocked:
            return .blocked
        case .skipped:
            return .skipped
        }
    }

    private func orderedSideEffectStepKinds(from stepKinds: [WorkflowStepKind]) -> [WorkflowStepKind] {
        let uniqueKinds = Array(Set(stepKinds.filter(Self.isSideEffectStep)))
        let priority: [WorkflowStepKind: Int] = [
            .notify: 0,
            .log: 1
        ]

        return uniqueKinds.sorted { lhs, rhs in
            let lhsPriority = priority[lhs, default: Int.max]
            let rhsPriority = priority[rhs, default: Int.max]
            if lhsPriority == rhsPriority {
                return lhs.rawValue < rhs.rawValue
            }
            return lhsPriority < rhsPriority
        }
    }

    private func executedAction(
        stepKind: WorkflowStepKind,
        file: FileItem,
        fileIdentity: String,
        compensationStatus: WorkflowCompensationStatus,
        compensationRecordID: UUID?,
        metadataDelta: WorkflowFileMetadataDelta?
    ) -> ExecutedFileAction? {
        guard compensationStatus == .available,
              let compensationRecordID else {
            return nil
        }

        return ExecutedFileAction(
            stepKind: stepKind,
            file: file,
            fileIdentity: fileIdentity,
            compensationRecordID: compensationRecordID,
            rollbackMetadataDelta: inverseMetadataDelta(for: metadataDelta)
        )
    }

    private func persistedCompensationPayload(
        for fileActionID: UUID,
        modelContext: ModelContext
    ) throws -> [String: String]? {
        let fileAction = try modelContext
            .fetch(FetchDescriptor<WorkflowFileActionRecord>())
            .first(where: { $0.id == fileActionID })

        guard let fileAction else {
            throw RunnerError.missingCompensationRecord(fileActionID)
        }

        guard let compensationPayload = fileAction.compensationPayload else {
            throw RunnerError.missingCompensationPayload(fileActionID)
        }

        return compensationPayload
    }

    private func rollbackMetadataDelta(for outcome: WorkflowCompensationOutcome) -> WorkflowFileMetadataDelta? {
        outcome.action.metadataDelta
    }

    private func inverseMetadataDelta(for metadataDelta: WorkflowFileMetadataDelta?) -> WorkflowFileMetadataDelta? {
        guard let metadataDelta else {
            return nil
        }

        let inverted = WorkflowFileMetadataDelta(
            addedTags: metadataDelta.removedTags,
            removedTags: metadataDelta.addedTags,
            previousProjectAssociation: metadataDelta.resultingProjectAssociation,
            resultingProjectAssociation: metadataDelta.previousProjectAssociation,
            previousWorkflowStatus: metadataDelta.resultingWorkflowStatus,
            resultingWorkflowStatus: metadataDelta.previousWorkflowStatus,
            previousNotesSummary: metadataDelta.resultingNotesSummary,
            resultingNotesSummary: metadataDelta.previousNotesSummary
        )

        return inverted.isEmpty ? nil : inverted
    }

    private func recordFailureAudit(
        runID: UUID,
        stepID: String,
        fileIdentity: String,
        sourcePath: String?,
        destinationPath: String?,
        compensationStatus: WorkflowCompensationStatus,
        compensationPayload: [String: String]?,
        metadataDelta: WorkflowFileMetadataDelta?,
        failureReason: String,
        startedAt: Date,
        endedAt: Date
    ) {
        do {
            let stepRun = try auditOperations.recordStepStatus(
                AuditStepStatusRequest(
                    runID: runID,
                    stepID: stepID,
                    status: .failed,
                    startedAt: startedAt,
                    endedAt: endedAt,
                    errorMessage: failureReason,
                    recordedAt: endedAt
                )
            )
            _ = try auditOperations.recordFileAction(
                AuditFileActionRequest(
                    runID: runID,
                    stepRunID: stepRun.id,
                    fileIdentity: fileIdentity,
                    sourcePath: sourcePath,
                    destinationPath: destinationPath,
                    disposition: .failed,
                    compensationStatus: compensationStatus,
                    compensationPayload: compensationPayload,
                    metadataDelta: metadataDelta,
                    failureReason: failureReason,
                    recordedAt: endedAt
                )
            )
        } catch {
            // Rollback must still proceed even if late audit persistence fails.
        }
    }
}
