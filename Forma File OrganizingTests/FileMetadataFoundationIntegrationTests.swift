import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class FileMetadataFoundationIntegrationTests: XCTestCase {
    private enum InjectedMetadataFailure: Error {
        case bulkUndoFirstItem
        case transitionWriteFailure
        case skipMainContextSaveFailure
        case workflowTagSaveFailure
    }
    override func setUp() {
        super.setUp()
        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
    }

    override func tearDown() {
        FeatureFlagService.shared.resetToDefaults()
        super.tearDown()
    }

    private func makeEnvironment() throws -> (
        container: ModelContainer,
        context: ModelContext,
        coordinator: FileOrganizationCoordinator,
        metadataService: FileMetadataFoundationService
    ) {
        try makeEnvironment(metadataUndoTransitionHook: nil)
    }

    private func makeEnvironment(
        metadataUndoTransitionHook: ((MetadataIdentitySnapshot) throws -> Void)?
    ) throws -> (
        container: ModelContainer,
        context: ModelContext,
        coordinator: FileOrganizationCoordinator,
        metadataService: FileMetadataFoundationService
    ) {
        let schema = Schema([
            FileItem.self,
            ActivityItem.self,
            FileMetadataRecord.self,
            FileOrganizationHistoryEntry.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let coordinator = FileOrganizationCoordinator()
        coordinator.metadataUndoTransitionHook = metadataUndoTransitionHook
        return (
            container: container,
            context: context,
            coordinator: coordinator,
            metadataService: FileMetadataFoundationService(modelContext: context)
        )
    }

    @discardableResult
    private func insertPathFallbackRecord(
        in context: ModelContext,
        path: String,
        displayName: String,
        fileExtension: String,
        timestamp: Date
    ) throws -> FileMetadataRecord {
        let record = FileMetadataRecord(
            canonicalIdentity: FileMetadataFoundationService.pathFallbackCanonicalIdentity(for: path),
            identityKind: .pathFallback,
            lastKnownPath: path,
            displayName: displayName,
            fileExtension: fileExtension,
            firstSeenAt: timestamp,
            lastSeenAt: timestamp
        )
        context.insert(record)
        try context.save()
        return record
    }

    func testProjectSpaceRetrieval_ReturnsResolvableSummariesAndDetail() throws {
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)

        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let alphaURL = try tempDirectory.createFile(name: "Inbox/alpha.txt", contents: "alpha")
        let betaURL = try tempDirectory.createFile(name: "Inbox/beta.txt", contents: "beta")
        let staleURL = try tempDirectory.createFile(name: "Inbox/stale.txt", contents: "stale")

        let alphaRecord = try insertPathFallbackRecord(
            in: environment.context,
            path: alphaURL.path,
            displayName: alphaURL.lastPathComponent,
            fileExtension: "txt",
            timestamp: Date(timeIntervalSince1970: 1_000)
        )
        alphaRecord.projectAssociation = "Alpha"
        alphaRecord.lastSeenAt = Date(timeIntervalSince1970: 2_000)

        let betaRecord = try insertPathFallbackRecord(
            in: environment.context,
            path: betaURL.path,
            displayName: betaURL.lastPathComponent,
            fileExtension: "txt",
            timestamp: Date(timeIntervalSince1970: 1_500)
        )
        betaRecord.projectAssociation = "Beta"
        betaRecord.lastSeenAt = Date(timeIntervalSince1970: 1_600)

        let staleRecord = try insertPathFallbackRecord(
            in: environment.context,
            path: staleURL.path,
            displayName: staleURL.lastPathComponent,
            fileExtension: "txt",
            timestamp: Date(timeIntervalSince1970: 1_700)
        )
        staleRecord.projectAssociation = "Alpha"
        try FileManager.default.removeItem(at: staleURL)

        try environment.context.save()

        let summaries = environment.metadataService.fetchProjectSpaceSummaries()
        XCTAssertEqual(summaries.map(\.normalizedLabel), ["Alpha", "Beta"])
        XCTAssertEqual(summaries.map(\.fileCount), [1, 1])

        let alphaDetail = try XCTUnwrap(environment.metadataService.fetchProjectSpaceDetail(for: "Alpha"))
        XCTAssertEqual(alphaDetail.summary.normalizedLabel, "Alpha")
        XCTAssertEqual(alphaDetail.files.map(\.displayName), ["alpha.txt"])
    }

    func testProjectSpaceCorrection_RefreshesSummariesAndDetailsAfterAssociationUpdate() throws {
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)
        FeatureFlagService.shared.setEnabled(.projectSpaceMemory, true)

        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let alphaOneURL = try tempDirectory.createFile(name: "Inbox/alpha-one.txt", contents: "alpha")
        let alphaTwoURL = try tempDirectory.createFile(name: "Inbox/alpha-two.txt", contents: "alpha")
        let betaURL = try tempDirectory.createFile(name: "Inbox/beta.txt", contents: "beta")

        let alphaOneRecord = try insertPathFallbackRecord(
            in: environment.context,
            path: alphaOneURL.path,
            displayName: alphaOneURL.lastPathComponent,
            fileExtension: "txt",
            timestamp: Date(timeIntervalSince1970: 1_000)
        )
        alphaOneRecord.projectAssociation = "Alpha"

        let alphaTwoRecord = try insertPathFallbackRecord(
            in: environment.context,
            path: alphaTwoURL.path,
            displayName: alphaTwoURL.lastPathComponent,
            fileExtension: "txt",
            timestamp: Date(timeIntervalSince1970: 1_100)
        )
        alphaTwoRecord.projectAssociation = "Alpha"

        let betaRecord = try insertPathFallbackRecord(
            in: environment.context,
            path: betaURL.path,
            displayName: betaURL.lastPathComponent,
            fileExtension: "txt",
            timestamp: Date(timeIntervalSince1970: 1_200)
        )
        betaRecord.projectAssociation = "Beta"

        try environment.context.save()

        let initialSummaryByLabel = Dictionary(uniqueKeysWithValues: environment.metadataService.fetchProjectSpaceSummaries().map {
            ($0.normalizedLabel, $0.fileCount)
        })
        XCTAssertEqual(initialSummaryByLabel, ["Alpha": 2, "Beta": 1])
        XCTAssertEqual(try XCTUnwrap(environment.metadataService.fetchProjectSpaceDetail(for: "Alpha")).summary.fileCount, 2)
        XCTAssertEqual(try XCTUnwrap(environment.metadataService.fetchProjectSpaceDetail(for: "Beta")).summary.fileCount, 1)

        let didCorrect = try environment.metadataService.correctProjectAssociation(
            forCanonicalIdentity: alphaTwoRecord.canonicalIdentity,
            to: "  Beta  ",
            timestamp: Date(timeIntervalSince1970: 2_000)
        )
        XCTAssertTrue(didCorrect)

        let refreshedSummaryByLabel = Dictionary(uniqueKeysWithValues: environment.metadataService.fetchProjectSpaceSummaries().map {
            ($0.normalizedLabel, $0.fileCount)
        })
        XCTAssertEqual(refreshedSummaryByLabel, ["Alpha": 1, "Beta": 2])

        let alphaDetail = try XCTUnwrap(environment.metadataService.fetchProjectSpaceDetail(for: "Alpha"))
        XCTAssertEqual(alphaDetail.summary.fileCount, 1)
        XCTAssertEqual(alphaDetail.files.map(\.displayName), ["alpha-one.txt"])

        let betaDetail = try XCTUnwrap(environment.metadataService.fetchProjectSpaceDetail(for: "Beta"))
        XCTAssertEqual(betaDetail.summary.fileCount, 2)
        XCTAssertEqual(Set(betaDetail.files.map(\.displayName)), ["alpha-two.txt", "beta.txt"])
        XCTAssertEqual(
            betaDetail.files
                .first(where: { $0.canonicalIdentity == alphaTwoRecord.canonicalIdentity })?
                .projectAssociation,
            "Beta"
        )
    }

    func testOrganizeFile_UpdatesMetadataRecordAndAppendsHistory() async throws {
        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        let destinationFolder = try tempDirectory.createDirectory(name: "Archive")
        let sourceURL = sourceFolder.appendingPathComponent("report.pdf")
        let destinationURL = destinationFolder.appendingPathComponent("report.pdf")
        let initialTimestamp = Date(timeIntervalSince1970: 1_000)

        _ = try insertPathFallbackRecord(
            in: environment.context,
            path: sourceURL.path,
            displayName: "report.pdf",
            fileExtension: "pdf",
            timestamp: initialTimestamp
        )

        let sourceFileURL = try tempDirectory.createFile(name: "Inbox/report.pdf", contents: "report")
        XCTAssertEqual(sourceFileURL.path, sourceURL.path)

        let destination = try Destination.folder(from: destinationURL.deletingLastPathComponent(), displayName: "Archive")
        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 1_024,
            creationDate: initialTimestamp,
            modificationDate: initialTimestamp,
            lastAccessedDate: initialTimestamp,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .ready
        )
        environment.context.insert(file)
        try environment.context.save()

        let successExpectation = expectation(description: "organize success")
        var capturedAction: FileOrganizationCoordinator.FileActionData?

        await environment.coordinator.organizeFile(
            file,
            context: environment.context,
            sourceSurface: .reviewFlow,
            onSuccess: { action in
                capturedAction = action
                successExpectation.fulfill()
            },
            onError: { error in
                XCTFail("Organize should succeed: \(error)")
            }
        )

        await fulfillment(of: [successExpectation], timeout: 2.0)
        XCTAssertNotNil(capturedAction)

        let records = try environment.context.fetch(FetchDescriptor<FileMetadataRecord>())
        XCTAssertEqual(records.count, 1)

        let record = try XCTUnwrap(records.first)
        XCTAssertEqual(record.lastKnownPath, destinationURL.path)
        XCTAssertEqual(record.organizationCount, 1)
        XCTAssertEqual(record.latestOrganizationStatus, .organized)
        XCTAssertEqual(record.canonicalIdentity, FileMetadataFoundationService.pathFallbackCanonicalIdentity(for: destinationURL.path))
        XCTAssertNotNil(record.lastOrganizedAt)
        XCTAssertEqual(record.historyEntries.count, 1)

        let historyEntry = try XCTUnwrap(record.historyEntries.first)
        XCTAssertEqual(historyEntry.eventKind, .organized)
        XCTAssertEqual(historyEntry.sourceSurface, .organize)
        XCTAssertEqual(historyEntry.fromPath, sourceURL.path)
        XCTAssertEqual(historyEntry.toPath, destinationURL.path)
    }

    func testWorkflowTags_ApplyAndRemoveOnlyNewTemplateTags() throws {
        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let fileURL = try tempDirectory.createFile(name: "Inbox/invoice.pdf", contents: "invoice")
        let timestamp = Date(timeIntervalSince1970: 1_250)

        let record = try XCTUnwrap(
            environment.metadataService.upsertRecord(
                for: fileURL.path,
                displayName: fileURL.lastPathComponent,
                fileExtension: fileURL.pathExtension,
                timestamp: timestamp
            )
        )
        record.tags = ["finance"]
        try environment.context.save()

        let appendedTags = try environment.metadataService.applyWorkflowTags(
            path: fileURL.path,
            displayName: fileURL.lastPathComponent,
            fileExtension: fileURL.pathExtension,
            tags: ["finance", "receipt", "document"],
            timestamp: timestamp
        )

        XCTAssertEqual(appendedTags, ["receipt", "document"])
        XCTAssertEqual(record.tags, ["finance", "receipt", "document"])

        let removedTags = try environment.metadataService.removeWorkflowTags(
            path: fileURL.path,
            tags: appendedTags
        )

        XCTAssertEqual(removedTags, ["receipt", "document"])
        XCTAssertEqual(record.tags, ["finance"])
    }

    func testWorkflowTags_ApplyAndRemoveReuseSeededPathFallbackRecord() throws {
        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let fileURL = try tempDirectory.createFile(name: "Inbox/path-fallback.pdf", contents: "invoice")
        let timestamp = Date(timeIntervalSince1970: 1_255)

        let seededRecord = try insertPathFallbackRecord(
            in: environment.context,
            path: fileURL.path,
            displayName: fileURL.lastPathComponent,
            fileExtension: fileURL.pathExtension,
            timestamp: timestamp
        )
        seededRecord.tags = ["finance"]
        try environment.context.save()

        let appendedTags = try environment.metadataService.applyWorkflowTags(
            path: fileURL.path,
            displayName: fileURL.lastPathComponent,
            fileExtension: fileURL.pathExtension,
            tags: ["finance", "receipt"],
            timestamp: timestamp
        )

        XCTAssertEqual(appendedTags, ["receipt"])

        let recordsAfterApply = try environment.context.fetch(FetchDescriptor<FileMetadataRecord>())
        XCTAssertEqual(recordsAfterApply.count, 1)
        XCTAssertEqual(recordsAfterApply.first?.id, seededRecord.id)
        XCTAssertEqual(recordsAfterApply.first?.tags, ["finance", "receipt"])

        let removedTags = try environment.metadataService.removeWorkflowTags(
            path: fileURL.path,
            tags: appendedTags
        )

        XCTAssertEqual(removedTags, ["receipt"])

        let recordsAfterRemove = try environment.context.fetch(FetchDescriptor<FileMetadataRecord>())
        XCTAssertEqual(recordsAfterRemove.count, 1)
        XCTAssertEqual(recordsAfterRemove.first?.id, seededRecord.id)
        XCTAssertEqual(recordsAfterRemove.first?.tags, ["finance"])
    }

    func testWorkflowTags_RemoveRollsBackInMemoryMutationWhenSaveFails() throws {
        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let fileURL = try tempDirectory.createFile(name: "Inbox/tag-rollback.pdf", contents: "invoice")
        let timestamp = Date(timeIntervalSince1970: 1_260)

        let record = try XCTUnwrap(
            environment.metadataService.upsertRecord(
                for: fileURL.path,
                displayName: fileURL.lastPathComponent,
                fileExtension: fileURL.pathExtension,
                timestamp: timestamp
            )
        )
        record.tags = ["finance", "receipt"]
        try environment.context.save()

        FileMetadataFoundationService.debugWorkflowTagSaveHook = {
            throw InjectedMetadataFailure.workflowTagSaveFailure
        }
        defer {
            FileMetadataFoundationService.debugWorkflowTagSaveHook = nil
        }

        XCTAssertThrowsError(
            try environment.metadataService.removeWorkflowTags(
                path: fileURL.path,
                tags: ["receipt"]
            )
        )

        let refreshedRecord = try XCTUnwrap(
            environment.context.fetch(FetchDescriptor<FileMetadataRecord>()).first
        )
        XCTAssertEqual(refreshedRecord.tags, ["finance", "receipt"])
    }

    func testWorkflowTags_PathFallbackRowWinsWhenPathFallbackAndResourceBackedRowsSharePath() throws {
        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let fileURL = try tempDirectory.createFile(name: "Inbox/coexistence.pdf", contents: "invoice")
        let timestamp = Date(timeIntervalSince1970: 1_265)

        let resourceRecord = FileMetadataRecord(
            canonicalIdentity: "resource|volume-1|file-1",
            identityKind: .resourceIdentifier,
            lastKnownPath: fileURL.path,
            displayName: fileURL.lastPathComponent,
            fileExtension: fileURL.pathExtension,
            firstSeenAt: timestamp,
            lastSeenAt: timestamp,
            tags: ["scanned"]
        )
        environment.context.insert(resourceRecord)
        try environment.context.save()

        let pathFallbackRecord = try insertPathFallbackRecord(
            in: environment.context,
            path: fileURL.path,
            displayName: fileURL.lastPathComponent,
            fileExtension: fileURL.pathExtension,
            timestamp: timestamp
        )
        pathFallbackRecord.tags = ["finance"]
        try environment.context.save()

        let appendedTags = try environment.metadataService.applyWorkflowTags(
            path: fileURL.path,
            displayName: fileURL.lastPathComponent,
            fileExtension: fileURL.pathExtension,
            tags: ["finance", "receipt"],
            timestamp: timestamp
        )

        XCTAssertEqual(appendedTags, ["receipt"])
        XCTAssertEqual(pathFallbackRecord.tags, ["finance", "receipt"])
        XCTAssertEqual(resourceRecord.tags, ["scanned"])

        let removedTags = try environment.metadataService.removeWorkflowTags(
            path: fileURL.path,
            tags: appendedTags
        )

        XCTAssertEqual(removedTags, ["receipt"])
        XCTAssertEqual(pathFallbackRecord.tags, ["finance"])
        XCTAssertEqual(resourceRecord.tags, ["scanned"])
    }

    func testWorkflowMoveHelper_MovesFileWithoutTouchingGlobalUndoStack() async throws {
        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        let destinationFolder = try tempDirectory.createDirectory(name: "Archive")
        let sourceURL = try tempDirectory.createFile(name: "Inbox/workflow-move.pdf", contents: "move")
        let destination = try Destination.folder(from: destinationFolder, displayName: "Archive")
        let timestamp = Date(timeIntervalSince1970: 1_300)

        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 512,
            creationDate: timestamp,
            modificationDate: timestamp,
            lastAccessedDate: timestamp,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .pending
        )
        environment.context.insert(file)
        try environment.context.save()

        let moveResult = try await environment.coordinator.executeWorkflowMove(
            file,
            context: environment.context
        )

        let expectedDestinationPath = destinationFolder.appendingPathComponent(sourceURL.lastPathComponent).path
        XCTAssertEqual(moveResult.originalPath, sourceURL.path)
        XCTAssertEqual(moveResult.destinationPath, expectedDestinationPath)
        XCTAssertEqual(file.path, expectedDestinationPath)
        XCTAssertEqual(file.status, .completed)
        XCTAssertTrue(environment.coordinator.undoStack.isEmpty)
    }

    func testOrganizeFile_ProjectLikeRuleDestinationWritesProjectAssociation() async throws {
        FeatureFlagService.shared.setEnabled(.autoProjectAssociation, true)

        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        _ = try tempDirectory.createDirectory(name: "Projects")
        let alphaFolder = try tempDirectory.createDirectory(name: "Projects/Alpha")
        let sourceURL = sourceFolder.appendingPathComponent("brief.pdf")
        let initialTimestamp = Date(timeIntervalSince1970: 1_500)

        _ = try insertPathFallbackRecord(
            in: environment.context,
            path: sourceURL.path,
            displayName: "brief.pdf",
            fileExtension: "pdf",
            timestamp: initialTimestamp
        )

        _ = try tempDirectory.createFile(name: "Inbox/brief.pdf", contents: "brief")

        let destination = try Destination.folder(from: alphaFolder, displayName: alphaFolder.path)
        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 1_024,
            creationDate: initialTimestamp,
            modificationDate: initialTimestamp,
            lastAccessedDate: initialTimestamp,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .ready
        )
        environment.context.insert(file)
        try environment.context.save()

        let organizeExpectation = expectation(description: "organize success")
        await environment.coordinator.organizeFile(
            file,
            context: environment.context,
            sourceSurface: .reviewFlow,
            onSuccess: { _ in
                organizeExpectation.fulfill()
            },
            onError: { error in
                XCTFail("Organize should succeed: \(error)")
            }
        )
        await fulfillment(of: [organizeExpectation], timeout: 2.0)

        let records = try environment.context.fetch(FetchDescriptor<FileMetadataRecord>())
        let record = try XCTUnwrap(records.first(where: {
            $0.lastKnownPath == alphaFolder.appendingPathComponent("brief.pdf").path
        }))
        XCTAssertEqual(record.projectAssociation, "Alpha")
    }

    func testOrganizeFile_DestinationAliasAppendsContentTag() async throws {
        FeatureFlagService.shared.setEnabled(.autoContentTags, true)

        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        let destinationFolder = try tempDirectory.createDirectory(name: "Archive")
        let sourceURL = sourceFolder.appendingPathComponent("report.pdf")
        let initialTimestamp = Date(timeIntervalSince1970: 1_550)

        _ = try insertPathFallbackRecord(
            in: environment.context,
            path: sourceURL.path,
            displayName: "report.pdf",
            fileExtension: "pdf",
            timestamp: initialTimestamp
        )

        _ = try tempDirectory.createFile(name: "Inbox/report.pdf", contents: "report")

        let destination = try Destination.folder(from: destinationFolder, displayName: "Invoices")
        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 1_024,
            creationDate: initialTimestamp,
            modificationDate: initialTimestamp,
            lastAccessedDate: initialTimestamp,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .ready
        )
        environment.context.insert(file)
        try environment.context.save()

        let organizeExpectation = expectation(description: "organize success")
        await environment.coordinator.organizeFile(
            file,
            context: environment.context,
            sourceSurface: .reviewFlow,
            onSuccess: { _ in
                organizeExpectation.fulfill()
            },
            onError: { error in
                XCTFail("Organize should succeed: \(error)")
            }
        )
        await fulfillment(of: [organizeExpectation], timeout: 2.0)

        let record = try XCTUnwrap(try environment.context.fetch(FetchDescriptor<FileMetadataRecord>()).first)
        XCTAssertEqual(record.tags, ["invoice"])
    }

    func testOrganizeFile_WritesDurableWorkflowStatusOrganized() async throws {
        FeatureFlagService.shared.setEnabled(.durableWorkflowStatus, true)
        FeatureFlagService.shared.setEnabled(.autoProjectAssociation, true)
        FeatureFlagService.shared.setEnabled(.autoContentTags, true)

        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        _ = try tempDirectory.createDirectory(name: "Projects")
        let projectFolder = try tempDirectory.createDirectory(name: "Projects/Alpha")
        let sourceURL = sourceFolder.appendingPathComponent("brief.pdf")
        let destinationURL = projectFolder.appendingPathComponent("brief.pdf")
        let initialTimestamp = Date(timeIntervalSince1970: 1_560)

        let seededRecord = try insertPathFallbackRecord(
            in: environment.context,
            path: sourceURL.path,
            displayName: "brief.pdf",
            fileExtension: "pdf",
            timestamp: initialTimestamp
        )
        let seededRecordID = seededRecord.persistentModelID
        seededRecord.projectAssociation = "Alpha"
        seededRecord.tags = ["invoice"]
        try environment.context.save()

        _ = try tempDirectory.createFile(name: "Inbox/brief.pdf", contents: "brief")

        let destination = try Destination.folder(from: projectFolder, displayName: projectFolder.path)
        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 1_024,
            creationDate: initialTimestamp,
            modificationDate: initialTimestamp,
            lastAccessedDate: initialTimestamp,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .ready
        )
        environment.context.insert(file)
        try environment.context.save()

        let organizeExpectation = expectation(description: "organize success")
        await environment.coordinator.organizeFile(
            file,
            context: environment.context,
            sourceSurface: .reviewFlow,
            onSuccess: { _ in
                organizeExpectation.fulfill()
            },
            onError: { error in
                XCTFail("Organize should succeed: \(error)")
            }
        )
        await fulfillment(of: [organizeExpectation], timeout: 2.0)

        let records = try environment.context.fetch(FetchDescriptor<FileMetadataRecord>())
        XCTAssertEqual(records.count, 1)

        let record = try XCTUnwrap(records.first)
        XCTAssertEqual(record.persistentModelID, seededRecordID)
        XCTAssertEqual(record.lastKnownPath, destinationURL.path)
        XCTAssertEqual(record.workflowStatus, .organized)
        XCTAssertEqual(record.projectAssociation, "Alpha")
        XCTAssertEqual(record.tags, ["invoice"])
        XCTAssertEqual(record.historyEntries.count, 1)
    }

    func testUndoLastAction_RekeysPathFallbackRecordAndAppendsUndoHistory() async throws {
        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        let destinationFolder = try tempDirectory.createDirectory(name: "Archive")
        let sourceURL = sourceFolder.appendingPathComponent("invoice.pdf")
        let destinationURL = destinationFolder.appendingPathComponent("invoice.pdf")
        let initialTimestamp = Date(timeIntervalSince1970: 2_000)

        _ = try insertPathFallbackRecord(
            in: environment.context,
            path: sourceURL.path,
            displayName: "invoice.pdf",
            fileExtension: "pdf",
            timestamp: initialTimestamp
        )

        _ = try tempDirectory.createFile(name: "Inbox/invoice.pdf", contents: "invoice")

        let destination = try Destination.folder(from: destinationURL.deletingLastPathComponent(), displayName: "Archive")
        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 1_024,
            creationDate: initialTimestamp,
            modificationDate: initialTimestamp,
            lastAccessedDate: initialTimestamp,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .ready
        )
        environment.context.insert(file)
        try environment.context.save()

        let organizeExpectation = expectation(description: "organize success")
        await environment.coordinator.organizeFile(
            file,
            context: environment.context,
            sourceSurface: .reviewFlow,
            onSuccess: { _ in
                organizeExpectation.fulfill()
            },
            onError: { error in
                XCTFail("Organize should succeed: \(error)")
            }
        )
        await fulfillment(of: [organizeExpectation], timeout: 2.0)

        let organizedRecords = try environment.context.fetch(FetchDescriptor<FileMetadataRecord>())
        let organizedRecord = try XCTUnwrap(organizedRecords.first)
        let lastOrganizedAtBeforeUndo = try XCTUnwrap(organizedRecord.lastOrganizedAt)
        XCTAssertEqual(organizedRecord.organizationCount, 1)

        var undoCompleted = false
        environment.coordinator.undoLastAction(allFiles: [file], context: environment.context) {
            undoCompleted = true
        }
        XCTAssertTrue(undoCompleted)

        let records = try environment.context.fetch(FetchDescriptor<FileMetadataRecord>())
        XCTAssertEqual(records.count, 1)

        let record = try XCTUnwrap(records.first)
        XCTAssertEqual(record.lastKnownPath, sourceURL.path)
        XCTAssertEqual(record.latestOrganizationStatus, .undone)
        XCTAssertEqual(record.canonicalIdentity, FileMetadataFoundationService.pathFallbackCanonicalIdentity(for: sourceURL.path))
        XCTAssertEqual(record.organizationCount, 1)
        XCTAssertEqual(record.lastOrganizedAt, lastOrganizedAtBeforeUndo)
        XCTAssertEqual(record.historyEntries.count, 2)

        let orderedHistory = record.historyEntries.sorted { $0.timestamp < $1.timestamp }
        let organizedEntry = try XCTUnwrap(orderedHistory.first)
        let undoEntry = try XCTUnwrap(orderedHistory.last)

        XCTAssertEqual(organizedEntry.eventKind, .organized)
        XCTAssertEqual(organizedEntry.sourceSurface, .organize)
        XCTAssertEqual(undoEntry.eventKind, .undone)
        XCTAssertEqual(undoEntry.sourceSurface, .undo)
        XCTAssertEqual(undoEntry.fromPath, destinationURL.path)
        XCTAssertEqual(undoEntry.toPath, sourceURL.path)
    }

    func testUndoOrganize_WritesDurableWorkflowStatusRecovered() async throws {
        FeatureFlagService.shared.setEnabled(.durableWorkflowStatus, true)
        FeatureFlagService.shared.setEnabled(.autoProjectAssociation, true)
        FeatureFlagService.shared.setEnabled(.autoContentTags, true)

        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        _ = try tempDirectory.createDirectory(name: "Projects")
        let projectFolder = try tempDirectory.createDirectory(name: "Projects/Beta")
        let sourceURL = sourceFolder.appendingPathComponent("proposal.pdf")
        let initialTimestamp = Date(timeIntervalSince1970: 2_025)

        let seededRecord = try insertPathFallbackRecord(
            in: environment.context,
            path: sourceURL.path,
            displayName: "proposal.pdf",
            fileExtension: "pdf",
            timestamp: initialTimestamp
        )
        let seededRecordID = seededRecord.persistentModelID
        seededRecord.projectAssociation = "Beta"
        seededRecord.tags = ["invoice"]
        try environment.context.save()

        _ = try tempDirectory.createFile(name: "Inbox/proposal.pdf", contents: "proposal")

        let destination = try Destination.folder(from: projectFolder, displayName: projectFolder.path)
        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 1_024,
            creationDate: initialTimestamp,
            modificationDate: initialTimestamp,
            lastAccessedDate: initialTimestamp,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .ready
        )
        environment.context.insert(file)
        try environment.context.save()

        let organizeExpectation = expectation(description: "organize success")
        await environment.coordinator.organizeFile(
            file,
            context: environment.context,
            sourceSurface: .reviewFlow,
            onSuccess: { _ in
                organizeExpectation.fulfill()
            },
            onError: { error in
                XCTFail("Organize should succeed: \(error)")
            }
        )
        await fulfillment(of: [organizeExpectation], timeout: 2.0)

        var undoCompleted = false
        environment.coordinator.undoLastAction(allFiles: [file], context: environment.context) {
            undoCompleted = true
        }
        XCTAssertTrue(undoCompleted)

        let records = try environment.context.fetch(FetchDescriptor<FileMetadataRecord>())
        XCTAssertEqual(records.count, 1)

        let record = try XCTUnwrap(records.first)
        XCTAssertEqual(record.persistentModelID, seededRecordID)
        XCTAssertEqual(record.lastKnownPath, sourceURL.path)
        XCTAssertEqual(record.workflowStatus, .recovered)
        XCTAssertEqual(record.projectAssociation, "Beta")
        XCTAssertEqual(record.tags, ["invoice"])
        XCTAssertEqual(record.historyEntries.count, 2)
    }

    func testUndoLastAction_PreservesProjectAssociationAfterProjectMove() async throws {
        FeatureFlagService.shared.setEnabled(.autoProjectAssociation, true)

        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        _ = try tempDirectory.createDirectory(name: "Projects")
        let betaFolder = try tempDirectory.createDirectory(name: "Projects/Beta")
        let sourceURL = sourceFolder.appendingPathComponent("proposal.pdf")
        let initialTimestamp = Date(timeIntervalSince1970: 2_050)

        _ = try insertPathFallbackRecord(
            in: environment.context,
            path: sourceURL.path,
            displayName: "proposal.pdf",
            fileExtension: "pdf",
            timestamp: initialTimestamp
        )

        _ = try tempDirectory.createFile(name: "Inbox/proposal.pdf", contents: "proposal")

        let destination = try Destination.folder(from: betaFolder, displayName: betaFolder.path)
        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 1_024,
            creationDate: initialTimestamp,
            modificationDate: initialTimestamp,
            lastAccessedDate: initialTimestamp,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .ready
        )
        environment.context.insert(file)
        try environment.context.save()

        let organizeExpectation = expectation(description: "organize success")
        await environment.coordinator.organizeFile(
            file,
            context: environment.context,
            sourceSurface: .reviewFlow,
            onSuccess: { _ in
                organizeExpectation.fulfill()
            },
            onError: { error in
                XCTFail("Organize should succeed: \(error)")
            }
        )
        await fulfillment(of: [organizeExpectation], timeout: 2.0)

        var undoCompleted = false
        environment.coordinator.undoLastAction(allFiles: [file], context: environment.context) {
            undoCompleted = true
        }
        XCTAssertTrue(undoCompleted)

        let records = try environment.context.fetch(FetchDescriptor<FileMetadataRecord>())
        let record = try XCTUnwrap(records.first)
        XCTAssertEqual(record.lastKnownPath, sourceURL.path)
        XCTAssertEqual(record.projectAssociation, "Beta")
    }

    func testUndoLastAction_PreservesContentTags() async throws {
        FeatureFlagService.shared.setEnabled(.autoContentTags, true)

        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        let destinationFolder = try tempDirectory.createDirectory(name: "Archive")
        let sourceURL = sourceFolder.appendingPathComponent("report.pdf")
        let initialTimestamp = Date(timeIntervalSince1970: 2_060)

        _ = try insertPathFallbackRecord(
            in: environment.context,
            path: sourceURL.path,
            displayName: "report.pdf",
            fileExtension: "pdf",
            timestamp: initialTimestamp
        )

        _ = try tempDirectory.createFile(name: "Inbox/report.pdf", contents: "report")

        let destination = try Destination.folder(from: destinationFolder, displayName: "Invoices")
        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 1_024,
            creationDate: initialTimestamp,
            modificationDate: initialTimestamp,
            lastAccessedDate: initialTimestamp,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .ready
        )
        environment.context.insert(file)
        try environment.context.save()

        let organizeExpectation = expectation(description: "organize success")
        await environment.coordinator.organizeFile(
            file,
            context: environment.context,
            sourceSurface: .reviewFlow,
            onSuccess: { _ in
                organizeExpectation.fulfill()
            },
            onError: { error in
                XCTFail("Organize should succeed: \(error)")
            }
        )
        await fulfillment(of: [organizeExpectation], timeout: 2.0)

        let tagsBeforeUndo = try XCTUnwrap(
            try environment.context.fetch(FetchDescriptor<FileMetadataRecord>()).first?.tags
        )
        XCTAssertEqual(tagsBeforeUndo, ["invoice"])

        var undoCompleted = false
        environment.coordinator.undoLastAction(allFiles: [file], context: environment.context) {
            undoCompleted = true
        }
        XCTAssertTrue(undoCompleted)

        let record = try XCTUnwrap(try environment.context.fetch(FetchDescriptor<FileMetadataRecord>()).first)
        XCTAssertEqual(record.tags, tagsBeforeUndo)
    }

    func testRedoLastAction_UpdatesMetadataRecordAfterUndoForSingleMove() async throws {
        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        let destinationFolder = try tempDirectory.createDirectory(name: "Archive")
        let sourceURL = sourceFolder.appendingPathComponent("redo.pdf")
        let destinationURL = destinationFolder.appendingPathComponent("redo.pdf")
        let initialTimestamp = Date(timeIntervalSince1970: 2_100)

        _ = try insertPathFallbackRecord(
            in: environment.context,
            path: sourceURL.path,
            displayName: "redo.pdf",
            fileExtension: "pdf",
            timestamp: initialTimestamp
        )

        _ = try tempDirectory.createFile(name: "Inbox/redo.pdf", contents: "redo")

        let destination = try Destination.folder(from: destinationURL.deletingLastPathComponent(), displayName: "Archive")
        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 1_024,
            creationDate: initialTimestamp,
            modificationDate: initialTimestamp,
            lastAccessedDate: initialTimestamp,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .ready
        )
        environment.context.insert(file)
        try environment.context.save()

        let organizeExpectation = expectation(description: "organize success")
        await environment.coordinator.organizeFile(
            file,
            context: environment.context,
            sourceSurface: .reviewFlow,
            onSuccess: { _ in
                organizeExpectation.fulfill()
            },
            onError: { error in
                XCTFail("Organize should succeed: \(error)")
            }
        )
        await fulfillment(of: [organizeExpectation], timeout: 2.0)

        var undoCompleted = false
        environment.coordinator.undoLastAction(allFiles: [file], context: environment.context) {
            undoCompleted = true
        }
        XCTAssertTrue(undoCompleted)

        var redoCompleted = false
        await environment.coordinator.redoLastAction(allFiles: [file], context: environment.context) {
            redoCompleted = true
        }
        XCTAssertTrue(redoCompleted)

        let records = try environment.context.fetch(FetchDescriptor<FileMetadataRecord>())
        XCTAssertEqual(records.count, 1)

        let record = try XCTUnwrap(records.first)
        XCTAssertEqual(record.lastKnownPath, destinationURL.path)
        XCTAssertEqual(record.latestOrganizationStatus, .organized)
        XCTAssertEqual(record.organizationCount, 2)
        XCTAssertEqual(record.historyEntries.count, 3)

        let orderedHistory = record.historyEntries.sorted { $0.timestamp < $1.timestamp }
        XCTAssertEqual(orderedHistory.map(\.eventKind), [.organized, .undone, .organized])
        XCTAssertEqual(orderedHistory.map(\.sourceSurface), [.organize, .undo, .organize])
        XCTAssertEqual(orderedHistory.first?.fromPath, sourceURL.path)
        XCTAssertEqual(orderedHistory.first?.toPath, destinationURL.path)
        XCTAssertEqual(orderedHistory.last?.fromPath, sourceURL.path)
        XCTAssertEqual(orderedHistory.last?.toPath, destinationURL.path)
    }

    func testRedoOrganize_RestoresDurableWorkflowStatusOrganized() async throws {
        FeatureFlagService.shared.setEnabled(.durableWorkflowStatus, true)
        FeatureFlagService.shared.setEnabled(.autoProjectAssociation, true)
        FeatureFlagService.shared.setEnabled(.autoContentTags, true)

        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        _ = try tempDirectory.createDirectory(name: "Projects")
        let projectFolder = try tempDirectory.createDirectory(name: "Projects/Gamma")
        let sourceURL = sourceFolder.appendingPathComponent("redo.pdf")
        let destinationURL = projectFolder.appendingPathComponent("redo.pdf")
        let initialTimestamp = Date(timeIntervalSince1970: 2_125)

        let seededRecord = try insertPathFallbackRecord(
            in: environment.context,
            path: sourceURL.path,
            displayName: "redo.pdf",
            fileExtension: "pdf",
            timestamp: initialTimestamp
        )
        let seededRecordID = seededRecord.persistentModelID
        seededRecord.projectAssociation = "Gamma"
        seededRecord.tags = ["invoice"]
        try environment.context.save()

        _ = try tempDirectory.createFile(name: "Inbox/redo.pdf", contents: "redo")

        let destination = try Destination.folder(from: projectFolder, displayName: projectFolder.path)
        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 1_024,
            creationDate: initialTimestamp,
            modificationDate: initialTimestamp,
            lastAccessedDate: initialTimestamp,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .ready
        )
        environment.context.insert(file)
        try environment.context.save()

        let organizeExpectation = expectation(description: "organize success")
        await environment.coordinator.organizeFile(
            file,
            context: environment.context,
            sourceSurface: .reviewFlow,
            onSuccess: { _ in
                organizeExpectation.fulfill()
            },
            onError: { error in
                XCTFail("Organize should succeed: \(error)")
            }
        )
        await fulfillment(of: [organizeExpectation], timeout: 2.0)

        var undoCompleted = false
        environment.coordinator.undoLastAction(allFiles: [file], context: environment.context) {
            undoCompleted = true
        }
        XCTAssertTrue(undoCompleted)

        var redoCompleted = false
        await environment.coordinator.redoLastAction(allFiles: [file], context: environment.context) {
            redoCompleted = true
        }
        XCTAssertTrue(redoCompleted)

        let records = try environment.context.fetch(FetchDescriptor<FileMetadataRecord>())
        XCTAssertEqual(records.count, 1)

        let record = try XCTUnwrap(records.first)
        XCTAssertEqual(record.persistentModelID, seededRecordID)
        XCTAssertEqual(record.lastKnownPath, destinationURL.path)
        XCTAssertEqual(record.workflowStatus, .organized)
        XCTAssertEqual(record.projectAssociation, "Gamma")
        XCTAssertEqual(record.tags, ["invoice"])
        XCTAssertEqual(record.historyEntries.count, 3)
    }

    func testSkipFile_WithContext_WritesIgnoredWorkflowStatusAndHistory() async throws {
        FeatureFlagService.shared.setEnabled(.durableWorkflowStatus, true)

        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        let sourceURL = sourceFolder.appendingPathComponent("ignored.pdf")
        let initialTimestamp = Date(timeIntervalSince1970: 2_150)

        let seededRecord = try insertPathFallbackRecord(
            in: environment.context,
            path: sourceURL.path,
            displayName: "ignored.pdf",
            fileExtension: "pdf",
            timestamp: initialTimestamp
        )
        seededRecord.workflowStatus = .queued
        try environment.context.save()

        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 1_024,
            creationDate: initialTimestamp,
            modificationDate: initialTimestamp,
            lastAccessedDate: initialTimestamp,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: .mockFolder("Archive"),
            status: .ready
        )
        environment.context.insert(file)
        try environment.context.save()

        environment.coordinator.skipFile(file, context: environment.context)

        let record = try XCTUnwrap(try environment.context.fetch(FetchDescriptor<FileMetadataRecord>()).first)
        XCTAssertEqual(file.status, .skipped)
        XCTAssertEqual(record.workflowStatus, .ignored)
        XCTAssertEqual(record.historyEntries.count, 1)
        XCTAssertEqual(record.historyEntries.first?.eventKind, .ignored)
        XCTAssertEqual(record.historyEntries.first?.sourceSurface, .review)
    }

    func testUndoSkip_WithContext_RestoresPreviousWorkflowStatus() async throws {
        FeatureFlagService.shared.setEnabled(.durableWorkflowStatus, true)

        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        let sourceURL = sourceFolder.appendingPathComponent("undo-skip.pdf")
        let initialTimestamp = Date(timeIntervalSince1970: 2_151)

        let seededRecord = try insertPathFallbackRecord(
            in: environment.context,
            path: sourceURL.path,
            displayName: "undo-skip.pdf",
            fileExtension: "pdf",
            timestamp: initialTimestamp
        )
        seededRecord.workflowStatus = .queued
        try environment.context.save()

        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 1_024,
            creationDate: initialTimestamp,
            modificationDate: initialTimestamp,
            lastAccessedDate: initialTimestamp,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: .mockFolder("Archive"),
            status: .ready
        )
        environment.context.insert(file)
        try environment.context.save()

        environment.coordinator.skipFile(file, context: environment.context)

        var undoCompleted = false
        environment.coordinator.undoLastAction(allFiles: [file], context: environment.context) {
            undoCompleted = true
        }
        XCTAssertTrue(undoCompleted)

        let record = try XCTUnwrap(try environment.context.fetch(FetchDescriptor<FileMetadataRecord>()).first)
        XCTAssertEqual(file.status, .ready)
        XCTAssertEqual(record.workflowStatus, .queued)
        XCTAssertEqual(record.historyEntries.count, 1)
        XCTAssertEqual(record.historyEntries.first?.eventKind, .ignored)
    }

    func testRedoSkip_WithContext_DoesNotDuplicateIgnoredHistory() async throws {
        FeatureFlagService.shared.setEnabled(.durableWorkflowStatus, true)

        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        let sourceURL = sourceFolder.appendingPathComponent("redo-skip.pdf")
        let initialTimestamp = Date(timeIntervalSince1970: 2_152)

        let seededRecord = try insertPathFallbackRecord(
            in: environment.context,
            path: sourceURL.path,
            displayName: "redo-skip.pdf",
            fileExtension: "pdf",
            timestamp: initialTimestamp
        )
        seededRecord.workflowStatus = .queued
        try environment.context.save()

        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 1_024,
            creationDate: initialTimestamp,
            modificationDate: initialTimestamp,
            lastAccessedDate: initialTimestamp,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: .mockFolder("Archive"),
            status: .ready
        )
        environment.context.insert(file)
        try environment.context.save()

        environment.coordinator.skipFile(file, context: environment.context)
        environment.coordinator.undoLastAction(allFiles: [file], context: environment.context) {}
        await environment.coordinator.redoLastAction(allFiles: [file], context: environment.context) {}

        let record = try XCTUnwrap(try environment.context.fetch(FetchDescriptor<FileMetadataRecord>()).first)
        XCTAssertEqual(file.status, .skipped)
        XCTAssertEqual(record.workflowStatus, .ignored)
        XCTAssertEqual(record.historyEntries.count, 1)
        XCTAssertEqual(record.historyEntries.first?.eventKind, .ignored)
    }

    func testSkipFile_MetadataWriteFailureFallsBackToTransientSkip() async throws {
        FeatureFlagService.shared.setEnabled(.durableWorkflowStatus, true)

        let schema = Schema([FileItem.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let coordinator = FileOrganizationCoordinator()

        let file = FileItem(
            path: "/tmp/transient-skip.pdf",
            sizeInBytes: 1_024,
            creationDate: Date(timeIntervalSince1970: 2_153),
            destination: .mockFolder("Archive"),
            status: .ready
        )
        context.insert(file)
        try context.save()

        coordinator.skipFile(file, context: context)

        XCTAssertEqual(file.status, .skipped)

        var undoCompleted = false
        coordinator.undoLastAction(allFiles: [file], context: context) {
            undoCompleted = true
        }
        XCTAssertTrue(undoCompleted)
        XCTAssertEqual(file.status, .ready)
    }

    func testSkipFile_MainContextSaveFailureRollsBackDurableMetadataAndFallsBackToTransientSkip() async throws {
        FeatureFlagService.shared.setEnabled(.durableWorkflowStatus, true)

        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        let sourceURL = sourceFolder.appendingPathComponent("rollback-skip.pdf")
        let initialTimestamp = Date(timeIntervalSince1970: 2_154)

        let seededRecord = try insertPathFallbackRecord(
            in: environment.context,
            path: sourceURL.path,
            displayName: "rollback-skip.pdf",
            fileExtension: "pdf",
            timestamp: initialTimestamp
        )
        seededRecord.workflowStatus = .queued
        try environment.context.save()

        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 1_024,
            creationDate: initialTimestamp,
            modificationDate: initialTimestamp,
            lastAccessedDate: initialTimestamp,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: .mockFolder("Archive"),
            status: .ready
        )
        environment.context.insert(file)
        try environment.context.save()

        environment.coordinator.metadataSkipSaveHook = {
            throw InjectedMetadataFailure.skipMainContextSaveFailure
        }

        let didSkip = environment.coordinator.skipFile(file, context: environment.context)

        XCTAssertTrue(didSkip)
        XCTAssertEqual(file.status, .skipped)

        let record = try XCTUnwrap(try environment.context.fetch(FetchDescriptor<FileMetadataRecord>()).first)
        XCTAssertEqual(record.workflowStatus, .queued)
        XCTAssertTrue(record.historyEntries.isEmpty)

        var undoCompleted = false
        environment.coordinator.undoLastAction(allFiles: [file], context: environment.context) {
            undoCompleted = true
        }
        XCTAssertTrue(undoCompleted)
        XCTAssertEqual(file.status, .ready)

        let persistedAfterUndo = try XCTUnwrap(try environment.context.fetch(FetchDescriptor<FileMetadataRecord>()).first)
        XCTAssertEqual(persistedAfterUndo.workflowStatus, .queued)
        XCTAssertTrue(persistedAfterUndo.historyEntries.isEmpty)
    }

    func testOrganizeUndoRedo_DestinationCollisionPreservesSourceIdentityWorkflowStatusAssociationAndTagOrdering() async throws {
        FeatureFlagService.shared.setEnabled(.durableWorkflowStatus, true)
        FeatureFlagService.shared.setEnabled(.autoProjectAssociation, true)

        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        _ = try tempDirectory.createDirectory(name: "Projects")
        let projectFolder = try tempDirectory.createDirectory(name: "Projects/Delta")
        let sourceURL = sourceFolder.appendingPathComponent("invoice.txt")
        let destinationURL = projectFolder.appendingPathComponent("invoice.txt")
        let sourceTimestamp = Date(timeIntervalSince1970: 2_200)
        let destinationTimestamp = Date(timeIntervalSince1970: 2_210)

        let sourceRecord = try insertPathFallbackRecord(
            in: environment.context,
            path: sourceURL.path,
            displayName: "invoice.txt",
            fileExtension: "txt",
            timestamp: sourceTimestamp
        )
        let sourceRecordID = sourceRecord.persistentModelID
        sourceRecord.tags = ["Invoices", "legacy-source"]

        let destinationRecord = try insertPathFallbackRecord(
            in: environment.context,
            path: destinationURL.path,
            displayName: "invoice.txt",
            fileExtension: "txt",
            timestamp: destinationTimestamp
        )
        destinationRecord.projectAssociation = "Delta"
        destinationRecord.tags = ["receipt", "legacy-target"]
        try environment.context.save()

        _ = try tempDirectory.createFile(name: "Inbox/invoice.txt", contents: "invoice")

        let destination = try Destination.folder(from: projectFolder, displayName: projectFolder.path)
        let file = FileItem(
            path: sourceURL.path,
            sizeInBytes: 1_024,
            creationDate: sourceTimestamp,
            modificationDate: sourceTimestamp,
            lastAccessedDate: sourceTimestamp,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .ready
        )
        environment.context.insert(file)
        try environment.context.save()

        let organizeExpectation = expectation(description: "organize success")
        await environment.coordinator.organizeFile(
            file,
            context: environment.context,
            sourceSurface: .reviewFlow,
            onSuccess: { _ in
                organizeExpectation.fulfill()
            },
            onError: { error in
                XCTFail("Organize should succeed: \(error)")
            }
        )
        await fulfillment(of: [organizeExpectation], timeout: 2.0)

        var record = try XCTUnwrap(try environment.context.fetch(FetchDescriptor<FileMetadataRecord>()).first)
        XCTAssertEqual(record.persistentModelID, sourceRecordID)
        XCTAssertEqual(record.lastKnownPath, destinationURL.path)
        XCTAssertEqual(record.workflowStatus, .organized)
        XCTAssertEqual(record.projectAssociation, "Delta")
        XCTAssertEqual(
            record.tags,
            ["receipt", "legacy-target", "Invoices", "legacy-source"]
        )
        XCTAssertEqual(record.historyEntries.count, 1)

        var undoCompleted = false
        environment.coordinator.undoLastAction(allFiles: [file], context: environment.context) {
            undoCompleted = true
        }
        XCTAssertTrue(undoCompleted)

        record = try XCTUnwrap(try environment.context.fetch(FetchDescriptor<FileMetadataRecord>()).first)
        XCTAssertEqual(record.persistentModelID, sourceRecordID)
        XCTAssertEqual(record.lastKnownPath, sourceURL.path)
        XCTAssertEqual(record.workflowStatus, .recovered)
        XCTAssertEqual(record.projectAssociation, "Delta")
        XCTAssertEqual(
            record.tags,
            ["receipt", "legacy-target", "Invoices", "legacy-source"]
        )
        XCTAssertEqual(record.historyEntries.count, 2)

        var redoCompleted = false
        await environment.coordinator.redoLastAction(allFiles: [file], context: environment.context) {
            redoCompleted = true
        }
        XCTAssertTrue(redoCompleted)

        record = try XCTUnwrap(try environment.context.fetch(FetchDescriptor<FileMetadataRecord>()).first)
        XCTAssertEqual(record.persistentModelID, sourceRecordID)
        XCTAssertEqual(record.lastKnownPath, destinationURL.path)
        XCTAssertEqual(record.workflowStatus, .organized)
        XCTAssertEqual(record.projectAssociation, "Delta")
        XCTAssertEqual(
            record.tags,
            ["receipt", "legacy-target", "Invoices", "legacy-source"]
        )
        XCTAssertEqual(record.historyEntries.count, 3)

        let orderedHistory = record.historyEntries.sorted { $0.timestamp < $1.timestamp }
        XCTAssertEqual(orderedHistory.map(\.eventKind), [.organized, .undone, .organized])
    }

    func testUndoLastAction_BulkUndoContinuesAfterMetadataWriteFailure() async throws {
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        let destinationFolder = try tempDirectory.createDirectory(name: "Archive")
        let firstSourceURL = sourceFolder.appendingPathComponent("first.pdf")
        let secondSourceURL = sourceFolder.appendingPathComponent("second.pdf")
        let timestamp = Date(timeIntervalSince1970: 2_500)
        let unrelatedActivity = ActivityItem(
            activityType: .fileScanned,
            fileName: "unrelated.txt",
            details: "original"
        )

        let environment = try makeEnvironment()

        _ = try insertPathFallbackRecord(
            in: environment.context,
            path: firstSourceURL.path,
            displayName: "first.pdf",
            fileExtension: "pdf",
            timestamp: timestamp
        )
        _ = try insertPathFallbackRecord(
            in: environment.context,
            path: secondSourceURL.path,
            displayName: "second.pdf",
            fileExtension: "pdf",
            timestamp: timestamp
        )
        environment.context.insert(unrelatedActivity)

        FileMetadataFoundationService.debugRecordTransitionHook = { sourcePath, _, eventKind in
            if eventKind == .undone, sourcePath == firstSourceURL.path {
                throw InjectedMetadataFailure.transitionWriteFailure
            }
        }
        defer {
            FileMetadataFoundationService.debugRecordTransitionHook = nil
        }

        _ = try tempDirectory.createFile(name: "Inbox/first.pdf", contents: "first")
        _ = try tempDirectory.createFile(name: "Inbox/second.pdf", contents: "second")

        let destination = try Destination.folder(from: destinationFolder, displayName: "Archive")
        let firstFile = FileItem(
            path: firstSourceURL.path,
            sizeInBytes: 1_024,
            creationDate: timestamp,
            modificationDate: timestamp,
            lastAccessedDate: timestamp,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .ready
        )
        let secondFile = FileItem(
            path: secondSourceURL.path,
            sizeInBytes: 1_024,
            creationDate: timestamp,
            modificationDate: timestamp,
            lastAccessedDate: timestamp,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .ready
        )
        environment.context.insert(firstFile)
        environment.context.insert(secondFile)
        try environment.context.save()

        let organizeExpectation = expectation(description: "bulk organize success")
        await environment.coordinator.organizeMultipleFiles(
            [firstFile, secondFile],
            origin: .automation,
            context: environment.context
        ) { success, failed, _, error in
            XCTAssertEqual(success, 2)
            XCTAssertEqual(failed, 0)
            XCTAssertNil(error)
            organizeExpectation.fulfill()
        }
        await fulfillment(of: [organizeExpectation], timeout: 2.0)

        var undoCompleted = false
        environment.coordinator.undoLastAction(allFiles: [firstFile, secondFile], context: environment.context) {
            undoCompleted = true
        }
        XCTAssertTrue(undoCompleted)

        let records = try environment.context.fetch(FetchDescriptor<FileMetadataRecord>())
        XCTAssertEqual(records.count, 2)

        let firstRecordIdentity = FileMetadataFoundationService.pathFallbackCanonicalIdentity(for: firstSourceURL.path)
        let secondRecordIdentity = FileMetadataFoundationService.pathFallbackCanonicalIdentity(for: secondSourceURL.path)
        let recordDetails = records
            .map { "\($0.canonicalIdentity) | \($0.lastKnownPath) | \($0.latestOrganizationStatus.rawValue) | \($0.historyEntries.count)" }
            .joined(separator: "\n")

        guard let firstRecord = records.first(where: { $0.canonicalIdentity == firstRecordIdentity }) else {
            XCTFail("Missing first record for identity \(firstRecordIdentity). Records:\n\(recordDetails)")
            return
        }
        guard let secondRecord = records.first(where: { $0.canonicalIdentity == secondRecordIdentity }) else {
            XCTFail("Missing second record for identity \(secondRecordIdentity). Records:\n\(recordDetails)")
            return
        }

        XCTAssertEqual(firstRecord.lastKnownPath, firstSourceURL.path)
        XCTAssertEqual(firstRecord.historyEntries.count, 2)
        XCTAssertEqual(firstRecord.latestOrganizationStatus, .undone)
        XCTAssertEqual(firstRecord.historyEntries.sorted(by: { $0.timestamp < $1.timestamp }).last?.eventKind, .undone)

        XCTAssertEqual(secondRecord.lastKnownPath, secondSourceURL.path)
        XCTAssertEqual(secondRecord.historyEntries.count, 2)
        XCTAssertEqual(secondRecord.latestOrganizationStatus, .undone)
        XCTAssertEqual(secondRecord.historyEntries.sorted(by: { $0.timestamp < $1.timestamp }).last?.eventKind, .undone)

        try environment.context.save()
        let unrelatedActivities = try environment.context.fetch(
            FetchDescriptor<ActivityItem>(
                predicate: #Predicate<ActivityItem> { $0.fileName == "unrelated.txt" }
            )
        )
        XCTAssertEqual(unrelatedActivities.count, 1)
        XCTAssertEqual(unrelatedActivities.first?.details, "original")
    }

    func testRedoLastAction_UpdatesMetadataRecordsAfterUndoForBulkMove() async throws {
        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        let destinationFolder = try tempDirectory.createDirectory(name: "Archive")
        let firstSourceURL = sourceFolder.appendingPathComponent("bulk-first.pdf")
        let secondSourceURL = sourceFolder.appendingPathComponent("bulk-second.pdf")
        let firstDestinationURL = destinationFolder.appendingPathComponent("bulk-first.pdf")
        let secondDestinationURL = destinationFolder.appendingPathComponent("bulk-second.pdf")
        let timestamp = Date(timeIntervalSince1970: 2_600)

        _ = try insertPathFallbackRecord(
            in: environment.context,
            path: firstSourceURL.path,
            displayName: "bulk-first.pdf",
            fileExtension: "pdf",
            timestamp: timestamp
        )
        _ = try insertPathFallbackRecord(
            in: environment.context,
            path: secondSourceURL.path,
            displayName: "bulk-second.pdf",
            fileExtension: "pdf",
            timestamp: timestamp
        )

        _ = try tempDirectory.createFile(name: "Inbox/bulk-first.pdf", contents: "bulk-first")
        _ = try tempDirectory.createFile(name: "Inbox/bulk-second.pdf", contents: "bulk-second")

        let destination = try Destination.folder(from: destinationFolder, displayName: "Archive")
        let firstFile = FileItem(
            path: firstSourceURL.path,
            sizeInBytes: 1_024,
            creationDate: timestamp,
            modificationDate: timestamp,
            lastAccessedDate: timestamp,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .ready
        )
        let secondFile = FileItem(
            path: secondSourceURL.path,
            sizeInBytes: 1_024,
            creationDate: timestamp,
            modificationDate: timestamp,
            lastAccessedDate: timestamp,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .ready
        )
        environment.context.insert(firstFile)
        environment.context.insert(secondFile)
        try environment.context.save()

        let organizeExpectation = expectation(description: "bulk organize success")
        await environment.coordinator.organizeMultipleFiles(
            [firstFile, secondFile],
            origin: .automation,
            context: environment.context
        ) { success, failed, _, error in
            XCTAssertEqual(success, 2)
            XCTAssertEqual(failed, 0)
            XCTAssertNil(error)
            organizeExpectation.fulfill()
        }
        await fulfillment(of: [organizeExpectation], timeout: 2.0)

        var undoCompleted = false
        environment.coordinator.undoLastAction(allFiles: [firstFile, secondFile], context: environment.context) {
            undoCompleted = true
        }
        XCTAssertTrue(undoCompleted)

        var redoCompleted = false
        await environment.coordinator.redoLastAction(allFiles: [firstFile, secondFile], context: environment.context) {
            redoCompleted = true
        }
        XCTAssertTrue(redoCompleted)

        let records = try environment.context.fetch(FetchDescriptor<FileMetadataRecord>())
        XCTAssertEqual(records.count, 2)

        let firstRecord = try XCTUnwrap(records.first(where: { $0.canonicalIdentity == FileMetadataFoundationService.pathFallbackCanonicalIdentity(for: firstDestinationURL.path) }))
        let secondRecord = try XCTUnwrap(records.first(where: { $0.canonicalIdentity == FileMetadataFoundationService.pathFallbackCanonicalIdentity(for: secondDestinationURL.path) }))

        XCTAssertEqual(firstRecord.lastKnownPath, firstDestinationURL.path)
        XCTAssertEqual(firstRecord.latestOrganizationStatus, .organized)
        XCTAssertEqual(firstRecord.organizationCount, 2)
        XCTAssertEqual(firstRecord.historyEntries.count, 3)
        XCTAssertEqual(firstRecord.historyEntries.sorted(by: { $0.timestamp < $1.timestamp }).map(\.eventKind), [.organized, .undone, .organized])

        XCTAssertEqual(secondRecord.lastKnownPath, secondDestinationURL.path)
        XCTAssertEqual(secondRecord.latestOrganizationStatus, .organized)
        XCTAssertEqual(secondRecord.organizationCount, 2)
        XCTAssertEqual(secondRecord.historyEntries.count, 3)
        XCTAssertEqual(secondRecord.historyEntries.sorted(by: { $0.timestamp < $1.timestamp }).map(\.eventKind), [.organized, .undone, .organized])
    }

    func testOrganizeCluster_RedoReplaysExplicitProjectAssociationContext() async throws {
        FeatureFlagService.shared.setEnabled(.autoProjectAssociation, true)

        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        let destinationBase = try tempDirectory.createDirectory(name: "Workspace")
        let clusterFolder = destinationBase.appendingPathComponent("Client Alpha", isDirectory: true)
        let firstSourceURL = sourceFolder.appendingPathComponent("alpha-notes.txt")
        let secondSourceURL = sourceFolder.appendingPathComponent("alpha-assets.txt")
        let firstDestinationURL = clusterFolder.appendingPathComponent("alpha-notes.txt")
        let secondDestinationURL = clusterFolder.appendingPathComponent("alpha-assets.txt")
        let timestamp = Date(timeIntervalSince1970: 2_550)

        _ = try insertPathFallbackRecord(
            in: environment.context,
            path: firstSourceURL.path,
            displayName: "alpha-notes.txt",
            fileExtension: "txt",
            timestamp: timestamp
        )
        _ = try insertPathFallbackRecord(
            in: environment.context,
            path: secondSourceURL.path,
            displayName: "alpha-assets.txt",
            fileExtension: "txt",
            timestamp: timestamp
        )

        _ = try tempDirectory.createFile(name: "Inbox/alpha-notes.txt", contents: "notes")
        _ = try tempDirectory.createFile(name: "Inbox/alpha-assets.txt", contents: "assets")

        let firstFile = FileItem(
            path: firstSourceURL.path,
            sizeInBytes: 512,
            creationDate: timestamp,
            modificationDate: timestamp,
            lastAccessedDate: timestamp,
            location: .custom,
            scanRootPath: sourceFolder.path,
            status: .ready
        )
        let secondFile = FileItem(
            path: secondSourceURL.path,
            sizeInBytes: 512,
            creationDate: timestamp,
            modificationDate: timestamp,
            lastAccessedDate: timestamp,
            location: .custom,
            scanRootPath: sourceFolder.path,
            status: .ready
        )
        environment.context.insert(firstFile)
        environment.context.insert(secondFile)
        try environment.context.save()

        let cluster = ProjectCluster(
            clusterType: .nameSimilarity,
            filePaths: [firstSourceURL.path, secondSourceURL.path],
            confidenceScore: 0.95,
            suggestedFolderName: "Client Alpha"
        )
        let viewModel = BulkOperationViewModel(
            organizationCoordinator: environment.coordinator,
            notificationService: .shared
        )

        await viewModel.organizeCluster(
            cluster,
            destinationBase: destinationBase.path,
            allFiles: [firstFile, secondFile],
            context: environment.context
        )

        var undoCompleted = false
        environment.coordinator.undoLastAction(allFiles: [firstFile, secondFile], context: environment.context) {
            undoCompleted = true
        }
        XCTAssertTrue(undoCompleted)

        var redoCompleted = false
        await environment.coordinator.redoLastAction(allFiles: [firstFile, secondFile], context: environment.context) {
            redoCompleted = true
        }
        XCTAssertTrue(redoCompleted)

        let records = try environment.context.fetch(FetchDescriptor<FileMetadataRecord>())
        let firstRecord = try XCTUnwrap(records.first(where: {
            $0.canonicalIdentity == FileMetadataFoundationService.pathFallbackCanonicalIdentity(for: firstDestinationURL.path)
        }))
        let secondRecord = try XCTUnwrap(records.first(where: {
            $0.canonicalIdentity == FileMetadataFoundationService.pathFallbackCanonicalIdentity(for: secondDestinationURL.path)
        }))

        XCTAssertEqual(firstRecord.projectAssociation, "Client Alpha")
        XCTAssertEqual(secondRecord.projectAssociation, "Client Alpha")
    }

    func testOrganizeMultipleFiles_AppendsOneHistoryEntryPerFileWithoutDuplicateRecords() async throws {
        let environment = try makeEnvironment()
        let tempDirectory = try TemporaryDirectory()
        defer { tempDirectory.cleanup() }

        let sourceFolder = try tempDirectory.createDirectory(name: "Inbox")
        let destinationFolder = try tempDirectory.createDirectory(name: "Archive")
        let firstSourceURL = sourceFolder.appendingPathComponent("first.pdf")
        let secondSourceURL = sourceFolder.appendingPathComponent("second.pdf")
        let firstDestinationURL = destinationFolder.appendingPathComponent("first.pdf")
        let secondDestinationURL = destinationFolder.appendingPathComponent("second.pdf")
        let seededTimestamp = Date(timeIntervalSince1970: 3_000)

        _ = try insertPathFallbackRecord(
            in: environment.context,
            path: firstSourceURL.path,
            displayName: "first.pdf",
            fileExtension: "pdf",
            timestamp: seededTimestamp
        )
        _ = try insertPathFallbackRecord(
            in: environment.context,
            path: secondSourceURL.path,
            displayName: "second.pdf",
            fileExtension: "pdf",
            timestamp: seededTimestamp
        )

        _ = try tempDirectory.createFile(name: "Inbox/first.pdf", contents: "first")
        _ = try tempDirectory.createFile(name: "Inbox/second.pdf", contents: "second")

        let destination = try Destination.folder(from: destinationFolder, displayName: "Archive")
        let firstFile = FileItem(
            path: firstSourceURL.path,
            sizeInBytes: 1_024,
            creationDate: seededTimestamp,
            modificationDate: seededTimestamp,
            lastAccessedDate: seededTimestamp,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .ready
        )
        let secondFile = FileItem(
            path: secondSourceURL.path,
            sizeInBytes: 1_024,
            creationDate: seededTimestamp,
            modificationDate: seededTimestamp,
            lastAccessedDate: seededTimestamp,
            location: .custom,
            scanRootPath: sourceFolder.path,
            destination: destination,
            status: .ready
        )
        environment.context.insert(firstFile)
        environment.context.insert(secondFile)
        try environment.context.save()

        var successCount = 0
        var failedCount = 0
        var completionError: Error?

        await environment.coordinator.organizeMultipleFiles(
            [firstFile, secondFile],
            origin: .automation,
            context: environment.context
        ) { success, failed, _, error in
            successCount = success
            failedCount = failed
            completionError = error
        }

        XCTAssertEqual(successCount, 2)
        XCTAssertEqual(failedCount, 0)
        XCTAssertNil(completionError)

        let records = try environment.context.fetch(FetchDescriptor<FileMetadataRecord>())
        XCTAssertEqual(records.count, 2)

        let recordByPath = Dictionary(uniqueKeysWithValues: records.map { ($0.lastKnownPath, $0) })

        let firstRecord = try XCTUnwrap(recordByPath[firstDestinationURL.path])
        let secondRecord = try XCTUnwrap(recordByPath[secondDestinationURL.path])

        XCTAssertEqual(firstRecord.historyEntries.count, 1)
        XCTAssertEqual(secondRecord.historyEntries.count, 1)
        XCTAssertEqual(firstRecord.latestOrganizationStatus, .organized)
        XCTAssertEqual(secondRecord.latestOrganizationStatus, .organized)
        XCTAssertEqual(firstRecord.canonicalIdentity, FileMetadataFoundationService.pathFallbackCanonicalIdentity(for: firstDestinationURL.path))
        XCTAssertEqual(secondRecord.canonicalIdentity, FileMetadataFoundationService.pathFallbackCanonicalIdentity(for: secondDestinationURL.path))

        let firstHistory = try XCTUnwrap(firstRecord.historyEntries.first)
        let secondHistory = try XCTUnwrap(secondRecord.historyEntries.first)
        XCTAssertEqual(firstHistory.eventKind, .organized)
        XCTAssertEqual(secondHistory.eventKind, .organized)
        XCTAssertEqual(firstHistory.sourceSurface, .organize)
        XCTAssertEqual(secondHistory.sourceSurface, .organize)
        XCTAssertEqual(firstHistory.fromPath, firstSourceURL.path)
        XCTAssertEqual(firstHistory.toPath, firstDestinationURL.path)
        XCTAssertEqual(secondHistory.fromPath, secondSourceURL.path)
        XCTAssertEqual(secondHistory.toPath, secondDestinationURL.path)
    }
}
