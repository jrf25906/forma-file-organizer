import Foundation
import SwiftData
import Observation
import Combine

// MARK: - Automation State

/// Observable state for UI binding to automation status.
@Observable
final class AutomationState {
    private let clock: Clock

    init(clock: Clock = SystemClock()) {
        self.clock = clock
    }

    /// Whether an automation operation is currently running.
    var isRunning: Bool = false

    /// Timestamp of the last completed automation run.
    var lastRunDate: Date?

    /// Number of files successfully organized in the last run.
    var lastRunSuccessCount: Int = 0

    /// Number of files that failed in the last run.
    var lastRunFailedCount: Int = 0

    /// Number of files skipped (didn't meet criteria) in the last run.
    var lastRunSkippedCount: Int = 0

    /// Next scheduled scan time (nil if no scheduled scans).
    var nextScheduledRun: Date?

    /// Current consecutive failure count (for backoff).
    var consecutiveFailures: Int = 0

    /// Current backoff interval in minutes (0 = no backoff).
    var currentBackoffMinutes: Int = 0

    /// Whether realtime folder watching is currently active.
    var isWatchingFolders: Bool = false

    /// Human-readable status for UI display.
    var statusMessage: String {
        if isRunning {
            return "Scanning..."
        } else if isWatchingFolders, let next = nextScheduledRun {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Watching folders · next sweep \(formatter.localizedString(for: next, relativeTo: clock.now))"
        } else if isWatchingFolders {
            return "Watching folders"
        } else if let next = nextScheduledRun {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Next scan \(formatter.localizedString(for: next, relativeTo: clock.now))"
        } else {
            return "Automation paused"
        }
    }
}

// MARK: - Automation Engine

/// Central coordinator for all background automation in Forma.
///
/// `AutomationEngine` owns:
/// - Scheduled and threshold-triggered scans
/// - Auto-organize decisions for eligible files
/// - Automation-related notifications
/// - Lifecycle-aware scheduling
///
/// ## Architecture
/// ```
/// ┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
/// │ AutomationPolicy│────▶│ AutomationEngine │────▶│ FileOrganization│
/// │   (decisions)   │     │  (orchestrator)  │     │   Coordinator   │
/// └─────────────────┘     └──────────────────┘     └─────────────────┘
///                                │
///                                ▼
///                      ┌──────────────────┐
///                      │NotificationService│
///                      └──────────────────┘
/// ```
///
/// ## Usage
/// ```swift
/// let engine = AutomationEngine.shared
/// engine.configure(modelContext: context)
/// engine.start()
/// ```
@MainActor
final class AutomationEngine: ObservableObject {

    // MARK: - Singleton

    static let shared = AutomationEngine()

    // MARK: - Published State

    /// Observable state for UI binding.
    @Published private(set) var state: AutomationState

    /// Current resolved policy.
    @Published private(set) var policy: AutomationPolicy = .resolve(
        flags: FeatureFlagService.shared,
        userSettings: .current
    )

    /// Current app lifecycle state.
    @Published var lifecycleState: AppLifecycleState = .activeWithWindow {
        didSet {
            handleLifecycleChange(from: oldValue, to: lifecycleState)
        }
    }

    // MARK: - Dependencies

    private let featureFlags: FeatureFlagService
    private let notificationService: AutomationNotificationServing
    private let clock: Clock
    private let policyResolver: () -> AutomationPolicy
    private let fileMonitor: FileMonitoring
    private let watchedFoldersProvider: @MainActor () -> [WatchedFolderDescriptor]
    private var modelContext: ModelContext?

    // Lazy initialization to avoid circular dependencies
    private var organizationCoordinator: FileOrganizationCoordinator?
    private var scanProvider: FileScanProvider?

    // MARK: - Internal State

