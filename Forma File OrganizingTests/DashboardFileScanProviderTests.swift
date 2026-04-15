import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class DashboardFileScanProviderTests: XCTestCase {
    func testDeltaRequestScansTouchedFilesDeletesRemovedRowsAndReturnsAggregateMetrics() async throws {
        let fileSystemService = MockFileSystemService()
        let pipeline = MockFileScanPipeline()
        let provider = DashboardFileScanProvider(
            pipeline: pipeline,
            fileSystemService: fileSystemService,
            ruleEngine: RuleEngine()
        )
        let container = try ModelContainer(
            for: FileItem.self,
            Rule.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let temporaryDirectory = try TemporaryDirectory()
        defer { temporaryDirectory.cleanup() }

        let desktopRootURL = try temporaryDirectory.createDirectory(name: "Desktop")
        let downloadsRootURL = try temporaryDirectory.createDirectory(name: "Downloads")
        let updatedFileURL = try temporaryDirectory.createFile(name: "Desktop/report.txt", contents: "updated")
        let removedFileURL = temporaryDirectory.url(for: "Desktop/obsolete.txt")
        let untouchedFileURL = try temporaryDirectory.createFile(name: "Downloads/keep.txt", contents: "keep")

        let desktopRoot = desktopRootURL.path
        let downloadsRoot = downloadsRootURL.path
        let updatedPath = updatedFileURL.path
        let removedPath = removedFileURL.path
        let untouchedPath = untouchedFileURL.path

        context.insert(
            FileItem(
                path: updatedPath,
                sizeInBytes: 50,
                creationDate: Date(timeIntervalSince1970: 10),
                modificationDate: Date(timeIntervalSince1970: 10),
                location: .desktop,
                scanRootPath: desktopRoot,
                destination: nil,
                status: .pending
            )
        )
        context.insert(
            FileItem(
                path: removedPath,
                sizeInBytes: 25,
                creationDate: Date(timeIntervalSince1970: 20),
                modificationDate: Date(timeIntervalSince1970: 20),
                location: .desktop,
                scanRootPath: desktopRoot,
                destination: nil,
                status: .ready
            )
        )
        context.insert(
            FileItem(
                path: untouchedPath,
                sizeInBytes: 75,
                creationDate: Date(timeIntervalSince1970: 30),
                modificationDate: Date(timeIntervalSince1970: 30),
                location: .downloads,
                scanRootPath: downloadsRoot,
                destination: nil,
                status: .completed
            )
        )
        try context.save()

        let updatedMetadata = FileMetadata(
            path: updatedPath,
            sizeInBytes: 150,
            creationDate: Date(timeIntervalSince1970: 10),
            modificationDate: Date(timeIntervalSince1970: 40),
            lastAccessedDate: Date(timeIntervalSince1970: 40),
            location: .desktop,
            scanRootPath: desktopRoot,
            status: .ready
        )
        fileSystemService.explicitSelectionResult = ExplicitSelectionScanResult(
            files: [updatedMetadata],
            skippedItems: [],
            scannedRootPaths: [desktopRoot]
        )
        pipeline.onEvaluateExplicitFiles = { files, _, _, context in
            for file in files {
                let existing = try? context.fetch(FetchDescriptor<FileItem>()).first(where: { $0.path == file.path })
                if let existing {
                    _ = existing.updateMetadata(
                        sizeInBytes: file.sizeInBytes,
                        modificationDate: file.modificationDate,
                        lastAccessedDate: file.lastAccessedDate
                    )
                    existing.scanRootPath = file.scanRootPath
                    existing.status = file.status
                } else {
                    context.insert(FileItem.from(file))
                }
            }
            try? context.save()
        }
        pipeline.explicitSelectionResult = FileScanPipeline.ScanResult(
            files: [FileItem.from(updatedMetadata)],
            errorSummary: nil,
            rawErrors: [:],
            scannedRootPaths: [desktopRoot]
        )

        let changeSet = WatchedFolderChangeSet(
            touchedRoots: [desktopRoot],
            updatedPaths: [updatedPath],
            removedPaths: [removedPath],
            requiresFallbackRootScan: false
        )

        let result = try await provider.scanFiles(
            context: context,
            request: .delta(changeSet)
        )

        XCTAssertEqual(fileSystemService.explicitSelectionCallCount, 1)
        XCTAssertEqual(fileSystemService.explicitSelectionRequestedURLs, [[URL(fileURLWithPath: updatedPath)]])
        XCTAssertEqual(pipeline.explicitScanCallCount, 1)
        XCTAssertEqual(pipeline.lastExplicitFiles.map(\.path), [updatedPath])
        XCTAssertEqual(pipeline.lastExplicitScannedRootPaths, [desktopRoot])
        XCTAssertEqual(pipeline.lastExplicitReconcileMissingFiles, false)

        let persistedFiles = try context.fetch(FetchDescriptor<FileItem>())
        XCTAssertEqual(Set(persistedFiles.map(\.path)), [updatedPath, untouchedPath])
        XCTAssertEqual(result.pendingCount, 0)
        XCTAssertEqual(result.readyCount, 1)
        XCTAssertEqual(result.organizedCount, 1)
        XCTAssertEqual(result.skippedCount, 0)
    }
}
