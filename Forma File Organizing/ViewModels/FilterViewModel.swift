import Foundation
import SwiftUI
import Combine

/// Manages file filtering, search, category selection, and view modes.
/// Responsible for:
/// - Category and folder filtering
/// - Search (filename + content)
/// - Secondary filters (Large Files, Recent, etc.)
/// - View mode preferences (card/list/grid)
/// - Grouping modes
@MainActor
class FilterViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Filtered files based on current filters
    @Published private(set) var filteredFiles: [FileItem] = []

    /// Selected category (All, Documents, Images, etc.)
    @Published var selectedCategory: FileTypeCategory = .all {
        didSet {
            applyFilterDebounced()
            // Update view mode when category changes
            currentViewMode = viewModeForCategory(selectedCategory)
        }
    }

    /// Selected folder location
    @Published var selectedFolder: FolderLocation = .home {
        didSet {
            applyFilterDebounced()
        }
    }

    /// Search query
    @Published var searchText: String = "" {
        didSet {
            applyFilterDebounced()
        }
    }

    /// Secondary filter (Large Files, Recent, etc.)
    @Published var selectedSecondaryFilter: SecondaryFilter = .none {
        didSet {
            applyFilterDebounced()
        }
    }

    /// Review filter mode (Needs Review vs All)
    @Published var reviewFilterMode: ReviewFilterMode = .needsReview {
        didSet {
            applyFilterDebounced()
        }
    }

    /// Grouping mode for file groups
    @Published var groupingMode: FileGroupingService.GroupingMode = .date {
        didSet {
            updateCachedGroups()
        }
    }

    /// Current view mode (card/list/grid)
    @Published var currentViewMode: ViewMode = .card

    // MARK: - Cached Computed Properties

    /// Cached visible files (for Review mode)
    @Published private(set) var cachedVisibleFiles: [FileItem] = []

    /// Cached grouped files
    @Published private(set) var cachedGroupedFiles: [FileGroup] = []

    /// Cached count of files needing review
    @Published private(set) var cachedNeedsReviewCount: Int = 0

    /// Cached reviewable files
    @Published private(set) var cachedReviewableFiles: [FileItem] = []

    // MARK: - Dependencies

    private let filterManager: FileFilterManager

    // MARK: - Private State

    private var allFiles: [FileItem] = []
    private var cancellables = Set<AnyCancellable>()
    private var filterDebounceTask: Task<Void, Never>?

    // MARK: - View Mode Persistence

    @AppStorage("viewMode.all") private var allViewMode: ViewMode = .card
    @AppStorage("viewMode.documents") private var documentsViewMode: ViewMode = .list
    @AppStorage("viewMode.images") private var imagesViewMode: ViewMode = .grid
    @AppStorage("viewMode.videos") private var videosViewMode: ViewMode = .card
    @AppStorage("viewMode.audio") private var audioViewMode: ViewMode = .list
    @AppStorage("viewMode.archives") private var archivesViewMode: ViewMode = .list

    // MARK: - Configuration

    private static let debounceDelay: Duration = .milliseconds(150)

    // MARK: - Initialization

    init(filterManager: FileFilterManager = FileFilterManager()) {
        self.filterManager = filterManager
        setupFilterForwarding()
        applyPersonalityPreferences()
    }

    // MARK: - Public Interface

    /// Update source files and re-apply filters
    func updateSourceFiles(_ files: [FileItem]) {
        allFiles = files
        syncFilterStateToManager()
        filterManager.updateSourceFiles(files)
        syncFromFilterManager()
    }

    /// Apply filter immediately (no debouncing)
    func applyFilterImmediately() {
        syncFilterStateToManager()
        filterManager.applyFilterImmediately(to: allFiles)
        syncFromFilterManager()
    }

    /// Clear all filters atomically
    func clearAllFilters() {
        searchText = ""
        selectedCategory = .all
        selectedSecondaryFilter = .none
        applyFilterImmediately()
    }

    /// Set view mode and persist preference for current category
    func setViewMode(_ mode: ViewMode) {
        currentViewMode = mode

        // Save preference for current category
        switch selectedCategory {
        case .all: allViewMode = mode
        case .documents: documentsViewMode = mode
        case .images: imagesViewMode = mode
        case .videos: videosViewMode = mode
        case .audio: audioViewMode = mode
        case .archives: archivesViewMode = mode
        }
    }

    // MARK: - Convenience Accessors

    /// Visible files (alias for filteredFiles)
    var visibleFiles: [FileItem] {
        filteredFiles
    }

    /// Count of files needing review
    var needsReviewCount: Int {
        cachedNeedsReviewCount
    }

    /// All files count
    var allFilesCount: Int {
        allFiles.count
    }

    /// Reviewable files (pending or ready)
    var reviewableFiles: [FileItem] {
        cachedReviewableFiles
    }

    /// Grouped files
    var groupedFiles: [FileGroup] {
        cachedGroupedFiles
    }

    // MARK: - Content Search Support

    /// Set paths that matched content search (from ContentSearchService)
    func setContentMatchedPaths(_ paths: Set<String>) {
        filterManager.contentMatchedPaths = paths
        applyFilterDebounced()
    }

    // MARK: - Private Helpers

    /// Apply filter with debouncing
    private func applyFilterDebounced() {
        filterDebounceTask?.cancel()

        filterDebounceTask = Task { [weak self] in
            guard let self else { return }

            do {
                try await Task.sleep(for: Self.debounceDelay)
            } catch {
                return // Cancelled
            }

            guard !Task.isCancelled else { return }

            self.syncFilterStateToManager()
            self.filterManager.applyFilterImmediately(to: self.allFiles)
            self.syncFromFilterManager()
        }
    }

    /// Sync state from FilterManager to this ViewModel
    private func syncFromFilterManager() {
        filteredFiles = filterManager.filteredFiles
        cachedVisibleFiles = filterManager.cachedVisibleFiles
        cachedGroupedFiles = filterManager.cachedGroupedFiles
        cachedNeedsReviewCount = filterManager.cachedNeedsReviewCount
        cachedReviewableFiles = filterManager.cachedReviewableFiles
    }

    /// Update cached groups when grouping mode changes
    private func updateCachedGroups() {
        syncFilterStateToManager()
        filterManager.groupingMode = groupingMode
        filterManager.applyFilterImmediately(to: allFiles)
        syncFromFilterManager()
    }

    /// Setup forwarding from FilterManager
    private func setupFilterForwarding() {
        filterManager.objectWillChange
            .sink { [weak self] _ in
                self?.syncFromFilterManager()
            }
            .store(in: &cancellables)
    }

    private func syncFilterStateToManager() {
        filterManager.searchText = searchText
        filterManager.selectedCategory = selectedCategory
        filterManager.selectedFolder = selectedFolder
        filterManager.selectedSecondaryFilter = selectedSecondaryFilter
        filterManager.reviewFilterMode = reviewFilterMode
        filterManager.groupingMode = groupingMode
    }

    /// Get view mode for a specific category
    func viewModeForCategory(_ category: FileTypeCategory) -> ViewMode {
        switch category {
        case .all: return allViewMode
        case .documents: return documentsViewMode
        case .images: return imagesViewMode
        case .videos: return videosViewMode
        case .audio: return audioViewMode
        case .archives: return archivesViewMode
        }
    }

    /// Apply personality preferences to view modes
    func applyPersonalityPreferences() {
        guard let personality = OrganizationPersonality.load() else { return }

        #if DEBUG
        Log.info("Applying personality preferences: \(personality.organizationStyle.rawValue)", category: .ui)
        #endif

        if personality.organizationStyle == .piler {
            // Pilers prefer visual grid layouts
            if allViewMode == .card { allViewMode = .grid }
            if documentsViewMode == .list { documentsViewMode = .grid }
            if videosViewMode == .card { videosViewMode = .grid }
        } else {
            // Filers prefer list views
            if allViewMode == .card { allViewMode = .list }
            if videosViewMode == .card { videosViewMode = .list }
        }

        currentViewMode = viewModeForCategory(selectedCategory)
    }
}
