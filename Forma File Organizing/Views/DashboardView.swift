import SwiftUI
import SwiftData

struct DashboardView: View {
    @StateObject private var nav = NavigationViewModel()
    @EnvironmentObject private var dashboardViewModel: DashboardViewModel
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appearanceMode") private var appearanceMode: String = AppearanceMode.system.rawValue
    @State private var scanTask: Task<Void, Never>?
    @State private var shouldFocusSearch = false

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
                    RuleEditorView(rule: nav.editingRule, fileContext: nav.ruleEditorFileContext, onDismiss: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            nav.isShowingRuleEditor = false
                            nav.ruleEditorFileContext = nil
                            nav.editingRule = nil
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

    /// Native window toolbar content (Xcode-style): search + sidebar/inspector toggles on the far right.
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            // Hidden button for ⌘F keyboard shortcut - focuses the toolbar search field
            Button(action: focusSearch) {
                EmptyView()
            }
            .keyboardShortcut("f", modifiers: .command)
            .frame(width: 0, height: 0)
            .opacity(0)
            .accessibilityHidden(true)

            // Right panel toggle logic moved to floating overlay
            // Keeping this empty or we can remove the ToolbarItemGroup entirely if empty, 
            // but we likely want to keep the search logic.
        }
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
                    let shouldShowRightPanel = geometry.size.width >= 1200 && dashboardViewModel.isRightPanelVisible
                    let interPaneSpacing = FormaLayout.Dashboard.interPaneSpacing
                    let sidebarSpacerWidth = max(0, sidebarWidth - interPaneSpacing)
                    let sidebarEdgeInset = FormaLayout.FloatingCard.edgeInset
                    let availableWidth = geometry.size.width - sidebarWidth - (shouldShowRightPanel ? rightPanelWidth : 0) - (shouldShowRightPanel ? interPaneSpacing : 0)

                    // ZStack layout with sidebar overlay (Xcode/ChatGPT-style)
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
                                ProductivityReportView(modelContext: modelContext)
                                    .frame(minWidth: availableWidth, idealWidth: availableWidth, maxWidth: availableWidth, maxHeight: .infinity)
                            } else {
                                MainContentView(
                                    selection: nav.selection,
                                    searchText: nav.searchText,
                                    activeChips: nav.activeChips,
                                    availableWidth: availableWidth
                                )
                                .frame(minWidth: availableWidth, idealWidth: availableWidth, maxWidth: availableWidth, maxHeight: .infinity)
                            }

                            // Right Panel (conditionally shown)
                            if shouldShowRightPanel {
                                RightPanelView()
                                    .frame(
                                        minWidth: FormaLayout.Dashboard.rightPanelMinWidth,
                                        idealWidth: FormaLayout.Dashboard.rightPanelIdealWidth,
                                        maxWidth: FormaLayout.Dashboard.rightPanelMaxWidth
                                    )
                                    .padding(.top, FormaLayout.RightPanel.edgeInset)
                                    .padding(.bottom, FormaLayout.RightPanel.edgeInset)
                                    .padding(.trailing, FormaLayout.RightPanel.edgeInset)
                                    .transition(.move(edge: .trailing).combined(with: .opacity))
                            }
                        }
                        .opacity(nav.isShowingRuleEditor ? 0.5 : 1.0)
                        .disabled(nav.isShowingRuleEditor)

                        // Sidebar overlay - full-height navigator (Xcode-style)
                        SidebarView(
                            shouldFocusSearch: $shouldFocusSearch
                        )
                        .frame(
                            width: max(0, sidebarWidth - (sidebarEdgeInset * 2)),
                            height: max(0, geometry.size.height - (sidebarEdgeInset * 2)),
                            alignment: .topLeading
                        )
                        .padding(.horizontal, sidebarEdgeInset)
                        .padding(.vertical, sidebarEdgeInset)


                    }
                }

                // Rule Editor Overlay - Centered Modal
                ruleEditorOverlay
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
            .toolbar { toolbarContent }
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
                scanTask?.cancel()
                scanTask = Task {
                    await dashboardViewModel.scanFiles(context: modelContext)
                }
            }
        }
        .onDisappear {
            scanTask?.cancel()
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
