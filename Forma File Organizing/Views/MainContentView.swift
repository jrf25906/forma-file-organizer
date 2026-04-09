import SwiftUI
import SwiftData
import AppKit

enum FileRecoveryState {
    static func recoverToReady(_ file: FileItem, destination: Destination) {
        file.destination = destination
        file.status = .ready
        file.lastOrganizeError = nil
    }

    static func clearErrorIfRecovered(_ file: FileItem) {
        guard file.status == .ready, file.destination != nil else { return }
        file.lastOrganizeError = nil
    }

    static func clearErrorIfRecovered(
        _ file: FileItem,
        previousDestination: Destination?,
        previousStatus: FileItem.OrganizationStatus,
        recoveredDestination: Destination? = nil
    ) {
        guard file.status == .ready, let currentDestination = file.destination else { return }

        let changedState = currentDestination != previousDestination || previousStatus != .ready
        let reappliedRecoveredDestination = recoveredDestination == currentDestination
        guard changedState || reappliedRecoveredDestination else { return }

        file.lastOrganizeError = nil
    }
}

#Preview {
    MainContentView(
        selection: .home,
        searchText: "",
        activeChips: [],
        availableWidth: 1200,
        showKeyboardHelp: .constant(false)
    )
    .environmentObject(DashboardViewModel())
    .environmentObject(NavigationViewModel())
}

struct MainContentView: View {
    private enum PrimaryActionSource {
        case floatingActionBar
        case rightPanelPinned
    }

    let availableWidth: CGFloat
    @EnvironmentObject var nav: NavigationViewModel
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    @Environment(\.modelContext) private var modelContext
    
    // Phase 4: Hover Preview
    @State private var hoveredFile: FileItem?
    @State private var cursorPosition: CGPoint = .zero
    @State private var hoverTask: Task<Void, Never>?
    
    // Phase 6: Organize Animations
    // Note: organizingFilePaths is now managed by DashboardViewModel for single source of truth
    @State private var ruleAppliedFilePaths: Set<String> = []
    // PERF: Removed @Namespace animation - matchedGeometryEffect was unused (no destination view)
    // Animation handled internally by organizeAnimation modifier

    // Phase 4: Keyboard shortcuts help
    @Binding var showKeyboardHelp: Bool

    // Command palette (⌘K)
    @State private var showCommandPalette = false

    @State private var unifiedToolbarHeight: CGFloat = 0

    init(
        selection: NavigationSelection,
        searchText: String,
        activeChips: Set<FileFilterChip>,
        availableWidth: CGFloat,
        showKeyboardHelp: Binding<Bool>
    ) {
        self.availableWidth = availableWidth
        self._showKeyboardHelp = showKeyboardHelp
        // selection, searchText, and activeChips are currently handled via
        // DashboardViewModel state rather than a local @Query.
    }
    
    /// Whether the currently selected folder lacks permission
    private var selectedFolderNeedsPermission: Bool {
        guard let folderType = nav.selection.folderType else { return false }
        return !BookmarkFolderService.shared.hasAccess(to: folderType)
    }

    /// Display name for the currently selected folder
    private var currentLockedFolderName: String {
        nav.selection.folderType?.displayName ?? "this folder"
    }

    @ObservedObject private var folderService = BookmarkFolderService.shared

    /// Request access for the currently selected folder via NSOpenPanel
    private func requestAccessForSelectedFolder() {
        Task {
            guard let folderType = nav.selection.folderType else { return }
            switch folderType {
            case .desktop: _ = await dashboardViewModel.requestDesktopAccess()
            case .downloads: _ = await dashboardViewModel.requestDownloadsAccess()
            case .documents: _ = await dashboardViewModel.requestDocumentsAccess()
            case .pictures: _ = await dashboardViewModel.requestPicturesAccess()
            case .music: _ = await dashboardViewModel.requestMusicAccess()
            }
        }
    }

    /// Whether the first-run suggestion banner should be shown
    private var shouldShowFirstRunBanner: Bool {
        UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        && !dashboardViewModel.isBulkOperationInProgress
        && dashboardViewModel.firstRunQuickWinSuggestion != nil
    }

    /// Whether the floating action bar should be displayed
    private var shouldShowFAB: Bool {
        dashboardViewModel.isSelectionMode
    }

    /// Primary-action ownership for the current screen state.
    private var primaryActionSource: PrimaryActionSource {
        dashboardViewModel.isSelectionMode ? .floatingActionBar : .rightPanelPinned
    }

    /// Row-level primary buttons are hidden when the bottom bulk bar is the active primary action.
    private var showsRowPrimaryActionButtons: Bool {
        primaryActionSource == .rightPanelPinned
    }

