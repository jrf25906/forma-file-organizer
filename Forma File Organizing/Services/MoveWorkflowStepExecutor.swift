import Foundation
import SwiftData

@MainActor
struct MoveWorkflowStepExecutor: WorkflowStepExecutor {
    private static let originalStatusKey = "originalStatus"

    let stepKind: WorkflowStepKind = .move

    private let fileOrganizationCoordinator: FileOrganizationCoordinator
    private let recordTransition: @MainActor (
        _ file: FileItem,
        _ moveResult: FileOrganizationCoordinator.WorkflowMoveResult,
        _ modelContext: ModelContext
    ) throws -> Void

    init(
        fileOrganizationCoordinator: FileOrganizationCoordinator = FileOrganizationCoordinator(),
        recordTransition: @escaping @MainActor (
            _ file: FileItem,
            _ moveResult: FileOrganizationCoordinator.WorkflowMoveResult,
            _ modelContext: ModelContext
        ) throws -> Void = Self.defaultRecordTransition
    ) {
        self.fileOrganizationCoordinator = fileOrganizationCoordinator
        self.recordTransition = recordTransition
    }

    func simulate(plannedFile: WorkflowPlannedFile) -> WorkflowSimulatedStep {
        plannedFile.steps.first(where: { $0.kind == stepKind })
            ?? WorkflowSimulatedStep(
                kind: stepKind,
                disposition: .skipped,
                blocker: nil,
                compensationPayload: nil
            )
    }

    func prepareExecution(
        file: FileItem,
        plannedFile: WorkflowPlannedFile,
        modelContext: ModelContext
    ) throws -> WorkflowPreparedStepExecution {
        guard let destinationPath = plannedFile.finalDestinationPath else {
            return WorkflowPreparedStepExecution(
                sourcePath: file.path,
                destinationPath: file.path,
                compensationStatus: .notNeeded,
                compensationPayloadDescriptor: nil
            )
        }

        guard destinationPath != file.path else {
            return WorkflowPreparedStepExecution(
                sourcePath: file.path,
                destinationPath: destinationPath,
                compensationStatus: .notNeeded,
                compensationPayloadDescriptor: nil
            )
        }

        let descriptor = WorkflowCompensationPayloadDescriptor.moveRollback(
            originalDestinationPath: destinationPath,
            rollbackPath: file.path
        )
        var auditPayload = WorkflowCompensationPayloadCodec.encode(descriptor) ?? [:]
        auditPayload[Self.originalStatusKey] = file.status.rawValue

        return WorkflowPreparedStepExecution(
            sourcePath: file.path,
            destinationPath: destinationPath,
            compensationStatus: .available,
            compensationPayloadDescriptor: descriptor,
            compensationAuditPayload: auditPayload
        )
    }

