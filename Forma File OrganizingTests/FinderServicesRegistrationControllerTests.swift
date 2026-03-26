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

    func testRefreshRegistrationIfNeeded_RebuildsLaunchServicesAndPbsCacheOutsideTests() {
        var executedCommands: [(path: String, arguments: [String])] = []
        var dynamicServicesUpdateCount = 0

        let controller = FinderServicesRegistrationController(
            defaults: defaults,
            bundle: .main,
            runCommand: { path, arguments in
                executedCommands.append((path, arguments))
            },
            updateDynamicServices: {
                dynamicServicesUpdateCount += 1
            },
            isTestingProcess: { false }
        )
        defaults.set("0.0 (0)", forKey: "finderServices.registeredVersion")

        controller.refreshRegistrationIfNeeded()

        XCTAssertEqual(dynamicServicesUpdateCount, 1)
        XCTAssertEqual(
            executedCommands.map(\.path),
            [
                "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister",
                "/System/Library/CoreServices/pbs",
                "/System/Library/CoreServices/pbs"
            ]
        )
        XCTAssertEqual(executedCommands[0].arguments.prefix(3), ["-f", "-R", "-trusted"])
        XCTAssertEqual(executedCommands[0].arguments.last, Bundle.main.bundleURL.path)
        XCTAssertEqual(executedCommands[1].arguments, ["-flush"])
        XCTAssertEqual(executedCommands[2].arguments, ["-update"])
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
