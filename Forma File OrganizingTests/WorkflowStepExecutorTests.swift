import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class WorkflowStepExecutorTests: XCTestCase {
    private struct InjectedMetadataFailure: Error {}

    private func makeEnvironment() throws -> (
        container: ModelContainer,
        context: ModelContext,
        metadataService: FileMetadataFoundationService,
        coordinator: FileOrganizationCoordinator
    ) {
        let schema = Schema([
            FileItem.self,
            FileMetadataRecord.self,
            FileOrganizationHistoryEntry.self
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
            metadataService: FileMetadataFoundationService(modelContext: context),
            coordinator: FileOrganizationCoordinator()
        )
    }

    override func tearDown() {
        FeatureFlagService.shared.resetToDefaults()
        super.tearDown()
    }

    func testRenameExecutor_RekeysWorkingPathAndCapturesCompensation() async throws {
        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceURL = try tempDirectory.createFile(name: "Inbox/April Receipt.pdf", contents: "receipt")
        let workingURL = tempDirectory.url(for: "Inbox/2026-04-08-April Receipt.pdf")
        let timestamp = Date(timeIntervalSince1970: 1_000)

        _ = try environment.metadataService.upsertRecord(
            for: sourceURL.path,
            displayName: sourceURL.lastPathComponent,
            fileExtension: sourceURL.pathExtension,
            timestamp: timestamp
        )

        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 128,
            creationDate: timestamp,
            modificationDate: timestamp,
            lastAccessedDate: timestamp,
            status: .pending
        )
        environment.context.insert(file)
        try environment.context.save()

        let plannedFile = makePlannedFile(
            sourcePath: sourceURL.path,
            workingPath: workingURL.path,
            finalDestinationPath: nil,
            renameTargetName: workingURL.lastPathComponent,
            tagIntents: []
        )

        let executor = RenameWorkflowStepExecutor()
        let result = try await executor.execute(
            file: file,
            plannedFile: plannedFile,
            modelContext: environment.context
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: workingURL.path))
        XCTAssertEqual(file.path, workingURL.path)
        XCTAssertEqual(result.disposition, .moved)
        XCTAssertEqual(result.compensationStatus, .available)
        XCTAssertEqual(
            result.compensationPayloadDescriptor,
            .renameRollback(originalPath: sourceURL.path, renamedPath: workingURL.path)
        )

        let record = try XCTUnwrap(
            environment.context.fetch(FetchDescriptor<FileMetadataRecord>()).first
        )
        XCTAssertEqual(record.lastKnownPath, workingURL.path)
        XCTAssertEqual(record.latestOrganizationStatus, .rekeyed)
        XCTAssertEqual(record.historyEntries.map(\.eventKind), [.rekeyed])
    }

    func testTagExecutor_AppliesTemplateTagsThroughMetadataFoundation() async throws {
        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let fileURL = try tempDirectory.createFile(name: "Inbox/invoice.pdf", contents: "invoice")
        let timestamp = Date(timeIntervalSince1970: 2_000)

        let existingRecord = try XCTUnwrap(
            environment.metadataService.upsertRecord(
                for: fileURL.path,
                displayName: fileURL.lastPathComponent,
                fileExtension: fileURL.pathExtension,
                timestamp: timestamp
            )
        )
        existingRecord.tags = ["finance"]
        try environment.context.save()

        let file = FileItem(
            path: fileURL.path,
            sizeInBytes: 64,
            creationDate: timestamp,
            modificationDate: timestamp,
            lastAccessedDate: timestamp,
            status: .pending
        )
        environment.context.insert(file)
        try environment.context.save()

        let plannedFile = makePlannedFile(
            sourcePath: fileURL.path,
            workingPath: fileURL.path,
            finalDestinationPath: nil,
            renameTargetName: fileURL.lastPathComponent,
            tagIntents: ["finance", "receipt", "document"]
        )

        let executor = TagWorkflowStepExecutor()
        let result = try await executor.execute(
            file: file,
            plannedFile: plannedFile,
            modelContext: environment.context
        )

        let record = try XCTUnwrap(
            environment.context.fetch(FetchDescriptor<FileMetadataRecord>()).first
        )
        XCTAssertEqual(record.tags, ["finance", "receipt", "document"])
        XCTAssertEqual(result.disposition, .pending)
        XCTAssertEqual(result.compensationStatus, .available)
        XCTAssertEqual(
            result.compensationPayloadDescriptor,
            .tagRemoval(path: fileURL.path, tagsToRemove: ["receipt", "document"])
        )
    }

    func testMoveExecutor_MovesFileWithoutPushingUndoStackAndCapturesCompensation() async throws {
        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceURL = try tempDirectory.createFile(name: "Inbox/project-notes.txt", contents: "notes")
        let destinationFolderURL = try tempDirectory.createDirectory(name: "Archive")
        let destination = try Destination.folder(from: destinationFolderURL, displayName: "Archive")
        let timestamp = Date(timeIntervalSince1970: 3_000)

        _ = try environment.metadataService.upsertRecord(
            for: sourceURL.path,
            displayName: sourceURL.lastPathComponent,
            fileExtension: sourceURL.pathExtension,
            timestamp: timestamp
        )

        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 64,
            creationDate: timestamp,
            modificationDate: timestamp,
            lastAccessedDate: timestamp,
            destination: destination,
            status: .pending
        )
        environment.context.insert(file)
        try environment.context.save()

        let destinationURL = destinationFolderURL.appendingPathComponent(sourceURL.lastPathComponent)
        let plannedFile = makePlannedFile(
            sourcePath: sourceURL.path,
            workingPath: sourceURL.path,
            finalDestinationPath: destinationURL.path,
            renameTargetName: sourceURL.lastPathComponent,
            tagIntents: []
        )

        let executor = MoveWorkflowStepExecutor(fileOrganizationCoordinator: environment.coordinator)
        let result = try await executor.execute(
            file: file,
            plannedFile: plannedFile,
            modelContext: environment.context
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))
        XCTAssertEqual(file.path, destinationURL.path)
        XCTAssertEqual(file.status, .completed)
        XCTAssertTrue(environment.coordinator.undoStack.isEmpty)
        XCTAssertEqual(result.disposition, .moved)
        XCTAssertEqual(result.compensationStatus, .available)
        XCTAssertEqual(
            result.compensationPayloadDescriptor,
            .moveRollback(originalDestinationPath: destinationURL.path, rollbackPath: sourceURL.path)
        )

        let record = try XCTUnwrap(
            environment.context.fetch(FetchDescriptor<FileMetadataRecord>()).first
        )
        XCTAssertEqual(record.lastKnownPath, destinationURL.path)
        XCTAssertEqual(record.historyEntries.map(\.eventKind), [.organized])
    }

    func testMoveExecutor_WrapsLateMetadataFailureWithCompensation() async throws {
        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceURL = try tempDirectory.createFile(name: "Inbox/report.txt", contents: "report")
        let destinationFolderURL = try tempDirectory.createDirectory(name: "Archive")
        let destination = try Destination.folder(from: destinationFolderURL, displayName: "Archive")
        let timestamp = Date(timeIntervalSince1970: 4_000)

        _ = try environment.metadataService.upsertRecord(
            for: sourceURL.path,
            displayName: sourceURL.lastPathComponent,
            fileExtension: sourceURL.pathExtension,
            timestamp: timestamp
        )

        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 64,
            creationDate: timestamp,
            modificationDate: timestamp,
            lastAccessedDate: timestamp,
            destination: destination,
            status: .pending
        )
        environment.context.insert(file)
        try environment.context.save()

        let destinationURL = destinationFolderURL.appendingPathComponent(sourceURL.lastPathComponent)
        let plannedFile = makePlannedFile(
            sourcePath: sourceURL.path,
            workingPath: sourceURL.path,
            finalDestinationPath: destinationURL.path,
            renameTargetName: sourceURL.lastPathComponent,
            tagIntents: []
        )

        let executor = MoveWorkflowStepExecutor(
            fileOrganizationCoordinator: environment.coordinator,
            recordTransition: { _, _, _ in
                throw InjectedMetadataFailure()
            }
        )

        do {
            _ = try await executor.execute(
                file: file,
                plannedFile: plannedFile,
                modelContext: environment.context
            )
            XCTFail("Expected post-move metadata persistence to fail")
        } catch let failure as WorkflowStepExecutionFailure {
            XCTAssertTrue(failure.underlyingError is InjectedMetadataFailure)
            XCTAssertEqual(failure.sourcePath, sourceURL.path)
            XCTAssertEqual(failure.destinationPath, destinationURL.path)
            XCTAssertEqual(failure.compensationStatus, .available)
            XCTAssertEqual(
                failure.compensationPayloadDescriptor,
                .moveRollback(
                    originalDestinationPath: destinationURL.path,
                    rollbackPath: sourceURL.path
                )
            )

            XCTAssertFalse(FileManager.default.fileExists(atPath: sourceURL.path))
            XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))

            let compensation = try XCTUnwrap(
                executor.makeCompensationAction(
                    fileIdentity: "report-identity",
                    compensationPayload: failure.compensationAuditPayload,
                    file: file,
                    modelContext: environment.context
                )
            )
            try compensation.apply()

            XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: destinationURL.path))
            XCTAssertEqual(file.path, sourceURL.path)
            XCTAssertEqual(file.status, .pending)
        }
    }

    private func makePlannedFile(
        sourcePath: String,
        workingPath: String,
        finalDestinationPath: String?,
        renameTargetName: String,
        tagIntents: [String]
    ) -> WorkflowPlannedFile {
        WorkflowPlannedFile(
            sourcePath: sourcePath,
            workingPath: workingPath,
            finalDestinationPath: finalDestinationPath,
            renameTargetName: renameTargetName,
            tagIntents: tagIntents,
            steps: [
                WorkflowSimulatedStep(
                    kind: .rename,
                    disposition: .planned,
                    blocker: nil,
                    compensationPayload: .renameRollback(originalPath: sourcePath, renamedPath: workingPath)
                ),
                WorkflowSimulatedStep(
                    kind: .tag,
                    disposition: .planned,
                    blocker: nil,
                    compensationPayload: .tagRemoval(path: workingPath, tagsToRemove: tagIntents)
                ),
                WorkflowSimulatedStep(
                    kind: .move,
                    disposition: .planned,
                    blocker: nil,
                    compensationPayload: finalDestinationPath.map {
                        .moveRollback(originalDestinationPath: $0, rollbackPath: workingPath)
                    }
                )
            ],
            blockers: []
        )
    }
}
