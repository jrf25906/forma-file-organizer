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

    override func setUpWithError() throws {
        try UITestGating.requireUI()
        continueAfterFailure = false
        app = XCUIApplication()
        harness = UITestHarness(app: app)
        // Pass a launch argument to indicate UI test mode, which can be used
        // to seed mock data or skip onboarding
        app.launchArguments = ["--uitesting", "-ApplePersistenceIgnoreState", "YES"]

        let isLaunchPerformanceTest = name.contains("testLaunchPerformance")
        if !isLaunchPerformanceTest {
            terminateRunningAppIfNeeded()
            app.launch()
        }

        // Wait for the app to settle
        if !isLaunchPerformanceTest {
            _ = app.wait(for: .runningForeground, timeout: 5)
        }
    }

    override func tearDownWithError() throws {
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
        
        // Initial counts: all three files are pending and non-completed
        let needsReviewButton = app.buttons["reviewMode_needsReview"]
        let allFilesButton = app.buttons["reviewMode_allFiles"]
        XCTAssertTrue(needsReviewButton.waitForExistence(timeout: 3))
        XCTAssertTrue(allFilesButton.exists)
        
        // Verify initial count for Needs Review
        XCTAssertEqual(harness.badgeValue(needsReviewButton), "3")
        
        // Skip the first file via keyboard (S)
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeText("s")
        
        // Needs Review should drop to 2
        harness.waitForValue(needsReviewButton, equals: "2", timeout: 3)
    }
    
    @MainActor
    func testReviewModeToggleShowsSkippedInAllFilesButNotNeedsReview() throws {
        harness.waitForMainContent()
        app.activate()
        
        let firstCard = harness.fileRow(named: "UITest_File_1_WithSuggestion.pdf")
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
        harness.waitForFileRow("UITest_File_1_WithSuggestion.pdf", exists: false, timeout: 3)
        
        // Switch to All Files mode
        allFilesButton.tap()
        
        // In All Files mode, skipped file should be visible again (non-completed)
        harness.waitForFileRow("UITest_File_1_WithSuggestion.pdf", exists: true, timeout: 3)
        
        // Switch back to Needs Review and ensure card is hidden again
        needsReviewButton.tap()
        harness.waitForFileRow("UITest_File_1_WithSuggestion.pdf", exists: false, timeout: 3)
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
        
        let firstCard = harness.fileRow(named: "UITest_File_1_WithSuggestion.pdf")
        XCTAssertTrue(firstCard.waitForExistence(timeout: 3))
        
        // Focus first file
        app.typeKey(.downArrow, modifierFlags: [])
        
        // Press S to skip the file
        app.typeText("s")
        
        // Skipped file should disappear from Needs Review list
        harness.waitForFileRow("UITest_File_1_WithSuggestion.pdf", exists: false, timeout: 3)
    }
    
    @MainActor
    func testKeyboardShortcutE_EditDestination() throws {
        harness.waitForMainContent()
        app.activate()
        
        let firstCard = harness.fileRow(named: "UITest_File_1_WithSuggestion.pdf")
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
        
        let firstCard = harness.fileRow(named: "UITest_File_1_WithSuggestion.pdf")
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
        
        let firstCard = harness.fileRow(named: "UITest_File_1_WithSuggestion.pdf")
        XCTAssertTrue(firstCard.waitForExistence(timeout: 3))
        
        // Focus the first file (has a suggested destination)
        app.typeKey(.downArrow, modifierFlags: [])
        
        // Press Enter to organize the file
        app.typeKey(.enter, modifierFlags: [])
        
        // Organized file should disappear from visible list (marked completed)
        harness.waitForFileRow("UITest_File_1_WithSuggestion.pdf", exists: false, timeout: 3)
    }
    
    @MainActor
    func testKeyboardShortcutCmdEnter_OrganizeAndMoveNext() throws {
        harness.waitForMainContent()
        app.activate()
        
        let firstCard = harness.fileRow(named: "UITest_File_1_WithSuggestion.pdf")
        XCTAssertTrue(firstCard.waitForExistence(timeout: 3))
        
        // Focus first file
        app.typeKey(.downArrow, modifierFlags: [])
        
        // Press Cmd+Enter to organize and move focus to next
        app.typeKey(.enter, modifierFlags: .command)
        
        // First card should be gone, second still present
        harness.waitForFileRow("UITest_File_1_WithSuggestion.pdf", exists: false, timeout: 3)
        
        let secondCard = harness.fileRow(named: "UITest_File_2_NoSuggestion.txt")
        XCTAssertTrue(secondCard.exists)
    }
    
    // MARK: - Integration Test
    
    @MainActor
    func testKeyboardWorkflow_NavigateAndOrganize() throws {
        harness.waitForMainContent()
        app.activate()
        
        let firstCard = harness.fileRow(named: "UITest_File_1_WithSuggestion.pdf")
        let secondCard = harness.fileRow(named: "UITest_File_2_NoSuggestion.txt")
        let thirdCard = harness.fileRow(named: "UITest_File_3_WithSuggestion.mov")
        XCTAssertTrue(firstCard.waitForExistence(timeout: 3))
        XCTAssertTrue(secondCard.exists)
        XCTAssertTrue(thirdCard.exists)
        
        // Focus first file
        app.typeKey(.downArrow, modifierFlags: [])
        
        // Skip the first file
        app.typeText("s")
        
        harness.waitForFileRow("UITest_File_1_WithSuggestion.pdf", exists: false, timeout: 3)
        
        // Move to next file (now the former second)
        app.typeText("j")
        
        // Attempt to organize the second file (has no suggestion, so no-op)
        app.typeKey(.enter, modifierFlags: [])
        XCTAssertTrue(secondCard.exists)
        
        // Move to third file and open Quick Look
        app.typeText("j")
        app.typeText(" ")
        
        // Ensure third card still exists (Quick Look is external to the app)
        XCTAssertTrue(thirdCard.exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