    private var scheduledScanTask: Task<Void, Never>?
    private var lastScanDate: Date?
    private var lastBacklogReminderDate: Date?
    private var lastErrorNotificationDate: Date?
    private var notificationCountThisHour: Int = 0
    private var hourStartDate: Date
    private var pendingRealtimeRoots: Set<FolderLocation> = []
    private var bookmarkFolderObservationTask: Task<Void, Never>?

    // MARK: - Initialization

    init(
        featureFlags: FeatureFlagService = .shared,
        notificationService: AutomationNotificationServing = NotificationService.shared,
        clock: Clock = SystemClock(),
        policyResolver: (() -> AutomationPolicy)? = nil,
        fileMonitor: FileMonitoring = FileMonitorService(),
        watchedFoldersProvider: (@MainActor () -> [WatchedFolderDescriptor])? = nil
    ) {
        self.featureFlags = featureFlags
        self.notificationService = notificationService
        self.clock = clock
        self.fileMonitor = fileMonitor
        self.policyResolver = policyResolver ?? {
            AutomationPolicy.resolve(flags: featureFlags, userSettings: .current)
        }
        self.watchedFoldersProvider = watchedFoldersProvider ?? {
            BookmarkFolderService.shared.enabledFolders.compactMap { folder in
                guard let resolved = folder.resolveURL() else { return nil }
                return WatchedFolderDescriptor(
                    location: FolderLocation.from(bookmarkFolderType: folder.folderType),
                    rootURL: resolved.url,
                    bookmarkData: folder.bookmarkData
                )
            }
        }
        self.policy = self.policyResolver()
        self.state = AutomationState(clock: clock)
        self.hourStartDate = clock.now

        // Observe feature flag changes
        setupObservers()
    }

    deinit {
        bookmarkFolderObservationTask?.cancel()
    }

    // MARK: - Configuration

    /// Configures the engine with required dependencies.
    ///
    /// Call this once during app initialization, typically in the App struct.
    ///
    /// - Parameters:
    ///   - modelContext: SwiftData context for persistence
    ///   - organizationCoordinator: Coordinator for file operations
    ///   - scanProvider: Provider for file scanning operations
    func configure(
        modelContext: ModelContext,
        organizationCoordinator: FileOrganizationCoordinator,
        scanProvider: FileScanProvider
    ) {
        self.modelContext = modelContext
        self.organizationCoordinator = organizationCoordinator
        self.scanProvider = scanProvider

        // Refresh policy with current settings
        refreshPolicy()
    }

    // MARK: - Lifecycle

    /// Starts the automation engine.
    ///
    /// This begins scheduled scans according to the current policy.
    /// Call this after `configure()` and when the app becomes active.
    func start() {
        guard policy.canScan else {
            Log.info("AutomationEngine: Not starting - automation disabled", category: .automation)
            refreshMonitoringState()
            return
        }

        Log.info("AutomationEngine: Starting with mode=\(policy.effectiveMode)", category: .automation)

        // Scan on launch if enabled
        if policy.scanOnLaunch {
            Task {
                await performScan(reason: .appLaunch, baseFolders: nil)
            }
        }

        // Start scheduled scans
        scheduleNextScan()
        refreshMonitoringState()
    }

    /// Stops the automation engine.
    ///
    /// Cancels any pending scans. Call when the app is terminating
    /// or when the user disables automation.
    func stop() {
        Log.info("AutomationEngine: Stopping", category: .automation)
        scheduledScanTask?.cancel()
        scheduledScanTask = nil
        state.nextScheduledRun = nil
        pendingRealtimeRoots.removeAll()
        fileMonitor.stopMonitoring()
        state.isWatchingFolders = false
    }

    /// Refreshes the policy from current settings and feature flags.
    ///
    /// Call this when user changes settings or feature flags change.
    func refreshPolicy() {
        let newPolicy = policyResolver()

        let modeChanged = policy.effectiveMode != newPolicy.effectiveMode
        policy = newPolicy

        if modeChanged {
            Log.info("AutomationEngine: Policy changed to mode=\(newPolicy.effectiveMode)", category: .automation)

            // Restart scheduling with new policy
            stop()
            if newPolicy.canScan {
                start()
            }
        } else {
            refreshMonitoringState()
        }
    }

