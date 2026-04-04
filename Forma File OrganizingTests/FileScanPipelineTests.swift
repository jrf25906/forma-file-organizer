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
        let schema = Schema([FileItem.self, Rule.self, FileMetadataRecord.self, FileOrganizationHistoryEntry.self])
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

        func upsertRecord(
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
