//
//  Forma_File_OrganizingUITests.swift
//  Forma File OrganizingUITests
//
//  Created by James Farmer on 11/17/25.
//

import AppKit
import Darwin
import XCTest

final class Forma_File_OrganizingUITests: XCTestCase {

    var app: XCUIApplication!
    var harness: UITestHarness!

    override func setUp() async throws {
        try UITestGating.requireUI()
        continueAfterFailure = false

        let isLaunchPerformanceTest = name.contains("testLaunchPerformance")
        let usesCustomLaunchWindowSize = requiresManualLaunch
        if !isLaunchPerformanceTest {
            terminateRunningAppIfNeeded()
        }

        if usesCustomLaunchWindowSize {
            app = nil
            harness = nil
            return
        }

        let defaultWindowPresentationSuiteName = defaultWindowPresentationSuiteName
        let launchedApp = await MainActor.run {
            let app = XCUIApplication()
            // Pass a launch argument to indicate UI test mode, which can be used
            // to seed mock data or skip onboarding
            app.launchArguments = ["--uitesting", "-ApplePersistenceIgnoreState", "YES"]
            app.launchEnvironment["FORMA_WINDOW_PRESENTATION_SUITE"] = defaultWindowPresentationSuiteName
            app.launchEnvironment["FORMA_RESET_WINDOW_PRESENTATION"] = "1"

            if !isLaunchPerformanceTest {
                app.launch()
                // Wait for the app to settle
                _ = app.wait(for: .runningForeground, timeout: 5)
            }
            return app
        }

        app = launchedApp
        harness = UITestHarness(app: launchedApp)
    }

    override func tearDown() async throws {
        app = nil
        harness = nil
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

    // MARK: - Keyboard Navigation Tests

    @MainActor
    func testMediumWindowLaunchDefaultsToTwoColumnLayout() throws {
        launchApp(windowSize: "1340x900")
        harness.waitForMainContent()

        let splitProbe = harness.splitLayoutProbe()
        harness.waitForExists(splitProbe, timeout: 4, message: "Split layout probe should exist")
        harness.waitForSplitLayout("twoColumn", timeout: 4)
    }

    @MainActor
    func testLargeWindowLaunchDefaultsToThreeColumnLayoutWhenInspectorHasMeaningfulContent() throws {
        launchApp(windowSize: "1600x980")
        harness.waitForMainContent()

        let splitProbe = harness.splitLayoutProbe()
        harness.waitForExists(splitProbe, timeout: 4, message: "Split layout probe should exist")
        harness.waitForSplitLayout("threeColumn", timeout: 4)
    }

    @MainActor
    func testInspectorVisibilityPersistsAcrossRelaunches() throws {
        let suiteName = "\(defaultWindowPresentationSuiteName).inspectorPersistence"
        launchApp(
            windowSize: "1600x980",
            suiteName: suiteName,
            resetWindowPresentation: true
        )
        harness.waitForMainContent()

        let splitProbe = harness.splitLayoutProbe()
        harness.waitForExists(splitProbe, timeout: 4, message: "Split layout probe should exist")
        harness.waitForSplitLayout("threeColumn", timeout: 4)

        app.activate()
        app.typeKey("i", modifierFlags: .command)
        harness.waitForSplitLayout("twoColumn", timeout: 4)

        launchApp(
            windowSize: "1600x980",
            suiteName: suiteName,
            resetWindowPresentation: false
        )
        harness.waitForMainContent()
        harness.waitForSplitLayout("twoColumn", timeout: 4)
    }

    @MainActor
    func testRestoredWindowFrameIsBroughtBackOntoVisibleDisplay() throws {
        let suiteName = "\(defaultWindowPresentationSuiteName).restoredFrameValidation"
        let screenFrames = NSScreen.screens.map(\.frame)
        guard let furthestVisibleEdge = screenFrames.map(\.maxX).max(),
              let largestScreenFrame = screenFrames.max(by: {
                  ($0.width * $0.height) < ($1.width * $1.height)
              }) else {
            XCTFail("Expected at least one visible screen frame")
            return
        }

        let restoredFrame = CGRect(
            x: furthestVisibleEdge + 1200,
            y: 120,
            width: largestScreenFrame.width + 400,
            height: largestScreenFrame.height + 260
        )

        launchApp(
            windowSize: "1340x900",
            suiteName: suiteName,
            resetWindowPresentation: true,
            restoredFrame: "\(restoredFrame.origin.x),\(restoredFrame.origin.y),\(restoredFrame.width),\(restoredFrame.height)"
        )
        harness.waitForMainContent()

        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 4), "Expected a restored main window")

