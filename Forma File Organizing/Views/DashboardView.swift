import SwiftUI
import SwiftData

struct DashboardView: View {
    @StateObject private var nav = NavigationViewModel()
    @EnvironmentObject private var dashboardViewModel: DashboardViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue
    @AppStorage("autoScanOnLaunch") private var autoScanOnLaunch = true
    @State private var scanTask: Task<Void, Never>?
    @State private var shouldFocusSearch = false
    @State private var showKeyboardHelp = false
    @State private var tourState = GuidedTourState()

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

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $nav.path) {
            ToastHost(viewModel: dashboardViewModel) {
                GeometryReader { geometry in
                    let sidebarWidth: CGFloat = FormaLayout.Dashboard.sidebarExpandedWidth
                    let rightPanelWidth: CGFloat = dashboardViewModel.isRightPanelVisible ? FormaLayout.Dashboard.rightPanelIdealWidth : 0
                    let shouldShowRightPanel = geometry.size.width >= 1200 &&
                        dashboardViewModel.isRightPanelVisible &&
                        nav.selection != .analytics
                    let interPaneSpacing = FormaLayout.Dashboard.interPaneSpacing
                    let sidebarSpacerWidth = max(0, sidebarWidth - interPaneSpacing)
                    let sidebarEdgeInset = FormaLayout.FloatingCard.edgeInset
                    let rightPanelEdgeInset = FormaLayout.RightPanel.edgeInset
                    // Right panel overlay handles its own padding; no extra inset needed here
                    let availableWidth = geometry.size.width - sidebarWidth - (shouldShowRightPanel ? rightPanelWidth : 0) - (shouldShowRightPanel ? interPaneSpacing : 0)

                    // ZStack layout with sidebar and right panel overlays (Xcode/ChatGPT-style)
                    ZStack(alignment: .topLeading) {
                        // Background layer - focus-aware glass/gradient
                        PrimaryBackgroundView()

                        // Main content layer
                        HStack(alignment: .top, spacing: interPaneSpacing) {
                            // Spacer for sidebar area
                            Color.clear
                                .frame(width: sidebarSpacerWidth)

                            // Main Content
                            if nav.selection == .rules {
                                RulesManagementView()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else if nav.selection == .analytics {
                                ProductivityReportView(
                                    modelContext: modelContext,
                                    navigation: nav,
                                    dashboardViewModel: dashboardViewModel
                                )
                                    .frame(minWidth: availableWidth, idealWidth: availableWidth, maxWidth: availableWidth, maxHeight: .infinity)
                            } else {
                                MainContentView(
                                    selection: nav.selection,
                                    searchText: nav.searchText,
                                    activeChips: nav.activeChips,
                                    availableWidth: availableWidth,
                                    showKeyboardHelp: $showKeyboardHelp
                                )
                                .frame(minWidth: availableWidth, idealWidth: availableWidth, maxWidth: availableWidth, maxHeight: .infinity)
                            }

                            // Spacer for right panel area (when visible)
                            if shouldShowRightPanel {
                                Color.clear
                                    .frame(width: rightPanelWidth)
                            }
                        }
                        .opacity(nav.isShowingRuleEditor ? 0.5 : 1.0)
                        .disabled(nav.isShowingRuleEditor || tourState.isActive)

                        // Sidebar overlay - full-height navigator (Xcode-style)
                        SidebarView(
                            shouldFocusSearch: $shouldFocusSearch,
                            showKeyboardHelp: $showKeyboardHelp
                        )
                        .frame(
                            width: max(0, sidebarWidth - (sidebarEdgeInset * 2)),
                            height: max(0, geometry.size.height - (sidebarEdgeInset * 2)),
                            alignment: .topLeading
                        )
                        .padding(.horizontal, sidebarEdgeInset)
                        .padding(.vertical, sidebarEdgeInset)

                        // Right Panel overlay - floating panel (matches sidebar style)
                        if shouldShowRightPanel {
                            HStack(spacing: 0) {
                                Spacer()
                                RightPanelView()
                                    .frame(
                                        width: max(0, rightPanelWidth - (rightPanelEdgeInset * 2)),
                                        height: max(0, geometry.size.height - (rightPanelEdgeInset * 2))
                                    )
                            }
                            .padding(rightPanelEdgeInset)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }


                    }
                }

                // Rule Editor Overlay - Centered Modal
                ruleEditorOverlay

                // Guided Tour Overlay
                GuidedTourOverlay(tourState: tourState)
            }
            .onPreferenceChange(GuidedTourRegionPreferenceKey.self) { frames in
                for regionFrame in frames {
                    tourState.regionFrames[regionFrame.region] = regionFrame.frame
                }
            }
            // .background(.thickMaterial) removed to allow window transparency
            .background(Color.clear) // Ensure SwiftUI root view is clear so NSWindow background shows through
            .frame(minWidth: 1200, idealWidth: 1400, minHeight: 600)
            .navigationTitle("Forma: File Management")
            .toolbarBackground(.hidden, for: .windowToolbar)
            .ignoresSafeArea()
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
        .ignoresSafeArea() // Ensure the NavigationStack itself allows content to bleed into window chrome
        .environmentObject(nav)
        .preferredColorScheme(AppearanceMode(rawValue: appearanceMode)?.colorScheme)
        .task {
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
