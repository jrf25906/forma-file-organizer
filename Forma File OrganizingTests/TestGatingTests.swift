import XCTest

final class TestGatingTests: XCTestCase {
    private var originalIntegrationValue: String?
    private var originalPerformanceValue: String?
    private var originalTestPlanName: String?

    override func setUp() {
        super.setUp()
        originalIntegrationValue = ProcessInfo.processInfo.environment["RUN_INTEGRATION_TESTS"]
        originalPerformanceValue = ProcessInfo.processInfo.environment["RUN_PERFORMANCE_TESTS"]
        originalTestPlanName = ProcessInfo.processInfo.environment["XCODE_TEST_PLAN_NAME"]
        unsetenv("RUN_INTEGRATION_TESTS")
        unsetenv("RUN_PERFORMANCE_TESTS")
        unsetenv("XCODE_TEST_PLAN_NAME")
    }

    override func tearDown() {
        restoreEnvironmentVariable("RUN_INTEGRATION_TESTS", value: originalIntegrationValue)
        restoreEnvironmentVariable("RUN_PERFORMANCE_TESTS", value: originalPerformanceValue)
        restoreEnvironmentVariable("XCODE_TEST_PLAN_NAME", value: originalTestPlanName)
        super.tearDown()
    }

    func testIntegrationTestsAreDisabledByDefault() {
        XCTAssertFalse(TestGating.isIntegrationEnabled)
        XCTAssertThrowsError(try TestGating.requireIntegration())
    }

    func testIntegrationTestsCanBeEnabledViaEnvironmentVariable() {
        setenv("RUN_INTEGRATION_TESTS", "1", 1)

        XCTAssertTrue(TestGating.isIntegrationEnabled)
        XCTAssertNoThrow(try TestGating.requireIntegration())
    }

    func testIntegrationTestsCanBeEnabledViaTestPlanName() {
        setenv("XCODE_TEST_PLAN_NAME", "Forma File Organizing - Integration", 1)

        XCTAssertTrue(TestGating.isIntegrationEnabled)
        XCTAssertNoThrow(try TestGating.requireIntegration())
        XCTAssertFalse(TestGating.isPerformanceEnabled)
    }

    func testPerformanceTestsAreDisabledByDefault() {
        XCTAssertFalse(TestGating.isPerformanceEnabled)
        XCTAssertThrowsError(try TestGating.requirePerformance())
    }

    func testPerformanceTestsCanBeEnabledViaEnvironmentVariable() {
        setenv("RUN_PERFORMANCE_TESTS", "1", 1)

        XCTAssertTrue(TestGating.isPerformanceEnabled)
        XCTAssertNoThrow(try TestGating.requirePerformance())
    }

    func testPerformanceTestsCanBeEnabledViaTestPlanName() {
        setenv("XCODE_TEST_PLAN_NAME", "Forma File Organizing - Performance", 1)

        XCTAssertTrue(TestGating.isPerformanceEnabled)
        XCTAssertNoThrow(try TestGating.requirePerformance())
        XCTAssertFalse(TestGating.isIntegrationEnabled)
    }

    func testPlanOnlySuitesOptIntoGating() throws {
        let root = repositoryRoot()

        let performanceFiles = [
            "Forma File OrganizingTests/DashboardViewModelPerformanceTests.swift",
            "Forma File OrganizingTests/OptimizationBenchmarksTests.swift",
            "Forma File OrganizingTests/StorageServicePerformanceTests.swift",
            "Forma File OrganizingTests/DestinationPredictionPerformanceTests.swift",
            "Forma File OrganizingTests/RateLimitingTests.swift"
        ]

        for relativePath in performanceFiles {
            let contents = try loadSource(root: root, relativePath: relativePath)
            XCTAssertTrue(
                contents.contains("TestGating.requirePerformance()"),
                "\(relativePath) should opt into performance gating"
            )
        }

        let automationIntegrationPath = "Forma File OrganizingTests/AutomationIntegrationTests.swift"
        let automationContents = try loadSource(root: root, relativePath: automationIntegrationPath)
        let testCount = automationContents.components(separatedBy: "@Test").count - 1
        let guardCount = automationContents.components(separatedBy: "guard requireIntegration() else { return }").count - 1

        XCTAssertEqual(
            guardCount,
            testCount,
            "\(automationIntegrationPath) should guard every test with requireIntegration() while suite-level gating is manual"
        )
    }

    private func restoreEnvironmentVariable(_ key: String, value: String?) {
        if let value {
            setenv(key, value, 1)
        } else {
            unsetenv(key)
        }
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func loadSource(root: URL, relativePath: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
