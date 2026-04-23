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
            app.launchEnvironment["FORMA_UI_TEST_SHOW_ONBOARDING"] = "0"
            app.launchEnvironment["FORMA_UI_TEST_ACCESSIBLE_FOLDERS"] = "desktop,downloads"
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
    func testMediumWindowLaunchDefaultsToHomeWorkspaceThreeColumnLayout() throws {
        launchApp(windowSize: "1340x900")
        harness.waitForMainContent()

        let splitProbe = harness.splitLayoutProbe()
        harness.waitForExists(splitProbe, timeout: 4, message: "Split layout probe should exist")
        harness.waitForSplitLayout("threeColumn", timeout: 4)
        harness.waitForWorkspaceDestination("homeWorkspace", timeout: 4)
        harness.waitForSplitArrangement("sidebarContentAndInspector", timeout: 4)
    }

    @MainActor
    func testLargeWindowLaunchUsesPreferredInspectorWidth() throws {
        launchApp(windowSize: "1600x980")
        harness.waitForMainContent()

        let splitProbe = harness.splitLayoutProbe()
        harness.waitForExists(splitProbe, timeout: 4, message: "Split layout probe should exist")
        harness.waitForSplitLayout("threeColumn", timeout: 4)
        harness.waitForWorkspaceDestination("homeWorkspace", timeout: 4)
        harness.waitForSplitArrangement("sidebarContentAndInspector", timeout: 4)

        let widthValue = harness.homeInspectorWidth()
        XCTAssertGreaterThanOrEqual(widthValue, 360, "Home should launch with a non-thin inspector width")
        XCTAssertLessThanOrEqual(widthValue, 420, "Home inspector width should stay within the supported range")
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
        harness.waitForWorkspaceDestination("homeWorkspace", timeout: 4)

        app.activate()
        app.typeKey("i", modifierFlags: .command)
        harness.waitForSplitLayout("twoColumn", timeout: 4)
        harness.waitForWorkspaceDestination("homeWorkspace", timeout: 4)

        launchApp(
            windowSize: "1600x980",
            suiteName: suiteName,
            resetWindowPresentation: false
        )
        harness.waitForMainContent()
        harness.waitForSplitLayout("twoColumn", timeout: 4)
        harness.waitForWorkspaceDestination("homeWorkspace", timeout: 4)
    }

    @MainActor
    func testInspectorRelaunchRestoresVisibleInspectorContent() throws {
        let suiteName = "\(defaultWindowPresentationSuiteName).inspectorVisiblePersistence"
        launchApp(
            windowSize: "1600x980",
            suiteName: suiteName,
            resetWindowPresentation: true
        )
        harness.waitForMainContent()
        harness.waitForSplitLayout("threeColumn", timeout: 4)
        harness.waitForWorkspaceDestination("homeWorkspace", timeout: 4)

        let selectedCountProbe = harness.element(withIdentifier: "mainContent_selectedCount")
        harness.waitForExists(selectedCountProbe, timeout: 4, message: "Selected-count probe should exist")

        app.activate()
        app.typeKey("a", modifierFlags: .command)
        harness.waitForValue(selectedCountProbe, notEquals: "0", timeout: 4)

        let inspectorView = harness.element(withIdentifier: "fileInspectorView")
        harness.waitForExists(inspectorView, timeout: 4, message: "Inspector should be visible before relaunch")

        launchApp(
            windowSize: "1600x980",
            suiteName: suiteName,
            resetWindowPresentation: false
        )
        harness.waitForMainContent()
        harness.waitForSplitLayout("threeColumn", timeout: 4)
        harness.waitForWorkspaceDestination("homeWorkspace", timeout: 4)

        app.activate()
        app.typeKey("a", modifierFlags: .command)
        harness.waitForExists(
            harness.element(withIdentifier: "fileInspectorView"),
            timeout: 4,
            message: "Visible inspector state should restore without needing the user to re-open the inspector after relaunch"
        )
    }

    @MainActor
    func testWideThreeColumnRightPanelUsesRegularLayoutContract() throws {
        launchApp(windowSize: "1600x980")
        harness.waitForMainContent()
        harness.waitForSplitLayout("threeColumn", timeout: 4)

        let defaultProbe = harness.element(withIdentifier: "defaultPanelContrastProbe")
        harness.waitForExists(defaultProbe, timeout: 4, message: "Default panel probe should exist")
        harness.waitForValue(defaultProbe, contains: "widthClass=regular", timeout: 4)

        let selectedCountProbe = harness.element(withIdentifier: "mainContent_selectedCount")
        harness.waitForExists(selectedCountProbe, timeout: 4, message: "Selected-count probe should exist")
        harness.waitForValue(selectedCountProbe, equals: "0", timeout: 4)

        app.activate()
        app.typeKey("a", modifierFlags: .command)
        harness.waitForValue(selectedCountProbe, notEquals: "0", timeout: 4)

        let inspectorView = harness.element(withIdentifier: "fileInspectorView")
        harness.waitForExists(inspectorView, timeout: 4, message: "Inspector view should exist")
        harness.waitForValue(inspectorView, contains: "widthClass=regular", timeout: 4)
    }

    @MainActor
    func testNarrowHomeWorkspacePreservesCompactInspectorAndContextualRuleBuilder() throws {
        let suiteName = "\(defaultWindowPresentationSuiteName).compactRightPanel"
        launchApp(
            windowSize: "1600x980",
            suiteName: suiteName,
            resetWindowPresentation: true
        )
        harness.waitForMainContent()
        harness.waitForSplitLayout("threeColumn", timeout: 4)

        launchApp(
            windowSize: "1200x900",
            suiteName: suiteName,
            resetWindowPresentation: false,
            restoredFrame: "120,120,1200,900"
        )
        harness.waitForMainContent()
        harness.waitForSplitLayout("threeColumn", timeout: 4)
        harness.waitForWorkspaceDestination("homeWorkspace", timeout: 4)
        harness.waitForSplitArrangement("sidebarContentAndInspector", timeout: 4)
        let homeInspectorWidth = harness.homeInspectorWidth()
        XCTAssertLessThan(homeInspectorWidth, 340, "Narrow home workspace should keep the inspector in compact width")

        let widthProbe = harness.homeInspectorWidthProbe()
        harness.waitForExists(widthProbe, timeout: 4, message: "Home inspector width probe should exist")
        let compactWidth = Int(harness.badgeValue(widthProbe)) ?? 0
        XCTAssertLessThan(compactWidth, 340, "Narrow Home should compress the inspector into the compact contract")

        harness.ensureSidebarVisible()
        let newRuleButton = harness.sidebarActionLabel("New Rule")
        XCTAssertTrue(newRuleButton.waitForExistence(timeout: 4), "Sidebar New Rule action should remain visible")
        newRuleButton.click()

        let builder = harness.element(withIdentifier: "inlineRuleBuilderView")
        harness.waitForExists(builder, timeout: 4, message: "Inline rule builder should appear")
        harness.waitForWorkspaceDestination("homeWorkspace", timeout: 4)
        harness.waitForSplitArrangement("sidebarContentAndInspector", timeout: 4)
        harness.waitForValue(builder, contains: "widthClass=compact", timeout: 4)

        let saveButton = harness.element(withIdentifier: "ruleComposerSaveButton")
        XCTAssertTrue(saveButton.waitForExistence(timeout: 4), "Compact inline rule builder should keep the save action visible")
    }

    @MainActor
    func testWideHomeSidebarNewRuleUsesInlineBuilder() throws {
        launchApp(windowSize: "1600x980")
        harness.waitForMainContent()
        harness.waitForWorkspaceDestination("homeWorkspace", timeout: 4)
        harness.waitForSplitArrangement("sidebarContentAndInspector", timeout: 4)

        harness.ensureSidebarVisible()
        let newRuleButton = harness.sidebarAction("sidebarAction_newRule")
        XCTAssertTrue(newRuleButton.waitForExistence(timeout: 4), "Sidebar New Rule action should remain visible")
        newRuleButton.click()

        harness.waitForValue(harness.homeInspectorModeProbe(), equals: "ruleBuilder", timeout: 4)
        let saveButton = harness.element(withIdentifier: "ruleComposerSaveButton")
        XCTAssertTrue(saveButton.waitForExistence(timeout: 4), "Wide Home New Rule should surface the inline rule builder")
        harness.waitForWorkspaceDestination("homeWorkspace", timeout: 4)
        harness.waitForSplitArrangement("sidebarContentAndInspector", timeout: 4)
    }

    @MainActor
    func testSmartRulesSelectionKeepsSidebarVisibleAndUsesFullWorkspaceLayout() throws {
        launchApp(windowSize: "1600x980")
        harness.waitForMainContent()
        let homeInspectorWidth = harness.homeInspectorWidth()

        harness.ensureSidebarVisible()
        let smartRulesButton = harness.sidebarAction("sidebarAction_smartRules")
        XCTAssertTrue(smartRulesButton.waitForExistence(timeout: 4), "Smart Rules sidebar action should exist")
        smartRulesButton.click()

        XCTAssertTrue(harness.sidebar().waitForExistence(timeout: 4), "Sidebar should remain visible in Smart Rules workspace")
        let smartRulesView = harness.element(withIdentifier: "smartRulesView")
        harness.waitForExists(smartRulesView, timeout: 4, message: "Smart Rules view should exist")
        harness.waitForValue(smartRulesView, contains: "widthClass=regular", timeout: 4)
        harness.waitForWorkspaceDestination("rulesWorkspace", timeout: 4)
        harness.waitForSplitLayout("twoColumn", timeout: 4)
        harness.waitForSplitArrangement("sidebarAndWorkspace", timeout: 4)

        let backButton = harness.backToDashboardButton()
        XCTAssertTrue(backButton.waitForExistence(timeout: 4), "Rules workspace should expose a back affordance")
        assertInspectorToggleUnavailableOrDisabled()

        backButton.click()
        harness.waitForWorkspaceDestination("homeWorkspace", timeout: 4)
        harness.waitForSplitLayout("threeColumn", timeout: 4)
        harness.waitForSplitArrangement("sidebarContentAndInspector", timeout: 4)
        XCTAssertEqual(harness.homeInspectorWidth(), homeInspectorWidth, "Returning from Smart Rules should restore the prior Home inspector width")
    }

    @MainActor
    func testRulesWorkspaceRuleCreationUsesModalEditor() throws {
        launchApp(windowSize: "1600x980")
        harness.waitForMainContent()

        harness.ensureSidebarVisible()
        let smartRulesButton = harness.sidebarAction("sidebarAction_smartRules")
        XCTAssertTrue(smartRulesButton.waitForExistence(timeout: 4), "Smart Rules sidebar action should exist")
        smartRulesButton.click()

        harness.waitForWorkspaceDestination("rulesWorkspace", timeout: 4)
        harness.waitForSplitArrangement("sidebarAndWorkspace", timeout: 4)

        let headerNewRuleButton = harness.element(withIdentifier: "smartRulesNewRuleButton")
        let emptyStateCreateRuleButton = harness.element(withIdentifier: "smartRulesCreateRuleButton")
        let workspaceCreateRuleButton =
            headerNewRuleButton.waitForExistence(timeout: 1) ? headerNewRuleButton : emptyStateCreateRuleButton
        XCTAssertTrue(workspaceCreateRuleButton.waitForExistence(timeout: 4), "Rules workspace should expose a visible create-rule button")
        workspaceCreateRuleButton.click()

        let modalSaveButton = app.buttons["ruleComposerSaveButton"]
        XCTAssertTrue(modalSaveButton.waitForExistence(timeout: 4), "Rules workspace create actions should open the modal rule editor")
        harness.waitForWorkspaceDestination("rulesWorkspace", timeout: 4)

        let discardButton = app.buttons["Discard Draft"]
        XCTAssertTrue(discardButton.waitForExistence(timeout: 4), "Modal rule editor should expose a discard action")
        discardButton.click()
        harness.waitForWorkspaceDestination("rulesWorkspace", timeout: 4)

        harness.ensureSidebarVisible()
        let sidebarNewRuleButton = harness.sidebarAction("sidebarAction_newRule")
        XCTAssertTrue(sidebarNewRuleButton.waitForExistence(timeout: 4), "Sidebar New Rule action should remain visible in Rules workspace")
        sidebarNewRuleButton.click()

        XCTAssertTrue(modalSaveButton.waitForExistence(timeout: 4), "Sidebar New Rule should use a visible modal editor when Rules workspace is active")
        harness.waitForWorkspaceDestination("rulesWorkspace", timeout: 4)
    }

    @MainActor
    func testNarrowThreeColumnFileSurfacesUseCompactLayoutAcrossViewModes() throws {
        let suiteName = "\(defaultWindowPresentationSuiteName).compactFileSurfaces"
        launchApp(
            windowSize: "1600x980",
            suiteName: suiteName,
            resetWindowPresentation: true
        )
        harness.waitForMainContent()
        harness.waitForSplitLayout("threeColumn", timeout: 4)

        launchApp(
            windowSize: "1200x900",
            suiteName: suiteName,
            resetWindowPresentation: false,
            restoredFrame: "120,120,1200,900"
        )
        harness.waitForMainContent()
        harness.waitForSplitLayout("threeColumn", timeout: 4)
        harness.waitForWorkspaceDestination("homeWorkspace", timeout: 4)

        harness.tapAllFilesSegment()

        let fileName = "IMG_1042.JPG"
        let initialRow = harness.fileRow(named: fileName)
        XCTAssertTrue(initialRow.waitForExistence(timeout: 4), "Expected the no-destination UI test row to stay visible in a narrow three-column layout")

        harness.tapCardViewSegment()
        harness.waitForViewMode("card")
        let cardState = harness.element(withIdentifier: "fileRowState_\(fileName)")
        harness.waitForExists(cardState, timeout: 4, message: "Compact card-state probe should exist")
        harness.waitForValue(cardState, contains: "widthClass=compact", timeout: 4)

        let cardRow = harness.fileRow(named: fileName)
        let cardPrimaryAction = cardRow.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "filePrimaryAction_chooseDestination_\(fileName)__")
        ).firstMatch
        XCTAssertTrue(cardPrimaryAction.waitForExistence(timeout: 4), "Compact card view should keep the Choose Destination action visible")

        harness.tapListViewSegment()
        harness.waitForViewMode("list")
        let listState = harness.element(withIdentifier: "fileListRowState_\(fileName)")
        harness.waitForExists(listState, timeout: 4, message: "Compact list-state probe should exist")
        harness.waitForValue(listState, contains: "widthClass=compact", timeout: 4)

        let listRow = harness.fileRow(named: fileName)
        let listPrimaryAction = listRow.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "filePrimaryAction_chooseDestination_\(fileName)__")
        ).firstMatch
        XCTAssertTrue(listPrimaryAction.waitForExistence(timeout: 4), "Compact list view should keep the Choose Destination action visible")

        harness.tapGridViewSegment()
        harness.waitForViewMode("grid")
        let gridState = harness.element(withIdentifier: "fileGridItemState_\(fileName)")
        harness.waitForExists(gridState, timeout: 4, message: "Compact grid-state probe should exist")
        harness.waitForValue(gridState, contains: "widthClass=compact", timeout: 4)

        let gridRow = harness.fileRow(named: fileName)
        let gridPrimaryAction = gridRow.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "filePrimaryAction_chooseDestination_\(fileName)__")
        ).firstMatch
        XCTAssertTrue(gridPrimaryAction.waitForExistence(timeout: 4), "Compact grid view should keep the Choose Destination action visible")
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
        let needsReviewCountProbe = harness.element(withIdentifier: "mainContent_needsReviewCount")
        harness.waitForExists(needsReviewCountProbe, timeout: 3, message: "Needs-review count probe should exist")

        let initialCountRaw = harness.badgeValue(needsReviewCountProbe)
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
        harness.waitForValue(needsReviewCountProbe, equals: "\(max(initialCount - 1, 0))", timeout: 3)
    }
    
    @MainActor
    func testReviewModeToggleShowsSkippedInAllFilesButNotNeedsReview() throws {
        harness.waitForMainContent()
        app.activate()

        let firstFileName = harness.firstVisibleFileName()
        let firstCard = harness.fileRow(named: firstFileName)
        XCTAssertTrue(firstCard.waitForExistence(timeout: 3))
        
        // Skip the first file while in Needs Review mode
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeText("s")
        
        // Wait for the first card to disappear in Needs Review mode
        harness.waitForFileRow(firstFileName, exists: false, timeout: 3)
        
        // Switch to All Files mode
        harness.tapAllFilesSegment()
        
        // In All Files mode, skipped file should be visible again (non-completed)
        harness.waitForFileRow(firstFileName, exists: true, timeout: 3)
        
        // Switch back to Needs Review and ensure card is hidden again
        harness.tapNeedsReviewSegment()
        harness.waitForFileRow(firstFileName, exists: false, timeout: 3)
    }

    @MainActor
    func testAnalyticsSelectionKeepsSidebarVisibleAndUsesFullWorkspaceLayout() throws {
        harness.waitForMainContent()
        app.activate()
        let homeInspectorWidth = harness.homeInspectorWidth()

        let analyticsButton = harness.sidebarActionLabel("Analytics")
        guard analyticsButton.exists else {
            throw XCTSkip("Analytics feature is disabled for this UI test runtime.")
        }

        analyticsButton.click()

        XCTAssertTrue(app.staticTexts["Productivity Health"].waitForExistence(timeout: 4), "Analytics workspace should be visible")

        XCTAssertTrue(harness.sidebar().waitForExistence(timeout: 4), "Sidebar container should remain visible on Analytics")
        let smartRulesButton = harness.sidebarAction("sidebarAction_smartRules")
        XCTAssertTrue(smartRulesButton.waitForExistence(timeout: 4), "Smart Rules action should remain visible on Analytics")

        let splitProbe = harness.element(withIdentifier: "dashboardSplitLayoutProbe")
        harness.waitForExists(splitProbe, timeout: 4, message: "Split layout probe should exist")
        harness.waitForValue(splitProbe, equals: "twoColumn", timeout: 4)
        harness.waitForSplitArrangement("sidebarAndWorkspace", timeout: 4)
        harness.waitForWorkspaceDestination("analyticsWorkspace", timeout: 4)

        let backButton = harness.backToDashboardButton()
        XCTAssertTrue(backButton.waitForExistence(timeout: 4), "Analytics workspace should expose a back affordance")
        assertInspectorToggleUnavailableOrDisabled()

        backButton.click()
        harness.waitForWorkspaceDestination("homeWorkspace", timeout: 4)
        harness.waitForSplitLayout("threeColumn", timeout: 4)
        harness.waitForSplitArrangement("sidebarContentAndInspector", timeout: 4)
        XCTAssertEqual(harness.homeInspectorWidth(), homeInspectorWidth, "Returning from Analytics should restore the prior Home inspector width")
    }

    @MainActor
    func testInspectorHiddenStateUsesTwoColumnWithoutCollapsingSidebar() throws {
        launchApp(windowSize: "1600x980")
        harness.waitForMainContent()
        app.activate()

        let splitProbe = harness.element(withIdentifier: "dashboardSplitLayoutProbe")
        harness.waitForExists(splitProbe, timeout: 4, message: "Split layout probe should exist")
        harness.waitForValue(splitProbe, equals: "threeColumn", timeout: 4)
        harness.waitForSplitArrangement("sidebarContentAndInspector", timeout: 4)
        harness.waitForWorkspaceDestination("homeWorkspace", timeout: 4)
        harness.waitForValue(harness.dashboardInspectorVisibilityProbe(), equals: "visible", timeout: 4)
        harness.waitForValue(harness.toolbarInspectorVisibilityProbe(), equals: "visible", timeout: 4)

        let inspectorToggle = harness.element(withIdentifier: "toolbarInspectorToggle")
        XCTAssertTrue(inspectorToggle.waitForExistence(timeout: 4), "Inspector toggle should exist")
        XCTAssertTrue(inspectorToggle.isEnabled, "Inspector toggle should be enabled on non-Analytics views")

        inspectorToggle.click()
        harness.waitForValue(harness.toolbarInspectorVisibilityProbe(), equals: "hidden", timeout: 4)
        harness.waitForValue(harness.dashboardInspectorVisibilityProbe(), equals: "hidden", timeout: 4)
        harness.waitForValue(splitProbe, equals: "twoColumn", timeout: 4)
        harness.waitForSplitArrangement("sidebarAndContent", timeout: 4)
        harness.waitForWorkspaceDestination("homeWorkspace", timeout: 4)

        XCTAssertTrue(harness.sidebar().waitForExistence(timeout: 4), "Sidebar container should remain visible when inspector is hidden")
        let smartRulesButton = harness.sidebarAction("sidebarAction_smartRules")
        XCTAssertTrue(smartRulesButton.waitForExistence(timeout: 4), "Sidebar actions should remain visible when inspector is hidden")
    }

    @MainActor
    func testInspectorTogglePreservesSidebarAndSplitProbeDuringVisibilityChanges() throws {
        launchApp(windowSize: "1600x980")
        harness.waitForMainContent()

        let splitProbe = harness.element(withIdentifier: "dashboardSplitLayoutProbe")
        harness.waitForValue(splitProbe, equals: "threeColumn", timeout: 4)
        harness.waitForSplitArrangement("sidebarContentAndInspector", timeout: 4)
        harness.waitForWorkspaceDestination("homeWorkspace", timeout: 4)
        harness.waitForValue(harness.dashboardInspectorVisibilityProbe(), equals: "visible", timeout: 4)
        harness.waitForValue(harness.toolbarInspectorVisibilityProbe(), equals: "visible", timeout: 4)

        let inspectorToggle = harness.element(withIdentifier: "toolbarInspectorToggle")
        inspectorToggle.click()
        harness.waitForValue(harness.toolbarInspectorVisibilityProbe(), equals: "hidden", timeout: 4)
        harness.waitForValue(harness.dashboardInspectorVisibilityProbe(), equals: "hidden", timeout: 4)
        harness.waitForValue(splitProbe, equals: "twoColumn", timeout: 4)
        harness.waitForSplitArrangement("sidebarAndContent", timeout: 4)
        harness.waitForWorkspaceDestination("homeWorkspace", timeout: 4)
        XCTAssertTrue(harness.sidebar().waitForExistence(timeout: 4))

        inspectorToggle.click()
        harness.waitForValue(harness.toolbarInspectorVisibilityProbe(), equals: "visible", timeout: 4)
        harness.waitForValue(harness.dashboardInspectorVisibilityProbe(), equals: "visible", timeout: 4)
        harness.waitForValue(splitProbe, equals: "threeColumn", timeout: 4)
        harness.waitForSplitArrangement("sidebarContentAndInspector", timeout: 4)
        harness.waitForWorkspaceDestination("homeWorkspace", timeout: 4)
        XCTAssertTrue(harness.sidebar().waitForExistence(timeout: 4))
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

        harness.waitForExists(reviewModeProbe, timeout: 3, message: "Review mode probe should exist")
        harness.waitForExists(needsReviewCountProbe, timeout: 3, message: "Needs-review count probe should exist")
        harness.waitForExists(allFilesCountProbe, timeout: 3, message: "All-files count probe should exist")
        harness.waitForExists(selectedCountProbe, timeout: 3, message: "Selected-count probe should exist")
        harness.waitForExists(focusedFilePathProbe, timeout: 3, message: "Focused-file probe should exist")

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
        let sectionCountsProbe = harness.element(withIdentifier: "mainContent_reviewSectionCounts")

        XCTAssertTrue(setAsideButton.waitForExistence(timeout: 3), "Needs-review bar should expose Set Aside")
        XCTAssertFalse(legacyButton.exists, "Legacy Done for now copy should be removed")
        harness.waitForExists(reviewStatusProbe, timeout: 3, message: "Review floating bar status probe should exist")
        harness.waitForExists(sectionCountsProbe, timeout: 3, message: "Review section counts probe should exist")

        let sectionCountsValue = (sectionCountsProbe.value as? String) ?? sectionCountsProbe.label
        let readyCount = reviewSectionCount(named: "ready", from: sectionCountsValue)
        let reviewCount = reviewSectionCount(named: "review", from: sectionCountsValue)
        let destinationCount = reviewSectionCount(named: "destination", from: sectionCountsValue)
        let reviewStatusValue = (reviewStatusProbe.value as? String) ?? reviewStatusProbe.label

        XCTAssertNotEqual(reviewStatusValue, "No files ready to organize")
        if !reviewStatusValue.isEmpty {
            if readyCount > 0 {
                XCTAssertTrue(reviewStatusValue.contains("ready to organize"), "Review status should describe the ready subset when files are ready")
            } else if destinationCount > 0 {
                XCTAssertTrue(reviewStatusValue.contains("destination"), "Review status should describe missing destinations when the pass is blocked there")
            } else if reviewCount > 0 {
                XCTAssertTrue(reviewStatusValue.contains("review"), "Review status should describe pending review when nothing is ready")
            }
        }
    }

    private func reviewSectionCount(named key: String, from countsValue: String) -> Int {
        let marker = "\(key)="
        guard let range = countsValue.range(of: marker) else { return 0 }
        let suffix = countsValue[range.upperBound...]
        let digits = suffix.prefix { $0.isNumber }
        return Int(digits) ?? 0
    }

    @MainActor
    func testNeedsReviewCurrentTaskCardUsesPassScopedProgressAndShortSectionCopy() throws {
        harness.waitForMainContent()
        app.activate()

        harness.tapNeedsReviewSegment()

        let hero = harness.element(withIdentifier: "defaultPanelHeroSection")
        harness.waitForExists(hero, timeout: 3, message: "Current-task hero should exist")

        let heroCount = harness.element(withIdentifier: "defaultPanelHeroCount")
        harness.waitForExists(heroCount, timeout: 3, message: "Current-task hero should expose the pass count")
        harness.waitForValue(heroCount, equals: "8", timeout: 3)

        let heroSummary = harness.element(withIdentifier: "defaultPanelHeroSummary")
        harness.waitForExists(heroSummary, timeout: 3, message: "Current-task hero should expose the pass-scoped summary")
        harness.waitForValue(heroSummary, contains: "8 files in this pass.", timeout: 3)
        harness.waitForValue(heroSummary, contains: "wait outside this pass.", timeout: 3)

        let heroSummaryValue = harness.badgeValue(heroSummary)
        XCTAssertTrue(heroSummaryValue.hasPrefix("8 files in this pass."), "Hero summary should lead with the active pass")
        XCTAssertFalse(heroSummaryValue.contains("Start with"), "Hero summary should use the v4 pass-first copy posture")

        XCTAssertTrue(
            harness.element(withIdentifier: "defaultPanelHeroCategoryBand").waitForExistence(timeout: 3),
            "Current-task hero should expose the compact category band"
        )
        let heroCategoryBand = harness.element(withIdentifier: "defaultPanelHeroCategoryBand")
        let heroCategoryBandHeight = heroCategoryBand.frame.size.height
        XCTAssertGreaterThan(heroCategoryBandHeight, 20, "Current-task hero category band should remain visible after the compressed spacing pass")
        XCTAssertLessThan(heroCategoryBandHeight, 60, "Current-task hero category band should stay tighter than the earlier tall shelf")
        XCTAssertFalse(
            harness.element(withIdentifier: "defaultPanelHeroRing").exists,
            "Current-task hero should not render a ring-based progress treatment"
        )

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
    func testNeedsReviewAutomationCardCollapsesZeroValueMetrics() throws {
        harness.waitForMainContent()
        app.activate()

        harness.tapNeedsReviewSegment()

        let automationCard = harness.element(withIdentifier: "defaultPanelAutomationStatusCard")
        harness.waitForExists(automationCard, timeout: 3, message: "Automation status card should exist")
        harness.waitForValue(automationCard, contains: "title=attached", timeout: 3)
        let automationSummary = harness.element(withIdentifier: "defaultPanelAutomationSummaryProbe")
        harness.waitForExists(
            automationSummary,
            timeout: 3,
            message: "Automation card should expose the combined state summary"
        )
        harness.waitForValue(automationSummary, contains: "surface=single", timeout: 3)
        harness.waitForValue(automationSummary, contains: "Watching Desktop and Downloads", timeout: 3)
        harness.waitForValue(automationSummary, contains: "waiting for review", timeout: 3)

        let summaryValue = harness.badgeValue(automationSummary)
        XCTAssertTrue(
            summaryValue.contains("secondary=none"),
            "Automation card should encode the flattened no-secondary-state contract when only review backlog is present"
        )
        XCTAssertFalse(
            summaryValue.contains("autopilot"),
            "Automation card should collapse zero-value autopilot metrics"
        )
        XCTAssertFalse(
            summaryValue.contains("blocked"),
            "Automation card should collapse zero-value blocked metrics"
        )

        let automationWidthProbe = harness.element(withIdentifier: "defaultPanelAutomationWidthProbe")
        harness.waitForExists(
            automationWidthProbe,
            timeout: 3,
            message: "Automation section should expose a width probe"
        )
        harness.waitForValue(automationWidthProbe, contains: "delta=", timeout: 3)

        let probeValue = harness.badgeValue(automationWidthProbe)
        let widthDelta = Double(probeValue.replacingOccurrences(of: "delta=", with: "")) ?? .greatestFiniteMagnitude
        XCTAssertLessThan(
            widthDelta,
            4,
            "Automation card should span the section width instead of sitting inset inside an outer shell"
        )
    }

    @MainActor
    func testNeedsReviewFeaturedNextMoveUsesEditorialBodyAndFooterProbe() throws {
        harness.waitForMainContent()
        app.activate()

        harness.tapNeedsReviewSegment()

        let suggestionsProbe = harness.element(withIdentifier: "defaultPanelSuggestionsSectionProbe")
        harness.waitForExists(
            suggestionsProbe,
            timeout: 8,
            message: "Next Moves should expose a lightweight outer-section probe"
        )
        harness.waitForValue(suggestionsProbe, contains: "outer=none", timeout: 8)
        harness.waitForValue(suggestionsProbe, contains: "featured=primary", timeout: 8)
        harness.waitForValue(suggestionsProbe, contains: "count=1", timeout: 8)
        harness.waitForValue(suggestionsProbe, contains: "delta=", timeout: 8)

        let suggestionsProbeValue = harness.badgeValue(suggestionsProbe)
        let suggestionsWidthDeltaString = suggestionsProbeValue
            .split(separator: "|")
            .first(where: { $0.hasPrefix("delta=") })?
            .replacingOccurrences(of: "delta=", with: "") ?? ""
        let suggestionsWidthDelta = Double(suggestionsWidthDeltaString) ?? .greatestFiniteMagnitude
        XCTAssertLessThan(
            suggestionsWidthDelta,
            4,
            "Featured next move should span the section width once the outer card is removed"
        )

        let featuredProbe = harness.element(withIdentifier: "defaultPanelFeaturedNextMoveProbe")
        harness.waitForExists(
            featuredProbe,
            timeout: 8,
            message: "Featured next move should expose an editorial-structure probe"
        )
        harness.waitForValue(featuredProbe, contains: "style=featured", timeout: 8)
        harness.waitForValue(featuredProbe, contains: "summary=", timeout: 8)
        harness.waitForValue(featuredProbe, contains: "why=Why it matters:", timeout: 8)
        harness.waitForValue(featuredProbe, contains: "action=", timeout: 8)

        let probeValue = harness.badgeValue(featuredProbe)
        XCTAssertFalse(
            probeValue.contains("metric=none"),
            "Featured next move should surface a quiet supporting metric above the footer CTA"
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
    func testOnboardingPermissionRecoveryDoesNotReopenOnboardingAfterDismissal() throws {
        let suiteName = "\(defaultWindowPresentationSuiteName).onboardingRecovery"
        launchApp(
            windowSize: "1340x900",
            suiteName: suiteName,
            resetWindowPresentation: true,
            extraEnvironment: [
                "FORMA_UI_TEST_SHOW_ONBOARDING": "1",
                "FORMA_UI_TEST_ACCESSIBLE_FOLDERS": "desktop"
            ]
        )

        let onboarding = harness.element(withIdentifier: "onboardingFlow")
        harness.waitForExists(onboarding, timeout: 4, message: "Onboarding should appear when the UI test explicitly requests it")

        let skipButton = app.buttons["onboardingSkipButton"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 4), "Onboarding should expose the Skip affordance")
        skipButton.click()

        harness.waitForMainContent()
        let requestAccess = app.buttons["sidebarRequestAccess_downloads"]
        harness.waitForExists(
            requestAccess,
            timeout: 4,
            message: "Downloads should still require access immediately after onboarding is dismissed"
        )

        launchApp(
            windowSize: "1340x900",
            suiteName: suiteName,
            resetWindowPresentation: false,
            extraEnvironment: [
                "FORMA_UI_TEST_SHOW_ONBOARDING": "0",
                "FORMA_UI_TEST_ACCESSIBLE_FOLDERS": "desktop,downloads"
            ]
        )

        harness.waitForMainContent()
        XCTAssertFalse(
            app.otherElements["onboardingFlow"].waitForExistence(timeout: 1),
            "Recovering folder access after onboarding dismissal should not reopen onboarding on relaunch"
        )
        XCTAssertFalse(
            app.buttons["sidebarRequestAccess_downloads"].waitForExistence(timeout: 1),
            "Recovered folder access should remove the explicit Request Access affordance on relaunch"
        )
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
        name.contains("testMediumWindowLaunchDefaultsToHomeWorkspaceThreeColumnLayout") ||
        name.contains("testLargeWindowLaunchUsesPreferredInspectorWidth") ||
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
        restoredFrame: String? = nil,
        extraEnvironment: [String: String] = [:]
    ) {
        app?.terminate()
        terminateRunningAppIfNeeded()

        let launchedApp = XCUIApplication()
        launchedApp.launchArguments = ["--uitesting", "-ApplePersistenceIgnoreState", "YES"]
        launchedApp.launchEnvironment["FORMA_UI_TEST_SHOW_ONBOARDING"] = "0"
        launchedApp.launchEnvironment["FORMA_UI_TEST_ACCESSIBLE_FOLDERS"] = "desktop,downloads"
        launchedApp.launchEnvironment["FORMA_WINDOW_SIZE"] = windowSize
        if let restoredFrame {
            launchedApp.launchEnvironment["FORMA_RESTORED_WINDOW_FRAME"] = restoredFrame
        }
        for (key, value) in extraEnvironment {
            launchedApp.launchEnvironment[key] = value
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

    @MainActor
    func assertInspectorToggleUnavailableOrDisabled(timeout: TimeInterval = 1) {
        let inspectorToggle = harness.inspectorToggle()
        if inspectorToggle.waitForExistence(timeout: timeout) {
            XCTAssertFalse(inspectorToggle.isEnabled, "Inspector toggle should be unavailable outside Home workspace")
            return
        }

        XCTAssertFalse(inspectorToggle.exists, "Inspector toggle should be hidden when the workspace does not support it")
    }

    private func containsWindowFrame(_ visibleFrame: CGRect, windowFrame: CGRect, tolerance: CGFloat = 4) -> Bool {
        windowFrame.minX >= visibleFrame.minX - tolerance &&
        windowFrame.maxX <= visibleFrame.maxX + tolerance &&
        windowFrame.minY >= visibleFrame.minY - tolerance &&
        windowFrame.maxY <= visibleFrame.maxY + tolerance
    }
}
