import XCTest
import SwiftData
@testable import Forma_File_Organizing

private enum StorageSnapshotMigrationV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [StorageSnapshot.self] }

    @Model
    final class StorageSnapshot {
        var id: UUID
        var date: Date
        var totalBytes: Int64
        var fileCount: Int
        var categoryBreakdownData: Data
        var deltaBytesSincePrevious: Int64?

        init(
            id: UUID = UUID(),
            date: Date,
            totalBytes: Int64,
            fileCount: Int,
            categoryBreakdownData: Data,
            deltaBytesSincePrevious: Int64? = nil
        ) {
            self.id = id
            self.date = date
            self.totalBytes = totalBytes
            self.fileCount = fileCount
            self.categoryBreakdownData = categoryBreakdownData
            self.deltaBytesSincePrevious = deltaBytesSincePrevious
        }
    }
}

private enum StorageSnapshotMigrationV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [Forma_File_Organizing.StorageSnapshot.self] }
}

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
    func testRecordDailySnapshotPersistsFolderBreakdown() async throws {
        let (container, context) = try makeInMemoryContainer()
        let calendar = makeUTCCalendar()
        let now = try makeDate(year: 2026, month: 2, day: 12, hour: 9, minute: 30, calendar: calendar)
        let downloadsRoot = try TemporaryDirectory()
        let desktopRoot = try TemporaryDirectory()
        defer {
            downloadsRoot.cleanup()
            desktopRoot.cleanup()
        }

        let bookmarkStore = InMemoryBookmarkStore()
        let downloadsDestination = try Destination.folder(from: downloadsRoot.url, displayName: "Downloads")
        try bookmarkStore.saveBookmark(
            try XCTUnwrap(downloadsDestination.bookmarkData),
            forKey: FormaConfig.Security.downloadsBookmarkKey
        )
        let desktopDestination = try Destination.folder(from: desktopRoot.url, displayName: "Desktop")
        try bookmarkStore.saveBookmark(
            try XCTUnwrap(desktopDestination.bookmarkData),
            forKey: FormaConfig.Security.desktopBookmarkKey
        )

        let downloadsFile = FileItem(
            path: downloadsRoot.url.appendingPathComponent("archive.zip").path,
            sizeInBytes: 4 * 1024 * 1024 * 1024,
            creationDate: now,
            location: .downloads,
            scanRootPath: downloadsRoot.url.path
        )
        let desktopFile = FileItem(
            path: desktopRoot.url.appendingPathComponent("screenshot.png").path,
            sizeInBytes: 512 * 1024 * 1024,
            creationDate: now,
            location: .desktop,
            scanRootPath: desktopRoot.url.path
        )

        context.insert(downloadsFile)
        context.insert(desktopFile)
        try context.save()

        let suiteName = "AnalyticsServiceTests.folderBreakdown.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let service = AnalyticsService(
            defaults: defaults,
            calendar: calendar,
            clock: FixedClock(now: now, calendar: calendar)
        )

        try await BookmarkStoreProvider.$override.withValue(bookmarkStore) {
            try await service.recordDailySnapshotIfNeeded(container: container)
        }

        let snapshot = try XCTUnwrap(try context.fetch(FetchDescriptor<StorageSnapshot>()).first)
        XCTAssertEqual(
            snapshot.bytes(for: .downloads),
            downloadsFile.sizeInBytes
        )
        XCTAssertEqual(
            snapshot.bytes(for: .desktop),
            desktopFile.sizeInBytes
        )
        XCTAssertEqual(snapshot.folderBreakdown[.documents], nil)
    }

    @MainActor
    func testRecordDailySnapshotUsesCurrentFilePathForFolderBreakdown() async throws {
        let (container, context) = try makeInMemoryContainer()
        let calendar = makeUTCCalendar()
        let now = try makeDate(year: 2026, month: 2, day: 13, hour: 9, minute: 30, calendar: calendar)

        let downloadsRoot = try TemporaryDirectory()
        let archiveRoot = try TemporaryDirectory()
        defer {
            downloadsRoot.cleanup()
            archiveRoot.cleanup()
        }

        let bookmarkStore = InMemoryBookmarkStore()
        let downloadsDestination = try Destination.folder(from: downloadsRoot.url, displayName: "Downloads")
        try bookmarkStore.saveBookmark(
            try XCTUnwrap(downloadsDestination.bookmarkData),
            forKey: FormaConfig.Security.downloadsBookmarkKey
        )

        let currentDownloadsFile = FileItem(
            path: downloadsRoot.url.appendingPathComponent("current.zip").path,
            sizeInBytes: 4 * 1024 * 1024 * 1024,
            creationDate: now,
            location: .downloads,
            scanRootPath: downloadsRoot.url.path
        )
        let movedOutFile = FileItem(
            path: archiveRoot.url.appendingPathComponent("moved.zip").path,
            sizeInBytes: 6 * 1024 * 1024 * 1024,
            creationDate: now,
            location: .downloads,
            scanRootPath: downloadsRoot.url.path,
            status: .completed
        )

        context.insert(currentDownloadsFile)
        context.insert(movedOutFile)
        try context.save()

        let suiteName = "AnalyticsServiceTests.liveFolderBreakdown.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let service = AnalyticsService(
            defaults: defaults,
            calendar: calendar,
            clock: FixedClock(now: now, calendar: calendar)
        )

        try await BookmarkStoreProvider.$override.withValue(bookmarkStore) {
            try await service.recordDailySnapshotIfNeeded(container: container)
        }

        let snapshot = try XCTUnwrap(try context.fetch(FetchDescriptor<StorageSnapshot>()).first)
        XCTAssertEqual(snapshot.bytes(for: .downloads), currentDownloadsFile.sizeInBytes)
    }

    func testStorageSnapshotFolderBreakdownDefaultsToEmptyForLegacyData() {
        let snapshot = StorageSnapshot(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            totalBytes: 1_024,
            fileCount: 1,
            categoryBreakdownData: Data()
        )

        XCTAssertTrue(snapshot.folderBreakdown.isEmpty)
        XCTAssertEqual(snapshot.bytes(for: .downloads), 0)
    }

    @MainActor
    func testStorageSnapshotLegacyStoreMigratesWithoutFolderBreakdownData() throws {
        let tempDir = try TemporaryDirectory()

        let storeURL = tempDir.url.appendingPathComponent("storage-snapshot-legacy.store")
        let legacySchema = Schema(versionedSchema: StorageSnapshotMigrationV1.self)
        let legacyConfiguration = ModelConfiguration(
            schema: legacySchema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let legacyContainer = try ModelContainer(for: legacySchema, configurations: [legacyConfiguration])
        let legacyContext = ModelContext(legacyContainer)
        legacyContext.insert(
            StorageSnapshotMigrationV1.StorageSnapshot(
                date: Date(timeIntervalSince1970: 1_700_000_000),
                totalBytes: 2_048,
                fileCount: 2,
                categoryBreakdownData: Data([0x01, 0x02]),
                deltaBytesSincePrevious: 128
            )
        )
        try legacyContext.save()

        let currentSchema = Schema(versionedSchema: StorageSnapshotMigrationV2.self)
        let currentConfiguration = ModelConfiguration(
            schema: currentSchema,
            url: storeURL,
            cloudKitDatabase: .none
        )

        let currentContainer = try ModelContainer(for: currentSchema, configurations: [currentConfiguration])
        let currentContext = ModelContext(currentContainer)
        let descriptor = FetchDescriptor<StorageSnapshot>(
            sortBy: [SortDescriptor(\.date)]
        )
        let snapshot = try XCTUnwrap(try currentContext.fetch(descriptor).first)

        XCTAssertEqual(snapshot.totalBytes, 2_048)
        XCTAssertEqual(snapshot.fileCount, 2)
        XCTAssertEqual(snapshot.categoryBreakdownData, Data([0x01, 0x02]))
        XCTAssertTrue(snapshot.folderBreakdownData.isEmpty)
        XCTAssertTrue(snapshot.folderBreakdown.isEmpty)
        XCTAssertEqual(snapshot.deltaBytesSincePrevious, 128)
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
