import XCTest
import SwiftData
import Combine
@testable import Forma_File_Organizing

@MainActor
final class AnalyticsViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        let schema = Schema([
            StorageSnapshot.self,
            FileItem.self,
            ActivityItem.self,
            Rule.self,
            LearnedPattern.self,
            ProjectCluster.self,
            MLTrainingHistory.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let testContainer = try ModelContainer(for: schema, configurations: [configuration])
        await MainActor.run {
            container = testContainer
            context = ModelContext(testContainer)
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            container = nil
            context = nil
        }
        try await super.tearDown()
    }

    func testRefreshDoesNotErrorWithEmptyData() async {
        let viewModel = AnalyticsViewModel(modelContext: context)
        await viewModel.refresh()
        XCTAssertNil(viewModel.errorMessage)
    }

    func testRefreshDoesNotErrorWithFolderHealthAlertsEnabledAndEmptyData() async {
        let staleKey = FolderHealthAlertSettings.Keys.staleRuleThresholdDays
        let previousStaleValue = UserDefaults.standard.object(forKey: staleKey)
        UserDefaults.standard.set(30, forKey: staleKey)
        defer {
            if let previousStaleValue {
                UserDefaults.standard.set(previousStaleValue, forKey: staleKey)
            } else {
                UserDefaults.standard.removeObject(forKey: staleKey)
            }
        }

        let viewModel = AnalyticsViewModel(modelContext: context)
        await viewModel.refresh()

        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.folderHealthEvaluation.hasActiveAlerts)
    }

    func testOpenPendingReviewQueueReturnsAnalyticsWorkspaceToHome() {
        let dashboardViewModel = DashboardViewModel(
            services: AppServices(),
            fileSystemService: MockFileSystemService(),
            fileScanPipeline: MockFileScanPipeline()
        )
        let navigation = NavigationViewModel()
        let reportViewModel = ProductivityReportViewModel(
            modelContext: context,
            navigation: navigation,
            dashboardViewModel: dashboardViewModel
        )

        dashboardViewModel.showAnalyticsWorkspace()

        reportViewModel.openPendingReviewQueue()

        XCTAssertEqual(dashboardViewModel.workspaceDestination, .home)
        XCTAssertEqual(navigation.selection, .home)
        XCTAssertEqual(dashboardViewModel.reviewFilterMode, .needsReview)
    }

    func testDetectClustersSkipsPublishingAndPersistingUnchangedClusterSet() async throws {
        let viewModel = AnalyticsDashboardViewModel(services: AppServices())
        let baselineDate = Date(timeIntervalSince1970: 1_710_000_000)
        let files = [
            clusterFile(name: "P-2048-brief.pdf", modifiedAt: baselineDate),
            clusterFile(name: "P-2048-notes.txt", modifiedAt: baselineDate.addingTimeInterval(600)),
            clusterFile(name: "P-2048-budget.csv", modifiedAt: baselineDate.addingTimeInterval(1_200)),
            clusterFile(name: "vacation-photo.jpg", modifiedAt: baselineDate.addingTimeInterval(7_200)),
            clusterFile(name: "podcast.m4a", modifiedAt: baselineDate.addingTimeInterval(14_400))
        ]
        let changedScanSameClusters = files + [
            clusterFile(name: "readme.md", modifiedAt: baselineDate.addingTimeInterval(28_800))
        ]

        var publishedClusterSets: [[String]] = []
        let cancellable = viewModel.$detectedClusters
            .dropFirst()
            .sink { clusters in
                publishedClusterSets.append(clusters.map(self.clusterSignature).sorted())
            }
        defer { cancellable.cancel() }

        await viewModel.detectClusters(from: files, context: context)
        let storedClustersAfterFirstPass = try context.fetch(FetchDescriptor<ProjectCluster>())
        XCTAssertFalse(storedClustersAfterFirstPass.isEmpty, "Expected baseline cluster detection to persist at least one cluster")

        await viewModel.detectClusters(from: changedScanSameClusters, context: context)
        let storedClustersAfterSecondPass = try context.fetch(FetchDescriptor<ProjectCluster>())

        XCTAssertEqual(
            publishedClusterSets.count,
            1,
            "A changed scan that converges to the same cluster set should not republish detected clusters"
        )
        XCTAssertEqual(
            storedClustersAfterSecondPass.count,
            storedClustersAfterFirstPass.count,
            "A changed scan that keeps the same cluster set should skip redundant cluster persistence"
        )
    }

    private func clusterFile(name: String, modifiedAt: Date) -> FileItem {
        FileItem(
            path: "/Users/test/Downloads/\(name)",
            sizeInBytes: 1_024,
            creationDate: modifiedAt.addingTimeInterval(-3_600),
            modificationDate: modifiedAt,
            lastAccessedDate: modifiedAt
        )
    }

    private func clusterSignature(_ cluster: ProjectCluster) -> String {
        let sortedPaths = cluster.filePaths.sorted().joined(separator: "|")
        let confidence = String(format: "%.4f", cluster.confidenceScore)
        return [
            cluster.clusterType.rawValue,
            cluster.suggestedFolderName,
            cluster.detectedPattern ?? "none",
            confidence,
            sortedPaths
        ].joined(separator: "::")
    }
}
