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
    typealias PersistLatestRun = @MainActor @Sendable (WorkflowRunRecord, String, Date) throws -> Void
    typealias RecordRun = @MainActor @Sendable (
        UUID,
        String,
        ProjectSpaceAutomationTriggerKind,
        UUID?,
        ProjectSpaceAutomationRunStatus,
        Date,
        Date?,
        Date
    ) throws -> ProjectSpaceAutomationRunRecord

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
    private let recommendationService: ProjectSpaceAutomationRecommendationService
    private let persistLatestRun: PersistLatestRun
    private let recordRun: RecordRun

    init(
        modelContext: ModelContext,
        metadataAdmissionWriter: any ProjectSpaceAutomationAdmissionWriting,
        automationService: ProjectSpaceAutomationService? = nil,
        workflowExecution: WorkflowExecutionClient = .live,
        admissionResolver: ProjectSpaceAdmissionResolver = ProjectSpaceAdmissionResolver(),
        recommendationService: ProjectSpaceAutomationRecommendationService = ProjectSpaceAutomationRecommendationService(),
        persistLatestRun: PersistLatestRun? = nil,
        recordRun: RecordRun? = nil
    ) {
        let resolvedAutomationService = automationService ?? ProjectSpaceAutomationService(modelContext: modelContext)

        self.modelContext = modelContext
        self.metadataAdmissionWriter = metadataAdmissionWriter
        self.automationService = resolvedAutomationService
        self.workflowExecution = workflowExecution
        self.admissionResolver = admissionResolver
        self.recommendationService = recommendationService
        self.persistLatestRun = persistLatestRun ?? { run, projectLabel, timestamp in
            guard run.primaryStatus != .queued,
                  run.primaryStatus != .running else {
                return
            }

            try ProjectSpaceWorkflowProfileService(modelContext: modelContext)
                .recordLatestRun(run, for: projectLabel, at: timestamp)
        }
        self.recordRun = recordRun ?? { policyID, workflowTemplateID, triggerKind, workflowRunID, status, startedAt, endedAt, createdAt in
            try resolvedAutomationService.recordRun(
                policyID: policyID,
                workflowTemplateID: workflowTemplateID,
                triggerKind: triggerKind,
                workflowRunID: workflowRunID,
                status: status,
                startedAt: startedAt,
                endedAt: endedAt,
                createdAt: createdAt
            )
        }
    }

    func executePolicy(
        _ policy: ProjectSpaceAutomationPolicy,
        detail: ProjectSpaceDetail,
        files: [FileItem],
        triggerKind: ProjectSpaceAutomationTriggerKind,
        invocationContext: WorkflowInvocationContext? = nil,
        now: Date
    ) async throws -> ProjectSpaceAutomationRunRecord {
        let eligibleFiles = try eligibleFiles(
            for: policy,
            detail: detail,
            files: files,
            timestamp: now
        )
        guard !eligibleFiles.isEmpty else {
            throw CoordinatorError.noRunnableFiles
        }

        let resolvedInvocationContext = invocationContext ?? .projectSpace(projectLabel: detail.projectLabel)
        let plan = workflowExecution.plan(policy.workflowTemplateID, eligibleFiles, resolvedInvocationContext)
        let partition = partitionWorkflowPlan(plan, files: eligibleFiles)
        guard !partition.runnableFiles.isEmpty else {
            throw CoordinatorError.noRunnableFiles
        }

        let scopeID = UUID()
        let workflowRun: WorkflowRunRecord

        do {
            workflowRun = try await workflowExecution.run(
                partition.runnablePlan,
                partition.runnableFiles,
                scopeID,
                modelContext
            )
        } catch {
            if let failedRun = try? WorkflowAuditStore(modelContext: modelContext)
                .latestRunSummary(scopeID: scopeID, workflowTemplateID: policy.workflowTemplateID) {
                try? persistLatestRun(failedRun, detail.projectLabel, now)
                _ = try? recordRun(
                    policy.id,
                    policy.workflowTemplateID,
                    triggerKind,
                    failedRun.id,
                    .failed,
                    failedRun.startedAt,
                    failedRun.endedAt ?? now,
                    now
                )
            }
            throw error
        }

        let automationRun = try recordRun(
            policy.id,
            policy.workflowTemplateID,
            triggerKind,
            workflowRun.id,
            workflowRun.primaryStatus == .succeeded ? .succeeded : .failed,
            workflowRun.startedAt,
            workflowRun.endedAt ?? now,
            now
        )

        try? persistLatestRun(workflowRun, detail.projectLabel, now)

        return automationRun
    }

    private func eligibleFiles(
        for policy: ProjectSpaceAutomationPolicy,
        detail: ProjectSpaceDetail,
        files: [FileItem],
        timestamp: Date
    ) throws -> [FileItem] {
        guard policy.admissionMode == .automatic else {
            return files
        }

        let rowsByPath = detailRowsByStandardizedPath(detail.files)
        var eligibleFiles: [FileItem] = []

        for file in files {
            let standardizedPath = URL(fileURLWithPath: file.path).standardizedFileURL.path
            guard let fileRows = rowsByPath[standardizedPath],
                  let fileRow = preferredAdmissionRow(from: fileRows, detail: detail, now: timestamp) else {
                continue
            }

            switch admissionDecision(for: fileRow, detail: detail, now: timestamp) {
            case .existingMember:
                eligibleFiles.append(file)
            case .strongConfirmed:
                try metadataAdmissionWriter.admitToProjectSpace(
                    canonicalIdentity: fileRow.canonicalIdentity,
                    projectLabel: detail.projectLabel,
                    detailsSummary: "Admitted to project space \(detail.projectLabel) before policy execution.",
                    timestamp: timestamp
                )
                eligibleFiles.append(file)
            case .insufficient:
                continue
            }
        }

        return eligibleFiles
    }

    private func detailRowsByStandardizedPath(
        _ rows: [ProjectSpaceFileRow]
    ) -> [String: [ProjectSpaceFileRow]] {
        Dictionary(grouping: rows) { row in
            URL(fileURLWithPath: row.normalizedPath).standardizedFileURL.path
        }
    }

    private func preferredAdmissionRow(
        from rows: [ProjectSpaceFileRow],
        detail: ProjectSpaceDetail,
        now: Date
    ) -> ProjectSpaceFileRow? {
        rows.max { lhs, rhs in
            admissionPreference(
                for: lhs,
                detail: detail,
                now: now
            ) < admissionPreference(
                for: rhs,
                detail: detail,
                now: now
            )
        }
    }

    private func admissionPreference(
        for fileRow: ProjectSpaceFileRow,
        detail: ProjectSpaceDetail,
        now: Date
    ) -> (Int, Date, String) {
        let rank: Int
        switch admissionDecision(for: fileRow, detail: detail, now: now) {
        case .existingMember:
            rank = 2
        case .strongConfirmed:
            rank = 1
        case .insufficient:
            rank = 0
        }

        return (rank, fileRow.lastActivityAt, fileRow.canonicalIdentity)
    }

    private func admissionDecision(
        for fileRow: ProjectSpaceFileRow,
        detail: ProjectSpaceDetail,
        now: Date
    ) -> ProjectSpaceAdmissionDecision {
        let dominantDestinationProjectLabel: String? = {
            guard let first = recommendationService.dominantDestination(for: detail, now: now),
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

    private func normalized(_ value: String?) -> String? {
        FileMetadataRecord.normalizedOptionalText(value)
    }
}
