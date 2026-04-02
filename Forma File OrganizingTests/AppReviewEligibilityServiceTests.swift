import XCTest
@testable import Forma_File_Organizing

final class AppReviewEligibilityServiceTests: XCTestCase {

    private var defaults: UserDefaults!
    private var currentDate: Date!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "test.appReviewEligibility.\(UUID().uuidString)")!
        currentDate = Date()
    }

    override func tearDown() {
        if let suiteName = defaults.volatileDomainNames.first {
            defaults.removePersistentDomain(forName: suiteName)
        }
        defaults = nil
        super.tearDown()
    }

    private func makeService(now: Date? = nil) -> AppReviewEligibilityService {
        let date = now ?? currentDate!
        return AppReviewEligibilityService(defaults: defaults, now: { date })
    }

    // MARK: - recordSuccessfulOperation

    func testRecordSuccessfulOperationAccumulatesCounts() {
        let service = makeService()

        service.recordSuccessfulOperation(count: 5)
        service.recordSuccessfulOperation(count: 10)

        XCTAssertEqual(defaults.integer(forKey: "forma.review.totalSuccessfulOps"), 15)
    }

    func testRecordSuccessfulOperationSetsFirstUseDateOnce() {
        let firstDate = Date(timeIntervalSince1970: 1_000_000)
        let laterDate = Date(timeIntervalSince1970: 2_000_000)

        let service1 = AppReviewEligibilityService(defaults: defaults, now: { firstDate })
        service1.recordSuccessfulOperation(count: 1)

        let service2 = AppReviewEligibilityService(defaults: defaults, now: { laterDate })
        service2.recordSuccessfulOperation(count: 1)

        XCTAssertEqual(defaults.double(forKey: "forma.review.firstUseDateSeconds"), firstDate.timeIntervalSince1970)
    }

    func testRecordSuccessfulOperationIgnoresZeroCount() {
        let service = makeService()
        service.recordSuccessfulOperation(count: 0)
        XCTAssertEqual(defaults.integer(forKey: "forma.review.totalSuccessfulOps"), 0)
    }

    // MARK: - shouldRequestReview

    func testShouldRequestReviewReturnsFalseWhenBelowMinOps() {
        let service = makeService()
        service.recordSuccessfulOperation(count: FormaConfig.ReviewPrompt.minSuccessfulOperations - 1)
        XCTAssertFalse(service.shouldRequestReview())
    }

    func testShouldRequestReviewReturnsFalseWhenTooFewDaysSinceFirstUse() {
        let firstUse = currentDate!
        let service1 = AppReviewEligibilityService(defaults: defaults, now: { firstUse })
        service1.recordSuccessfulOperation(count: FormaConfig.ReviewPrompt.minSuccessfulOperations)

        // Only 1 day later
        let oneDayLater = firstUse.addingTimeInterval(FormaConfig.Timing.secondsInDay)
        let service2 = AppReviewEligibilityService(defaults: defaults, now: { oneDayLater })
        XCTAssertFalse(service2.shouldRequestReview())
    }

    func testShouldRequestReviewReturnsFalseWhenLifetimeRequestsExceeded() {
        // Set up eligible state
        let firstUse = currentDate!
        let service1 = AppReviewEligibilityService(defaults: defaults, now: { firstUse })
        service1.recordSuccessfulOperation(count: FormaConfig.ReviewPrompt.minSuccessfulOperations)

        let eligibleDate = firstUse.addingTimeInterval(Double(FormaConfig.ReviewPrompt.minDaysSinceFirstUse + 1) * FormaConfig.Timing.secondsInDay)
        let service2 = AppReviewEligibilityService(defaults: defaults, now: { eligibleDate })

        // Exhaust lifetime requests
        for _ in 0..<FormaConfig.ReviewPrompt.maxLifetimeRequests {
            service2.markReviewRequested()
        }

        // Reset last request date so cooldown doesn't block
        defaults.set(0, forKey: "forma.review.lastRequestDateSeconds")

        XCTAssertFalse(service2.shouldRequestReview())
    }

    func testShouldRequestReviewReturnsFalseWhenCooldownNotElapsed() {
        let firstUse = currentDate!
        let service1 = AppReviewEligibilityService(defaults: defaults, now: { firstUse })
        service1.recordSuccessfulOperation(count: FormaConfig.ReviewPrompt.minSuccessfulOperations)

        let eligibleDate = firstUse.addingTimeInterval(Double(FormaConfig.ReviewPrompt.minDaysSinceFirstUse + 1) * FormaConfig.Timing.secondsInDay)
        let service2 = AppReviewEligibilityService(defaults: defaults, now: { eligibleDate })
        service2.markReviewRequested()

        // Only 1 day after the request
        let nextDay = eligibleDate.addingTimeInterval(FormaConfig.Timing.secondsInDay)
        let service3 = AppReviewEligibilityService(defaults: defaults, now: { nextDay })
        XCTAssertFalse(service3.shouldRequestReview())
    }

    func testShouldRequestReviewReturnsTrueWhenAllConditionsMet() {
        let firstUse = currentDate!
        let service1 = AppReviewEligibilityService(defaults: defaults, now: { firstUse })
        service1.recordSuccessfulOperation(count: FormaConfig.ReviewPrompt.minSuccessfulOperations)

        let eligibleDate = firstUse.addingTimeInterval(Double(FormaConfig.ReviewPrompt.minDaysSinceFirstUse + 1) * FormaConfig.Timing.secondsInDay)
        let service2 = AppReviewEligibilityService(defaults: defaults, now: { eligibleDate })

        XCTAssertTrue(service2.shouldRequestReview())
    }

    // MARK: - markReviewRequested

    func testMarkReviewRequestedIncrementsCountAndSetsDate() {
        let now = currentDate!
        let service = AppReviewEligibilityService(defaults: defaults, now: { now })

        service.markReviewRequested()

        XCTAssertEqual(defaults.integer(forKey: "forma.review.requestCount"), 1)
        XCTAssertEqual(defaults.double(forKey: "forma.review.lastRequestDateSeconds"), now.timeIntervalSince1970, accuracy: 1.0)

        service.markReviewRequested()
        XCTAssertEqual(defaults.integer(forKey: "forma.review.requestCount"), 2)
    }
}

// MARK: - Mock

final class MockAppReviewEligibilityService: AppReviewEligibilityProviding, @unchecked Sendable {
    var recordedOperationCounts: [Int] = []
    var shouldRequestReviewResult = false
    var markReviewRequestedCallCount = 0

    func recordSuccessfulOperation(count: Int) {
        recordedOperationCounts.append(count)
    }

    func shouldRequestReview() -> Bool {
        shouldRequestReviewResult
    }

    func markReviewRequested() {
        markReviewRequestedCallCount += 1
    }
}