    func execute(
        file: FileItem,
        plannedFile: WorkflowPlannedFile,
        modelContext: ModelContext
    ) async throws -> WorkflowStepExecutionResult {
        let originalStatus = file.status
        var completedMove: FileOrganizationCoordinator.WorkflowMoveResult?

        do {
            let moveResult = try await fileOrganizationCoordinator.executeWorkflowMove(
                file,
                context: modelContext
            )
            completedMove = moveResult

            let descriptor = WorkflowCompensationPayloadDescriptor.moveRollback(
                originalDestinationPath: moveResult.destinationPath,
                rollbackPath: moveResult.originalPath
            )
            var auditPayload = WorkflowCompensationPayloadCodec.encode(descriptor) ?? [:]
            auditPayload[Self.originalStatusKey] = originalStatus.rawValue

            try recordTransition(file, moveResult, modelContext)

            return WorkflowStepExecutionResult(
                sourcePath: moveResult.originalPath,
                destinationPath: moveResult.destinationPath,
                disposition: .moved,
                compensationStatus: .available,
                compensationPayloadDescriptor: descriptor,
                compensationAuditPayload: auditPayload
            )
        } catch let failure as WorkflowStepExecutionFailure {
            throw failure
        } catch let workflowMoveError as FileOrganizationCoordinator.WorkflowMoveError {
            let descriptor = WorkflowCompensationPayloadDescriptor.moveRollback(
                originalDestinationPath: workflowMoveError.result.destinationPath,
                rollbackPath: workflowMoveError.result.originalPath
            )
            var auditPayload = WorkflowCompensationPayloadCodec.encode(descriptor) ?? [:]
            auditPayload[Self.originalStatusKey] = originalStatus.rawValue

            throw WorkflowStepExecutionFailure(
                underlyingError: workflowMoveError.underlyingError,
                sourcePath: workflowMoveError.result.originalPath,
                destinationPath: workflowMoveError.result.destinationPath,
                compensationStatus: .available,
                compensationPayloadDescriptor: descriptor,
                compensationAuditPayload: auditPayload
            )
        } catch {
            guard let completedMove else {
                throw error
            }

            let descriptor = WorkflowCompensationPayloadDescriptor.moveRollback(
                originalDestinationPath: completedMove.destinationPath,
                rollbackPath: completedMove.originalPath
            )
            var auditPayload = WorkflowCompensationPayloadCodec.encode(descriptor) ?? [:]
            auditPayload[Self.originalStatusKey] = originalStatus.rawValue

            throw WorkflowStepExecutionFailure(
                underlyingError: error,
                sourcePath: completedMove.originalPath,
                destinationPath: completedMove.destinationPath,
                compensationStatus: .available,
                compensationPayloadDescriptor: descriptor,
                compensationAuditPayload: auditPayload
            )
        }
    }

    func makeCompensationAction(
        fileIdentity: String,
        compensationPayload: [String: String]?,
        file: FileItem,
        modelContext: ModelContext
    ) throws -> WorkflowCompensationAction? {
        guard let payload = compensationPayload,
              let descriptor = WorkflowCompensationPayloadCodec.decode(payload) else {
            return nil
        }

        guard case .moveRollback(let originalDestinationPath, let rollbackPath) = descriptor else {
            return nil
        }

        let originalStatus = payload[Self.originalStatusKey]
            .flatMap(FileItem.OrganizationStatus.init(rawValue:))

        return WorkflowCompensationAction(
            stepKind: .move,
            fileIdentity: fileIdentity,
            sourcePath: originalDestinationPath,
            destinationPath: rollbackPath
        ) {
            let fileOperationsService = FileOperationsService()
            try fileOperationsService.secureMoveOnDisk(from: originalDestinationPath, to: rollbackPath)
            _ = file.updatePath(rollbackPath)
            if let originalStatus {
                file.status = originalStatus
            }
            try modelContext.save()

            let metadataService = FileMetadataFoundationService(
                modelContext: ModelContext(modelContext.container)
            )
            _ = try metadataService.recordWorkflowTransition(
                from: originalDestinationPath,
                to: rollbackPath,
                displayName: file.name,
                fileExtension: file.fileExtension,
                eventKind: .undone,
                sourceSurface: .undo,
                timestamp: Date()
            )
        }
    }

    private static func defaultRecordTransition(
        file: FileItem,
        moveResult: FileOrganizationCoordinator.WorkflowMoveResult,
        modelContext: ModelContext
    ) throws {
        let metadataService = FileMetadataFoundationService(
            modelContext: ModelContext(modelContext.container)
        )
        _ = try metadataService.recordWorkflowTransition(
            from: moveResult.originalPath,
            to: moveResult.destinationPath,
            displayName: file.name,
            fileExtension: file.fileExtension,
            eventKind: .organized,
            sourceSurface: .organize,
            destinationDisplayName: moveResult.destinationDisplayName,
            projectAssociationWriteContext: moveResult.projectAssociationWriteContext,
            matchedRuleID: file.matchedRuleID,
            timestamp: Date()
        )
    }
}
