import XCTest

enum TestGating {
    static var isIntegrationEnabled: Bool {
        isEnabled("RUN_INTEGRATION_TESTS")
    }

    static var isPerformanceEnabled: Bool {
        isEnabled("RUN_PERFORMANCE_TESTS")
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

    private static func isEnabled(_ key: String) -> Bool {
        ProcessInfo.processInfo.environment[key] == "1"
    }
}
