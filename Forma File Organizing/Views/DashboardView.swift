import SwiftUI
import SwiftData

struct DashboardView: View {
    @StateObject private var nav = NavigationViewModel()
    @EnvironmentObject private var dashboardViewModel: DashboardViewModel
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
        CommandLine.arguments.contains("--perf-signpost-harness")
        #else
        false
        #endif
    }

    private var perfSignpostHarnessIterations: Int {
        #if DEBUG
        let rawValue = ProcessInfo.processInfo.environment["FORMA_PERF_HARNESS_ITERATIONS"] ?? "24"
        return Int(rawValue) ?? 24
        #else
        0
        #endif
    }

    private var perfSignpostHarnessWarmupIterations: Int {
        #if DEBUG
        let rawValue = ProcessInfo.processInfo.environment["FORMA_PERF_HARNESS_WARMUP"] ?? "3"
        return Int(rawValue) ?? 3
        #else
        0
        #endif
    }

    private func runStartupFlow() async {
        dashboardViewModel.restoreExternalReviewSessionIfNeeded()

        if dashboardViewModel.showOnboarding {
            return
        }

        _ = await ExternalIngressCoordinator.shared.processPendingRequestIfPossible()
        dashboardViewModel.restoreExternalReviewSessionIfNeeded()

        guard autoScanOnLaunch else {
            return
        }

        await dashboardViewModel.scanFiles(context: modelContext)
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

    private var showsInspectorColumn: Bool {
        dashboardViewModel.isRightPanelVisible && nav.selection != .analytics
    }

    private var splitLayoutMode: String {
        showsInspectorColumn ? "threeColumn" : "twoColumn"
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
        .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
    }

    @ViewBuilder
    private var centerColumn: some View {
        GeometryReader { proxy in
            centerContent(availableWidth: proxy.size.width)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationSplitViewColumnWidth(min: 680, ideal: 960)
    }

    @ViewBuilder
    private var splitViewLayout: some View {
        if showsInspectorColumn {
            NavigationSplitView {
                sidebarColumn
            } content: {
                centerColumn
            } detail: {
                RightPanelView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 420)
            }
            .navigationSplitViewStyle(.balanced)
        } else {
            NavigationSplitView {
                sidebarColumn
            } detail: {
                centerColumn
            }
            .navigationSplitViewStyle(.balanced)
        }
    }

    @ViewBuilder
    private func centerContent(availableWidth: CGFloat) -> some View {
        if nav.selection == .rules {
            RulesManagementView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if nav.selection == .analytics {
            ProductivityReportView(
                modelContext: modelContext,
                navigation: nav,
                dashboardViewModel: dashboardViewModel
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            MainContentView(
                selection: nav.selection,
                searchText: nav.searchText,
                activeChips: nav.activeChips,
                availableWidth: availableWidth,
                showKeyboardHelp: $showKeyboardHelp
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $nav.path) {
            ToastHost(viewModel: dashboardViewModel) {
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
            .frame(minWidth: 1200, idealWidth: 1400, minHeight: 600)
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
            if shouldRunPerfSignpostHarness {
                await dashboardViewModel.runPerformanceSignpostHarness(
                    iterations: perfSignpostHarnessIterations,
                    warmupIterations: perfSignpostHarnessWarmupIterations,
                    context: modelContext
                )
                return
            }
            // In UI tests, we rely on DashboardViewModel mock data and skip
            // real file system scanning for determinism.
            if CommandLine.arguments.contains("--uitesting") {
                return
            }
            await runStartupFlow()
        }
        .sheet(isPresented: $dashboardViewModel.showOnboarding) {
            OnboardingFlowView()
                .environmentObject(dashboardViewModel)
        }
        .onChange(of: dashboardViewModel.showOnboarding) { wasShowingOnboarding, isShowingOnboarding in
            // Trigger scan when onboarding completes (was showing, now dismissed)
            if wasShowingOnboarding && !isShowingOnboarding {
                scanTask?.cancel()
                scanTask = Task {
                    await runStartupFlow()
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
        }
        .onReceive(NotificationCenter.default.publisher(for: .replayGuidedTour)) { _ in
            tourState.replayTour()
        }
        .onReceive(NotificationCenter.default.publisher(for: .automationScanDidPersist)) { notification in
            let scannedPaths = notification.userInfo?[AutomationScanNotificationUserInfo.scannedPaths] as? [String] ?? []
            guard let scannedRootPaths = notification.userInfo?[AutomationScanNotificationUserInfo.scannedRootPaths] as? [String] else {
                return
            }
            let errorSummary = notification.userInfo?[AutomationScanNotificationUserInfo.errorSummary] as? String
            let replacesAllFiles = notification.userInfo?[AutomationScanNotificationUserInfo.replacesAllFiles] as? Bool ?? false
            Task {
                await dashboardViewModel.applyAutomationScanUpdate(
                    scannedPaths: scannedPaths,
                    scannedRootPaths: scannedRootPaths,
                    errorSummary: errorSummary,
                    replacesAllFiles: replacesAllFiles,
                    context: modelContext
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .externalReviewSessionDidChange)) { notification in
            let session = notification.userInfo?[ExternalReviewSessionNotificationUserInfo.session] as? ExternalReviewSession
            dashboardViewModel.applyExternalReviewSession(session)
        }
        .sheet(isPresented: $dashboardViewModel.showQuickLookSheet) {
            if let url = dashboardViewModel.quickLookURL {
                QuickLookSheet(url: url)
            }
        }
        .onChange(of: nav.selection) { _, newSelection in
            if newSelection == .analytics {
                dashboardViewModel.rightPanelMode = .analytics
            } else if case .analytics = dashboardViewModel.rightPanelMode {
                dashboardViewModel.rightPanelMode = .default
            }
        }
    }
}
