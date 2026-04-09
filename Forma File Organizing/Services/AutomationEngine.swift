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

    /// Latest preflight summary for the next automation pass.
    var lastPreflightSummary: AutomationPreflightSummary?

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
    private let folderHealthAlertService: FolderHealthAlertService
    private let clock: Clock
    private let policyResolver: () -> AutomationPolicy
    private let fileMonitor: FileMonitoring
    private let watchedFoldersProvider: @MainActor () -> [WatchedFolderDescriptor]
    private let workflowExecution: WorkflowExecutionClient
    private let projectSpaceDetailReader: @MainActor (ModelContext, String) -> ProjectSpaceDetail?
    private let projectPolicyCoordinatorFactory: @MainActor (
        ModelContext,
        ProjectSpaceAutomationService,
        WorkflowExecutionClient
    ) -> ProjectSpaceAutomationCoordinator
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
        folderHealthAlertService: FolderHealthAlertService = FolderHealthAlertService(),
        clock: Clock = SystemClock(),
        policyResolver: (() -> AutomationPolicy)? = nil,
        fileMonitor: FileMonitoring = FileMonitorService(),
        watchedFoldersProvider: (@MainActor () -> [WatchedFolderDescriptor])? = nil,
        workflowExecution: WorkflowExecutionClient = .live,
        projectSpaceDetailReader: (@MainActor (ModelContext, String) -> ProjectSpaceDetail?)? = nil,
        projectPolicyCoordinatorFactory: (@MainActor (
            ModelContext,
            ProjectSpaceAutomationService,
            WorkflowExecutionClient
        ) -> ProjectSpaceAutomationCoordinator)? = nil
    ) {
        self.featureFlags = featureFlags
        self.notificationService = notificationService
        self.folderHealthAlertService = folderHealthAlertService
        self.clock = clock
        self.fileMonitor = fileMonitor
        self.workflowExecution = workflowExecution
        self.projectSpaceDetailReader = projectSpaceDetailReader ?? { context, normalizedProjectLabel in
            FileMetadataFoundationService(modelContext: context)
                .fetchProjectSpaceDetail(for: normalizedProjectLabel)
        }
        self.projectPolicyCoordinatorFactory = projectPolicyCoordinatorFactory ?? { context, automationService, workflowExecution in
            ProjectSpaceAutomationCoordinator(
                modelContext: context,
                metadataAdmissionWriter: FileMetadataFoundationService(modelContext: context),
                automationService: automationService,
                workflowExecution: workflowExecution
            )
        }
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

        if let context = modelContext {
            evaluateFolderHealthAlerts(context: context, sendNotifications: false)
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

        await performAutoOrganize(triggerSource: .manualRefreshInspection)
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
            evaluateFolderHealthAlerts(context: context)

            // Auto-organize if enabled
            if policy.canAutoOrganize {
                await performAutoOrganize(triggerSource: autoOrganizeTriggerSource(for: reason))
            }

            Log.info("AutomationEngine: Scan completed - \(result.totalScanned) files", category: .automation)

        } catch {
            handleScanFailure(error: error)
        }
    }

    private func performAutoOrganize(triggerSource: TrustedAutomationScopeRunTriggerSource) async {
        guard let context = modelContext,
              let provider = scanProvider else {
            return
        }

        let candidates: [FileItem]
        do {
            candidates = try await provider.getAutoOrganizeCandidates(context: context)
        } catch {
            state.lastPreflightSummary = nil
            let errorType = AutomationErrorType.classify(error: error)
            let message = AutomationErrorType.cleanMessage(from: error)
            Log.error("AutomationEngine: \(message)", category: .automation)
            ActivityLoggingService.create(from: context)?.logAutomationError(type: errorType, message: message)
            sendErrorNotification(type: errorType, message: message)
            return
        }

        let scopeResolver = TrustedAutomationScopeResolver(modelContext: context)
        let scopeService = TrustedAutomationScopeService(modelContext: context)
        let projectAutomationService = featureFlags.isEnabled(.projectSpaceAutomationBoard)
            ? ProjectSpaceAutomationService(modelContext: context)
            : nil

        let preflightPlan: ScopedAutomationPreflightPlan
        do {
            preflightPlan = try Self.buildScopedPreflightPlan(
                modelContext: context,
                candidates: candidates,
                confidenceThreshold: policy.mlConfidenceThreshold,
                scopeResolver: scopeResolver,
                projectAutomationService: projectAutomationService,
                projectSpaceDetailReader: projectSpaceDetailReader,
                triggerKind: projectAutomationTriggerKind(for: triggerSource),
                now: clock.now
            )
        } catch {
            let errorType = AutomationErrorType.classify(error: error)
            let message = AutomationErrorType.cleanMessage(from: error)
            Log.error("AutomationEngine: Failed to build scoped auto-organize preflight - \(message)", category: .automation)
            ActivityLoggingService.create(from: context)?.logAutomationError(type: errorType, message: message)
            sendErrorNotification(type: errorType, message: message)
            return
        }

        let preflight = preflightPlan.summary
        state.lastPreflightSummary = preflight
        state.lastRunSuccessCount = 0
        state.lastRunFailedCount = 0
        state.lastRunSkippedCount = preflight.totalSkippedCount

        recordScopedPreflightRuns(
            groups: preflightPlan.trustedScopeGroups,
            triggerSource: triggerSource,
            scopeService: scopeService
        )

        guard !preflight.eligibleFiles.isEmpty else {
            recordHeldScopeRuns(
                groups: preflightPlan.trustedScopeGroups,
                triggerSource: triggerSource,
                scopeService: scopeService
            )

            if let attentionNotification = makeAttentionNotification(
                touchedScopeCount: preflightPlan.trustedScopeGroups.count,
                signals: preflightPlan.attentionSignals
            ) {
                sendTrustedScopeAttention(
                    scopeDisplayName: attentionNotification.scopeDisplayName,
                    groupedScopeCount: attentionNotification.groupedScopeCount,
                    reason: attentionNotification.reason
                )
            }

            Log.info(
                "AutomationEngine: No eligible files for auto-organize (\(preflight.totalSkippedCount) skipped in preflight)",
                category: .automation
            )
            return
        }

        Log.info("AutomationEngine: Auto-organizing \(preflight.eligibleCount) files", category: .automation)

        var totalSuccess = 0
        var totalFailed = 0
        var postPreflightSkippedCount = 0
        var trustedSuccess = 0
        var trustedFailed = 0
        var trustedPostPreflightSkippedCount = 0
        var firstExecutionError: Error?
        var attentionSignals = preflightPlan.attentionSignals
        var trustedPlannedWorkflowNativeNotify = false

        for group in preflightPlan.trustedScopeGroups {
            guard !group.eligibleFiles.isEmpty else {
                continue
            }

            let executionResult = await executeScopedAutoOrganizeGroup(
                group,
                triggerSource: triggerSource,
                context: context
            )

            totalSuccess += executionResult.successCount
            totalFailed += executionResult.failedCount
            postPreflightSkippedCount += executionResult.skippedCount
            trustedSuccess += executionResult.successCount
            trustedFailed += executionResult.failedCount
            trustedPostPreflightSkippedCount += executionResult.skippedCount
            trustedPlannedWorkflowNativeNotify = trustedPlannedWorkflowNativeNotify || executionResult.plannedWorkflowNotify

            if firstExecutionError == nil {
                firstExecutionError = executionResult.error
            }

            if let executionAttentionSignal = group.executionAttentionSignal(for: executionResult.error) {
                attentionSignals.append(executionAttentionSignal)
            }

            guard executionResult.shouldRecordRun else {
                continue
            }

            do {
                try scopeService.recordRun(
                    scopeID: group.scope.id,
                    triggerSource: triggerSource,
                    status: executionResult.status,
                    matchedCount: group.matchedCount,
                    eligibleCount: group.eligibleFiles.count,
                    organizedCount: executionResult.successCount,
                    heldCount: group.heldCount + executionResult.additionalHeldCount,
                    failedCount: executionResult.failedCount,
                    heldBuckets: group.heldBuckets + executionResult.additionalHeldBuckets,
                    summaryText: executionResult.summaryText ?? group.executedSummaryText(
                        successCount: executionResult.successCount,
                        failedCount: executionResult.failedCount
                    ),
                    exampleFileNames: group.exampleFileNames,
                    startedAt: clock.now,
                    endedAt: clock.now
                )
            } catch {
                Log.error("AutomationEngine: Failed to record trusted scope run - \(error.localizedDescription)", category: .automation)
            }
        }

        for group in preflightPlan.projectPolicyGroups {
            guard !group.eligibleFiles.isEmpty else {
                continue
            }

            let executionResult = await executeProjectPolicyAutoOrganizeGroup(
                group,
                triggerSource: triggerSource,
                context: context,
                automationService: projectAutomationService ?? ProjectSpaceAutomationService(modelContext: context)
            )

            totalSuccess += executionResult.successCount
            totalFailed += executionResult.failedCount
            postPreflightSkippedCount += executionResult.skippedCount

            if firstExecutionError == nil {
                firstExecutionError = executionResult.error
            }
        }

        recordHeldScopeRuns(
            groups: preflightPlan.trustedScopeGroups.filter { $0.eligibleFiles.isEmpty },
            triggerSource: triggerSource,
            scopeService: scopeService
        )

        state.lastRunSuccessCount = totalSuccess
        state.lastRunFailedCount = totalFailed
        state.lastRunSkippedCount = preflight.totalSkippedCount + postPreflightSkippedCount

        ActivityLoggingService.create(from: context)?.logAutoOrganizeBatch(
            successCount: totalSuccess,
            failedCount: totalFailed,
            skippedCount: preflight.totalSkippedCount + postPreflightSkippedCount,
            skippedMissingDestination: preflight.skippedMissingDestination,
            skippedPermissionIssues: preflight.skippedPermissionIssues,
            skippedConfidenceThreshold: preflight.skippedConfidenceThreshold,
            skippedExcludedFromAutomation: preflight.skippedExcludedFromAutomation,
            undoAvailable: false
        )

        if trustedSuccess > 0 && !trustedPlannedWorkflowNativeNotify {
            sendAutoOrganizeSummary(
                successCount: trustedSuccess,
                failedCount: trustedFailed,
                skippedCount: preflight.trustedScopeSkippedCount + trustedPostPreflightSkippedCount,
                touchedScopeCount: preflightPlan.trustedScopeGroups.count,
                singleScopeDisplayName: preflightPlan.trustedScopeGroups.count == 1
                    ? preflightPlan.trustedScopeGroups.first?.scope.displayName
                    : nil
            )
        }

        if let attentionNotification = makeAttentionNotification(
            touchedScopeCount: preflightPlan.trustedScopeGroups.count,
            signals: attentionSignals
        ) {
            sendTrustedScopeAttention(
                scopeDisplayName: attentionNotification.scopeDisplayName,
                groupedScopeCount: attentionNotification.groupedScopeCount,
                reason: attentionNotification.reason
            )
        }

        if let firstExecutionError {
            if totalFailed > 0 {
                Log.error("AutomationEngine: Auto-organize had failures - \(firstExecutionError.localizedDescription)", category: .automation)
            } else {
                Log.warning("AutomationEngine: Auto-organize completed with bookkeeping warnings - \(firstExecutionError.localizedDescription)", category: .automation)
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

    private func sendAutoOrganizeSummary(
        successCount: Int,
        failedCount: Int,
        skippedCount: Int,
        touchedScopeCount: Int,
        singleScopeDisplayName: String?
    ) {
        guard policy.notificationsEnabled, canSendNotification() else { return }

        notificationService.notifyAutoOrganizeSummary(
            successCount: successCount,
            failedCount: failedCount,
            skippedCount: skippedCount,
            scopeDisplayName: singleScopeDisplayName,
            groupedScopeCount: touchedScopeCount
        )
        recordNotificationSent()
    }

    private func sendTrustedScopeAttention(
        scopeDisplayName: String?,
        groupedScopeCount: Int,
        reason: String
    ) {
        guard policy.notificationsEnabled, canSendNotification() else { return }

        notificationService.notifyTrustedAutomationScopeAttention(
            scopeDisplayName: scopeDisplayName,
            groupedScopeCount: groupedScopeCount,
            reason: reason
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

    private func evaluateFolderHealthAlerts(context: ModelContext, sendNotifications: Bool = true) {
        let monitoredRootPathsByFolder = BookmarkFolder.alertEligibleRootPaths()
        let evaluation: FolderHealthEvaluation

        do {
            let files = try context.fetch(FetchDescriptor<FileItem>())
            let rules = try context.fetch(FetchDescriptor<Rule>())
            evaluation = folderHealthAlertService.evaluate(
                files: files,
                rules: rules,
                settings: policy.folderHealthAlerts,
                monitoredRootPathsByFolder: monitoredRootPathsByFolder,
                now: clock.now
            )
        } catch {
            Log.error("AutomationEngine: Failed evaluating folder health alerts - \(error.localizedDescription)", category: .automation)
            return
        }

        clearResolvedFolderHealthNotifications(
            configuredFolderTypes: Set(policy.folderHealthAlerts.folderSizeThresholdBytesByFolder.keys),
            activeFolderTypes: Set(evaluation.folderSizeAlerts.map(\.folderType)),
            hasStaleRulesAlert: evaluation.staleRuleAlert != nil
        )

        guard sendNotifications, policy.notificationsEnabled, canSendBacklogReminder() else { return }

        var didSendReminder = false
        for alert in evaluation.folderSizeAlerts where canSendNotification() {
            notificationService.notifyFolderHealthAlert(
                folderType: alert.folderType,
                currentBytes: alert.currentBytes,
                thresholdBytes: alert.thresholdBytes
            )
            recordNotificationSent()
            didSendReminder = true
        }

        if let staleRuleAlert = evaluation.staleRuleAlert, canSendNotification() {
            notificationService.notifyStaleRulesAlert(
                ruleNames: staleRuleAlert.rules.map(\.ruleName),
                thresholdDays: staleRuleAlert.thresholdDays
            )
            recordNotificationSent()
            didSendReminder = true
        }

        if didSendReminder {
            lastBacklogReminderDate = clock.now
        }
    }

    private func clearResolvedFolderHealthNotifications(
        configuredFolderTypes: Set<BookmarkFolder.FolderType>,
        activeFolderTypes: Set<BookmarkFolder.FolderType>,
        hasStaleRulesAlert: Bool
    ) {
        for folderType in configuredFolderTypes where !activeFolderTypes.contains(folderType) {
            notificationService.clearFolderHealthAlert(folderType: folderType)
        }

        if policy.folderHealthAlerts.staleRuleThresholdDays == nil || !hasStaleRulesAlert {
            notificationService.clearStaleRulesAlert()
        }
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

    private func autoOrganizeTriggerSource(for reason: ScanReason) -> TrustedAutomationScopeRunTriggerSource {
        switch reason {
        case .fileSystemEvent:
            return .realtimeAutomationPass
        case .manual:
            return .manualRefreshInspection
        case .appLaunch, .scheduled, .thresholdExceeded:
            return .scheduledAutomationPass
        }
    }

    private func projectAutomationTriggerKind(
        for triggerSource: TrustedAutomationScopeRunTriggerSource
    ) -> ProjectSpaceAutomationTriggerKind {
        switch triggerSource {
        case .promotionPreview, .manualRefreshInspection:
            return .manual
        case .scheduledAutomationPass:
            return .scheduledSweep
        case .realtimeAutomationPass:
            return .folderWatch
        }
    }

    func workflowInvocationContext(
        for triggerSource: TrustedAutomationScopeRunTriggerSource,
        scopeDisplayName: String?
    ) -> WorkflowInvocationContext {
        switch triggerSource {
        case .promotionPreview:
            return .trustedScopeInspection(scopeDisplayName: scopeDisplayName)
        case .scheduledAutomationPass:
            return .trustedScopeScheduled(scopeDisplayName: scopeDisplayName)
        case .realtimeAutomationPass:
            return .trustedScopeRealtime(scopeDisplayName: scopeDisplayName)
        case .manualRefreshInspection:
            return .trustedScopeInspection(scopeDisplayName: scopeDisplayName)
        }
    }

    func workflowInvocationContext(
        for triggerSource: TrustedAutomationScopeRunTriggerSource,
        projectLabel: String,
        policyName: String
    ) -> WorkflowInvocationContext {
        switch triggerSource {
        case .promotionPreview, .manualRefreshInspection:
            return .projectPolicyManual(projectLabel: projectLabel, policyName: policyName)
        case .scheduledAutomationPass:
            return .projectPolicyScheduled(projectLabel: projectLabel, policyName: policyName)
        case .realtimeAutomationPass:
            return .projectPolicyRealtime(projectLabel: projectLabel, policyName: policyName)
        }
    }

    private func recordScopedPreflightRuns(
        groups: [ScopedAutomationGroup],
        triggerSource: TrustedAutomationScopeRunTriggerSource,
        scopeService: TrustedAutomationScopeService
    ) {
        for group in groups {
            do {
                try scopeService.recordRun(
                    scopeID: group.scope.id,
                    triggerSource: triggerSource,
                    status: .simulated,
                    matchedCount: group.matchedCount,
                    eligibleCount: group.eligibleFiles.count,
                    organizedCount: 0,
                    heldCount: group.heldCount,
                    failedCount: 0,
                    heldBuckets: group.heldBuckets,
                    summaryText: group.simulatedSummaryText,
                    exampleFileNames: group.exampleFileNames,
                    startedAt: clock.now,
                    endedAt: clock.now
                )
            } catch {
                Log.error("AutomationEngine: Failed to record trusted scope preflight - \(error.localizedDescription)", category: .automation)
            }
        }
    }

    private func recordHeldScopeRuns(
        groups: [ScopedAutomationGroup],
        triggerSource: TrustedAutomationScopeRunTriggerSource,
        scopeService: TrustedAutomationScopeService
    ) {
        for group in groups where group.heldCount > 0 {
            do {
                try scopeService.recordRun(
                    scopeID: group.scope.id,
                    triggerSource: triggerSource,
                    status: .held,
                    matchedCount: group.matchedCount,
                    eligibleCount: group.eligibleFiles.count,
                    organizedCount: 0,
                    heldCount: group.heldCount,
                    failedCount: 0,
                    heldBuckets: group.heldBuckets,
                    summaryText: group.heldSummaryText,
                    exampleFileNames: group.exampleFileNames,
                    startedAt: clock.now,
                    endedAt: clock.now
                )
            } catch {
                Log.error("AutomationEngine: Failed to record trusted scope hold - \(error.localizedDescription)", category: .automation)
            }
        }
    }

    private func executeScopedAutoOrganizeGroup(
        _ group: ScopedAutomationGroup,
        triggerSource: TrustedAutomationScopeRunTriggerSource,
        context: ModelContext
    ) async -> ScopedAutomationExecutionResult {
        guard let templateID = group.scope.selectedWorkflowTemplateID,
              WorkflowTemplateCatalog.template(for: templateID) != nil else {
            return ScopedAutomationExecutionResult(
                successCount: 0,
                failedCount: 0,
                skippedCount: group.eligibleFiles.count,
                additionalHeldCount: group.eligibleFiles.count,
                additionalHeldBuckets: [
                    .init(bucket: "Workflow template required", count: group.eligibleFiles.count)
                ],
                status: .held,
                error: nil,
                didExecuteWorkflow: false,
                plannedWorkflowNotify: false,
                summaryText: group.configurationRequiredSummaryText
            )
        }

        let plan = workflowExecution.plan(
            templateID,
            group.eligibleFiles,
            workflowInvocationContext(
                for: triggerSource,
                scopeDisplayName: group.scope.displayName
            )
        )
        let plannedWorkflowNotify = plan.definition.stepKinds.contains(.notify)

        do {
            try await workflowExecution.run(plan, group.eligibleFiles, group.scope.id, context)
            return ScopedAutomationExecutionResult(
                successCount: group.eligibleFiles.count,
                failedCount: 0,
                skippedCount: 0,
                additionalHeldCount: 0,
                additionalHeldBuckets: [],
                status: .executed,
                error: nil,
                didExecuteWorkflow: true,
                plannedWorkflowNotify: plannedWorkflowNotify,
                summaryText: nil
            )
        } catch {
            return ScopedAutomationExecutionResult(
                successCount: 0,
                failedCount: group.eligibleFiles.count,
                skippedCount: 0,
                additionalHeldCount: 0,
                additionalHeldBuckets: [],
                status: .failed,
                error: error,
                didExecuteWorkflow: true,
                plannedWorkflowNotify: plannedWorkflowNotify,
                summaryText: nil
            )
        }
    }

    private func executeProjectPolicyAutoOrganizeGroup(
        _ group: ProjectPolicyAutomationGroup,
        triggerSource: TrustedAutomationScopeRunTriggerSource,
        context: ModelContext,
        automationService: ProjectSpaceAutomationService
    ) async -> ProjectPolicyAutomationExecutionResult {
        let coordinator = projectPolicyCoordinatorFactory(
            context,
            automationService,
            workflowExecution
        )

        do {
            let policyName = WorkflowTemplateCatalog.template(for: group.policy.workflowTemplateID)?.displayName
                ?? group.policy.workflowTemplateID
            let runRecord = try await coordinator.executePolicy(
                group.policy,
                detail: group.detail,
                files: group.eligibleFiles,
                triggerKind: group.triggerKind,
                invocationContext: workflowInvocationContext(
                    for: triggerSource,
                    projectLabel: group.detail.projectLabel,
                    policyName: policyName
                ),
                now: clock.now
            )
            let successCountStatuses: Set<ProjectSpaceAutomationRunStatus> = [.succeeded, .completedWithIssues]
            let successCount = successCountStatuses.contains(runRecord.status) ? group.eligibleFiles.count : 0
            let failedCount = runRecord.status == .failed ? group.eligibleFiles.count : 0

            return ProjectPolicyAutomationExecutionResult(
                successCount: successCount,
                failedCount: failedCount,
                skippedCount: 0,
                error: nil,
                plannedWorkflowNotify: projectPolicyPlansWorkflowNotify(group, triggerSource: triggerSource)
            )
        } catch let bookkeepingError as ProjectSpaceAutomationCoordinator.CoordinatorError {
            switch bookkeepingError {
            case let .bookkeepingFailedAfterWorkflowRun(status, _):
                let successCountStatuses: Set<ProjectSpaceAutomationRunStatus> = [.succeeded, .completedWithIssues]
                let successCount = successCountStatuses.contains(status) ? group.eligibleFiles.count : 0
                let failedCount = status == .failed ? group.eligibleFiles.count : 0

                return ProjectPolicyAutomationExecutionResult(
                    successCount: successCount,
                    failedCount: failedCount,
                    skippedCount: 0,
                    error: bookkeepingError,
                    plannedWorkflowNotify: projectPolicyPlansWorkflowNotify(group, triggerSource: triggerSource)
                )
            case .noRunnableFiles:
                return ProjectPolicyAutomationExecutionResult(
                    successCount: 0,
                    failedCount: 0,
                    skippedCount: group.eligibleFiles.count,
                    error: nil,
                    plannedWorkflowNotify: false
                )
            }
        } catch {
            return ProjectPolicyAutomationExecutionResult(
                successCount: 0,
                failedCount: group.eligibleFiles.count,
                skippedCount: 0,
                error: error,
                plannedWorkflowNotify: projectPolicyPlansWorkflowNotify(group, triggerSource: triggerSource)
            )
        }
    }

    private func projectPolicyPlansWorkflowNotify(
        _ group: ProjectPolicyAutomationGroup,
        triggerSource: TrustedAutomationScopeRunTriggerSource
    ) -> Bool {
        let policyName = WorkflowTemplateCatalog.template(for: group.policy.workflowTemplateID)?.displayName
            ?? group.policy.workflowTemplateID
        let invocationContext = workflowInvocationContext(
            for: triggerSource,
            projectLabel: group.detail.projectLabel,
            policyName: policyName
        )
        guard invocationContext.allowsWorkflowNotify else {
            return false
        }
        return WorkflowTemplateCatalog.template(for: group.policy.workflowTemplateID)?.notificationPolicy == .trustedScopeOnly
    }

    private func makeAttentionNotification(
        touchedScopeCount: Int,
        signals: [ScopedAutomationAttentionSignal]
    ) -> ScopedAutomationAttentionNotification? {
        var seenScopeIDs: Set<UUID> = []
        let uniqueSignals = signals.filter { signal in
            seenScopeIDs.insert(signal.scopeID).inserted
        }

        guard !uniqueSignals.isEmpty else {
            return nil
        }

        if touchedScopeCount == 1, let signal = uniqueSignals.first {
            return ScopedAutomationAttentionNotification(
                scopeDisplayName: signal.scopeDisplayName,
                groupedScopeCount: 1,
                reason: signal.reason
            )
        }

        return ScopedAutomationAttentionNotification(
            scopeDisplayName: nil,
            groupedScopeCount: touchedScopeCount,
            reason: "Forma needs permission or destination access again before auto-organize can continue across this pass."
        )
    }
}

// MARK: - Supporting Types

private struct ScopedAutomationExecutionResult {
    let successCount: Int
    let failedCount: Int
    let skippedCount: Int
    let additionalHeldCount: Int
    let additionalHeldBuckets: [TrustedAutomationScopeRunRecord.HeldBucket]
    let status: TrustedAutomationScopeRunStatus
    let error: Error?
    let didExecuteWorkflow: Bool
    let plannedWorkflowNotify: Bool
    let summaryText: String?

    var shouldRecordRun: Bool {
        didExecuteWorkflow || additionalHeldCount > 0 || failedCount > 0
    }
}

private struct ProjectPolicyAutomationExecutionResult {
    let successCount: Int
    let failedCount: Int
    let skippedCount: Int
    let error: Error?
    let plannedWorkflowNotify: Bool
}

private struct ScopedAutomationPreflightPlan {
    let summary: AutomationPreflightSummary
    let trustedScopeGroups: [ScopedAutomationGroup]
    let projectPolicyGroups: [ProjectPolicyAutomationGroup]

    var attentionSignals: [ScopedAutomationAttentionSignal] {
        trustedScopeGroups.compactMap { group in
            guard group.shouldSurfaceAttentionNotification else {
                return nil
            }

            return ScopedAutomationAttentionSignal(
                scopeID: group.scope.id,
                scopeDisplayName: group.scope.displayName,
                reason: group.attentionNotificationReason
            )
        }
    }
}

private struct ScopedAutomationAttentionSignal {
    let scopeID: UUID
    let scopeDisplayName: String
    let reason: String
}

private struct ScopedAutomationAttentionNotification {
    let scopeDisplayName: String?
    let groupedScopeCount: Int
    let reason: String
}

private struct ScopedAutomationGroup {
    let scope: TrustedAutomationScope
    var matchedCount: Int = 0
    var eligibleFiles: [FileItem] = []
    var skippedMissingDestination: Int = 0
    var skippedPermissionIssues: Int = 0
    var skippedConfidenceThreshold: Int = 0
    var skippedExcludedFromAutomation: Int = 0
    var exampleFileNames: [String] = []

    var heldCount: Int {
        skippedMissingDestination +
        skippedPermissionIssues +
        skippedConfidenceThreshold +
        skippedExcludedFromAutomation
    }

    var heldBuckets: [TrustedAutomationScopeRunRecord.HeldBucket] {
        var buckets: [TrustedAutomationScopeRunRecord.HeldBucket] = []
        if skippedMissingDestination > 0 {
            buckets.append(.init(bucket: "Missing destination", count: skippedMissingDestination))
        }
        if skippedPermissionIssues > 0 {
            buckets.append(.init(bucket: "Permission or destination issue", count: skippedPermissionIssues))
        }
        if skippedConfidenceThreshold > 0 {
            buckets.append(.init(bucket: "Below confidence threshold", count: skippedConfidenceThreshold))
        }
        if skippedExcludedFromAutomation > 0 {
            buckets.append(.init(bucket: "Excluded from automation", count: skippedExcludedFromAutomation))
        }
        return buckets
    }

    var shouldSurfaceAttentionNotification: Bool {
        skippedMissingDestination > 0 || skippedPermissionIssues > 0
    }

    var attentionNotificationReason: String {
        if skippedPermissionIssues > 0 {
            return "Forma needs permission or destination access again before the \(scope.displayName) trusted scope can keep organizing automatically"
        }
        return "Forma needs a valid destination again before the \(scope.displayName) trusted scope can keep organizing automatically"
    }

    func executionAttentionSignal(for error: Error?) -> ScopedAutomationAttentionSignal? {
        guard let error else {
            return nil
        }

        switch AutomationErrorType.classify(error: error) {
        case .permissionDenied, .bookmarkInvalid:
            return ScopedAutomationAttentionSignal(
                scopeID: scope.id,
                scopeDisplayName: scope.displayName,
                reason: "Forma needs permission or destination access again before the \(scope.displayName) trusted scope can keep organizing automatically"
            )
        case .destinationInaccessible:
            return ScopedAutomationAttentionSignal(
                scopeID: scope.id,
                scopeDisplayName: scope.displayName,
                reason: "Forma needs a valid destination again before the \(scope.displayName) trusted scope can keep organizing automatically"
            )
        case .scanFailed:
            return nil
        }
    }

    var simulatedSummaryText: String {
        if heldCount > 0 {
            return "Preview matched \(matchedCount) file(s); \(heldCount) would be held."
        }
        return "Preview matched \(matchedCount) file(s) for the \(scope.displayName) trusted scope."
    }

    var heldSummaryText: String {
        if let leadBucket = heldBuckets.first {
            return "\(heldCount) file(s) were held for \(scope.displayName). \(leadBucket.bucket.capitalized): \(leadBucket.count)."
        }
        return "\(heldCount) file(s) were held for \(scope.displayName)."
    }

    var configurationRequiredSummaryText: String {
        "\(eligibleFiles.count) file(s) matched \(scope.displayName) but need a workflow template before automatic runs can continue."
    }

    func executedSummaryText(successCount: Int, failedCount: Int) -> String {
        let leadSentence: String
        if successCount > 0 {
            leadSentence = "Organized \(successCount) file(s) in the \(scope.displayName) trusted scope"
        } else if failedCount > 0 {
            leadSentence = "\(failedCount) file(s) failed in the \(scope.displayName) trusted scope"
        } else {
            leadSentence = "No files were organized in the \(scope.displayName) trusted scope"
        }

        var sentences = [leadSentence]
        if heldCount > 0 {
            sentences.append("\(heldCount) file(s) remained held")
        }
        if failedCount > 0 {
            sentences.append("\(failedCount) file(s) failed")
        }
        return sentences.joined(separator: ". ").terminatedSentence()
    }

    mutating func appendExampleName(_ name: String) {
        guard exampleFileNames.count < 3 else { return }
        exampleFileNames.append(name)
    }
}

private struct ProjectPolicyAutomationGroup {
    let policy: ProjectSpaceAutomationPolicy
    let detail: ProjectSpaceDetail
    let triggerKind: ProjectSpaceAutomationTriggerKind
    var matchedCount: Int = 0
    var eligibleFiles: [FileItem] = []
    var skippedMissingDestination: Int = 0
    var skippedPermissionIssues: Int = 0
    var skippedConfidenceThreshold: Int = 0
    var skippedExcludedFromAutomation: Int = 0

    mutating func absorb(_ disposition: AutomationPreflightDisposition, file: FileItem) {
        matchedCount += 1
        switch disposition {
        case .eligible:
            eligibleFiles.append(file)
        case .missingDestination:
            skippedMissingDestination += 1
        case .permissionIssues:
            skippedPermissionIssues += 1
        case .confidenceThreshold:
            skippedConfidenceThreshold += 1
        case .excludedFromAutomation:
            skippedExcludedFromAutomation += 1
        }
    }
}

private struct ProjectPolicyResolvedCandidate {
    let resolvedPolicy: ProjectSpaceAutomationResolvedPolicy
    let detail: ProjectSpaceDetail
    let decision: ProjectSpaceAdmissionDecision
}

private struct ProjectPolicyOwnershipCandidate {
    let resolvedPolicy: ProjectSpaceAutomationResolvedPolicy?
    let detail: ProjectSpaceDetail?
    let decision: ProjectSpaceAdmissionDecision?
    let isAmbiguous: Bool
}

/// Reason for triggering a scan.
enum ScanReason: String, Sendable {
    case appLaunch = "app_launch"
    case scheduled = "scheduled"
    case manual = "manual"
    case fileSystemEvent = "file_system_event"
    case thresholdExceeded = "threshold_exceeded"
}

struct AutomationPreflightSummary {
    let eligibleFiles: [FileItem]
    let eligibleCount: Int
    let skippedMissingDestination: Int
    let skippedPermissionIssues: Int
    let skippedConfidenceThreshold: Int
    let skippedExcludedFromAutomation: Int
    let trustedScopeSkippedCount: Int
    let exampleFileNames: [String]

    var totalSkippedCount: Int {
        skippedMissingDestination +
        skippedPermissionIssues +
        skippedConfidenceThreshold +
        skippedExcludedFromAutomation
    }
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

    /// Returns pending/ready files that should be classified for automation preflight.
    func getAutoOrganizeCandidates(context: ModelContext) async throws -> [FileItem]

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
    func getAutoOrganizeCandidates(context: ModelContext) async throws -> [FileItem] {
        let pendingRaw = FileItem.OrganizationStatus.pending.rawValue
        let readyRaw = FileItem.OrganizationStatus.ready.rawValue
        let descriptor = FetchDescriptor<FileItem>(
            predicate: #Predicate<FileItem> { file in
                file.statusRaw == pendingRaw || file.statusRaw == readyRaw
            }
        )
        return try context.fetch(descriptor)
    }

    func scanFiles(context: ModelContext) async throws -> FileScanResult {
        try await scanFiles(context: context, baseFolders: nil)
    }
}

private enum AutomationPreflightDisposition {
    case eligible
    case missingDestination
    case permissionIssues
    case confidenceThreshold
    case excludedFromAutomation
}

extension AutomationEngine {
    @MainActor
    private static func buildScopedPreflightPlan(
        modelContext: ModelContext,
        candidates: [FileItem],
        confidenceThreshold: Double,
        scopeResolver: TrustedAutomationScopeResolver,
        projectAutomationService: ProjectSpaceAutomationService?,
        projectSpaceDetailReader: @MainActor (ModelContext, String) -> ProjectSpaceDetail?,
        triggerKind: ProjectSpaceAutomationTriggerKind,
        now: Date
    ) throws -> ScopedAutomationPreflightPlan {
        let activeScopes = try scopeResolver.activeScopes()
        let projectPolicies = projectAutomationService?.policies(
            matching: triggerKind,
            states: [.active]
        ) ?? []
        let projectDetailsByLabel: [String: ProjectSpaceDetail] = Dictionary(uniqueKeysWithValues: projectPolicies.compactMap { resolvedPolicy in
            guard let detail = projectSpaceDetailReader(modelContext, resolvedPolicy.normalizedProjectLabel) else {
                return nil
            }
            return (resolvedPolicy.normalizedProjectLabel, detail)
        })
        var eligibleFiles: [FileItem] = []
        var skippedMissingDestination = 0
        var skippedPermissionIssues = 0
        var skippedConfidenceThreshold = 0
        var skippedExcludedFromAutomation = 0
        var trustedScopeSkippedCount = 0
        var destinationValidationCache: [Data: Bool] = [:]
        var groupsByScopeID: [UUID: ScopedAutomationGroup] = [:]
        var orderedScopeIDs: [UUID] = []
        var projectGroupsByPolicyID: [UUID: ProjectPolicyAutomationGroup] = [:]
        var orderedProjectPolicyIDs: [UUID] = []
        let ownershipResolver = ProjectAutomationOwnershipResolver()
        let admissionResolver = ProjectSpaceAdmissionResolver()
        let recommendationService = ProjectSpaceAutomationRecommendationService()

        for file in candidates {
            let trustedScope = try scopeResolver.resolveMatch(
                for: file,
                destination: file.destination,
                within: activeScopes
            )
            let projectCandidate = resolveProjectPolicyCandidate(
                for: file,
                resolvedPolicies: projectPolicies,
                detailsByLabel: projectDetailsByLabel,
                now: now,
                admissionResolver: admissionResolver,
                recommendationService: recommendationService
            )

            let ownerDecision: ProjectAutomationOwnerDecision
            if projectCandidate.isAmbiguous {
                ownerDecision = trustedScope.map {
                    .trustedScope(
                        ProjectAutomationTrustedScopeOwner(
                            id: $0.id,
                            scopeType: $0.scopeType,
                            displayName: $0.displayName,
                            status: $0.status
                        )
                    )
                } ?? .none
            } else {
                ownerDecision = ownershipResolver.resolveOwner(
                    projectDecision: projectCandidate.decision,
                    trustedScope: trustedScope
                )
            }

            let disposition = preflightDisposition(
                for: file,
                confidenceThreshold: confidenceThreshold,
                validationCache: &destinationValidationCache
            )

            switch ownerDecision {
            case .trustedScope(let owner):
                guard let scope = activeScopes.first(where: { $0.id == owner.id }) else {
                    skippedExcludedFromAutomation += 1
                    continue
                }

                if groupsByScopeID[scope.id] == nil {
                    groupsByScopeID[scope.id] = ScopedAutomationGroup(scope: scope)
                    orderedScopeIDs.append(scope.id)
                }

                var group = groupsByScopeID[scope.id] ?? ScopedAutomationGroup(scope: scope)
                group.matchedCount += 1
                group.appendExampleName(file.name)

                switch disposition {
                case .eligible:
                    eligibleFiles.append(file)
                    group.eligibleFiles.append(file)
                case .missingDestination:
                    skippedMissingDestination += 1
                    trustedScopeSkippedCount += 1
                    group.skippedMissingDestination += 1
                case .permissionIssues:
                    skippedPermissionIssues += 1
                    trustedScopeSkippedCount += 1
                    group.skippedPermissionIssues += 1
                case .confidenceThreshold:
                    skippedConfidenceThreshold += 1
                    trustedScopeSkippedCount += 1
                    group.skippedConfidenceThreshold += 1
                case .excludedFromAutomation:
                    skippedExcludedFromAutomation += 1
                    trustedScopeSkippedCount += 1
                    group.skippedExcludedFromAutomation += 1
                }

                groupsByScopeID[scope.id] = group

            case .projectPolicy:
                guard let resolvedPolicy = projectCandidate.resolvedPolicy,
                      let detail = projectCandidate.detail else {
                    skippedExcludedFromAutomation += 1
                    continue
                }
                if projectGroupsByPolicyID[resolvedPolicy.policy.id] == nil {
                    projectGroupsByPolicyID[resolvedPolicy.policy.id] = ProjectPolicyAutomationGroup(
                        policy: resolvedPolicy.policy,
                        detail: detail,
                        triggerKind: triggerKind
                    )
                    orderedProjectPolicyIDs.append(resolvedPolicy.policy.id)
                }

                var group = projectGroupsByPolicyID[resolvedPolicy.policy.id] ?? ProjectPolicyAutomationGroup(
                    policy: resolvedPolicy.policy,
                    detail: detail,
                    triggerKind: triggerKind
                )
                group.absorb(disposition, file: file)
                switch disposition {
                case .eligible:
                    eligibleFiles.append(file)
                case .missingDestination:
                    skippedMissingDestination += 1
                case .permissionIssues:
                    skippedPermissionIssues += 1
                case .confidenceThreshold:
                    skippedConfidenceThreshold += 1
                case .excludedFromAutomation:
                    skippedExcludedFromAutomation += 1
                }
                projectGroupsByPolicyID[resolvedPolicy.policy.id] = group

            case .none:
                skippedExcludedFromAutomation += 1
            }
        }

        return ScopedAutomationPreflightPlan(
            summary: AutomationPreflightSummary(
                eligibleFiles: eligibleFiles,
                eligibleCount: eligibleFiles.count,
                skippedMissingDestination: skippedMissingDestination,
                skippedPermissionIssues: skippedPermissionIssues,
                skippedConfidenceThreshold: skippedConfidenceThreshold,
                skippedExcludedFromAutomation: skippedExcludedFromAutomation,
                trustedScopeSkippedCount: trustedScopeSkippedCount,
                exampleFileNames: Array(eligibleFiles.prefix(3).map(\.name))
            ),
            trustedScopeGroups: orderedScopeIDs.compactMap { groupsByScopeID[$0] },
            projectPolicyGroups: orderedProjectPolicyIDs.compactMap { projectGroupsByPolicyID[$0] }
        )
    }

    static func buildPreflightSummary(
        candidates: [FileItem],
        confidenceThreshold: Double
    ) -> AutomationPreflightSummary {
        var eligibleFiles: [FileItem] = []
        var skippedMissingDestination = 0
        var skippedPermissionIssues = 0
        var skippedConfidenceThreshold = 0
        var skippedExcludedFromAutomation = 0
        var destinationValidationCache: [Data: Bool] = [:]

        for file in candidates {
            switch preflightDisposition(
                for: file,
                confidenceThreshold: confidenceThreshold,
                validationCache: &destinationValidationCache
            ) {
            case .eligible:
                eligibleFiles.append(file)
            case .missingDestination:
                skippedMissingDestination += 1
            case .permissionIssues:
                skippedPermissionIssues += 1
            case .confidenceThreshold:
                skippedConfidenceThreshold += 1
            case .excludedFromAutomation:
                skippedExcludedFromAutomation += 1
            }
        }

        return AutomationPreflightSummary(
            eligibleFiles: eligibleFiles,
            eligibleCount: eligibleFiles.count,
            skippedMissingDestination: skippedMissingDestination,
            skippedPermissionIssues: skippedPermissionIssues,
            skippedConfidenceThreshold: skippedConfidenceThreshold,
            skippedExcludedFromAutomation: skippedExcludedFromAutomation,
            trustedScopeSkippedCount: 0,
            exampleFileNames: Array(eligibleFiles.prefix(3).map(\.name))
        )
    }

    private static func resolveProjectPolicyCandidate(
        for file: FileItem,
        resolvedPolicies: [ProjectSpaceAutomationResolvedPolicy],
        detailsByLabel: [String: ProjectSpaceDetail],
        now: Date,
        admissionResolver: ProjectSpaceAdmissionResolver,
        recommendationService: ProjectSpaceAutomationRecommendationService
    ) -> ProjectPolicyOwnershipCandidate {
        let explicitCandidates = resolvedPolicies.compactMap { resolvedPolicy -> ProjectPolicyResolvedCandidate? in
            guard let detail = detailsByLabel[resolvedPolicy.normalizedProjectLabel],
                  let decision = projectAdmissionDecision(
                    for: file,
                    detail: detail,
                    now: now,
                    admissionResolver: admissionResolver,
                    recommendationService: recommendationService
                  ) else {
                return nil
            }

            switch decision {
            case .existingMember, .strongConfirmed:
                return ProjectPolicyResolvedCandidate(
                    resolvedPolicy: resolvedPolicy,
                    detail: detail,
                    decision: decision
                )
            case .insufficient:
                return nil
            }
        }

        guard !explicitCandidates.isEmpty else {
            return ProjectPolicyOwnershipCandidate(
                resolvedPolicy: nil,
                detail: nil,
                decision: nil,
                isAmbiguous: false
            )
        }

        guard explicitCandidates.count == 1 else {
            return ProjectPolicyOwnershipCandidate(
                resolvedPolicy: nil,
                detail: nil,
                decision: nil,
                isAmbiguous: true
            )
        }

        let explicitCandidate = explicitCandidates[0]
        return ProjectPolicyOwnershipCandidate(
            resolvedPolicy: explicitCandidate.resolvedPolicy,
            detail: explicitCandidate.detail,
            decision: explicitCandidate.decision,
            isAmbiguous: false
        )
    }

    private static func projectAdmissionDecision(
        for file: FileItem,
        detail: ProjectSpaceDetail,
        now: Date,
        admissionResolver: ProjectSpaceAdmissionResolver,
        recommendationService: ProjectSpaceAutomationRecommendationService
    ) -> ProjectSpaceAdmissionDecision? {
        let standardizedPath = URL(fileURLWithPath: file.path).standardizedFileURL.path
        let matchingRows = detail.files.filter { row in
            URL(fileURLWithPath: row.normalizedPath).standardizedFileURL.path == standardizedPath
        }
        guard let fileRow = preferredAdmissionRow(from: matchingRows, detail: detail, now: now) else {
            return nil
        }

        let dominantDestinationProjectLabel: String? = {
            guard let dominantDestination = recommendationService.dominantDestination(for: detail, now: now),
                  normalized(dominantDestination.destinationDisplayName) == normalized(detail.projectLabel) else {
                return nil
            }
            return detail.projectLabel
        }()

        let evidence = ProjectSpaceAdmissionEvidence(
            existingProjectAssociation: fileRow.projectAssociation,
            dominantDestinationProjectLabel: dominantDestinationProjectLabel,
            dominantDestinationIsGenericHint: false,
            sourceFolderProjectLabel: normalized(fileRow.sourceFolderHint) == normalized(detail.projectLabel)
                ? detail.projectLabel
                : nil,
            relatedFileProjectLabel: relatedFileProjectLabel(for: fileRow, in: detail)
        )

        return admissionResolver.resolveAdmission(
            projectLabel: detail.projectLabel,
            evidence: evidence
        )
    }

    private static func preferredAdmissionRow(
        from rows: [ProjectSpaceFileRow],
        detail: ProjectSpaceDetail,
        now: Date
    ) -> ProjectSpaceFileRow? {
        rows.max { lhs, rhs in
            admissionPreference(for: lhs, detail: detail, now: now) <
                admissionPreference(for: rhs, detail: detail, now: now)
        }
    }

    private static func admissionPreference(
        for fileRow: ProjectSpaceFileRow,
        detail: ProjectSpaceDetail,
        now: Date
    ) -> (Int, Date, String) {
        let rank: Int
        let normalizedProjectLabel = normalized(detail.projectLabel)
        let normalizedAssociation = normalized(fileRow.projectAssociation)
        switch normalizedAssociation {
        case normalizedProjectLabel:
            rank = 2
        case nil:
            rank = 1
        default:
            rank = 0
        }
        return (rank, fileRow.lastActivityAt, fileRow.canonicalIdentity)
    }

    private static func relatedFileProjectLabel(
        for fileRow: ProjectSpaceFileRow,
        in detail: ProjectSpaceDetail
    ) -> String? {
        guard let sourceFolderHint = normalized(fileRow.sourceFolderHint) else {
            return nil
        }

        return detail.files.first(where: { row in
            row.canonicalIdentity != fileRow.canonicalIdentity &&
            normalized(row.sourceFolderHint) == sourceFolderHint &&
            normalized(row.projectAssociation) == normalized(detail.projectLabel)
        }).flatMap { _ in detail.projectLabel }
    }

    private static func normalized(_ value: String?) -> String? {
        FileMetadataRecord.normalizedOptionalText(value)
    }

    private static func preflightDisposition(
        for file: FileItem,
        confidenceThreshold: Double,
        validationCache: inout [Data: Bool]
    ) -> AutomationPreflightDisposition {
        guard let destination = file.destination else {
            return .missingDestination
        }

        let bookmarkData: Data?
        switch destination {
        case .folder(let bookmark, _):
            bookmarkData = bookmark
        case .trash:
            bookmarkData = nil
        }

        let isDestinationUsable: Bool
        if let bookmarkData, let cached = validationCache[bookmarkData] {
            isDestinationUsable = cached
        } else {
            let result = destination.validate().isUsable
            if let bookmarkData {
                validationCache[bookmarkData] = result
            }
            isDestinationUsable = result
        }

        guard isDestinationUsable else {
            return .permissionIssues
        }

        if let confidence = file.confidenceScore, confidence < confidenceThreshold {
            return .confidenceThreshold
        }

        if file.matchedRuleID != nil,
           let confidence = file.confidenceScore,
           confidence < FormaConfig.Automation.mlRuleConfidenceMinimum {
            return .confidenceThreshold
        }

        if let folderType = file.location.bookmarkFolderType {
            let folder = BookmarkFolder(folderType: folderType)
            if folder.isExcludedFromAutomation {
                return .excludedFromAutomation
            }
        }

        return .eligible
    }
}

// Note: Feature flags (.backgroundMonitoring, .autoOrganize, .automationReminders)
// and Log.Category.automation are now defined in their respective source files.
