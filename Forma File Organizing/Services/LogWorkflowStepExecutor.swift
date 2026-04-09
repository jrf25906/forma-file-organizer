import Foundation
import SwiftData

struct WorkflowRunSideEffectExecutionContext {
    let run: WorkflowRunRecord
    let plan: WorkflowPlan
    let files: [FileItem]
    let modelContext: ModelContext

    var affectedFileCount: Int {
        files.count
    }
}

struct WorkflowRunSideEffectExecutionResult {
    let stepStatus: WorkflowStepStatus
    let disposition: WorkflowFileDisposition
}

@MainActor
protocol WorkflowRunSideEffectExecutor {
    var stepKind: WorkflowStepKind { get }

    func execute(
        context: WorkflowRunSideEffectExecutionContext
    ) async throws -> WorkflowRunSideEffectExecutionResult
}

@MainActor
struct LogWorkflowStepExecutor: WorkflowRunSideEffectExecutor {
    typealias RecordSummary = @MainActor (
        _ run: WorkflowRunRecord,
        _ triggerSurface: ActivityItem.WorkflowTriggerSurface,
        _ affectedFileCount: Int,
        _ modelContext: ModelContext
    ) throws -> Void

    let stepKind: WorkflowStepKind = .log

    private let recordSummary: RecordSummary

    init(
        recordSummary: @escaping RecordSummary = Self.defaultRecordSummary
    ) {
        self.recordSummary = recordSummary
    }

    func execute(
        context: WorkflowRunSideEffectExecutionContext
    ) async throws -> WorkflowRunSideEffectExecutionResult {
        try recordSummary(
            context.run,
            context.plan.definition.invocationContext.triggerSurface,
            context.affectedFileCount,
            context.modelContext
        )
        return WorkflowRunSideEffectExecutionResult(
            stepStatus: .succeeded,
            disposition: .logged
        )
    }

    private static func defaultRecordSummary(
        run: WorkflowRunRecord,
        triggerSurface: ActivityItem.WorkflowTriggerSurface,
        affectedFileCount: Int,
        modelContext: ModelContext
    ) throws {
        ActivityLoggingService(modelContext: modelContext).logWorkflowRunSummary(
            run: run,
            triggerSurface: triggerSurface,
            affectedFileCount: affectedFileCount
        )
    }
}
