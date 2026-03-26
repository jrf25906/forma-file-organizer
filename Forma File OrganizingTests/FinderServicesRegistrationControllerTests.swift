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

    func testFinderServiceDeclarationIncludesRequiredContextForAutomaticMenuPresentation() throws {
        XCTAssertNotNil(
            try organizeWithFormaServiceDeclaration()["NSRequiredContext"] as? [String: Any],
            "Finder services need NSRequiredContext, even when empty, or macOS may register them without showing them in Finder's Services menu."
        )
    }

    func testFinderServiceDeclarationIncludesPortNameForRegisteredProviderLookup() throws {
        XCTAssertEqual(
            try organizeWithFormaServiceDeclaration()["NSPortName"] as? String,
            "$(PRODUCT_NAME)",
            "Finder services should declare the same port name that NSRegisterServicesProvider uses so AppKit can dispatch the request back into Forma."
        )
    }

    private func organizeWithFormaServiceDeclaration() throws -> [String: Any] {
        let infoPlistURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Forma File Organizing/Info.plist")

        let plistData = try Data(contentsOf: infoPlistURL)
        let propertyList = try XCTUnwrap(
            try PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any]
        )
        let services = try XCTUnwrap(propertyList["NSServices"] as? [[String: Any]])
        return try XCTUnwrap(
            services.first(where: { service in
                let menuItem = service["NSMenuItem"] as? [String: String]
                return menuItem?["default"] == "Organize with Forma"
            })
        )
    }
}
