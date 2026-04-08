import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class WorkflowRunnerTests: XCTestCase {
    private struct InjectedMoveFailure: Error {}
    private struct InjectedAuditFailure: Error {}
    private struct InjectedRunStatusFailure: Error {}
    private struct InjectedRollbackStatusFailure: Error {}

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
            FileItem.self,
            FileMetadataRecord.self,
            FileOrganizationHistoryEntry.self,
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
