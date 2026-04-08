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

    func testLogBulkOrganizedUsesPassLanguageForReviewDrivenRuns() throws {
        let schema = Schema([ActivityItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext
        let service = ActivityLoggingService(modelContext: context)

        service.logBulkOrganized(
            count: 3,
            destination: "Documents/Sorted",
            origin: .reviewDriven,
            undoAvailable: true
        )

        let activities = try context.fetch(FetchDescriptor<ActivityItem>())
        XCTAssertEqual(activities.last?.details, "Moved to Documents/Sorted. Review pass. Undo available")
    }

    func testLogBulkUndoneUsesAutomaticPassLanguage() throws {
        let schema = Schema([ActivityItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext
        let service = ActivityLoggingService(modelContext: context)

        service.logBulkUndone(count: 2, origin: .automation)

        let activities = try context.fetch(FetchDescriptor<ActivityItem>())
        XCTAssertEqual(
            activities.last?.details,
            "Restored to original locations from the last automatic pass."
        )
    }

    func testLogWorkflowRunSummary_PersistsInspectableRunLink() throws {
        let schema = Schema([
            ActivityItem.self,
            WorkflowRunRecord.self,
            WorkflowStepRunRecord.self,
            WorkflowFileActionRecord.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext
        let store = WorkflowAuditStore(modelContext: context)
        let service = ActivityLoggingService(modelContext: context)

        let run = try store.createRun(
            scopeID: UUID(),
            workflowTemplateID: BuiltInWorkflowTemplate.StableID.screenshots,
            startedAt: Date(timeIntervalSince1970: 3_000),
            primaryStatus: .succeeded
        )
        try store.updateRunStatus(
            runID: run.id,
            primaryStatus: .succeeded,
            endedAt: Date(timeIntervalSince1970: 3_030)
        )

        service.logWorkflowRunSummary(
            run: run,
            triggerSurface: .bulkOrganize,
            affectedFileCount: 4
        )

        let activities = try context.fetch(FetchDescriptor<ActivityItem>())
        let activity = try XCTUnwrap(activities.last)

        XCTAssertEqual(activity.workflowRunID, run.id)
        XCTAssertEqual(activity.workflowTemplateID, BuiltInWorkflowTemplate.StableID.screenshots)
        XCTAssertEqual(activity.affectedFileCount, 4)
        XCTAssertEqual(activity.activityType, .workflowRunCompleted)
    }
}
