//
//  Forma_File_OrganizingUITests.swift
//  Forma File OrganizingUITests
//
//  Created by James Farmer on 11/17/25.
//

import XCTest

final class Forma_File_OrganizingUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Pass a launch argument to indicate UI test mode, which can be used
        // to seed mock data or skip onboarding
        app.launchArguments = ["--uitesting"]
        app.launch()
        
        // Wait for the app to settle
        _ = app.wait(for: .runningForeground, timeout: 5)
    }

    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Helper Methods
    
    /// Wait for the main content view to appear (i.e., onboarding is dismissed)
    private func waitForMainContent() {
        // Look for a unique element in the main content
        let reviewButton = app.buttons["reviewMode_needsReview"]
        XCTAssertTrue(reviewButton.waitForExistence(timeout: 8), "Main content should appear")
        
        // Ensure seeded UI test files are visible before proceeding
        let firstCard = reviewCard(for: "UITest_File_1_WithSuggestion.pdf")
        XCTAssertTrue(firstCard.waitForExistence(timeout: 8), "UI test files should be visible")
    }
    
    /// Convenience accessor for a specific review file card by file name
    private func reviewCard(for name: String) -> XCUIElement {
        app.otherElements["fileRow_\(name)"]
    }
    
    private func buttonValue(_ button: XCUIElement) -> String {
        button.value as? String ?? ""
    }
    
    // MARK: - Keyboard Navigation Tests
    
    @MainActor
    func testKeyboardNavigationDownAndJ() throws {
        waitForMainContent()
        
        // Ensure there are files visible
        let scrollView = app.scrollViews["fileListScrollView"]
        XCTAssertTrue(scrollView.exists, "Center panel scroll view should exist")
        
        // Focus first file by pressing Down arrow
        app.typeKey(.downArrow, modifierFlags: [])
        
        // Wait a moment for focus to update
        sleep(1)
        
        // Now press J to move to next file
        app.typeText("j")
        
        // Verify that focus moved (this is indirect; in a real test you'd check
        // for a focused state indicator, e.g. a border or accessibility trait)
        // For now, just ensure no crash occurred
        XCTAssertTrue(app.exists)
    }
    
    @MainActor
    func testKeyboardNavigationUpAndK() throws {
        waitForMainContent()
        
        let scrollView = app.scrollViews["fileListScrollView"]
        XCTAssertTrue(scrollView.exists, "Center panel scroll view should exist")
        
        // Focus first file
        app.typeKey(.downArrow, modifierFlags: [])
        sleep(1)
        
        // Move to next file
        app.typeText("j")
        sleep(1)
        
        // Move back up with K
        app.typeText("k")
        sleep(1)
        
        // Verify app is still responsive
        XCTAssertTrue(app.exists)
    }
    
    @MainActor
    func testKeyboardNavigationArrowKeys() throws {
        waitForMainContent()
        
        let scrollView = app.scrollViews["fileListScrollView"]
        XCTAssertTrue(scrollView.exists, "Center panel scroll view should exist")
        
        // Navigate with Down arrow
        app.typeKey(.downArrow, modifierFlags: [])
        sleep(1)
        
        app.typeKey(.downArrow, modifierFlags: [])
        sleep(1)
        
        // Navigate back with Up arrow
        app.typeKey(.upArrow, modifierFlags: [])
        sleep(1)
        
        XCTAssertTrue(app.exists)
    }
    
    // MARK: - Review Mode Toggle
    
    @MainActor
    func testReviewModeToggleCountsUpdateWithActions() throws {
        waitForMainContent()
        
        // Initial counts: all three files are pending and non-completed
        let needsReviewButton = app.buttons["reviewMode_needsReview"]
        let allFilesButton = app.buttons["reviewMode_allFiles"]
        XCTAssertTrue(needsReviewButton.waitForExistence(timeout: 3))
        XCTAssertTrue(allFilesButton.exists)
        
        // Verify initial count for Needs Review
        XCTAssertEqual(buttonValue(needsReviewButton), "3")
        
        // Skip the first file via keyboard (S)
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeText("s")
        
        // Needs Review should drop to 2
        let needsReviewPredicate = NSPredicate(format: "value == %@", "2")
        let needsReviewUpdated = expectation(for: needsReviewPredicate, evaluatedWith: needsReviewButton, handler: nil)
        wait(for: [needsReviewUpdated], timeout: 3)
    }
    
    @MainActor
    func testReviewModeToggleShowsSkippedInAllFilesButNotNeedsReview() throws {
        waitForMainContent()
        
        let firstCard = reviewCard(for: "UITest_File_1_WithSuggestion.pdf")
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
        let notExistsPredicate = NSPredicate(format: "exists == false")
        let firstGone = expectation(for: notExistsPredicate, evaluatedWith: firstCard, handler: nil)
        wait(for: [firstGone], timeout: 3)
        
        // Switch to All Files mode
        allFilesButton.tap()
        
        // In All Files mode, skipped file should be visible again (non-completed)
        let existsPredicate = NSPredicate(format: "exists == true")
        let firstBack = expectation(for: existsPredicate, evaluatedWith: firstCard, handler: nil)
        wait(for: [firstBack], timeout: 3)
        
        // Switch back to Needs Review and ensure card is hidden again
        needsReviewButton.tap()
        let firstHiddenAgain = expectation(for: notExistsPredicate, evaluatedWith: firstCard, handler: nil)
        wait(for: [firstHiddenAgain], timeout: 3)
    }
    
    // MARK: - File Action Tests
    
    @MainActor
    func testKeyboardShortcutSpace_QuickLook() throws {
        waitForMainContent()
        
        // Focus a file
        app.typeKey(.downArrow, modifierFlags: [])
        sleep(1)
        
        // Press Space to trigger Quick Look
        app.typeText(" ")
        sleep(1)
        
        // Quick Look should open; verify the app is still responsive
        // (Quick Look is a system panel and may not be easily queryable)
        XCTAssertTrue(app.exists)
    }
    
    @MainActor
    func testKeyboardShortcutS_Skip() throws {
        waitForMainContent()
        
        let firstCard = reviewCard(for: "UITest_File_1_WithSuggestion.pdf")
        XCTAssertTrue(firstCard.waitForExistence(timeout: 3))
        
        // Focus first file
        app.typeKey(.downArrow, modifierFlags: [])
        
        // Press S to skip the file
        app.typeText("s")
        
        // Skipped file should disappear from Needs Review list
        let notExistsPredicate = NSPredicate(format: "exists == false")
        let expectation = expectation(for: notExistsPredicate, evaluatedWith: firstCard, handler: nil)
        wait(for: [expectation], timeout: 3)
    }
    
    @MainActor
    func testKeyboardShortcutE_EditDestination() throws {
        waitForMainContent()
        
        let firstCard = reviewCard(for: "UITest_File_1_WithSuggestion.pdf")
        XCTAssertTrue(firstCard.waitForExistence(timeout: 3))
        
        // Focus the first file
        app.typeKey(.downArrow, modifierFlags: [])
        sleep(1)
        
        // Press E to open Edit Destination sheet
        app.typeText("e")
        
        let sheet = app.otherElements["editDestinationSheet"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 3), "Edit destination sheet should appear")
        
        // Dismiss the sheet by pressing Escape
        app.typeKey(.escape, modifierFlags: [])
        sleep(1)
    }
    
    @MainActor
    func testKeyboardShortcutR_CreateRule() throws {
        waitForMainContent()
        
        let firstCard = reviewCard(for: "UITest_File_1_WithSuggestion.pdf")
        XCTAssertTrue(firstCard.waitForExistence(timeout: 3))
        
        // Focus the first file
        app.typeKey(.downArrow, modifierFlags: [])
        sleep(1)
        
        // Press R to open rule editor
        app.typeText("r")
        
        let editor = app.otherElements["ruleEditorView"]
        XCTAssertTrue(editor.waitForExistence(timeout: 3), "Rule editor should appear")
        
        // Dismiss rule editor
        app.typeKey(.escape, modifierFlags: [])
        sleep(1)
    }
    
    @MainActor
    func testKeyboardShortcutEnter_Organize() throws {
        waitForMainContent()
        
        let firstCard = reviewCard(for: "UITest_File_1_WithSuggestion.pdf")
        XCTAssertTrue(firstCard.waitForExistence(timeout: 3))
        
        // Focus the first file (has a suggested destination)
        app.typeKey(.downArrow, modifierFlags: [])
        
        // Press Enter to organize the file
        app.typeKey(.enter, modifierFlags: [])
        
        // Organized file should disappear from visible list (marked completed)
        let notExistsPredicate = NSPredicate(format: "exists == false")
        let expectation = expectation(for: notExistsPredicate, evaluatedWith: firstCard, handler: nil)
        wait(for: [expectation], timeout: 3)
    }
    
    @MainActor
    func testKeyboardShortcutCmdEnter_OrganizeAndMoveNext() throws {
        waitForMainContent()
        
        let firstCard = reviewCard(for: "UITest_File_1_WithSuggestion.pdf")
        XCTAssertTrue(firstCard.waitForExistence(timeout: 3))
        
        // Focus first file
        app.typeKey(.downArrow, modifierFlags: [])
        
        // Press Cmd+Enter to organize and move focus to next
        app.typeKey(.enter, modifierFlags: .command)
        
        // First card should be gone, second still present
        let notExistsPredicate = NSPredicate(format: "exists == false")
        let expectation = expectation(for: notExistsPredicate, evaluatedWith: firstCard, handler: nil)
        wait(for: [expectation], timeout: 3)
        
        let secondCard = reviewCard(for: "UITest_File_2_NoSuggestion.txt")
        XCTAssertTrue(secondCard.exists)
    }
    
    // MARK: - Integration Test
    
    @MainActor
    func testKeyboardWorkflow_NavigateAndOrganize() throws {
        waitForMainContent()
        
        let firstCard = reviewCard(for: "UITest_File_1_WithSuggestion.pdf")
        let secondCard = reviewCard(for: "UITest_File_2_NoSuggestion.txt")
        let thirdCard = reviewCard(for: "UITest_File_3_WithSuggestion.mov")
        XCTAssertTrue(firstCard.waitForExistence(timeout: 3))
        XCTAssertTrue(secondCard.exists)
        XCTAssertTrue(thirdCard.exists)
        
        // Focus first file
        app.typeKey(.downArrow, modifierFlags: [])
        
        // Skip the first file
        app.typeText("s")
        
        let notExistsPredicate = NSPredicate(format: "exists == false")
        let firstGone = expectation(for: notExistsPredicate, evaluatedWith: firstCard, handler: nil)
        wait(for: [firstGone], timeout: 3)
        
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
