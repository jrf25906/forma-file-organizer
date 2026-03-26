import XCTest
@testable import Forma_File_Organizing

@MainActor
final class FinderServicesRegistrationControllerTests: XCTestCase {
    private var defaults: UserDefaults!
    private var defaultsSuiteName: String!

    override func setUp() {
        super.setUp()
        defaultsSuiteName = "FinderServicesRegistrationControllerTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)
        defaults.removePersistentDomain(forName: defaultsSuiteName)
    }

    override func tearDown() {
        if let defaultsSuiteName {
            defaults.removePersistentDomain(forName: defaultsSuiteName)
        }
        defaults = nil
        defaultsSuiteName = nil
        super.tearDown()
    }

    func testRefreshRegistrationIfNeeded_UpdatesStoredVersionAndTimestamp() {
        let controller = FinderServicesRegistrationController(defaults: defaults, bundle: .main)
        defaults.set("0.0 (0)", forKey: "finderServices.registeredVersion")

        XCTAssertTrue(controller.currentStatus().needsRefresh)

        controller.refreshRegistrationIfNeeded()

        let refreshedStatus = controller.currentStatus()
        XCTAssertFalse(refreshedStatus.needsRefresh)
        XCTAssertEqual(refreshedStatus.registeredVersion, refreshedStatus.currentVersion)
        XCTAssertNotNil(refreshedStatus.lastRefreshDate)
    }
}
