import XCTest
import SwiftData
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
}
