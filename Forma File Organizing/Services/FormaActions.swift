import Foundation
import SwiftData
import Combine

// MARK: - Forma Actions

/// Shared action layer that provides a unified API for triggering Forma operations.
///
/// Both the menu bar and AppIntents call these same methods, ensuring consistent
/// behavior across all entry points (UI, Siri, Shortcuts, Spotlight).
///
/// ## Architecture
/// ```
/// ┌─────────────┐     ┌─────────────┐     ┌──────────────┐
/// │  Menu Bar   │────▶│             │     │ Automation   │
/// └─────────────┘     │             │────▶│   Engine     │
/// ┌─────────────┐     │ FormaActions│     └──────────────┘
/// │ AppIntents  │────▶│             │     ┌──────────────┐
/// └─────────────┘     │             │────▶│ Organization │
/// ┌─────────────┐     │             │     │ Coordinator  │
/// │  Shortcuts  │────▶│             │     └──────────────┘
/// └─────────────┘     └─────────────┘
/// ```
@MainActor
final class FormaActions: ObservableObject {

    // MARK: - Singleton

    static let shared = FormaActions()

    // MARK: - Dependencies

    private weak var modelContext: ModelContext?
    private var organizationCoordinator: FileOrganizationCoordinator?
    private var scanProvider: FileScanProvider?
    private let notificationService: NotificationService

    // MARK: - Published State

    /// Result of the last action for UI feedback
    @Published private(set) var lastActionResult: ActionResult?

    /// Whether full action capabilities are configured
    var isFullyConfigured: Bool {
        modelContext != nil && organizationCoordinator != nil && scanProvider != nil
    }

    // MARK: - Initialization

    private init() {
        self.notificationService = .shared
    }

    /// Configure with model context only (for read-only operations like counts and activity).
    /// Call this early during app initialization.
    func configureReadOnly(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Configure with full dependencies for all operations.
    /// Call once the organization coordinator and scan provider are available.
    func configureFull(
        modelContext: ModelContext,
        organizationCoordinator: FileOrganizationCoordinator,
        scanProvider: FileScanProvider
    ) {
        self.modelContext = modelContext
        self.organizationCoordinator = organizationCoordinator
        self.scanProvider = scanProvider
    }

    // MARK: - Actions

    /// Triggers a file scan across all monitored folders.
    ///
    /// - Returns: Result containing scan statistics
    func scanFiles() async -> ScanResult {
        guard let context = modelContext, let provider = scanProvider else {
            Log.warning("FormaActions: Cannot scan - not configured", category: .automation)
            return ScanResult(success: false, error: "Forma is not fully initialized")
        }

        do {
            let result = try await provider.scanFiles(context: context)
            if let errorSummary = result.errorSummary {
                notificationService.showNotification(
                    title: "Scan Completed With Errors",
                    message: errorSummary
                )
            }

            let scanResult = ScanResult(
                success: true,
                totalScanned: result.totalScanned,
                pendingCount: result.pendingCount,
                readyCount: result.readyCount
            )

            lastActionResult = .scan(scanResult)
            return scanResult

        } catch {
            Log.error("FormaActions: Scan failed - \(error.localizedDescription)", category: .automation)
            let scanResult = ScanResult(success: false, error: error.localizedDescription)
            lastActionResult = .scan(scanResult)
            return scanResult
        }
    }

    /// Organizes all files that meet the confidence threshold.
    ///
    /// - Parameter confidenceThreshold: Minimum confidence (0.0-1.0) for auto-organization. Default 0.9 (90%)
    /// - Returns: Result containing organization statistics
    func organizeHighConfidenceFiles(confidenceThreshold: Double = 0.9) async -> OrganizeResult {
        guard let context = modelContext,
              let coordinator = organizationCoordinator,
              let provider = scanProvider else {
            Log.warning("FormaActions: Cannot organize - not configured", category: .automation)
            return OrganizeResult(success: false, error: "Forma is not fully initialized")
        }

        // Get eligible files
        let eligibleFiles = await provider.getAutoOrganizeEligibleFiles(
            context: context,
            confidenceThreshold: confidenceThreshold
        )

        guard !eligibleFiles.isEmpty else {
            let result = OrganizeResult(success: true, organizedCount: 0, message: "No files ready for organization")
            lastActionResult = .organize(result)
            return result
        }

        // Perform organization
        return await withCheckedContinuation { continuation in
            Task {
                await coordinator.organizeMultipleFiles(eligibleFiles, context: context) { [weak self] success, failed, _, error in
                    let result = OrganizeResult(
                        success: error == nil,
                        organizedCount: success,
                        failedCount: failed,
                        error: error?.localizedDescription
                    )
                    self?.lastActionResult = .organize(result)
                    continuation.resume(returning: result)
                }
            }
        }
    }

    /// Gets the count of files pending organization.
    ///
    /// - Returns: File count statistics by source
    func getPendingFileCounts() async -> PendingFileCounts {
        guard let context = modelContext else {
            return PendingFileCounts()
        }

        // Query files with pending status
        let pendingRaw = FileItem.OrganizationStatus.pending.rawValue
        let descriptor = FetchDescriptor<FileItem>(
            predicate: #Predicate { $0.statusRaw == pendingRaw }
        )

        do {
            let pendingFiles = try context.fetch(descriptor)

            var desktopCount = 0
            var downloadsCount = 0
            var documentsCount = 0
            var picturesCount = 0
            var otherCount = 0

            for file in pendingFiles {
                switch file.location {
                case .desktop:
                    desktopCount += 1
                case .downloads:
                    downloadsCount += 1
                case .documents:
                    documentsCount += 1
                case .pictures:
                    picturesCount += 1
                case .home, .music, .custom, .unknown:
                    otherCount += 1
                }
            }

            return PendingFileCounts(
                total: pendingFiles.count,
                desktop: desktopCount,
                downloads: downloadsCount,
                documents: documentsCount,
                pictures: picturesCount,
                other: otherCount
            )
        } catch {
            Log.error("FormaActions: Failed to fetch pending counts - \(error.localizedDescription)", category: .general)
            return PendingFileCounts()
        }
    }

    /// Gets recent activity items for display.
    ///
    /// - Parameter limit: Maximum number of items to return
    /// - Returns: Array of recent activities
    func getRecentActivity(limit: Int = 5) async -> [RecentActivity] {
        guard let context = modelContext else {
            return []
        }

        // Fetch recent activities sorted by timestamp (fetch more than limit to filter)
        var descriptor = FetchDescriptor<ActivityItem>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit * 3 // Fetch extra to filter from

        // Types we want to show in menu bar (file movements only)
        let organizeTypes: Set<ActivityItem.ActivityType> = [
            .fileOrganized,
            .fileMoved,
            .bulkOrganized,
            .automationAutoOrganized
        ]

        do {
            let allActivities = try context.fetch(descriptor)

            // Filter in-memory since activityTypeRaw is private
            let filteredActivities = allActivities
                .filter { organizeTypes.contains($0.activityType) }
                .prefix(limit)

            return filteredActivities.map { activity in
                RecentActivity(
                    id: activity.id,
                    fileName: activity.fileName,
                    destination: activity.details,
                    timestamp: activity.timestamp,
                    fileExtension: activity.fileExtension,
                    activityType: activity.activityType
                )
            }
        } catch {
            Log.error("FormaActions: Failed to fetch recent activity - \(error.localizedDescription)", category: .general)
            return []
        }
    }

    /// Toggles automation mode between off and scan-only (or scan-and-organize if enabled).
    ///
    /// - Returns: The new automation mode
    func toggleAutomation() -> AutomationMode {
        let currentSettings = AutomationUserSettings.current
        let newMode: AutomationMode

        if currentSettings.mode == .off {
            // Turn on - use scan only by default for safety
            newMode = .scanOnly
        } else {
            // Turn off
            newMode = .off
        }

        // Persist the change to UserDefaults
        UserDefaults.standard.set(newMode.rawValue, forKey: AutomationUserSettings.Keys.mode)

        // Refresh the automation engine
        AutomationEngine.shared.refreshPolicy()

        lastActionResult = .toggleAutomation(newMode)
        return newMode
    }

    /// Gets the current automation status.
    func getAutomationStatus() -> AutomationStatus {
        let engine = AutomationEngine.shared
        let state = engine.state
        let policy = engine.policy

        return AutomationStatus(
            mode: policy.effectiveMode,
            isRunning: state.isRunning,
            nextScheduledRun: state.nextScheduledRun,
            lastRunDate: state.lastRunDate,
            lastRunSuccessCount: state.lastRunSuccessCount
        )
    }
}

// MARK: - Result Types

extension FormaActions {

