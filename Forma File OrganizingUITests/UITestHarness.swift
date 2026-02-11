import XCTest

final class UITestHarness {
    let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    @MainActor
    func waitForMainContent(timeout: TimeInterval = 8) {
        let needsReviewButton = app.buttons["reviewMode_needsReview"]
        XCTAssertTrue(needsReviewButton.waitForExistence(timeout: timeout), "Main content should appear")

        let firstVisibleRow = firstFileRow()
        XCTAssertTrue(firstVisibleRow.waitForExistence(timeout: timeout), "UI test files should be visible")
    }

    @MainActor
    func fileRow(named name: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "fileRow_\(name)").firstMatch
    }

    @MainActor
    func firstFileRow() -> XCUIElement {
        let predicate = NSPredicate(format: "identifier BEGINSWITH %@", "fileRow_")
        return app.descendants(matching: .any).matching(predicate).firstMatch
    }

    @MainActor
    func firstVisibleFileName(timeout: TimeInterval = 4) -> String {
        let firstRow = firstFileRow()
        XCTAssertTrue(firstRow.waitForExistence(timeout: timeout), "Expected at least one visible file row")

        let identifier = firstRow.identifier
        let prefix = "fileRow_"
        XCTAssertTrue(identifier.hasPrefix(prefix), "Expected file row identifier to begin with \(prefix)")
        return String(identifier.dropFirst(prefix.count))
    }

    @MainActor
    func visibleFileNames(timeout: TimeInterval = 4) -> [String] {
        let predicate = NSPredicate(format: "identifier BEGINSWITH %@", "fileRow_")
        let query = app.descendants(matching: .any).matching(predicate)
        XCTAssertTrue(query.firstMatch.waitForExistence(timeout: timeout), "Expected at least one visible file row")

        let prefix = "fileRow_"
        return query.allElementsBoundByIndex.compactMap { element in
            let identifier = element.identifier
            guard identifier.hasPrefix(prefix) else { return nil }
            return String(identifier.dropFirst(prefix.count))
        }
    }

    @MainActor
    func waitForFileRow(_ name: String, exists: Bool, timeout: TimeInterval = 4) {
        let row = fileRow(named: name)
        let predicate = NSPredicate(format: "exists == %@", exists as NSNumber)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: row)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "Expected file row \(name) exists=\(exists)")
    }

    @MainActor
    func waitForValue(_ element: XCUIElement, equals value: String, timeout: TimeInterval = 4) {
        let predicate = NSPredicate(format: "value == %@ OR label == %@", value, value)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "Expected value to be \(value)")
    }

    @MainActor
    func waitForValue(_ element: XCUIElement, contains value: String, timeout: TimeInterval = 4) {
        let predicate = NSPredicate(format: "value CONTAINS %@ OR label CONTAINS %@", value, value)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "Expected value to contain \(value)")
    }

    @MainActor
    func waitForExists(_ element: XCUIElement, timeout: TimeInterval = 4, message: String) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), message)
    }

    @MainActor
    func element(withIdentifier identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    func badgeValue(_ element: XCUIElement) -> String {
        element.value as? String ?? ""
    }
}
