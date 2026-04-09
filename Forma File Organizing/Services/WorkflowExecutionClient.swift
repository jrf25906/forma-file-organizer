import Foundation
import SwiftData

@MainActor
struct WorkflowExecutionClient {
    private let planRequestImpl: (
        _ request: WorkflowExecutionRequest,
        _ files: [FileItem]
    ) -> WorkflowPlan
    private let runRequestImpl: (
        _ request: WorkflowExecutionRequest,
        _ plan: WorkflowPlan,
        _ files: [FileItem],
        _ modelContext: ModelContext
    ) async throws -> WorkflowRunRecord

    init(
        plan: @escaping (
            _ templateID: String,
            _ files: [FileItem],
            _ invocationContext: WorkflowInvocationContext
        ) -> WorkflowPlan,
        run: @escaping (
            _ plan: WorkflowPlan,
            _ files: [FileItem],
            _ scopeID: UUID,
            _ modelContext: ModelContext
        ) async throws -> WorkflowRunRecord
    ) {
        self.planRequestImpl = { request, files in
            plan(request.templateID, files, request.invocationContext)
        }
        self.runRequestImpl = { request, plan, files, modelContext in
            try await run(plan, files, request.scopeID, modelContext)
        }
    }

    init(
        planRequest: @escaping (
            _ request: WorkflowExecutionRequest,
            _ files: [FileItem]
        ) -> WorkflowPlan,
        runRequest: @escaping (
            _ request: WorkflowExecutionRequest,
            _ plan: WorkflowPlan,
            _ files: [FileItem],
            _ modelContext: ModelContext
        ) async throws -> WorkflowRunRecord
    ) {
        self.planRequestImpl = planRequest
        self.runRequestImpl = runRequest
    }

    func plan(
        _ templateID: String,
        _ files: [FileItem],
        _ invocationContext: WorkflowInvocationContext
    ) -> WorkflowPlan {
        plan(
            WorkflowExecutionRequest(
                templateID: templateID,
                invocationContext: invocationContext
            ),
            files
        )
    }

    func plan(
        _ request: WorkflowExecutionRequest,
        _ files: [FileItem]
    ) -> WorkflowPlan {
        planRequestImpl(request, files)
    }

    func run(
        _ plan: WorkflowPlan,
        _ files: [FileItem],
        _ scopeID: UUID,
        _ modelContext: ModelContext
    ) async throws -> WorkflowRunRecord {
        try await run(
            WorkflowExecutionRequest(
                templateID: plan.definition.templateID,
                scopeID: scopeID,
                invocationContext: plan.definition.invocationContext
            ),
            plan,
            files,
            modelContext
        )
    }

    func run(
        _ request: WorkflowExecutionRequest,
        _ plan: WorkflowPlan,
        _ files: [FileItem],
        _ modelContext: ModelContext
    ) async throws -> WorkflowRunRecord {
        try await runRequestImpl(request, plan, files, modelContext)
    }
}

extension WorkflowExecutionClient {
    static let live = WorkflowExecutionClient(
        planRequest: { request, files in
            WorkflowPlanner().plan(
                templateID: request.templateID,
                files: files,
                invocationContext: request.invocationContext
            )
        },
        runRequest: { request, plan, files, modelContext in
            let runner = WorkflowRunner(
                auditStore: WorkflowAuditStore(modelContext: modelContext)
            )
            return try await runner.run(
                request: request,
                plan: plan,
                files: files,
                modelContext: modelContext
            )
        }
    )
}
