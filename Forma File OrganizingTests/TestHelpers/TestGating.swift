import XCTest

enum TestGating {
    static var isIntegrationEnabled: Bool { true }
    static var isPerformanceEnabled: Bool { true }

    static func requireIntegration() throws {
        // Integration tests are selected via dedicated `.xctestplan` files.
        // Avoid environment-variable gating here so `xcodebuild test -testPlan ...`
        // runs deterministically.
    }

    static func requirePerformance() throws {
        // Performance tests are selected via dedicated `.xctestplan` files.
        // Avoid environment-variable gating here so `xcodebuild test -testPlan ...`
        // runs deterministically.
    }
}