        let frame = window.frame
        XCTAssertTrue(
            screenFrames.contains(where: { containsWindowFrame($0, windowFrame: frame) }),
            "Expected restored frame \(frame) to fit inside one physical screen frame \(screenFrames)"
        )
    }
    
    @MainActor
    func testKeyboardNavigationDownAndJ() throws {
        harness.waitForMainContent()
        app.activate()
        
        // Ensure there are files visible
        let scrollView = app.scrollViews["fileListScrollView"]
        XCTAssertTrue(scrollView.exists, "Center panel scroll view should exist")
        
        // Focus first file by pressing Down arrow
        app.typeKey(.downArrow, modifierFlags: [])
        
        // Now press J to move to next file
        app.typeText("j")
        
        // Verify that focus moved (this is indirect; in a real test you'd check
        // for a focused state indicator, e.g. a border or accessibility trait)
        // For now, just ensure no crash occurred
        XCTAssertTrue(app.exists)
    }
    
    @MainActor
    func testKeyboardNavigationUpAndK() throws {
        harness.waitForMainContent()
        app.activate()
        
        let scrollView = app.scrollViews["fileListScrollView"]
        XCTAssertTrue(scrollView.exists, "Center panel scroll view should exist")
        
        // Focus first file
        app.typeKey(.downArrow, modifierFlags: [])
        
        // Move to next file
        app.typeText("j")
        
        // Move back up with K
        app.typeText("k")
        
        // Verify app is still responsive
        XCTAssertTrue(app.exists)
    }
    
    @MainActor
    func testKeyboardNavigationArrowKeys() throws {
        harness.waitForMainContent()
        app.activate()
        
        let scrollView = app.scrollViews["fileListScrollView"]
        XCTAssertTrue(scrollView.exists, "Center panel scroll view should exist")
        
        // Navigate with Down arrow
        app.typeKey(.downArrow, modifierFlags: [])
        
        app.typeKey(.downArrow, modifierFlags: [])
        
        // Navigate back with Up arrow
        app.typeKey(.upArrow, modifierFlags: [])
        
        XCTAssertTrue(app.exists)
    }
    
    // MARK: - Review Mode Toggle
    
    @MainActor
    func testReviewModeToggleCountsUpdateWithActions() throws {
        harness.waitForMainContent()
        app.activate()
        
        // Initial counts should be data-driven based on seeded UI test mocks.
        let needsReviewButton = app.buttons["reviewMode_needsReview"]
        let allFilesButton = app.buttons["reviewMode_allFiles"]
        XCTAssertTrue(needsReviewButton.waitForExistence(timeout: 3))
        XCTAssertTrue(allFilesButton.exists)

        let initialCountRaw = harness.badgeValue(needsReviewButton)
        guard let initialCount = Int(initialCountRaw) else {
            XCTFail("Needs-review badge value should be numeric, got: \(initialCountRaw)")
            return
        }
        XCTAssertGreaterThan(initialCount, 0, "Needs-review should contain at least one file")

        let firstFileName = harness.firstVisibleFileName()
        
        // Skip the first file via keyboard (S)
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeText("s")

        harness.waitForFileRow(firstFileName, exists: false, timeout: 3)

        // Needs-review count should decrement by one.
        harness.waitForValue(needsReviewButton, equals: "\(max(initialCount - 1, 0))", timeout: 3)
    }
    
    @MainActor
    func testReviewModeToggleShowsSkippedInAllFilesButNotNeedsReview() throws {
        harness.waitForMainContent()
        app.activate()

        let firstFileName = harness.firstVisibleFileName()
        let firstCard = harness.fileRow(named: firstFileName)
        XCTAssertTrue(firstCard.waitForExistence(timeout: 3))
        
        // Verify initial segments
        let needsReviewButton = app.buttons["reviewMode_needsReview"]
        let allFilesButton = app.buttons["reviewMode_allFiles"]
        XCTAssertTrue(needsReviewButton.exists)
        XCTAssertTrue(allFilesButton.exists)
        
        // Skip the first file while in Needs Review mode
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeText("s")
        
        // Wait for the first card to disappear in Needs Review mode
        harness.waitForFileRow(firstFileName, exists: false, timeout: 3)
        
        // Switch to All Files mode
        allFilesButton.tap()
        
        // In All Files mode, skipped file should be visible again (non-completed)
        harness.waitForFileRow(firstFileName, exists: true, timeout: 3)
        
        // Switch back to Needs Review and ensure card is hidden again
        needsReviewButton.tap()
        harness.waitForFileRow(firstFileName, exists: false, timeout: 3)
    }

    @MainActor
    func testAnalyticsSelectionKeepsSidebarVisibleAndUsesTwoColumnLayout() throws {
        harness.waitForMainContent()
        app.activate()

        let analyticsButton = app.buttons["Analytics"]
        guard analyticsButton.exists else {
            throw XCTSkip("Analytics feature is disabled for this UI test runtime.")
        }

        analyticsButton.click()

        let productivityHeader = app.staticTexts["Productivity Health"]
        XCTAssertTrue(productivityHeader.waitForExistence(timeout: 4), "Analytics content should be visible")

        let smartRulesButton = app.buttons["Smart Rules"]
        XCTAssertTrue(smartRulesButton.waitForExistence(timeout: 4), "Sidebar should remain visible on Analytics")

        let splitProbe = harness.element(withIdentifier: "dashboardSplitLayoutProbe")
        harness.waitForExists(splitProbe, timeout: 4, message: "Split layout probe should exist")
        harness.waitForValue(splitProbe, equals: "twoColumn", timeout: 4)

        let inspectorToggle = app.buttons["toolbarInspectorToggle"]
        XCTAssertTrue(inspectorToggle.waitForExistence(timeout: 4), "Inspector toggle should remain visible in toolbar")
        XCTAssertFalse(inspectorToggle.isEnabled, "Inspector toggle should be disabled while viewing Analytics")
    }

    @MainActor
    func testInspectorHiddenStateUsesTwoColumnWithoutCollapsingSidebar() throws {
        harness.waitForMainContent()
        app.activate()

        let splitProbe = harness.element(withIdentifier: "dashboardSplitLayoutProbe")
        harness.waitForExists(splitProbe, timeout: 4, message: "Split layout probe should exist")
        harness.waitForValue(splitProbe, equals: "threeColumn", timeout: 4)

        let inspectorToggle = app.buttons["toolbarInspectorToggle"]
        XCTAssertTrue(inspectorToggle.waitForExistence(timeout: 4), "Inspector toggle should exist")
        XCTAssertTrue(inspectorToggle.isEnabled, "Inspector toggle should be enabled on non-Analytics views")

        inspectorToggle.click()
        harness.waitForValue(splitProbe, equals: "twoColumn", timeout: 4)

        let smartRulesButton = app.buttons["Smart Rules"]
        XCTAssertTrue(smartRulesButton.waitForExistence(timeout: 4), "Sidebar should remain visible when inspector is hidden")
    }

    @MainActor
    func testAccessibilityStateIdentifiersAcrossViewModes() throws {
        harness.waitForMainContent()
        app.activate()

        let fileName = harness.firstVisibleFileName()

        let reviewModeProbe = harness.element(withIdentifier: "mainContent_reviewMode")
        let needsReviewCountProbe = harness.element(withIdentifier: "mainContent_needsReviewCount")
        let allFilesCountProbe = harness.element(withIdentifier: "mainContent_allFilesCount")
        let selectedCountProbe = harness.element(withIdentifier: "mainContent_selectedCount")
        let focusedFilePathProbe = harness.element(withIdentifier: "mainContent_focusedFilePath")
        let needsReviewButton = app.buttons["reviewMode_needsReview"]
        let allFilesButton = app.buttons["reviewMode_allFiles"]

        harness.waitForExists(reviewModeProbe, timeout: 3, message: "Review mode probe should exist")
        harness.waitForExists(needsReviewCountProbe, timeout: 3, message: "Needs-review count probe should exist")
        harness.waitForExists(allFilesCountProbe, timeout: 3, message: "All-files count probe should exist")
        harness.waitForExists(selectedCountProbe, timeout: 3, message: "Selected-count probe should exist")
        harness.waitForExists(focusedFilePathProbe, timeout: 3, message: "Focused-file probe should exist")
        XCTAssertTrue(needsReviewButton.waitForExistence(timeout: 3), "Needs-review mode button should exist")
        XCTAssertTrue(allFilesButton.waitForExistence(timeout: 3), "All-files mode button should exist")
        needsReviewButton.tap()

        // Force card view before asserting card-specific probes.
        app.typeKey("3", modifierFlags: .command)
        let cardState = harness.element(withIdentifier: "fileRowState_\(fileName)")
        harness.waitForExists(cardState, timeout: 3, message: "Card row state probe should exist")
        harness.waitForValue(cardState, contains: "view=card", timeout: 3)

        // Verify selection status probes update.
        app.typeKey("a", modifierFlags: .command)
        harness.waitForValue(cardState, contains: "selected=1", timeout: 3)

        // List mode probe
        app.typeKey("2", modifierFlags: .command)
        let listState = harness.element(withIdentifier: "fileListRowState_\(fileName)")
        harness.waitForExists(listState, timeout: 3, message: "List row state probe should exist")
        harness.waitForValue(listState, contains: "view=list", timeout: 3)
        harness.waitForValue(listState, contains: "selected=1", timeout: 3)

        // Grid mode probe
        app.typeKey("1", modifierFlags: .command)
        let gridState = harness.element(withIdentifier: "fileGridItemState_\(fileName)")
        harness.waitForExists(gridState, timeout: 3, message: "Grid item state probe should exist")
        harness.waitForValue(gridState, contains: "view=grid", timeout: 3)
        harness.waitForValue(gridState, contains: "selected=1", timeout: 3)

        // Deselect and ensure row-state probe reflects unselected.
        app.typeKey("d", modifierFlags: .command)
        harness.waitForValue(gridState, contains: "selected=0", timeout: 3)
    }

    @MainActor
    func testNeedsReviewModeExposesReviewSectionOrderAndCurrentPassSummary() throws {
        harness.waitForMainContent()
        app.activate()

        harness.tapNeedsReviewSegment()
        harness.tapListViewSegment()
        harness.waitForViewMode("list")

        let sectionOrderProbe = harness.element(withIdentifier: "mainContent_reviewSectionOrder")
        let sectionCountsProbe = harness.element(withIdentifier: "mainContent_reviewSectionCounts")
        let contextSummary = harness.element(withIdentifier: "toolbarContextSummary")

        harness.waitForExists(sectionOrderProbe, timeout: 3, message: "Review section order probe should exist")
        harness.waitForExists(sectionCountsProbe, timeout: 3, message: "Review section counts probe should exist")
        harness.waitForValue(sectionOrderProbe, equals: "ready,review,destination", timeout: 3)
        harness.waitForValue(sectionCountsProbe, contains: "ready=", timeout: 3)
        harness.waitForValue(sectionCountsProbe, contains: "review=", timeout: 3)
        harness.waitForValue(sectionCountsProbe, contains: "destination=", timeout: 3)
        harness.waitForValue(contextSummary, contains: "in current pass", timeout: 3)
    }

    @MainActor
    func testNeedsReviewFloatingActionBarUsesSetAsideCopyAndStatusProbe() throws {
        harness.waitForMainContent()
        app.activate()

        harness.tapNeedsReviewSegment()

        let setAsideButton = app.buttons["Set Aside"]
        let legacyButton = app.buttons["Done for now"]
        let reviewStatusProbe = harness.element(withIdentifier: "floatingActionBar_reviewStatus")

        XCTAssertTrue(setAsideButton.waitForExistence(timeout: 3), "Needs-review bar should expose Set Aside")
        XCTAssertFalse(legacyButton.exists, "Legacy Done for now copy should be removed")
        harness.waitForExists(reviewStatusProbe, timeout: 3, message: "Review floating bar status probe should exist")
        harness.waitForValue(reviewStatusProbe, contains: "ready to organize", timeout: 3)
    }

    @MainActor
    func testNeedsReviewCurrentTaskCardUsesPassScopedProgressAndShortSectionCopy() throws {
        harness.waitForMainContent()
        app.activate()

        harness.tapNeedsReviewSegment()

        let progressSummary = harness.element(withIdentifier: "defaultPanelProgressSummary")
        harness.waitForExists(progressSummary, timeout: 3, message: "Current-task progress summary should exist")
        harness.waitForValue(progressSummary, equals: "0 of 8 organized", timeout: 3)

        XCTAssertTrue(
            app.staticTexts["Destination set — ready now."].waitForExistence(timeout: 3),
            "Ready section should use the tightened subtitle copy"
        )
        XCTAssertTrue(
            app.staticTexts["Destination set — confirm to organize."].waitForExistence(timeout: 3),
            "Needs review section should use the tightened subtitle copy"
        )
        XCTAssertTrue(
            app.staticTexts["No destination yet — choose one to continue."].waitForExistence(timeout: 3),
            "Needs destination section should use the tightened subtitle copy"
        )
    }

    @MainActor
    func testLockedFoldersExposeRequestAccessAffordance() throws {
        harness.waitForMainContent()
        harness.ensureSidebarVisible()

        let lockedDocuments = app.otherElements.matching(
            NSPredicate(format: "label == %@", "Documents, Access required")
        ).firstMatch
        harness.waitForExists(
            lockedDocuments,
            timeout: 3,
            message: "Locked standard folders should remain visible in the sidebar"
        )
        let requestAccess = app.buttons["sidebarRequestAccess_documents"]
        harness.waitForExists(
            requestAccess,
            timeout: 3,
            message: "Locked standard folders should expose the explicit Request Access affordance"
        )
        XCTAssertEqual(requestAccess.label, "Request Access")
    }

    @MainActor
    func testNeedsReviewContextMenuExposesChooseDestinationForDestinationlessFile() throws {
        throw XCTSkip("macOS XCUITest secondary-click does not reliably surface the SwiftUI row context menu; destination editing is covered by keyboard shortcut coverage.")

        harness.waitForMainContent()
        app.activate()

        harness.tapNeedsReviewSegment()
        app.scrollViews["fileListScrollView"].swipeUp()

        let destinationlessRow = harness.fileRow(named: "IMG_1042.JPG")
        XCTAssertTrue(destinationlessRow.waitForExistence(timeout: 3), "Expected a deterministic destinationless mock row")

        let primaryRowTarget = destinationlessRow.buttons.element(boundBy: 1)
        XCTAssertTrue(primaryRowTarget.waitForExistence(timeout: 3), "Expected the destinationless row to expose a primary interaction target")

        primaryRowTarget.click()
        primaryRowTarget.rightClick()

        let chooseDestinationItem = app.menuItems.matching(
            NSPredicate(format: "label == %@", "Choose Destination")
        ).firstMatch
        XCTAssertTrue(
            chooseDestinationItem.waitForExistence(timeout: 3),
            "Destinationless rows should expose Choose Destination in the context menu"
        )

        chooseDestinationItem.click()

        let sheet = app.otherElements["editDestinationSheet"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 3), "Choose Destination should open the destination sheet")

        app.typeKey(.escape, modifierFlags: [])
    }
    
    // MARK: - File Action Tests
    
    @MainActor
    func testKeyboardShortcutSpace_QuickLook() throws {
        harness.waitForMainContent()
        app.activate()
        
        // Focus a file
        app.typeKey(.downArrow, modifierFlags: [])
        
        // Press Space to trigger Quick Look
        app.typeText(" ")
        
        // Quick Look should open; verify the app is still responsive
        // (Quick Look is a system panel and may not be easily queryable)
        XCTAssertTrue(app.exists)
    }
    
    @MainActor
    func testKeyboardShortcutS_Skip() throws {
        harness.waitForMainContent()
        app.activate()

        let firstFileName = harness.firstVisibleFileName()
        let firstCard = harness.fileRow(named: firstFileName)
        XCTAssertTrue(firstCard.waitForExistence(timeout: 3))
        
        // Focus first file
        app.typeKey(.downArrow, modifierFlags: [])
        
        // Press S to skip the file
        app.typeText("s")
        
        // Skipped file should disappear from Needs Review list
        harness.waitForFileRow(firstFileName, exists: false, timeout: 3)
    }
    
    @MainActor
    func testKeyboardShortcutE_EditDestination() throws {
        harness.waitForMainContent()
        app.activate()

        let firstFileName = harness.firstVisibleFileName()
        let firstCard = harness.fileRow(named: firstFileName)
        XCTAssertTrue(firstCard.waitForExistence(timeout: 3))
        
        // Focus the first file
        app.typeKey(.downArrow, modifierFlags: [])
        
        // Press E to open Edit Destination sheet
        app.typeText("e")
        
        let sheet = app.otherElements["editDestinationSheet"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 3), "Edit destination sheet should appear")
        
        // Dismiss the sheet by pressing Escape
        app.typeKey(.escape, modifierFlags: [])
    }
    
    @MainActor
    func testKeyboardShortcutR_CreateRule() throws {
        harness.waitForMainContent()
        app.activate()

        let firstFileName = harness.firstVisibleFileName()
        let firstCard = harness.fileRow(named: firstFileName)
        XCTAssertTrue(firstCard.waitForExistence(timeout: 3))
        
        // Focus the first file
        app.typeKey(.downArrow, modifierFlags: [])
        
        // Press R to open rule editor
        app.typeText("r")
        
        let editor = app.otherElements["ruleEditorView"]
        XCTAssertTrue(editor.waitForExistence(timeout: 3), "Rule editor should appear")
        
        // Dismiss rule editor
        app.typeKey(.escape, modifierFlags: [])
    }
    
    @MainActor
    func testKeyboardShortcutEnter_Organize() throws {
        harness.waitForMainContent()
        app.activate()

        let firstFileName = harness.firstVisibleFileName()
        let firstCard = harness.fileRow(named: firstFileName)
        XCTAssertTrue(firstCard.waitForExistence(timeout: 3))
        
        // Focus the first file (has a suggested destination)
        app.typeKey(.downArrow, modifierFlags: [])
        
        // Press Enter to organize the file
        app.typeKey(.enter, modifierFlags: [])
        
        // Organized file should disappear from visible list (marked completed)
        harness.waitForFileRow(firstFileName, exists: false, timeout: 3)
    }
    
    @MainActor
    func testKeyboardShortcutCmdEnter_OrganizeAndMoveNext() throws {
        harness.waitForMainContent()
        app.activate()

        let initialFileNames = harness.visibleFileNames()
        guard let firstFileName = initialFileNames.first else {
            XCTFail("Expected at least one visible file")
            return
        }
        let secondFileName = initialFileNames.dropFirst().first

        let firstCard = harness.fileRow(named: firstFileName)
        XCTAssertTrue(firstCard.waitForExistence(timeout: 3))
        
        // Focus first file
        app.typeKey(.downArrow, modifierFlags: [])
        
        // Press Cmd+Enter to organize and move focus to next
        app.typeKey(.enter, modifierFlags: .command)
        
        // First card should be gone, second still present
        harness.waitForFileRow(firstFileName, exists: false, timeout: 3)

        if let secondFileName {
            let secondCard = harness.fileRow(named: secondFileName)
            XCTAssertTrue(secondCard.exists, "Expected next file to remain visible after Cmd+Enter")
        }
    }
    
    // MARK: - Integration Test
    
    @MainActor
    func testKeyboardWorkflow_NavigateAndOrganize() throws {
        harness.waitForMainContent()
        app.activate()

        let initialFileNames = harness.visibleFileNames()
        XCTAssertGreaterThanOrEqual(initialFileNames.count, 3, "Expected at least three visible files for workflow test")

        let firstFileName = initialFileNames[0]
        let secondFileName = initialFileNames[1]
        let thirdFileName = initialFileNames[2]

        let firstCard = harness.fileRow(named: firstFileName)
        let secondCard = harness.fileRow(named: secondFileName)
        let thirdCard = harness.fileRow(named: thirdFileName)
        XCTAssertTrue(firstCard.waitForExistence(timeout: 3))
        XCTAssertTrue(secondCard.exists)
        XCTAssertTrue(thirdCard.exists)
        
        // Focus first file
        app.typeKey(.downArrow, modifierFlags: [])
        
        // Skip the first file
        app.typeText("s")
        
        harness.waitForFileRow(firstFileName, exists: false, timeout: 3)
        
        // Move to next file (now the former second)
        app.typeText("j")
        
        // Attempt to organize the focused file.
        app.typeKey(.enter, modifierFlags: [])
        XCTAssertTrue(app.exists)
        
        // Move to third file and open Quick Look
        app.typeText("j")
        app.typeText(" ")
        
        // Quick Look is external to the app; ensure app stays responsive and at least one downstream file remains visible.
        XCTAssertTrue(app.exists)
        XCTAssertTrue(secondCard.exists || thirdCard.exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments = ["--uitesting", "-ApplePersistenceIgnoreState", "YES"]
            app.launch()
        }
    }
}

