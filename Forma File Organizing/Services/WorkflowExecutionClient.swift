import Foundation
import SwiftData

@MainActor
struct WorkflowExecutionClient {
    var plan: (
        _ templateID: String,
        _ files: [FileItem],
        _ invocationContext: WorkflowInvocationContext
    ) -> WorkflowPlan
    var run: (
        _ plan: WorkflowPlan,
        _ files: [FileItem],
        _ scopeID: UUID,
        _ modelContext: ModelContext
    ) async throws -> WorkflowRunRecord
}

extension WorkflowExecutionClient {
    static let live = WorkflowExecutionClient(
        plan: { templateID, files, invocationContext in
            WorkflowPlanner().plan(
                templateID: templateID,
                files: files,
                invocationContext: invocationContext
            )
        },
        run: { plan, files, scopeID, modelContext in
            let runner = WorkflowRunner(
                auditStore: WorkflowAuditStore(modelContext: modelContext)
            )
            return try await runner.run(
                plan: plan,
                files: files,
                scopeID: scopeID,
                modelContext: modelContext
            )
        }
    )
}
