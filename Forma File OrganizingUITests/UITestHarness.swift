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

        let firstCard = fileRow(named: "UITest_File_1_WithSuggestion.pdf")
        XCTAssertTrue(firstCard.waitForExistence(timeout: timeout), "UI test files should be visible")
    }

    @MainActor
    func fileRow(named name: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "fileRow_\(name)").firstMatch
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
        let predicate = NSPredicate(format: "value == %@", value)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed, "Expected value to be \(value)")
    }

    @MainActor
    func badgeValue(_ element: XCUIElement) -> String {
        element.value as? String ?? ""
    }
}