    // MARK: - Manual Triggers

    /// Triggers an immediate scan, bypassing the schedule.
    ///
    /// Use for user-initiated "Scan Now" actions.
    func triggerManualScan() async {
        await performScan(reason: .manual, baseFolders: nil)
    }

    /// Triggers an auto-organize pass for eligible files.
    ///
    /// Only runs if policy allows auto-organization.
    func triggerAutoOrganize() async {
        guard policy.canAutoOrganize else {
            Log.info("AutomationEngine: Auto-organize not allowed by policy", category: .automation)
            return
        }

        await performAutoOrganize()
    }

    // MARK: - Threshold Checks

    /// Checks if backlog thresholds are exceeded and takes action.
    ///
    /// Call this after scans complete to trigger reminders or early actions.
    ///
    /// - Parameter metrics: Current file metrics from the scan
    func checkThresholds(metrics: AutomationMetrics) {
        // Check backlog count threshold
        if metrics.pendingCount >= policy.backlogThreshold {
            handleBacklogThresholdExceeded(metrics: metrics)
        }

        // Check file age threshold
        if let oldestAge = metrics.oldestPendingAgeDays, oldestAge >= policy.ageThresholdDays {
            handleAgeThresholdExceeded(oldestAgeDays: oldestAge)
        }
    }

    // MARK: - Private: Scanning

    private func performScan(reason: ScanReason, baseFolders: [FolderLocation]?) async {
        guard let context = modelContext, let provider = scanProvider else {
            Log.warning("AutomationEngine: Cannot scan - not configured", category: .automation)
            return
        }

        if state.isRunning {
            if reason == .fileSystemEvent, let baseFolders {
                pendingRealtimeRoots.formUnion(baseFolders)
            } else {
                Log.info("AutomationEngine: Ignoring \(reason.rawValue) while a scan is already running", category: .automation)
            }
            return
        }

        // Debounce rapid scans
        if let last = lastScanDate,
           reason != .fileSystemEvent,
           clock.now.timeIntervalSince(last) < FormaConfig.Automation.scanDebounceDurationSeconds {
            Log.info("AutomationEngine: Scan debounced", category: .automation)
            return
        }

        state.isRunning = true
        defer {
            state.isRunning = false
            scheduleNextScan()
            Task { @MainActor [weak self] in
                await self?.drainPendingRealtimeRescansIfNeeded()
            }
        }
        Log.info("AutomationEngine: Starting scan (reason: \(reason))", category: .automation)

        do {
            // Perform the scan via the provider
            let result = try await provider.scanFiles(context: context, baseFolders: baseFolders)

            // Update state
            lastScanDate = clock.now
            state.lastRunDate = clock.now
            state.consecutiveFailures = 0
            state.currentBackoffMinutes = 0

            // Check thresholds
            let metrics = AutomationMetrics(from: result)
            if let errorSummary = result.errorSummary {
                let errorType = result.primaryErrorType ?? AutomationErrorType.classify(message: errorSummary)
                Log.warning("AutomationEngine: Scan completed with errors - \(errorSummary)", category: .automation)
                ActivityLoggingService.create(from: context)?.logAutomationError(type: errorType, message: errorSummary)
                sendErrorNotification(type: errorType, message: errorSummary)
            }
            checkThresholds(metrics: metrics)

            // Auto-organize if enabled
            if policy.canAutoOrganize {
                await performAutoOrganize()
            }

            Log.info("AutomationEngine: Scan completed - \(result.totalScanned) files", category: .automation)

        } catch {
            handleScanFailure(error: error)
        }
    }

