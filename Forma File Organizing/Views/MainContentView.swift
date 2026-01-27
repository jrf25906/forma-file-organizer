import SwiftUI
import SwiftData
import AppKit

struct MainContentView: View {
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
    @State private var showKeyboardHelp = false

    // Command palette (⌘K)
    @State private var showCommandPalette = false

    @State private var unifiedToolbarHeight: CGFloat = 0
    
    init(selection: NavigationSelection, searchText: String, activeChips: Set<FileFilterChip>, availableWidth: CGFloat) {
        self.availableWidth = availableWidth
        // selection, searchText, and activeChips are currently handled via
        // DashboardViewModel state rather than a local @Query.
    }
    
    /// Whether the floating action bar should be displayed
    private var shouldShowFAB: Bool {
        dashboardViewModel.isSelectionMode ||
        (dashboardViewModel.reviewFilterMode == .needsReview && !dashboardViewModel.reviewableFiles.isEmpty)
    }

    var body: some View {
        ZStack(alignment: .bottom) { // Use ZStack as root for overlay alignment
            VStack(alignment: .leading, spacing: 0) {
            // Align toolbar to sidebar's visual top (traffic lights clearance)
            Color.clear.frame(height: FormaSpacing.Toolbar.topOffset)

            ZStack(alignment: .top) {
                // Content
                Group {
                    if dashboardViewModel.isLoading && dashboardViewModel.visibleFiles.isEmpty {
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
                                .background(.ultraThinMaterial)
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
                        // Include contentSearchResultsCount in id so view re-renders when search results change
                        .id("\(dashboardViewModel.currentViewMode.rawValue)-\(dashboardViewModel.contentSearchResultsCount)")
                        .animation(.easeInOut(duration: 0.2), value: dashboardViewModel.currentViewMode)
                    }
                }

                // TaperedFocusOverlay removed - fade effect didn't look right

                UnifiedToolbar(availableWidth: availableWidth, showKeyboardHelp: $showKeyboardHelp)
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
            .padding(.bottom, FormaSpacing.large + FormaSpacing.tight)
        } else if dashboardViewModel.reviewFilterMode == .needsReview && !dashboardViewModel.reviewableFiles.isEmpty {
            // Review mode floating action bar - use cached reviewableFiles
            FloatingActionBar(
                mode: .review,
                count: dashboardViewModel.reviewableFiles.count,
                canOrganizeAll: dashboardViewModel.reviewableFiles.contains { $0.status == .ready },
                onOrganize: {
                    dashboardViewModel.organizeAllReadyFiles(context: modelContext)
                },
                onSkip: {
                    dashboardViewModel.skipAllPendingFiles()
                },
                onBulkEdit: nil,
                onDeselect: nil
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .zIndex(100)
            .padding(.bottom, FormaSpacing.large + FormaSpacing.tight)
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
                            // TODO: Implement cancellation logic
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
        .sheet(item: $dashboardViewModel.editingDestinationFile) { file in
            EditDestinationSheet(file: file) { newDestination in
                dashboardViewModel.updateDestination(for: file, to: newDestination)
            }
            .accessibilityIdentifier("editDestinationSheet")
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
    
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        // Ignore if text input is focused (except maybe Cmd shortcuts, but for now ignore all to be safe)
        if let window = NSApp.keyWindow,
           let responder = window.firstResponder as? NSView,
           responder is NSTextView || responder is NSTextField {
            return false
        }
        
        let command = event.modifierFlags.contains(.command)
        let keyCode = event.keyCode
        let chars = event.charactersIgnoringModifiers ?? ""
        
        // Cmd+Enter: organize and move focus to next
        if command && keyCode == 36 { // Return
            dashboardViewModel.organizeFocusedFile(context: modelContext)
            dashboardViewModel.focusNextFile()
            return true
        }

        // Cmd+K: Open command palette
        if command && chars.lowercased() == "k" {
            showCommandPalette = true
            return true
        }

        // Enter: organize focused file
        if keyCode == 36 { // Return
            dashboardViewModel.organizeFocusedFile(context: modelContext)
            return true
        }
        
        // Space: Quick Look
        if chars == " " {
            dashboardViewModel.quickLookFocusedFile()
            return true
        }
        
        // Navigation: Down / J, Up / K
        if keyCode == 125 || chars.lowercased() == "j" { // Down arrow or J
            dashboardViewModel.focusNextFile()
            return true
        }
        if keyCode == 126 || chars.lowercased() == "k" { // Up arrow or K
            dashboardViewModel.focusPreviousFile()
            return true
        }
        
        // S: Skip
        if chars.lowercased() == "s" {
            dashboardViewModel.skipFocusedFile()
            return true
        }
        
        // E: Edit destination (stubbed)
        if chars.lowercased() == "e" {
            dashboardViewModel.editDestinationForFocusedFile()
            return true
        }
        
        // R: Create/View rule from focused file
        if chars.lowercased() == "r" {
            if let focusedPath = dashboardViewModel.focusedFilePath {
                if let focused = dashboardViewModel.visibleFiles.first(where: { $0.path == focusedPath }) {
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

    private var gridColumnSpacing: CGFloat { FormaSpacing.standard }
    private var gridRowSpacing: CGFloat { FormaSpacing.extraLarge }

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
                    LazyVStack(spacing: FormaSpacing.large) {
                        ForEach(dashboardViewModel.visibleFiles) { file in
                            FileRow(
                                file: file,
                                isFocused: dashboardViewModel.focusedFilePath == file.path,
                                isSelected: dashboardViewModel.isSelected(file),
                                isSelectionMode: dashboardViewModel.isSelectionMode,
                                showKeyboardHints: dashboardViewModel.isKeyboardNavigating,
                                searchMatchType: dashboardViewModel.searchMatchType(for: file),
                                contentSnippet: dashboardViewModel.contentSnippet(for: file),
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
                                    dashboardViewModel.toggleSelection(for: item)
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
                            // Force view identity to include content search state
                            .id("\(file.id)-\(dashboardViewModel.contentSearchResultsCount)")
                        }
                    }
                }
                // Establish explicit dependency on content search results for SwiftUI observation
                .id(dashboardViewModel.contentSearchResultsCount)
            }
            .padding(.top, contentTopPadding + scrollContentTopInset)
            .padding(.bottom, shouldShowFAB ? FormaSpacing.huge + FormaSpacing.extraLarge : FormaSpacing.generous)
        }
        .frame(maxHeight: .infinity) // Fill available space
        .background(Color.clear)
        .accessibilityIdentifier("fileListScrollView")
    }

    private var listView: some View {
        ScrollView {
            contentContainer {
                listViewContent
            }
            .padding(.top, contentTopPadding + scrollContentTopInset)
            .padding(.bottom, shouldShowFAB ? FormaSpacing.huge + FormaSpacing.extraLarge : FormaSpacing.generous)
        }
        .frame(maxHeight: .infinity)
        .background(Color.clear)
        .accessibilityIdentifier("fileListScrollView")
    }

    // MARK: - List View Content (Extracted for Type Inference)

    @ViewBuilder
    private var listViewContent: some View {
        LazyVStack(spacing: FormaSpacing.tight) {
            ForEach(Array(dashboardViewModel.visibleFiles.enumerated()), id: \.element.id) { index, file in
                listFileRow(file: file, index: index)
            }
        }
        .id(dashboardViewModel.contentSearchResultsCount)
    }

    @ViewBuilder
    private func listFileRow(file: FileItem, index: Int) -> some View {
        FileListRow(
            file: file,
            rowIndex: index,
            isFocused: dashboardViewModel.focusedFilePath == file.path,
            isSelected: dashboardViewModel.isSelected(file),
            isSelectionMode: dashboardViewModel.isSelectionMode,
            searchMatchType: dashboardViewModel.searchMatchType(for: file),
            onToggleSelection: { dashboardViewModel.toggleSelection(for: file) },
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
        .id("\(file.id)-\(dashboardViewModel.contentSearchResultsCount)")
    }

    private var gridView: some View {
        ScrollView {
            let columns = [
                GridItem(.adaptive(minimum: 180, maximum: 240), spacing: gridColumnSpacing)
            ]
            contentContainer {
                LazyVGrid(
                    columns: columns,
                    alignment: .leading,
                    spacing: gridRowSpacing
                ) {
                    // Use flat visibleFiles list to avoid duplicate IDs from grouping
                    ForEach(dashboardViewModel.visibleFiles) { file in
                        FileGridItem(
                            file: file,
                            isFocused: dashboardViewModel.focusedFilePath == file.path,
                            isSelected: dashboardViewModel.isSelected(file),
                            isSelectionMode: dashboardViewModel.isSelectionMode,
                            searchMatchType: dashboardViewModel.searchMatchType(for: file),
                            onToggleSelection: {
                                dashboardViewModel.toggleSelection(for: file)
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
                        // Force re-render when content search results change
                        .id("\(file.id)-\(dashboardViewModel.contentSearchResultsCount)")
                    }
                }
                // Force re-render of grid when content search results change
                .id(dashboardViewModel.contentSearchResultsCount)
            }
            .padding(.top, contentTopPadding + scrollContentTopInset)
            .padding(.bottom, shouldShowFAB ? FormaSpacing.huge + FormaSpacing.extraLarge : FormaSpacing.generous)
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
