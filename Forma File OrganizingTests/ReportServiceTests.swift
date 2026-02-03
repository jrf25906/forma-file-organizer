import XCTest
@testable import Forma_File_Organizing

final class ReportServiceTests: XCTestCase {
    @MainActor
    func testShouldGenerateWeeklyReportResetsAfterWeekChange() {
        let defaults = UserDefaults(suiteName: "ReportServiceTests")!
        defaults.removePersistentDomain(forName: "ReportServiceTests")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let clock = FixedClock(now: now, calendar: calendar)
        let service = ReportService(defaults: defaults, calendar: calendar, clock: clock)
        let key = ReportService.lastReportDateKey
        defaults.removeObject(forKey: key)

        XCTAssertTrue(service.shouldGenerateWeeklyReport(now: now))

        defaults.set(now, forKey: key)
        XCTAssertFalse(service.shouldGenerateWeeklyReport(now: now))

        let nextWeek = calendar.date(byAdding: .day, value: 7, to: now)!
        XCTAssertTrue(service.shouldGenerateWeeklyReport(now: nextWeek))
    }
}
