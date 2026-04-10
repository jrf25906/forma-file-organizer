import Foundation
import XCTest

final class FileSurfaceToolbarValidationTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false
    }

    override func setUpWithError() throws {
        try UITestGating.requireUI()
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureFileSurfaceAndToolbarValidationShots() throws {
        let baseOutputDir = ProcessInfo.processInfo.environment["FORMA_SCREENSHOT_OUTPUT_DIR"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }

        try captureStandardWidthShots(outputDir: baseOutputDir)
        try captureCompactWidthShot(windowSize: "1080x760", name: "file-surface-toolbar-05-all-files-list-1080", outputDir: baseOutputDir)
        try captureCompactWidthShot(windowSize: "920x700", name: "file-surface-toolbar-06-all-files-list-920", outputDir: baseOutputDir)
    }

    @MainActor
    func testDashboardDoesNotShowLegacyFileManagementHeader() throws {
        let app = launchApp(windowSize: "1440x900")
        defer { app.terminate() }

        XCTAssertFalse(
            app.staticTexts["Forma: File Management"].waitForExistence(timeout: 1),
            "Dashboard should not show the legacy file management header"
        )
    }

    @MainActor
    func testGridViewKeepsChooseDestinationPrimaryActionVisibleWithoutHover() throws {
        let app = launchApp(windowSize: "1440x900")
        let harness = UITestHarness(app: app)
        defer { app.terminate() }

        harness.tapAllFilesSegment()
        harness.tapGridViewSegment()
        harness.waitForViewMode("grid")
        waitForRow(in: app)

        let noDestinationRow = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "fileRow_IMG_1042.JPG__")
        ).firstMatch
        XCTAssertTrue(
            noDestinationRow.waitForExistence(timeout: 3),
            "Expected the no-destination UI test row to be visible in grid view"
        )

        let chooseDestinationButton = noDestinationRow.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "filePrimaryAction_chooseDestination_IMG_1042.JPG__")
        ).firstMatch
        XCTAssertTrue(
            chooseDestinationButton.waitForExistence(timeout: 3),
            "Grid view should keep the Choose Destination action visible for files that still need setup"
        )
    }
}

@MainActor
private extension FileSurfaceToolbarValidationTests {

    func launchApp(windowSize: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "-ApplePersistenceIgnoreState", "YES"]
        app.launchEnvironment["FORMA_APPEARANCE_MODE"] = "light"
        app.launchEnvironment["FORMA_WINDOW_SIZE"] = windowSize
        app.launchEnvironment["FORMA_WINDOW_PRESENTATION_SUITE"] = sanitizedSuiteName(name)
        app.launchEnvironment["FORMA_RESET_WINDOW_PRESENTATION"] = "1"
        app.launch()

        UITestHarness(app: app).waitForMainContent(timeout: 12)
        return app
    }

    func captureStandardWidthShots(outputDir: URL?) throws {
        let app = launchApp(windowSize: "1440x900")
        let harness = UITestHarness(app: app)
        defer { app.terminate() }

        ensureInspectorVisible(app: app, harness: harness)
        assertToolbarGroups(app: app)
        harness.waitForViewMode("card")
        waitForRow(in: app)
        try captureWindowShot(
            app: app,
            name: "file-surface-toolbar-01-pending-card-1440",
            outputDir: outputDir
        )

        harness.tapAllFilesSegment()

        harness.tapCardViewSegment()
        harness.waitForViewMode("card")
        waitForRow(in: app)
        assertToolbarGroups(app: app)
        try captureWindowShot(
            app: app,
            name: "file-surface-toolbar-02-all-files-card-1440",
            outputDir: outputDir
        )

        harness.tapListViewSegment()
        harness.waitForViewMode("list")
        waitForRow(in: app)
        assertToolbarGroups(app: app)
        try captureWindowShot(
            app: app,
            name: "file-surface-toolbar-03-all-files-list-1440",
            outputDir: outputDir
        )

        harness.tapGridViewSegment()
        harness.waitForViewMode("grid")
        waitForRow(in: app)
        assertToolbarGroups(app: app)
        try captureWindowShot(
            app: app,
            name: "file-surface-toolbar-04-all-files-grid-1440",
            outputDir: outputDir
        )
    }

    func captureCompactWidthShot(windowSize: String, name: String, outputDir: URL?) throws {
        let app = launchApp(windowSize: windowSize)
        let harness = UITestHarness(app: app)
        defer { app.terminate() }

        harness.tapAllFilesSegment()
        harness.tapListViewSegment()

        harness.waitForViewMode("list")
        waitForRow(in: app)
        assertToolbarGroups(app: app)
        try captureWindowShot(app: app, name: name, outputDir: outputDir)
    }

    func ensureInspectorVisible(app: XCUIApplication, harness: UITestHarness, timeout: TimeInterval = 4) {
        let splitProbe = harness.splitLayoutProbe()
        harness.waitForExists(splitProbe, timeout: timeout, message: "Split layout probe should exist")
        guard splitProbe.label != "threeColumn",
              (splitProbe.value as? String) != "threeColumn" else { return }

        harness.toggleInspector(timeout: timeout)
        harness.waitForSplitLayout("threeColumn", timeout: timeout)
    }

    func assertToolbarGroups(app: XCUIApplication) {
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "toolbarReviewModePicker").firstMatch.waitForExistence(timeout: 3),
            "Toolbar review mode picker should exist"
        )
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "toolbarContextSummary").firstMatch.waitForExistence(timeout: 3),
            "Toolbar context summary should exist"
        )
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "toolbarArrangeMenu").firstMatch.waitForExistence(timeout: 3),
            "Toolbar arrange menu should exist"
        )
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "toolbarViewModePicker").firstMatch.waitForExistence(timeout: 3),
            "Toolbar display cluster should exist"
        )
    }

    func waitForRow(in app: XCUIApplication, timeout: TimeInterval = 4) {
        let predicate = NSPredicate(format: "identifier BEGINSWITH %@", "fileRow_")
        let element = app.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Expected visible file row")
    }

    func captureWindowShot(
        app: XCUIApplication,
        name: String,
        outputDir: URL?
    ) throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 4), "Expected an app window to exist for screenshot \(name)")

        let screenshot = window.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        guard let outputDir else { return }
        try FileManager.default.createDirectory(
            at: outputDir,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let outURL = outputDir.appendingPathComponent("\(name).png")
        try screenshot.pngRepresentation.write(to: outURL, options: .atomic)
    }

    func sanitizedSuiteName(_ rawValue: String) -> String {
        let sanitized = rawValue.map { character -> Character in
            if character.isLetter || character.isNumber {
                return character
            }
            return "_"
        }
        return "FileSurfaceToolbarValidationTests.\(String(sanitized))"
    }
}
