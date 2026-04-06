import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class FileMetadataFoundationServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.autoContentTags, true)
        FeatureFlagService.shared.setEnabled(.autoProjectAssociation, true)
    }

    override func tearDown() {
        FeatureFlagService.shared.resetToDefaults()
        super.tearDown()
    }

    private func makeService() throws -> (ModelContainer, ModelContext, FileMetadataFoundationService) {
        let schema = Schema([
            FileMetadataRecord.self,
            FileOrganizationHistoryEntry.self,
            ProjectCluster.self,
            Rule.self,
            RuleCategory.self
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

    private func insertProjectCluster(
        in context: ModelContext,
        filePath: String,
        suggestedFolderName: String,
        confidenceScore: Double
    ) throws -> ProjectCluster {
        let cluster = ProjectCluster(
            clusterType: .nameSimilarity,
            filePaths: [filePath],
            confidenceScore: confidenceScore,
            suggestedFolderName: suggestedFolderName
        )
        context.insert(cluster)
        try context.save()
        return cluster
    }

    private func insertRule(
        in context: ModelContext,
        categoryName: String? = nil,
        destinationDisplayName: String? = nil
    ) throws -> Rule {
        let category = categoryName.map { name in
            RuleCategory(name: name)
        }

        if let category {
            context.insert(category)
        }

        let destination: Destination?
        if let destinationDisplayName {
            destination = .folder(bookmark: Data(), displayName: destinationDisplayName)
        } else {
            destination = nil
        }

        let rule = Rule(
            name: "Tagging Rule",
            conditionType: .fileExtension,
            conditionValue: "pdf",
            actionType: .move,
            destination: destination,
            category: category
        )
        context.insert(rule)
        try context.save()
        return rule
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

    func testApplyProjectAssociation_ExplicitProjectLikeDestinationWritesNormalizedLabel() throws {
        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let fileURL = try tempDir.createFile(name: "Inbox/report.txt", contents: "report")
            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: fileURL.path,
                    displayName: "report.txt",
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 8_000)
                )
            )

            let writeContext = ProjectAssociationWriteContext(
                resolvedExplicitDestinationFolderPath: "/Users/example/Documents/Projects/  Alpha  ",
                explicitSourceMode: false,
                inferredCandidates: []
            )

            let sourceCategory = try XCTUnwrap(
                service.applyProjectAssociationWithoutSaving(
                    for: record,
                    writeContext: writeContext
                )
            )

            XCTAssertEqual(sourceCategory, .destinationFolder)
            XCTAssertEqual(record.projectAssociation, "Alpha")
            XCTAssertEqual(try context.fetch(FetchDescriptor<FileMetadataRecord>()).first?.projectAssociation, "Alpha")
        }
    }

    func testApplyProjectAssociation_InferencePopulatesEmptyRecordOnly() throws {
        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let sourceURL = try tempDir.createFile(name: "Inbox/alpha-note.txt", contents: "alpha")
            let candidate = try insertProjectCluster(
                in: context,
                filePath: sourceURL.path,
                suggestedFolderName: "Alpha",
                confidenceScore: 0.91
            )

            let emptyRecord = try XCTUnwrap(
                service.upsertRecord(
                    for: sourceURL.path,
                    displayName: "alpha-note.txt",
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 8_100)
                )
            )

            let emptyWriteContext = ProjectAssociationWriteContext(
                resolvedExplicitDestinationFolderPath: nil,
                explicitSourceMode: false,
                inferredCandidates: [
                    .init(
                        suggestedFolderName: candidate.suggestedFolderName,
                        normalizedLabel: candidate.suggestedFolderName,
                        confidence: candidate.confidenceScore
                    )
                ]
            )

            let sourceCategory = try XCTUnwrap(
                service.applyProjectAssociationWithoutSaving(
                    for: emptyRecord,
                    writeContext: emptyWriteContext
                )
            )

            XCTAssertEqual(sourceCategory, .relatedFilePattern)
            XCTAssertEqual(emptyRecord.projectAssociation, "Alpha")

            let existingRecord = try XCTUnwrap(
                service.upsertRecord(
                    for: tempDir.url.appendingPathComponent("Inbox/existing-alpha-note.txt").path,
                    displayName: "existing-alpha-note.txt",
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 8_200)
                )
            )
            existingRecord.projectAssociation = "Existing Label"
            try context.save()

            let existingWriteContext = ProjectAssociationWriteContext(
                resolvedExplicitDestinationFolderPath: nil,
                explicitSourceMode: false,
                inferredCandidates: [
                    .init(
                        suggestedFolderName: candidate.suggestedFolderName,
                        normalizedLabel: candidate.suggestedFolderName,
                        confidence: candidate.confidenceScore
                    )
                ]
            )

            _ = service.applyProjectAssociationWithoutSaving(
                for: existingRecord,
                writeContext: existingWriteContext
            )

            XCTAssertEqual(existingRecord.projectAssociation, "Existing Label")
        }
    }

    func testInspectorSummary_IncludesProjectAssociationSourceSummary() throws {
        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let fileURL = try tempDir.createFile(name: "Inbox/finance-report.txt", contents: "finance")

            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: fileURL.path,
                    displayName: "finance-report.txt",
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 8_300)
                )
            )
            record.projectAssociation = "Finance Vault"
            try context.save()

            _ = try XCTUnwrap(
                service.appendHistoryEntry(
                    for: record,
                    eventKind: .organized,
                    sourceSurface: .organize,
                    fromPath: fileURL.path,
                    toPath: "/Users/example/Documents/Projects/Finance Vault/finance-report.txt",
                    destinationDisplayName: "Finance Vault",
                    matchedRuleID: nil,
                    detailsSummary: "Moved into a project folder.",
                    timestamp: Date(timeIntervalSince1970: 8_400)
                )
            )

            let summary = try XCTUnwrap(service.inspectorSummary(for: fileURL.path))
            XCTAssertEqual(summary.projectAssociationSummary, "Finance Vault")
            XCTAssertEqual(summary.projectAssociationSourceSummary, "Derived from destination folder")
        }
    }

    func testInspectorSummary_DoesNotTreatScannedRowsAsDestinationFolderProof() throws {
        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let fileURL = try tempDir.createFile(name: "Inbox/scanned-project.txt", contents: "scan")

            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: fileURL.path,
                    displayName: "scanned-project.txt",
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 8_420)
                )
            )
            record.projectAssociation = "Finance Vault"
            try context.save()

            _ = try XCTUnwrap(
                service.appendHistoryEntry(
                    for: record,
                    eventKind: .scanned,
                    sourceSurface: .scan,
                    fromPath: nil,
                    toPath: "/Users/example/Documents/Projects/Finance Vault/scanned-project.txt",
                    destinationDisplayName: "Finance Vault",
                    matchedRuleID: nil,
                    detailsSummary: "Scan row with a project-like destination path.",
                    timestamp: Date(timeIntervalSince1970: 8_421)
                )
            )

            let summary = try XCTUnwrap(service.inspectorSummary(for: fileURL.path))
            XCTAssertEqual(summary.projectAssociationSummary, "Finance Vault")
            XCTAssertNil(summary.projectAssociationSourceSummary)
        }
    }

    func testInspectorSummary_DoesNotExposeDestinationFolderSourceSummaryForGenericDestination() throws {
        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let fileURL = try tempDir.createFile(name: "Inbox/screenshot.png", contents: "shot")

            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: fileURL.path,
                    displayName: "screenshot.png",
                    fileExtension: "png",
                    timestamp: Date(timeIntervalSince1970: 8_450)
                )
            )
            record.projectAssociation = "Screenshots"
            try context.save()

            _ = try XCTUnwrap(
                service.appendHistoryEntry(
                    for: record,
                    eventKind: .organized,
                    sourceSurface: .organize,
                    fromPath: fileURL.path,
                    toPath: "/Users/example/Pictures/Screenshots/screenshot.png",
                    destinationDisplayName: "Screenshots",
                    matchedRuleID: nil,
                    detailsSummary: "Moved into a generic destination folder.",
                    timestamp: Date(timeIntervalSince1970: 8_460)
                )
            )

            let summary = try XCTUnwrap(service.inspectorSummary(for: fileURL.path))
            XCTAssertEqual(summary.projectAssociationSummary, "Screenshots")
            XCTAssertNil(summary.projectAssociationSourceSummary)
        }
    }

    func testInspectorSummary_HidesProjectAssociationRowWhenAutoProjectAssociationDisabled() throws {
        try withService { context, service in
            FeatureFlagService.shared.setEnabled(.autoProjectAssociation, false)

            let tempDir = try TemporaryDirectory()
            let fileURL = try tempDir.createFile(name: "Inbox/project-note.txt", contents: "project")

            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: fileURL.path,
                    displayName: "project-note.txt",
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 8_500)
                )
            )
            record.projectAssociation = "Project Atlas"
            try context.save()

            _ = try XCTUnwrap(
                service.appendHistoryEntry(
                    for: record,
                    eventKind: .organized,
                    sourceSurface: .organize,
                    fromPath: fileURL.path,
                    toPath: "/Users/example/Documents/Projects/Project Atlas/project-note.txt",
                    destinationDisplayName: "Project Atlas",
                    matchedRuleID: nil,
                    detailsSummary: "Moved into a project folder.",
                    timestamp: Date(timeIntervalSince1970: 8_600)
                )
            )

            let summary = try XCTUnwrap(service.inspectorSummary(for: fileURL.path))
            XCTAssertEqual(summary.firstSeenSummary, "First seen: 1970-01-01 02:21:40 UTC")
            XCTAssertEqual(summary.lastOrganizedSummary, "Last organized: 1970-01-01 02:23:20 UTC")
            XCTAssertEqual(summary.organizationCountSummary, "1 organization")
            XCTAssertEqual(summary.projectAssociationSummary, "")
            XCTAssertNil(summary.projectAssociationSourceSummary)
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

    func testApplyContentTags_AppendsExplicitAndInferredTagsWithoutDuplicates() throws {
        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let fileURL = try tempDir.createFile(name: "Inbox/invoice-contract.pdf", contents: "invoice")
            let rule = try insertRule(in: context, categoryName: "Invoices")
            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: fileURL.path,
                    displayName: "invoice-contract.pdf",
                    fileExtension: "pdf",
                    timestamp: Date(timeIntervalSince1970: 8_700)
                )
            )
            record.tags = ["legacy-custom"]

            let appendedTags = service.applyContentTagsWithoutSaving(
                for: record,
                displayName: "invoice-contract.pdf",
                fileExtension: "pdf",
                destinationDisplayName: "Contracts",
                matchedRuleID: rule.id
            )

            XCTAssertEqual(appendedTags, [.contract, .invoice])
            XCTAssertEqual(record.tags, ["legacy-custom", "contract", "invoice"])
        }
    }

    func testApplyContentTags_FeatureFlagDisabledSkipsWrites() throws {
        try withService { context, service in
            FeatureFlagService.shared.setEnabled(.autoContentTags, false)

            let tempDir = try TemporaryDirectory()
            let fileURL = try tempDir.createFile(name: "Inbox/invoice.pdf", contents: "invoice")
            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: fileURL.path,
                    displayName: "invoice.pdf",
                    fileExtension: "pdf",
                    timestamp: Date(timeIntervalSince1970: 8_710)
                )
            )

            let appendedTags = service.applyContentTagsWithoutSaving(
                for: record,
                displayName: "invoice.pdf",
                fileExtension: "pdf",
                destinationDisplayName: "Invoices",
                matchedRuleID: nil
            )

            XCTAssertEqual(appendedTags, [])
            XCTAssertEqual(record.tags, [])
            XCTAssertEqual(try context.fetch(FetchDescriptor<FileMetadataRecord>()).count, 1)
        }
    }

    func testApplyContentTags_DoesNotEvictStoredTagsWhenRecordIsAlreadyAtCap() throws {
        try withService { _, service in
            let tempDir = try TemporaryDirectory()
            let fileURL = try tempDir.createFile(name: "Inbox/board-deck.pptx", contents: "deck")
            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: fileURL.path,
                    displayName: "board-deck.pptx",
                    fileExtension: "pptx",
                    timestamp: Date(timeIntervalSince1970: 8_720)
                )
            )
            record.tags = ["invoice", "receipt", "contract"]

            let appendedTags = service.applyContentTagsWithoutSaving(
                for: record,
                displayName: "board-deck.pptx",
                fileExtension: "pptx",
                destinationDisplayName: "Statements",
                matchedRuleID: nil
            )

            XCTAssertEqual(appendedTags, [.statement, .presentation])
            XCTAssertEqual(
                record.tags,
                ["invoice", "receipt", "contract", "statement", "presentation"]
            )
        }
    }

    func testApplyContentTags_RecognizesAliasShapedStoredTagsWhenSuppressingDuplicates() throws {
        try withService { _, service in
            let tempDir = try TemporaryDirectory()
            let fileURL = try tempDir.createFile(name: "Inbox/invoice.pdf", contents: "invoice")
            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: fileURL.path,
                    displayName: "invoice.pdf",
                    fileExtension: "pdf",
                    timestamp: Date(timeIntervalSince1970: 8_721)
                )
            )
            record.tags = ["Invoices"]

            let appendedTags = service.applyContentTagsWithoutSaving(
                for: record,
                displayName: "invoice.pdf",
                fileExtension: "pdf",
                destinationDisplayName: "Invoices",
                matchedRuleID: nil
            )

            XCTAssertEqual(appendedTags, [])
            XCTAssertEqual(record.tags, ["Invoices"])
        }
    }

    func testRecordTransition_AppliesContentTagsWhenFeatureEnabled() throws {
        try withService { _, service in
            let tempDir = try TemporaryDirectory()
            let sourceURL = try tempDir.createFile(name: "Inbox/invoice.pdf", contents: "invoice")
            let destinationURL = tempDir.url.appendingPathComponent("Archive/invoice.pdf")

            let record = try XCTUnwrap(
                service.recordTransition(
                    from: sourceURL.path,
                    to: destinationURL.path,
                    displayName: "invoice.pdf",
                    fileExtension: "pdf",
                    eventKind: .organized,
                    sourceSurface: .organize,
                    destinationDisplayName: "Invoices",
                    matchedRuleID: nil,
                    timestamp: Date(timeIntervalSince1970: 8_725)
                )
            )

            XCTAssertEqual(record.tags, ["invoice"])
        }
    }

    func testRecordTransition_RuleCategoryTagSurvivesUndoAndRedoWithoutMatchedRuleID() throws {
        try withService { context, service in
            let rule = try insertRule(
                in: context,
                categoryName: "Contracts",
                destinationDisplayName: "Reference"
            )
            let tempDir = try TemporaryDirectory()
            let sourceURL = try tempDir.createFile(name: "Inbox/q1-summary.pdf", contents: "summary")
            let destinationURL = tempDir.url.appendingPathComponent("Archive/q1-summary.pdf")

            let organizedRecord = try XCTUnwrap(
                service.recordTransition(
                    from: sourceURL.path,
                    to: destinationURL.path,
                    displayName: "q1-summary.pdf",
                    fileExtension: "pdf",
                    eventKind: .organized,
                    sourceSurface: .organize,
                    destinationDisplayName: "Reference",
                    matchedRuleID: rule.id,
                    timestamp: Date(timeIntervalSince1970: 8_726)
                )
            )
            XCTAssertEqual(organizedRecord.tags, ["contract"])

            let undoneRecord = try XCTUnwrap(
                service.recordTransition(
                    from: destinationURL.path,
                    to: sourceURL.path,
                    displayName: "q1-summary.pdf",
                    fileExtension: "pdf",
                    eventKind: .undone,
                    sourceSurface: .undo,
                    destinationDisplayName: "Reference",
                    matchedRuleID: nil,
                    timestamp: Date(timeIntervalSince1970: 8_727)
                )
            )
            XCTAssertEqual(undoneRecord.tags, ["contract"])

            let redoneRecord = try XCTUnwrap(
                service.recordTransition(
                    from: sourceURL.path,
                    to: destinationURL.path,
                    displayName: "q1-summary.pdf",
                    fileExtension: "pdf",
                    eventKind: .organized,
                    sourceSurface: .organize,
                    destinationDisplayName: "Reference",
                    matchedRuleID: nil,
                    timestamp: Date(timeIntervalSince1970: 8_728)
                )
            )
            XCTAssertEqual(redoneRecord.tags, ["contract"])
        }
    }

    func testContentTagIndex_ReturnsBuiltInTagsForRequestedPathsOnly() throws {
        try withService { _, service in
            let tempDir = try TemporaryDirectory()
            let invoiceURL = try tempDir.createFile(name: "Inbox/invoice.pdf", contents: "invoice")
            let receiptURL = try tempDir.createFile(name: "Inbox/receipt.pdf", contents: "receipt")
            let deckURL = try tempDir.createFile(name: "Inbox/deck.pptx", contents: "deck")

            let invoiceRecord = try XCTUnwrap(
                service.upsertRecord(
                    for: invoiceURL.path,
                    displayName: "invoice.pdf",
                    fileExtension: "pdf",
                    timestamp: Date(timeIntervalSince1970: 8_730)
                )
            )
            invoiceRecord.tags = ["Invoices", "legacy-custom"]

            let receiptRecord = try XCTUnwrap(
                service.upsertRecord(
                    for: receiptURL.path,
                    displayName: "receipt.pdf",
                    fileExtension: "pdf",
                    timestamp: Date(timeIntervalSince1970: 8_731)
                )
            )
            receiptRecord.tags = ["Receipts"]

            let deckRecord = try XCTUnwrap(
                service.upsertRecord(
                    for: deckURL.path,
                    displayName: "deck.pptx",
                    fileExtension: "pptx",
                    timestamp: Date(timeIntervalSince1970: 8_732)
                )
            )
            deckRecord.tags = ["Slides"]

            let index = service.contentTagIndex(for: [invoiceURL.path, receiptURL.path])

            XCTAssertEqual(index.count, 2)
            XCTAssertEqual(index[invoiceURL.path], [.invoice])
            XCTAssertEqual(index[receiptURL.path], [.receipt])
            XCTAssertNil(index[deckURL.path])
        }
    }

    func testContentTagIndex_AutoContentTagsDisabledReturnsEmptyIndex() throws {
        try withService { _, service in
            let tempDir = try TemporaryDirectory()
            let invoiceURL = try tempDir.createFile(name: "Inbox/invoice.pdf", contents: "invoice")

            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: invoiceURL.path,
                    displayName: "invoice.pdf",
                    fileExtension: "pdf",
                    timestamp: Date(timeIntervalSince1970: 8_733)
                )
            )
            record.tags = ["invoice"]

            FeatureFlagService.shared.setEnabled(.autoContentTags, false)

            XCTAssertEqual(service.contentTagIndex(for: [invoiceURL.path]), [:])
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

    func testRekeyPathFallbackRecord_WhenDestinationCollisionExists_PreservesSourceAndDestinationTags() throws {
        try withService { _, service in
            let oldPath = "/Users/example/Downloads/Legacy/invoice.txt"
            let newPath = "/Users/example/Documents/Invoices/invoice.txt"

            let sourceRecord = try XCTUnwrap(
                service.upsertRecord(
                    for: oldPath,
                    displayName: "invoice.txt",
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 7_500)
                )
            )
            sourceRecord.tags = ["Invoices", "legacy-source"]

            let targetRecord = try XCTUnwrap(
                service.upsertRecord(
                    for: newPath,
                    displayName: "invoice.txt",
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 7_600)
                )
            )
            targetRecord.tags = ["receipt", "legacy-target"]

            let mergedRecord = try XCTUnwrap(
                service.rekeyPathFallbackRecord(
                    oldPath: oldPath,
                    newPath: newPath,
                    timestamp: Date(timeIntervalSince1970: 7_700)
                )
            )

            XCTAssertEqual(
                mergedRecord.tags,
                ["receipt", "legacy-target", "Invoices", "legacy-source"]
            )
        }
    }
}
