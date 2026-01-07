import Foundation

// MARK: - Automation Mode

/// Defines the level of automation the user has enabled.
///
/// This is the primary user-facing control for automation behavior.
enum AutomationMode: String, CaseIterable, Identifiable, Codable {
    /// No automatic scans or moves. User must manually trigger everything.
    case off

    /// Background scans update file statuses and analytics, but no automatic moves.
    /// Useful for users who want visibility but prefer manual control.
    case scanOnly

    /// Full automation: background scans plus automatic moves for eligible files.
    /// Files are only moved when rules/destinations are clearly valid.
    case scanAndOrganize

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .scanOnly: return "Scan Only"
        case .scanAndOrganize: return "Scan & Auto-Organize"
        }
    }

    var description: String {
        switch self {
        case .off:
            return "Manual scans only. No background activity."
        case .scanOnly:
            return "Periodically scan files and update suggestions, but don't move files automatically."
        case .scanAndOrganize:
            return "Automatically organize files that match your rules with high confidence."
        }
    }

    var iconName: String {
        switch self {
        case .off: return "stop.circle"
        case .scanOnly: return "eye"
        case .scanAndOrganize: return "bolt.circle"
        }
    }
}

// MARK: - Automation Policy

/// A resolved policy object combining user settings, feature flags, and config caps.
///
/// `AutomationPolicy` is the single source of truth for automation decisions.
/// Services should query this instead of checking multiple sources directly.
///
/// ## Usage
/// ```swift
/// let policy = AutomationPolicy.resolve(
///     flags: FeatureFlagService.shared,
///     userSettings: AutomationUserSettings.current
/// )
///
/// if policy.effectiveMode == .scanAndOrganize && policy.canAutoOrganize {
///     // Proceed with auto-organization
/// }
/// ```
struct AutomationPolicy: Equatable, Sendable {

    // MARK: - Core Settings

    /// The user's selected automation mode.
    let userMode: AutomationMode

    /// The effective mode after applying feature flag overrides.
    /// May be more restrictive than `userMode` if flags are disabled.
    let effectiveMode: AutomationMode

    /// Scan interval in minutes. Zero means no scheduled scans.
    let scanIntervalMinutes: Int

    /// Whether to scan immediately on app launch.
    let scanOnLaunch: Bool

    // MARK: - Thresholds

    /// Number of pending files that triggers an early scan/reminder.
    let backlogThreshold: Int

    /// Age (in days) of oldest pending file that triggers a reminder.
    let ageThresholdDays: Int

    /// Minimum ML confidence required for auto-organize (0.0-1.0).
    /// Files below this threshold require manual review.
    let mlConfidenceThreshold: Double

    /// Maximum consecutive scan failures before backing off.
    let maxConsecutiveFailures: Int

    // MARK: - Notification Settings

    /// Whether automation-related notifications are enabled.
    let notificationsEnabled: Bool

    /// Cooldown between backlog reminder notifications (in hours).
    let backlogReminderCooldownHours: Int

    /// Cooldown between error notifications (in minutes).
    let errorNotificationCooldownMinutes: Int

    // MARK: - Computed Properties

    /// Whether any form of background scanning is allowed.
    var canScan: Bool {
        effectiveMode != .off
    }

    /// Whether automatic file organization is allowed.
    var canAutoOrganize: Bool {
        effectiveMode == .scanAndOrganize
    }

    /// Whether scheduled (interval-based) scans are enabled.
    var hasScheduledScans: Bool {
        canScan && scanIntervalMinutes > 0
    }

    // MARK: - Resolution

    /// Creates a resolved policy from current app state.
    ///
    /// This method combines:
    /// - User preferences (mode, interval)
    /// - Feature flags (may disable features)
    /// - FormaConfig caps (safety limits)
    ///
    /// - Parameters:
    ///   - flags: The feature flag service instance
    ///   - userSettings: User's automation preferences
    /// - Returns: A fully resolved policy ready for use
    static func resolve(
        flags: FeatureFlagService,
        userSettings: AutomationUserSettings
    ) -> AutomationPolicy {

        // Determine effective mode based on feature flags
        let effectiveMode: AutomationMode = {
            // If master AI is off, no automation
            guard flags.masterAIEnabled else { return .off }

            // If background monitoring flag is off, no automation
            guard flags.isEnabled(.backgroundMonitoring) else { return .off }

            // If user wants auto-organize but flag is off, downgrade to scan-only
            if userSettings.mode == .scanAndOrganize && !flags.isEnabled(.autoOrganize) {
                return .scanOnly
            }

            return userSettings.mode
        }()

        // Clamp interval to config bounds
        let clampedInterval = min(
            max(userSettings.scanIntervalMinutes, FormaConfig.Automation.minScanIntervalMinutes),
            FormaConfig.Automation.maxScanIntervalMinutes
        )

        // Notifications require both user setting and feature flag
        let notificationsEnabled = userSettings.notificationsEnabled &&
            flags.isEnabled(.automationReminders)

        return AutomationPolicy(
            userMode: userSettings.mode,
            effectiveMode: effectiveMode,
            scanIntervalMinutes: effectiveMode == .off ? 0 : clampedInterval,
            scanOnLaunch: userSettings.scanOnLaunch && effectiveMode != .off,
            backlogThreshold: FormaConfig.Automation.backlogThreshold,
            ageThresholdDays: FormaConfig.Automation.ageThresholdDays,
            mlConfidenceThreshold: FormaConfig.Automation.mlAutoOrganizeConfidenceMinimum,
            maxConsecutiveFailures: FormaConfig.Automation.maxConsecutiveFailures,
            notificationsEnabled: notificationsEnabled,
            backlogReminderCooldownHours: FormaConfig.Automation.backlogReminderCooldownHours,
            errorNotificationCooldownMinutes: FormaConfig.Automation.errorNotificationCooldownMinutes
        )
    }
}