    private func performAutoOrganize() async {
        guard let context = modelContext,
              let coordinator = organizationCoordinator,
              let provider = scanProvider else {
            return
        }

        // Get eligible files
        let eligibleFiles: [FileItem]
        do {
            eligibleFiles = try await provider.getAutoOrganizeEligibleFiles(
                context: context,
                confidenceThreshold: policy.mlConfidenceThreshold
            )
        } catch {
            let errorType = AutomationErrorType.classify(error: error)
            let message = AutomationErrorType.cleanMessage(from: error)
            Log.error("AutomationEngine: \(message)", category: .automation)
            ActivityLoggingService.create(from: context)?.logAutomationError(type: errorType, message: message)
            sendErrorNotification(type: errorType, message: message)
            return
        }

        guard !eligibleFiles.isEmpty else {
            Log.info("AutomationEngine: No eligible files for auto-organize", category: .automation)
            return
        }

        Log.info("AutomationEngine: Auto-organizing \(eligibleFiles.count) files", category: .automation)

        // Perform bulk organize
        await coordinator.organizeMultipleFiles(eligibleFiles, context: context) { [weak self] success, failed, failedFiles, error in
            guard let self else { return }

            self.state.lastRunSuccessCount = success
            self.state.lastRunFailedCount = failed

            // Send notification
            if success > 0 {
                self.sendAutoOrganizeSummary(successCount: success, failedCount: failed, skippedCount: 0)
            }

            if let error {
                Log.error("AutomationEngine: Auto-organize had failures - \(error.localizedDescription)", category: .automation)
            }
        }
    }

    // MARK: - Private: Scheduling

