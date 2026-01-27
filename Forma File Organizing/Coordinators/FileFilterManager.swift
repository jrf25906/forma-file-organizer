import Foundation
import Combine

/// Manages file filtering, searching, and view caching for the dashboard.
@MainActor
class FileFilterManager: ObservableObject {
    // MARK: - Published State
    
    @Published var filteredFiles: [FileItem] = []
    @Published var selectedCategory: FileTypeCategory = .all
    @Published var selectedFolder: FolderLocation = .home
    @Published var searchText: String = ""
    @Published var selectedSecondaryFilter: SecondaryFilter = .none

    /// File paths that matched content search (set by DashboardViewModel after content search completes)
    var contentMatchedPaths: Set<String> = []
    @Published var reviewFilterMode: ReviewFilterMode = .needsReview
    @Published var groupingMode: FileGroupingService.GroupingMode = .date
    
    // MARK: - Cached Values (Performance Optimization)
    
    @Published private(set) var cachedVisibleFiles: [FileItem] = []
    @Published private(set) var cachedGroupedFiles: [FileGroup] = []
    @Published private(set) var cachedNeedsReviewCount: Int = 0
    @Published private(set) var cachedReviewableFiles: [FileItem] = []
    
    // MARK: - Private State
    
    private var cachedFilteredFiles: [FileItem] = []
    private var lastFilterHash: Int = 0
    private var fileListGeneration: Int = 0
    private var filterDebounceTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Services
    
    private let groupingService = FileGroupingService()
    
    // MARK: - Configuration
    
    private static let filterDebounceDelay: Duration = .milliseconds(150)
    private static let largeFileSizeThresholdMB = FormaConfig.Limits.largeFileSizeThresholdMB
    
    // MARK: - Initialization
    
    init() {
        setupFilterObservers()
    }
    
    // MARK: - Public Interface
    
    /// Updates the source files and triggers filtering
    func updateSourceFiles(_ files: [FileItem]) {
        invalidateFilterCache()
        applyFilter(to: files)
    }
    
    /// Apply filters immediately (no debouncing)
    func applyFilterImmediately(to allFiles: [FileItem]) {
        applyFilter(to: allFiles)
    }

    /// Atomically updates multiple filter properties and applies a single filter pass.
    /// Use this instead of setting individual properties when clearing or resetting filters
    /// to avoid multiple re-render cycles (O(n) properties → O(1) render).
    func batchUpdateFilters(
        searchText: String? = nil,
        category: FileTypeCategory? = nil,
        folder: FolderLocation? = nil,
        secondaryFilter: SecondaryFilter? = nil,
        reviewFilterMode: ReviewFilterMode? = nil,
        groupingMode: FileGroupingService.GroupingMode? = nil,
        allFiles: [FileItem]
    ) {
        // Update properties without triggering individual re-renders
        if let searchText = searchText {
            self.searchText = searchText
        }
        if let category = category {
            self.selectedCategory = category
        }
        if let folder = folder {
            self.selectedFolder = folder
        }
        if let secondaryFilter = secondaryFilter {
            self.selectedSecondaryFilter = secondaryFilter
        }
        if let reviewFilterMode = reviewFilterMode {
            self.reviewFilterMode = reviewFilterMode
        }
        if let groupingMode = groupingMode {
            self.groupingMode = groupingMode
        }

        // Single filter application for all changes
        invalidateFilterCache()
        applyFilter(to: allFiles)
    }

    /// Convenience method to reset all filters to defaults
    func resetAllFilters(allFiles: [FileItem]) {
        batchUpdateFilters(
            searchText: "",
            category: .all,
            folder: .home,
            secondaryFilter: SecondaryFilter.none,
            reviewFilterMode: .needsReview,
            allFiles: allFiles
        )
    }

