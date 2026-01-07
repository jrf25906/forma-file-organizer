import XCTest
@testable import Forma_File_Organizing

final class ReportServiceTests: XCTestCase {
    @MainActor
    func testShouldGenerateWeeklyReportResetsAfterWeekChange() {
        let service = ReportService.shared
        let key = ReportService.lastReportDateKey
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: key)

        XCTAssertTrue(service.shouldGenerateWeeklyReport())

        let now = Date()
        defaults.set(now, forKey: key)
        XCTAssertFalse(service.shouldGenerateWeeklyReport(now: now))

        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: now)!
        XCTAssertTrue(service.shouldGenerateWeeklyReport(now: nextWeek))
    }
}
