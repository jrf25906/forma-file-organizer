import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class DashboardScanRefreshControllerTests: XCTestCase {
    private final class TrackingAnalyticsDashboardViewModel: AnalyticsDashboardViewModel {
        private(set) var detectClustersCallCount = 0

        override func detectClusters(from allFiles: [FileItem], context: ModelContext) async {
            detectClustersCallCount += 1
        }
    }

    func testDeltaApplySkipsClusterRefreshAndRerunsActiveSearch() async throws {
        let scanViewModel = FileScanViewModel(
            fileSystemService: MockFileSystemService(),
            fileScanPipeline: MockFileScanPipeline()
        )
        let analyticsViewModel = TrackingAnalyticsDashboardViewModel(
            storageService: .shared,
            insightsService: InsightsService()
        )
        let controller = DashboardScanRefreshController(
            scanViewModel: scanViewModel,
            analyticsViewModel: analyticsViewModel,
            insightsService: InsightsService()
        )
        let container = try ModelContainer(
            for: FileItem.self,
            Rule.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let desktopRoot = "/Users/test/Desktop"
        let downloadsRoot = "/Users/test/Downloads"
        let updatedPath = "\(desktopRoot)/report.txt"
        let removedPath = "\(desktopRoot)/stale.txt"
        let retainedPath = "\(downloadsRoot)/keep.txt"

        scanViewModel._testSetFiles([
            FileItem(
                path: updatedPath,
                sizeInBytes: 50,
                creationDate: Date(timeIntervalSince1970: 10),
                modificationDate: Date(timeIntervalSince1970: 10),
                location: .desktop,
                scanRootPath: desktopRoot,
                destination: nil,
                status: .pending
            ),
            FileItem(
                path: removedPath,
                sizeInBytes: 25,
                creationDate: Date(timeIntervalSince1970: 15),
                modificationDate: Date(timeIntervalSince1970: 15),
                location: .desktop,
                scanRootPath: desktopRoot,
                destination: nil,
                status: .pending
            ),
            FileItem(
                path: retainedPath,
                sizeInBytes: 75,
                creationDate: Date(timeIntervalSince1970: 20),
                modificationDate: Date(timeIntervalSince1970: 20),
                location: .downloads,
                scanRootPath: downloadsRoot,
                destination: nil,
                status: .ready
            )
        ])

        let refreshedFile = FileItem(
            path: updatedPath,
            sizeInBytes: 150,
            creationDate: Date(timeIntervalSince1970: 10),
            modificationDate: Date(timeIntervalSince1970: 30),
            location: .desktop,
            scanRootPath: desktopRoot,
            destination: nil,
            status: .ready
        )
        context.insert(refreshedFile)
        try context.save()

        var searchQueries: [String] = []
        var refreshedFoldersCount = 0
        await controller.applyAutomationScanUpdate(
            updatedPaths: [updatedPath],
            removedPaths: [removedPath],
            scannedRootPaths: [desktopRoot],
            errorSummary: nil,
            replacesAllFiles: false,
            requiresClusterRefresh: false,
            context: context,
            actions: DashboardScanRefreshController.Actions(
                onScanErrorSummary: { _ in XCTFail("Unexpected scan error") },
                onAutomationSummary: { _ in },
                resetOrganizationProgress: { _ in },
                currentSearchText: { "invoice" },
                triggerContentSearch: { query in searchQueries.append(query) },
                refreshAvailableFolders: { refreshedFoldersCount += 1 },
                prepareForIncrementalFileUpdate: {}
            )
        )

        XCTAssertEqual(analyticsViewModel.detectClustersCallCount, 0)
        XCTAssertEqual(searchQueries, ["invoice"])
        XCTAssertEqual(refreshedFoldersCount, 1)
        XCTAssertEqual(Set(scanViewModel.allFiles.map(\.path)), [updatedPath, retainedPath])
        XCTAssertEqual(scanViewModel.allFiles.first(where: { $0.path == updatedPath })?.sizeInBytes, 150)
    }

    func testFallbackApplyRunsClusterRefresh() async throws {
        let scanViewModel = FileScanViewModel(
            fileSystemService: MockFileSystemService(),
            fileScanPipeline: MockFileScanPipeline()
        )
        let analyticsViewModel = TrackingAnalyticsDashboardViewModel(
            storageService: .shared,
            insightsService: InsightsService()
        )
        let controller = DashboardScanRefreshController(
            scanViewModel: scanViewModel,
            analyticsViewModel: analyticsViewModel,
            insightsService: InsightsService()
        )
        let container = try ModelContainer(
            for: FileItem.self,
            Rule.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let desktopRoot = "/Users/test/Desktop"
        let refreshedFile = FileItem(
            path: "\(desktopRoot)/report.txt",
            sizeInBytes: 150,
            creationDate: Date(timeIntervalSince1970: 10),
            modificationDate: Date(timeIntervalSince1970: 30),
            location: .desktop,
            scanRootPath: desktopRoot,
            destination: nil,
            status: .ready
        )
        context.insert(refreshedFile)
        try context.save()

        await controller.applyAutomationScanUpdate(
            updatedPaths: [refreshedFile.path],
            removedPaths: [],
            scannedRootPaths: [desktopRoot],
            errorSummary: nil,
            replacesAllFiles: false,
            requiresClusterRefresh: true,
            context: context,
            actions: DashboardScanRefreshController.Actions(
                onScanErrorSummary: { _ in XCTFail("Unexpected scan error") },
                onAutomationSummary: { _ in },
                resetOrganizationProgress: { _ in },
                currentSearchText: { "" },
                triggerContentSearch: { _ in XCTFail("Search should not run without an active query") },
                refreshAvailableFolders: {},
                prepareForIncrementalFileUpdate: {}
            )
        )

        XCTAssertEqual(analyticsViewModel.detectClustersCallCount, 1)
    }
}
