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

    init(
        sourcePath: String?,
        destinationPath: String?,
        compensationStatus: WorkflowCompensationStatus,
        compensationPayloadDescriptor: WorkflowCompensationPayloadDescriptor?,
        compensationAuditPayload: [String: String]? = nil
    ) {
        self.sourcePath = sourcePath
        self.destinationPath = destinationPath
        self.compensationStatus = compensationStatus
        self.compensationPayloadDescriptor = compensationPayloadDescriptor
        self.compensationAuditPayload = compensationAuditPayload
            ?? WorkflowCompensationPayloadCodec.encode(compensationPayloadDescriptor)
    }
}

struct WorkflowStepExecutionResult {
    let sourcePath: String?
    let destinationPath: String?
    let disposition: WorkflowFileDisposition
    let compensationStatus: WorkflowCompensationStatus
    let compensationPayloadDescriptor: WorkflowCompensationPayloadDescriptor?
    let compensationAuditPayload: [String: String]?

    init(
        sourcePath: String?,
        destinationPath: String?,
        disposition: WorkflowFileDisposition,
        compensationStatus: WorkflowCompensationStatus,
        compensationPayloadDescriptor: WorkflowCompensationPayloadDescriptor?,
        compensationAuditPayload: [String: String]? = nil
    ) {
        self.sourcePath = sourcePath
        self.destinationPath = destinationPath
        self.disposition = disposition
        self.compensationStatus = compensationStatus
        self.compensationPayloadDescriptor = compensationPayloadDescriptor
        self.compensationAuditPayload = compensationAuditPayload
            ?? WorkflowCompensationPayloadCodec.encode(compensationPayloadDescriptor)
    }
}

