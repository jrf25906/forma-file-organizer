import AppIntents
import SwiftUI

// MARK: - Scan Files Intent

/// Scans all monitored folders for files that need organization.
///
/// Invokable via:
/// - Siri: "Scan my files with Forma"
/// - Shortcuts: "Forma Scan Files" action
/// - Spotlight: Type "Scan files"
struct ScanFilesIntent: AppIntent {
    static let title: LocalizedStringResource = "Scan Files"
    static let description = IntentDescription("Scan monitored folders for files to organize")

    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let result = await FormaActions.shared.scanFiles()

        if result.success {
            return .result(value: result.summary)
        } else {
            throw FormaIntentError.scanFailed(result.error ?? "Unknown error")
        }
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Scan folders for files to organize")
    }
}

// MARK: - Organize Files Intent

/// Organizes files that meet the confidence threshold automatically.
///
/// Invokable via:
/// - Siri: "Organize my files with Forma"
/// - Shortcuts: "Forma Quick Organize" action
struct OrganizeFilesIntent: AppIntent {
    static let title: LocalizedStringResource = "Quick Organize"
    static let description = IntentDescription("Automatically organize high-confidence files")

    static let openAppWhenRun: Bool = false

    /// Confidence threshold (0.0-1.0). Files with ML confidence at or above this are organized.
    @Parameter(
        title: "Confidence Threshold",
        description: "Minimum confidence level (0-100%)",
        default: 90,
        controlStyle: .stepper,
        inclusiveRange: (50, 100)
    )
    var confidencePercent: Int

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let threshold = Double(confidencePercent) / 100.0
        let result = await FormaActions.shared.organizeHighConfidenceFiles(confidenceThreshold: threshold)

        if result.success {
            return .result(value: result.summary)
        } else {
            throw FormaIntentError.organizeFailed(result.error ?? "Unknown error")
        }
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Organize files with \(\.$confidencePercent)% confidence or higher")
    }
}

// MARK: - Get Pending Count Intent

/// Returns the count of files pending organization.
///
/// Useful in Shortcuts for conditional workflows:
/// - If pending count > 10, send notification
/// - Display count in a widget
struct GetPendingCountIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Pending File Count"
    static let description = IntentDescription("Get the number of files waiting to be organized")

    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        let counts = await FormaActions.shared.getPendingFileCounts()
        return .result(value: counts.total)
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Get pending file count")
    }
}

// MARK: - Toggle Automation Intent

/// Toggles Forma's automation mode on or off.
///
/// Useful for:
/// - Focus mode shortcuts (turn off during work)
/// - Time-based automation (enable at night)
struct ToggleAutomationIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Automation"
    static let description = IntentDescription("Turn Forma's automatic file organization on or off")

    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let newMode = FormaActions.shared.toggleAutomation()
        let modeDescription = newMode == .off ? "off" : "on (\(newMode.displayName))"
        return .result(value: "Automation is now \(modeDescription)")
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Toggle automation on/off")
    }
}

// MARK: - Get Automation Status Intent

/// Returns the current automation status.
struct GetAutomationStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Automation Status"
    static let description = IntentDescription("Check if Forma's automation is enabled")

    static let openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let status = FormaActions.shared.getAutomationStatus()
        return .result(value: status.statusText)
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Get automation status")
    }
}

// MARK: - Open Forma Intent

/// Opens the main Forma window.
///
/// Useful as part of a Shortcuts workflow that needs user review.
struct OpenFormaIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Forma"
    static let description = IntentDescription("Open Forma's main window for file review")

    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Open Forma")
    }
}

// MARK: - Error Types

enum FormaIntentError: Error, CustomLocalizedStringResourceConvertible {
    case scanFailed(String)
    case organizeFailed(String)
    case notConfigured

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .scanFailed(let message):
            return "Scan failed: \(message)"
        case .organizeFailed(let message):
            return "Organization failed: \(message)"
        case .notConfigured:
            return "Forma is not fully configured. Please open the app first."
        }
    }
}

// MARK: - App Shortcuts Provider

/// Registers Forma's intents as App Shortcuts for Siri and Spotlight.
///
/// These shortcuts appear in:
/// - Shortcuts app under "Forma"
/// - Spotlight search
/// - Siri suggestions
struct FormaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ScanFilesIntent(),
            phrases: [
                "Scan files with \(.applicationName)",
                "Check my files with \(.applicationName)",
                "Scan for files to organize with \(.applicationName)"
            ],
            shortTitle: "Scan Files",
            systemImageName: "magnifyingglass"
        )

        AppShortcut(
            intent: OrganizeFilesIntent(),
            phrases: [
                "Organize my files with \(.applicationName)",
                "Quick organize with \(.applicationName)",
                "Auto-organize files with \(.applicationName)"
            ],
            shortTitle: "Quick Organize",
            systemImageName: "folder.badge.gearshape"
        )

        AppShortcut(
            intent: GetPendingCountIntent(),
            phrases: [
                "How many files need organizing in \(.applicationName)",
                "Pending files in \(.applicationName)",
                "Files to organize with \(.applicationName)"
            ],
            shortTitle: "Pending Count",
            systemImageName: "number"
        )

        AppShortcut(
            intent: ToggleAutomationIntent(),
            phrases: [
                "Toggle \(.applicationName) automation",
                "Turn \(.applicationName) automation on",
                "Turn \(.applicationName) automation off"
            ],
            shortTitle: "Toggle Automation",
            systemImageName: "gearshape.2"
        )

        AppShortcut(
            intent: OpenFormaIntent(),
            phrases: [
                "Open \(.applicationName)",
                "Show \(.applicationName)",
                "Review files with \(.applicationName)"
            ],
            shortTitle: "Open Forma",
            systemImageName: "square.stack.3d.up.fill"
        )
    }
}
