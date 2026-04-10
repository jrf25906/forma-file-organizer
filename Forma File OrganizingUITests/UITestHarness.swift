import XCTest

final class UITestHarness {
    let app: XCUIApplication

    init(app: XCUIApplication) {
        self.app = app
    }

    @MainActor
    func waitForMainContent(timeout: TimeInterval = 8) {
        let reviewModePicker = element(withIdentifier: "toolbarReviewModePicker")
        XCTAssertTrue(reviewModePicker.waitForExistence(timeout: timeout), "Main content should appear")

        let firstVisibleRow = firstFileRow()
        XCTAssertTrue(firstVisibleRow.waitForExistence(timeout: timeout), "UI test files should be visible")
    }

    @MainActor
    func ensureSidebarVisible(timeout: TimeInterval = 4) {
        let showSidebarButton = app.buttons.matching(NSPredicate(format: "label == %@", "Show Sidebar")).firstMatch
        if showSidebarButton.waitForExistence(timeout: 0.5) {
            showSidebarButton.click()
        }

        let newRuleButton = app.buttons["New Rule"]
        XCTAssertTrue(newRuleButton.waitForExistence(timeout: timeout), "Sidebar should be visible")
    }

    @MainActor
    func reviewModePicker() -> XCUIElement {
        element(withIdentifier: "toolbarReviewModePicker")
    }

    @MainActor
    func needsReviewSegment() -> XCUIElement {
        reviewModePicker().buttons.element(boundBy: 0)
    }

    @MainActor
    func allFilesSegment() -> XCUIElement {
        reviewModePicker().buttons.element(boundBy: 1)
    }

    @MainActor
    func viewModePicker() -> XCUIElement {
        element(withIdentifier: "toolbarViewModePicker")
    }

    @MainActor
    func splitLayoutProbe() -> XCUIElement {
        element(withIdentifier: "dashboardSplitLayoutProbe")
    }

    @MainActor
    func inspectorToggle() -> XCUIElement {
        app.buttons["toolbarInspectorToggle"]
    }

    @MainActor
    func tapNeedsReviewSegment(timeout: TimeInterval = 4) {
        let picker = reviewModePicker()
        XCTAssertTrue(picker.waitForExistence(timeout: timeout), "Review mode picker should exist")
        picker.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)).click()
    }

    @MainActor
    func tapAllFilesSegment(timeout: TimeInterval = 4) {
        let picker = reviewModePicker()
        XCTAssertTrue(picker.waitForExistence(timeout: timeout), "Review mode picker should exist")
        picker.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5)).click()
    }

    @MainActor
    func tapGridViewSegment(timeout: TimeInterval = 4) {
        tapViewModeSegment(
            identifier: "viewMode_grid",
            accessibilityLabel: "Grid view",
            fallbackOffset: CGVector(dx: 0.12, dy: 0.5),
            timeout: timeout
        )
    }

    @MainActor
    func tapListViewSegment(timeout: TimeInterval = 4) {
        tapViewModeSegment(
            identifier: "viewMode_list",
            accessibilityLabel: "List view",
            fallbackOffset: CGVector(dx: 0.30, dy: 0.5),
            timeout: timeout
        )
    }

    @MainActor
    func tapCardViewSegment(timeout: TimeInterval = 4) {
        tapViewModeSegment(
            identifier: "viewMode_card",
            accessibilityLabel: "Card view",
            fallbackOffset: CGVector(dx: 0.50, dy: 0.5),
            timeout: timeout
        )
    }

    @MainActor
    func tapViewModeSegment(
        identifier: String,
        accessibilityLabel: String,
        fallbackOffset: CGVector,
        timeout: TimeInterval
    ) {
        let picker = viewModePicker()
        XCTAssertTrue(picker.waitForExistence(timeout: timeout), "View mode picker should exist")

        let labeledButton = app.buttons[accessibilityLabel]
        if labeledButton.waitForExistence(timeout: 1) {
            labeledButton.click()
            return
        }

        let button = element(withIdentifier: identifier)
        if button.waitForExistence(timeout: 0.5) {
            button.click()
        } else {
            picker.coordinate(withNormalizedOffset: fallbackOffset).click()
        }
    }

    @MainActor
    func fileRow(named name: String) -> XCUIElement {
        let predicate = NSPredicate(
            format: "identifier BEGINSWITH %@",
            "fileRow_\(name)__"
        )
        return app.descendants(matching: .any).matching(predicate).firstMatch
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

        return decodedFileName(from: firstRow.identifier)
    }

    @MainActor
    func visibleFileNames(timeout: TimeInterval = 4) -> [String] {
        let predicate = NSPredicate(format: "identifier BEGINSWITH %@", "fileRow_")
        let query = app.descendants(matching: .any).matching(predicate)
        XCTAssertTrue(query.firstMatch.waitForExistence(timeout: timeout), "Expected at least one visible file row")

        return query.allElementsBoundByIndex.compactMap { element in
            decodedFileName(from: element.identifier)
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

    @MainActor
    func waitForViewMode(_ mode: String, timeout: TimeInterval = 4) {
        waitForValue(element(withIdentifier: "mainContent_viewMode"), contains: mode, timeout: timeout)
    }

    @MainActor
    func waitForSplitLayout(_ mode: String, timeout: TimeInterval = 4) {
        waitForValue(splitLayoutProbe(), equals: mode, timeout: timeout)
    }

    @MainActor
    func toggleInspector(timeout: TimeInterval = 4) {
        let toggle = inspectorToggle()
        if toggle.waitForExistence(timeout: timeout) {
            toggle.click()
            return
        }

        app.activate()
        app.typeKey("i", modifierFlags: .command)
    }

    private func decodedFileName(from identifier: String) -> String {
        let prefix = "fileRow_"
        guard identifier.hasPrefix(prefix) else {
            XCTFail("Expected file row identifier to begin with \(prefix), got \(identifier)")
            return identifier
        }

        let trimmed = String(identifier.dropFirst(prefix.count))
        return trimmed.components(separatedBy: "__").first ?? trimmed
    }
}
