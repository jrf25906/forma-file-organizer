import Foundation
import Combine

/// ViewModel for the enhanced menu bar interface.
///
/// Provides live file counts, file review queue, recent activity,
/// and automation status for the menu bar extra, with periodic refresh.
@MainActor
final class MenuBarViewModel: ObservableObject {

    // MARK: - Published State

    /// File counts by source location
    @Published private(set) var fileCounts = FormaActions.PendingFileCounts()

    /// The file review queue (pending/ready files)
    @Published private(set) var pendingFiles: [FileItem] = []

    /// Current position in the review queue
    @Published var currentReviewIndex: Int = 0

    /// Counts of files organized today and this week
    @Published private(set) var organizedTodayCount: Int = 0
    @Published private(set) var organizedThisWeekCount: Int = 0

    /// Loading state for single-file organize action
    @Published private(set) var isOrganizingCurrent: Bool = false

    /// Brief confirmation toast after "Organize All"
    @Published var showOrganizeAllConfirmation: Bool = false

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

    // MARK: - Computed Properties

    /// The file currently shown in the review card
    var currentReviewFile: FileItem? {
        guard !pendingFiles.isEmpty,
              currentReviewIndex >= 0,
              currentReviewIndex < pendingFiles.count else { return nil }
        return pendingFiles[currentReviewIndex]
    }

    /// Pagination text like "1 of 12"
    var reviewPaginationText: String {
        guard !pendingFiles.isEmpty else { return "" }
        return "\(currentReviewIndex + 1) of \(pendingFiles.count)"
    }

    /// Total pending files across all sources
    var totalPendingFiles: Int {
        fileCounts.total
    }

    /// Whether there are any pending files
    var hasPendingFiles: Bool {
        !pendingFiles.isEmpty
    }

    /// Summary text for total pending
    var pendingSummary: String {
        if pendingFiles.isEmpty {
            return "All organized"
        } else {
            let count = pendingFiles.count
            return "\(count) file\(count == 1 ? "" : "s") need review"
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

    /// Number of high-confidence files eligible for bulk organize
    var highConfidenceCount: Int {
        pendingFiles.filter { ($0.confidenceScore ?? 0) >= 0.9 && $0.hasDestination }.count
    }

    enum StatusIndicator {
        case clear   // No pending files - green/none
        case low     // 1-10 files - subtle
        case medium  // 11-50 files - attention
        case high    // 50+ files - urgent
    }

    // MARK: - Dependencies

    private let actions: FormaActions
    nonisolated(unsafe) private var refreshTimer: Timer?
    private var automationStateObservationTask: Task<Void, Never>?
    private var actionResultObservationTask: Task<Void, Never>?
    private var automationScanObservationTask: Task<Void, Never>?

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
        automationStateObservationTask?.cancel()
        actionResultObservationTask?.cancel()
        automationScanObservationTask?.cancel()
    }

    // MARK: - Lifecycle

    /// Start periodic refresh. Call when menu bar becomes visible.
    func startRefreshing() {
        Task {
            await refresh()
        }

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

        // Fetch all data (sequential — all @MainActor-isolated with non-Sendable results)
        fileCounts = await actions.getPendingFileCounts()
        pendingFiles = await actions.getPendingFileItems(limit: 50)
        recentActivity = await actions.getRecentActivity(limit: maxRecentActivities)
        let organizedResult = await actions.getOrganizedCounts()
        organizedTodayCount = organizedResult.today
        organizedThisWeekCount = organizedResult.thisWeek
        automationStatus = actions.getAutomationStatus()
        lastRefresh = Date()

        // Clamp review index
        clampReviewIndex()

        isRefreshing = false
    }

    // MARK: - Review Actions

    /// Organize the currently displayed file
    func organizeCurrentFile() async {
        guard let file = currentReviewFile else { return }

        isOrganizingCurrent = true
        let success = await actions.organizeFile(file)
        isOrganizingCurrent = false

        if success {
            removeCurrentFileFromQueue()
            organizedTodayCount += 1
            organizedThisWeekCount += 1
        }
    }

    /// Skip the currently displayed file
    func skipCurrentFile() {
        guard let file = currentReviewFile else { return }

        actions.skipFile(file)
        removeCurrentFileFromQueue()
    }

    /// Navigate the review card (forward/backward)
    func navigateReview(direction: ReviewDirection) {
        switch direction {
        case .next:
            if currentReviewIndex < pendingFiles.count - 1 {
                currentReviewIndex += 1
            }
        case .previous:
            if currentReviewIndex > 0 {
                currentReviewIndex -= 1
            }
        }
    }

    enum ReviewDirection {
        case next
        case previous
    }

    /// Organize all high-confidence files at once
    func organizeAllHighConfidence() async {
        let result = await actions.organizeHighConfidenceFiles()
        if result.success && result.organizedCount > 0 {
            showOrganizeAllConfirmation = true
            await refresh()
            // Auto-dismiss after 2 seconds
            Task {
                try? await Task.sleep(for: .seconds(2))
                showOrganizeAllConfirmation = false
            }
        }
    }

    // MARK: - Legacy Actions

    /// Trigger a file scan
    func scanFiles() async -> FormaActions.ScanResult {
        let result = await actions.scanFiles()
        await refresh()
        return result
    }

    /// Organize all high-confidence files (legacy wrapper)
    func organizeHighConfidenceFiles() async -> FormaActions.OrganizeResult {
        let result = await actions.organizeHighConfidenceFiles()
        await refresh()
        return result
    }

    /// Toggle automation on/off
    func toggleAutomation() -> AutomationMode {
        let newMode = actions.toggleAutomation()
        automationStatus = actions.getAutomationStatus()
        return newMode
    }

    // MARK: - Private

    private func removeCurrentFileFromQueue() {
        guard !pendingFiles.isEmpty,
              currentReviewIndex >= 0,
              currentReviewIndex < pendingFiles.count else { return }

        pendingFiles.remove(at: currentReviewIndex)
        clampReviewIndex()
    }

    private func clampReviewIndex() {
        if pendingFiles.isEmpty {
            currentReviewIndex = 0
        } else if currentReviewIndex >= pendingFiles.count {
            currentReviewIndex = pendingFiles.count - 1
        }
    }

    private func setupObservers() {
        automationStateObservationTask?.cancel()
        actionResultObservationTask?.cancel()
        automationScanObservationTask?.cancel()

        automationStateObservationTask = Task { @MainActor [weak self] in
            for await _ in AutomationEngine.shared.$state.values {
                guard let self else { return }
                automationStatus = actions.getAutomationStatus()
            }
        }

        actionResultObservationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await result in self.actions.$lastActionResult.values {
                if result != nil {
                    await self.refresh()
                }
            }
        }

        // Keep menu bar counts in sync with automation-engine scans that bypass FormaActions.
        automationScanObservationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await _ in NotificationCenter.default.notifications(named: .automationScanDidPersist) {
                await self.refresh()
            }
        }
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
        ].filter { $0.hasFiles || fileCounts.total == 0 }
    }
}
