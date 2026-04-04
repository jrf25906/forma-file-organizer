import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class FileMetadataFoundationIntegrationTests: XCTestCase {
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
        let schema = Schema([
            FileItem.self,
            ActivityItem.self,
            FileMetadataRecord.self,
            FileOrganizationHistoryEntry.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        return (
            container: container,
            context: context,
            coordinator: FileOrganizationCoordinator(),
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
