import AppKit
import Darwin
import XCTest

final class RuleEditingWorkflowUITests: XCTestCase {
    private var app: XCUIApplication!
    private var harness: UITestHarness!

    override func setUp() async throws {
        try UITestGating.requireUI()
        continueAfterFailure = false

        terminateRunningAppIfNeeded()

        let launchedApp = await MainActor.run {
            let app = XCUIApplication()
            app.launchArguments = ["--uitesting", "-ApplePersistenceIgnoreState", "YES"]
            app.launchEnvironment["FORMA_WINDOW_PRESENTATION_SUITE"] = "FormaUITests.RuleEditingWorkflow"
            app.launchEnvironment["FORMA_RESET_WINDOW_PRESENTATION"] = "1"
            app.launch()
            _ = app.wait(for: .runningForeground, timeout: 5)
            return app
        }

        app = launchedApp
        harness = UITestHarness(app: launchedApp)
    }

    override func tearDown() async throws {
        app = nil
        harness = nil
    }

    @MainActor
    func testRuleDraftPersistsAcrossModalAndPanelHandoffs() throws {
        harness.waitForMainContent()
        app.activate()

        let (modalEditor, inlineBuilder) = openCollapsedDraftFromReview()

        let expandButton = app.buttons["expandRuleEditorButton"]
        XCTAssertTrue(expandButton.waitForExistence(timeout: 3), "Expand button should appear in inline builder")
        expandButton.click()

        XCTAssertTrue(modalEditor.waitForExistence(timeout: 3), "Rule editor should reappear after expanding")
    }

    @MainActor
    func testClosingCollapsedDraftFromReviewDismissesInlineBuilder() throws {
        harness.waitForMainContent()
        app.activate()

        let (_, inlineBuilder) = openCollapsedDraftFromReview()

        let closeButton = app.buttons["closeRuleBuilderButton"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 3), "Close button should appear in inline builder")
        closeButton.click()

        let disappears = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: disappears, object: inlineBuilder)
        let result = XCTWaiter().wait(for: [expectation], timeout: 3)
        XCTAssertEqual(result, .completed, "Inline rule builder should dismiss after closing")
    }

    @MainActor
    func testRuleComposerShowsStagedSectionsInModalAndPanel() throws {
        harness.waitForMainContent()
        app.activate()

        app.typeKey(.downArrow, modifierFlags: [])
        app.typeText("r")

        let modalEditor = app.otherElements["ruleEditorView"]
        XCTAssertTrue(modalEditor.waitForExistence(timeout: 3), "Rule editor should appear")
        XCTAssertTrue(app.otherElements["ruleComposerWhenSection"].waitForExistence(timeout: 3), "Modal editor should expose a When section")
        XCTAssertTrue(app.otherElements["ruleComposerThenSection"].waitForExistence(timeout: 3), "Modal editor should expose a Then section")
        XCTAssertTrue(app.otherElements["ruleComposerImpactSection"].waitForExistence(timeout: 3), "Modal editor should expose an Impact section")
        XCTAssertTrue(app.buttons["ruleComposerSaveButton"].waitForExistence(timeout: 3), "Rule editor should expose a primary save action")

        let collapseButton = app.buttons["collapseRuleEditorButton"]
        XCTAssertTrue(collapseButton.waitForExistence(timeout: 3), "Collapse button should appear")
        collapseButton.click()

        let inlineBuilder = app.otherElements["inlineRuleBuilderView"]
        XCTAssertTrue(inlineBuilder.waitForExistence(timeout: 3), "Inline builder should appear after collapsing")
        XCTAssertTrue(app.otherElements["ruleComposerWhenSection"].waitForExistence(timeout: 3), "Inline builder should expose a When section")
        XCTAssertTrue(app.otherElements["ruleComposerThenSection"].waitForExistence(timeout: 3), "Inline builder should expose a Then section")
        XCTAssertTrue(app.otherElements["ruleComposerImpactSection"].waitForExistence(timeout: 3), "Inline builder should expose an Impact section")
        XCTAssertTrue(app.buttons["ruleComposerSaveButton"].waitForExistence(timeout: 3), "Inline builder should expose a primary save action")
    }

    @MainActor
    private func openCollapsedDraftFromReview() -> (modalEditor: XCUIElement, inlineBuilder: XCUIElement) {
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeText("r")

        let modalEditor = app.otherElements["ruleEditorView"]
        XCTAssertTrue(modalEditor.waitForExistence(timeout: 3), "Rule editor should appear")

        let collapseButton = app.buttons["collapseRuleEditorButton"]
        XCTAssertTrue(collapseButton.waitForExistence(timeout: 3), "Collapse button should appear")
        collapseButton.click()

        let inlineBuilder = app.otherElements["inlineRuleBuilderView"]
        XCTAssertTrue(inlineBuilder.waitForExistence(timeout: 3), "Inline rule builder should appear after collapsing")

        return (modalEditor, inlineBuilder)
    }

    private func terminateRunningAppIfNeeded() {
        let bundleID = "jamesfarmer.Forma-File-Organizing"
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        guard !runningApps.isEmpty else { return }

        for runningApp in runningApps {
            let pid = runningApp.processIdentifier
            if runningApp.terminate() {
                waitForTermination(of: runningApp, timeout: 2)
            }
            if !runningApp.isTerminated {
                _ = runningApp.forceTerminate()
                waitForTermination(of: runningApp, timeout: 2)
            }
            if !runningApp.isTerminated, pid > 0 {
                kill(pid, SIGKILL)
            }
        }

        let deadline = Date().addingTimeInterval(5)
        while !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
        }
    }

    private func waitForTermination(of runningApp: NSRunningApplication, timeout: TimeInterval) {
        let deadline = Date().addingTimeInterval(timeout)
        while !runningApp.isTerminated && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
        }
    }
}
