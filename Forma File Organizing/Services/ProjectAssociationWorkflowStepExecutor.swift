import Foundation
import SwiftData

@MainActor
struct ProjectAssociationWorkflowStepExecutor: WorkflowStepExecutor {
    let stepKind: WorkflowStepKind = .projectAssociation

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
        guard let targetProjectAssociation = plannedFile.projectAssociationTarget else {
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
        let preview = try metadataService.previewWorkflowProjectAssociation(
            path: plannedFile.workingPath,
            targetProjectAssociation: targetProjectAssociation
        )

        let descriptor = preview?.willChange == true
            ? WorkflowCompensationPayloadDescriptor.projectAssociationRestore(
                path: plannedFile.workingPath,
                previousProjectAssociation: preview?.previousProjectAssociation
            )
            : nil
        let metadataDelta = preview?.willChange == true
            ? WorkflowFileMetadataDelta(
                previousProjectAssociation: preview?.previousProjectAssociation,
                resultingProjectAssociation: targetProjectAssociation
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
        guard let targetProjectAssociation = plannedFile.projectAssociationTarget else {
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
        let preview = try metadataService.applyWorkflowProjectAssociation(
            path: plannedFile.workingPath,
            displayName: file.name,
            fileExtension: file.fileExtension,
            targetProjectAssociation: targetProjectAssociation,
            timestamp: Date()
        )

        let descriptor = preview?.willChange == true
            ? WorkflowCompensationPayloadDescriptor.projectAssociationRestore(
                path: plannedFile.workingPath,
                previousProjectAssociation: preview?.previousProjectAssociation
            )
            : nil
        let metadataDelta = preview?.willChange == true
            ? WorkflowFileMetadataDelta(
                previousProjectAssociation: preview?.previousProjectAssociation,
                resultingProjectAssociation: targetProjectAssociation
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

        guard case .projectAssociationRestore(let path, let previousProjectAssociation) = descriptor else {
            return nil
        }

        return WorkflowCompensationAction(
            stepKind: .projectAssociation,
            fileIdentity: fileIdentity,
            sourcePath: path,
            destinationPath: path,
            metadataDelta: nil
        ) {
            let metadataService = FileMetadataFoundationService(
                modelContext: ModelContext(modelContext.container)
            )
            _ = try metadataService.restoreWorkflowProjectAssociation(
                canonicalIdentity: fileIdentity,
                path: path,
                previousProjectAssociation: previousProjectAssociation,
                timestamp: Date()
            )
        }
    }
}
