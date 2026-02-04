//
//  Forma_File_OrganizingUITestsLaunchTests.swift
//  Forma File OrganizingUITests
//
//  Created by James Farmer on 11/17/25.
//

import XCTest

final class Forma_File_OrganizingUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        try UITestGating.requireUI()
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "-ApplePersistenceIgnoreState", "YES"]
        app.launch()

        // Wait for the UI-testing seed data to render before taking a screenshot.
        let needsReviewButton = app.buttons["reviewMode_needsReview"]
        XCTAssertTrue(needsReviewButton.waitForExistence(timeout: 8), "Main content should appear")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
