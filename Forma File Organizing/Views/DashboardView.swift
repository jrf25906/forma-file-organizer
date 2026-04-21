import SwiftUI
import SwiftData
import AppKit

struct DashboardSplitLayoutConfiguration {
    enum Arrangement: String {
        case sidebarAndContent
        case sidebarAndRightPanel
        case sidebarContentAndInspector
    }

    let isInspectorVisible: Bool
    let showsAnalyticsAsPrimaryDetail: Bool

    var arrangement: Arrangement {
        if showsAnalyticsAsPrimaryDetail {
            return .sidebarAndRightPanel
        }

        if isInspectorVisible {
            return .sidebarContentAndInspector
        }

        return .sidebarAndContent
    }

    var usesThreeColumnLayout: Bool {
        arrangement == .sidebarContentAndInspector
    }

    var mode: String {
        usesThreeColumnLayout ? "threeColumn" : "twoColumn"
    }
}

struct DashboardView: View {
    @StateObject private var nav = NavigationViewModel()
    @EnvironmentObject private var dashboardViewModel: DashboardViewModel
    @EnvironmentObject private var panelStateManager: PanelStateManager
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue
    @AppStorage("autoScanOnLaunch") private var autoScanOnLaunch = true
    @State private var scanTask: Task<Void, Never>?
    @State private var shouldFocusSearch = false
    @State private var showKeyboardHelp = false
    @State private var tourState = GuidedTourState()

    private enum DebugFlags {
        #if DEBUG
        static let disableGuidedTourOverlay = CommandLine.arguments.contains("--debug-disable-guided-tour-overlay")
        #else
        static let disableGuidedTourOverlay = false
        #endif
    }

    private var shouldRunPerfSignpostHarness: Bool {
        #if DEBUG
        PerformanceHarnessConfiguration.isEnabled
        #else
        false
        #endif
    }

    // MARK: - Extracted Views (helps compiler type-checking)

    @ViewBuilder
    private var ruleEditorOverlay: some View {
        if let draftSession = nav.ruleDraftSession, draftSession.presentation == .modal {
            // Dimmed background overlay
            Color.formaObsidian.opacity(Color.FormaOpacity.overlay)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        dismissRuleDraft()
                    }
                }
                .transition(.opacity)
                .zIndex(99)

