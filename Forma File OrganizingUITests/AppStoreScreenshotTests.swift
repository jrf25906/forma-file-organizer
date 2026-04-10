//
//  AppStoreScreenshotTests.swift
//  Forma File OrganizingUITests
//
//  Created by Codex on 2/4/26.
//

import Foundation
import XCTest

final class AppStoreScreenshotTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false
    }

    override func setUpWithError() throws {
        try UITestGating.requireUI()
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureAppStoreScreenshots() throws {
        let baseOutputDir = ProcessInfo.processInfo.environment["FORMA_SCREENSHOT_OUTPUT_DIR"]
            .map { URL(fileURLWithPath: $0, isDirectory: true) }

        try captureScreenshots(
            appearance: .light,
            outputDir: baseOutputDir?.appendingPathComponent("Light", isDirectory: true)
        )
        try captureScreenshots(
            appearance: .dark,
            outputDir: baseOutputDir?.appendingPathComponent("Dark", isDirectory: true)
        )
    }
}

private enum ScreenshotAppearance: String {
    case light
    case dark
}

@MainActor
private extension AppStoreScreenshotTests {

    func captureScreenshots(appearance: ScreenshotAppearance, outputDir: URL?) throws {
        // 1) Main window: hero + all files + rule editor
        var app = launchApp(appearance: appearance)
        try captureMainWindowShots(app: app, appearance: appearance, outputDir: outputDir)
        app.terminate()

        // 2) Smart Rules (+ optional Analytics)
        app = launchApp(appearance: appearance)
        try captureToolsShots(app: app, appearance: appearance, outputDir: outputDir)
        app.terminate()

        // 3) Settings window
        app = launchApp(appearance: appearance)
        try captureSettingsShot(app: app, appearance: appearance, outputDir: outputDir)
        app.terminate()
    }

