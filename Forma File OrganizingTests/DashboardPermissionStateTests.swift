import XCTest
import Darwin
@testable import Forma_File_Organizing

final class DashboardPermissionStateTests: XCTestCase {
    private var originalAccessibleFoldersOverride: String?
    private var originalShowOnboardingOverride: String?

    override func setUp() {
        super.setUp()
        originalAccessibleFoldersOverride = ProcessInfo.processInfo.environment["FORMA_UI_TEST_ACCESSIBLE_FOLDERS"]
        originalShowOnboardingOverride = ProcessInfo.processInfo.environment["FORMA_UI_TEST_SHOW_ONBOARDING"]
        unsetenv("FORMA_UI_TEST_ACCESSIBLE_FOLDERS")
        unsetenv("FORMA_UI_TEST_SHOW_ONBOARDING")
    }

    override func tearDown() {
        Self.restoreEnvironmentVariable("FORMA_UI_TEST_ACCESSIBLE_FOLDERS", value: originalAccessibleFoldersOverride)
        Self.restoreEnvironmentVariable("FORMA_UI_TEST_SHOW_ONBOARDING", value: originalShowOnboardingOverride)
        super.tearDown()
    }

    @MainActor
    func testUITestDefaultPermissionsMatchDefaultAccessibleFolders() {
        let state = DashboardPermissionState()
        let defaults = UserDefaults(suiteName: "DashboardPermissionStateTests.\(UUID().uuidString)")!
        defaults.set(true, forKey: "hasCompletedOnboarding")

        state.checkPermissions(
            using: MockFileSystemService(),
            defaults: defaults,
            isUITesting: true
        )

        XCTAssertTrue(state.hasDesktopAccess)
        XCTAssertTrue(state.hasDownloadsAccess)
        XCTAssertFalse(state.hasDocumentsAccess)
        XCTAssertFalse(state.hasPicturesAccess)
        XCTAssertFalse(state.hasMusicAccess)
        XCTAssertFalse(state.showOnboarding)
    }

    @MainActor
    func testRequestAccess_ReturnsErrorWhenDownloadsVerificationFailsAfterSuccessfulRequest() async {
        let state = DashboardPermissionState()
        let fileSystemService = MockFileSystemService()
        fileSystemService.hasDownloads = false
        fileSystemService.requestDownloadsAccessResult = true
        fileSystemService.downloadsAccessStateAfterRequest = false

        let result = await state.requestAccess(for: .downloads, using: fileSystemService)

        switch result {
        case .error(let message):
            XCTAssertFalse(message.isEmpty)
        default:
            XCTFail("Expected a verification failure when Downloads access remains unavailable after the request succeeds.")
        }

        XCTAssertFalse(state.hasDownloadsAccess)
        XCTAssertFalse(state.permissionCancelledFolders.contains(.downloads))
    }

    @MainActor
    func testRequestAccess_ReturnsCancelledWhenOpenPanelIsCancelled() async {
        let state = DashboardPermissionState()
        let fileSystemService = MockFileSystemService()
        fileSystemService.requestDownloadsAccessError = FormaError.operation(.cancelled)

        let result = await state.requestAccess(for: .downloads, using: fileSystemService)

        switch result {
        case .cancelled:
            break
        default:
            XCTFail("Expected folder picker cancellation to remain a cancellation result.")
        }

        XCTAssertFalse(state.hasDownloadsAccess)
        XCTAssertTrue(state.permissionCancelledFolders.contains(.downloads))
    }

    private static func restoreEnvironmentVariable(_ key: String, value: String?) {
        if let value {
            setenv(key, value, 1)
        } else {
            unsetenv(key)
        }
    }
}
