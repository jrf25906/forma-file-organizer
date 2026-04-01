import Darwin
import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class ExternalIngressCoordinatorTests: XCTestCase {
    private var defaults: UserDefaults!
    private var defaultsSuiteName: String!
    private var container: ModelContainer!
    private var context: ModelContext!
    private var fileSystemService: MockFileSystemService!
    private var pipeline: MockFileScanPipeline!

    override func setUp() async throws {
        try await super.setUp()

        let suiteName = "ExternalIngressCoordinatorTests.\(UUID().uuidString)"
        defaultsSuiteName = suiteName
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let schema = Schema([
            FileItem.self,
            Rule.self,
            ActivityItem.self,
            LearnedPattern.self,
            MLTrainingHistory.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = container.mainContext
        fileSystemService = MockFileSystemService()
        pipeline = MockFileScanPipeline()
    }

    override func tearDown() async throws {
        if let defaultsSuiteName {
            defaults?.removePersistentDomain(forName: defaultsSuiteName)
        }
        defaults = nil
        defaultsSuiteName = nil
        pipeline = nil
        fileSystemService = nil
        context = nil
        container = nil
        try await super.tearDown()
    }

    func testProcessPendingRequestRequiresOnboardingWithoutConsumingQueuedRequest() async throws {
        let tempDir = try TemporaryDirectory()
        defer { tempDir.cleanup() }

        let selectedFile = try tempDir.createFile(name: "invoice.pdf")
        let coordinator = makeCoordinator(onboardingCompleted: false)

        let queuedRequest = try coordinator.queueRequest(
            source: .finderService,
            urls: [selectedFile]
        )
        XCTAssertEqual(queuedRequest.items.count, 1)

        let disposition = await coordinator.processPendingRequestIfPossible()

        guard case .needsOnboarding = disposition else {
            return XCTFail("Expected coordinator to defer processing until onboarding completes")
        }

        XCTAssertNotNil(coordinator.pendingRequest)
        XCTAssertEqual(fileSystemService.explicitSelectionCallCount, 0)
    }

    func testProcessPendingRequestAutoOrganizesEligibleFilesAndPublishesReviewSession() async throws {
        let tempDir = try TemporaryDirectory()
        defer { tempDir.cleanup() }

        let reviewFileURL = try tempDir.createFile(name: "review.txt")
        let autoFileURL = try tempDir.createFile(name: "auto.txt")
        let folderURL = try tempDir.createDirectory(name: "Batch")
        _ = try tempDir.createFile(name: "Batch/folder-child.txt")

        let createdAt = Date(timeIntervalSince1970: 1_000)
        let folderChildMetadata = FileMetadata(
            path: folderURL.appendingPathComponent("folder-child.txt").path,
            sizeInBytes: 12,
            creationDate: createdAt,
            modificationDate: createdAt,
            lastAccessedDate: createdAt,
            location: .custom,
            scanRootPath: folderURL.path
        )
        let reviewMetadata = FileMetadata(
            path: reviewFileURL.path,
            sizeInBytes: 24,
            creationDate: createdAt,
            modificationDate: createdAt,
            lastAccessedDate: createdAt,
            location: .custom,
            scanRootPath: reviewFileURL.deletingLastPathComponent().path
        )
        let autoMetadata = FileMetadata(
            path: autoFileURL.path,
            sizeInBytes: 42,
            creationDate: createdAt,
            modificationDate: createdAt,
            lastAccessedDate: createdAt,
            location: .custom,
            scanRootPath: autoFileURL.deletingLastPathComponent().path
        )

        fileSystemService.explicitSelectionResult = ExplicitSelectionScanResult(
            files: [reviewMetadata, autoMetadata, folderChildMetadata],
            skippedItems: [
                ExternalIngressSkippedItem(
                    path: tempDir.url.appendingPathComponent("Alias.webloc").path,
                    reason: .unsupportedSelection,
                    message: "Alias files are not supported."
                )
            ],
            scannedRootPaths: [folderURL.path]
        )

        let autoItem = FileItem.from(autoMetadata)
        autoItem.status = .ready
        autoItem.destination = .mockFolder("Documents/Auto")
        autoItem.confidenceScore = 0.95

        let reviewItem = FileItem.from(reviewMetadata)
        reviewItem.status = .pending

        let folderChildItem = FileItem.from(folderChildMetadata)
        folderChildItem.status = .pending

        pipeline.explicitSelectionResult = FileScanPipeline.ScanResult(
            files: [reviewItem, autoItem, folderChildItem],
            errorSummary: nil,
            rawErrors: [:],
            scannedRootPaths: [folderURL.path]
        )

        var publishedSessions: [ExternalReviewSession?] = []
        var organizedPaths: [String] = []
        var activationCount = 0

        let coordinator = makeCoordinator(
            onboardingCompleted: true,
            activateApp: { activationCount += 1 },
            publishReviewSession: { session in publishedSessions.append(session) },
            eligibleFiles: { files in
                files.filter { $0.path == autoFileURL.path }
            },
            organizeFile: { file, _ in
                organizedPaths.append(file.path)
                file.status = .completed
                return true
            }
        )

        _ = try coordinator.queueRequest(
            source: .finderService,
            urls: [reviewFileURL, folderURL, autoFileURL]
        )

        let disposition = await coordinator.processPendingRequestIfPossible()

        guard case .processed(let result) = disposition else {
            return XCTFail("Expected coordinator to process queued request")
        }

        XCTAssertEqual(result.autoOrganizedCount, 1)
        XCTAssertEqual(Set(result.needsReviewPaths), Set([reviewFileURL.path, folderChildMetadata.path]))
        XCTAssertEqual(result.skippedItems.count, 1)
        XCTAssertEqual(organizedPaths, [autoFileURL.path])
        XCTAssertEqual(activationCount, 1, "Review work should activate the app")
        XCTAssertEqual(Set(publishedSessions.compactMap(\.?.reviewPaths).flatMap { $0 }), Set([reviewFileURL.path, folderChildMetadata.path]))
        XCTAssertNil(coordinator.pendingRequest)
    }

    func testProcessPendingRequestPublishesPromotionCandidateForSingleStandardFolderSelection() async throws {
        let tempDir = try TemporaryDirectory()
        defer { tempDir.cleanup() }

        let downloadsURL = actualUserHomeDirectory().appendingPathComponent("Downloads", isDirectory: true)
        let childURL = downloadsURL.appendingPathComponent("to-review.pdf")
        let createdAt = Date(timeIntervalSince1970: 2_000)
        let bookmarkSourceURL = try tempDir.createDirectory(name: "bookmark-source")
        let bookmarkData = try bookmarkSourceURL.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        let childMetadata = FileMetadata(
            path: childURL.path,
            sizeInBytes: 18,
            creationDate: createdAt,
            modificationDate: createdAt,
            lastAccessedDate: createdAt,
            location: .custom,
            scanRootPath: downloadsURL.path
        )

        let reviewItem = FileItem.from(childMetadata)
        reviewItem.status = .pending

        fileSystemService.explicitSelectionResult = ExplicitSelectionScanResult(
            files: [childMetadata],
            skippedItems: [],
            scannedRootPaths: [downloadsURL.path]
        )

        pipeline.explicitSelectionResult = FileScanPipeline.ScanResult(
            files: [reviewItem],
            errorSummary: nil,
            rawErrors: [:],
            scannedRootPaths: [downloadsURL.path]
        )

        var publishedSession: ExternalReviewSession?
        let coordinator = makeCoordinator(
            onboardingCompleted: true,
            publishReviewSession: { session in publishedSession = session },
            createBookmarkData: { url in
                XCTAssertEqual(url.standardizedFileURL.path, downloadsURL.standardizedFileURL.path)
                return bookmarkData
            }
        )

        _ = try coordinator.queueRequest(source: .finderService, urls: [downloadsURL])

        let disposition = await coordinator.processPendingRequestIfPossible()

        guard case .processed(let result) = disposition else {
            return XCTFail("Expected coordinator to process queued folder request")
        }

        XCTAssertEqual(result.needsReviewPaths, [childURL.path])
        XCTAssertEqual(publishedSession?.promotionCandidate?.folderType, .downloads)
        XCTAssertEqual(publishedSession?.promotionCandidate?.bookmarkData, bookmarkData)
    }

    func testProcessPendingRequestDoesNotPromoteArbitraryFolderNamedLikeStandardFolder() async throws {
        let tempDir = try TemporaryDirectory()
        defer { tempDir.cleanup() }

        let fauxDownloadsURL = try tempDir.createDirectory(name: "Downloads")
        let childURL = try tempDir.createFile(name: "Downloads/to-review.pdf")
        let createdAt = Date(timeIntervalSince1970: 2_500)
        let bookmarkData = try fauxDownloadsURL.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        let childMetadata = FileMetadata(
            path: childURL.path,
            sizeInBytes: 18,
            creationDate: createdAt,
            modificationDate: createdAt,
            lastAccessedDate: createdAt,
            location: .custom,
            scanRootPath: fauxDownloadsURL.path
        )

        let reviewItem = FileItem.from(childMetadata)
        reviewItem.status = .pending

        fileSystemService.explicitSelectionResult = ExplicitSelectionScanResult(
            files: [childMetadata],
            skippedItems: [],
            scannedRootPaths: [fauxDownloadsURL.path]
        )

        pipeline.explicitSelectionResult = FileScanPipeline.ScanResult(
            files: [reviewItem],
            errorSummary: nil,
            rawErrors: [:],
            scannedRootPaths: [fauxDownloadsURL.path]
        )

        var publishedSession: ExternalReviewSession?
        let coordinator = makeCoordinator(
            onboardingCompleted: true,
            publishReviewSession: { session in publishedSession = session },
            createBookmarkData: { url in
                XCTAssertEqual(url.standardizedFileURL.path, fauxDownloadsURL.standardizedFileURL.path)
                return bookmarkData
            }
        )

        _ = try coordinator.queueRequest(source: .finderService, urls: [fauxDownloadsURL])

        let disposition = await coordinator.processPendingRequestIfPossible()

        guard case .processed(let result) = disposition else {
            return XCTFail("Expected coordinator to process queued folder request")
        }

        XCTAssertEqual(result.needsReviewPaths, [childURL.path])
        XCTAssertNil(publishedSession?.promotionCandidate)
    }

    func testProcessPendingRequestDoesNotPromoteMixedFolderAndFileSelection() async throws {
        let tempDir = try TemporaryDirectory()
        defer { tempDir.cleanup() }

        let downloadsURL = actualUserHomeDirectory().appendingPathComponent("Downloads", isDirectory: true)
        let selectedFileURL = try tempDir.createFile(name: "extra.txt")
        let childURL = downloadsURL.appendingPathComponent("to-review.pdf")
        let createdAt = Date(timeIntervalSince1970: 2_750)
        let bookmarkSourceURL = try tempDir.createDirectory(name: "bookmark-source")
        let bookmarkData = try bookmarkSourceURL.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        let childMetadata = FileMetadata(
            path: childURL.path,
            sizeInBytes: 18,
            creationDate: createdAt,
            modificationDate: createdAt,
            lastAccessedDate: createdAt,
            location: .custom,
            scanRootPath: downloadsURL.path
        )

        let reviewItem = FileItem.from(childMetadata)
        reviewItem.status = .pending

        fileSystemService.explicitSelectionResult = ExplicitSelectionScanResult(
            files: [childMetadata],
            skippedItems: [],
            scannedRootPaths: [downloadsURL.path]
        )

        pipeline.explicitSelectionResult = FileScanPipeline.ScanResult(
            files: [reviewItem],
            errorSummary: nil,
            rawErrors: [:],
            scannedRootPaths: [downloadsURL.path]
        )

        var publishedSession: ExternalReviewSession?
        let coordinator = makeCoordinator(
            onboardingCompleted: true,
            publishReviewSession: { session in publishedSession = session },
            createBookmarkData: { url in
                if url.standardizedFileURL.path == downloadsURL.standardizedFileURL.path {
                    return bookmarkData
                }
                return nil
            }
        )

        _ = try coordinator.queueRequest(source: .finderService, urls: [downloadsURL, selectedFileURL])

        let disposition = await coordinator.processPendingRequestIfPossible()

        guard case .processed(let result) = disposition else {
            return XCTFail("Expected coordinator to process queued mixed selection")
        }

        XCTAssertEqual(result.needsReviewPaths, [childURL.path])
        XCTAssertNil(publishedSession?.promotionCandidate)
    }

    func testProcessPendingRequestSkippedOnlySelectionActivatesAppAndPublishesFeedbackSession() async throws {
        let tempDir = try TemporaryDirectory()
        defer { tempDir.cleanup() }

        let selectedAlias = try tempDir.createFile(name: "Selected.alias")

        fileSystemService.explicitSelectionResult = ExplicitSelectionScanResult(
            files: [],
            skippedItems: [
                ExternalIngressSkippedItem(
                    path: selectedAlias.path,
                    reason: .aliasSelection,
                    message: "Alias files need to be resolved before Forma can organize them."
                )
            ],
            scannedRootPaths: []
        )

        pipeline.explicitSelectionResult = FileScanPipeline.ScanResult(
            files: [],
            errorSummary: nil,
            rawErrors: [:],
            scannedRootPaths: []
        )

        var activationCount = 0
        var publishedSession: ExternalReviewSession?

        let coordinator = makeCoordinator(
            onboardingCompleted: true,
            activateApp: { activationCount += 1 },
            publishReviewSession: { session in publishedSession = session }
        )

        _ = try coordinator.queueRequest(source: .finderService, urls: [selectedAlias])

        let disposition = await coordinator.processPendingRequestIfPossible()

        guard case .processed(let result) = disposition else {
            return XCTFail("Expected coordinator to process queued request")
        }

        XCTAssertEqual(result.autoOrganizedCount, 0)
        XCTAssertTrue(result.needsReviewPaths.isEmpty)
        XCTAssertEqual(result.skippedItems.map(\.reason), [.aliasSelection])
        XCTAssertEqual(activationCount, 1, "Skipped-only requests should still surface feedback in the app")
        XCTAssertEqual(publishedSession?.reviewPaths, [])
        XCTAssertEqual(publishedSession?.skippedItems.map(\.reason), [.aliasSelection])
        XCTAssertNil(coordinator.pendingRequest)
    }

    func testProcessPendingRequestBookmarkCaptureFailurePublishesReauthorizationFeedback() async throws {
        let tempDir = try TemporaryDirectory()
        defer { tempDir.cleanup() }

        let selectedFile = try tempDir.createFile(name: "invoice.pdf")

        var activationCount = 0
        var publishedSession: ExternalReviewSession?

        let coordinator = makeCoordinator(
            onboardingCompleted: true,
            activateApp: { activationCount += 1 },
            publishReviewSession: { session in publishedSession = session },
            createBookmarkData: { _ in
                throw CocoaError(.fileReadNoPermission)
            }
        )

        _ = try coordinator.queueRequest(source: .finderService, urls: [selectedFile])

        let disposition = await coordinator.processPendingRequestIfPossible()

        guard case .processed(let result) = disposition else {
            return XCTFail("Expected coordinator to surface reauthorization feedback")
        }

        XCTAssertEqual(fileSystemService.explicitSelectionCallCount, 0)
        XCTAssertEqual(result.skippedItems.count, 1)
        XCTAssertEqual(result.skippedItems.first?.reason, .inaccessibleSelection)
        XCTAssertEqual(activationCount, 1)
        XCTAssertEqual(publishedSession?.reviewPaths, [])
        XCTAssertEqual(publishedSession?.skippedItems.first?.reason, .inaccessibleSelection)
        XCTAssertNil(coordinator.pendingRequest)
    }

    func testProcessPendingRequestInvalidBookmarkPublishesReauthorizationFeedbackWithoutScanningRawPath() async throws {
        let tempDir = try TemporaryDirectory()
        defer { tempDir.cleanup() }

        let selectedFile = try tempDir.createFile(name: "protected.pdf")

        let request = ExternalIngressRequest(
            id: UUID(),
            createdAt: Date(),
            source: .finderService,
            items: [
                ExternalIngressRequestItem(
                    path: selectedFile.path,
                    bookmarkData: Data([0x00, 0x01, 0x02]),
                    bookmarkCreationFailed: false,
                    kind: .fileURL
                )
            ]
        )
        defaults.set(try JSONEncoder().encode(request), forKey: "externalIngress.pendingRequest")

        var activationCount = 0
        var publishedSession: ExternalReviewSession?
        let coordinator = makeCoordinator(
            onboardingCompleted: true,
            activateApp: { activationCount += 1 },
            publishReviewSession: { session in publishedSession = session }
        )

        let disposition = await coordinator.processPendingRequestIfPossible()

        guard case .processed(let result) = disposition else {
            return XCTFail("Expected coordinator to surface reauthorization feedback")
        }

        XCTAssertEqual(fileSystemService.explicitSelectionCallCount, 0)
        XCTAssertEqual(result.skippedItems.count, 1)
        XCTAssertEqual(result.skippedItems.first?.reason, .inaccessibleSelection)
        XCTAssertEqual(activationCount, 1)
        XCTAssertEqual(publishedSession?.reviewPaths, [])
        XCTAssertEqual(publishedSession?.skippedItems.first?.reason, .inaccessibleSelection)
        XCTAssertNil(coordinator.pendingRequest)
    }

    private func makeCoordinator(
        onboardingCompleted: Bool,
        activateApp: @escaping @MainActor () -> Void = {},
        publishReviewSession: @escaping @MainActor (ExternalReviewSession?) -> Void = { _ in },
        eligibleFiles: @escaping @MainActor ([FileItem]) -> [FileItem] = { _ in [] },
        organizeFile: @escaping @MainActor (FileItem, ModelContext) async -> Bool = { _, _ in false },
        createBookmarkData: @escaping @MainActor (URL) throws -> Data? = { url in
            try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }
    ) -> ExternalIngressCoordinator {
        defaults.set(onboardingCompleted, forKey: "hasCompletedOnboarding")

        let coordinator = ExternalIngressCoordinator(
            defaults: defaults,
            activateApp: activateApp,
            publishReviewSession: publishReviewSession,
            eligibleFilesForAutoOrganize: eligibleFiles,
            organizeFile: organizeFile,
            createBookmarkData: createBookmarkData
        )
        coordinator.configure(
            modelContext: context,
            fileSystemService: fileSystemService,
            fileScanPipeline: pipeline,
            ruleEngine: RuleEngine()
        )
        return coordinator
    }

    private func actualUserHomeDirectory() -> URL {
        if let pw = getpwuid(getuid()) {
            return URL(fileURLWithPath: String(cString: pw.pointee.pw_dir))
        }

        return FileManager.default.homeDirectoryForCurrentUser
    }
}
