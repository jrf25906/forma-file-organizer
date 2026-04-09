import Foundation
import SwiftData

@MainActor
protocol ProjectSpaceAutomationAdmissionWriting {
    func admitToProjectSpace(
        canonicalIdentity: String,
        projectLabel: String,
        detailsSummary: String,
        timestamp: Date
    ) throws
}

extension FileMetadataFoundationService: ProjectSpaceAutomationAdmissionWriting {}

@MainActor
struct ProjectSpaceAutomationCoordinator {
    enum CoordinatorError: LocalizedError {
        case noRunnableFiles

        var errorDescription: String? {
            switch self {
            case .noRunnableFiles:
                return "No runnable files were available for this project-space automation policy."
            }
        }
    }

    private let modelContext: ModelContext
    private let metadataAdmissionWriter: any ProjectSpaceAutomationAdmissionWriting
    private let automationService: ProjectSpaceAutomationService
    private let workflowExecution: WorkflowExecutionClient
    private let admissionResolver: ProjectSpaceAdmissionResolver

    init(
        modelContext: ModelContext,
        metadataAdmissionWriter: any ProjectSpaceAutomationAdmissionWriting,
        automationService: ProjectSpaceAutomationService? = nil,
        workflowExecution: WorkflowExecutionClient = .live,
        admissionResolver: ProjectSpaceAdmissionResolver = ProjectSpaceAdmissionResolver()
    ) {
        self.modelContext = modelContext
        self.metadataAdmissionWriter = metadataAdmissionWriter
        self.automationService = automationService ?? ProjectSpaceAutomationService(modelContext: modelContext)
        self.workflowExecution = workflowExecution
        self.admissionResolver = admissionResolver
    }

    func executePolicy(
        _ policy: ProjectSpaceAutomationPolicy,
        detail: ProjectSpaceDetail,
        files: [FileItem],
        triggerKind: ProjectSpaceAutomationTriggerKind,
        now: Date
    ) async throws -> ProjectSpaceAutomationRunRecord {
        try performAdmissionWritesIfNeeded(
            for: policy,
            detail: detail,
            files: files,
            timestamp: now
        )

        let invocationContext = WorkflowInvocationContext.projectSpace(projectLabel: detail.projectLabel)
        let plan = workflowExecution.plan(policy.workflowTemplateID, files, invocationContext)
        let partition = partitionWorkflowPlan(plan, files: files)
        guard !partition.runnableFiles.isEmpty else {
            throw CoordinatorError.noRunnableFiles
        }

        let scopeID = UUID()

        do {
            let workflowRun = try await workflowExecution.run(
                partition.runnablePlan,
                partition.runnableFiles,
                scopeID,
                modelContext
            )
            try persistLatestRunBestEffort(workflowRun, projectLabel: detail.projectLabel, at: now)

            return try automationService.recordRun(
                policyID: policy.id,
                workflowTemplateID: policy.workflowTemplateID,
                triggerKind: triggerKind,
                workflowRunID: workflowRun.id,
                status: workflowRun.primaryStatus == .succeeded ? .succeeded : .failed,
                startedAt: workflowRun.startedAt,
                endedAt: workflowRun.endedAt ?? now,
                createdAt: now
            )
        } catch {
            if let failedRun = try? WorkflowAuditStore(modelContext: modelContext)
                .latestRunSummary(scopeID: scopeID, workflowTemplateID: policy.workflowTemplateID) {
                try? persistLatestRunBestEffort(failedRun, projectLabel: detail.projectLabel, at: now)
                _ = try? automationService.recordRun(
                    policyID: policy.id,
                    workflowTemplateID: policy.workflowTemplateID,
                    triggerKind: triggerKind,
                    workflowRunID: failedRun.id,
                    status: .failed,
                    startedAt: failedRun.startedAt,
                    endedAt: failedRun.endedAt ?? now,
                    createdAt: now
                )
            }
            throw error
        }
    }

