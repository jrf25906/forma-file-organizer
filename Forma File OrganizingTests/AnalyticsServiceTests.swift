import XCTest
import SwiftData
@testable import Forma_File_Organizing

final class AnalyticsServiceTests: XCTestCase {
    @MainActor
    func testRecordDailySnapshotIsIdempotentPerDay() async throws {
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
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let now = Date()
        try await AnalyticsService.shared.recordDailySnapshotIfNeeded(container: container, now: now)
        let afterFirst = try context.fetch(FetchDescriptor<StorageSnapshot>())
        XCTAssertEqual(afterFirst.count, 1)

        try await AnalyticsService.shared.recordDailySnapshotIfNeeded(container: container, now: now)
        let afterSecond = try context.fetch(FetchDescriptor<StorageSnapshot>())
        XCTAssertEqual(afterSecond.count, 1)
    }
}