// MARK: - User Settings

/// User-configurable automation preferences.
///
/// These are persisted via `@AppStorage` in the Settings UI.
struct AutomationUserSettings: Equatable, Sendable {
    let mode: AutomationMode
    let scanIntervalMinutes: Int
    let scanOnLaunch: Bool
    let notificationsEnabled: Bool

    /// Loads current settings from UserDefaults.
    static var current: AutomationUserSettings {
        AutomationUserSettings(
            mode: AutomationMode(rawValue: UserDefaults.standard.string(forKey: Keys.mode) ?? "") ?? .scanOnly,
            scanIntervalMinutes: UserDefaults.standard.integer(forKey: Keys.scanInterval),
            scanOnLaunch: UserDefaults.standard.bool(forKey: Keys.scanOnLaunch),
            notificationsEnabled: UserDefaults.standard.bool(forKey: Keys.notifications)
        )
    }

    enum Keys {
        static let mode = "automation.mode"
        static let scanInterval = "automation.scanInterval"
        static let scanOnLaunch = "automation.scanOnLaunch"
        static let notifications = "automation.notifications"
    }
}

// MARK: - App Lifecycle State

/// Represents the app's current lifecycle state for automation decisions.
///
/// Automation behavior varies based on whether the app is actively in use.
enum AppLifecycleState: Equatable, Sendable {
    /// App is active with main window visible. Full automation.
    case activeWithWindow

    /// App is active but main window is closed (Dock only). Reduced cadence.
    case activeWindowClosed

    /// App is in background. Automation paused.
    case backgrounded

    /// App is running as menu bar only. On-demand scans only.
    case menuBarOnly

    /// Multiplier applied to scan interval based on lifecycle state.
    var scanIntervalMultiplier: Double {
        switch self {
        case .activeWithWindow: return 1.0
        case .activeWindowClosed: return 2.0  // Half frequency
        case .backgrounded: return 0.0        // Paused
        case .menuBarOnly: return 0.0         // On-demand only
        }
    }

    /// Whether scheduled scans should run in this state.
    var allowsScheduledScans: Bool {
        switch self {
        case .activeWithWindow, .activeWindowClosed: return true
        case .backgrounded, .menuBarOnly: return false
        }
    }
}

// MARK: - FormaConfig Extension

extension FormaConfig {
    /// Automation-related configuration constants.
    enum Automation {
        /// Minimum scan interval (prevents aggressive scanning).
        static let minScanIntervalMinutes = 5

        /// Maximum scan interval.
        static let maxScanIntervalMinutes = 1440  // 24 hours

        /// Default scan interval for new users.
        static let defaultScanIntervalMinutes = 30

        /// Debounce window between scans (prevents rapid consecutive scans).
        static let scanDebounceDurationSeconds: TimeInterval = 60

        /// Number of pending files that triggers early action.
        static let backlogThreshold = 50

        /// Age threshold for "stale" pending files (days).
        static let ageThresholdDays = 7

        /// Minimum ML confidence for rule-based auto-organize.
        static let mlRuleConfidenceMinimum: Double = 0.75

        /// Higher threshold for ML-predicted destinations (no explicit rule).
        static let mlAutoOrganizeConfidenceMinimum: Double = 0.90

        /// Max consecutive failures before backing off.
        static let maxConsecutiveFailures = 3

        /// Backoff multiplier after failures (exponential).
        static let failureBackoffMultiplier: Double = 2.0

        /// Maximum backoff interval (minutes).
        static let maxBackoffIntervalMinutes = 120

        /// Cooldown between backlog reminders (hours).
        static let backlogReminderCooldownHours = 24

        /// Cooldown between error notifications (minutes).
        static let errorNotificationCooldownMinutes = 60

        /// Max automation notifications per hour (spam prevention).
        static let maxNotificationsPerHour = 5
    }
}