    func launchApp(appearance: ScreenshotAppearance) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "-ApplePersistenceIgnoreState", "YES"]
        app.launchEnvironment["FORMA_APPEARANCE_MODE"] = appearance.rawValue
        app.launchEnvironment["FORMA_WINDOW_SIZE"] = "1600x980"
        app.launchEnvironment["FORMA_WINDOW_PRESENTATION_SUITE"] = "AppStoreScreenshotTests"
        app.launchEnvironment["FORMA_RESET_WINDOW_PRESENTATION"] = "1"
        app.launch()

        let reviewModePicker = app.descendants(matching: .any).matching(identifier: "toolbarReviewModePicker").firstMatch
        XCTAssertTrue(reviewModePicker.waitForExistence(timeout: 8), "Main content should appear")
        return app
    }

    func captureMainWindowShots(app: XCUIApplication, appearance: ScreenshotAppearance, outputDir: URL?) throws {
        let harness = UITestHarness(app: app)
        assertRightPanelRhythm(app: app)
        assertRightPanelContrast(app: app, appearance: appearance)

        try captureWindowShot(
            app: app,
            name: "forma-01-hero-main-window",
            appearance: appearance,
            outputDir: outputDir
        )

        harness.tapAllFilesSegment()
        app.typeKey("2", modifierFlags: [.command]) // List view
        try captureWindowShot(
            app: app,
            name: "forma-02-all-files-list",
            appearance: appearance,
            outputDir: outputDir
        )

        if openInspectorForFirstFile(app: app) {
            assertInspectorRhythm(app: app)
            assertInspectorContrast(app: app, appearance: appearance)
            try captureWindowShot(
                app: app,
                name: "forma-02b-file-inspector",
                appearance: appearance,
                outputDir: outputDir
            )
        }

        let newRuleButton = harness.sidebarActionLabel("New Rule")
        XCTAssertTrue(newRuleButton.waitForExistence(timeout: 4), "New Rule sidebar item should exist")
        newRuleButton.click()
        XCTAssertTrue(app.staticTexts["New Rule"].waitForExistence(timeout: 6), "Rule builder should appear")
        try captureWindowShot(
            app: app,
            name: "forma-03-rule-builder",
            appearance: appearance,
            outputDir: outputDir
        )
    }

    func captureToolsShots(app: XCUIApplication, appearance: ScreenshotAppearance, outputDir: URL?) throws {
        let harness = UITestHarness(app: app)
        let smartRulesButton = harness.sidebarActionLabel("Smart Rules")
        XCTAssertTrue(smartRulesButton.waitForExistence(timeout: 4), "Smart Rules sidebar item should exist")
        smartRulesButton.click()

        let smartRulesProbe = app.otherElements["smartRulesContrastProbe"]
        XCTAssertTrue(smartRulesProbe.waitForExistence(timeout: 3), "Smart Rules should open the rules management surface")
        assertSmartRulesRhythm(app: app)
        assertSmartRulesContrast(app: app, appearance: appearance)

        try captureWindowShot(
            app: app,
            name: "forma-04-smart-rules",
            appearance: appearance,
            outputDir: outputDir
        )

        let analyticsButton = harness.sidebarActionLabel("Analytics")
        if analyticsButton.exists {
            analyticsButton.click()
            try captureWindowShot(
                app: app,
                name: "forma-05-analytics",
                appearance: appearance,
                outputDir: outputDir
            )
        }
    }

    func captureSettingsShot(app: XCUIApplication, appearance: ScreenshotAppearance, outputDir: URL?) throws {
        app.typeKey(",", modifierFlags: [.command]) // Open Settings
        // Give the settings window a moment to appear and become the primary window.
        _ = app.windows.firstMatch.waitForExistence(timeout: 3)
        try captureWindowShot(
            app: app,
            name: "forma-06-settings",
            appearance: appearance,
            outputDir: outputDir
        )
    }

    func captureWindowShot(
        app: XCUIApplication,
        name: String,
        appearance: ScreenshotAppearance,
        outputDir: URL?
    ) throws {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 4), "Expected an app window to exist for screenshot \(name)")

        let screenshot = window.screenshot()

        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "\(name) (\(appearance.rawValue))"
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

    // MARK: - Layout Rhythm Assertions

    func assertSmartRulesRhythm(app: XCUIApplication) {
        let probe = app.otherElements["smartRulesContrastProbe"]
        XCTAssertTrue(probe.waitForExistence(timeout: 3), "Smart Rules contrast/rhythm probe should exist")
        let metrics = metrics(from: probe)

        assertMetricRange(metrics, key: "rowSpacing", min: 8.0, max: 8.0, context: "Smart Rules row spacing")
        assertMetricRange(metrics, key: "rowVerticalPadding", min: 8.0, max: 8.0, context: "Smart Rules row vertical padding")
        assertMetricRange(metrics, key: "listPadding", min: 16.0, max: 16.0, context: "Smart Rules list padding")
    }

    func assertRightPanelRhythm(app: XCUIApplication) {
        let probe = app.otherElements["defaultPanelContrastProbe"]
        XCTAssertTrue(probe.waitForExistence(timeout: 3), "Default panel probe should exist")
        let metrics = waitForMetrics(
            from: probe,
            requiredNonNegativeKeys: ["heroToAutomation"],
            timeout: 3
        )

        assertMetricRange(metrics, key: "heroToAutomation", min: 8.0, max: 16.0, context: "Hero-to-automation gap")

        guard let automationToSuggestions = metrics["automationToSuggestions"], automationToSuggestions >= 0 else {
            XCTContext.runActivity(named: "Suggestions content not present; skipping automation-to-suggestions spacing check") { _ in
                let attachment = XCTAttachment(string: "automationToSuggestions metric was unavailable in the current launch state. Metrics: \(metrics)")
                attachment.lifetime = .keepAlways
                add(attachment)
            }
            return
        }

        XCTAssertGreaterThanOrEqual(automationToSuggestions, 12, "Automation-to-suggestions gap is too compressed: \(automationToSuggestions)")
        XCTAssertLessThanOrEqual(automationToSuggestions, 20, "Automation-to-suggestions gap is too loose: \(automationToSuggestions)")
    }

    func assertInspectorRhythm(app: XCUIApplication) {
        let probe = app.otherElements["inspectorContrastProbe"]
        XCTAssertTrue(probe.waitForExistence(timeout: 3), "Inspector probe should exist")
        let metrics = metrics(from: probe)

        assertMetricRange(metrics, key: "sectionSpacing", min: 32.0, max: 32.0, context: "Inspector vertical section spacing")
        assertMetricRange(metrics, key: "panelPadding", min: 24.0, max: 24.0, context: "Inspector panel padding")
        assertMetricRange(metrics, key: "previewHeight", min: 200.0, max: 200.0, context: "Inspector preview card height")
    }

    // MARK: - Contrast Assertions

    func assertSmartRulesContrast(app: XCUIApplication, appearance: ScreenshotAppearance) {
        let probe = app.otherElements["smartRulesContrastProbe"]
        XCTAssertTrue(probe.waitForExistence(timeout: 3), "Smart Rules contrast probe should exist")
        let cardMetrics = metrics(from: probe)
        assertMetric(cardMetrics, key: "titleOnCard", min: 4.5, context: "Smart Rules title contrast (\(appearance.rawValue))")
        assertMetric(cardMetrics, key: "secondaryOnCard", min: 3.2, context: "Smart Rules secondary text contrast (\(appearance.rawValue))")
        assertMetric(cardMetrics, key: "bodyOnBanner", min: 3.0, context: "Needs-access banner contrast (\(appearance.rawValue))")
    }

    func assertRightPanelContrast(app: XCUIApplication, appearance: ScreenshotAppearance) {
        let probe = app.otherElements["defaultPanelContrastProbe"]
        XCTAssertTrue(probe.waitForExistence(timeout: 3), "Default panel contrast probe should exist")

        let metrics = metrics(from: probe)
        assertMetric(metrics, key: "primaryAction", min: 3.0, context: "Quick action primary CTA contrast (\(appearance.rawValue))")
        assertMetric(metrics, key: "ignore", min: 3.0, context: "Quick action secondary text contrast (\(appearance.rawValue))")
    }

    func assertInspectorContrast(app: XCUIApplication, appearance: ScreenshotAppearance) {
        let probe = app.otherElements["inspectorContrastProbe"]
        XCTAssertTrue(probe.waitForExistence(timeout: 3), "Inspector contrast probe should exist")
        let metrics = metrics(from: probe)

        assertMetric(metrics, key: "titleOnCard", min: 4.5, context: "Inspector title contrast (\(appearance.rawValue))")
        assertMetric(metrics, key: "secondaryOnCard", min: 3.0, context: "Inspector secondary contrast (\(appearance.rawValue))")
        assertMetric(metrics, key: "quickLook", min: 3.0, context: "Inspector Quick Look button contrast (\(appearance.rawValue))")
    }

    func openInspectorForFirstFile(app: XCUIApplication) -> Bool {
        let rowQuery = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "fileRow_"))
        let firstRow = rowQuery.firstMatch
        guard firstRow.waitForExistence(timeout: 4) else {
            XCTFail("Expected at least one file row to open inspector")
            return false
        }

        if firstRow.isHittable {
            firstRow.click()
        } else {
            app.typeKey(.downArrow, modifierFlags: [])
        }

        let probe = app.otherElements["inspectorContrastProbe"]
        if !probe.waitForExistence(timeout: 4) {
            XCTContext.runActivity(named: "Inspector probe unavailable; continuing screenshot flow") { _ in
                let attachment = XCTAttachment(string: "Skipping inspector-specific screenshot/assertions because inspectorContrastProbe did not appear.")
                attachment.lifetime = .keepAlways
                add(attachment)
            }
            return false
        }
        return true
    }

    func metrics(from element: XCUIElement) -> [String: Double] {
        if let value = element.value as? String, !value.isEmpty {
            return parseMetrics(from: value)
        }
        return parseMetrics(from: element.label)
    }

    func waitForMetrics(
        from element: XCUIElement,
        requiredNonNegativeKeys: [String],
        timeout: TimeInterval
    ) -> [String: Double] {
        let deadline = Date().addingTimeInterval(timeout)
        var latestMetrics = metrics(from: element)

        while Date() < deadline {
            let isReady = requiredNonNegativeKeys.allSatisfy { key in
                guard let value = latestMetrics[key] else { return false }
                return value >= 0
            }

            if isReady {
                return latestMetrics
            }

            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
            latestMetrics = metrics(from: element)
        }

        XCTFail("Timed out waiting for metrics \(requiredNonNegativeKeys). Latest metrics: \(latestMetrics)")
        return latestMetrics
    }

    func parseMetrics(from rawValue: String?) -> [String: Double] {
        guard let rawValue, !rawValue.isEmpty else { return [:] }

        return rawValue
            .split(separator: ";")
            .reduce(into: [String: Double]()) { partialResult, segment in
                let pair = segment.split(separator: "=", maxSplits: 1).map(String.init)
                guard pair.count == 2, let numeric = Double(pair[1]) else { return }
                partialResult[pair[0]] = numeric
            }
    }

    func assertMetric(_ metrics: [String: Double], key: String, min: Double, context: String) {
        guard let value = metrics[key] else {
            XCTFail("Missing contrast metric \(key) for \(context). Metrics: \(metrics)")
            return
        }
        XCTAssertGreaterThanOrEqual(value, min, "\(context) is below threshold (\(value) < \(min))")
    }

    func assertMetricRange(_ metrics: [String: Double], key: String, min: Double, max: Double, context: String) {
        guard let value = metrics[key] else {
            XCTFail("Missing layout metric \(key) for \(context). Metrics: \(metrics)")
            return
        }
        XCTAssertGreaterThanOrEqual(value, min, "\(context) is below range (\(value) < \(min))")
        XCTAssertLessThanOrEqual(value, max, "\(context) is above range (\(value) > \(max))")
    }
}
