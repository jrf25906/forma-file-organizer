import Foundation
import SwiftData

@MainActor
struct RenameWorkflowStepExecutor: WorkflowStepExecutor {
    let stepKind: WorkflowStepKind = .rename

    private let fileOperationsService: FileOperationsService

    init(fileOperationsService: FileOperationsService = FileOperationsService()) {
        self.fileOperationsService = fileOperationsService
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
        let sourcePath = file.path
        let destinationPath = plannedFile.workingPath

        guard sourcePath != destinationPath else {
            return WorkflowPreparedStepExecution(
                sourcePath: sourcePath,
                destinationPath: destinationPath,
                compensationStatus: .notNeeded,
                compensationPayloadDescriptor: nil
            )
        }

        let descriptor = WorkflowCompensationPayloadDescriptor.renameRollback(
            originalPath: sourcePath,
            renamedPath: destinationPath
        )

        return WorkflowPreparedStepExecution(
            sourcePath: sourcePath,
            destinationPath: destinationPath,
            compensationStatus: .available,
            compensationPayloadDescriptor: descriptor
        )
    }

    func execute(
        file: FileItem,
        plannedFile: WorkflowPlannedFile,
        modelContext: ModelContext
    ) async throws -> WorkflowStepExecutionResult {
        let sourcePath = file.path
        let destinationPath = plannedFile.workingPath

        guard sourcePath != destinationPath else {
            return WorkflowStepExecutionResult(
                sourcePath: sourcePath,
                destinationPath: destinationPath,
                disposition: .pending,
                compensationStatus: .notNeeded,
                compensationPayloadDescriptor: nil
            )
        }

        let descriptor = WorkflowCompensationPayloadDescriptor.renameRollback(
            originalPath: sourcePath,
            renamedPath: destinationPath
        )

        do {
            try fileOperationsService.secureMoveOnDisk(from: sourcePath, to: destinationPath)
            _ = file.updatePath(destinationPath)
            try modelContext.save()

            let metadataService = FileMetadataFoundationService(
                modelContext: ModelContext(modelContext.container)
            )
            _ = try metadataService.recordWorkflowTransition(
                from: sourcePath,
                to: destinationPath,
                displayName: file.name,
                fileExtension: file.fileExtension,
                eventKind: .rekeyed,
                sourceSurface: .organize,
                timestamp: Date()
            )
        } catch {
            throw WorkflowStepExecutionFailure(
                underlyingError: error,
                sourcePath: sourcePath,
                destinationPath: destinationPath,
                compensationStatus: .available,
                compensationPayloadDescriptor: descriptor,
                compensationAuditPayload: WorkflowCompensationPayloadCodec.encode(descriptor),
                metadataDelta: nil
            )
        }

        return WorkflowStepExecutionResult(
            sourcePath: sourcePath,
            destinationPath: destinationPath,
            disposition: .moved,
            compensationStatus: .available,
            compensationPayloadDescriptor: descriptor
        )
    }

    func makeCompensationAction(
        fileIdentity: String,
        compensationPayload: [String: String]?,
        file: FileItem,
        modelContext: ModelContext
    ) throws -> WorkflowCompensationAction? {
        guard let descriptor = WorkflowCompensationPayloadCodec.decode(compensationPayload) else {
            return nil
        }

        guard case .renameRollback(let originalPath, let renamedPath) = descriptor else {
            return nil
        }

        return WorkflowCompensationAction(
            stepKind: .rename,
            fileIdentity: fileIdentity,
            sourcePath: renamedPath,
            destinationPath: originalPath,
            metadataDelta: nil
        ) {
            try fileOperationsService.secureMoveOnDisk(from: renamedPath, to: originalPath)
            _ = file.updatePath(originalPath)
            try modelContext.save()

            let metadataService = FileMetadataFoundationService(
                modelContext: ModelContext(modelContext.container)
            )
            _ = try metadataService.recordWorkflowRollbackTransition(
                from: renamedPath,
                to: originalPath,
                displayName: URL(fileURLWithPath: originalPath).lastPathComponent,
                fileExtension: URL(fileURLWithPath: originalPath).pathExtension,
                timestamp: Date()
            )
        }
    }
}
