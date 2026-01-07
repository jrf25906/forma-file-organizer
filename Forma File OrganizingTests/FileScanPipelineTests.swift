import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class FileScanPipelineTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        let schema = Schema([FileItem.self, Rule.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
    }

    override func tearDown() async throws {
        // Allow async TaskGroup/TaskLocal cleanup to complete before deallocating
        // to prevent memory corruption during Swift Concurrency internal cleanup.
        try await Task.sleep(for: .milliseconds(50))

        context = nil
        container = nil
    }

    /// Simple FileSystemServiceProtocol stub that returns predetermined metadata
    private final class StubFileSystemService: FileSystemServiceProtocol {
        let metadata: [FileMetadata]

        init(metadata: [FileMetadata]) {
            self.metadata = metadata
        }

        func scanDesktop() async throws -> [FileMetadata] { metadata }
        func scanDownloads() async throws -> [FileMetadata] { metadata }
        func scanDocuments() async throws -> [FileMetadata] { metadata }
        func scanPictures() async throws -> [FileMetadata] { metadata }
        func scanMusic() async throws -> [FileMetadata] { metadata }

        func scanAllFolders(customFolders: [CustomFolder]) async -> ScanResult {
            ScanResult(files: metadata, errors: [:])
        }

        func scan(baseFolders: [FolderLocation], customFolders: [CustomFolder]) async -> ScanResult {
            ScanResult(files: metadata, errors: [:])
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
            customFolders: [],
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
}