struct WorkflowStepExecutionFailure: Error, LocalizedError {
    let underlyingError: Error
    let sourcePath: String?
    let destinationPath: String?
    let compensationStatus: WorkflowCompensationStatus
    let compensationPayloadDescriptor: WorkflowCompensationPayloadDescriptor?
    let compensationAuditPayload: [String: String]?

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
                createRunImpl: { scopeID, workflowTemplateID, startedAt, primaryStatus in
                    try store.createRun(
                        scopeID: scopeID,
                        workflowTemplateID: workflowTemplateID,
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
            startedAt: Date,
            primaryStatus: WorkflowRunPrimaryStatus
        ) throws -> WorkflowRunRecord {
            try createRunImpl(scopeID, workflowTemplateID, startedAt, primaryStatus)
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
    }

    private let auditOperations: AuditOperations
    private let rollbackCoordinator: WorkflowRollbackCoordinator
    private let executorsByKind: [WorkflowStepKind: any WorkflowStepExecutor]
    private let clock: () -> Date

    init(
        auditStore: WorkflowAuditStore,
        rollbackCoordinator: WorkflowRollbackCoordinator = WorkflowRollbackCoordinator(),
        executorsByKind: [WorkflowStepKind: any WorkflowStepExecutor]? = nil,
        clock: @escaping () -> Date = Date.init,
        auditOperations: AuditOperations? = nil
    ) {
        self.auditOperations = auditOperations ?? AuditOperations.live(store: auditStore)
        self.rollbackCoordinator = rollbackCoordinator
        self.executorsByKind = executorsByKind ?? [
            .rename: RenameWorkflowStepExecutor(),
            .tag: TagWorkflowStepExecutor(),
            .move: MoveWorkflowStepExecutor()
        ]
        self.clock = clock
    }

    @discardableResult
    func run(
        plan: WorkflowPlan,
        files: [FileItem],
        scopeID: UUID,
        modelContext: ModelContext
    ) async throws -> WorkflowRunRecord {
        let runRecord = try auditOperations.createRun(
            scopeID: scopeID,
            workflowTemplateID: plan.definition.templateID,
            startedAt: clock(),
            primaryStatus: .running
        )

        guard !plan.hasBlockers else {
            try auditOperations.updateRunStatus(
                runID: runRecord.id,
                primaryStatus: .failed,
                endedAt: clock()
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

        for plannedFile in plan.files {
            guard let file = fileLookup[FileMetadataRecord.normalizedPath(plannedFile.sourcePath)] else {
                throw RunnerError.missingFile(plannedFile.sourcePath)
            }

            let fileIdentity = metadataService.resolveIdentity(for: plannedFile.sourcePath).canonicalIdentity

            for plannedStep in plannedFile.steps where plannedStep.disposition == .planned {
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
                        compensationRecordID: preparedAction?.id
                    ) {
                        executedActions.append(executedAction)
                    }

                    recordSuccessfulStepAudit(
                        runID: runRecord.id,
                        stepID: stepID,
                        fileIdentity: fileIdentity,
                        result: result,
                        startedAt: startedAt,
                        endedAt: endedAt
                    )
                } catch let failure as WorkflowStepExecutionFailure {
                    if let executedAction = executedAction(
                        stepKind: plannedStep.kind,
                        file: file,
                        fileIdentity: fileIdentity,
                        compensationStatus: failure.compensationStatus,
                        compensationRecordID: preparedAction?.id
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
                    throw failure.underlyingError
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
                    throw error
                }
            }
        }

        do {
            try auditOperations.updateRunStatus(
                runID: runRecord.id,
                primaryStatus: .succeeded,
                endedAt: clock()
            )
        } catch {
            // Filesystem mutations already completed successfully.
        }
        return runRecord
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

        let compensationActions = try executedActions.compactMap { executedAction in
            guard let executor = executorsByKind[executedAction.stepKind] else {
                throw RunnerError.missingExecutor(executedAction.stepKind)
            }

            let compensationPayload = try persistedCompensationPayload(
                for: executedAction.compensationRecordID,
                modelContext: modelContext
            )
            return try executor.makeCompensationAction(
                fileIdentity: executedAction.fileIdentity,
                compensationPayload: compensationPayload,
                file: executedAction.file,
                modelContext: modelContext
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
                rollbackStatus: outcomes.allSatisfy(\.succeeded) ? .succeeded : .failed,
                rollbackReason: error.localizedDescription,
                rollbackCompletedAt: rollbackCompletedAt,
                updatedAt: rollbackCompletedAt
            )
        } catch {
            // The original execution failure remains the surfaced error.
        }
    }

    private func recordSuccessfulStepAudit(
        runID: UUID,
        stepID: String,
        fileIdentity: String,
        result: WorkflowStepExecutionResult,
        startedAt: Date,
        endedAt: Date
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
                    failureReason: nil,
                    recordedAt: endedAt
                )
            )
        } catch {
            // Successful filesystem work must not be recast as a workflow failure.
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
                    failureReason: outcome.error?.localizedDescription,
                    recordedAt: recordedAt
                )
            )
        } catch {
            // Rollback is already complete; retain the original execution failure.
        }
    }

    private static func stepID(
        phase: String,
        stepKind: WorkflowStepKind,
        filePath: String
    ) -> String {
        "\(phase)|\(stepKind.rawValue)|\(filePath)"
    }

    private func executedAction(
        stepKind: WorkflowStepKind,
        file: FileItem,
        fileIdentity: String,
        compensationStatus: WorkflowCompensationStatus,
        compensationRecordID: UUID?
    ) -> ExecutedFileAction? {
        guard compensationStatus == .available,
              let compensationRecordID else {
            return nil
        }

        return ExecutedFileAction(
            stepKind: stepKind,
            file: file,
            fileIdentity: fileIdentity,
            compensationRecordID: compensationRecordID
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

    private func recordFailureAudit(
        runID: UUID,
        stepID: String,
        fileIdentity: String,
        sourcePath: String?,
        destinationPath: String?,
        compensationStatus: WorkflowCompensationStatus,
        compensationPayload: [String: String]?,
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
                    failureReason: failureReason,
                    recordedAt: endedAt
                )
            )
        } catch {
            // Rollback must still proceed even if late audit persistence fails.
        }
    }
}
