import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class FileScanPipelineTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        FeatureFlagService.shared.resetToDefaults()
        let schema = Schema([
            FileItem.self,
            Rule.self,
            FileMetadataRecord.self,
            FileOrganizationHistoryEntry.self,
            ProjectCluster.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
    }

    override func tearDown() async throws {
        FeatureFlagService.shared.resetToDefaults()
        // Allow async TaskGroup/TaskLocal cleanup to complete before deallocating
        // to prevent memory corruption during Swift Concurrency internal cleanup.
        try await Task.sleep(for: .milliseconds(50))

        context = nil
        container = nil
    }

    /// Simple FileSystemServiceProtocol stub that returns predetermined metadata
    private final class StubFileSystemService: FileSystemServiceProtocol {
        let metadata: [FileMetadata]
        let scannedRootPaths: [String]

        init(metadata: [FileMetadata], scannedRootPaths: [String] = []) {
            self.metadata = metadata
            self.scannedRootPaths = scannedRootPaths
        }

        func scanDesktop(options: FileScanOptions) async throws -> [FileMetadata] { metadata }
        func scanDownloads(options: FileScanOptions) async throws -> [FileMetadata] { metadata }
        func scanDocuments(options: FileScanOptions) async throws -> [FileMetadata] { metadata }
        func scanPictures(options: FileScanOptions) async throws -> [FileMetadata] { metadata }
        func scanMusic(options: FileScanOptions) async throws -> [FileMetadata] { metadata }

        func scanAllFolders(options: FileScanOptions) async -> ScanResult {
            ScanResult(files: metadata, errors: [:], scannedRootPaths: scannedRootPaths)
        }

        func scan(baseFolders: [FolderLocation], options: FileScanOptions) async -> ScanResult {
            ScanResult(files: metadata, errors: [:], scannedRootPaths: scannedRootPaths)
        }

        func scanExplicitSelection(
            urls: [URL],
            options: FileScanOptions
        ) async throws -> ExplicitSelectionScanResult {
            _ = urls
            return ExplicitSelectionScanResult(
                files: metadata,
                skippedItems: [],
                scannedRootPaths: scannedRootPaths
            )
        }

        func hasDesktopAccess() -> Bool { true }
        func hasDownloadsAccess() -> Bool { true }
        func hasDocumentsAccess() -> Bool { true }
        func hasPicturesAccess() -> Bool { true }
        func hasMusicAccess() -> Bool { true }

        func requestDesktopAccess() async throws -> Bool { true }
        func requestDownloadsAccess() async throws -> Bool { true }
        func requestDocumentsAccess() async throws -> Bool { true }
        func requestPicturesAccess() async throws -> Bool { true }
        func requestMusicAccess() async throws -> Bool { true }

        func getMigrationState() -> BookmarkMigrationState? { nil }
        func resetDesktopAccess() {}
    }

    private final class FailingMetadataFoundationService: FileMetadataFoundationServiceProtocol {
        enum TestError: LocalizedError {
            case failedToPersist

            var errorDescription: String? {
                "metadata persistence failed"
            }
        }

        func upsertRecordWithoutSaving(
            for path: String,
            displayName: String,
            fileExtension: String,
            timestamp: Date
        ) throws -> FileMetadataRecord? {
            _ = path
            _ = displayName
            _ = fileExtension
            _ = timestamp
            throw TestError.failedToPersist
        }

        func upsertRecordForDiscoveryWithoutSaving(
            for path: String,
            displayName: String,
            fileExtension: String,
            timestamp: Date
        ) throws -> FileMetadataFoundationServiceProtocol.UpsertResult? {
            _ = path
            _ = displayName
            _ = fileExtension
            _ = timestamp
            throw TestError.failedToPersist
        }

        func applyProjectAssociationWithoutSaving(
            for metadataRecord: FileMetadataRecord,
            writeContext: ProjectAssociationWriteContext
        ) -> ProjectAssociationWriteContext.SourceSummaryCategory? {
            _ = metadataRecord
            _ = writeContext
            return nil
        }

        func applyContentTagsWithoutSaving(
            for record: FileMetadataRecord,
            displayName: String,
            fileExtension: String,
            destinationDisplayName: String?,
            matchedRuleID: UUID?
        ) -> [MetadataContentTag] {
            _ = record
            _ = displayName
            _ = fileExtension
            _ = destinationDisplayName
            _ = matchedRuleID
            return []
        }

        func applyWorkflowStatusForDiscoveryWithoutSaving(
            to record: FileMetadataRecord,
            wasCreated: Bool,
            timestamp: Date
        ) throws -> Bool {
            _ = record
            _ = wasCreated
            _ = timestamp
            return false
        }
    }

    private final class TrackingMetadataFoundationService: FileMetadataFoundationServiceProtocol {
        private(set) var upsertCalls: Int = 0

        func upsertRecordWithoutSaving(
            for path: String,
            displayName: String,
            fileExtension: String,
            timestamp: Date
        ) throws -> FileMetadataRecord? {
            _ = path
            _ = displayName
            _ = fileExtension
            _ = timestamp
            upsertCalls += 1
            return nil
        }

        func upsertRecordForDiscoveryWithoutSaving(
            for path: String,
            displayName: String,
            fileExtension: String,
            timestamp: Date
        ) throws -> FileMetadataFoundationServiceProtocol.UpsertResult? {
            _ = path
            _ = displayName
            _ = fileExtension
            _ = timestamp
            upsertCalls += 1
            return nil
        }

        func applyProjectAssociationWithoutSaving(
            for metadataRecord: FileMetadataRecord,
            writeContext: ProjectAssociationWriteContext
        ) -> ProjectAssociationWriteContext.SourceSummaryCategory? {
            _ = metadataRecord
            _ = writeContext
            return nil
        }

        func applyContentTagsWithoutSaving(
            for record: FileMetadataRecord,
            displayName: String,
            fileExtension: String,
            destinationDisplayName: String?,
            matchedRuleID: UUID?
        ) -> [MetadataContentTag] {
            _ = record
            _ = displayName
            _ = fileExtension
            _ = destinationDisplayName
            _ = matchedRuleID
            return []
        }

        func applyWorkflowStatusForDiscoveryWithoutSaving(
            to record: FileMetadataRecord,
            wasCreated: Bool,
            timestamp: Date
        ) throws -> Bool {
            _ = record
            _ = wasCreated
            _ = timestamp
            return false
        }
    }

    private func insertProjectCluster(
        filePath: String,
        suggestedFolderName: String,
        confidenceScore: Double,
        isDismissed: Bool = false,
        isOrganized: Bool = false
    ) throws {
        let cluster = ProjectCluster(
            clusterType: .nameSimilarity,
            filePaths: [filePath],
            confidenceScore: confidenceScore,
            suggestedFolderName: suggestedFolderName,
            isDismissed: isDismissed,
            isOrganized: isOrganized
        )
        context.insert(cluster)
        try context.save()
    }

    func testScanAndPersist_PreservesLocationKind() async throws {
        // Given: two files from different logical locations
        let now = Date()
        let desktopMeta = FileMetadata(
            path: "/Users/test/Desktop/a.txt",
            sizeInBytes: 1024,
            creationDate: now,
            modificationDate: now,
            lastAccessedDate: now,
            location: .desktop
        )
        let downloadsMeta = FileMetadata(
            path: "/Users/test/Downloads/b.txt",
            sizeInBytes: 2048,
            creationDate: now,
            modificationDate: now,
            lastAccessedDate: now,
            location: .downloads
        )

        let stubFS = StubFileSystemService(metadata: [desktopMeta, downloadsMeta])
        let pipeline: FileScanPipelineProtocol = FileScanPipeline()
        let ruleEngine = RuleEngine()
        let rules: [Rule] = []

        // When: running the scan pipeline
        let result = await pipeline.scanAndPersist(
            baseFolders: [.desktop, .downloads],
            scanOptions: .defaults,
            fileSystemService: stubFS,
            ruleEngine: ruleEngine,
            rules: rules,
            context: context
        )

        // Then: we should get two FileItem records with matching locations
        XCTAssertEqual(result.files.count, 2)

        let byPath = Dictionary(uniqueKeysWithValues: result.files.map { ($0.path, $0) })
        XCTAssertEqual(byPath[desktopMeta.path]?.location, .desktop)
        XCTAssertEqual(byPath[downloadsMeta.path]?.location, .downloads)
    }

    func testScanAndPersist_ReusesMetadataRecordForRescan() async throws {
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)

        let now = Date()
        let path = "/Users/test/Desktop/report.txt"
        let metadata = FileMetadata(
            path: path,
            sizeInBytes: 1024,
            creationDate: now,
            modificationDate: now,
            lastAccessedDate: now,
            location: .desktop,
            scanRootPath: "/Users/test/Desktop"
        )

        let stubFS = StubFileSystemService(metadata: [metadata], scannedRootPaths: ["/Users/test/Desktop"])
        let pipeline: FileScanPipelineProtocol = FileScanPipeline()

        let firstResult = await pipeline.scanAndPersist(
            baseFolders: [.desktop],
            scanOptions: .defaults,
            fileSystemService: stubFS,
            ruleEngine: RuleEngine(),
            rules: [],
            context: context
        )

        let secondResult = await pipeline.scanAndPersist(
            baseFolders: [.desktop],
            scanOptions: .defaults,
            fileSystemService: stubFS,
            ruleEngine: RuleEngine(),
            rules: [],
            context: context
        )

        XCTAssertEqual(firstResult.files.count, 1)
        XCTAssertEqual(secondResult.files.count, 1)

        let verificationContext = ModelContext(container)
        let records = try verificationContext.fetch(FetchDescriptor<FileMetadataRecord>())
        XCTAssertEqual(records.count, 1, "Rescanning the same file should reuse the existing metadata row")
        XCTAssertEqual(records.first?.canonicalIdentity, FileMetadataFoundationService.pathFallbackCanonicalIdentity(for: path))
    }

    func testScanAndPersist_StrongProjectInferencePopulatesMetadataAssociation() async throws {
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.autoProjectAssociation, true)

        let now = Date()
        let rootPath = "/Users/test/Desktop"
        let filePath = "\(rootPath)/project-note.txt"
        let metadata = FileMetadata(
            path: filePath,
            sizeInBytes: 128,
            creationDate: now,
            modificationDate: now,
            lastAccessedDate: now,
            location: .desktop,
            scanRootPath: rootPath
        )

        try insertProjectCluster(
            filePath: filePath,
            suggestedFolderName: "Alpha",
            confidenceScore: 0.92
        )
        try insertProjectCluster(
            filePath: filePath,
            suggestedFolderName: "Beta",
            confidenceScore: 0.70
        )
        try insertProjectCluster(
            filePath: "\(rootPath)/unrelated-note.txt",
            suggestedFolderName: "Gamma",
            confidenceScore: 0.99
        )

        let pipeline: FileScanPipelineProtocol = FileScanPipeline()

        let result = await pipeline.scanAndPersist(
            baseFolders: [.desktop],
            scanOptions: .defaults,
            fileSystemService: StubFileSystemService(metadata: [metadata], scannedRootPaths: [rootPath]),
            ruleEngine: RuleEngine(),
            rules: [],
            context: context
        )

        XCTAssertEqual(result.files.count, 1)

        let verificationContext = ModelContext(container)
        let record = try XCTUnwrap(
            verificationContext
                .fetch(FetchDescriptor<FileMetadataRecord>(predicate: #Predicate { $0.lastKnownPath == filePath }))
                .first
        )
        XCTAssertEqual(record.projectAssociation, "Alpha")
    }

    func testScanAndPersist_WeakProjectInferenceDoesNotWriteAssociation() async throws {
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.autoProjectAssociation, true)

        let now = Date()
        let rootPath = "/Users/test/Desktop"
        let filePath = "\(rootPath)/conflicting-note.txt"
        let metadata = FileMetadata(
            path: filePath,
            sizeInBytes: 128,
            creationDate: now,
            modificationDate: now,
            lastAccessedDate: now,
            location: .desktop,
            scanRootPath: rootPath
        )

        try insertProjectCluster(
            filePath: filePath,
            suggestedFolderName: "Alpha",
            confidenceScore: 0.90
        )
        try insertProjectCluster(
            filePath: filePath,
            suggestedFolderName: "Beta",
            confidenceScore: 0.80
        )

        let pipeline: FileScanPipelineProtocol = FileScanPipeline()

        _ = await pipeline.scanAndPersist(
            baseFolders: [.desktop],
            scanOptions: .defaults,
            fileSystemService: StubFileSystemService(metadata: [metadata], scannedRootPaths: [rootPath]),
            ruleEngine: RuleEngine(),
            rules: [],
            context: context
        )

        let verificationContext = ModelContext(container)
        let record = try XCTUnwrap(
            verificationContext
                .fetch(FetchDescriptor<FileMetadataRecord>(predicate: #Predicate { $0.lastKnownPath == filePath }))
                .first
        )
        XCTAssertNil(record.projectAssociation)
    }

    func testScanAndPersist_ScreenshotFilenameWritesScreenshotTag() async throws {
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.autoContentTags, true)

        let now = Date()
        let rootPath = "/Users/test/Desktop"
        let screenshotMetadata = FileMetadata(
            path: "\(rootPath)/Screenshot 2026-04-06 at 09.15.00.png",
            sizeInBytes: 2_048,
            creationDate: now,
            modificationDate: now,
            lastAccessedDate: now,
            location: .desktop,
            scanRootPath: rootPath
        )
        let screenshotPath = screenshotMetadata.path

        let pipeline: FileScanPipelineProtocol = FileScanPipeline()

        _ = await pipeline.scanAndPersist(
            baseFolders: [.desktop],
            scanOptions: .defaults,
            fileSystemService: StubFileSystemService(metadata: [screenshotMetadata], scannedRootPaths: [rootPath]),
            ruleEngine: RuleEngine(),
            rules: [],
            context: context
        )

        let verificationContext = ModelContext(container)
        let record = try XCTUnwrap(
            verificationContext
                .fetch(FetchDescriptor<FileMetadataRecord>(predicate: #Predicate { $0.lastKnownPath == screenshotPath }))
                .first
        )
        XCTAssertEqual(record.tags, ["screenshot"])
    }

    func testPersistMetadataRecords_NewRecordInitializesQueuedStatus() async throws {
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.durableWorkflowStatus, true)

        let now = Date(timeIntervalSince1970: 9_500)
        let rootPath = "/Users/test/Desktop"
        let filePath = "\(rootPath)/queued-on-discovery.txt"
        let metadata = FileMetadata(
            path: filePath,
            sizeInBytes: 512,
            creationDate: now,
            modificationDate: now,
            lastAccessedDate: now,
            location: .desktop,
            scanRootPath: rootPath
        )

        let pipeline: FileScanPipelineProtocol = FileScanPipeline()

        _ = await pipeline.scanAndPersist(
            baseFolders: [.desktop],
            scanOptions: .defaults,
            fileSystemService: StubFileSystemService(metadata: [metadata], scannedRootPaths: [rootPath]),
            ruleEngine: RuleEngine(),
            rules: [],
            context: context
        )

        let record = try XCTUnwrap(fetchMetadataRecord(path: filePath))
        XCTAssertEqual(record.workflowStatus, .queued)
    }

    func testPersistMetadataRecords_ExistingLegacyRecordDoesNotBackfillQueuedStatus() async throws {
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.durableWorkflowStatus, true)

        let now = Date(timeIntervalSince1970: 9_501)
        let rootPath = "/Users/test/Desktop"
        let filePath = "\(rootPath)/legacy-record.txt"
        let metadataService = FileMetadataFoundationService(modelContext: context)
        let existingRecord = try XCTUnwrap(
            metadataService.upsertRecordWithoutSaving(
                for: filePath,
                displayName: "legacy-record.txt",
                fileExtension: "txt",
                timestamp: now.addingTimeInterval(-60)
            )
        )
        try context.save()
        XCTAssertNil(existingRecord.workflowStatus)

        let metadata = FileMetadata(
            path: filePath,
            sizeInBytes: 256,
            creationDate: now,
            modificationDate: now,
            lastAccessedDate: now,
            location: .desktop,
            scanRootPath: rootPath
        )
        let pipeline: FileScanPipelineProtocol = FileScanPipeline()

        _ = await pipeline.scanAndPersist(
            baseFolders: [.desktop],
            scanOptions: .defaults,
            fileSystemService: StubFileSystemService(metadata: [metadata], scannedRootPaths: [rootPath]),
            ruleEngine: RuleEngine(),
            rules: [],
            context: context
        )

        let records = try context.fetch(FetchDescriptor<FileMetadataRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertNil(records.first?.workflowStatus)
    }

    func testPersistMetadataRecords_DiscoveryHelperIsSkippedWhenFeatureDisabled() async throws {
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.durableWorkflowStatus, false)

        let now = Date(timeIntervalSince1970: 9_502)
        let rootPath = "/Users/test/Desktop"
        let filePath = "\(rootPath)/no-queued-write.txt"
        let metadata = FileMetadata(
            path: filePath,
            sizeInBytes: 128,
            creationDate: now,
            modificationDate: now,
            lastAccessedDate: now,
            location: .desktop,
            scanRootPath: rootPath
        )

        let pipeline: FileScanPipelineProtocol = FileScanPipeline()

        _ = await pipeline.scanAndPersist(
            baseFolders: [.desktop],
            scanOptions: .defaults,
            fileSystemService: StubFileSystemService(metadata: [metadata], scannedRootPaths: [rootPath]),
            ruleEngine: RuleEngine(),
            rules: [],
            context: context
        )

        let record = try XCTUnwrap(fetchMetadataRecord(path: filePath))
        XCTAssertNil(record.workflowStatus)
    }

    func testScanAndPersist_MetadataFoundationDisabledSkipsMetadataWrites() async throws {
        FeatureFlagService.shared.setEnabled(.metadataFoundation, false)

        let now = Date()
        let metadata = FileMetadata(
            path: "/Users/test/Desktop/disabled-guard.txt",
            sizeInBytes: 256,
            creationDate: now,
            modificationDate: now,
            lastAccessedDate: now,
            location: .desktop,
            scanRootPath: "/Users/test/Desktop"
        )

        let trackingService = TrackingMetadataFoundationService()
        let pipeline = FileScanPipeline(metadataFoundationServiceFactory: { _ in
            trackingService
        })

        _ = await pipeline.scanAndPersist(
            baseFolders: [.desktop],
            scanOptions: .defaults,
            fileSystemService: StubFileSystemService(metadata: [metadata], scannedRootPaths: ["/Users/test/Desktop"]),
            ruleEngine: RuleEngine(),
            rules: [],
            context: context
        )

        let records = try context.fetch(FetchDescriptor<FileMetadataRecord>())
        XCTAssertEqual(records.count, 0, "Disabled metadata foundation should not write metadata rows")
        XCTAssertEqual(trackingService.upsertCalls, 0, "Factory should not be invoked when the feature flag is disabled")
    }

    func testEvaluateAndPersistExplicitFiles_UpsertsMetadataRecordWhenFeatureEnabled() async throws {
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)

        let now = Date()
        let rootPath = "/Users/test/Downloads"
        let explicitMetadata = FileMetadata(
            path: "\(rootPath)/invoice.pdf",
            sizeInBytes: 4096,
            creationDate: now,
            modificationDate: now,
            lastAccessedDate: now,
            location: .downloads,
            scanRootPath: rootPath
        )

        let pipeline: FileScanPipelineProtocol = FileScanPipeline()

        let result = await pipeline.evaluateAndPersistExplicitFiles(
            files: [explicitMetadata],
            scannedRootPaths: [rootPath],
            reconcileMissingFiles: false,
            ruleEngine: RuleEngine(),
            rules: [],
            context: context
        )

        XCTAssertEqual(result.files.count, 1)

        let verificationContext = ModelContext(container)
        let records = try verificationContext.fetch(FetchDescriptor<FileMetadataRecord>())
        XCTAssertEqual(records.count, 1, "Explicit-file evaluation should upsert a metadata record when the feature is enabled")
        XCTAssertEqual(records.first?.canonicalIdentity, FileMetadataFoundationService.pathFallbackCanonicalIdentity(for: explicitMetadata.path))
    }

    func testEvaluateAndPersistExplicitFiles_ProjectLikeDestinationWritesAssociation() async throws {
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.autoProjectAssociation, true)

        let temp = try TemporaryDirectory()
        defer { temp.cleanup() }

        let projectsFolder = try temp.createDirectory(name: "Projects/Alpha")
        let destination = try Destination.folder(from: projectsFolder)
        let resolvedDestinationURL = try XCTUnwrap(destination.resolve()?.url)
        XCTAssertEqual(
            resolvedDestinationURL.standardizedFileURL.path,
            projectsFolder.standardizedFileURL.path
        )
        let explicitPath = temp.url.appendingPathComponent("Inbox/report.pdf").path
        let explicitMetadata = FileMetadata(
            path: explicitPath,
            sizeInBytes: 4096,
            creationDate: Date(),
            modificationDate: Date(),
            lastAccessedDate: Date(),
            location: .downloads,
            scanRootPath: temp.url.appendingPathComponent("Inbox").path,
            destination: destination
        )

        let pipeline: FileScanPipelineProtocol = FileScanPipeline()

        _ = await pipeline.evaluateAndPersistExplicitFiles(
            files: [explicitMetadata],
            scannedRootPaths: [temp.url.path],
            reconcileMissingFiles: false,
            ruleEngine: RuleEngine(),
            rules: [],
            context: context
        )

        let verificationContext = ModelContext(container)
        let record = try XCTUnwrap(
            verificationContext
                .fetch(FetchDescriptor<FileMetadataRecord>(predicate: #Predicate { $0.lastKnownPath == explicitPath }))
                .first
        )
        XCTAssertEqual(record.projectAssociation, "Alpha")
    }

    func testEvaluateAndPersistExplicitFiles_CurrentExplicitDestinationWinsOverStalePersistedDestination() async throws {
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.autoProjectAssociation, true)

        let temp = try TemporaryDirectory()
        defer { temp.cleanup() }

        let projectsFolder = try temp.createDirectory(name: "Projects/Alpha")
        let destination = try Destination.folder(from: projectsFolder)
        let explicitPath = temp.url.appendingPathComponent("Inbox/report.pdf").path
        let staleExisting = FileItem(
            path: explicitPath,
            sizeInBytes: 4096,
            creationDate: Date(),
            modificationDate: Date(),
            lastAccessedDate: Date(),
            location: .downloads,
            scanRootPath: temp.url.appendingPathComponent("Inbox").path,
            destination: .mockFolder("Documents"),
            originalSuggestedDestination: .mockFolder("Documents"),
            status: .ready
        )
        context.insert(staleExisting)
        try context.save()

        let explicitMetadata = FileMetadata(
            path: explicitPath,
            sizeInBytes: 4096,
            creationDate: Date(),
            modificationDate: Date(),
            lastAccessedDate: Date(),
            location: .downloads,
            scanRootPath: temp.url.appendingPathComponent("Inbox").path,
            destination: destination
        )

        let pipeline: FileScanPipelineProtocol = FileScanPipeline()

        _ = await pipeline.evaluateAndPersistExplicitFiles(
            files: [explicitMetadata],
            scannedRootPaths: [temp.url.path],
            reconcileMissingFiles: false,
            ruleEngine: RuleEngine(),
            rules: [],
            context: context
        )

        let verificationContext = ModelContext(container)
        let record = try XCTUnwrap(
            verificationContext
                .fetch(FetchDescriptor<FileMetadataRecord>(predicate: #Predicate { $0.lastKnownPath == explicitPath }))
                .first
        )
        XCTAssertEqual(record.projectAssociation, "Alpha")
    }

    func testEvaluateAndPersistExplicitFiles_NonProjectDestinationDoesNotWriteAssociation() async throws {
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.autoProjectAssociation, true)

        let temp = try TemporaryDirectory()
        defer { temp.cleanup() }

        let screenshotsFolder = try temp.createDirectory(name: "Pictures/Screenshots")
        let destination = try Destination.folder(from: screenshotsFolder)
        let explicitPath = temp.url.appendingPathComponent("Inbox/screen.png").path
        let explicitMetadata = FileMetadata(
            path: explicitPath,
            sizeInBytes: 1024,
            creationDate: Date(),
            modificationDate: Date(),
            lastAccessedDate: Date(),
            location: .pictures,
            scanRootPath: temp.url.appendingPathComponent("Inbox").path,
            destination: destination
        )

        let pipeline: FileScanPipelineProtocol = FileScanPipeline()

        _ = await pipeline.evaluateAndPersistExplicitFiles(
            files: [explicitMetadata],
            scannedRootPaths: [temp.url.path],
            reconcileMissingFiles: false,
            ruleEngine: RuleEngine(),
            rules: [],
            context: context
        )

        let verificationContext = ModelContext(container)
        let record = try XCTUnwrap(
            verificationContext
                .fetch(FetchDescriptor<FileMetadataRecord>(predicate: #Predicate { $0.lastKnownPath == explicitPath }))
                .first
        )
        XCTAssertNil(record.projectAssociation)
    }

    func testEvaluateAndPersistExplicitFiles_SkipsProjectAssociationWhenFeatureDisabled() async throws {
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.autoProjectAssociation, false)

        let temp = try TemporaryDirectory()
        defer { temp.cleanup() }

        let projectsFolder = try temp.createDirectory(name: "Projects/Atlas")
        let destination = try Destination.folder(from: projectsFolder)
        let explicitPath = temp.url.appendingPathComponent("Inbox/atlas.pdf").path
        let explicitMetadata = FileMetadata(
            path: explicitPath,
            sizeInBytes: 2048,
            creationDate: Date(),
            modificationDate: Date(),
            lastAccessedDate: Date(),
            location: .downloads,
            scanRootPath: temp.url.appendingPathComponent("Inbox").path,
            destination: destination
        )

        let pipeline: FileScanPipelineProtocol = FileScanPipeline()

        _ = await pipeline.evaluateAndPersistExplicitFiles(
            files: [explicitMetadata],
            scannedRootPaths: [temp.url.path],
            reconcileMissingFiles: false,
            ruleEngine: RuleEngine(),
            rules: [],
            context: context
        )

        let verificationContext = ModelContext(container)
        let record = try XCTUnwrap(
            verificationContext
                .fetch(FetchDescriptor<FileMetadataRecord>(predicate: #Predicate { $0.lastKnownPath == explicitPath }))
                .first
        )
        XCTAssertNil(record.projectAssociation)
    }

    func testEvaluateAndPersistExplicitFiles_DestinationAliasWritesInvoiceTag() async throws {
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.autoContentTags, true)

        let temp = try TemporaryDirectory()
        defer { temp.cleanup() }

        let invoicesFolder = try temp.createDirectory(name: "Documents/Financial")
        let destination = try Destination.folder(from: invoicesFolder, displayName: "Invoices")
        let explicitPath = temp.url.appendingPathComponent("Inbox/report.pdf").path
        let explicitMetadata = FileMetadata(
            path: explicitPath,
            sizeInBytes: 4_096,
            creationDate: Date(),
            modificationDate: Date(),
            lastAccessedDate: Date(),
            location: .downloads,
            scanRootPath: temp.url.appendingPathComponent("Inbox").path,
            destination: destination
        )

        let pipeline: FileScanPipelineProtocol = FileScanPipeline()

        _ = await pipeline.evaluateAndPersistExplicitFiles(
            files: [explicitMetadata],
            scannedRootPaths: [temp.url.path],
            reconcileMissingFiles: false,
            ruleEngine: RuleEngine(),
            rules: [],
            context: context
        )

        let verificationContext = ModelContext(container)
        let record = try XCTUnwrap(
            verificationContext
                .fetch(FetchDescriptor<FileMetadataRecord>(predicate: #Predicate { $0.lastKnownPath == explicitPath }))
                .first
        )
        XCTAssertEqual(record.tags, ["invoice"])
    }

    func testEvaluateAndPersistExplicitFiles_WeakSignalWritesNoTags() async throws {
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.autoContentTags, true)

        let temp = try TemporaryDirectory()
        defer { temp.cleanup() }

        let archiveFolder = try temp.createDirectory(name: "Archive")
        let destination = try Destination.folder(from: archiveFolder, displayName: "Archive")
        let explicitPath = temp.url.appendingPathComponent("Inbox/notes.pdf").path
        let explicitMetadata = FileMetadata(
            path: explicitPath,
            sizeInBytes: 2_048,
            creationDate: Date(),
            modificationDate: Date(),
            lastAccessedDate: Date(),
            location: .downloads,
            scanRootPath: temp.url.appendingPathComponent("Inbox").path,
            destination: destination
        )

        let pipeline: FileScanPipelineProtocol = FileScanPipeline()

        _ = await pipeline.evaluateAndPersistExplicitFiles(
            files: [explicitMetadata],
            scannedRootPaths: [temp.url.path],
            reconcileMissingFiles: false,
            ruleEngine: RuleEngine(),
            rules: [],
            context: context
        )

        let verificationContext = ModelContext(container)
        let record = try XCTUnwrap(
            verificationContext
                .fetch(FetchDescriptor<FileMetadataRecord>(predicate: #Predicate { $0.lastKnownPath == explicitPath }))
                .first
        )
        XCTAssertEqual(record.tags, [])
    }

    func testScanAndPersist_MetadataUpsertFailureStillPersistsFileItems() async throws {
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)

        let now = Date()
        let metadata = FileMetadata(
            path: "/Users/test/Desktop/failure-case.txt",
            sizeInBytes: 512,
            creationDate: now,
            modificationDate: now,
            lastAccessedDate: now,
            location: .desktop,
            scanRootPath: "/Users/test/Desktop"
        )

        let stubFS = StubFileSystemService(metadata: [metadata], scannedRootPaths: ["/Users/test/Desktop"])
        let pipeline = FileScanPipeline(metadataFoundationServiceFactory: { _ in
            FailingMetadataFoundationService()
        })

        let result = await pipeline.scanAndPersist(
            baseFolders: [.desktop],
            scanOptions: .defaults,
            fileSystemService: stubFS,
            ruleEngine: RuleEngine(),
            rules: [],
            context: context
        )

        XCTAssertEqual(result.files.count, 1, "Metadata failures should not block file-item persistence")
        let persistedFiles = try context.fetch(FetchDescriptor<FileItem>())
        XCTAssertEqual(persistedFiles.count, 1, "FileItem persistence should still succeed when metadata upserts fail")
    }

    func testScanAndPersist_SkipsMetadataWritesWhenPrimaryPersistenceFails() async throws {
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)

        let now = Date()
        let metadata = FileMetadata(
            path: "/Users/test/Desktop/primary-failure.txt",
            sizeInBytes: 128,
            creationDate: now,
            modificationDate: now,
            lastAccessedDate: now,
            location: .desktop,
            scanRootPath: "/Users/test/Desktop"
        )

        let trackingService = TrackingMetadataFoundationService()
        enum ForcedSaveError: LocalizedError {
            case failed

            var errorDescription: String? {
                "primary save failed"
            }
        }
        let pipeline = FileScanPipeline(
            metadataFoundationServiceFactory: { _ in trackingService },
            primaryPersistenceSaveErrorProvider: { ForcedSaveError.failed }
        )

        let result = await pipeline.scanAndPersist(
            baseFolders: [.desktop],
            scanOptions: .defaults,
            fileSystemService: StubFileSystemService(metadata: [metadata], scannedRootPaths: ["/Users/test/Desktop"]),
            ruleEngine: RuleEngine(),
            rules: [],
            context: context
        )

        XCTAssertEqual(result.files.count, 1, "Primary persistence should still report the discovered file even when save fails")
        XCTAssertNotNil(result.errorSummary, "Primary persistence failure should surface in the scan result")
        XCTAssertEqual(trackingService.upsertCalls, 0, "Metadata writes should be skipped when primary persistence fails")

        let records = try context.fetch(FetchDescriptor<FileMetadataRecord>())
        XCTAssertEqual(records.count, 0, "No metadata rows should be written after a failed primary save")
    }

    private func fetchMetadataRecord(path: String) throws -> FileMetadataRecord? {
        let verificationContext = ModelContext(container)
        return try verificationContext.fetch(
            FetchDescriptor<FileMetadataRecord>(
                predicate: #Predicate { $0.lastKnownPath == path }
            )
        ).first
    }

    func testScanAndPersist_StoresScanRootAndRelativeParentPath() async throws {
        let now = Date()
        let rootPath = "/Users/test/Desktop"
        let nestedMeta = FileMetadata(
            path: "\(rootPath)/Projects/Forma/spec.md",
            sizeInBytes: 128,
            creationDate: now,
            modificationDate: now,
            lastAccessedDate: now,
            location: .desktop,
            scanRootPath: rootPath,
            relativeParentPath: "Projects/Forma"
        )

        let stubFS = StubFileSystemService(metadata: [nestedMeta], scannedRootPaths: [rootPath])
        let pipeline: FileScanPipelineProtocol = FileScanPipeline()

        let result = await pipeline.scanAndPersist(
            baseFolders: [.desktop],
            scanOptions: .defaults,
            fileSystemService: stubFS,
            ruleEngine: RuleEngine(),
            rules: [],
            context: context
        )

        XCTAssertEqual(result.files.count, 1)
        let file = try XCTUnwrap(result.files.first)
        XCTAssertEqual(file.scanRootPath, rootPath)
        XCTAssertEqual(file.relativeParentPath, "Projects/Forma")
        XCTAssertEqual(file.relativePathContextLabel, "Desktop/Projects/Forma")
    }

    func testScanAndPersist_ReconcilesMissingPendingFilesUnderScannedRoot() async throws {
        let rootPath = "/Users/test/Desktop"

        let stalePending = FileItem(
            path: "\(rootPath)/Old/old.txt",
            sizeInBytes: 50,
            creationDate: Date(),
            location: .desktop,
            scanRootPath: rootPath,
            relativeParentPath: "Old",
            destination: nil,
            status: .pending
        )
        context.insert(stalePending)

        let completedFile = FileItem(
            path: "\(rootPath)/Completed/keep.txt",
            sizeInBytes: 50,
            creationDate: Date(),
            location: .desktop,
            scanRootPath: rootPath,
            relativeParentPath: "Completed",
            destination: nil,
            status: .completed
        )
        context.insert(completedFile)
        try context.save()

        let activeMeta = FileMetadata(
            path: "\(rootPath)/New/new.txt",
            sizeInBytes: 75,
            creationDate: Date(),
            modificationDate: Date(),
            lastAccessedDate: Date(),
            location: .desktop,
            scanRootPath: rootPath,
            relativeParentPath: "New"
        )

        let stubFS = StubFileSystemService(metadata: [activeMeta], scannedRootPaths: [rootPath])
        let pipeline: FileScanPipelineProtocol = FileScanPipeline()

        _ = await pipeline.scanAndPersist(
            baseFolders: [.desktop],
            scanOptions: .defaults,
            fileSystemService: stubFS,
            ruleEngine: RuleEngine(),
            rules: [],
            context: context
        )

        let files = try context.fetch(FetchDescriptor<FileItem>())
        XCTAssertFalse(files.contains { $0.path == stalePending.path }, "Stale pending file should be deleted during reconciliation")
        XCTAssertTrue(files.contains { $0.path == completedFile.path }, "Completed files should be preserved")
        XCTAssertTrue(files.contains { $0.path == activeMeta.path }, "Current scan files should remain")
    }

    func testScanAndPersist_PreservesExistingDestinationForNonPendingFileWhenRescanHasNoSuggestion() async throws {
        let path = "/Users/test/Desktop/already-ready.pdf"
        let existing = FileItem(
            path: path,
            sizeInBytes: 100,
            creationDate: Date(),
            location: .desktop,
            destination: .mockFolder("Documents"),
            originalSuggestedDestination: .mockFolder("Documents"),
            status: .ready
        )
        context.insert(existing)
        try context.save()

        let rescannedMeta = FileMetadata(
            path: path,
            sizeInBytes: 200,
            creationDate: Date(),
            modificationDate: Date(),
            lastAccessedDate: Date(),
            location: .desktop,
            destination: nil,
            status: .pending
        )

        let stubFS = StubFileSystemService(metadata: [rescannedMeta], scannedRootPaths: ["/Users/test/Desktop"])
        let pipeline: FileScanPipelineProtocol = FileScanPipeline()

        _ = await pipeline.scanAndPersist(
            baseFolders: [.desktop],
            scanOptions: .defaults,
            fileSystemService: stubFS,
            ruleEngine: RuleEngine(),
            rules: [],
            context: context
        )

        let refreshed = try XCTUnwrap(context.fetch(FetchDescriptor<FileItem>(predicate: #Predicate { $0.path == path })).first)
        XCTAssertEqual(refreshed.status, .ready)
        XCTAssertEqual(refreshed.destination?.displayName, "Documents")
        XCTAssertEqual(refreshed.originalSuggestedDestination?.displayName, "Documents")
        XCTAssertEqual(refreshed.sizeInBytes, 200, "Metadata fields should still refresh during rescan")
    }

    func testScanAndPersist_MarksFileCompletedWhenAlreadyInDestinationFolder() async throws {
        let temp = try TemporaryDirectory()
        defer { temp.cleanup() }

        let destinationFolder = try temp.createDirectory(name: "Desktop/Screenshots")
        let fileURL = try temp.createFile(name: "Desktop/Screenshots/screen.png", contents: "pixels")
        let destination = try Destination.folder(from: destinationFolder)
        let desktopRoot = temp.url.appendingPathComponent("Desktop").path

        let metadata = FileMetadata(
            path: fileURL.path,
            sizeInBytes: 6,
            creationDate: Date(),
            modificationDate: Date(),
            lastAccessedDate: Date(),
            location: .desktop,
            scanRootPath: desktopRoot,
            relativeParentPath: "Screenshots"
        )

        let stubFS = StubFileSystemService(metadata: [metadata], scannedRootPaths: [desktopRoot])
        let pipeline: FileScanPipelineProtocol = FileScanPipeline()
        let rule = Rule(
            name: "Screenshots Rule",
            conditions: [.fileExtension("png")],
            logicalOperator: .single,
            actionType: .move,
            destination: destination,
            isEnabled: true
        )

        let result = await pipeline.scanAndPersist(
            baseFolders: [.desktop],
            scanOptions: .defaults,
            fileSystemService: stubFS,
            ruleEngine: RuleEngine(),
            rules: [rule],
            context: context
        )

        let file = try XCTUnwrap(result.files.first)
        XCTAssertEqual(file.status, .completed)
        XCTAssertNil(file.matchReason, "Completed in-place files should not remain in review suggestion state")
    }

    func testEvaluateAndPersistExplicitFiles_DoesNotReconcileMissingFilesWhenDisabled() async throws {
        let rootPath = "/Users/test/Desktop"

        let existingSibling = FileItem(
            path: "\(rootPath)/keep-me.txt",
            sizeInBytes: 64,
            creationDate: Date(),
            location: .desktop,
            scanRootPath: rootPath,
            destination: nil,
            status: .pending
        )
        context.insert(existingSibling)
        try context.save()

        let explicitMetadata = FileMetadata(
            path: "\(rootPath)/organize-me.txt",
            sizeInBytes: 96,
            creationDate: Date(),
            modificationDate: Date(),
            lastAccessedDate: Date(),
            location: .desktop,
            scanRootPath: rootPath
        )

        let pipeline: FileScanPipelineProtocol = FileScanPipeline()

        _ = await pipeline.evaluateAndPersistExplicitFiles(
            files: [explicitMetadata],
            scannedRootPaths: [rootPath],
            reconcileMissingFiles: false,
            ruleEngine: RuleEngine(),
            rules: [],
            context: context
        )

        let files = try context.fetch(FetchDescriptor<FileItem>())
        XCTAssertTrue(files.contains { $0.path == existingSibling.path }, "Explicit ingress should not delete other files under the same root")
        XCTAssertTrue(files.contains { $0.path == explicitMetadata.path }, "Explicitly scanned files should still persist")
    }
}