    private func scheduleNextScan() {
        scheduledScanTask?.cancel()

        guard policy.hasScheduledScans,
              lifecycleState.allowsScheduledScans else {
            state.nextScheduledRun = nil
            return
        }

        // Calculate interval with lifecycle multiplier and backoff
        var intervalMinutes = Double(policy.scanIntervalMinutes)
        intervalMinutes *= lifecycleState.scanIntervalMultiplier
        intervalMinutes += Double(state.currentBackoffMinutes)

        let interval = max(intervalMinutes, Double(FormaConfig.Automation.minScanIntervalMinutes))
        let nextRun = clock.now.addingTimeInterval(interval * 60)
        state.nextScheduledRun = nextRun

        scheduledScanTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(interval * 60))
            } catch {
                Log.debug("AutomationEngine: Scheduled scan sleep interrupted - \(error.localizedDescription)", category: .automation)
                return
            }

            guard !Task.isCancelled else { return }
            await self?.performScan(reason: .scheduled, baseFolders: nil)
        }
    }

    // MARK: - Private: Error Handling

    private func handleScanFailure(error: Error) {
        state.consecutiveFailures += 1
        Log.error("AutomationEngine: Scan failed (\(state.consecutiveFailures) consecutive) - \(error.localizedDescription)", category: .automation)

        if state.consecutiveFailures >= policy.maxConsecutiveFailures {
            // Apply exponential backoff
            state.currentBackoffMinutes = AutomationBackoffPolicy.backoffMinutes(
                consecutiveFailures: state.consecutiveFailures
            )

            // Send error notification
            sendErrorNotification(
                type: AutomationErrorType.classify(error: error),
                message: AutomationErrorType.cleanMessage(from: error)
            )
        }
    }

    private func handleBacklogThresholdExceeded(metrics: AutomationMetrics) {
        Log.info("AutomationEngine: Backlog threshold exceeded (\(metrics.pendingCount) files)", category: .automation)

        // Trigger early scan if in scan-only mode
        if policy.effectiveMode == .scanOnly {
            sendBacklogReminder(pendingCount: metrics.pendingCount, oldestAgeDays: metrics.oldestPendingAgeDays)
        }
    }

    private func handleAgeThresholdExceeded(oldestAgeDays: Int) {
        Log.info("AutomationEngine: Age threshold exceeded (\(oldestAgeDays) days)", category: .automation)
        sendBacklogReminder(pendingCount: 0, oldestAgeDays: oldestAgeDays)
    }

    // MARK: - Private: Notifications

    private func sendAutoOrganizeSummary(successCount: Int, failedCount: Int, skippedCount: Int) {
        guard policy.notificationsEnabled, canSendNotification() else { return }

        notificationService.notifyAutoOrganizeSummary(
            successCount: successCount,
            failedCount: failedCount,
            skippedCount: skippedCount
        )
        recordNotificationSent()
    }

    private func sendBacklogReminder(pendingCount: Int, oldestAgeDays: Int?) {
        guard policy.notificationsEnabled, canSendBacklogReminder() else { return }

        notificationService.notifyBacklogReminder(
            pendingCount: pendingCount,
            oldestAgeDays: oldestAgeDays
        )
        lastBacklogReminderDate = clock.now
        recordNotificationSent()
    }

    private func sendErrorNotification(type: AutomationErrorType, message: String) {
        guard policy.notificationsEnabled, canSendErrorNotification() else { return }

        notificationService.notifyAutomationError(type: type, message: message)
        lastErrorNotificationDate = clock.now
        recordNotificationSent()
    }

    private func canSendNotification() -> Bool {
        // Reset hourly counter if needed
        if clock.now.timeIntervalSince(hourStartDate) >= 3600 {
            hourStartDate = clock.now
            notificationCountThisHour = 0
        }
        return notificationCountThisHour < FormaConfig.Automation.maxNotificationsPerHour
    }

    private func canSendBacklogReminder() -> Bool {
        guard let last = lastBacklogReminderDate else { return true }
        let cooldown = TimeInterval(policy.backlogReminderCooldownHours * 3600)
        return clock.now.timeIntervalSince(last) >= cooldown
    }

    private func canSendErrorNotification() -> Bool {
        guard let last = lastErrorNotificationDate else { return true }
        let cooldown = TimeInterval(policy.errorNotificationCooldownMinutes * 60)
        return clock.now.timeIntervalSince(last) >= cooldown
    }

    private func recordNotificationSent() {
        notificationCountThisHour += 1
    }

    // MARK: - Private: Lifecycle

    private func handleLifecycleChange(from oldState: AppLifecycleState, to newState: AppLifecycleState) {
        Log.info("AutomationEngine: Lifecycle changed from \(oldState) to \(newState)", category: .automation)

        if newState.allowsScheduledScans && !oldState.allowsScheduledScans {
            // Resuming - reschedule
            scheduleNextScan()
        } else if !newState.allowsScheduledScans && oldState.allowsScheduledScans {
            // Pausing - cancel scheduled task
            scheduledScanTask?.cancel()
            state.nextScheduledRun = nil
        } else if newState.scanIntervalMultiplier != oldState.scanIntervalMultiplier {
            // Interval changed - reschedule
            scheduleNextScan()
        }

        refreshMonitoringState()
    }

    private func setupObservers() {
        bookmarkFolderObservationTask?.cancel()
        bookmarkFolderObservationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await _ in BookmarkFolderService.shared.$availableFolders.values {
                self.refreshMonitoringState()
            }
        }
    }

    private func refreshMonitoringState() {
        let shouldWatchFolders = policy.canScan &&
            (lifecycleState == .activeWithWindow || lifecycleState == .menuBarOnly)

        guard shouldWatchFolders else {
            pendingRealtimeRoots.removeAll()
            fileMonitor.stopMonitoring()
            state.isWatchingFolders = false
            return
        }

        let folders = watchedFoldersProvider()
        let watchedLocations = Set(folders.map(\.location))
        pendingRealtimeRoots = pendingRealtimeRoots.intersection(watchedLocations)
        guard !folders.isEmpty else {
            pendingRealtimeRoots.removeAll()
            fileMonitor.stopMonitoring()
            state.isWatchingFolders = false
            return
        }

        if fileMonitor.isMonitoring {
            fileMonitor.updateMonitoredFolders(folders)
        } else {
            fileMonitor.startMonitoring(folders: folders) { [weak self] changedFolders in
                self?.handleWatchedFoldersChanged(changedFolders)
            }
        }

        state.isWatchingFolders = fileMonitor.isMonitoring
    }

    private func handleWatchedFoldersChanged(_ folders: Set<FolderLocation>) {
        guard policy.canScan, !folders.isEmpty else { return }
        pendingRealtimeRoots.formUnion(folders)

        Task { @MainActor [weak self] in
            await self?.drainPendingRealtimeRescansIfNeeded()
        }
    }

    private func drainPendingRealtimeRescansIfNeeded() async {
        guard !state.isRunning, !pendingRealtimeRoots.isEmpty else { return }
        let roots = pendingRealtimeRoots.sorted { $0.displayName < $1.displayName }
        pendingRealtimeRoots.removeAll()
        await performScan(reason: .fileSystemEvent, baseFolders: roots)
    }
}