    /// Result of a scan action
    struct ScanResult: Sendable {
        let success: Bool
        var totalScanned: Int = 0
        var pendingCount: Int = 0
        var readyCount: Int = 0
        var error: String?

        var summary: String {
            if success {
                if pendingCount > 0 {
                    return "Found \(pendingCount) file\(pendingCount == 1 ? "" : "s") to organize"
                } else {
                    return "All files organized"
                }
            } else {
                return error ?? "Scan failed"
            }
        }
    }

    /// Result of an organize action
    struct OrganizeResult: Sendable {
        let success: Bool
        var organizedCount: Int = 0
        var failedCount: Int = 0
        var error: String?
        var message: String?

        var summary: String {
            if let message = message {
                return message
            }
            if success {
                if organizedCount > 0 {
                    var text = "Organized \(organizedCount) file\(organizedCount == 1 ? "" : "s")"
                    if failedCount > 0 {
                        text += " (\(failedCount) failed)"
                    }
                    return text
                } else {
                    return "No files needed organizing"
                }
            } else {
                return error ?? "Organization failed"
            }
        }
    }

    /// Pending file counts by source
    struct PendingFileCounts: Sendable {
        var total: Int = 0
        var desktop: Int = 0
        var downloads: Int = 0
        var documents: Int = 0
        var pictures: Int = 0
        var other: Int = 0
    }

    /// Recent activity item for display
    struct RecentActivity: Identifiable, Sendable {
        let id: UUID
        let fileName: String
        let destination: String
        let timestamp: Date
        let fileExtension: String?
        let activityType: ActivityItem.ActivityType

        var relativeTime: String {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return formatter.localizedString(for: timestamp, relativeTo: Date())
        }

        var iconName: String {
            activityType.iconName
        }
    }

    /// Current automation status
    struct AutomationStatus: Sendable {
        let mode: AutomationMode
        let isRunning: Bool
        let nextScheduledRun: Date?
        let lastRunDate: Date?
        let lastRunSuccessCount: Int

        var isEnabled: Bool {
            mode != .off
        }

        var statusText: String {
            if isRunning {
                return "Scanning..."
            } else if let next = nextScheduledRun {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .abbreviated
                return "Next: \(formatter.localizedString(for: next, relativeTo: Date()))"
            } else if mode == .off {
                return "Off"
            } else {
                return "Ready"
            }
        }
    }

    /// Wrapper for last action result
    enum ActionResult {
        case scan(ScanResult)
        case organize(OrganizeResult)
        case toggleAutomation(AutomationMode)
    }
}
