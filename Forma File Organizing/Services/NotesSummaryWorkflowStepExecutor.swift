import Foundation
import SwiftData

@MainActor
struct NotesSummaryWorkflowStepExecutor: WorkflowStepExecutor {
    let stepKind: WorkflowStepKind = .notesSummary

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
        guard let targetNotesSummary = plannedFile.notesSummaryTarget else {
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
        let preview = try metadataService.previewWorkflowNotesSummary(
            path: plannedFile.workingPath,
            targetNotesSummary: targetNotesSummary
        )

        let descriptor = preview?.willChange == true
            ? WorkflowCompensationPayloadDescriptor.notesSummaryRestore(
                path: plannedFile.workingPath,
                previousNotesSummary: preview?.previousNotesSummary
            )
            : nil
        let metadataDelta = preview?.willChange == true
            ? WorkflowFileMetadataDelta(
                previousNotesSummary: preview?.previousNotesSummary,
                resultingNotesSummary: targetNotesSummary
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
        guard let targetNotesSummary = plannedFile.notesSummaryTarget else {
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
        let preview = try metadataService.applyWorkflowNotesSummary(
            path: plannedFile.workingPath,
            displayName: file.name,
            fileExtension: file.fileExtension,
            targetNotesSummary: targetNotesSummary,
            timestamp: Date()
        )

        let descriptor = preview?.willChange == true
            ? WorkflowCompensationPayloadDescriptor.notesSummaryRestore(
                path: plannedFile.workingPath,
                previousNotesSummary: preview?.previousNotesSummary
            )
            : nil
        let metadataDelta = preview?.willChange == true
            ? WorkflowFileMetadataDelta(
                previousNotesSummary: preview?.previousNotesSummary,
                resultingNotesSummary: targetNotesSummary
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

        guard case .notesSummaryRestore(let path, let previousNotesSummary) = descriptor else {
            return nil
        }

        return WorkflowCompensationAction(
            stepKind: .notesSummary,
            fileIdentity: fileIdentity,
            sourcePath: path,
            destinationPath: path,
            metadataDelta: nil
        ) {
            let metadataService = FileMetadataFoundationService(
                modelContext: ModelContext(modelContext.container)
            )
            _ = try metadataService.restoreWorkflowNotesSummary(
                canonicalIdentity: fileIdentity,
                path: path,
                previousNotesSummary: previousNotesSummary,
                timestamp: Date()
            )
        }
    }
}
