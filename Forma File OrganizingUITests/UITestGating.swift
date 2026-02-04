import XCTest

enum UITestGating {
    static func requireUI() throws {
        // UI tests are selected via the dedicated UI `.xctestplan`.
    }
}
