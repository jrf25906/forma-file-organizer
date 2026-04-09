import Foundation
import SwiftData

@MainActor
struct WorkflowStatusWorkflowStepExecutor: WorkflowStepExecutor {
    let stepKind: WorkflowStepKind = .workflowStatus

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
        guard let targetWorkflowStatus = plannedFile.workflowStatusTarget else {
            return WorkflowPreparedStepExecution(
                sourcePath: plannedFile.workingPath,
                destinationPath: plannedFile.workingPath,
                compensationStatus: .notNeeded,
                compensationPayloadDescriptor: nil
            )
        }

        let metadataService = FileMetadataFoundationService(
            modelContext: ModelContext(modelContext.container)
        )
        let preview = try metadataService.previewWorkflowStatus(
            path: plannedFile.workingPath,
            targetWorkflowStatus: targetWorkflowStatus
        )

        let descriptor = preview?.willChange == true
            ? WorkflowCompensationPayloadDescriptor.workflowStatusRestore(
                path: plannedFile.workingPath,
                previousWorkflowStatus: preview?.previousWorkflowStatus
            )
            : nil
        let metadataDelta = preview?.willChange == true
            ? WorkflowFileMetadataDelta(
                previousWorkflowStatus: preview?.previousWorkflowStatus,
                resultingWorkflowStatus: targetWorkflowStatus
            )
            : nil

        return WorkflowPreparedStepExecution(
            sourcePath: plannedFile.workingPath,
            destinationPath: plannedFile.workingPath,
            compensationStatus: descriptor == nil ? .notNeeded : .available,
            compensationPayloadDescriptor: descriptor,
            metadataDelta: metadataDelta
        )
    }

    func execute(
        file: FileItem,
        plannedFile: WorkflowPlannedFile,
        modelContext: ModelContext
    ) async throws -> WorkflowStepExecutionResult {
        guard let targetWorkflowStatus = plannedFile.workflowStatusTarget else {
            return WorkflowStepExecutionResult(
                sourcePath: plannedFile.workingPath,
                destinationPath: plannedFile.workingPath,
                disposition: .pending,
                compensationStatus: .notNeeded,
                compensationPayloadDescriptor: nil
            )
        }

        let metadataService = FileMetadataFoundationService(
            modelContext: ModelContext(modelContext.container)
        )
        let preview = try metadataService.applyWorkflowStatus(
            path: plannedFile.workingPath,
            displayName: file.name,
            fileExtension: file.fileExtension,
            targetWorkflowStatus: targetWorkflowStatus,
            timestamp: Date()
        )

        let descriptor = preview?.willChange == true
            ? WorkflowCompensationPayloadDescriptor.workflowStatusRestore(
                path: plannedFile.workingPath,
                previousWorkflowStatus: preview?.previousWorkflowStatus
            )
            : nil
        let metadataDelta = preview?.willChange == true
            ? WorkflowFileMetadataDelta(
                previousWorkflowStatus: preview?.previousWorkflowStatus,
                resultingWorkflowStatus: targetWorkflowStatus
            )
            : nil

        return WorkflowStepExecutionResult(
            sourcePath: plannedFile.workingPath,
            destinationPath: plannedFile.workingPath,
            disposition: .pending,
            compensationStatus: descriptor == nil ? .notNeeded : .available,
            compensationPayloadDescriptor: descriptor,
            metadataDelta: metadataDelta
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

        guard case .workflowStatusRestore(let path, let previousWorkflowStatus) = descriptor else {
            return nil
        }

        return WorkflowCompensationAction(
            stepKind: .workflowStatus,
            fileIdentity: fileIdentity,
            sourcePath: path,
            destinationPath: path,
            metadataDelta: nil
        ) {
            let metadataService = FileMetadataFoundationService(
                modelContext: ModelContext(modelContext.container)
            )
            _ = try metadataService.restoreWorkflowStatus(
                canonicalIdentity: fileIdentity,
                path: path,
                previousWorkflowStatus: previousWorkflowStatus,
                timestamp: Date()
            )
        }
    }
}
