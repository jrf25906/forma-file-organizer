import XCTest

enum TestGating {
    static var isIntegrationEnabled: Bool {
        ProcessInfo.processInfo.environment["RUN_INTEGRATION_TESTS"] == "1"
    }

    static var isPerformanceEnabled: Bool {
        ProcessInfo.processInfo.environment["RUN_PERFORMANCE_TESTS"] == "1"
    }

    static func requireIntegration() throws {
        if !isIntegrationEnabled {
            throw XCTSkip("Integration tests disabled. Set RUN_INTEGRATION_TESTS=1 to enable.")
        }
    }

    static func requirePerformance() throws {
        if !isPerformanceEnabled {
            throw XCTSkip("Performance tests disabled. Set RUN_PERFORMANCE_TESTS=1 to enable.")
        }
    }
}