            // Centered modal container
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    RuleEditorView(
                        rule: draftSession.editingRule,
                        fileContext: draftSession.fileContext,
                        suggestedNaturalLanguageText: draftSession.suggestedNaturalLanguageText,
                        onDismiss: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                dismissRuleDraft()
                            }
                        }
                    )
                    .accessibilityIdentifier("ruleEditorView")
                    Spacer()
                }
                Spacer()
            }
            .transition(.scale(scale: 0.95).combined(with: .opacity))
            .zIndex(100)
        }
    }

    private func dismissRuleDraft() {
        let returnTarget = nav.ruleDraftSession?.returnTarget ?? .none
        nav.discardRuleDraft()
        dashboardViewModel.restorePanel(afterRuleDraftReturnTarget: returnTarget)
    }

    /// Hidden command bridge for ⌘F so the search focus shortcut does not affect toolbar layout.
    private var searchShortcutBridge: some View {
        Button(action: focusSearch) {
            EmptyView()
        }
        .buttonStyle(.plain)
        .keyboardShortcut("f", modifiers: .command)
        .frame(width: 0, height: 0)
        .opacity(0.001)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    /// ⌘F action: focuses the toolbar search field
    private func focusSearch() {
        shouldFocusSearch = true
    }

    @MainActor
    private func scheduleStartupFollowUp(_ followUp: DashboardStartupFollowUp) {
        guard followUp == .deferredInitialAutoScan else { return }

        scanTask?.cancel()
        scanTask = Task { @MainActor in
            StartupTelemetry.mark("startup_auto_scan_waiting_for_window")
            await waitForVisibleWindow()
            guard !Task.isCancelled else { return }
            StartupTelemetry.mark("startup_auto_scan_window_visible")
            await dashboardViewModel.runDeferredStartupAutoScan(context: modelContext)
            scanTask = nil
        }
    }

    @MainActor
    private func waitForVisibleWindow(timeout: Duration = .seconds(2)) async {
        let clock = ContinuousClock()
        let start = clock.now

        while !Task.isCancelled {
            if NSApp.windows.contains(where: { $0.isVisible }) {
                return
            }

            if clock.now - start >= timeout {
                return
            }

            try? await Task.sleep(for: .milliseconds(25))
        }
    }

    private var splitLayoutMode: String {
        splitLayoutConfiguration.mode
    }

    private var showsAnalyticsAsPrimaryDetail: Bool {
        if case .analytics = panelStateManager.rightPanelMode {
            return true
        }
        return false
    }

    private var splitLayoutArrangement: String {
        splitLayoutConfiguration.arrangement.rawValue
    }

    private var inspectorVisibilityState: String {
        dashboardViewModel.isRightPanelVisible ? "visible" : "hidden"
    }

    private var splitLayoutConfiguration: DashboardSplitLayoutConfiguration {
        DashboardSplitLayoutConfiguration(
            isInspectorVisible: dashboardViewModel.isRightPanelVisible,
            showsAnalyticsAsPrimaryDetail: showsAnalyticsAsPrimaryDetail
        )
    }

    private var usesThreeColumnLayout: Bool {
        splitLayoutConfiguration.usesThreeColumnLayout
    }

    private var shouldCollectGuidedTourFrames: Bool {
        GuidedTourMeasurementPolicy.shouldCollectFrames(
            isTourActive: tourState.isActive,
            hasSeenTour: tourState.hasSeenTour
        )
    }

    @ViewBuilder
    private var sidebarColumn: some View {
        SidebarView(
            shouldFocusSearch: $shouldFocusSearch,
            showKeyboardHelp: $showKeyboardHelp
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationSplitViewColumnWidth(
            min: FormaSpacing.Column.sidebarMin,
            ideal: FormaSpacing.Column.sidebarIdeal,
            max: FormaSpacing.Column.sidebarMax
        )
    }

    @ViewBuilder
    private var centerColumn: some View {
        GeometryReader { proxy in
            centerContent(availableWidth: proxy.size.width)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationSplitViewColumnWidth(
            min: FormaSpacing.Column.centerMin,
            ideal: FormaSpacing.Column.centerIdeal
        )
    }

    @ViewBuilder
    private var twoColumnDetailColumn: some View {
        if showsAnalyticsAsPrimaryDetail {
            rightPanelColumn
        } else {
            centerColumn
        }
    }

    private var analyticsSplitViewLayout: some View {
        NavigationSplitView {
            sidebarColumn
        } detail: {
            twoColumnDetailColumn
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var contentSplitViewLayout: some View {
        NavigationSplitView {
            sidebarColumn
        } detail: {
            centerColumn
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var inspectorSplitViewLayout: some View {
        NavigationSplitView {
            sidebarColumn
        } content: {
            centerColumn
        } detail: {
            rightPanelColumn
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private var splitViewLayout: some View {
        if showsAnalyticsAsPrimaryDetail {
            analyticsSplitViewLayout
        } else if dashboardViewModel.isRightPanelVisible {
            inspectorSplitViewLayout
        } else {
            contentSplitViewLayout
        }
    }

    @ViewBuilder
    private var rightPanelColumn: some View {
        RightPanelView()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationSplitViewColumnWidth(
                min: FormaSpacing.Column.rightPanelMin,
                ideal: FormaSpacing.Column.rightPanelIdeal,
                max: FormaSpacing.Column.rightPanelMax
            )
    }

    @ViewBuilder
    private func centerContent(availableWidth: CGFloat) -> some View {
        MainContentView(
            selection: nav.selection,
            searchText: nav.searchText,
            activeChips: nav.activeChips,
            availableWidth: availableWidth,
            showKeyboardHelp: $showKeyboardHelp
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $nav.path) {
            ToastHost(panelStateManager: panelStateManager) {
                ZStack {
                    PrimaryBackgroundView()

                    splitViewLayout
                    .disabled(nav.isShowingRuleEditor || (tourState.isActive && !DebugFlags.disableGuidedTourOverlay))

                    Color.clear
                        .frame(width: 1, height: 1)
                        .accessibilityIdentifier("dashboardSplitLayoutProbe")
                        .accessibilityLabel(splitLayoutMode)
                        .accessibilityValue(splitLayoutMode)
                        .allowsHitTesting(false)

                    Color.clear
                        .frame(width: 1, height: 1)
                        .accessibilityIdentifier("dashboardSplitArrangementProbe")
                        .accessibilityLabel(splitLayoutArrangement)
                        .accessibilityValue(splitLayoutArrangement)
                        .allowsHitTesting(false)

                    Color.clear
                        .frame(width: 1, height: 1)
                        .accessibilityIdentifier("dashboardInspectorVisibilityProbe")
                        .accessibilityLabel(inspectorVisibilityState)
                        .accessibilityValue(inspectorVisibilityState)
                        .allowsHitTesting(false)

                    // Rule Editor Overlay - Centered Modal
                    ruleEditorOverlay

                    // Guided Tour Overlay
                    if !DebugFlags.disableGuidedTourOverlay {
                        GuidedTourOverlay(tourState: tourState)
                    }
                }
            }
            .environment(\.guidedTourMeasurementsEnabled, shouldCollectGuidedTourFrames)
            .onPreferenceChange(GuidedTourRegionPreferenceKey.self) { frames in
                guard shouldCollectGuidedTourFrames else { return }
                for regionFrame in frames {
                    if tourState.regionFrames[regionFrame.region] != regionFrame.frame {
                        tourState.regionFrames[regionFrame.region] = regionFrame.frame
                    }
                }
            }
            .background(Color.formaBackground)
            .frame(
                minWidth: FormaSpacing.Window.minWidth,
                idealWidth: FormaSpacing.Window.preferredWidth,
                minHeight: FormaSpacing.Window.minHeight
            )
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .category(let cat):
                    FullListView(category: cat)
                case .allFiles:
                    FullListView(category: nil)
                case .fileDetail(_):
                    Text("File Detail")
                }
            }
            .overlay(alignment: .topLeading) {
                searchShortcutBridge
            }
        }
        .environmentObject(nav)
        .preferredColorScheme(AppearanceMode(rawValue: appearanceMode)?.colorScheme)
        .task {
            StartupTelemetry.mark("dashboard_task_begin autoScanOnLaunch=\(autoScanOnLaunch)")
            dashboardViewModel.prepareStartupContext(modelContext)
            if shouldRunPerfSignpostHarness {
                StartupTelemetry.mark("dashboard_task_end perf_harness")
                return
            }
            // In UI tests, we rely on DashboardViewModel mock data and skip
            // real file system scanning for determinism.
            if CommandLine.arguments.contains("--uitesting") {
                StartupTelemetry.mark("dashboard_task_end ui_testing")
                return
            }
            let followUp = await dashboardViewModel.handleDashboardStartup(
                context: modelContext,
                autoScanOnLaunch: autoScanOnLaunch
            )
            await MainActor.run {
                scheduleStartupFollowUp(followUp)
            }
            StartupTelemetry.mark("dashboard_task_end")
        }
        .sheet(isPresented: $dashboardViewModel.showOnboarding) {
            OnboardingFlowView()
                .environmentObject(dashboardViewModel)
        }
        .onChange(of: dashboardViewModel.showOnboarding) { wasShowingOnboarding, isShowingOnboarding in
            // Trigger scan when onboarding completes (was showing, now dismissed)
            if wasShowingOnboarding && !isShowingOnboarding {
                Task {
                    let followUp = await dashboardViewModel.handleDashboardStartup(
                        context: modelContext,
                        autoScanOnLaunch: autoScanOnLaunch
                    )
                    await MainActor.run {
                        scheduleStartupFollowUp(followUp)
                    }
                }
                // Show guided tour after onboarding with delay for frames to populate
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(800))
                    tourState.checkShouldShowTour()
                }
            }
        }
        .onDisappear {
            scanTask?.cancel()
            scanTask = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .replayGuidedTour)) { _ in
            tourState.replayTour()
        }
        .onReceive(NotificationCenter.default.publisher(for: .automationScanDidPersist)) { notification in
            let scannedPaths = notification.userInfo?[AutomationScanNotificationUserInfo.scannedPaths] as? [String] ?? []
            let updatedPaths = notification.userInfo?[AutomationScanNotificationUserInfo.updatedPaths] as? [String] ?? scannedPaths
            let removedPaths = notification.userInfo?[AutomationScanNotificationUserInfo.removedPaths] as? [String] ?? []
            guard let scannedRootPaths = notification.userInfo?[AutomationScanNotificationUserInfo.scannedRootPaths] as? [String] else {
                return
            }
            let errorSummary = notification.userInfo?[AutomationScanNotificationUserInfo.errorSummary] as? String
            let replacesAllFiles = notification.userInfo?[AutomationScanNotificationUserInfo.replacesAllFiles] as? Bool ?? false
            let requiresClusterRefresh = notification.userInfo?[AutomationScanNotificationUserInfo.requiresClusterRefresh] as? Bool ?? true
            Task {
                await dashboardViewModel.applyAutomationScanUpdate(
                    updatedPaths: updatedPaths,
                    removedPaths: removedPaths,
                    scannedRootPaths: scannedRootPaths,
                    errorSummary: errorSummary,
                    replacesAllFiles: replacesAllFiles,
                    requiresClusterRefresh: requiresClusterRefresh,
                    context: modelContext
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .externalReviewSessionDidChange)) { notification in
            let session = notification.userInfo?[ExternalReviewSessionNotificationUserInfo.session] as? ExternalReviewSession
            dashboardViewModel.applyExternalReviewSession(session)
        }
        .sheet(isPresented: $panelStateManager.showQuickLookSheet) {
            if let url = panelStateManager.quickLookURL {
                QuickLookSheet(url: url)
            }
        }
        // Analytics is now triggered directly via the sidebar ACTIONS section,
        // not as a navigation selection. No nav.selection sync needed.
    }
}
