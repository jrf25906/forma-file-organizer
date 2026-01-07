import XCTest
@testable import Forma_File_Organizing

/// Tests for AutomationPolicy resolution logic.
///
/// Tests cover:
/// - Feature flag hierarchy (master → backgroundMonitoring → autoOrganize)
/// - Mode downgrade when flags are disabled
/// - Interval clamping to config bounds
/// - Notification settings inheritance
/// - User settings preservation
final class AutomationPolicyTests: XCTestCase {

    private var featureFlags: FeatureFlagService!

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()
        featureFlags = FeatureFlagService.shared
        // Reset to known state before each test
        featureFlags.resetToDefaults()
    }

    override func tearDown() {
        // Clean up test state
        featureFlags.resetToDefaults()
        clearAutomationUserDefaults()
        super.tearDown()
    }

    // MARK: - Master AI Toggle Tests

    /// Test: When master AI is off, effective mode is always .off
    func testMasterAIDisabled_EffectiveModeIsOff() {
        // Given
        featureFlags.masterAIEnabled = false
        featureFlags.setEnabled(.backgroundMonitoring, true)
        featureFlags.setEnabled(.autoOrganize, true)

        let userSettings = AutomationUserSettings(
            mode: .scanAndOrganize,
            scanIntervalMinutes: 30,
            scanOnLaunch: true,
            notificationsEnabled: true
        )

        // When
        let policy = AutomationPolicy.resolve(flags: featureFlags, userSettings: userSettings)

        // Then
        XCTAssertEqual(policy.userMode, .scanAndOrganize, "User mode should be preserved")
        XCTAssertEqual(policy.effectiveMode, .off, "Effective mode should be .off when master AI is disabled")
        XCTAssertFalse(policy.canScan, "canScan should be false")
        XCTAssertFalse(policy.canAutoOrganize, "canAutoOrganize should be false")
    }

    /// Test: When master AI is on, effective mode follows user settings
    func testMasterAIEnabled_EffectiveModeFollowsUserSettings() {
        // Given
        featureFlags.masterAIEnabled = true
        featureFlags.setEnabled(.backgroundMonitoring, true)
        featureFlags.setEnabled(.autoOrganize, true)

        let userSettings = AutomationUserSettings(
            mode: .scanAndOrganize,
            scanIntervalMinutes: 30,
            scanOnLaunch: true,
            notificationsEnabled: true
        )

        // When
        let policy = AutomationPolicy.resolve(flags: featureFlags, userSettings: userSettings)

        // Then
        XCTAssertEqual(policy.effectiveMode, .scanAndOrganize)
        XCTAssertTrue(policy.canScan)
        XCTAssertTrue(policy.canAutoOrganize)
    }

    // MARK: - Background Monitoring Flag Tests

    /// Test: When backgroundMonitoring flag is off, effective mode is .off
    func testBackgroundMonitoringDisabled_EffectiveModeIsOff() {
        // Given
        featureFlags.masterAIEnabled = true
        featureFlags.setEnabled(.backgroundMonitoring, false)
        featureFlags.setEnabled(.autoOrganize, true)

        let userSettings = AutomationUserSettings(
            mode: .scanOnly,
            scanIntervalMinutes: 30,
            scanOnLaunch: true,
            notificationsEnabled: true
        )

        // When
        let policy = AutomationPolicy.resolve(flags: featureFlags, userSettings: userSettings)

        // Then
        XCTAssertEqual(policy.effectiveMode, .off, "Effective mode should be .off when backgroundMonitoring is disabled")
        XCTAssertFalse(policy.canScan)
    }

    // MARK: - Auto-Organize Flag Tests

    /// Test: When autoOrganize flag is off, scanAndOrganize downgrades to scanOnly
    func testAutoOrganizeDisabled_DowngradesToScanOnly() {
        // Given
        featureFlags.masterAIEnabled = true
        featureFlags.setEnabled(.backgroundMonitoring, true)
        featureFlags.setEnabled(.autoOrganize, false)

        let userSettings = AutomationUserSettings(
            mode: .scanAndOrganize,
            scanIntervalMinutes: 30,
            scanOnLaunch: true,
            notificationsEnabled: true
        )

        // When
        let policy = AutomationPolicy.resolve(flags: featureFlags, userSettings: userSettings)

        // Then
        XCTAssertEqual(policy.userMode, .scanAndOrganize, "User mode should be preserved")
        XCTAssertEqual(policy.effectiveMode, .scanOnly, "Should downgrade to scanOnly when autoOrganize flag is off")
        XCTAssertTrue(policy.canScan)
        XCTAssertFalse(policy.canAutoOrganize)
    }

    /// Test: ScanOnly mode is not affected by autoOrganize flag
    func testScanOnlyMode_NotAffectedByAutoOrganizeFlag() {
        // Given
        featureFlags.masterAIEnabled = true
        featureFlags.setEnabled(.backgroundMonitoring, true)
        featureFlags.setEnabled(.autoOrganize, false)

        let userSettings = AutomationUserSettings(
            mode: .scanOnly,
            scanIntervalMinutes: 30,
            scanOnLaunch: true,
            notificationsEnabled: true
        )

        // When
        let policy = AutomationPolicy.resolve(flags: featureFlags, userSettings: userSettings)

        // Then
        XCTAssertEqual(policy.effectiveMode, .scanOnly)
        XCTAssertTrue(policy.canScan)
        XCTAssertFalse(policy.canAutoOrganize)
    }

    // MARK: - Interval Clamping Tests

    /// Test: Interval below minimum is clamped to minimum
    func testIntervalBelowMinimum_ClampedToMinimum() {
        // Given
        featureFlags.masterAIEnabled = true
        featureFlags.setEnabled(.backgroundMonitoring, true)

        let userSettings = AutomationUserSettings(
            mode: .scanOnly,
            scanIntervalMinutes: 1, // Below minimum of 5
            scanOnLaunch: true,
            notificationsEnabled: true
        )

        // When
        let policy = AutomationPolicy.resolve(flags: featureFlags, userSettings: userSettings)

        // Then
        XCTAssertEqual(
            policy.scanIntervalMinutes,
            FormaConfig.Automation.minScanIntervalMinutes,
            "Interval should be clamped to minimum"
        )
    }

    /// Test: Interval above maximum is clamped to maximum
    func testIntervalAboveMaximum_ClampedToMaximum() {
        // Given
        featureFlags.masterAIEnabled = true
        featureFlags.setEnabled(.backgroundMonitoring, true)

        let userSettings = AutomationUserSettings(
            mode: .scanOnly,
            scanIntervalMinutes: 9999, // Above maximum
            scanOnLaunch: true,
            notificationsEnabled: true
        )

        // When
        let policy = AutomationPolicy.resolve(flags: featureFlags, userSettings: userSettings)

        // Then
        XCTAssertEqual(
            policy.scanIntervalMinutes,
            FormaConfig.Automation.maxScanIntervalMinutes,
            "Interval should be clamped to maximum"
        )
    }

    /// Test: Valid interval within bounds is preserved
    func testValidInterval_Preserved() {
        // Given
        featureFlags.masterAIEnabled = true
        featureFlags.setEnabled(.backgroundMonitoring, true)

        let validInterval = 60
        let userSettings = AutomationUserSettings(
            mode: .scanOnly,
            scanIntervalMinutes: validInterval,
            scanOnLaunch: true,
            notificationsEnabled: true
        )

        // When
        let policy = AutomationPolicy.resolve(flags: featureFlags, userSettings: userSettings)

        // Then
        XCTAssertEqual(policy.scanIntervalMinutes, validInterval)
    }

    /// Test: Interval is 0 when effective mode is .off
    func testIntervalIsZero_WhenEffectiveModeIsOff() {
        // Given
        featureFlags.masterAIEnabled = false

        let userSettings = AutomationUserSettings(
            mode: .scanOnly,
            scanIntervalMinutes: 30,
            scanOnLaunch: true,
            notificationsEnabled: true
        )

        // When
        let policy = AutomationPolicy.resolve(flags: featureFlags, userSettings: userSettings)

        // Then
        XCTAssertEqual(policy.scanIntervalMinutes, 0, "Interval should be 0 when mode is off")
        XCTAssertFalse(policy.hasScheduledScans)
    }

    // MARK: - Notification Settings Tests

    /// Test: Notifications disabled when automationReminders flag is off
    func testNotificationsDisabled_WhenRemindersFlagOff() {
        // Given
        featureFlags.masterAIEnabled = true
        featureFlags.setEnabled(.backgroundMonitoring, true)
        featureFlags.setEnabled(.automationReminders, false)

        let userSettings = AutomationUserSettings(
            mode: .scanOnly,
            scanIntervalMinutes: 30,
            scanOnLaunch: true,
            notificationsEnabled: true // User wants notifications
        )

        // When
        let policy = AutomationPolicy.resolve(flags: featureFlags, userSettings: userSettings)

        // Then
        XCTAssertFalse(policy.notificationsEnabled, "Notifications should be disabled when flag is off")
    }

    /// Test: Notifications disabled when user disables them
    func testNotificationsDisabled_WhenUserDisables() {
        // Given
        featureFlags.masterAIEnabled = true
        featureFlags.setEnabled(.backgroundMonitoring, true)
        featureFlags.setEnabled(.automationReminders, true)

        let userSettings = AutomationUserSettings(
            mode: .scanOnly,
            scanIntervalMinutes: 30,
            scanOnLaunch: true,
            notificationsEnabled: false // User disabled notifications
        )

        // When
        let policy = AutomationPolicy.resolve(flags: featureFlags, userSettings: userSettings)

        // Then
        XCTAssertFalse(policy.notificationsEnabled, "Notifications should be disabled when user disables them")
    }

    /// Test: Notifications enabled when both flag and user setting are on
    func testNotificationsEnabled_WhenBothOn() {
        // Given
        featureFlags.masterAIEnabled = true
        featureFlags.setEnabled(.backgroundMonitoring, true)
        featureFlags.setEnabled(.automationReminders, true)

        let userSettings = AutomationUserSettings(
            mode: .scanOnly,
            scanIntervalMinutes: 30,
            scanOnLaunch: true,
            notificationsEnabled: true
        )

        // When
        let policy = AutomationPolicy.resolve(flags: featureFlags, userSettings: userSettings)

        // Then
        XCTAssertTrue(policy.notificationsEnabled)
    }

    // MARK: - Scan On Launch Tests

    /// Test: Scan on launch disabled when effective mode is .off
    func testScanOnLaunchDisabled_WhenModeIsOff() {
        // Given
        featureFlags.masterAIEnabled = false

        let userSettings = AutomationUserSettings(
            mode: .scanOnly,
            scanIntervalMinutes: 30,
            scanOnLaunch: true, // User wants scan on launch
            notificationsEnabled: true
        )

        // When
        let policy = AutomationPolicy.resolve(flags: featureFlags, userSettings: userSettings)

        // Then
        XCTAssertFalse(policy.scanOnLaunch, "Scan on launch should be disabled when mode is off")
    }

    /// Test: Scan on launch follows user setting when mode is active
    func testScanOnLaunchFollowsUserSetting_WhenModeIsActive() {
        // Given
        featureFlags.masterAIEnabled = true
        featureFlags.setEnabled(.backgroundMonitoring, true)

        let userSettingsWithScan = AutomationUserSettings(
            mode: .scanOnly,
            scanIntervalMinutes: 30,
            scanOnLaunch: true,
            notificationsEnabled: true
        )

        let userSettingsWithoutScan = AutomationUserSettings(
            mode: .scanOnly,
            scanIntervalMinutes: 30,
            scanOnLaunch: false,
            notificationsEnabled: true
        )

        // When
        let policyWithScan = AutomationPolicy.resolve(flags: featureFlags, userSettings: userSettingsWithScan)
        let policyWithoutScan = AutomationPolicy.resolve(flags: featureFlags, userSettings: userSettingsWithoutScan)

        // Then
        XCTAssertTrue(policyWithScan.scanOnLaunch)
        XCTAssertFalse(policyWithoutScan.scanOnLaunch)
    }

    // MARK: - Config Constants Tests

    /// Test: Policy includes config constants
    func testPolicyIncludesConfigConstants() {
        // Given
        featureFlags.masterAIEnabled = true
        featureFlags.setEnabled(.backgroundMonitoring, true)

        let userSettings = AutomationUserSettings(
            mode: .scanOnly,
            scanIntervalMinutes: 30,
            scanOnLaunch: true,
            notificationsEnabled: true
        )

        // When
        let policy = AutomationPolicy.resolve(flags: featureFlags, userSettings: userSettings)

        // Then
        XCTAssertEqual(policy.backlogThreshold, FormaConfig.Automation.backlogThreshold)
        XCTAssertEqual(policy.ageThresholdDays, FormaConfig.Automation.ageThresholdDays)
        XCTAssertEqual(policy.mlConfidenceThreshold, FormaConfig.Automation.mlAutoOrganizeConfidenceMinimum)
        XCTAssertEqual(policy.maxConsecutiveFailures, FormaConfig.Automation.maxConsecutiveFailures)
        XCTAssertEqual(policy.backlogReminderCooldownHours, FormaConfig.Automation.backlogReminderCooldownHours)
        XCTAssertEqual(policy.errorNotificationCooldownMinutes, FormaConfig.Automation.errorNotificationCooldownMinutes)
    }

    // MARK: - Computed Properties Tests

    /// Test: hasScheduledScans property
    func testHasScheduledScans() {
        // Given
        featureFlags.masterAIEnabled = true
        featureFlags.setEnabled(.backgroundMonitoring, true)

        let userSettingsWithInterval = AutomationUserSettings(
            mode: .scanOnly,
            scanIntervalMinutes: 30,
            scanOnLaunch: true,
            notificationsEnabled: true
        )

        // When
        let policy = AutomationPolicy.resolve(flags: featureFlags, userSettings: userSettingsWithInterval)

        // Then
        XCTAssertTrue(policy.hasScheduledScans)
    }

    // MARK: - Mode Display Properties Tests

    /// Test: AutomationMode display properties
    func testAutomationModeDisplayProperties() {
        XCTAssertEqual(AutomationMode.off.displayName, "Off")
        XCTAssertEqual(AutomationMode.scanOnly.displayName, "Scan Only")
        XCTAssertEqual(AutomationMode.scanAndOrganize.displayName, "Scan & Auto-Organize")

        XCTAssertEqual(AutomationMode.off.iconName, "stop.circle")
        XCTAssertEqual(AutomationMode.scanOnly.iconName, "eye")
        XCTAssertEqual(AutomationMode.scanAndOrganize.iconName, "bolt.circle")

        XCTAssertFalse(AutomationMode.off.description.isEmpty)
        XCTAssertFalse(AutomationMode.scanOnly.description.isEmpty)
        XCTAssertFalse(AutomationMode.scanAndOrganize.description.isEmpty)
    }

    // MARK: - App Lifecycle State Tests

    /// Test: AppLifecycleState scan interval multiplier
    func testAppLifecycleStateScanIntervalMultiplier() {
        XCTAssertEqual(AppLifecycleState.activeWithWindow.scanIntervalMultiplier, 1.0)
        XCTAssertEqual(AppLifecycleState.activeWindowClosed.scanIntervalMultiplier, 2.0)
        XCTAssertEqual(AppLifecycleState.backgrounded.scanIntervalMultiplier, 0.0)
        XCTAssertEqual(AppLifecycleState.menuBarOnly.scanIntervalMultiplier, 0.0)
    }

    /// Test: AppLifecycleState allowsScheduledScans
    func testAppLifecycleStateAllowsScheduledScans() {
        XCTAssertTrue(AppLifecycleState.activeWithWindow.allowsScheduledScans)
        XCTAssertTrue(AppLifecycleState.activeWindowClosed.allowsScheduledScans)
        XCTAssertFalse(AppLifecycleState.backgrounded.allowsScheduledScans)
        XCTAssertFalse(AppLifecycleState.menuBarOnly.allowsScheduledScans)
    }

    // MARK: - Helpers

    private func clearAutomationUserDefaults() {
        UserDefaults.standard.removeObject(forKey: AutomationUserSettings.Keys.mode)
        UserDefaults.standard.removeObject(forKey: AutomationUserSettings.Keys.scanInterval)
        UserDefaults.standard.removeObject(forKey: AutomationUserSettings.Keys.scanOnLaunch)
        UserDefaults.standard.removeObject(forKey: AutomationUserSettings.Keys.notifications)
    }
}