    var body: some View {
        ZStack(alignment: .bottom) { // Use ZStack as root for overlay alignment
            VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .top) {
                // Content
                Group {
                    if selectedFolderNeedsPermission {
                        // JIT Permission: folder selected but no access granted
                        JITPermissionCard(
                            folderName: currentLockedFolderName,
                            onGrantAccess: {
                                requestAccessForSelectedFolder()
                            }
                        )
                        .padding(.top, contentTopInset)
                    } else if dashboardViewModel.isLoading && dashboardViewModel.visibleFiles.isEmpty {
                        // Show loading state during initial file scan
                        Spacer()
                        VStack(spacing: FormaSpacing.generous) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Loading files...")
                                .font(.formaBody)
                                .foregroundColor(.formaSecondaryLabel)
                        }
                        Spacer()
                    } else if dashboardViewModel.visibleFiles.isEmpty {
                        // Show empty state if in review mode and all caught up
                        if dashboardViewModel.reviewFilterMode == .needsReview {
                            AllCaughtUpView()
                                .padding(.top, contentTopInset)
                        } else {
                            VStack(spacing: FormaSpacing.generous) {
                                // Show active filters above empty state
                                ActiveFiltersBar(
                                    searchText: dashboardViewModel.searchText,
                                    category: dashboardViewModel.selectedCategory,
                                    secondaryFilter: dashboardViewModel.selectedSecondaryFilter,
                                    selectedContentTags: dashboardViewModel.selectedContentTags,
                                    onClearSearch: {
                                        dashboardViewModel.updateSearchText("")
                                        nav.searchText = ""
                                    },
                                    onClearCategory: {
                                        dashboardViewModel.selectedCategory = .all
                                    },
                                    onClearSecondary: {
                                        dashboardViewModel.setSecondaryFilter(.none)
                                    },
                                    onRemoveContentTag: { tag in
                                        dashboardViewModel.removeContentTagQuickFilter(tag)
                                    },
                                    onClearAll: {
                                        dashboardViewModel.clearAllFilters()
                                        nav.searchText = ""
                                    }
                                )
                                .padding(.horizontal, FormaLayout.Gutters.center)
                                .padding(.top, FormaSpacing.generous)

                                FormaEmptyState(
                                    title: "No files found",
                                    message: "Try adjusting your filters or search terms.",
                                    actionTitle: "Clear Filters",
                                    action: {
                                        dashboardViewModel.clearAllFilters()
                                        nav.searchText = ""
                                    }
                                )
                            }
                            .background(.ultraThinMaterial)
                            .formaFrostedTexture()
                            .padding(.top, contentTopInset)
                        }
                    } else {
                        // Phase 3: View mode switching
                        Group {
                            switch dashboardViewModel.currentViewMode {
                            case .card:
                                cardView
                            case .list:
                                listView
                            case .grid:
                                gridView
                            }
                        }
                        .mask(scrollFadeMask)
                        .guidedTourRegion(.mainFileList)
                        .animation(FormaEasing.standard, value: dashboardViewModel.currentViewMode)
                    }
                }

                contentContainer {
                    VStack(alignment: .leading, spacing: 0) {
                        UnifiedToolbar(availableWidth: contentMaxWidth)
                            .padding(.top, toolbarTopOffset)
                            .padding(.bottom, dashboardToolbarBottomSpacing)

                        if dashboardViewModel.showsContentTagQuickFilters {
                            ContentTagQuickFilters(
                                availableTags: dashboardViewModel.availableContentTags,
                                selectedTags: dashboardViewModel.selectedContentTags,
                                onToggle: { tag in
                                    dashboardViewModel.toggleContentTagQuickFilter(tag)
                                }
                            )
                        }
                    }
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .preference(key: UnifiedToolbarHeightKey.self, value: proxy.size.height)
                        }
                    )
                    .onPreferenceChange(UnifiedToolbarHeightKey.self) { newHeight in
                        unifiedToolbarHeight = newHeight
                    }
                }
                .zIndex(10)
            }

            KeyCaptureView { event in
                handleKeyEvent(event)
            }
            .frame(width: 0, height: 0)

            accessibilityStateProbes
                .frame(width: 0, height: 0)

            #if DEBUG
            if isUITesting {
                uiTestShortcutHandlers
                Group {
                    if dashboardViewModel.editingDestinationFile != nil {
                        Color.clear
                            .accessibilityIdentifier("editDestinationSheet")
                    }
                    if nav.ruleDraftSession?.presentation == .modal {
                        Color.clear
                            .accessibilityIdentifier("ruleEditorView")
                    }
                }
                .frame(width: 0, height: 0)
            }
            #endif
            
        } // End VStack
        
        
        // Floating Action Bar - Direct ZStack child
        if dashboardViewModel.isSelectionMode {
            VStack(spacing: FormaSpacing.tight) {
                if dashboardViewModel.showsDashboardWorkflowTemplatePicker {
                    WorkflowTemplatePicker(
                        selectedTemplateID: $dashboardViewModel.selectedWorkflowTemplateID,
                        preview: dashboardViewModel.dashboardWorkflowSimulationPreview
                    )
                    .padding(.horizontal, FormaLayout.Gutters.center)
                }

                FloatingActionBar(
                    mode: .selection,
                    count: dashboardViewModel.selectedFileIDs.count,
                    canOrganizeAll: dashboardViewModel.canOrganizeAllSelected,
                    onOrganize: {
                        dashboardViewModel.organizeSelectedFiles(context: modelContext)
                    },
                    onSkip: {
                        dashboardViewModel.skipSelectedFiles()
                    },
                    onBulkEdit: {
                        dashboardViewModel.showBulkEditSheet = true
                    },
                    onDeselect: {
                        dashboardViewModel.deselectAll()
                    }
                )
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .zIndex(100)
            .padding(.bottom, FloatingActionBar.bottomOffset)
        } else if dashboardViewModel.reviewFilterMode == .needsReview && !dashboardViewModel.visibleFiles.isEmpty {
            VStack(spacing: FormaSpacing.tight) {
                if dashboardViewModel.showsDashboardWorkflowTemplatePicker {
                    WorkflowTemplatePicker(
                        selectedTemplateID: $dashboardViewModel.selectedWorkflowTemplateID,
                        preview: dashboardViewModel.dashboardWorkflowSimulationPreview
                    )
                    .padding(.horizontal, FormaLayout.Gutters.center)
                }

                FloatingActionBar(
                    mode: .review,
                    count: dashboardViewModel.currentReviewChunkReadyCount,
                    canOrganizeAll: dashboardViewModel.currentReviewChunkReadyCount > 0,
                    onOrganize: {
                        dashboardViewModel.organizeAllReadyFiles(context: modelContext)
                    },
                    onSkip: {
                        dashboardViewModel.doneForNow()
                    }
                )
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .zIndex(100)
            .padding(.bottom, FloatingActionBar.bottomOffset)
        }
        } // End ZStack
        .overlay {
            // Phase 2: Bulk Operation Progress Overlay
            if dashboardViewModel.isBulkOperationInProgress {
                ZStack {
                    Color.formaObsidian.opacity(Color.FormaOpacity.overlay)
                        .edgesIgnoringSafeArea(.all)
                    
                    BulkOperationProgressView(
                        totalFiles: dashboardViewModel.selectedFiles.count,
                        progress: dashboardViewModel.bulkOperationProgress,
                        onCancel: {
                            dashboardViewModel.cancelBulkOperation()
                            dashboardViewModel.deselectAll()
                        }
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
            
            // Phase 4: Hover Preview Popup
            if let file = hoveredFile {
                ThumbnailPreviewPopup(
                    file: file,
                    cursorPosition: cursorPosition
                )
                .zIndex(100)
            }
        }
        .onAppear {
            syncSelectionAndFilters()
        }
        .onChange(of: nav.selection) {
            syncSelectionAndFilters()
        }
        .onChange(of: nav.searchText) { _, newValue in
            dashboardViewModel.updateSearchText(newValue)
        }
        .sheet(isPresented: Binding(
            get: { dashboardViewModel.editingDestinationFile != nil },
            set: { isPresented in
                if !isPresented {
                    dashboardViewModel.editingDestinationFile = nil
                }
            }
        )) {
            if let file = dashboardViewModel.editingDestinationFile {
                EditDestinationSheet(file: file) { newDestination in
                    dashboardViewModel.updateDestination(for: file, to: newDestination)
                }
                .accessibilityIdentifier("editDestinationSheet")
            }
        }
        // Phase 2: Bulk Edit Sheet
        .sheet(isPresented: $dashboardViewModel.showBulkEditSheet) {
            BulkEditSheet(
                selectedFiles: dashboardViewModel.selectedFiles,
                onSave: { destination, createRules in
                    dashboardViewModel.bulkEditDestination(destination, createRules: createRules, context: modelContext)
                }
            )
        }
        // Phase 4: Keyboard Shortcuts Help
        .sheet(isPresented: $showKeyboardHelp) {
            KeyboardShortcutsHelpView()
                .presentationBackground(.clear)
        }
        // Command Palette (⌘K)
        .sheet(isPresented: $showCommandPalette) {
            CommandPaletteView()
                .presentationBackground(.clear)
        }
        // Failed Files Sheet
        .sheet(isPresented: $dashboardViewModel.showFailedFilesSheet) {
            FailedFilesSheet(
                failedFiles: dashboardViewModel.lastBatchFailedFiles,
                onRetry: {
                    dashboardViewModel.retryFailedFiles(context: modelContext)
                },
                onDismiss: {
                    dashboardViewModel.dismissFailedFiles()
                }
            )
        }
        // Phase 2: Keyboard Shortcuts
        .dashboardKeyboardShortcuts(viewModel: dashboardViewModel, context: modelContext)
        .onAppear {
            dashboardViewModel.setModelContext(modelContext)
        }
    }

    private struct UnifiedToolbarHeightKey: PreferenceKey {
        static var defaultValue: CGFloat { 0 }

        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = max(value, nextValue())
        }
    }
    
    private func syncSelectionAndFilters() {
        let folder: FolderLocation
        var nestedScope: (relativePath: String?, includeSubfolders: Bool)?
        switch nav.selection {
        case .home:
            folder = .home
        case .desktop:
            folder = .desktop
        case .downloads:
            folder = .downloads
        case .documents:
            folder = .documents
        case .pictures:
            folder = .pictures
        case .music:
            folder = .music
        case .nestedFolder(let base, let relativePath, let includeSubfolders):
            folder = FolderLocation.from(bookmarkFolderType: base)
            nestedScope = (relativePath: relativePath, includeSubfolders: includeSubfolders)
        case .rules:
            // Rules view doesn't need folder filtering
            return
        case .analytics:
            // Analytics view doesn't need folder filtering
            return
        case .category:
            // Category selection is handled via FilterTabBar / selectedCategory
            folder = .home
        }
        dashboardViewModel.selectFolder(folder, resetNestedScope: nestedScope == nil)
        if let nestedScope {
            dashboardViewModel.selectNestedFolder(
                relativePath: nestedScope.relativePath,
                includeSubfolders: nestedScope.includeSubfolders
            )
        } else {
            dashboardViewModel.selectNestedFolder(relativePath: nil, includeSubfolders: false)
        }
        dashboardViewModel.updateSearchText(nav.searchText)
    }

    private func handleSelectionToggle(for file: FileItem) {
        guard !attemptRangeSelection(for: file) else { return }
        dashboardViewModel.toggleSelection(for: file)
    }

    private func attemptRangeSelection(for file: FileItem) -> Bool {
        guard NSApp.currentEvent?.modifierFlags.contains(.shift) == true else { return false }

        let anchorPath = dashboardViewModel.rangeSelectionAnchorPath ?? dashboardViewModel.selectedFileIDs.first
        guard let anchorPath,
              anchorPath != file.path,
              let anchor = dashboardViewModel.visibleFiles.first(where: { $0.path == anchorPath }) else {
            return false
        }

        dashboardViewModel.selectRange(from: anchor, to: file)
        return true
    }
    
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        // Ignore if text input is focused (except maybe Cmd shortcuts, but for now ignore all to be safe)
        if !isUITesting,
           let window = NSApp.keyWindow,
           let responder = window.firstResponder as? NSView,
           responder is NSTextView || responder is NSTextField {
            return false
        }
        
        let command = event.modifierFlags.contains(.command)
        let keyCode = event.keyCode
        let chars = event.charactersIgnoringModifiers ?? event.characters ?? ""
        let lowercasedChars = chars.lowercased()
        let isReturnKey = keyCode == 36 || keyCode == 76 || chars == "\r" || chars == "\n" || chars == "\u{3}"
        
        // Cmd+Enter: organize and move focus to next
        if command && isReturnKey { // Return / keypad Enter
            dashboardViewModel.organizeFocusedFile(context: modelContext)
            dashboardViewModel.focusNextFile()
            return true
        }

        // Cmd+K: Open command palette
        if command && lowercasedChars == "k" {
            showCommandPalette = true
            return true
        }

        // Enter: organize focused file
        if isReturnKey { // Return / keypad Enter
            dashboardViewModel.organizeFocusedFile(context: modelContext)
            return true
        }
        
        // Space: Quick Look
        if chars == " " {
            dashboardViewModel.quickLookFocusedFile()
            return true
        }
        
        // Navigation: Down / J, Up / K
        if keyCode == 125 || lowercasedChars == "j" { // Down arrow or J
            dashboardViewModel.focusNextFile()
            return true
        }
        if keyCode == 126 || lowercasedChars == "k" { // Up arrow or K
            dashboardViewModel.focusPreviousFile()
            return true
        }
        
        // S: Skip
        if lowercasedChars == "s" {
            dashboardViewModel.skipFocusedFile()
            return true
        }
        
        // E: Edit destination (stubbed)
        if lowercasedChars == "e" || keyCode == 14 {
            Task { @MainActor in
                if let focusedPath = dashboardViewModel.focusedFilePath,
                   let focused = dashboardViewModel.visibleFiles.first(where: { $0.path == focusedPath }) {
                    dashboardViewModel.beginEditingDestination(for: focused)
                } else if let first = dashboardViewModel.visibleFiles.first {
                    dashboardViewModel.beginEditingDestination(for: first)
                } else {
                    dashboardViewModel.editDestinationForFocusedFile()
                }
            }
            return true
        }
        
        // R: Create/View rule from focused file
        if lowercasedChars == "r" || keyCode == 15 {
            Task { @MainActor in
                let focused = dashboardViewModel.focusedFilePath
                    .flatMap { path in dashboardViewModel.visibleFiles.first(where: { $0.path == path }) }
                    ?? dashboardViewModel.visibleFiles.first
                if let focused {
                    presentRuleEditor(for: focused)
                }
            }
            return true
        }
        
        // ?: Show keyboard shortcuts help
        if chars == "?" {
            showKeyboardHelp = true
            return true
        }
        
        return false
    }

    private var isUITesting: Bool {
        CommandLine.arguments.contains("--uitesting") ||
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private var accessibilityStateProbes: some View {
        let reviewModeValue = dashboardViewModel.reviewFilterMode == .needsReview ? "needsReview" : "allFiles"
        let viewModeValue = switch dashboardViewModel.currentViewMode {
        case .grid: "grid"
        case .list: "list"
        case .card: "card"
        }
        let needsReviewCountValue = "\(dashboardViewModel.needsReviewCount)"
        let allFilesCountValue = "\(dashboardViewModel.allFilesCount)"
        let selectedCountValue = "\(dashboardViewModel.selectedFileIDs.count)"
        let focusedFilePathValue = dashboardViewModel.focusedFilePath ?? "none"

        return Group {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityIdentifier("mainContent_reviewMode")
                .accessibilityLabel("Review mode \(reviewModeValue)")
                .accessibilityValue(reviewModeValue)

            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityIdentifier("mainContent_viewMode")
                .accessibilityLabel("View mode \(viewModeValue)")
                .accessibilityValue(viewModeValue)

            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityIdentifier("mainContent_needsReviewCount")
                .accessibilityLabel("Needs review count \(needsReviewCountValue)")
                .accessibilityValue(needsReviewCountValue)

            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityIdentifier("mainContent_allFilesCount")
                .accessibilityLabel("All files count \(allFilesCountValue)")
                .accessibilityValue(allFilesCountValue)

            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityIdentifier("mainContent_selectedCount")
                .accessibilityLabel("Selected file count \(selectedCountValue)")
                .accessibilityValue(selectedCountValue)

            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityIdentifier("mainContent_focusedFilePath")
                .accessibilityLabel("Focused file path \(focusedFilePathValue)")
                .accessibilityValue(focusedFilePathValue)
        }
        .allowsHitTesting(false)
    }

    #if DEBUG
    private var uiTestShortcutHandlers: some View {
        Group {
            Button("") {
                dashboardViewModel.organizeFocusedFile(context: modelContext)
            }
            .keyboardShortcut(.return, modifiers: [])
            .hidden()

            Button("") {
                dashboardViewModel.organizeFocusedFile(context: modelContext)
                dashboardViewModel.focusNextFile()
            }
            .keyboardShortcut(.return, modifiers: .command)
            .hidden()

            Button("") {
                if let focusedPath = dashboardViewModel.focusedFilePath,
                   let focused = dashboardViewModel.visibleFiles.first(where: { $0.path == focusedPath }) {
                    dashboardViewModel.beginEditingDestination(for: focused)
                } else if let first = dashboardViewModel.visibleFiles.first {
                    dashboardViewModel.beginEditingDestination(for: first)
                }
            }
            .keyboardShortcut("e", modifiers: [])
            .hidden()

            Button("") {
                let focused = dashboardViewModel.focusedFilePath
                    .flatMap { path in dashboardViewModel.visibleFiles.first(where: { $0.path == path }) }
                    ?? dashboardViewModel.visibleFiles.first
                if let focused {
                    presentRuleEditor(for: focused)
                }
            }
            .keyboardShortcut("r", modifiers: [])
            .hidden()
        }
    }
    #endif
    
    // MARK: - Hover Preview Helpers (Phase 4)
    private func handleThumbnailHover(file: FileItem?, event: NSEvent?) {
        // Cancel any pending hover task
        hoverTask?.cancel()
        
        guard let file = file else {
            // Mouse left, clear preview immediately
            hoveredFile = nil
            return
        }
        
        // Update cursor position if event provided
        if event != nil {
            cursorPosition = NSEvent.mouseLocation
        }
        
        // Delay showing preview by 300ms
        hoverTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
            
            if !Task.isCancelled {
                hoveredFile = file
            }
        }
    }
    
    /// MARK: - Organize Animation Helpers (Phase 6)
    /// Triggers the organize flow for a file.
    ///
    /// The ViewModel handles the full flow:
    /// 1. Marks file as "organizing" (triggers animation)
    /// 2. Moves file on disk
    /// 3. Animation completes → `handleOrganizeAnimationComplete` collapses the gap
    private func organizeFileWithAnimation(_ file: FileItem) {
        // The ViewModel handles everything - marking as organizing, file operation, etc.
        // The animation is driven by dashboardViewModel.organizingFilePaths
        dashboardViewModel.organizeFile(file, context: modelContext)
    }

    private func presentRuleEditor(for file: FileItem) {
        withAnimation(FormaEasing.standard) {
            nav.openRuleEditor(
                fileContext: file,
                returnTarget: .defaultPanel
            )
        }
    }
    
    // MARK: - View Mode Implementations (Phase 3)
    // Grid column count is now adaptive in gridView below

    private var contentHorizontalPadding: CGFloat { FormaLayout.Gutters.center }
    private var contentMaxWidth: CGFloat { max(0, availableWidth - (contentHorizontalPadding * 2)) }

    private var contentTopPadding: CGFloat { FormaLayout.Content.topPadding }
    private var dashboardToolbarTopLift: CGFloat { FormaSpacing.tight }
    private var dashboardToolbarBottomSpacing: CGFloat { FormaSpacing.standard - FormaSpacing.micro }
    private var toolbarTopOffset: CGFloat { -dashboardToolbarTopLift }
    private var contentTopInset: CGFloat {
        max(0, unifiedToolbarHeight + dashboardToolbarBottomSpacing - dashboardToolbarTopLift)
    }
    private var scrollContentTopInset: CGFloat { contentTopInset }

    /// Mask applied to the scroll view group so content fades to transparent
    /// as it scrolls under the toolbar, letting the real background show through.
    private var scrollFadeMask: some View {
        VStack(spacing: 0) {
            // Fully transparent under the toolbar — content here is invisible
            Color.clear
                .frame(height: scrollContentTopInset)

            // Short fade from transparent to opaque
            LinearGradient(
                colors: [.clear, .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 2)

            // Fully visible content area
            Rectangle().fill(.black)
        }
    }
    private var fabReservedSpace: CGFloat {
        guard shouldShowFAB else { return FormaSpacing.generous }
        return FloatingActionBar.chromeHeight + FloatingActionBar.bottomOffset + FormaSpacing.standard
    }
    private var fileDisplayDensity: FileDisplayDensity { .spacious }
    /// Unique destinations from visible files, for inline destination pickers.
    private var availableDestinations: [Destination] {
        let destinations = dashboardViewModel.visibleFiles.compactMap(\.destination)
        var seen = Set<Destination>()
        return destinations.filter { seen.insert($0).inserted }
    }

    private func fileSurfaceActivity(for file: FileItem) -> FileSurfaceStyle.ActivityState {
        if dashboardViewModel.organizingFilePaths.contains(file.path) {
            return .processing
        }
        if let lastOrganizeError = file.lastOrganizeError, !lastOrganizeError.isEmpty {
            return .error
        }
        return .none
    }

    private func recoverFile(_ file: FileItem, to destination: Destination) {
        FileRecoveryState.recoverToReady(file, destination: destination)
        dashboardViewModel.filterViewModel.applyFilterImmediately()
    }

    private func applyRuleRecovery(_ rule: Rule, to file: FileItem) {
        let previousDestination = file.destination
        let previousStatus = file.status

        dashboardViewModel.applyRule(rule, to: file)
        FileRecoveryState.clearErrorIfRecovered(
            file,
            previousDestination: previousDestination,
            previousStatus: previousStatus,
            recoveredDestination: rule.destination
        )
    }

    @ViewBuilder
    private var firstRunBannerIfNeeded: some View {
        if shouldShowFirstRunBanner,
           let suggestion = dashboardViewModel.firstRunQuickWinSuggestion {
            FirstRunSuggestionBanner(
                suggestion: suggestion,
                onOrganize: {
                    dashboardViewModel.organizeFirstRunQuickWin(context: modelContext)
                },
                onDismiss: {
                    dashboardViewModel.dismissFirstRunQuickWin()
                }
            )
        }
    }

    private var cardRowSpacing: CGFloat {
        switch fileDisplayDensity {
        case .tight: return 4
        case .balanced: return 6
        case .spacious: return 8
        }
    }
    private var listRowSpacing: CGFloat {
        switch fileDisplayDensity {
        case .tight: return 0
        case .balanced: return 0
        case .spacious: return 0
        }
    }
    private var gridColumnSpacing: CGFloat {
        switch fileDisplayDensity {
        case .tight: return 8
        case .balanced: return 10
        case .spacious: return 12
        }
    }
    private var gridRowSpacing: CGFloat {
        switch fileDisplayDensity {
        case .tight: return 12
        case .balanced: return 16
        case .spacious: return 20
        }
    }
    private var gridMinimumWidth: CGFloat {
        switch fileDisplayDensity {
        case .tight: return 156
        case .balanced: return 170
        case .spacious: return 186
        }
    }
    private var gridMaximumWidth: CGFloat {
        switch fileDisplayDensity {
        case .tight: return 200
        case .balanced: return 220
        case .spacious: return 240
        }
    }

    private func contentContainer<Content: View>(
        alignment: Alignment = .leading,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(width: contentMaxWidth, alignment: alignment)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var cardView: some View {
        ScrollView(showsIndicators: false) {
            contentContainer {
                // Force view update when content search results change
                // Using VStack wrapper to establish proper SwiftUI observation
                VStack(spacing: 0) {
                    firstRunBannerIfNeeded
                        .padding(.bottom, FormaSpacing.tight)

                    LazyVStack(spacing: cardRowSpacing) {
                        ForEach(dashboardViewModel.visibleFiles) { file in
                            FileRow(
                                file: file,
                                density: fileDisplayDensity,
                                isFocused: dashboardViewModel.focusedFilePath == file.path,
                                isSelected: dashboardViewModel.isSelected(file),
                                isSelectionMode: dashboardViewModel.isSelectionMode,
                                showsPrimaryActionButton: showsRowPrimaryActionButtons,
                                showKeyboardHints: dashboardViewModel.isKeyboardNavigating,
                                surfaceActivity: fileSurfaceActivity(for: file),
                                searchMatchType: dashboardViewModel.searchMatchType(for: file),
                                contentSnippet: dashboardViewModel.contentSnippet(for: file),
                                availableDestinations: availableDestinations,
                                onChangeDestination: { item, destination in
                                    recoverFile(item, to: destination)
                                },
                                onOrganize: { item in
                                    organizeFileWithAnimation(item)
                                },
                                onSkip: { item in
                                    dashboardViewModel.skipFile(item)
                                },
                                onEditDestination: { item in
                                    dashboardViewModel.beginEditingDestination(for: item)
                                },
                                onCreateRule: { item in
                                    presentRuleEditor(for: item)
                                },
                                onViewRule: nil,
                                matchingRules: dashboardViewModel.getMatchingRules(for: file),
                                onApplyRule: { rule in
                                    applyRuleRecovery(rule, to: file)
                                    ruleAppliedFilePaths.insert(file.path)
                                    Task { @MainActor in
                                        try? await Task.sleep(nanoseconds: 500_000_000)
                                        ruleAppliedFilePaths.remove(file.path)
                                    }
                                },
                                onQuickLook: { item in
                                    dashboardViewModel.showQuickLook(for: item)
                                },
                                onToggleSelection: { item in
                                    handleSelectionToggle(for: item)
                                },
                                onThumbnailHover: handleThumbnailHover
                            )
                            .frame(maxWidth: .infinity)
                            .organizeAnimation(
                                isOrganizing: dashboardViewModel.organizingFilePaths.contains(file.path),
                                onComplete: {
                                    dashboardViewModel.handleOrganizeAnimationComplete(for: file.path)
                                }
                            )
                            .transition(
                                .asymmetric(
                                    insertion: .opacity,
                                    removal: .scale(scale: 0.8).combined(with: .opacity)
                                )
                            )
                        }
                    }
                }
            }
            .padding(.top, contentTopPadding + scrollContentTopInset)
            .padding(.bottom, fabReservedSpace)
        }
        .frame(maxHeight: .infinity) // Fill available space
        .background(Color.clear)
        .accessibilityIdentifier("fileListScrollView")
    }

    private var listView: some View {
        ScrollView(showsIndicators: false) {
            contentContainer {
                VStack(spacing: 0) {
                    firstRunBannerIfNeeded
                        .padding(.bottom, FormaSpacing.tight)

                    listViewContent
                }
            }
            .padding(.top, contentTopPadding + scrollContentTopInset)
            .padding(.bottom, fabReservedSpace)
        }
        .frame(maxHeight: .infinity)
        .background(Color.clear)
        .accessibilityIdentifier("fileListScrollView")
    }

    // MARK: - List View Content (Extracted for Type Inference)

    @ViewBuilder
    private var listViewContent: some View {
        LazyVStack(spacing: listRowSpacing) {
            ForEach(Array(dashboardViewModel.visibleFiles.enumerated()), id: \.element.id) { index, file in
                listFileRow(file: file, index: index)

                // Separator between list rows (not after the last row)
                if index < dashboardViewModel.visibleFiles.count - 1 {
                    Color.formaSeparator.opacity(0.3)
                        .frame(height: 0.5)
                        .padding(.leading, 52)
                }
            }
        }
    }

    @ViewBuilder
    private func listFileRow(file: FileItem, index: Int) -> some View {
        FileListRow(
            file: file,
            density: fileDisplayDensity,
            rowIndex: index,
            isFocused: dashboardViewModel.focusedFilePath == file.path,
            isSelected: dashboardViewModel.isSelected(file),
            isSelectionMode: dashboardViewModel.isSelectionMode,
            showsPrimaryActionButton: showsRowPrimaryActionButtons,
            surfaceActivity: fileSurfaceActivity(for: file),
            searchMatchType: dashboardViewModel.searchMatchType(for: file),
            onToggleSelection: { handleSelectionToggle(for: file) },
            onOrganize: { organizeFileWithAnimation(file) },
            onEdit: { dashboardViewModel.beginEditingDestination(for: file) },
            onSkip: { dashboardViewModel.skipFile(file) },
            onQuickLook: { dashboardViewModel.showQuickLook(for: file) },
            availableDestinations: availableDestinations,
            onChangeDestination: { destination in
                recoverFile(file, to: destination)
            },
            matchingRules: dashboardViewModel.getMatchingRules(for: file),
            onCreateRule: {
                presentRuleEditor(for: file)
            },
            onApplyRule: { rule in
                applyRuleRecovery(rule, to: file)
                ruleAppliedFilePaths.insert(file.path)
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    ruleAppliedFilePaths.remove(file.path)
                }
            }
        )
        .frame(maxWidth: .infinity)
        .organizeAnimation(
            isOrganizing: dashboardViewModel.organizingFilePaths.contains(file.path),
            onComplete: { dashboardViewModel.handleOrganizeAnimationComplete(for: file.path) }
        )
        .ruleAppliedFlash(isApplied: ruleAppliedFilePaths.contains(file.path))
        .transition(.asymmetric(insertion: .opacity, removal: .scale(scale: 0.8).combined(with: .opacity)))
    }

    private var gridView: some View {
        ScrollView(showsIndicators: false) {
            let columns = [
                GridItem(.adaptive(minimum: gridMinimumWidth, maximum: gridMaximumWidth), spacing: gridColumnSpacing)
            ]
            contentContainer {
                VStack(spacing: 0) {
                    firstRunBannerIfNeeded
                        .padding(.bottom, FormaSpacing.tight)

                    LazyVGrid(
                    columns: columns,
                    alignment: .leading,
                    spacing: gridRowSpacing
                ) {
                    // Use flat visibleFiles list to avoid duplicate IDs from grouping
                    ForEach(dashboardViewModel.visibleFiles) { file in
                        FileGridItem(
                            file: file,
                            density: fileDisplayDensity,
                            isFocused: dashboardViewModel.focusedFilePath == file.path,
                            isSelected: dashboardViewModel.isSelected(file),
                            isSelectionMode: dashboardViewModel.isSelectionMode,
                            showsPrimaryActionButton: showsRowPrimaryActionButtons,
                            surfaceActivity: fileSurfaceActivity(for: file),
                            searchMatchType: dashboardViewModel.searchMatchType(for: file),
                            onToggleSelection: {
                                handleSelectionToggle(for: file)
                            },
                            onOrganize: {
                                organizeFileWithAnimation(file)
                            },
                            onEdit: {
                                dashboardViewModel.beginEditingDestination(for: file)
                            },
                            onSkip: {
                                dashboardViewModel.skipFile(file)
                            },
                            onQuickLook: {
                                dashboardViewModel.showQuickLook(for: file)
                            },
                            availableDestinations: availableDestinations,
                            onChangeDestination: { destination in
                                recoverFile(file, to: destination)
                            },
                            matchingRules: dashboardViewModel.getMatchingRules(for: file),
                            onCreateRule: {
                                presentRuleEditor(for: file)
                            },
                            onApplyRule: { rule in
                                applyRuleRecovery(rule, to: file)
                                ruleAppliedFilePaths.insert(file.path)
                                Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 500_000_000)
                                    ruleAppliedFilePaths.remove(file.path)
                                }
                            }
                        )
                        .frame(maxWidth: .infinity)
                        .organizeAnimation(
                            isOrganizing: dashboardViewModel.organizingFilePaths.contains(file.path),
                            onComplete: {
                                dashboardViewModel.handleOrganizeAnimationComplete(for: file.path)
                            }
                        )
                        .transition(
                            .asymmetric(
                                insertion: .opacity,
                                removal: .scale(scale: 0.8).combined(with: .opacity)
                            )
                        )
                    }
                }
                }
            }
            .padding(.top, contentTopPadding + scrollContentTopInset)
            .padding(.bottom, fabReservedSpace)
        }
        .frame(maxHeight: .infinity) // Fill available space
        .background(Color.clear)
        .accessibilityIdentifier("fileListScrollView")
    }

    static func makePredicate(selection: NavigationSelection, searchText: String, activeChips: Set<FileFilterChip>) -> Predicate<FileItem> {
        let search = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let hasSearch = !search.isEmpty
        
        let hasRecent = activeChips.contains(.recent)
        let recentDate = Date().addingTimeInterval(-86400 * 7) // 7 days
        
        let hasLarge = activeChips.contains(.largeFiles)
        let largeSize: Int64 = 50 * 1024 * 1024 // 50 MB
        
        switch selection {
        case .home:
            return #Predicate<FileItem> { file in
                (!hasSearch || file.name.localizedStandardContains(search))
                && (!hasRecent || file.creationDate > recentDate)
                && (!hasLarge || file.sizeInBytes > largeSize)
            }
        case .desktop:
            return #Predicate<FileItem> { file in
                file.path.contains("/Desktop/")
                && (!hasSearch || file.name.localizedStandardContains(search))
                && (!hasRecent || file.creationDate > recentDate)
                && (!hasLarge || file.sizeInBytes > largeSize)
            }
        case .downloads:
            return #Predicate<FileItem> { file in
                file.path.contains("/Downloads/")
                && (!hasSearch || file.name.localizedStandardContains(search))
                && (!hasRecent || file.creationDate > recentDate)
                && (!hasLarge || file.sizeInBytes > largeSize)
            }
        case .documents:
            return #Predicate<FileItem> { file in
                file.path.contains("/Documents/")
                && (!hasSearch || file.name.localizedStandardContains(search))
                && (!hasRecent || file.creationDate > recentDate)
                && (!hasLarge || file.sizeInBytes > largeSize)
            }
        case .pictures:
            return #Predicate<FileItem> { file in
                file.path.contains("/Pictures/")
                && (!hasSearch || file.name.localizedStandardContains(search))
                && (!hasRecent || file.creationDate > recentDate)
                && (!hasLarge || file.sizeInBytes > largeSize)
            }
        case .music:
            return #Predicate<FileItem> { file in
                file.path.contains("/Music/")
                && (!hasSearch || file.name.localizedStandardContains(search))
                && (!hasRecent || file.creationDate > recentDate)
                && (!hasLarge || file.sizeInBytes > largeSize)
            }
        case .nestedFolder(let base, _, _):
            let folderPath = "/\(base.displayName)/"
            return #Predicate<FileItem> { file in
                file.path.contains(folderPath)
                && (!hasSearch || file.name.localizedStandardContains(search))
                && (!hasRecent || file.creationDate > recentDate)
                && (!hasLarge || file.sizeInBytes > largeSize)
            }
        case .category(let cat):
            let exts = cat.extensions
            return #Predicate<FileItem> { file in
                exts.contains(file.fileExtension)
                && (!hasSearch || file.name.localizedStandardContains(search))
                && (!hasRecent || file.creationDate > recentDate)
                && (!hasLarge || file.sizeInBytes > largeSize)
            }
        case .analytics:
            return #Predicate<FileItem> { _ in false }
        case .rules:
            // Rules view doesn't show files, return an empty predicate
            return #Predicate<FileItem> { _ in false }
        }
    }
}