// MARK: - Supporting Types

/// Reason for triggering a scan.
enum ScanReason: String, Sendable {
    case appLaunch = "app_launch"
    case scheduled = "scheduled"
    case manual = "manual"
    case fileSystemEvent = "file_system_event"
    case thresholdExceeded = "threshold_exceeded"
}

/// Metrics computed from a scan result.
struct AutomationMetrics: Sendable {
    let totalScanned: Int
    let pendingCount: Int
    let readyCount: Int
    let organizedCount: Int
    let skippedCount: Int
    let oldestPendingAgeDays: Int?

    init(from scanResult: FileScanResult) {
        self.totalScanned = scanResult.totalScanned
        self.pendingCount = scanResult.pendingCount
        self.readyCount = scanResult.readyCount
        self.organizedCount = scanResult.organizedCount
        self.skippedCount = scanResult.skippedCount
        self.oldestPendingAgeDays = scanResult.oldestPendingAgeDays
    }

    init(totalScanned: Int = 0, pendingCount: Int = 0, readyCount: Int = 0,
         organizedCount: Int = 0, skippedCount: Int = 0, oldestPendingAgeDays: Int? = nil) {
        self.totalScanned = totalScanned
        self.pendingCount = pendingCount
        self.readyCount = readyCount
        self.organizedCount = organizedCount
        self.skippedCount = skippedCount
        self.oldestPendingAgeDays = oldestPendingAgeDays
    }
}

/// Types of automation errors for notifications.
enum AutomationErrorType: Sendable {
    case scanFailed
    case bookmarkInvalid
    case destinationInaccessible
    case permissionDenied

    var title: String {
        switch self {
        case .scanFailed: return "Scan Needs Attention"
        case .bookmarkInvalid: return "Reconnect Folder Access"
        case .destinationInaccessible: return "Destination Unavailable"
        case .permissionDenied: return "Permission Needed"
        }
    }

    func supportiveMessage(detail: String) -> String {
        let prefix: String
        switch self {
        case .scanFailed:
            prefix = "Forma couldn't finish a scan"
        case .bookmarkInvalid:
            prefix = "Forma needs folder access restored before it can keep watching this location"
        case .destinationInaccessible:
            prefix = "Forma couldn't reach one of your organize destinations"
        case .permissionDenied:
            prefix = "Forma needs macOS permission before it can keep organizing here"
        }

        let cleanedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedDetail.isEmpty else {
            return prefix + "."
        }
        return prefix + ". " + cleanedDetail.terminatedSentence()
    }

