import XCTest

enum TestGating {
    private static let integrationPlanName = "Forma File Organizing - Integration"
    private static let performancePlanName = "Forma File Organizing - Performance"

    static var isIntegrationEnabled: Bool {
        isEnabled("RUN_INTEGRATION_TESTS", planName: integrationPlanName)
    }

    static var isPerformanceEnabled: Bool {
        isEnabled("RUN_PERFORMANCE_TESTS", planName: performancePlanName)
    }

    static func requireIntegration() throws {
        if !isIntegrationEnabled {
            throw XCTSkip("Integration tests disabled. Use the dedicated integration test plan to enable them.")
        }
    }

    static func requirePerformance() throws {
        if !isPerformanceEnabled {
            throw XCTSkip("Performance tests disabled. Use the dedicated performance test plan to enable them.")
        }
    }

    private static func isEnabled(_ key: String, planName: String) -> Bool {
        let environment = ProcessInfo.processInfo.environment
        if environment[key] == "1" {
            return true
        }

        return environment["XCODE_TEST_PLAN_NAME"] == planName
    }
}