    private func performAdmissionWritesIfNeeded(
        for policy: ProjectSpaceAutomationPolicy,
        detail: ProjectSpaceDetail,
        files: [FileItem],
        timestamp: Date
    ) throws {
        guard policy.admissionMode == .automatic else {
            return
        }

        let rowsByPath = Dictionary(
            uniqueKeysWithValues: detail.files.map {
                (URL(fileURLWithPath: $0.normalizedPath).standardizedFileURL.path, $0)
            }
        )

        for file in files {
            let standardizedPath = URL(fileURLWithPath: file.path).standardizedFileURL.path
            guard let fileRow = rowsByPath[standardizedPath] else {
                continue
            }

            let decision = admissionDecision(for: fileRow, detail: detail)
            guard case .strongConfirmed = decision else {
                continue
            }

            try metadataAdmissionWriter.admitToProjectSpace(
                canonicalIdentity: fileRow.canonicalIdentity,
                projectLabel: detail.projectLabel,
                detailsSummary: "Admitted to project space \(detail.projectLabel) before policy execution.",
                timestamp: timestamp
            )
        }
    }

    private func admissionDecision(
        for fileRow: ProjectSpaceFileRow,
        detail: ProjectSpaceDetail
    ) -> ProjectSpaceAdmissionDecision {
        let dominantDestinationProjectLabel: String? = {
            guard let first = detail.preferredDestinations.first,
                  dominantDestinationIsStrong(for: detail),
                  normalized(first.destinationDisplayName) == normalized(detail.projectLabel) else {
                return nil
            }

            return detail.projectLabel
        }()

        let evidence = ProjectSpaceAdmissionEvidence(
            existingProjectAssociation: fileRow.projectAssociation,
            dominantDestinationProjectLabel: dominantDestinationProjectLabel,
            dominantDestinationIsGenericHint: false,
            sourceFolderProjectLabel: normalized(fileRow.sourceFolderHint) == normalized(detail.projectLabel)
                ? detail.projectLabel
                : nil,
            relatedFileProjectLabel: relatedFileProjectLabel(for: fileRow, in: detail)
        )

        return admissionResolver.resolveAdmission(
            projectLabel: detail.projectLabel,
            evidence: evidence
        )
    }

    private func relatedFileProjectLabel(
        for fileRow: ProjectSpaceFileRow,
        in detail: ProjectSpaceDetail
    ) -> String? {
        guard let sourceFolderHint = normalized(fileRow.sourceFolderHint) else {
            return nil
        }

        return detail.files.first(where: { row in
            row.canonicalIdentity != fileRow.canonicalIdentity &&
            normalized(row.sourceFolderHint) == sourceFolderHint &&
            normalized(row.projectAssociation) == normalized(detail.projectLabel)
        }).flatMap { _ in detail.projectLabel }
    }

    private func dominantDestinationIsStrong(for detail: ProjectSpaceDetail) -> Bool {
        guard let first = detail.preferredDestinations.first else {
            return false
        }

        let totalEvents = detail.preferredDestinations.reduce(0) { $0 + $1.eventCount }
        guard first.eventCount >= 2,
              totalEvents > 0 else {
            return false
        }

        return Double(first.eventCount) / Double(totalEvents) >= 0.60
    }

    private func partitionWorkflowPlan(
        _ plan: WorkflowPlan,
        files: [FileItem]
    ) -> (runnablePlan: WorkflowPlan, runnableFiles: [FileItem]) {
        let runnablePaths = Set(plan.files.filter { !$0.isBlocked }.map(\.sourcePath))
        let runnableFiles = files.filter { file in
            runnablePaths.contains(URL(fileURLWithPath: file.path).standardizedFileURL.path)
        }
        let runnablePlan = WorkflowPlan(
            definition: plan.definition,
            files: plan.files.filter { runnablePaths.contains($0.sourcePath) },
            simulation: WorkflowSimulationReport(
                files: plan.simulation.files.filter { runnablePaths.contains($0.sourcePath) }
            )
        )

        return (runnablePlan, runnableFiles)
    }

    private func persistLatestRunBestEffort(
        _ run: WorkflowRunRecord,
        projectLabel: String,
        at timestamp: Date
    ) throws {
        guard run.primaryStatus != .queued,
              run.primaryStatus != .running else {
            return
        }

        try ProjectSpaceWorkflowProfileService(modelContext: modelContext)
            .recordLatestRun(run, for: projectLabel, at: timestamp)
    }

    private func normalized(_ value: String?) -> String? {
        FileMetadataRecord.normalizedOptionalText(value)
    }
}
