import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class AnalyticsViewModelTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([
            StorageSnapshot.self,
            FileItem.self,
            ActivityItem.self,
            Rule.self,
            CustomFolder.self,
            LearnedPattern.self,
            ProjectCluster.self,
            MLTrainingHistory.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    func testRefreshDoesNotErrorWithEmptyData() async {
        let viewModel = AnalyticsViewModel(modelContext: context)
        await viewModel.refresh()
        XCTAssertNil(viewModel.errorMessage)
    }
}