    static func classify(error: Error) -> AutomationErrorType {
        if let scanError = error as? DashboardFileScanProvider.ScanError {
            switch scanError {
            case .bookmarkFailure:
                return .bookmarkInvalid
            case .candidateFetchFailed(let details):
                return classify(message: details)
            case .timeout, .noFoldersConfigured:
                return .scanFailed
            }
        }

        if let formaError = error as? FormaError {
            switch formaError {
            case .fileSystem(let fileError):
                switch fileError {
                case .permissionDenied:
                    return .permissionDenied
                default:
                    break
                }
            case .validation(let validationError):
                switch validationError {
                case .invalidDestination(let details):
                    let normalized = details.lowercased()
                    return normalized.contains("bookmark") ? .bookmarkInvalid : .destinationInaccessible
                default:
                    break
                }
            case .data(let dataError):
                switch dataError {
                case .corruptedData(let details), .invalidData(let details):
                    if details.lowercased().contains("bookmark") {
                        return .bookmarkInvalid
                    }
                default:
                    break
                }
            default:
                break
            }
        }

        return classify(message: cleanMessage(from: error))
    }

    static func classify(scanErrors: [String: Error], fallbackSummary: String?) -> AutomationErrorType? {
        let structuredTypes = scanErrors.values.map(classify(error:))
        let priority: [AutomationErrorType] = [
            .bookmarkInvalid,
            .permissionDenied,
            .destinationInaccessible,
            .scanFailed
        ]

        for candidate in priority where structuredTypes.contains(candidate) {
            return candidate
        }

        guard let fallbackSummary else {
            return nil
        }
        return classify(message: fallbackSummary)
    }

    static func classify(message: String) -> AutomationErrorType {
        let normalized = message.lowercased()
        if normalized.contains("bookmark") || normalized.contains("security-scoped") {
            return .bookmarkInvalid
        }
        if normalized.contains("permission") || normalized.contains("access denied") || normalized.contains("access to folder denied") {
            return .permissionDenied
        }
        if normalized.contains("destination") || normalized.contains("unavailable") {
            return .destinationInaccessible
        }
        return .scanFailed
    }

    static func cleanMessage(from error: Error) -> String {
        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? "Unknown automation error" : message
    }
}

private extension String {
    func terminatedSentence() -> String {
        guard let last else { return self }
        if last == "." || last == "!" || last == "?" {
            return self
        }
        return self + "."
    }
}

// MARK: - Protocols

/// Protocol for providing file scan capabilities to the automation engine.
///
/// This abstraction allows the engine to be tested without real file system access.
@MainActor
protocol FileScanProvider: AnyObject {
    /// Performs a file scan and returns the result.
    func scanFiles(context: ModelContext, baseFolders: [FolderLocation]?) async throws -> FileScanResult

    /// Returns files eligible for auto-organization.
    func getAutoOrganizeEligibleFiles(
        context: ModelContext,
        confidenceThreshold: Double
    ) async throws -> [FileItem]
}

/// Result of a file scan operation.
struct FileScanResult: Sendable {
    let totalScanned: Int
    let pendingCount: Int
    let readyCount: Int
    let organizedCount: Int
    let skippedCount: Int
    let oldestPendingAgeDays: Int?
    let errorSummary: String?
    let primaryErrorType: AutomationErrorType?
    let scannedRootPaths: [String]

    init(
        totalScanned: Int,
        pendingCount: Int,
        readyCount: Int,
        organizedCount: Int,
        skippedCount: Int,
        oldestPendingAgeDays: Int?,
        errorSummary: String? = nil,
        primaryErrorType: AutomationErrorType? = nil,
        scannedRootPaths: [String] = []
    ) {
        self.totalScanned = totalScanned
        self.pendingCount = pendingCount
        self.readyCount = readyCount
        self.organizedCount = organizedCount
        self.skippedCount = skippedCount
        self.oldestPendingAgeDays = oldestPendingAgeDays
        self.errorSummary = errorSummary
        self.primaryErrorType = primaryErrorType
        self.scannedRootPaths = scannedRootPaths
    }
}

extension FileScanProvider {
    func scanFiles(context: ModelContext) async throws -> FileScanResult {
        try await scanFiles(context: context, baseFolders: nil)
    }
}

// Note: Feature flags (.backgroundMonitoring, .autoOrganize, .automationReminders)
// and Log.Category.automation are now defined in their respective source files.