private extension Forma_File_OrganizingUITests {
    var requiresManualLaunch: Bool {
        name.contains("testMediumWindowLaunchDefaultsToTwoColumnLayout") ||
        name.contains("testLargeWindowLaunchDefaultsToThreeColumnLayoutWhenInspectorHasMeaningfulContent") ||
        name.contains("testInspectorVisibilityPersistsAcrossRelaunches")
    }

    var defaultWindowPresentationSuiteName: String {
        sanitizeSuiteName(name)
    }

    @MainActor
    func launchApp(
        windowSize: String,
        suiteName: String? = nil,
        resetWindowPresentation: Bool = true,
        restoredFrame: String? = nil
    ) {
        app?.terminate()
        terminateRunningAppIfNeeded()

        let launchedApp = XCUIApplication()
        launchedApp.launchArguments = ["--uitesting", "-ApplePersistenceIgnoreState", "YES"]
        launchedApp.launchEnvironment["FORMA_WINDOW_SIZE"] = windowSize
        if let restoredFrame {
            launchedApp.launchEnvironment["FORMA_RESTORED_WINDOW_FRAME"] = restoredFrame
        }
        configureWindowPresentationIsolation(
            for: launchedApp,
            suiteName: suiteName ?? defaultWindowPresentationSuiteName,
            resetWindowPresentation: resetWindowPresentation
        )
        launchedApp.launch()
        _ = launchedApp.wait(for: .runningForeground, timeout: 5)

        app = launchedApp
        harness = UITestHarness(app: launchedApp)
    }

    @MainActor
    func configureWindowPresentationIsolation(
        for app: XCUIApplication,
        suiteName: String? = nil,
        resetWindowPresentation: Bool = true
    ) {
        app.launchEnvironment["FORMA_WINDOW_PRESENTATION_SUITE"] = suiteName ?? defaultWindowPresentationSuiteName
        app.launchEnvironment["FORMA_RESET_WINDOW_PRESENTATION"] = resetWindowPresentation ? "1" : "0"
    }

    func sanitizeSuiteName(_ rawValue: String) -> String {
        let sanitized = rawValue.map { character -> Character in
            if character.isLetter || character.isNumber {
                return character
            }
            return "_"
        }
        return "FormaUITests.\(String(sanitized))"
    }

    private func containsWindowFrame(_ visibleFrame: CGRect, windowFrame: CGRect, tolerance: CGFloat = 4) -> Bool {
        windowFrame.minX >= visibleFrame.minX - tolerance &&
        windowFrame.maxX <= visibleFrame.maxX + tolerance &&
        windowFrame.minY >= visibleFrame.minY - tolerance &&
        windowFrame.maxY <= visibleFrame.maxY + tolerance
    }
}
