import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class FileMetadataFoundationIntegrationTests: XCTestCase {
    private enum InjectedMetadataFailure: Error {
        case bulkUndoFirstItem
        case transitionWriteFailure
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
