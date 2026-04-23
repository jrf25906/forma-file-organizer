import XCTest
@testable import Forma_File_Organizing

final class SecurityConfigurationRegressionTests: XCTestCase {
    func testThumbnailServiceDoesNotWriteFilePathsToSharedTmpDebugLog() async {
        let legacyLogURL = URL(fileURLWithPath: "/tmp/thumbnail_debug.log")
        try? FileManager.default.removeItem(at: legacyLogURL)
        defer {
            try? FileManager.default.removeItem(at: legacyLogURL)
        }

        _ = await ThumbnailService.shared.thumbnail(
            for: "/tmp/forma-thumbnail-debug-log-regression-probe",
            size: CGSize(width: 16, height: 16)
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyLogURL.path))
    }

    func testUITestFolderAccessConfigurationEnablesOnlyKnownHarnessArguments() {
        XCTAssertFalse(UITestFolderAccessConfiguration.isEnabled(arguments: ["Forma"]))
        XCTAssertFalse(UITestFolderAccessConfiguration.isEnabled(arguments: ["Forma", "--not-uitesting"]))
        XCTAssertTrue(UITestFolderAccessConfiguration.isEnabled(arguments: ["Forma", "--uitesting"]))
        XCTAssertTrue(UITestFolderAccessConfiguration.isEnabled(arguments: ["Forma", "--perf-signpost-harness"]))
    }

    func testUITestFolderAccessConfigurationParsesAccessibleFolderEnvironment() {
        let key = UITestFolderAccessConfiguration.accessibleFoldersEnvironmentKey

        XCTAssertEqual(
            UITestFolderAccessConfiguration.accessibleFolderNames(environment: [:]),
            ["desktop", "downloads"]
        )
        XCTAssertEqual(
            UITestFolderAccessConfiguration.accessibleFolderNames(
                environment: [key: " Desktop, DOWNLOADS, Pictures ,, "]
            ),
            ["desktop", "downloads", "pictures"]
        )
    }
}
