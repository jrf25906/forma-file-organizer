import XCTest
import SwiftData
@testable import Forma_File_Organizing

final class AnalyticsServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        FeatureFlagService.shared.resetToDefaults()
    }

    override func tearDown() {
        FeatureFlagService.shared.resetToDefaults()
        super.tearDown()
    }

    @MainActor
    func testRecordDailySnapshotIsIdempotentPerDay_UsesInjectedClockAndDefaults() async throws {
        let (container, context) = try makeInMemoryContainer()
        let calendar = makeUTCCalendar()
        let now = try makeDate(year: 2026, month: 2, day: 11, hour: 9, minute: 30, calendar: calendar)

        let suiteName = "AnalyticsServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let service = AnalyticsService(
            defaults: defaults,
            calendar: calendar,
            clock: FixedClock(now: now, calendar: calendar)
        )

        try await service.recordDailySnapshotIfNeeded(container: container)
        let afterFirst = try context.fetch(FetchDescriptor<StorageSnapshot>())
        XCTAssertEqual(afterFirst.count, 1)
        XCTAssertEqual(afterFirst.first?.date, calendar.startOfDay(for: now))

        try await service.recordDailySnapshotIfNeeded(container: container)
        let afterSecond = try context.fetch(FetchDescriptor<StorageSnapshot>())
        XCTAssertEqual(afterSecond.count, 1)

        let persistedSnapshotDate = defaults.object(forKey: "forma.analytics.lastSnapshotDate") as? Date
        XCTAssertEqual(persistedSnapshotDate, calendar.startOfDay(for: now))
    }

    @MainActor
    func testFetchUsageStatistics_UsesInjectedClockForWeekWindow() async throws {
        let (_, context) = try makeInMemoryContainer()
        let calendar = makeUTCCalendar()
        let now = try makeDate(year: 2026, month: 2, day: 11, hour: 10, minute: 0, calendar: calendar)
        let service = AnalyticsService(
            defaults: UserDefaults(suiteName: "AnalyticsServiceTests.usage.\(UUID().uuidString)")!,
            calendar: calendar,
            clock: FixedClock(now: now, calendar: calendar)
        )

        let startOfToday = calendar.startOfDay(for: now)
        let expectedStart = try XCTUnwrap(calendar.date(byAdding: .day, value: -6, to: startOfToday))
        let justBeforeWindow = expectedStart.addingTimeInterval(-1)
        let justAfterNow = now.addingTimeInterval(1)
        let insideMidWeek = try makeDate(year: 2026, month: 2, day: 9, hour: 14, minute: 15, calendar: calendar)

        let outsideBefore = ActivityItem(activityType: .fileOrganized, fileName: "outside-before.txt", details: "outside")
        outsideBefore.timestamp = justBeforeWindow

        let insideAtStart = ActivityItem(activityType: .fileOrganized, fileName: "inside-start.txt", details: "inside")
        insideAtStart.timestamp = expectedStart

        let insideMoved = ActivityItem(activityType: .fileMoved, fileName: "inside-moved.txt", details: "inside")
        insideMoved.timestamp = insideMidWeek

        let outsideAfter = ActivityItem(activityType: .fileOrganized, fileName: "outside-after.txt", details: "outside")
        outsideAfter.timestamp = justAfterNow

        context.insert(outsideBefore)
        context.insert(insideAtStart)
        context.insert(insideMoved)
        context.insert(outsideAfter)
        try context.save()

        let usage = try await service.fetchUsageStatistics(for: .week, modelContext: context)
        XCTAssertEqual(usage.startDate, expectedStart)
        XCTAssertEqual(usage.endDate, now)
        XCTAssertEqual(usage.filesOrganized, 2, "Only activities within the injected clock window should count")
    }

    @MainActor
    func testGenerateProductivityHealthReport_UsesInjectedClockForGeneratedAt() async throws {
        let (container, _) = try makeInMemoryContainer()
        let calendar = makeUTCCalendar()
        let now = try makeDate(year: 2026, month: 2, day: 11, hour: 16, minute: 45, calendar: calendar)
        let service = AnalyticsService(
            defaults: UserDefaults(suiteName: "AnalyticsServiceTests.report.\(UUID().uuidString)")!,
            calendar: calendar,
            clock: FixedClock(now: now, calendar: calendar)
        )

        let report = try await service.generateProductivityHealthReport(for: .day, container: container)
        XCTAssertEqual(report.generatedAt, now)
    }

    // MARK: - Helpers

    @MainActor
    private func makeInMemoryContainer() throws -> (container: ModelContainer, context: ModelContext) {
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
        return (container, ModelContext(container))
    }

    private func makeUTCCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        calendar: Calendar
    ) throws -> Date {
        let date = calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))
        return try XCTUnwrap(date)
    }
}
