import Foundation
import SwiftData

@MainActor
struct WorkflowExecutionClient {
    var plan: (_ templateID: String, _ files: [FileItem]) -> WorkflowPlan
    var run: (
        _ plan: WorkflowPlan,
        _ files: [FileItem],
        _ scopeID: UUID,
        _ modelContext: ModelContext
    ) async throws -> Void
}

extension WorkflowExecutionClient {
    static let live = WorkflowExecutionClient(
        plan: { templateID, files in
            WorkflowPlanner().plan(templateID: templateID, files: files)
        },
        run: { plan, files, scopeID, modelContext in
            let runner = WorkflowRunner(
                auditStore: WorkflowAuditStore(modelContext: modelContext)
            )
            _ = try await runner.run(
                plan: plan,
                files: files,
                scopeID: scopeID,
                modelContext: modelContext
            )
        }
    )
}
