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

    // MARK: - Extracted Views (helps compiler type-checking)

    @ViewBuilder
    private var ruleEditorOverlay: some View {
        if nav.isShowingRuleEditor {
            // Dimmed background overlay
            Color.formaObsidian.opacity(Color.FormaOpacity.overlay)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        nav.isShowingRuleEditor = false
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
                        rule: nav.editingRule,
                        fileContext: nav.ruleEditorFileContext,
                        suggestedNaturalLanguageText: nav.ruleEditorSuggestedText,
                        onDismiss: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            nav.isShowingRuleEditor = false
                            nav.ruleEditorFileContext = nil
                            nav.editingRule = nil
                            nav.ruleEditorSuggestedText = nil
                        }
                    })
                    .accessibilityIdentifier("ruleEditorView")
                    Spacer()
                }
                Spacer()
            }
            .transition(.scale(scale: 0.95).combined(with: .opacity))
            .zIndex(100)
        }
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
            .onPreferenceChange(GuidedTourRegionPreferenceKey.self) { frames in
                for regionFrame in frames {
                    tourState.regionFrames[regionFrame.region] = regionFrame.frame
                }
            }
            .background(Color.formaBackground)
            .frame(minWidth: 1200, idealWidth: 1400, minHeight: 600)
            .navigationTitle("Forma: File Management")
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
            // Don't scan files until onboarding is complete - scanning triggers
            // folder permission requests which would interrupt the onboarding flow
            if dashboardViewModel.showOnboarding {
                return
            }
            guard autoScanOnLaunch else {
                return
            }
            // Initial scan when dashboard appears
            await dashboardViewModel.scanFiles(context: modelContext)
        }
        .sheet(isPresented: $dashboardViewModel.showOnboarding) {
            OnboardingFlowView()
                .environmentObject(dashboardViewModel)
        }
        .onChange(of: dashboardViewModel.showOnboarding) { wasShowingOnboarding, isShowingOnboarding in
            // Trigger scan when onboarding completes (was showing, now dismissed)
            if wasShowingOnboarding && !isShowingOnboarding {
                if autoScanOnLaunch {
                    scanTask?.cancel()
                    scanTask = Task {
                        await dashboardViewModel.scanFiles(context: modelContext)
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
        }
        .onReceive(NotificationCenter.default.publisher(for: .replayGuidedTour)) { _ in
            tourState.replayTour()
        }
        .onReceive(NotificationCenter.default.publisher(for: .automationScanDidPersist)) { notification in
            guard let scannedPaths = notification.userInfo?[AutomationScanNotificationUserInfo.scannedPaths] as? [String] else {
                return
            }
            let errorSummary = notification.userInfo?[AutomationScanNotificationUserInfo.errorSummary] as? String
            Task {
                await dashboardViewModel.applyAutomationScanUpdate(
                    scannedPaths: scannedPaths,
                    errorSummary: errorSummary,
                    context: modelContext
                )
            }
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
