import Foundation
import SwiftData

@MainActor
struct WorkflowEntryPointOrganizer {
    struct Outcome {
        let runRecord: WorkflowRunRecord?
        let runnableFiles: [FileItem]
        let blockedFiles: [FileItem]
    }

    private let workflowExecution: WorkflowExecutionClient

    init(workflowExecution: WorkflowExecutionClient = .live) {
        self.workflowExecution = workflowExecution
    }

    func execute(
        files: [FileItem],
        template: BuiltInWorkflowTemplate,
        invocationContext: WorkflowInvocationContext,
        modelContext: ModelContext,
        scopeID: UUID? = nil
    ) async throws -> Outcome {
        let request = WorkflowExecutionRequest(
            templateID: template.id,
            invocationContext: invocationContext
        )
        let plan = workflowExecution.plan(request, files)
        let partition = partitionWorkflowPlan(plan, files: files)

        guard !partition.runnableFiles.isEmpty else {
            return Outcome(
                runRecord: nil,
                runnableFiles: [],
                blockedFiles: partition.blockedFiles
            )
        }

        let executionRequest = request.replacingScopeID(scopeID ?? request.scopeID)
        let runRecord = try await workflowExecution.run(
            executionRequest,
            partition.runnablePlan,
            partition.runnableFiles,
            modelContext
        )

        for file in partition.runnableFiles {
            file.status = .completed
        }

        return Outcome(
            runRecord: runRecord,
            runnableFiles: partition.runnableFiles,
            blockedFiles: partition.blockedFiles
        )
    }

    private func partitionWorkflowPlan(
        _ plan: WorkflowPlan,
        files: [FileItem]
    ) -> BulkOperationViewModel.WorkflowExecutionPartition {
        let runnablePaths = Set(plan.files.filter { !$0.isBlocked }.map(\.sourcePath))
        let blockedPaths = Set(plan.files.filter(\.isBlocked).map(\.sourcePath))
        let runnableFiles = files.filter { runnablePaths.contains(standardizedPath(for: $0)) }
        let blockedFiles = files.filter { blockedPaths.contains(standardizedPath(for: $0)) }
        let runnablePlan = WorkflowPlan(
            definition: plan.definition,
            files: plan.files.filter { runnablePaths.contains($0.sourcePath) },
            simulation: WorkflowSimulationReport(
                files: plan.simulation.files.filter { runnablePaths.contains($0.sourcePath) }
            )
        )

        return BulkOperationViewModel.WorkflowExecutionPartition(
            runnablePlan: runnablePlan,
            runnableFiles: runnableFiles,
            blockedFiles: blockedFiles
        )
    }

    private func standardizedPath(for file: FileItem) -> String {
        URL(fileURLWithPath: file.path).standardizedFileURL.path
    }
}
