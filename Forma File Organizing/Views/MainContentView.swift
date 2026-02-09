import SwiftUI
import SwiftData
import AppKit

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

    // First-run suggestion banner
    @AppStorage("firstRunBannerDismissCount") private var firstRunBannerDismissCount = 0
    @State private var firstRunBannerDismissedThisSession = false
    
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
            switch nav.selection {
            case .desktop: _ = await dashboardViewModel.requestDesktopAccess()
            case .downloads: _ = await dashboardViewModel.requestDownloadsAccess()
            case .documents: _ = await dashboardViewModel.requestDocumentsAccess()
            case .pictures: _ = await dashboardViewModel.requestPicturesAccess()
            case .music: _ = await dashboardViewModel.requestMusicAccess()
            default: break
            }
        }
    }

    /// Whether the first-run suggestion banner should be shown
    private var shouldShowFirstRunBanner: Bool {
        UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        && firstRunBannerDismissCount < 3
        && !firstRunBannerDismissedThisSession
        && !dashboardViewModel.visibleFiles.isEmpty
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
            // Align toolbar to sidebar's visual top (traffic lights clearance)
            Color.clear.frame(height: FormaSpacing.Toolbar.topOffset)

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
                        .padding(.top, unifiedToolbarHeight + FormaLayout.Toolbar.bottomToContentSpacing)
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
                                .padding(.top, unifiedToolbarHeight + FormaLayout.Toolbar.bottomToContentSpacing)
                        } else {
                            VStack(spacing: FormaSpacing.generous) {
                                // Show active filters above empty state
                                ActiveFiltersBar(
                                    searchText: dashboardViewModel.searchText,
                                    category: dashboardViewModel.selectedCategory,
                                    secondaryFilter: dashboardViewModel.selectedSecondaryFilter,
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
                            .padding(.top, unifiedToolbarHeight + FormaLayout.Toolbar.bottomToContentSpacing)
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
                        .guidedTourRegion(.mainFileList)
                        .animation(.easeInOut(duration: 0.2), value: dashboardViewModel.currentViewMode)
                    }
                }

                // TaperedFocusOverlay removed - fade effect didn't look right

                UnifiedToolbar(availableWidth: availableWidth)
                    .padding(.horizontal, FormaLayout.Gutters.center)
                    .padding(.bottom, FormaLayout.Toolbar.bottomToContentSpacing)
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .preference(key: UnifiedToolbarHeightKey.self, value: proxy.size.height)
                        }
                    )
                    .onPreferenceChange(UnifiedToolbarHeightKey.self) { newHeight in
                        unifiedToolbarHeight = newHeight
                    }
                    .zIndex(10)
            }

            KeyCaptureView { event in
                handleKeyEvent(event)
            }
            .frame(width: 0, height: 0)

            #if DEBUG
            if isUITesting {
                uiTestShortcutHandlers
                Group {
                    if dashboardViewModel.editingDestinationFile != nil {
                        Color.clear
                            .accessibilityIdentifier("editDestinationSheet")
                    }
                    if nav.isShowingRuleEditor {
                        Color.clear
                            .accessibilityIdentifier("ruleEditorView")
                    }
                }
                .frame(width: 0, height: 0)
            }
            #endif
            
        } // End VStack
        
        
        // Floating Action Bar - Direct ZStack child
        // Show in Selection mode OR Review mode (needs review filter)
        if dashboardViewModel.isSelectionMode {
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
        dashboardViewModel.selectFolder(folder)
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
                    nav.ruleEditorFileContext = focused
                    withAnimation(.easeInOut(duration: 0.2)) {
                        nav.isShowingRuleEditor = true
                    }
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
                    nav.ruleEditorFileContext = focused
                    withAnimation(.easeInOut(duration: 0.2)) {
                        nav.isShowingRuleEditor = true
                    }
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
    
    // MARK: - View Mode Implementations (Phase 3)
    // Grid column count is now adaptive in gridView below

    private var contentHorizontalPadding: CGFloat { FormaLayout.Gutters.center }
    private var contentMaxWidth: CGFloat { max(0, availableWidth - (contentHorizontalPadding * 2)) }

    private var contentTopPadding: CGFloat { FormaLayout.Content.topPadding }
    private var scrollContentTopInset: CGFloat { unifiedToolbarHeight + FormaLayout.Toolbar.bottomToContentSpacing }
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

    @ViewBuilder
    private var firstRunBannerIfNeeded: some View {
        if shouldShowFirstRunBanner {
            FirstRunSuggestionBanner(
                fileCount: dashboardViewModel.visibleFiles.count,
                folderName: dashboardViewModel.selectedFolder.displayName,
                onOrganize: {
                    dashboardViewModel.organizeAllReadyFiles(context: modelContext)
                    firstRunBannerDismissedThisSession = true
                },
                onDismiss: {
                    firstRunBannerDismissCount += 1
                    firstRunBannerDismissedThisSession = true
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
        ScrollView {
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
                                searchMatchType: dashboardViewModel.searchMatchType(for: file),
                                contentSnippet: dashboardViewModel.contentSnippet(for: file),
                                availableDestinations: availableDestinations,
                                onChangeDestination: { item, destination in
                                    item.destination = destination
                                    item.status = .ready
                                    dashboardViewModel.filterViewModel.applyFilterImmediately()
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
                                    nav.ruleEditorFileContext = item
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        nav.isShowingRuleEditor = true
                                    }
                                },
                                onViewRule: nil,
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
        ScrollView {
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
            searchMatchType: dashboardViewModel.searchMatchType(for: file),
            onToggleSelection: { handleSelectionToggle(for: file) },
            onOrganize: { organizeFileWithAnimation(file) },
            onEdit: { dashboardViewModel.beginEditingDestination(for: file) },
            onSkip: { dashboardViewModel.skipFile(file) },
            onQuickLook: { dashboardViewModel.showQuickLook(for: file) },
            matchingRules: dashboardViewModel.getMatchingRules(for: file),
            onCreateRule: {
                nav.ruleEditorFileContext = file
                withAnimation(.easeInOut(duration: 0.2)) {
                    nav.isShowingRuleEditor = true
                }
            },
            onApplyRule: { rule in
                dashboardViewModel.applyRule(rule, to: file)
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
        ScrollView {
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
