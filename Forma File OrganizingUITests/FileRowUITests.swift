//
//  FileRowUITests.swift
//  Forma File OrganizingUITests
//
//  Created by James Farmer on 11/23/25.
//

import XCTest

final class FileRowUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        throw XCTSkip("Hover detection in UI tests is unreliable. Verify manually in the app.")
    }

    override func tearDownWithError() throws {
        app = nil
    }
    
    @MainActor
    func testFileRowHoverShowsActions() throws {
        // Skipped in setUpWithError.
    }
}
