import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class FileMetadataFoundationServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
    }

    override func tearDown() {
        FeatureFlagService.shared.resetToDefaults()
        super.tearDown()
    }

    private func makeService() throws -> (ModelContainer, ModelContext, FileMetadataFoundationService) {
        let schema = Schema([
            FileMetadataRecord.self,
            FileOrganizationHistoryEntry.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        return (container, context, FileMetadataFoundationService(modelContext: context))
    }

    private func withService(
        _ body: (_ context: ModelContext, _ service: FileMetadataFoundationService) throws -> Void
    ) throws {
        let (container, context, service) = try makeService()
        try withExtendedLifetime(container) {
            try body(context, service)
        }
    }

    func testUpsertRecord_DeduplicatesByCanonicalIdentity() throws {
        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let sourceURL = try tempDir.createFile(name: "Inbox/report.txt", contents: "report")
            let firstTimestamp = Date(timeIntervalSince1970: 1_000)
            let secondTimestamp = Date(timeIntervalSince1970: 2_000)

            let firstRecord = try XCTUnwrap(
                service.upsertRecord(
                    for: sourceURL.path,
                    displayName: "report.txt",
                    fileExtension: "txt",
                    timestamp: firstTimestamp
                )
            )

            let movedURL = tempDir.url.appendingPathComponent("Archive/renamed-report.txt")
            try FileManager.default.createDirectory(
                at: movedURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try FileManager.default.moveItem(at: sourceURL, to: movedURL)

            let secondRecord = try XCTUnwrap(
                service.upsertRecord(
                    for: movedURL.path,
                    displayName: "renamed-report.txt",
                    fileExtension: "txt",
                    timestamp: secondTimestamp
                )
            )

            let records = try context.fetch(FetchDescriptor<FileMetadataRecord>())
            XCTAssertEqual(records.count, 1)
            XCTAssertEqual(firstRecord.canonicalIdentity, secondRecord.canonicalIdentity)
            XCTAssertEqual(records.first?.canonicalIdentity, secondRecord.canonicalIdentity)
            XCTAssertEqual(records.first?.lastKnownPath, movedURL.path)
            XCTAssertEqual(records.first?.firstSeenAt, firstTimestamp)
            XCTAssertEqual(records.first?.lastSeenAt, secondTimestamp)
        }
    }

    func testRekeyPathFallbackRecord_AfterManagedMove() throws {
        try withService { context, service in
            let oldPath = "/Users/example/Downloads/Legacy/invoice.txt"
            let newPath = "/Users/example/Documents/Invoices/invoice.txt"
            let firstTimestamp = Date(timeIntervalSince1970: 3_000)
            let secondTimestamp = Date(timeIntervalSince1970: 4_000)
            let thirdTimestamp = Date(timeIntervalSince1970: 5_000)

            let originalRecord = try XCTUnwrap(
                service.upsertRecord(
                    for: oldPath,
                    displayName: "invoice.txt",
                    fileExtension: "txt",
                    timestamp: firstTimestamp
                )
            )

            XCTAssertEqual(originalRecord.identityKind, .pathFallback)

            let rekeyedRecord = try XCTUnwrap(
                service.rekeyPathFallbackRecord(
                    oldPath: oldPath,
                    newPath: newPath,
                    timestamp: secondTimestamp
                )
            )

            XCTAssertEqual(rekeyedRecord.identityKind, .pathFallback)
            XCTAssertEqual(rekeyedRecord.canonicalIdentity, FileMetadataFoundationService.pathFallbackCanonicalIdentity(for: newPath))
            XCTAssertEqual(rekeyedRecord.lastKnownPath, newPath)

            let refreshedRecord = try XCTUnwrap(
                service.upsertRecord(
                    for: newPath,
                    displayName: "invoice.txt",
                    fileExtension: "txt",
                    timestamp: thirdTimestamp
                )
            )

            let records = try context.fetch(FetchDescriptor<FileMetadataRecord>())
            XCTAssertEqual(records.count, 1)
            XCTAssertEqual(refreshedRecord.canonicalIdentity, rekeyedRecord.canonicalIdentity)
            XCTAssertEqual(records.first?.lastKnownPath, newPath)
            XCTAssertEqual(records.first?.lastSeenAt, thirdTimestamp)
        }
    }

    func testAppendHistoryEntry_PreservesMetadataRelationshipAcrossFallbackRekey() throws {
        try withService { context, service in
            let oldPath = "/Users/example/Downloads/Legacy/receipt.pdf"
            let newPath = "/Users/example/Documents/Receipts/receipt.pdf"
            let eventTimestamp = Date(timeIntervalSince1970: 6_000)

            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: oldPath,
                    displayName: "receipt.pdf",
                    fileExtension: "pdf",
                    timestamp: Date(timeIntervalSince1970: 5_900)
                )
            )

            _ = try XCTUnwrap(
                service.appendHistoryEntry(
                    for: record,
                    eventKind: .organized,
                    sourceSurface: .organize,
                    fromPath: oldPath,
                    toPath: newPath,
                    destinationDisplayName: "Receipts",
                    matchedRuleID: nil,
                    detailsSummary: "Moved by Forma during a managed organization pass.",
                    timestamp: eventTimestamp
                )
            )

            _ = try XCTUnwrap(
                service.rekeyPathFallbackRecord(
                    oldPath: oldPath,
                    newPath: newPath,
                    timestamp: Date(timeIntervalSince1970: 6_100)
                )
            )

            let summary = try XCTUnwrap(service.inspectorSummary(for: newPath))
            XCTAssertEqual(summary.recentHistoryRows.count, 1)
            XCTAssertEqual(summary.recentHistoryRows.first?.fromPath, oldPath)
            XCTAssertEqual(summary.recentHistoryRows.first?.toPath, newPath)
            XCTAssertEqual(summary.recentHistoryRows.first?.destinationDisplayName, "Receipts")

            let records = try context.fetch(FetchDescriptor<FileMetadataRecord>())
            XCTAssertEqual(records.count, 1)
            XCTAssertEqual(records.first?.historyEntries.count, 1)
        }
    }

    func testInspectorSummary_UsesReservedDefaultsAndHistoryOrdering() throws {
        try withService { _, service in
            let tempDir = try TemporaryDirectory()
            let fileURL = try tempDir.createFile(name: "report.csv", contents: "alpha,beta")
            let firstSeen = Date(timeIntervalSince1970: 0)
            let olderHistory = Date(timeIntervalSince1970: 60)
            let middleHistory = Date(timeIntervalSince1970: 120)
            let newestHistory = Date(timeIntervalSince1970: 180)

            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: fileURL.path,
                    displayName: "report.csv",
                    fileExtension: "csv",
                    timestamp: firstSeen
                )
            )

            _ = try XCTUnwrap(
                service.appendHistoryEntry(
                    for: record,
                    eventKind: .scanned,
                    sourceSurface: .scan,
                    fromPath: nil,
                    toPath: fileURL.path,
                    destinationDisplayName: nil,
                    matchedRuleID: nil,
                    detailsSummary: "Initial metadata capture.",
                    timestamp: middleHistory
                )
            )

            _ = try XCTUnwrap(
                service.appendHistoryEntry(
                    for: record,
                    eventKind: .organized,
                    sourceSurface: .organize,
                    fromPath: fileURL.path,
                    toPath: "/Users/example/Documents/report.csv",
                    destinationDisplayName: "Documents",
                    matchedRuleID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"),
                    detailsSummary: "Moved into Documents.",
                    timestamp: newestHistory
                )
            )

            _ = try XCTUnwrap(
                service.appendHistoryEntry(
                    for: record,
                    eventKind: .noted,
                    sourceSurface: .inspector,
                    fromPath: fileURL.path,
                    toPath: nil,
                    destinationDisplayName: nil,
                    matchedRuleID: nil,
                    detailsSummary: "Inspector note.",
                    timestamp: olderHistory
                )
            )

            let summary = try XCTUnwrap(service.inspectorSummary(for: fileURL.path))
            XCTAssertEqual(summary.firstSeenSummary, "First seen: 1970-01-01 00:00:00 UTC")
            XCTAssertEqual(summary.lastOrganizedSummary, "Last organized: 1970-01-01 00:03:00 UTC")
            XCTAssertEqual(summary.organizationCountSummary, "1 organization")
            XCTAssertEqual(summary.tagsSummary, "")
            XCTAssertEqual(summary.projectAssociationSummary, "")
            XCTAssertEqual(summary.recentHistoryRows.map(\.detailsSummary), [
                "Moved into Documents.",
                "Initial metadata capture.",
                "Inspector note."
            ])
        }
    }

    func testInspectorSummary_IncludesHistoryAndReservedMetadataWhenAvailable() throws {
        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let fileURL = try tempDir.createFile(name: "archive/proof.txt", contents: "proof")
            let firstSeen = Date(timeIntervalSince1970: 10)
            let scannedAt = Date(timeIntervalSince1970: 20)
            let organizedAt = Date(timeIntervalSince1970: 30)

            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: fileURL.path,
                    displayName: "proof.txt",
                    fileExtension: "txt",
                    timestamp: firstSeen
                )
            )

            record.projectAssociation = "  Finance Vault  "
            record.tags = ["  Priority  ", "  Archived  "]
            try context.save()

            _ = try XCTUnwrap(
                service.appendHistoryEntry(
                    for: record,
                    eventKind: .scanned,
                    sourceSurface: .scan,
                    fromPath: nil,
                    toPath: fileURL.path,
                    destinationDisplayName: nil,
                    matchedRuleID: nil,
                    detailsSummary: "Scanned into metadata foundation.",
                    timestamp: scannedAt
                )
            )

            _ = try XCTUnwrap(
                service.appendHistoryEntry(
                    for: record,
                    eventKind: .organized,
                    sourceSurface: .organize,
                    fromPath: fileURL.path,
                    toPath: "/Users/example/Documents/proof.txt",
                    destinationDisplayName: "Documents",
                    matchedRuleID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"),
                    detailsSummary: "Moved into the durable archive.",
                    timestamp: organizedAt
                )
            )

            let summary = try XCTUnwrap(service.inspectorSummary(for: fileURL.path))
            XCTAssertEqual(summary.firstSeenSummary, "First seen: 1970-01-01 00:00:10 UTC")
            XCTAssertEqual(summary.lastOrganizedSummary, "Last organized: 1970-01-01 00:00:30 UTC")
            XCTAssertEqual(summary.organizationCountSummary, "1 organization")
            XCTAssertEqual(summary.projectAssociationSummary, "Finance Vault")
            XCTAssertEqual(summary.tagsSummary, "Priority, Archived")
            XCTAssertEqual(summary.recentHistoryRows.count, 2)
            XCTAssertEqual(summary.recentHistoryRows.map(\.eventKind), ["organized", "scanned"])
            XCTAssertEqual(summary.recentHistoryRows.map(\.detailsSummary), [
                "Moved into the durable archive.",
                "Scanned into metadata foundation."
            ])
        }
    }

    func testInspectorSummary_ReturnsNilWhenFeatureDisabledOrRecordMissing() throws {
        try withService { _, service in
            let tempDir = try TemporaryDirectory()
            let trackedURL = try tempDir.createFile(name: "vault/tracked.txt", contents: "tracked")

            _ = try XCTUnwrap(
                service.upsertRecord(
                    for: trackedURL.path,
                    displayName: "tracked.txt",
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 100)
                )
            )

            FeatureFlagService.shared.setEnabled(.metadataFoundation, false)
            XCTAssertNil(service.inspectorSummary(for: trackedURL.path))

            FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
            XCTAssertNil(service.inspectorSummary(for: "/Users/example/does-not-exist.txt"))
        }
    }

    func testRekeyPathFallbackRecord_WhenDestinationCollisionExists_MergesIntoExistingRecord() throws {
        try withService { context, service in
            let oldPath = "/Users/example/Downloads/Legacy/invoice.txt"
            let newPath = "/Users/example/Documents/Invoices/invoice.txt"

            let sourceRecord = try XCTUnwrap(
                service.upsertRecord(
                    for: oldPath,
                    displayName: "invoice.txt",
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 7_000)
                )
            )
            _ = try XCTUnwrap(
                service.appendHistoryEntry(
                    for: sourceRecord,
                    eventKind: .organized,
                    sourceSurface: .organize,
                    fromPath: oldPath,
                    toPath: oldPath,
                    destinationDisplayName: "Legacy",
                    matchedRuleID: nil,
                    detailsSummary: "Old path organization.",
                    timestamp: Date(timeIntervalSince1970: 7_100)
                )
            )

            let targetRecord = try XCTUnwrap(
                service.upsertRecord(
                    for: newPath,
                    displayName: "invoice.txt",
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 7_200)
                )
            )
            _ = try XCTUnwrap(
                service.appendHistoryEntry(
                    for: targetRecord,
                    eventKind: .organized,
                    sourceSurface: .organize,
                    fromPath: newPath,
                    toPath: newPath,
                    destinationDisplayName: "Invoices",
                    matchedRuleID: nil,
                    detailsSummary: "Destination already had a record.",
                    timestamp: Date(timeIntervalSince1970: 7_300)
                )
            )

            let mergedRecord = try XCTUnwrap(
                service.rekeyPathFallbackRecord(
                    oldPath: oldPath,
                    newPath: newPath,
                    timestamp: Date(timeIntervalSince1970: 7_400)
                )
            )

            let records = try context.fetch(FetchDescriptor<FileMetadataRecord>())
            XCTAssertEqual(records.count, 1)
            XCTAssertEqual(mergedRecord.canonicalIdentity, FileMetadataFoundationService.pathFallbackCanonicalIdentity(for: newPath))
            XCTAssertEqual(mergedRecord.firstSeenAt, Date(timeIntervalSince1970: 7_000))
            XCTAssertEqual(mergedRecord.lastSeenAt, Date(timeIntervalSince1970: 7_400))
            XCTAssertEqual(mergedRecord.organizationCount, 2)
            XCTAssertEqual(mergedRecord.historyEntries.count, 2)
            XCTAssertEqual(mergedRecord.historyEntries.compactMap(\.detailsSummary).sorted(), [
                "Destination already had a record.",
                "Old path organization."
            ])
        }
    }
}
