import Foundation
import SwiftData
import Combine

/// ViewModel for the enhanced menu bar interface.
///
/// Provides live file counts, recent activity, and automation status
/// for the menu bar extra, with periodic refresh.
@MainActor
final class MenuBarViewModel: ObservableObject {

    // MARK: - Published State

    /// File counts by source location
    @Published private(set) var fileCounts = FormaActions.PendingFileCounts()

    /// Recent organization activity
    @Published private(set) var recentActivity: [FormaActions.RecentActivity] = []

    /// Current automation status
    @Published private(set) var automationStatus = FormaActions.AutomationStatus(
        mode: .off,
        isRunning: false,
        nextScheduledRun: nil,
        lastRunDate: nil,
        lastRunSuccessCount: 0
    )

    /// Whether data is currently being refreshed
    @Published private(set) var isRefreshing = false

    /// Last refresh timestamp
    @Published private(set) var lastRefresh: Date?

    // MARK: - Dependencies

    private let actions: FormaActions
    // nonisolated(unsafe) allows access from deinit in Swift 6
    nonisolated(unsafe) private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Configuration

    /// How often to refresh counts (in seconds)
    private let refreshInterval: TimeInterval = 30

    /// Maximum recent activities to show
    private let maxRecentActivities = 5

    // MARK: - Initialization

    init(actions: FormaActions = .shared) {
        self.actions = actions
        setupObservers()
    }

    deinit {
        refreshTimer?.invalidate()
    }

    // MARK: - Lifecycle

    /// Start periodic refresh. Call when menu bar becomes visible.
    func startRefreshing() {
        // Immediate refresh
        Task {
            await refresh()
        }

        // Setup timer for periodic refresh
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
    }

    /// Stop periodic refresh. Call when menu bar is hidden.
    func stopRefreshing() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    /// Manually trigger a refresh
    func refresh() async {
        guard !isRefreshing else { return }

        isRefreshing = true

        // Fetch all data in parallel
        async let counts = actions.getPendingFileCounts()
        async let activity = actions.getRecentActivity(limit: maxRecentActivities)
        let status = actions.getAutomationStatus()

        fileCounts = await counts
        recentActivity = await activity
        automationStatus = status
        lastRefresh = Date()

        isRefreshing = false
    }

    // MARK: - Actions

    /// Trigger a file scan
    func scanFiles() async -> FormaActions.ScanResult {
        let result = await actions.scanFiles()
        await refresh() // Refresh counts after scan
        return result
    }

    /// Organize all high-confidence files
    func organizeHighConfidenceFiles() async -> FormaActions.OrganizeResult {
        let result = await actions.organizeHighConfidenceFiles()
        await refresh() // Refresh after organization
        return result
    }

    /// Toggle automation on/off
    func toggleAutomation() -> AutomationMode {
        let newMode = actions.toggleAutomation()
        automationStatus = actions.getAutomationStatus()
        return newMode
    }

    // MARK: - Computed Properties

    /// Total pending files across all sources
    var totalPendingFiles: Int {
        fileCounts.total
    }

    /// Whether there are any pending files
    var hasPendingFiles: Bool {
        fileCounts.total > 0
    }

    /// Summary text for total pending
    var pendingSummary: String {
        if fileCounts.total == 0 {
            return "All organized"
        } else {
            return "\(fileCounts.total) file\(fileCounts.total == 1 ? "" : "s") pending"
        }
    }

    /// Badge text for menu bar icon (nil if no pending files)
    var badgeText: String? {
        guard fileCounts.total > 0 else { return nil }
        if fileCounts.total > 99 {
            return "99+"
        }
        return "\(fileCounts.total)"
    }

    /// Color indicator based on pending file count
    var statusIndicator: StatusIndicator {
        switch fileCounts.total {
        case 0:
            return .clear
        case 1...10:
            return .low
        case 11...50:
            return .medium
        default:
            return .high
        }
    }

    enum StatusIndicator {
        case clear   // No pending files - green/none
        case low     // 1-10 files - subtle
        case medium  // 11-50 files - attention
        case high    // 50+ files - urgent
    }

    // MARK: - Private

    private func setupObservers() {
        // Observe automation engine state changes
        AutomationEngine.shared.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                automationStatus = actions.getAutomationStatus()
            }
            .store(in: &cancellables)

        // Observe action results for immediate UI feedback
        actions.$lastActionResult
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.refresh()
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Menu Bar Data Structures

extension MenuBarViewModel {

    /// Represents a source folder with its pending count
    struct FolderStatus: Identifiable {
        let id = UUID()
        let name: String
        let iconName: String
        let count: Int

        var hasFiles: Bool { count > 0 }
    }

    /// Get folder statuses for display
    var folderStatuses: [FolderStatus] {
        [
            FolderStatus(name: "Desktop", iconName: "desktopcomputer", count: fileCounts.desktop),
            FolderStatus(name: "Downloads", iconName: "arrow.down.circle", count: fileCounts.downloads),
            FolderStatus(name: "Documents", iconName: "doc.text", count: fileCounts.documents),
            FolderStatus(name: "Pictures", iconName: "photo", count: fileCounts.pictures)
        ].filter { $0.hasFiles || fileCounts.total == 0 } // Show all if empty, otherwise only non-zero
    }
}