    /// Debounced filter application for reactive properties.
    /// Uses a closure to fetch files at execution time (not invocation time),
    /// ensuring filters always run against the current file list.
    func applyFilterDebounced(filesProvider: @escaping () -> [FileItem]) {
        // In unit tests, apply immediately to keep behavior deterministic
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        if isRunningTests {
            applyFilter(to: filesProvider())
            return
        }

        // Cancel previous debounce task
        filterDebounceTask?.cancel()

        // Start new debounce timer - filesProvider is captured and called at execution time
        filterDebounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.filterDebounceDelay)
            guard let self else { return }

            if !Task.isCancelled {
                // Fetch current files at execution time, not at debounce start
                let currentFiles = filesProvider()
                self.applyFilter(to: currentFiles)
            }
        }
    }

    /// Convenience overload for backward compatibility - captures files at invocation time.
    /// Prefer using the closure-based version for reactive contexts where files may change.
    func applyFilterDebounced(to allFiles: [FileItem]) {
        applyFilterDebounced(filesProvider: { allFiles })
    }
    
    /// Returns visible files after applying all filters
    var visibleFiles: [FileItem] {
        cachedVisibleFiles
    }
    
    /// Count of files needing review
    var needsReviewCount: Int {
        cachedNeedsReviewCount
    }
    
    /// Count of all actionable files (excluding completed)
    var allFilesCount: Int {
        filteredFiles.filter { $0.status != .completed }.count
    }
    
    /// Files that can be reviewed (pending or ready)
    var reviewableFiles: [FileItem] {
        cachedReviewableFiles
    }
    
    /// Grouped files for display
    var groupedFiles: [FileGroup] {
        cachedGroupedFiles
    }
    
    // MARK: - Private Methods
    
    private func setupFilterObservers() {
        // No need to observe @Published properties manually - they already trigger objectWillChange
        // Debouncing is handled via applyFilterDebounced() called from DashboardViewModel
    }
    
    /// Invalidates the filter cache by incrementing the generation counter.
    /// Call this whenever source files change to prevent hash collisions.
    private func invalidateFilterCache() {
        fileListGeneration += 1
    }
    
    /// Computed hash of current filter state
    private var filterStateHash: Int {
        var hasher = Hasher()
        hasher.combine(fileListGeneration)
        hasher.combine(searchText)
        hasher.combine(selectedCategory)
        hasher.combine(selectedFolder)
        hasher.combine(reviewFilterMode)
        hasher.combine(selectedSecondaryFilter)
        hasher.combine(groupingMode)
        return hasher.finalize()
    }
    
    /// Core filtering logic
    private func applyFilter(to allFiles: [FileItem]) {
        let currentHash = filterStateHash
        
        // Return cached result if nothing changed
        if currentHash == lastFilterHash && !cachedFilteredFiles.isEmpty {
            filteredFiles = cachedFilteredFiles
            // Even if the base filtered set hasn't changed, derived caches
            // (visibleFiles, groupedFiles, needsReviewCount) depend on
            // reviewFilterMode, selectedSecondaryFilter, and groupingMode.
            updateCachedValues()
            return
        }
        
        var files = allFiles
        
        // 1. Filter by Search Text (includes both filename and content matches)
        if !searchText.isEmpty {
            let lowercasedSearch = searchText.lowercased()
            files = files.filter { file in
                // Match by filename OR by content (from content search results)
                file.name.lowercased().contains(lowercasedSearch) ||
                contentMatchedPaths.contains(file.path)
            }
        }
        
        // 2. Filter by Category
        if selectedCategory != .all {
            files = files.filter { $0.category == selectedCategory }
        }
        
        // 3. Filter by Folder Location
        if selectedFolder != .home {
            files = files.filter { file in
                switch selectedFolder {
                case .home: return true
                case .desktop: return isInStandardLocation(file, kind: .desktop, legacySubstring: "/Desktop/")
                case .downloads: return isInStandardLocation(file, kind: .downloads, legacySubstring: "/Downloads/")
                case .documents: return isInStandardLocation(file, kind: .documents, legacySubstring: "/Documents/")
                case .pictures: return isInStandardLocation(file, kind: .pictures, legacySubstring: "/Pictures/")
                case .music: return isInStandardLocation(file, kind: .music, legacySubstring: "/Music/")
                }
            }
        }
        
        // Cache the result
        filteredFiles = files
        cachedFilteredFiles = files
        lastFilterHash = currentHash
        
        // Update derived caches
        updateCachedValues()
        
        #if DEBUG
        Log.debug("applyFilter: allFiles=\(allFiles.count), filteredFiles=\(filteredFiles.count)", category: .pipeline)
        #endif
    }
    
    /// Helper to determine if a file belongs to a standard top-level location.
    /// Uses FileLocationKind when available, with a legacy path-based fallback
    /// for older records and test fixtures.
    private func isInStandardLocation(_ file: FileItem, kind: FileLocationKind, legacySubstring: String) -> Bool {
        if file.location == kind { return true }
        // Legacy or unknown: fall back to path substring check
        if file.location == .unknown && file.path.contains(legacySubstring) {
            return true
        }
        return false
    }

    /// Updates all cached computed values. Call when filteredFiles, reviewFilterMode,
    /// selectedSecondaryFilter, or groupingMode changes.
    private func updateCachedValues() {
        // Update visible files
        var files = filteredFiles
        
        // Exclude completed files by default
        files = files.filter { $0.status != .completed }
        
        // Needs Review vs All Files
        switch reviewFilterMode {
        case .needsReview:
            files = files.filter { file in
                let isPending = file.status == .pending
                let isReady = file.status == .ready
                let noDestination = file.destination == nil
                return isPending || isReady || noDestination
            }
        case .all:
            break
        }
        
        // Secondary filters
        switch selectedSecondaryFilter {
        case .none:
            // Preserve original ordering from filteredFiles when no
            // secondary filter is active. This keeps keyboard navigation
            // predictable and aligned with scan order.
            break
        case .recent:
            files.sort { $0.creationDate > $1.creationDate }
        case .largeFiles:
            let threshold = Self.largeFileSizeThresholdMB * 1024 * 1024
            files = files.filter { $0.sizeInBytes >= threshold }
            files.sort { $0.sizeInBytes > $1.sizeInBytes }
        case .flagged:
            // Placeholder: until we support a flagged property, leave files unchanged
            break
        }
        
        cachedVisibleFiles = files
        
        // Update grouped files
        cachedGroupedFiles = groupingService.groupFiles(files, mode: groupingMode)
        
        // Update needs review count - must match the Review mode filter criteria
        let nonCompletedFiles = filteredFiles.filter { $0.status != .completed }
        cachedNeedsReviewCount = nonCompletedFiles.filter { file in
            let isPending = file.status == .pending
            let isReady = file.status == .ready
            let noDestination = file.destination == nil
            return isPending || isReady || noDestination
        }.count
        
        #if DEBUG
        Log.debug("FILTERING BREAKDOWN — after category/location filter: \(filteredFiles.count)", category: .pipeline)
        let completedCount = filteredFiles.filter { $0.status == .completed }.count
        Log.debug("Completed (hidden by default): \(completedCount)", category: .pipeline)
        Log.debug("Visible after status filter: \(cachedVisibleFiles.count)", category: .pipeline)
        Log.debug("Review mode: \(reviewFilterMode)", category: .pipeline)
        if reviewFilterMode == .needsReview {
            let pendingCount = filteredFiles.filter { $0.status == .pending || $0.destination == nil }.count
            Log.debug("Files needing review: \(pendingCount)", category: .pipeline)
        }
        let readyCount = filteredFiles.filter { $0.status == .ready }.count
        Log.debug("Ready to organize: \(readyCount)", category: .pipeline)
        #endif
        
        // Update reviewable files (for floating action bar)
        cachedReviewableFiles = filteredFiles.filter { $0.status == .pending || $0.status == .ready }
    }
}
