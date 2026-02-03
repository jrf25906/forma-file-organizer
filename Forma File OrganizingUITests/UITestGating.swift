import XCTest

enum UITestGating {
    static func requireUI() throws {
        if ProcessInfo.processInfo.environment["RUN_UI_TESTS"] != "1" {
            throw XCTSkip("UI tests disabled. Set RUN_UI_TESTS=1 to enable.")
        }
    }
}
