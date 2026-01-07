import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class ActivityLoggingTests: XCTestCase {

    func testAddActivityPersistsAndUpdatesRecentActivities() throws {
        // In-memory container for ActivityItem
        let schema = Schema([ActivityItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext

        // DashboardViewModel with mock dependencies
        let mockFS = MockFileSystemService()
        let mockPipeline = MockFileScanPipeline()
        let viewModel = DashboardViewModel(
            services: AppServices(),
            fileSystemService: mockFS,
            fileScanPipeline: mockPipeline
        )

        let activity = ActivityItem(
            activityType: .ruleCreated,
            fileName: "NL Rule",
            details: "Created from natural language: \"Move PDFs older than 30 days to Archive\""
        )

        viewModel.addActivity(activity, context: context)

        XCTAssertEqual(viewModel.recentActivities.count, 1)
        XCTAssertEqual(viewModel.recentActivities.first?.activityType, .ruleCreated)
        XCTAssertEqual(viewModel.recentActivities.first?.fileName, "NL Rule")
    }
}
