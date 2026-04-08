import Foundation
import SwiftData

@MainActor
struct TagWorkflowStepExecutor: WorkflowStepExecutor {
    let stepKind: WorkflowStepKind = .tag

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
        let metadataService = FileMetadataFoundationService(
            modelContext: ModelContext(modelContext.container)
        )
        let appendedTags = try metadataService.previewWorkflowTags(
            path: plannedFile.workingPath,
            tags: plannedFile.tagIntents
        )

        let descriptor: WorkflowCompensationPayloadDescriptor? = appendedTags.isEmpty
            ? nil
            : .tagRemoval(path: plannedFile.workingPath, tagsToRemove: appendedTags)

        return WorkflowPreparedStepExecution(
            sourcePath: plannedFile.workingPath,
            destinationPath: plannedFile.workingPath,
            compensationStatus: appendedTags.isEmpty ? .notNeeded : .available,
            compensationPayloadDescriptor: descriptor
        )
    }

    func execute(
        file: FileItem,
        plannedFile: WorkflowPlannedFile,
        modelContext: ModelContext
    ) async throws -> WorkflowStepExecutionResult {
        let metadataService = FileMetadataFoundationService(
            modelContext: ModelContext(modelContext.container)
        )
        let appendedTags = try metadataService.applyWorkflowTags(
            path: plannedFile.workingPath,
            displayName: file.name,
            fileExtension: file.fileExtension,
            tags: plannedFile.tagIntents,
            timestamp: Date()
        )

        let descriptor: WorkflowCompensationPayloadDescriptor? = appendedTags.isEmpty
            ? nil
            : .tagRemoval(path: plannedFile.workingPath, tagsToRemove: appendedTags)

        return WorkflowStepExecutionResult(
            sourcePath: plannedFile.workingPath,
            destinationPath: plannedFile.workingPath,
            disposition: .pending,
            compensationStatus: appendedTags.isEmpty ? .notNeeded : .available,
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

        guard case .tagRemoval(let path, let tagsToRemove) = descriptor,
              !tagsToRemove.isEmpty else {
            return nil
        }

        return WorkflowCompensationAction(
            stepKind: .tag,
            fileIdentity: fileIdentity,
            sourcePath: path,
            destinationPath: path
        ) {
            let metadataService = FileMetadataFoundationService(
                modelContext: ModelContext(modelContext.container)
            )
            _ = try metadataService.removeWorkflowTags(path: path, tags: tagsToRemove)
        }
    }
}
