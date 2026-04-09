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
    private struct AdmissionCandidate {
        let canonicalIdentity: String?
        let projectAssociation: String?
        let sourceFolderHint: String?
    }

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
        case bookkeepingFailedAfterWorkflowRun(
            status: ProjectSpaceAutomationRunStatus,
            underlyingError: Error
        )

        var errorDescription: String? {
            switch self {
            case .noRunnableFiles:
                return "No runnable files were available for this project-space automation policy."
            case let .bookkeepingFailedAfterWorkflowRun(status, underlyingError):
                return "Project-space automation bookkeeping failed after the workflow completed with status \(status.rawValue): \(underlyingError.localizedDescription)"
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

    func eligibleFilesForExecution(
        _ policy: ProjectSpaceAutomationPolicy,
        detail: ProjectSpaceDetail,
        files: [FileItem],
        now: Date
    ) throws -> [FileItem] {
        try eligibleFiles(
            for: policy,
            detail: detail,
            files: files,
            timestamp: now
        )
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

        let scopeID = UUID()
        let executionRequest: WorkflowExecutionRequest
        if let invocationContext {
            executionRequest = WorkflowExecutionRequest(
                templateID: policy.workflowTemplateID,
                scopeID: scopeID,
                invocationContext: invocationContext
            )
        } else {
            executionRequest = automationService.workflowExecutionRequest(
                for: policy,
                projectLabel: detail.projectLabel,
                triggerKind: triggerKind,
                scopeID: scopeID
            )
        }

        let plan = workflowExecution.plan(executionRequest, eligibleFiles)
        let partition = partitionWorkflowPlan(plan, files: eligibleFiles)
        guard !partition.runnableFiles.isEmpty else {
            throw CoordinatorError.noRunnableFiles
        }
        let workflowRun: WorkflowRunRecord

        do {
            workflowRun = try await workflowExecution.run(
                executionRequest,
                partition.runnablePlan,
                partition.runnableFiles,
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

        let runStatus = automationRunStatus(for: workflowRun.primaryStatus)
        let automationRun: ProjectSpaceAutomationRunRecord
        do {
            automationRun = try recordRun(
                policy.id,
                policy.workflowTemplateID,
                triggerKind,
                workflowRun.id,
                runStatus,
                workflowRun.startedAt,
                workflowRun.endedAt ?? now,
                now
            )
        } catch {
            throw CoordinatorError.bookkeepingFailedAfterWorkflowRun(
                status: runStatus,
                underlyingError: error
            )
        }

        try? persistLatestRun(workflowRun, detail.projectLabel, now)

        return automationRun
    }

    private func automationRunStatus(for primaryStatus: WorkflowRunPrimaryStatus) -> ProjectSpaceAutomationRunStatus {
        switch primaryStatus {
        case .queued:
            return .queued
        case .running:
            return .running
        case .succeeded:
            return .succeeded
        case .completedWithIssues:
            return .completedWithIssues
        case .failed:
            return .failed
        case .canceled:
            return .failed
        }
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

        let metadataService = FileMetadataFoundationService(modelContext: modelContext)
        var eligibleFiles: [FileItem] = []

        for file in files {
            let candidate = admissionCandidate(
                for: file,
                detail: detail,
                metadataService: metadataService,
                now: timestamp
            )

            switch candidate.decision {
            case .existingMember:
                eligibleFiles.append(file)
            case .strongConfirmed:
                guard let canonicalIdentity = candidate.value.canonicalIdentity else {
                    continue
                }
                try metadataAdmissionWriter.admitToProjectSpace(
                    canonicalIdentity: canonicalIdentity,
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

    private func admissionCandidate(
        for file: FileItem,
        detail: ProjectSpaceDetail,
        metadataService: FileMetadataFoundationService,
        now: Date
    ) -> (value: AdmissionCandidate, decision: ProjectSpaceAdmissionDecision) {
        let snapshot = metadataService.projectSpaceAdmissionFileSnapshot(for: file.path)
        let matchingRows = detail.files.filter { row in
            URL(fileURLWithPath: row.normalizedPath).standardizedFileURL.path == snapshot.normalizedPath
        }
        let preferredRow = preferredAdmissionRow(from: matchingRows, detail: detail, now: now)
        let candidate = AdmissionCandidate(
            canonicalIdentity: preferredRow?.canonicalIdentity ?? snapshot.canonicalIdentity,
            projectAssociation: preferredRow?.projectAssociation ?? snapshot.projectAssociation,
            sourceFolderHint: preferredRow?.sourceFolderHint ?? snapshot.sourceFolderHint
        )

        return (
            candidate,
            admissionDecision(for: candidate, detail: detail, now: now)
        )
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
        switch admissionDecision(
            for: AdmissionCandidate(
                canonicalIdentity: fileRow.canonicalIdentity,
                projectAssociation: fileRow.projectAssociation,
                sourceFolderHint: fileRow.sourceFolderHint
            ),
            detail: detail,
            now: now
        ) {
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
        for candidate: AdmissionCandidate,
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
            existingProjectAssociation: candidate.projectAssociation,
            dominantDestinationProjectLabel: dominantDestinationProjectLabel,
            dominantDestinationIsGenericHint: false,
            sourceFolderProjectLabel: normalized(candidate.sourceFolderHint) == normalized(detail.projectLabel)
                ? detail.projectLabel
                : nil,
            relatedFileProjectLabel: relatedFileProjectLabel(
                for: candidate.sourceFolderHint,
                in: detail
            )
        )

        return admissionResolver.resolveAdmission(
            projectLabel: detail.projectLabel,
            evidence: evidence
        )
    }

    private func relatedFileProjectLabel(
        for sourceFolderHint: String?,
        in detail: ProjectSpaceDetail
    ) -> String? {
        guard let sourceFolderHint = normalized(sourceFolderHint) else {
            return nil
        }

        return detail.files.first(where: { row in
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
