import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class WorkflowRunnerTests: XCTestCase {
    private struct InjectedMoveFailure: Error {}
    private struct InjectedAuditFailure: Error {}
    private struct InjectedRunStatusFailure: Error {}
    private struct InjectedRollbackStatusFailure: Error {}
    private struct InjectedLogFailure: Error {}
    private struct InjectedNotifyFailure: Error {}

    private struct StubRunSideEffectExecutor: WorkflowRunSideEffectExecutor {
        let stepKind: WorkflowStepKind
        let onExecute: @MainActor (
            WorkflowRunSideEffectExecutionContext
        ) async throws -> WorkflowRunSideEffectExecutionResult

        func execute(
            context: WorkflowRunSideEffectExecutionContext
        ) async throws -> WorkflowRunSideEffectExecutionResult {
            try await onExecute(context)
        }
    }

    private struct FailingMoveExecutor: WorkflowStepExecutor {
        let baseExecutor: MoveWorkflowStepExecutor
        let failingSourcePath: String

        var stepKind: WorkflowStepKind { .move }

        func simulate(plannedFile: WorkflowPlannedFile) -> WorkflowSimulatedStep {
            baseExecutor.simulate(plannedFile: plannedFile)
        }

        func prepareExecution(
            file: FileItem,
            plannedFile: WorkflowPlannedFile,
            modelContext: ModelContext
        ) throws -> WorkflowPreparedStepExecution {
            try baseExecutor.prepareExecution(
                file: file,
                plannedFile: plannedFile,
                modelContext: modelContext
            )
        }

        func execute(
            file: FileItem,
            plannedFile: WorkflowPlannedFile,
            modelContext: ModelContext
        ) async throws -> WorkflowStepExecutionResult {
            if plannedFile.sourcePath == failingSourcePath {
                throw InjectedMoveFailure()
            }

            return try await baseExecutor.execute(
                file: file,
                plannedFile: plannedFile,
                modelContext: modelContext
            )
        }

        func makeCompensationAction(
            fileIdentity: String,
            compensationPayload: [String: String]?,
            file: FileItem,
            modelContext: ModelContext
        ) throws -> WorkflowCompensationAction? {
            try baseExecutor.makeCompensationAction(
                fileIdentity: fileIdentity,
                compensationPayload: compensationPayload,
                file: file,
                modelContext: modelContext
            )
        }
    }

    private func makeEnvironment() throws -> (
        container: ModelContainer,
        context: ModelContext,
        coordinator: FileOrganizationCoordinator,
        auditStore: WorkflowAuditStore
    ) {
        let schema = Schema([
            ActivityItem.self,
            FileItem.self,
            FileMetadataRecord.self,
            FileOrganizationHistoryEntry.self,
            ProjectSpaceWorkflowProfile.self,
            TrustedAutomationScopeRunRecord.self,
            WorkflowRunRecord.self,
            WorkflowStepRunRecord.self,
            WorkflowFileActionRecord.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.autoContentTags, true)

        return (
            container: container,
            context: context,
            coordinator: FileOrganizationCoordinator(),
            auditStore: WorkflowAuditStore(modelContext: context)
        )
    }

    override func tearDown() {
        FeatureFlagService.shared.resetToDefaults()
        super.tearDown()
    }

    func testRunner_ReviewInvocation_LogsWorkflowSummaryWithoutNotify() async throws {
        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        let destinationFolder = try tempDirectory.createDirectory(name: "Receipts")
        let sourceURL = try tempDirectory.createFile(name: "Inbox/July Receipt.pdf", contents: "receipt")
        let destination = try Destination.folder(from: destinationFolder, displayName: "Receipts")
        let creationDate = Date(timeIntervalSince1970: 1_712_620_800)

        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 100,
            creationDate: creationDate,
            modificationDate: creationDate,
            lastAccessedDate: creationDate,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .pending
        )
        environment.context.insert(file)
        try environment.context.save()

        let plan = WorkflowPlanner().plan(
            templateID: BuiltInWorkflowTemplate.StableID.receipts,
            files: [file],
            invocationContext: .dashboardReview
        )
        XCTAssertFalse(plan.hasBlockers)

        var notifyExecutionCount = 0
        let notifyExecutor = StubRunSideEffectExecutor(stepKind: .notify) { _ in
            notifyExecutionCount += 1
            return WorkflowRunSideEffectExecutionResult(
                stepStatus: .succeeded,
                disposition: .notified
            )
        }

        let runner = WorkflowRunner(
            auditStore: environment.auditStore,
            rollbackCoordinator: WorkflowRollbackCoordinator(),
            executorsByKind: [
                .rename: RenameWorkflowStepExecutor(),
                .tag: TagWorkflowStepExecutor(),
                .workflowStatus: WorkflowStatusWorkflowStepExecutor(),
                .move: MoveWorkflowStepExecutor(fileOrganizationCoordinator: environment.coordinator)
            ],
            sideEffectExecutorsByKind: [
                .log: LogWorkflowStepExecutor(),
                .notify: notifyExecutor
            ]
        )

        _ = try await runner.run(
            plan: plan,
            files: [file],
            scopeID: UUID(),
            modelContext: environment.context
        )

        XCTAssertEqual(notifyExecutionCount, 0)

        let activity = try XCTUnwrap(
            environment.context.fetch(FetchDescriptor<ActivityItem>()).last
        )
        XCTAssertEqual(activity.activityType, .workflowRunCompleted)
        XCTAssertTrue(activity.details.contains("Review"))

        let stepRuns = try environment.auditStore.stepRuns(
            runID: try XCTUnwrap(environment.context.fetch(FetchDescriptor<WorkflowRunRecord>()).first).id
        )
        XCTAssertTrue(stepRuns.contains(where: { $0.stepID == "finalize|log" && $0.status == .succeeded }))
        XCTAssertFalse(stepRuns.contains(where: { $0.stepID == "finalize|notify" }))
    }

    func testRunner_TrustedScopeNotifyFailure_MarksCompletedWithIssuesWithoutRollback() async throws {
        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Drop")
        let destinationFolder = try tempDirectory.createDirectory(name: "Projects")
        let sourceURL = try tempDirectory.createFile(name: "Drop/Product Spec.pdf", contents: "project")
        let destination = try Destination.folder(from: destinationFolder, displayName: "Projects")
        let creationDate = Date(timeIntervalSince1970: 1_712_620_800)

        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 100,
            creationDate: creationDate,
            modificationDate: creationDate,
            lastAccessedDate: creationDate,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .pending
        )
        environment.context.insert(file)
        try environment.context.save()

        let plan = WorkflowPlanner().plan(
            templateID: BuiltInWorkflowTemplate.StableID.projectDrop,
            files: [file],
            invocationContext: .trustedScopeScheduled(scopeDisplayName: "Design Assets")
        )
        XCTAssertFalse(plan.hasBlockers)
        XCTAssertEqual(plan.definition.stepKinds, [.rename, .tag, .workflowStatus, .move, .log, .notify])

        let notifyExecutor = StubRunSideEffectExecutor(stepKind: .notify) { _ in
            throw InjectedNotifyFailure()
        }

        let runner = WorkflowRunner(
            auditStore: environment.auditStore,
            rollbackCoordinator: WorkflowRollbackCoordinator(),
            executorsByKind: [
                .rename: RenameWorkflowStepExecutor(),
                .tag: TagWorkflowStepExecutor(),
                .workflowStatus: WorkflowStatusWorkflowStepExecutor(),
                .move: MoveWorkflowStepExecutor(fileOrganizationCoordinator: environment.coordinator)
            ],
            sideEffectExecutorsByKind: [
                .log: LogWorkflowStepExecutor(),
                .notify: notifyExecutor
            ]
        )

        _ = try await runner.run(
            plan: plan,
            files: [file],
            scopeID: UUID(),
            modelContext: environment.context
        )

        let run = try XCTUnwrap(environment.context.fetch(FetchDescriptor<WorkflowRunRecord>()).first)
        XCTAssertEqual(run.primaryStatus, .completedWithIssues)
        XCTAssertEqual(run.rollbackStatus, .notRequested)
        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertEqual(file.status, .completed)

        let stepRuns = try environment.auditStore.stepRuns(runID: run.id)
        XCTAssertTrue(stepRuns.contains(where: { $0.stepID == "finalize|notify" && $0.status == .failed }))

        let fileActions = try environment.auditStore.fileActions(runID: run.id)
        XCTAssertTrue(fileActions.contains(where: { $0.disposition == .notified || $0.disposition == .logged }))
        XCTAssertFalse(fileActions.contains(where: { $0.disposition == .restored }))
    }

    func testRunner_ProjectSpaceInvocation_ExecutesMetadataStepsThroughDefaultRunner() async throws {
        let environment = try makeEnvironment()
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)
        FeatureFlagService.shared.setEnabled(.durableWorkflowStatus, true)
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Drop")
        let destinationFolder = try tempDirectory.createDirectory(name: "Projects")
        let sourceURL = try tempDirectory.createFile(name: "Drop/Product Spec.pdf", contents: "project")
        let destination = try Destination.folder(from: destinationFolder, displayName: "Projects")
        let creationDate = Date(timeIntervalSince1970: 1_712_620_800)

        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 100,
            creationDate: creationDate,
            modificationDate: creationDate,
            lastAccessedDate: creationDate,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .pending
        )
        environment.context.insert(file)
        try environment.context.save()

        let plan = WorkflowPlanner().plan(
            templateID: BuiltInWorkflowTemplate.StableID.projectDrop,
            files: [file],
            invocationContext: .projectSpace(projectLabel: "Alpha")
        )
        XCTAssertFalse(plan.hasBlockers)
        XCTAssertEqual(plan.definition.stepKinds, [.rename, .tag, .projectAssociation, .workflowStatus, .notesSummary, .move, .log])

        let runner = WorkflowRunner(
            auditStore: environment.auditStore,
            rollbackCoordinator: WorkflowRollbackCoordinator()
        )

        _ = try await runner.run(
            plan: plan,
            files: [file],
            scopeID: UUID(),
            modelContext: environment.context
        )

        let record = try XCTUnwrap(
            environment.context.fetch(FetchDescriptor<FileMetadataRecord>()).first
        )
        XCTAssertEqual(record.projectAssociation, "Alpha")
        XCTAssertEqual(record.workflowStatus, .organized)
        XCTAssertEqual(record.notesSummary, "Project: Alpha")

        let run = try XCTUnwrap(environment.context.fetch(FetchDescriptor<WorkflowRunRecord>()).first)
        let stepRuns = try environment.auditStore.stepRuns(runID: run.id)
        XCTAssertTrue(stepRuns.contains(where: { $0.stepID.contains("projectAssociation") && $0.status == .succeeded }))
        XCTAssertTrue(stepRuns.contains(where: { $0.stepID.contains("workflowStatus") && $0.status == .succeeded }))
        XCTAssertTrue(stepRuns.contains(where: { $0.stepID.contains("notesSummary") && $0.status == .succeeded }))

        let fileActions = try environment.auditStore.fileActions(runID: run.id)
        XCTAssertTrue(fileActions.contains(where: { $0.metadataDelta?.resultingNotesSummary == "Project: Alpha" }))
    }

    func testRunner_ArchiveTemplate_PersistsArchivedWorkflowStatusAndAuditDelta() async throws {
        let environment = try makeEnvironment()
        FeatureFlagService.shared.setEnabled(.durableWorkflowStatus, true)
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        let destinationFolder = try tempDirectory.createDirectory(name: "Archive")
        let sourceURL = try tempDirectory.createFile(name: "Inbox/Quarterly Report.pdf", contents: "report")
        let destination = try Destination.folder(from: destinationFolder, displayName: "Archive")
        let creationDate = Date(timeIntervalSince1970: 1_712_620_800)

        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 100,
            creationDate: creationDate,
            modificationDate: creationDate,
            lastAccessedDate: creationDate,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .pending
        )
        environment.context.insert(file)
        try environment.context.save()

        let plan = WorkflowPlanner().plan(
            templateID: BuiltInWorkflowTemplate.StableID.datedArchive,
            files: [file],
            invocationContext: .dashboardReview
        )
        XCTAssertFalse(plan.hasBlockers)
        XCTAssertEqual(plan.definition.stepKinds, [.rename, .tag, .workflowStatus, .move, .log])

        let runner = WorkflowRunner(
            auditStore: environment.auditStore,
            rollbackCoordinator: WorkflowRollbackCoordinator()
        )

        _ = try await runner.run(
            plan: plan,
            files: [file],
            scopeID: UUID(),
            modelContext: environment.context
        )

        let record = try XCTUnwrap(
            environment.context.fetch(FetchDescriptor<FileMetadataRecord>()).first
        )
        XCTAssertEqual(record.workflowStatus, .archived)

        let run = try XCTUnwrap(environment.context.fetch(FetchDescriptor<WorkflowRunRecord>()).first)
        let stepRuns = try environment.auditStore.stepRuns(runID: run.id)
        XCTAssertTrue(stepRuns.contains(where: { $0.stepID.contains("workflowStatus") && $0.status == .succeeded }))

        let fileActions = try environment.auditStore.fileActions(runID: run.id)
        XCTAssertTrue(fileActions.contains(where: { $0.metadataDelta?.resultingWorkflowStatus == .archived }))
    }

    func testRunner_BlockedPlan_PersistsPreflightAuditRows() async throws {
        let environment = try makeEnvironment()
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)
        FeatureFlagService.shared.setEnabled(.durableWorkflowStatus, true)
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Drop")
        let destinationFolder = try tempDirectory.createDirectory(name: "Projects")
        let sourceURL = try tempDirectory.createFile(name: "Drop/Product Spec.pdf", contents: "project")
        let destination = try Destination.folder(from: destinationFolder, displayName: "Projects")
        let creationDate = Date(timeIntervalSince1970: 1_712_620_800)

        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 100,
            creationDate: creationDate,
            modificationDate: creationDate,
            lastAccessedDate: creationDate,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .pending
        )
        environment.context.insert(file)
        try environment.context.save()

        let plan = WorkflowPlanner().plan(
            templateID: BuiltInWorkflowTemplate.StableID.projectDrop,
            files: [file],
            invocationContext: .projectSpace(projectLabel: "")
        )
        XCTAssertTrue(plan.hasBlockers)

        let runner = WorkflowRunner(
            auditStore: environment.auditStore,
            rollbackCoordinator: WorkflowRollbackCoordinator()
        )

        do {
            _ = try await runner.run(
                plan: plan,
                files: [file],
                scopeID: UUID(),
                modelContext: environment.context
            )
            XCTFail("Runner should fail when the plan is blocked")
        } catch let error as WorkflowRunner.RunnerError {
            guard case .blockedPlan = error else {
                XCTFail("Unexpected runner error: \(error)")
                return
            }
        }

        let run = try XCTUnwrap(environment.context.fetch(FetchDescriptor<WorkflowRunRecord>()).first)
        XCTAssertEqual(run.primaryStatus, .failed)
        XCTAssertEqual(run.triggerSurface, .projectSpace)

        let stepRuns = try environment.auditStore.stepRuns(runID: run.id)
        XCTAssertTrue(stepRuns.contains(where: { $0.stepID == "execute|rename|\(sourceURL.path)" && $0.status == .planned }))
        XCTAssertTrue(stepRuns.contains(where: { $0.stepID == "execute|tag|\(sourceURL.path)" && $0.status == .planned }))
        XCTAssertTrue(stepRuns.contains(where: { $0.stepID == "execute|projectAssociation|\(sourceURL.path)" && $0.status == .blocked }))
        XCTAssertTrue(stepRuns.contains(where: { $0.stepID == "execute|workflowStatus|\(sourceURL.path)" && $0.status == .skipped }))
        XCTAssertTrue(stepRuns.contains(where: { $0.stepID == "execute|notesSummary|\(sourceURL.path)" && $0.status == .skipped }))
        XCTAssertTrue(stepRuns.contains(where: { $0.stepID == "execute|move|\(sourceURL.path)" && $0.status == .skipped }))
    }

    func testRunner_ProjectWorkflowCompletion_UpdatesWorkflowMemoryProfileOncePerRun() async throws {
        let environment = try makeEnvironment()
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)
        FeatureFlagService.shared.setEnabled(.durableWorkflowStatus, true)
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Drop")
        let destinationFolder = try tempDirectory.createDirectory(name: "Projects")
        let firstSourceURL = try tempDirectory.createFile(name: "Drop/Product Spec A.pdf", contents: "project-a")
        let secondSourceURL = try tempDirectory.createFile(name: "Drop/Product Spec B.pdf", contents: "project-b")
        let destination = try Destination.folder(from: destinationFolder, displayName: "Projects")
        let creationDate = Date(timeIntervalSince1970: 1_712_620_800)

        let firstFile = FileItem(
            path: firstSourceURL.path,
            sizeInBytes: 100,
            creationDate: creationDate,
            modificationDate: creationDate,
            lastAccessedDate: creationDate,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .pending
        )
        let secondFile = FileItem(
            path: secondSourceURL.path,
            sizeInBytes: 100,
            creationDate: creationDate,
            modificationDate: creationDate,
            lastAccessedDate: creationDate,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .pending
        )
        environment.context.insert(firstFile)
        environment.context.insert(secondFile)
        try environment.context.save()

        let request = WorkflowExecutionRequest(
            templateID: BuiltInWorkflowTemplate.StableID.projectDrop,
            scopeID: UUID(),
            entryPoint: .projectPolicy(
                policyID: UUID(),
                triggerKind: .manual,
                projectLabel: " Alpha ",
                policyName: "Project Drop Zone"
            )
        )
        let plan = WorkflowPlanner().plan(
            templateID: request.templateID,
            files: [firstFile, secondFile],
            invocationContext: request.invocationContext
        )
        XCTAssertFalse(plan.hasBlockers)

        let runner = WorkflowRunner(
            auditStore: environment.auditStore,
            rollbackCoordinator: WorkflowRollbackCoordinator()
        )

        let run = try await runner.run(
            request: request,
            plan: plan,
            files: [firstFile, secondFile],
            modelContext: environment.context
        )

        let profile = try XCTUnwrap(
            ProjectSpaceWorkflowProfileService(modelContext: environment.context)
                .profile(normalizedProjectLabel: "Alpha")
        )
        XCTAssertEqual(profile.lastWorkflowRunID, run.id)
        XCTAssertEqual(profile.successfulTemplateID, BuiltInWorkflowTemplate.StableID.projectDrop)
        XCTAssertEqual(profile.successfulTemplateCount, 1)
        XCTAssertEqual(profile.dominantTriggerSurface, .projectPolicyManual)
        XCTAssertEqual(profile.dominantTriggerSurfaceCount, 1)
        XCTAssertEqual(profile.workflowMemoryStatus, .stable)
    }

    func testRunner_BlockedWorkflow_DoesNotStrengthenWorkflowMemory() async throws {
        let environment = try makeEnvironment()
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)
        FeatureFlagService.shared.setEnabled(.durableWorkflowStatus, true)
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Drop")
        let destinationFolder = try tempDirectory.createDirectory(name: "Projects")
        let destination = try Destination.folder(from: destinationFolder, displayName: "Projects")
        let creationDate = Date(timeIntervalSince1970: 1_712_620_800)

        let successSourceURL = try tempDirectory.createFile(name: "Drop/Successful Spec.pdf", contents: "success")
        let successFile = FileItem(
            path: successSourceURL.path,
            sizeInBytes: 100,
            creationDate: creationDate,
            modificationDate: creationDate,
            lastAccessedDate: creationDate,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .pending
        )
        environment.context.insert(successFile)
        try environment.context.save()

        let successRequest = WorkflowExecutionRequest(
            templateID: BuiltInWorkflowTemplate.StableID.projectDrop,
            scopeID: UUID(),
            entryPoint: .projectPolicy(
                policyID: UUID(),
                triggerKind: .manual,
                projectLabel: "Alpha",
                policyName: "Project Drop Zone"
            )
        )
        let successPlan = WorkflowPlanner().plan(
            templateID: successRequest.templateID,
            files: [successFile],
            invocationContext: successRequest.invocationContext
        )
        XCTAssertFalse(successPlan.hasBlockers)

        let runner = WorkflowRunner(
            auditStore: environment.auditStore,
            rollbackCoordinator: WorkflowRollbackCoordinator()
        )
        let successfulRun = try await runner.run(
            request: successRequest,
            plan: successPlan,
            files: [successFile],
            modelContext: environment.context
        )

        let profileService = ProjectSpaceWorkflowProfileService(modelContext: environment.context)
        let beforeBlockedProfile = try XCTUnwrap(profileService.profile(normalizedProjectLabel: "Alpha"))
        XCTAssertEqual(beforeBlockedProfile.successfulTemplateCount, 1)

        let blockedSourceURL = try tempDirectory.createFile(name: "Drop/Blocked Spec.pdf", contents: "blocked")
        let blockedFile = FileItem(
            path: blockedSourceURL.path,
            sizeInBytes: 100,
            creationDate: creationDate,
            modificationDate: creationDate,
            lastAccessedDate: creationDate,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: nil,
            status: .pending
        )
        environment.context.insert(blockedFile)
        try environment.context.save()

        let blockedRequest = WorkflowExecutionRequest(
            templateID: BuiltInWorkflowTemplate.StableID.projectDrop,
            scopeID: UUID(),
            entryPoint: .projectPolicy(
                policyID: UUID(),
                triggerKind: .manual,
                projectLabel: "Alpha",
                policyName: "Project Drop Zone"
            )
        )
        let blockedPlan = WorkflowPlanner().plan(
            templateID: blockedRequest.templateID,
            files: [blockedFile],
            invocationContext: blockedRequest.invocationContext
        )
        XCTAssertTrue(blockedPlan.hasBlockers)

        do {
            _ = try await runner.run(
                request: blockedRequest,
                plan: blockedPlan,
                files: [blockedFile],
                modelContext: environment.context
            )
            XCTFail("Runner should fail for blocked project workflows")
        } catch let error as WorkflowRunner.RunnerError {
            guard case .blockedPlan = error else {
                XCTFail("Unexpected runner error: \(error)")
                return
            }
        }

        let afterBlockedProfile = try XCTUnwrap(profileService.profile(normalizedProjectLabel: "Alpha"))
        XCTAssertEqual(afterBlockedProfile.successfulTemplateID, BuiltInWorkflowTemplate.StableID.projectDrop)
        XCTAssertEqual(afterBlockedProfile.successfulTemplateCount, 1)
        XCTAssertEqual(afterBlockedProfile.dominantTriggerSurface, .projectPolicyManual)
        XCTAssertEqual(afterBlockedProfile.dominantTriggerSurfaceCount, 1)
        XCTAssertEqual(afterBlockedProfile.lastWorkflowRunID, successfulRun.id)
    }

    func testRunner_RolledBackWorkflow_RecordsConflictInsteadOfSuccess() async throws {
        let environment = try makeEnvironment()
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)
        FeatureFlagService.shared.setEnabled(.durableWorkflowStatus, true)
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Drop")
        let destinationFolder = try tempDirectory.createDirectory(name: "Projects")
        let destination = try Destination.folder(from: destinationFolder, displayName: "Projects")
        let creationDate = Date(timeIntervalSince1970: 1_712_620_800)

        let successSourceURL = try tempDirectory.createFile(name: "Drop/Successful Spec.pdf", contents: "success")
        let successFile = FileItem(
            path: successSourceURL.path,
            sizeInBytes: 100,
            creationDate: creationDate,
            modificationDate: creationDate,
            lastAccessedDate: creationDate,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .pending
        )
        environment.context.insert(successFile)
        try environment.context.save()

        let successRequest = WorkflowExecutionRequest(
            templateID: BuiltInWorkflowTemplate.StableID.projectDrop,
            scopeID: UUID(),
            entryPoint: .projectPolicy(
                policyID: UUID(),
                triggerKind: .manual,
                projectLabel: "Alpha",
                policyName: "Project Drop Zone"
            )
        )
        let successPlan = WorkflowPlanner().plan(
            templateID: successRequest.templateID,
            files: [successFile],
            invocationContext: successRequest.invocationContext
        )
        XCTAssertFalse(successPlan.hasBlockers)

        let successRunner = WorkflowRunner(
            auditStore: environment.auditStore,
            rollbackCoordinator: WorkflowRollbackCoordinator()
        )
        _ = try await successRunner.run(
            request: successRequest,
            plan: successPlan,
            files: [successFile],
            modelContext: environment.context
        )

        let failingSourceURL = try tempDirectory.createFile(name: "Drop/Failing Spec.pdf", contents: "failure")
        let failingFile = FileItem(
            path: failingSourceURL.path,
            sizeInBytes: 100,
            creationDate: creationDate,
            modificationDate: creationDate,
            lastAccessedDate: creationDate,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .pending
        )
        environment.context.insert(failingFile)
        try environment.context.save()

        let failingRequest = WorkflowExecutionRequest(
            templateID: BuiltInWorkflowTemplate.StableID.projectDrop,
            scopeID: UUID(),
            entryPoint: .projectPolicy(
                policyID: UUID(),
                triggerKind: .manual,
                projectLabel: "Alpha",
                policyName: "Project Drop Zone"
            )
        )
        let failingPlan = WorkflowPlanner().plan(
            templateID: failingRequest.templateID,
            files: [failingFile],
            invocationContext: failingRequest.invocationContext
        )
        XCTAssertFalse(failingPlan.hasBlockers)

        let moveExecutor = FailingMoveExecutor(
            baseExecutor: MoveWorkflowStepExecutor(fileOrganizationCoordinator: environment.coordinator),
            failingSourcePath: failingSourceURL.path
        )
        let failingRunner = WorkflowRunner(
            auditStore: environment.auditStore,
            rollbackCoordinator: WorkflowRollbackCoordinator(),
            executorsByKind: [
                .rename: RenameWorkflowStepExecutor(),
                .tag: TagWorkflowStepExecutor(),
                .projectAssociation: ProjectAssociationWorkflowStepExecutor(),
                .workflowStatus: WorkflowStatusWorkflowStepExecutor(),
                .notesSummary: NotesSummaryWorkflowStepExecutor(),
                .move: moveExecutor
            ]
        )

        do {
            _ = try await failingRunner.run(
                request: failingRequest,
                plan: failingPlan,
                files: [failingFile],
                modelContext: environment.context
            )
            XCTFail("Runner should fail after injected move failure")
        } catch {
            XCTAssertTrue(error is InjectedMoveFailure)
        }

        let failedRun = try XCTUnwrap(
            try environment.auditStore.latestRunSummary(
                scopeID: failingRequest.scopeID,
                workflowTemplateID: failingRequest.templateID
            )
        )
        XCTAssertEqual(failedRun.primaryStatus, .failed)
        XCTAssertEqual(failedRun.rollbackStatus, .succeeded)

        let profile = try XCTUnwrap(
            ProjectSpaceWorkflowProfileService(modelContext: environment.context)
                .profile(normalizedProjectLabel: "Alpha")
        )
        XCTAssertEqual(profile.lastWorkflowRunID, failedRun.id)
        XCTAssertEqual(profile.successfulTemplateID, BuiltInWorkflowTemplate.StableID.projectDrop)
        XCTAssertEqual(profile.successfulTemplateCount, 1)
        XCTAssertEqual(profile.dominantTriggerSurface, .projectPolicyManual)
        XCTAssertEqual(profile.dominantTriggerSurfaceCount, 1)
        XCTAssertEqual(profile.workflowMemoryStatus, .conflicted)
    }

    func testRunner_ProjectPolicyRun_PersistsAuditContextAndMetadataDeltas() async throws {
        let environment = try makeEnvironment()
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)
        FeatureFlagService.shared.setEnabled(.durableWorkflowStatus, true)
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Drop")
        let destinationFolder = try tempDirectory.createDirectory(name: "Projects")
        let sourceURL = try tempDirectory.createFile(name: "Drop/Product Spec.pdf", contents: "project")
        let destination = try Destination.folder(from: destinationFolder, displayName: "Projects")
        let creationDate = Date(timeIntervalSince1970: 1_712_620_800)

        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 100,
            creationDate: creationDate,
            modificationDate: creationDate,
            lastAccessedDate: creationDate,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .pending
        )
        environment.context.insert(file)
        try environment.context.save()

        let plan = WorkflowPlanner().plan(
            templateID: BuiltInWorkflowTemplate.StableID.projectDrop,
            files: [file],
            invocationContext: .projectPolicyManual(
                projectLabel: "Alpha",
                policyName: "Project Drop Zone"
            )
        )
        XCTAssertFalse(plan.hasBlockers)

        let runner = WorkflowRunner(
            auditStore: environment.auditStore,
            rollbackCoordinator: WorkflowRollbackCoordinator()
        )

        _ = try await runner.run(
            plan: plan,
            files: [file],
            scopeID: UUID(),
            modelContext: environment.context
        )

        let run = try XCTUnwrap(environment.context.fetch(FetchDescriptor<WorkflowRunRecord>()).first)
        XCTAssertEqual(run.triggerSurface, .projectPolicyManual)
        XCTAssertEqual(run.ownerDisplayName, "Alpha")
        XCTAssertEqual(run.policyName, "Project Drop Zone")

        let stepRuns = try environment.auditStore.stepRuns(runID: run.id)
        XCTAssertTrue(stepRuns.contains(where: { $0.stepID.contains("projectAssociation") && $0.status == .planned }))
        XCTAssertTrue(stepRuns.contains(where: { $0.stepID.contains("projectAssociation") && $0.status == .succeeded }))
        XCTAssertTrue(stepRuns.contains(where: { $0.stepID.contains("workflowStatus") && $0.status == .planned }))
        XCTAssertTrue(stepRuns.contains(where: { $0.stepID.contains("workflowStatus") && $0.status == .succeeded }))
        XCTAssertTrue(stepRuns.contains(where: { $0.stepID.contains("notesSummary") && $0.status == .planned }))
        XCTAssertTrue(stepRuns.contains(where: { $0.stepID.contains("notesSummary") && $0.status == .succeeded }))

        let fileActions = try environment.auditStore.fileActions(runID: run.id)
        XCTAssertTrue(fileActions.contains(where: { $0.metadataDelta?.resultingProjectAssociation == "Alpha" }))
        XCTAssertTrue(fileActions.contains(where: { $0.metadataDelta?.resultingWorkflowStatus == .organized }))
        XCTAssertTrue(fileActions.contains(where: { $0.metadataDelta?.resultingNotesSummary == "Project: Alpha | Policy: Project Drop Zone" }))
        XCTAssertTrue(fileActions.contains(where: { Set($0.metadataDelta?.addedTags ?? []) == Set(["project", "context", "intake"]) }))
    }

    func testRunner_ProjectSpaceInvocation_RollsBackMetadataStepsAfterMoveFailure() async throws {
        let environment = try makeEnvironment()
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)
        FeatureFlagService.shared.setEnabled(.durableWorkflowStatus, true)
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Drop")
        let destinationFolder = try tempDirectory.createDirectory(name: "Projects")
        let sourceURL = try tempDirectory.createFile(name: "Drop/Product Spec.pdf", contents: "project")
        let destination = try Destination.folder(from: destinationFolder, displayName: "Projects")
        let creationDate = Date(timeIntervalSince1970: 1_712_620_800)

        let seededRecord = try XCTUnwrap(
            FileMetadataFoundationService(modelContext: environment.context).upsertRecord(
                for: sourceURL.path,
                displayName: sourceURL.lastPathComponent,
                fileExtension: sourceURL.pathExtension,
                timestamp: creationDate
            )
        )
        seededRecord.projectAssociation = "Beta"
        seededRecord.workflowStatus = .queued
        seededRecord.notesSummary = "Project: Beta"
        try environment.context.save()

        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 100,
            creationDate: creationDate,
            modificationDate: creationDate,
            lastAccessedDate: creationDate,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .pending
        )
        environment.context.insert(file)
        try environment.context.save()

        let plan = WorkflowPlanner().plan(
            templateID: BuiltInWorkflowTemplate.StableID.projectDrop,
            files: [file],
            invocationContext: .projectSpace(projectLabel: "Alpha")
        )
        XCTAssertFalse(plan.hasBlockers)

        let moveExecutor = FailingMoveExecutor(
            baseExecutor: MoveWorkflowStepExecutor(fileOrganizationCoordinator: environment.coordinator),
            failingSourcePath: sourceURL.path
        )

        let runner = WorkflowRunner(
            auditStore: environment.auditStore,
            rollbackCoordinator: WorkflowRollbackCoordinator(),
            executorsByKind: [
                .rename: RenameWorkflowStepExecutor(),
                .tag: TagWorkflowStepExecutor(),
                .projectAssociation: ProjectAssociationWorkflowStepExecutor(),
                .workflowStatus: WorkflowStatusWorkflowStepExecutor(),
                .notesSummary: NotesSummaryWorkflowStepExecutor(),
                .move: moveExecutor
            ]
        )

        do {
            _ = try await runner.run(
                plan: plan,
                files: [file],
                scopeID: UUID(),
                modelContext: environment.context
            )
            XCTFail("Runner should fail after the injected move failure")
        } catch {
            XCTAssertTrue(error is InjectedMoveFailure)
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertEqual(file.path, sourceURL.path)

        let record = try XCTUnwrap(
            environment.context.fetch(FetchDescriptor<FileMetadataRecord>()).first
        )
        XCTAssertEqual(record.projectAssociation, "Beta")
        XCTAssertEqual(record.workflowStatus, .queued)
        XCTAssertEqual(record.notesSummary, "Project: Beta")

        let run = try XCTUnwrap(environment.context.fetch(FetchDescriptor<WorkflowRunRecord>()).first)
        XCTAssertEqual(run.primaryStatus, .failed)
        XCTAssertEqual(run.rollbackStatus, .succeeded)

        let stepRuns = try environment.auditStore.stepRuns(runID: run.id)
        XCTAssertTrue(stepRuns.contains(where: { $0.stepID.contains("projectAssociation") && $0.status == .succeeded }))
        XCTAssertTrue(stepRuns.contains(where: { $0.stepID.contains("workflowStatus") && $0.status == .succeeded }))
        XCTAssertTrue(stepRuns.contains(where: { $0.stepID.contains("notesSummary") && $0.status == .succeeded }))
        XCTAssertTrue(stepRuns.contains(where: { $0.stepID.contains("rollback") && $0.status == .succeeded }))

        let fileActions = try environment.auditStore.fileActions(runID: run.id)
        XCTAssertTrue(
            fileActions.contains(where: {
                $0.disposition == .restored &&
                Set($0.metadataDelta?.removedTags ?? []) == Set(["project", "context", "intake"])
            })
        )
        XCTAssertTrue(
            fileActions.contains(where: {
                $0.disposition == .restored &&
                $0.metadataDelta?.resultingProjectAssociation == "Beta"
            })
        )
        XCTAssertTrue(
            fileActions.contains(where: {
                $0.disposition == .restored &&
                $0.metadataDelta?.resultingWorkflowStatus == .queued
            })
        )
        XCTAssertTrue(
            fileActions.contains(where: {
                $0.disposition == .restored &&
                $0.metadataDelta?.resultingNotesSummary == "Project: Beta"
            })
        )
    }

    func testRunner_LogFailure_DoesNotRollbackDurableSuccess() async throws {
        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        let destinationFolder = try tempDirectory.createDirectory(name: "Receipts")
        let sourceURL = try tempDirectory.createFile(name: "Inbox/August Receipt.pdf", contents: "receipt")
        let destination = try Destination.folder(from: destinationFolder, displayName: "Receipts")
        let creationDate = Date(timeIntervalSince1970: 1_712_620_800)

        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 100,
            creationDate: creationDate,
            modificationDate: creationDate,
            lastAccessedDate: creationDate,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .pending
        )
        environment.context.insert(file)
        try environment.context.save()

        let plan = WorkflowPlanner().plan(
            templateID: BuiltInWorkflowTemplate.StableID.receipts,
            files: [file],
            invocationContext: .dashboardReview
        )
        XCTAssertFalse(plan.hasBlockers)

        let logExecutor = StubRunSideEffectExecutor(stepKind: .log) { _ in
            throw InjectedLogFailure()
        }

        let runner = WorkflowRunner(
            auditStore: environment.auditStore,
            rollbackCoordinator: WorkflowRollbackCoordinator(),
            executorsByKind: [
                .rename: RenameWorkflowStepExecutor(),
                .tag: TagWorkflowStepExecutor(),
                .workflowStatus: WorkflowStatusWorkflowStepExecutor(),
                .move: MoveWorkflowStepExecutor(fileOrganizationCoordinator: environment.coordinator)
            ],
            sideEffectExecutorsByKind: [
                .log: logExecutor
            ]
        )

        _ = try await runner.run(
            plan: plan,
            files: [file],
            scopeID: UUID(),
            modelContext: environment.context
        )

        let run = try XCTUnwrap(environment.context.fetch(FetchDescriptor<WorkflowRunRecord>()).first)
        XCTAssertEqual(run.primaryStatus, .completedWithIssues)
        XCTAssertEqual(run.rollbackStatus, .notRequested)
        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertEqual(file.status, .completed)

        let fileActions = try environment.auditStore.fileActions(runID: run.id)
        XCTAssertFalse(fileActions.contains(where: { $0.disposition == .restored }))
        XCTAssertTrue(fileActions.contains(where: { $0.disposition == .failed }))
    }

    func testRunner_TrustedScopeNotifySuccess_RecordsNotifiedDisposition() async throws {
        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Drop")
        let destinationFolder = try tempDirectory.createDirectory(name: "Projects")
        let sourceURL = try tempDirectory.createFile(name: "Drop/UI Mockup.png", contents: "mockup")
        let destination = try Destination.folder(from: destinationFolder, displayName: "Projects")
        let creationDate = Date(timeIntervalSince1970: 1_712_620_800)

        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 100,
            creationDate: creationDate,
            modificationDate: creationDate,
            lastAccessedDate: creationDate,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .pending
        )
        environment.context.insert(file)
        try environment.context.save()

        let plan = WorkflowPlanner().plan(
            templateID: BuiltInWorkflowTemplate.StableID.projectDrop,
            files: [file],
            invocationContext: .trustedScopeScheduled(scopeDisplayName: "Design Assets")
        )
        XCTAssertFalse(plan.hasBlockers)

        var notifiedCount = 0
        let notifyExecutor = StubRunSideEffectExecutor(stepKind: .notify) { _ in
            notifiedCount += 1
            return WorkflowRunSideEffectExecutionResult(
                stepStatus: .succeeded,
                disposition: .notified
            )
        }

        let runner = WorkflowRunner(
            auditStore: environment.auditStore,
            rollbackCoordinator: WorkflowRollbackCoordinator(),
            executorsByKind: [
                .rename: RenameWorkflowStepExecutor(),
                .tag: TagWorkflowStepExecutor(),
                .workflowStatus: WorkflowStatusWorkflowStepExecutor(),
                .move: MoveWorkflowStepExecutor(fileOrganizationCoordinator: environment.coordinator)
            ],
            sideEffectExecutorsByKind: [
                .log: LogWorkflowStepExecutor(),
                .notify: notifyExecutor
            ]
        )

        _ = try await runner.run(
            plan: plan,
            files: [file],
            scopeID: UUID(),
            modelContext: environment.context
        )

        XCTAssertEqual(notifiedCount, 1)

        let run = try XCTUnwrap(environment.context.fetch(FetchDescriptor<WorkflowRunRecord>()).first)
        XCTAssertEqual(run.primaryStatus, .succeeded)
        XCTAssertEqual(run.rollbackStatus, .notRequested)

        let fileActions = try environment.auditStore.fileActions(runID: run.id)
        XCTAssertTrue(fileActions.contains(where: { $0.disposition == .notified }))
    }

    func testRunner_RollsBackMoveTagRenameInReverseOrderAfterLateFailure() async throws {
        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        let destinationFolder = try tempDirectory.createDirectory(name: "Receipts")

        let firstSourceURL = try tempDirectory.createFile(name: "Inbox/First Receipt.pdf", contents: "one")
        let secondSourceURL = try tempDirectory.createFile(name: "Inbox/Second Receipt.pdf", contents: "two")
        let destination = try Destination.folder(from: destinationFolder, displayName: "Receipts")
        let creationDate = Date(timeIntervalSince1970: 1_712_620_800)

        let firstFile = FileItem(
            path: firstSourceURL.path,
            sizeInBytes: 100,
            creationDate: creationDate,
            modificationDate: creationDate,
            lastAccessedDate: creationDate,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .pending
        )
        let secondFile = FileItem(
            path: secondSourceURL.path,
            sizeInBytes: 100,
            creationDate: creationDate,
            modificationDate: creationDate,
            lastAccessedDate: creationDate,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .pending
        )
        environment.context.insert(firstFile)
        environment.context.insert(secondFile)
        try environment.context.save()

        let plan = WorkflowPlanner().plan(
            templateID: BuiltInWorkflowTemplate.StableID.receipts,
            files: [firstFile, secondFile]
        )
        XCTAssertFalse(plan.hasBlockers)

        let moveExecutor = FailingMoveExecutor(
            baseExecutor: MoveWorkflowStepExecutor(fileOrganizationCoordinator: environment.coordinator),
            failingSourcePath: secondSourceURL.path
        )

        let runner = WorkflowRunner(
            auditStore: environment.auditStore,
            rollbackCoordinator: WorkflowRollbackCoordinator(),
            executorsByKind: [
                .rename: RenameWorkflowStepExecutor(),
                .tag: TagWorkflowStepExecutor(),
                .move: moveExecutor
            ]
        )

        do {
            _ = try await runner.run(
                plan: plan,
                files: [firstFile, secondFile],
                scopeID: UUID(),
                modelContext: environment.context
            )
            XCTFail("Runner should fail after the injected late move failure")
        } catch {
            XCTAssertTrue(error is InjectedMoveFailure)
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: firstSourceURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: secondSourceURL.path))
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: destinationFolder.appendingPathComponent("2024-04-09-First Receipt.pdf").path
            )
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: destinationFolder.appendingPathComponent("2024-04-09-Second Receipt.pdf").path
            )
        )
        XCTAssertEqual(firstFile.path, firstSourceURL.path)
        XCTAssertEqual(secondFile.path, secondSourceURL.path)

        let run = try XCTUnwrap(try environment.auditStore.latestRunSummary(scopeID: environment.context.fetch(FetchDescriptor<WorkflowRunRecord>()).first?.scopeID ?? UUID(), workflowTemplateID: plan.definition.templateID))
        XCTAssertEqual(run.primaryStatus, .failed)
        XCTAssertEqual(run.rollbackStatus, .succeeded)

        let stepRecords = try environment.context.fetch(FetchDescriptor<WorkflowStepRunRecord>())
        XCTAssertTrue(stepRecords.contains(where: { $0.stepID.contains(secondSourceURL.path) && $0.status == .failed }))
        XCTAssertTrue(stepRecords.contains(where: { $0.stepID.contains("rollback") && $0.status == .succeeded }))

        let fileActions = try environment.context.fetch(FetchDescriptor<WorkflowFileActionRecord>())
        XCTAssertTrue(fileActions.contains(where: { $0.disposition == .restored && $0.compensationStatus == .applied }))

        let metadataRecords = try environment.context.fetch(FetchDescriptor<FileMetadataRecord>())
        XCTAssertEqual(metadataRecords.count, 2)
        XCTAssertTrue(metadataRecords.allSatisfy { $0.lastKnownPath == firstSourceURL.path || $0.lastKnownPath == secondSourceURL.path })
        XCTAssertTrue(metadataRecords.allSatisfy { !$0.tags.contains("receipt") && !$0.tags.contains("document") })
    }

    func testRunner_DoesNotRollbackWhenCurrentStepAuditPersistenceFailsAfterMoveExecution() async throws {
        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        let destinationFolder = try tempDirectory.createDirectory(name: "Receipts")
        let sourceURL = try tempDirectory.createFile(name: "Inbox/April Receipt.pdf", contents: "receipt")
        let destination = try Destination.folder(from: destinationFolder, displayName: "Receipts")
        let creationDate = Date(timeIntervalSince1970: 1_712_620_800)

        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 100,
            creationDate: creationDate,
            modificationDate: creationDate,
            lastAccessedDate: creationDate,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .pending
        )
        environment.context.insert(file)
        try environment.context.save()

        let plan = WorkflowPlanner().plan(
            templateID: BuiltInWorkflowTemplate.StableID.receipts,
            files: [file]
        )
        XCTAssertFalse(plan.hasBlockers)

        let finalDestinationPath = destinationFolder
            .appendingPathComponent("2024-04-09-April Receipt.pdf")
            .path
        var didFailCompletedMoveFileAction = false
        let auditOperations = WorkflowRunner.AuditOperations.live(store: environment.auditStore).with(
            recordFileAction: { args, recordFileAction in
                if args.destinationPath == finalDestinationPath,
                   args.disposition == .moved,
                   !didFailCompletedMoveFileAction {
                    didFailCompletedMoveFileAction = true
                    throw InjectedAuditFailure()
                }
                return try recordFileAction(args)
            }
        )

        let runner = WorkflowRunner(
            auditStore: environment.auditStore,
            rollbackCoordinator: WorkflowRollbackCoordinator(),
            executorsByKind: [
                .rename: RenameWorkflowStepExecutor(),
                .tag: TagWorkflowStepExecutor(),
                .move: MoveWorkflowStepExecutor(fileOrganizationCoordinator: environment.coordinator)
            ],
            auditOperations: auditOperations
        )

        _ = try await runner.run(
            plan: plan,
            files: [file],
            scopeID: UUID(),
            modelContext: environment.context
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: finalDestinationPath))
        XCTAssertEqual(file.path, finalDestinationPath)
        XCTAssertEqual(file.status, .completed)

        let workflowRuns = try environment.context.fetch(FetchDescriptor<WorkflowRunRecord>())
        let run = try XCTUnwrap(workflowRuns.first)
        XCTAssertEqual(run.primaryStatus, .succeeded)
        XCTAssertEqual(run.rollbackStatus, .notRequested)

        let fileActions = try environment.context.fetch(FetchDescriptor<WorkflowFileActionRecord>())
        XCTAssertTrue(
            fileActions.contains(where: {
                $0.disposition == .pending &&
                $0.compensationStatus == .available &&
                $0.destinationPath == finalDestinationPath
            })
        )
        XCTAssertFalse(fileActions.contains(where: { $0.disposition == .restored && $0.compensationStatus == .applied }))

        let metadataRecord = try XCTUnwrap(
            environment.context.fetch(FetchDescriptor<FileMetadataRecord>()).first
        )
        XCTAssertEqual(metadataRecord.lastKnownPath, finalDestinationPath)
        XCTAssertTrue(metadataRecord.tags.contains("receipt"))
        XCTAssertTrue(metadataRecord.tags.contains("document"))
    }

    func testRunner_DoesNotMutateWhenCompensationPayloadPersistenceFailsBeforeMoveExecution() async throws {
        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        let destinationFolder = try tempDirectory.createDirectory(name: "Receipts")
        let sourceURL = try tempDirectory.createFile(name: "Inbox/May Receipt.pdf", contents: "receipt")
        let destination = try Destination.folder(from: destinationFolder, displayName: "Receipts")
        let creationDate = Date(timeIntervalSince1970: 1_712_620_800)

        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 100,
            creationDate: creationDate,
            modificationDate: creationDate,
            lastAccessedDate: creationDate,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .pending
        )
        environment.context.insert(file)
        try environment.context.save()

        let plan = WorkflowPlanner().plan(
            templateID: BuiltInWorkflowTemplate.StableID.receipts,
            files: [file]
        )
        XCTAssertFalse(plan.hasBlockers)

        let finalDestinationPath = destinationFolder
            .appendingPathComponent("2024-04-09-May Receipt.pdf")
            .path
        var didFailPendingCompensationWrite = false
        let auditOperations = WorkflowRunner.AuditOperations.live(store: environment.auditStore).with(
            recordFileAction: { args, recordFileAction in
                if args.destinationPath == finalDestinationPath,
                   args.disposition == .pending,
                   args.stepRunID == nil,
                   !didFailPendingCompensationWrite {
                    didFailPendingCompensationWrite = true
                    throw InjectedAuditFailure()
                }
                return try recordFileAction(args)
            }
        )

        let runner = WorkflowRunner(
            auditStore: environment.auditStore,
            rollbackCoordinator: WorkflowRollbackCoordinator(),
            executorsByKind: [
                .rename: RenameWorkflowStepExecutor(),
                .tag: TagWorkflowStepExecutor(),
                .move: MoveWorkflowStepExecutor(fileOrganizationCoordinator: environment.coordinator)
            ],
            auditOperations: auditOperations
        )

        do {
            _ = try await runner.run(
                plan: plan,
                files: [file],
                scopeID: UUID(),
                modelContext: environment.context
            )
            XCTFail("Runner should fail before executing move when compensation persistence fails")
        } catch {
            XCTAssertTrue(error is InjectedAuditFailure)
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: finalDestinationPath))
        XCTAssertEqual(file.path, sourceURL.path)
        XCTAssertEqual(file.status, .pending)

        let workflowRuns = try environment.context.fetch(FetchDescriptor<WorkflowRunRecord>())
        let run = try XCTUnwrap(workflowRuns.first)
        XCTAssertEqual(run.primaryStatus, .failed)
        XCTAssertEqual(run.rollbackStatus, .succeeded)

        let fileActions = try environment.context.fetch(FetchDescriptor<WorkflowFileActionRecord>())
        XCTAssertFalse(
            fileActions.contains(where: {
                $0.destinationPath == finalDestinationPath &&
                $0.disposition == .pending
            })
        )
        XCTAssertFalse(fileActions.contains(where: { $0.destinationPath == finalDestinationPath && $0.disposition == .moved }))
        XCTAssertTrue(fileActions.contains(where: { $0.disposition == .restored && $0.compensationStatus == .applied }))
    }

    func testRunner_RollsBackWhenRunAndRollbackStatusWritesFailAfterLateFailure() async throws {
        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        let destinationFolder = try tempDirectory.createDirectory(name: "Receipts")

        let firstSourceURL = try tempDirectory.createFile(name: "Inbox/First Receipt.pdf", contents: "one")
        let secondSourceURL = try tempDirectory.createFile(name: "Inbox/Second Receipt.pdf", contents: "two")
        let destination = try Destination.folder(from: destinationFolder, displayName: "Receipts")
        let creationDate = Date(timeIntervalSince1970: 1_712_620_800)

        let firstFile = FileItem(
            path: firstSourceURL.path,
            sizeInBytes: 100,
            creationDate: creationDate,
            modificationDate: creationDate,
            lastAccessedDate: creationDate,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .pending
        )
        let secondFile = FileItem(
            path: secondSourceURL.path,
            sizeInBytes: 100,
            creationDate: creationDate,
            modificationDate: creationDate,
            lastAccessedDate: creationDate,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .pending
        )
        environment.context.insert(firstFile)
        environment.context.insert(secondFile)
        try environment.context.save()

        let plan = WorkflowPlanner().plan(
            templateID: BuiltInWorkflowTemplate.StableID.receipts,
            files: [firstFile, secondFile]
        )
        XCTAssertFalse(plan.hasBlockers)

        let moveExecutor = FailingMoveExecutor(
            baseExecutor: MoveWorkflowStepExecutor(fileOrganizationCoordinator: environment.coordinator),
            failingSourcePath: secondSourceURL.path
        )

        var didFailRunStatus = false
        var didFailRollbackStatus = false
        let auditOperations = WorkflowRunner.AuditOperations.live(store: environment.auditStore).with(
            updateRunStatus: { args, updateRunStatus in
                if args.primaryStatus == .failed && !didFailRunStatus {
                    didFailRunStatus = true
                    throw InjectedRunStatusFailure()
                }
                try updateRunStatus(args)
            },
            updateRollbackStatus: { args, updateRollbackStatus in
                if args.rollbackStatus == .requested && !didFailRollbackStatus {
                    didFailRollbackStatus = true
                    throw InjectedRollbackStatusFailure()
                }
                try updateRollbackStatus(args)
            }
        )

        let runner = WorkflowRunner(
            auditStore: environment.auditStore,
            rollbackCoordinator: WorkflowRollbackCoordinator(),
            executorsByKind: [
                .rename: RenameWorkflowStepExecutor(),
                .tag: TagWorkflowStepExecutor(),
                .move: moveExecutor
            ],
            auditOperations: auditOperations
        )

        do {
            _ = try await runner.run(
                plan: plan,
                files: [firstFile, secondFile],
                scopeID: UUID(),
                modelContext: environment.context
            )
            XCTFail("Runner should surface the underlying late move failure")
        } catch {
            XCTAssertTrue(error is InjectedMoveFailure)
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: firstSourceURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: secondSourceURL.path))
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: destinationFolder.appendingPathComponent("2024-04-09-First Receipt.pdf").path
            )
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: destinationFolder.appendingPathComponent("2024-04-09-Second Receipt.pdf").path
            )
        )
        XCTAssertEqual(firstFile.path, firstSourceURL.path)
        XCTAssertEqual(secondFile.path, secondSourceURL.path)

        let fileActions = try environment.context.fetch(FetchDescriptor<WorkflowFileActionRecord>())
        XCTAssertTrue(fileActions.contains(where: { $0.disposition == .restored && $0.compensationStatus == .applied }))
    }

    func testRunner_SuccessFinalizationAuditWriteFailureDoesNotThrowAfterFilesystemMutation() async throws {
        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        let destinationFolder = try tempDirectory.createDirectory(name: "Receipts")
        let sourceURL = try tempDirectory.createFile(name: "Inbox/June Receipt.pdf", contents: "receipt")
        let destination = try Destination.folder(from: destinationFolder, displayName: "Receipts")
        let creationDate = Date(timeIntervalSince1970: 1_712_620_800)

        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 100,
            creationDate: creationDate,
            modificationDate: creationDate,
            lastAccessedDate: creationDate,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .pending
        )
        environment.context.insert(file)
        try environment.context.save()

        let plan = WorkflowPlanner().plan(
            templateID: BuiltInWorkflowTemplate.StableID.receipts,
            files: [file]
        )
        XCTAssertFalse(plan.hasBlockers)

        let finalDestinationPath = destinationFolder
            .appendingPathComponent("2024-04-09-June Receipt.pdf")
            .path
        var didFailMovedFileAction = false
        var didFailSucceededRunStatus = false
        let auditOperations = WorkflowRunner.AuditOperations.live(store: environment.auditStore).with(
            updateRunStatus: { args, updateRunStatus in
                if args.primaryStatus == .succeeded && !didFailSucceededRunStatus {
                    didFailSucceededRunStatus = true
                    throw InjectedRunStatusFailure()
                }
                try updateRunStatus(args)
            },
            recordFileAction: { args, recordFileAction in
                if args.destinationPath == finalDestinationPath,
                   args.disposition == .moved,
                   !didFailMovedFileAction {
                    didFailMovedFileAction = true
                    throw InjectedAuditFailure()
                }
                return try recordFileAction(args)
            }
        )

        let runner = WorkflowRunner(
            auditStore: environment.auditStore,
            rollbackCoordinator: WorkflowRollbackCoordinator(),
            executorsByKind: [
                .rename: RenameWorkflowStepExecutor(),
                .tag: TagWorkflowStepExecutor(),
                .move: MoveWorkflowStepExecutor(fileOrganizationCoordinator: environment.coordinator)
            ],
            auditOperations: auditOperations
        )

        _ = try await runner.run(
            plan: plan,
            files: [file],
            scopeID: UUID(),
            modelContext: environment.context
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: finalDestinationPath))
        XCTAssertEqual(file.path, finalDestinationPath)
        XCTAssertEqual(file.status, .completed)

        let run = try XCTUnwrap(try environment.context.fetch(FetchDescriptor<WorkflowRunRecord>()).first)
        XCTAssertNotEqual(run.primaryStatus, .failed)
        XCTAssertEqual(run.rollbackStatus, .notRequested)

        let fileActions = try environment.context.fetch(FetchDescriptor<WorkflowFileActionRecord>())
        XCTAssertFalse(fileActions.contains(where: { $0.disposition == .restored }))
    }

    func testRunner_RollbackOutcomeAuditWriteFailureDoesNotMaskOriginalExecutionFailure() async throws {
        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        let destinationFolder = try tempDirectory.createDirectory(name: "Receipts")
        let firstSourceURL = try tempDirectory.createFile(name: "Inbox/First Receipt.pdf", contents: "one")
        let secondSourceURL = try tempDirectory.createFile(name: "Inbox/Second Receipt.pdf", contents: "two")
        let destination = try Destination.folder(from: destinationFolder, displayName: "Receipts")
        let creationDate = Date(timeIntervalSince1970: 1_712_620_800)

        let firstFile = FileItem(
            path: firstSourceURL.path,
            sizeInBytes: 100,
            creationDate: creationDate,
            modificationDate: creationDate,
            lastAccessedDate: creationDate,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .pending
        )
        let secondFile = FileItem(
            path: secondSourceURL.path,
            sizeInBytes: 100,
            creationDate: creationDate,
            modificationDate: creationDate,
            lastAccessedDate: creationDate,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .pending
        )
        environment.context.insert(firstFile)
        environment.context.insert(secondFile)
        try environment.context.save()

        let plan = WorkflowPlanner().plan(
            templateID: BuiltInWorkflowTemplate.StableID.receipts,
            files: [firstFile, secondFile]
        )
        XCTAssertFalse(plan.hasBlockers)

        let moveExecutor = FailingMoveExecutor(
            baseExecutor: MoveWorkflowStepExecutor(fileOrganizationCoordinator: environment.coordinator),
            failingSourcePath: secondSourceURL.path
        )

        var didFailRollbackOutcomeWrite = false
        let auditOperations = WorkflowRunner.AuditOperations.live(store: environment.auditStore).with(
            recordFileAction: { args, recordFileAction in
                if args.disposition == .restored,
                   !didFailRollbackOutcomeWrite {
                    didFailRollbackOutcomeWrite = true
                    throw InjectedAuditFailure()
                }
                return try recordFileAction(args)
            }
        )

        let runner = WorkflowRunner(
            auditStore: environment.auditStore,
            rollbackCoordinator: WorkflowRollbackCoordinator(),
            executorsByKind: [
                .rename: RenameWorkflowStepExecutor(),
                .tag: TagWorkflowStepExecutor(),
                .move: moveExecutor
            ],
            auditOperations: auditOperations
        )

        do {
            _ = try await runner.run(
                plan: plan,
                files: [firstFile, secondFile],
                scopeID: UUID(),
                modelContext: environment.context
            )
            XCTFail("Runner should surface the original execution failure")
        } catch {
            XCTAssertTrue(error is InjectedMoveFailure)
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: firstSourceURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: secondSourceURL.path))
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: destinationFolder.appendingPathComponent("2024-04-09-First Receipt.pdf").path
            )
        )
        XCTAssertEqual(firstFile.path, firstSourceURL.path)
        XCTAssertEqual(secondFile.path, secondSourceURL.path)
    }
}
