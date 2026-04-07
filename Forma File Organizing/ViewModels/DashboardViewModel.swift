import Foundation
import SwiftUI
import SwiftData
import Combine

struct FirstRunQuickWinSuggestion: Equatable {
    enum Kind: String, Equatable {
        case screenshots
        case archives
        case staleDownloads
        case invoices
        case readyBatch

        var priority: Int {
            switch self {
            case .screenshots: 0
            case .archives: 1
            case .staleDownloads: 2
            case .invoices: 3
            case .readyBatch: 4
            }
        }

        var iconName: String {
            switch self {
            case .screenshots: "camera.viewfinder"
            case .archives: "archivebox.fill"
            case .staleDownloads: "tray.full.fill"
            case .invoices: "doc.text.fill"
            case .readyBatch: "sparkles"
            }
        }

        var titleText: String {
            switch self {
            case .screenshots: "Clean up your screenshots"
            case .archives: "Clear out ready archives"
            case .staleDownloads: "Move older Downloads out of the way"
            case .invoices: "File your invoices"
            case .readyBatch: "Organize one ready batch"
            }
        }

        var primaryActionTitle: String {
            switch self {
            case .screenshots: "Organize Screenshots"
            case .archives: "Organize Archives"
            case .staleDownloads: "Organize Older Downloads"
            case .invoices: "File Invoices"
            case .readyBatch: "Organize Batch"
            }
        }
    }

    let kind: Kind
    let folderName: String
    let fileCount: Int
    let destinationSummary: String
    let primaryActionTitle: String
    let candidateKey: String

    var iconName: String { kind.iconName }
    var titleText: String { kind.titleText }

    var detailText: String {
        let noun: String
        switch kind {
        case .screenshots:
            noun = fileCount == 1 ? "screenshot" : "screenshots"
        case .archives:
            noun = fileCount == 1 ? "archive" : "archives"
        case .staleDownloads:
            noun = fileCount == 1 ? "older download" : "older downloads"
        case .invoices:
            noun = fileCount == 1 ? "invoice" : "invoices"
        case .readyBatch:
            noun = fileCount == 1 ? "file" : "files"
        }

        return "\(fileCount) \(noun) from \(folderName) are ready for \(destinationSummary)."
    }
}

struct ExternalReviewPromotionSuggestion: Equatable {
    let folderType: BookmarkFolder.FolderType
    let bookmarkData: Data

    var iconName: String { folderType.iconName }
    var titleText: String { "Keep monitoring \(folderType.displayName)" }
    var detailText: String {
        "\(folderType.displayName) was a one-time review. Add it to monitored folders so new files from it keep appearing automatically."
    }
    var primaryActionTitle: String { "Monitor \(folderType.displayName)" }
}

@MainActor
final class WindowPresentationStore {
    private enum Keys {
        static let inspectorVisible = "windowPresentation.inspectorVisible"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var savedInspectorVisibility: Bool? {
        guard defaults.object(forKey: Keys.inspectorVisible) != nil else { return nil }
        return defaults.bool(forKey: Keys.inspectorVisible)
    }

    func setInspectorVisible(_ isVisible: Bool) {
        defaults.set(isVisible, forKey: Keys.inspectorVisible)
    }

    func resetInspectorVisibility() {
        defaults.removeObject(forKey: Keys.inspectorVisible)
    }
}

struct DashboardLaunchPresentation {
    static let inspectorEligibleWidth: CGFloat = 1500

    let launchWidth: CGFloat
    let hasMeaningfulDefaultPanelContent: Bool

    var defaultInspectorVisibility: Bool {
        launchWidth >= Self.inspectorEligibleWidth && hasMeaningfulDefaultPanelContent
    }
}

/// Coordinator ViewModel that composes focused ViewModels.
/// This is the main entry point for the Dashboard, delegating responsibilities
/// to specialized ViewModels for scanning, filtering, selection, analytics, and bulk operations.
///
/// ARCHITECTURE:
/// - FileScanViewModel: File discovery and scanning
/// - FilterViewModel: Filtering, search, and view modes
/// - SelectionViewModel: Multi-select and keyboard navigation
/// - AnalyticsDashboardViewModel: Storage analytics and insights
/// - BulkOperationViewModel: Batch operations and progress
@MainActor
class DashboardViewModel: ObservableObject {
    private static let permissionRefreshDebounceDelay: Duration = .milliseconds(100)

    private enum FirstRunQuickWinDefaultsKeys {
        static let dismissedCandidateKeys = "dismissedFirstRunQuickWinCandidateKeys"
    }

    private struct FirstRunQuickWinBatch {
        let suggestion: FirstRunQuickWinSuggestion
        let files: [FileItem]
    }

    private struct FirstRunQuickWinBatchKey: Hashable {
        let identifier: String
        let folderName: String
        let kind: FirstRunQuickWinSuggestion.Kind
        let destinationSummary: String

        var storageKey: String {
            "\(kind.rawValue)|\(identifier)|\(destinationSummary)"
        }
    }

    private static let minimumFirstRunQuickWinFileCount = 5
    private static let staleDownloadsThresholdDays = 7

    private struct ReviewChunkScopeKey: Hashable {
        let selectedCategory: FileTypeCategory
        let selectedFolder: FolderLocation
        let selectedRelativeFolderPath: String?
        let includeNestedSubfolders: Bool
        let searchText: String
        let selectedSecondaryFilter: SecondaryFilter
        let selectedContentTags: Set<MetadataContentTag>
        let sortMode: SortMode
        let externalReviewRequestID: UUID?
    }

    private static let defaultReviewChunkSize = 8

    // MARK: - Focused ViewModels (New Architecture)

    /// Manages file scanning and discovery
    @ObservedObject private(set) var scanViewModel: FileScanViewModel

    /// Manages filtering, search, and view modes
    @ObservedObject private(set) var filterViewModel: FilterViewModel

    /// Manages selection and keyboard navigation
    @ObservedObject private(set) var selectionViewModel: SelectionViewModel

    /// Manages analytics and insights
    @ObservedObject private(set) var analyticsViewModel: AnalyticsDashboardViewModel

    /// Manages bulk operations
    @ObservedObject private(set) var bulkOperationViewModel: BulkOperationViewModel

    /// Manages debounced content search orchestration
    @ObservedObject private var contentSearchController: DashboardContentSearchController

    /// Manages scan/refresh orchestration and harness timing
    @ObservedObject private var scanRefreshController: DashboardScanRefreshController

    // MARK: - Legacy Coordinators (Still Needed)

    @ObservedObject private var organizationCoordinator: FileOrganizationCoordinator
    private let undoRedoController: DashboardUndoRedoController
    @ObservedObject private var panelManager = PanelStateManager()
    private let windowPresentationStore: WindowPresentationStore

    // MARK: - Permissions State
    @ObservedObject private(set) var permissionState = DashboardPermissionState()

    // MARK: - UI State
    @Published var isRightPanelVisible: Bool = true
    @Published var errorMessage: String?
    @Published var shouldRequestAppReview: Bool = false

    // MARK: - Organization Progress State
    /// Baseline count of actionable files captured at the start of the current scan session.
    @Published private(set) var organizationProgressTotalCount: Int = 0

    // MARK: - Services
    private let fileSystemService: FileSystemServiceProtocol
    private let storageService: StorageService
    private let ruleEngine = RuleEngine()
    private let fileOperationsService = FileOperationsService()
    private let notificationService: NotificationService
    private let quickLookService: QuickLookService
    private let insightsService: InsightsService
    private let userDefaults: UserDefaults
    private let featureFlags = FeatureFlagService.shared
    // MARK: - Private State
    private var modelContext: ModelContext?
    private var rules: [Rule] = []
    private var cancellables = Set<AnyCancellable>()
    private var bulkOperationTask: Task<Void, Never>?
    private var permissionRefreshTask: Task<Void, Never>?
    private var lastPresentedExternalSessionID: UUID?
    private var deferredReviewPathsByScope: [ReviewChunkScopeKey: Set<String>] = [:]

    // MARK: - Initialization

    init(
        services: AppServices,
        fileSystemService: FileSystemServiceProtocol,
        fileScanPipeline: FileScanPipelineProtocol,
        contentSearchService: ContentSearchServing = ContentSearchService.shared,
        windowPresentationStore: WindowPresentationStore = WindowPresentationStore(),
        userDefaults: UserDefaults = .standard,
        launchPresentation: DashboardLaunchPresentation = DashboardLaunchPresentation(
            launchWidth: FormaSpacing.Window.preferredWidth,
            hasMeaningfulDefaultPanelContent: true
        )
    ) {
        let coordinator = FileOrganizationCoordinator()
        self.organizationCoordinator = coordinator
        self.undoRedoController = DashboardUndoRedoController(coordinator: coordinator)
        self.windowPresentationStore = windowPresentationStore
        self.isRightPanelVisible = windowPresentationStore.savedInspectorVisibility ?? launchPresentation.defaultInspectorVisibility
        self.fileSystemService = fileSystemService
        self.storageService = services.storageService
        self.notificationService = services.notificationService
        self.quickLookService = services.quickLookService
        self.insightsService = services.insightsService
        self.userDefaults = userDefaults
        self.contentSearchController = DashboardContentSearchController(
            contentSearchService: contentSearchService
        )

        // Initialize focused ViewModels
        let scanViewModel = FileScanViewModel(
            fileSystemService: fileSystemService,
            fileScanPipeline: fileScanPipeline
        )
        let filterViewModel = FilterViewModel()
        let selectionViewModel = SelectionViewModel()
        let analyticsViewModel = AnalyticsDashboardViewModel(
            storageService: storageService,
            insightsService: insightsService
        )
        let bulkOperationViewModel = BulkOperationViewModel(
            organizationCoordinator: coordinator,
            notificationService: notificationService
        )
        let scanRefreshController = DashboardScanRefreshController(
            scanViewModel: scanViewModel,
            analyticsViewModel: analyticsViewModel,
            insightsService: insightsService
        )
        self.scanViewModel = scanViewModel
        self.filterViewModel = filterViewModel
        self.selectionViewModel = selectionViewModel
        self.analyticsViewModel = analyticsViewModel
        self.bulkOperationViewModel = bulkOperationViewModel
        self.scanRefreshController = scanRefreshController

        // Setup inter-ViewModel communication
        setupViewModelForwarding()
        setupBulkOperationCallbacks()

        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        let isRunningTests = env["XCTestConfigurationFilePath"] != nil ||
            env["XCTestBundlePath"] != nil ||
            env["XCTestSessionIdentifier"] != nil ||
            env["XCInjectBundleInto"] != nil
        let isUITesting = CommandLine.arguments.contains("--uitesting")

        if !isRunningTests && !isUITesting && CommandLine.arguments.contains("--force-onboarding") {
            if let concreteFS = fileSystemService as? FileSystemService {
                concreteFS.resetAllAccess()
            }
        }

        let shouldRunBookmarkDiagnostics = env["FORMA_RUN_BOOKMARK_DIAGNOSTICS"] == "1"

        if !isRunningTests && !isUITesting && shouldRunBookmarkDiagnostics {
            Log.debug("Running bookmark diagnostics on startup", category: .bookmark, verboseOnly: true)
            fileOperationsService.diagnoseBookmarks()
        }
        #endif

        if CommandLine.arguments.contains("--uitesting") {
            loadMockData()
        } else {
            #if DEBUG
            if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                loadMockData()
            }
            #endif
        }

        checkPermissions()
    }

    convenience init(services: AppServices) {
        self.init(
            services: services,
            fileSystemService: services.fileSystemService,
            fileScanPipeline: services.fileScanPipeline
        )
    }

    convenience init() {
        self.init(services: AppServices())
    }

    deinit {
        bulkOperationTask?.cancel()
        permissionRefreshTask?.cancel()
    }

    func setModelContext(_ context: ModelContext) {
        modelContext = context
        refreshContentTagQuickFilters()

        #if DEBUG
        if CommandLine.arguments.contains("--uitesting") {
            // Seed deterministic UI test data without scanning the real filesystem.
            let descriptor = FetchDescriptor<FileItem>(
                sortBy: [SortDescriptor(\.creationDate, order: .reverse)]
            )
            let fetchedFiles = (try? context.fetch(descriptor)) ?? []
            let files = fetchedFiles.isEmpty ? FileItem.uiTestMocks : fetchedFiles
            filterViewModel.searchText = ""
            filterViewModel.selectedCategory = .all
            filterViewModel.selectedSecondaryFilter = .none
            filterViewModel.selectedFolder = .home
            reviewFilterMode = .needsReview
            filterViewModel.setViewMode(.card)
            _testSetFiles(files)
            filterViewModel.applyFilterImmediately()
        }
        #endif
    }

    // MARK: - File Scanning (Delegated to FileScanViewModel)

    func scanFiles(context: ModelContext) async {
        let loadedRules = loadRules(from: context)
        await scanRefreshController.scanFiles(
            context: context,
            rules: loadedRules,
            actions: makeScanRefreshActions()
        )
    }

    func refresh(context: ModelContext) async {
        await scanFiles(context: context)
    }

    /// Applies an automation-triggered scan result to the dashboard state without re-scanning.
    func applyAutomationScanUpdate(
        scannedPaths: [String] = [],
        scannedRootPaths: [String],
        errorSummary: String?,
        replacesAllFiles: Bool = false,
        context: ModelContext
    ) async {
        await scanRefreshController.applyAutomationScanUpdate(
            scannedPaths: scannedPaths,
            scannedRootPaths: scannedRootPaths,
            errorSummary: errorSummary,
            replacesAllFiles: replacesAllFiles,
            context: context,
            actions: makeScanRefreshActions()
        )
    }

    /// Debug-only harness for deterministic signpost capture of dashboard refresh flows.
    /// Runs multiple automation-style refresh iterations and wraps insight generation
    /// in the same operation the Default Panel uses for refresh timing.
    func runPerformanceSignpostHarness(
        iterations: Int,
        warmupIterations: Int = 3,
        context: ModelContext
    ) async {
        await scanRefreshController.runPerformanceSignpostHarness(
            iterations: iterations,
            warmupIterations: warmupIterations,
            context: context,
            recentActivitiesProvider: { [weak self] in
                self?.recentActivities ?? []
            },
            actions: makeScanRefreshActions()
        )
    }

    /// Refreshes the available folders from BookmarkFolderService
    func refreshAvailableFolders() {
        BookmarkFolderService.shared.refresh()
    }

    // MARK: - Filtering (Delegated to FilterViewModel)

    var filteredFiles: [FileItem] { filterViewModel.filteredFiles }
    var selectedCategory: FileTypeCategory {
        get { filterViewModel.selectedCategory }
        set { filterViewModel.selectedCategory = newValue }
    }
    var selectedFolder: FolderLocation {
        get { filterViewModel.selectedFolder }
        set { filterViewModel.selectedFolder = newValue }
    }
    var selectedRelativeFolderPath: String? {
        get { filterViewModel.selectedRelativeFolderPath }
        set { filterViewModel.selectedRelativeFolderPath = newValue }
    }
    var includeNestedSubfolders: Bool {
        get { filterViewModel.includeNestedSubfolders }
        set { filterViewModel.includeNestedSubfolders = newValue }
    }
    var searchText: String {
        get { filterViewModel.searchText }
        set {
            filterViewModel.searchText = newValue
            triggerContentSearch(query: newValue)
        }
    }
    var currentViewMode: ViewMode {
        get { filterViewModel.currentViewMode }
        set { filterViewModel.currentViewMode = newValue }
    }
    var reviewFilterMode: ReviewFilterMode {
        get { filterViewModel.reviewFilterMode }
        set { filterViewModel.reviewFilterMode = newValue }
    }
    var selectedSecondaryFilter: SecondaryFilter {
        get { filterViewModel.selectedSecondaryFilter }
        set { filterViewModel.selectedSecondaryFilter = newValue }
    }
    var groupingMode: FileGroupingService.GroupingMode {
        get { filterViewModel.groupingMode }
        set { filterViewModel.groupingMode = newValue }
    }
    var sortMode: SortMode {
        get { filterViewModel.sortMode }
        set { filterViewModel.sortMode = newValue }
    }
    var availableContentTags: [MetadataContentTag] {
        guard featureFlags.isEnabled(.metadataFoundation),
              featureFlags.isEnabled(.autoContentTags) else {
            return []
        }
        return filterViewModel.availableContentTags
    }
    var selectedContentTags: Set<MetadataContentTag> {
        guard featureFlags.isEnabled(.metadataFoundation),
              featureFlags.isEnabled(.autoContentTags) else {
            return []
        }
        return filterViewModel.selectedContentTags
    }
    var showsContentTagQuickFilters: Bool {
        featureFlags.isEnabled(.metadataFoundation) &&
        featureFlags.isEnabled(.autoContentTags) &&
        !filterViewModel.availableContentTags.isEmpty
    }

    func selectCategory(_ category: FileTypeCategory) {
        filterViewModel.selectedCategory = category
    }

    func selectFolder(_ folder: FolderLocation, resetNestedScope: Bool = true) {
        filterViewModel.selectedFolder = folder
        if resetNestedScope {
            filterViewModel.selectedRelativeFolderPath = nil
            filterViewModel.includeNestedSubfolders = false
        }
    }

    func selectNestedFolder(relativePath: String?, includeSubfolders: Bool) {
        filterViewModel.selectedRelativeFolderPath = relativePath
        filterViewModel.includeNestedSubfolders = includeSubfolders
    }

    func setSecondaryFilter(_ filter: SecondaryFilter) {
        filterViewModel.selectedSecondaryFilter = filter
    }

    func updateSearchText(_ text: String) {
        searchText = text
    }

    func toggleContentTagQuickFilter(_ tag: MetadataContentTag) {
        guard featureFlags.isEnabled(.metadataFoundation),
              featureFlags.isEnabled(.autoContentTags) else {
            return
        }

        filterViewModel.toggleContentTag(tag)
    }

    func clearContentTagQuickFilters() {
        filterViewModel.clearContentTagFilters()
    }

    func removeContentTagQuickFilter(_ tag: MetadataContentTag) {
        filterViewModel.removeContentTag(tag)
    }

    func clearAllFilters() {
        if hasActiveExternalReviewSession {
            exitExternalReviewSession()
        }
        filterViewModel.clearAllFilters()
    }

    func applyExternalReviewSession(_ session: ExternalReviewSession?) {
        guard let session else {
            filterViewModel.clearExternalReviewPaths()
            return
        }

        if lastPresentedExternalSessionID != session.requestID {
            showToast(message: makeExternalReviewToastMessage(for: session), canUndo: false)
            lastPresentedExternalSessionID = session.requestID
        }

        if session.reviewPaths.isEmpty {
            exitExternalReviewSession()
            return
        }

        filterViewModel.searchText = ""
        filterViewModel.selectedCategory = .all
        filterViewModel.selectedFolder = .home
        filterViewModel.selectedRelativeFolderPath = nil
        filterViewModel.includeNestedSubfolders = false
        filterViewModel.selectedSecondaryFilter = .none
        filterViewModel.reviewFilterMode = .needsReview
        filterViewModel.setExternalReviewPaths(Set(session.reviewPaths))
    }

    func restoreExternalReviewSessionIfNeeded() {
        applyExternalReviewSession(ExternalReviewSessionStore.shared.currentSession)
    }

    private func makeExternalReviewToastMessage(for session: ExternalReviewSession) -> String {
        let uniqueSkipMessages = Array(NSOrderedSet(array: session.skippedItems.map(\.message))) as? [String] ?? []
        guard !uniqueSkipMessages.isEmpty else {
            return session.statusText
        }

        return ([session.statusText] + uniqueSkipMessages).joined(separator: " ")
    }

    func setViewMode(_ mode: ViewMode) {
        filterViewModel.setViewMode(mode)
        showToast(message: "\(mode.displayName) View", canUndo: false)
    }

    // MARK: - Selection (Delegated to SelectionViewModel)

    var selectedFileIDs: Set<String> {
        get { selectionViewModel.selectedFileIDs }
        set { selectionViewModel.selectedFileIDs = newValue }
    }
    var isSelectionMode: Bool { selectionViewModel.isSelectionMode }
    var focusedFilePath: String? {
        get { selectionViewModel.focusedFilePath }
        set { selectionViewModel.focusedFilePath = newValue }
    }
    var rangeSelectionAnchorPath: String? { selectionViewModel.rangeSelectionAnchorPath }

    func toggleSelection(for file: FileItem) {
        selectionViewModel.toggleSelection(for: file)
        updateRightPanelMode()
    }

    func selectAll() {
        selectionViewModel.selectAll(visibleFiles: visibleFiles)
        updateRightPanelMode()
    }

    func deselectAll() {
        selectionViewModel.deselectAll()
        updateRightPanelMode()
    }

    func selectRange(from startFile: FileItem, to endFile: FileItem) {
        selectionViewModel.selectRange(from: startFile, to: endFile, in: visibleFiles)
        updateRightPanelMode()
    }

    func isSelected(_ file: FileItem) -> Bool {
        selectionViewModel.isSelected(file)
    }

    var selectedFiles: [FileItem] {
        selectionViewModel.getSelectedFiles(from: scanViewModel.allFiles)
    }

    // MARK: - Keyboard Navigation

    func focusNextFile() {
        selectionViewModel.focusNextFile(in: visibleFiles)
    }

    func focusPreviousFile() {
        selectionViewModel.focusPreviousFile(in: visibleFiles)
    }

    func organizeFocusedFile(context: ModelContext? = nil) {
        guard let file = selectionViewModel.getFocusedFile(in: visibleFiles) else { return }
        organizeFile(file, context: context)
    }

    func skipFocusedFile() {
        guard let file = selectionViewModel.getFocusedFile(in: visibleFiles) else { return }
        skipFile(file)
    }

    func quickLookFocusedFile() {
        guard let file = selectionViewModel.getFocusedFile(in: visibleFiles) else { return }
        showQuickLook(for: file)
    }

    func editDestinationForFocusedFile() {
        guard let file = selectionViewModel.getFocusedFile(in: visibleFiles) else { return }
        beginEditingDestination(for: file)
    }

    // MARK: - Analytics (Delegated to AnalyticsDashboardViewModel)

    var storageAnalytics: StorageAnalytics { analyticsViewModel.storageAnalytics }
    var filteredStorageAnalytics: StorageAnalytics { analyticsViewModel.filteredStorageAnalytics }
    var recentActivities: [ActivityItem] { analyticsViewModel.recentActivities }
    var detectedClusters: [ProjectCluster] { analyticsViewModel.detectedClusters }

    func refreshAnalytics() {
        analyticsViewModel.refreshAnalytics(from: scanViewModel.allFiles)
    }

    func loadActivities(from context: ModelContext) {
        analyticsViewModel.loadActivities(from: context)
    }

    func dismissCluster(_ cluster: ProjectCluster, context: ModelContext) {
        analyticsViewModel.dismissCluster(cluster, context: context)
    }

    func addActivity(_ activity: ActivityItem, context: ModelContext) {
        analyticsViewModel.addActivity(activity, context: context)
    }

    // MARK: - Bulk Operations (Delegated to BulkOperationViewModel)

    var bulkOperationProgress: Double { bulkOperationViewModel.bulkOperationProgress }
    var isBulkOperationInProgress: Bool { bulkOperationViewModel.isBulkOperationInProgress }
    var showBulkEditSheet: Bool {
        get { bulkOperationViewModel.showBulkEditSheet }
        set { bulkOperationViewModel.showBulkEditSheet = newValue }
    }
    var showFailedFilesSheet: Bool {
        get { bulkOperationViewModel.showFailedFilesSheet }
        set { bulkOperationViewModel.showFailedFilesSheet = newValue }
    }
    var lastBatchFailedFiles: [FileItem] {
        get { bulkOperationViewModel.lastBatchFailedFiles }
        set { bulkOperationViewModel.lastBatchFailedFiles = newValue }
    }

    func organizeSelectedFiles(context: ModelContext? = nil) {
        startBulkOperation { [weak self] in
            guard let self else { return }
            await self.bulkOperationViewModel.organizeSelectedFiles(self.selectedFiles, context: context)
            self.deselectAll()
            self.filterViewModel.applyFilterImmediately()
        }
    }

    func skipSelectedFiles() {
        bulkOperationViewModel.skipSelectedFiles(selectedFiles)
        deselectAll()
        filterViewModel.applyFilterImmediately()
    }

    func organizeAllReadyFiles(context: ModelContext? = nil) {
        startBulkOperation { [weak self] in
            guard let self else { return }
            await self.bulkOperationViewModel.organizeAllReadyFiles(self.reviewableFiles, context: context)
            self.filterViewModel.applyFilterImmediately()
        }
    }

    func organizeFirstRunQuickWin(context: ModelContext? = nil) {
        let quickWinFiles = firstRunQuickWinBatch?.files ?? []
        guard !quickWinFiles.isEmpty else { return }

        startBulkOperation { [weak self] in
            guard let self else { return }
            await self.bulkOperationViewModel.organizeSelectedFiles(quickWinFiles, context: context)
            self.filterViewModel.applyFilterImmediately()
        }
    }

    func dismissFirstRunQuickWin() {
        guard let candidateKey = firstRunQuickWinSuggestion?.candidateKey else { return }

        var dismissedCandidateKeys = dismissedFirstRunQuickWinCandidateKeys
        let inserted = dismissedCandidateKeys.insert(candidateKey).inserted
        guard inserted else { return }

        userDefaults.set(
            Array(dismissedCandidateKeys).sorted(),
            forKey: FirstRunQuickWinDefaultsKeys.dismissedCandidateKeys
        )
        objectWillChange.send()
    }

    func skipAllPendingFiles() {
        bulkOperationViewModel.skipAllPendingFiles(reviewableFiles)
        filterViewModel.applyFilterImmediately()
    }

    func doneForNow() {
        guard let scopeKey = currentReviewChunkScopeKey else { return }

        let deferredPaths = Set(currentReviewChunkPaths)
        guard !deferredPaths.isEmpty else { return }

        var existingDeferredPaths = deferredReviewPathsByScope[scopeKey] ?? []
        existingDeferredPaths.formUnion(deferredPaths)
        deferredReviewPathsByScope[scopeKey] = existingDeferredPaths

        deselectAll()
        objectWillChange.send()
        showToast(
            message: "Set aside \(deferredPaths.count) file\(deferredPaths.count == 1 ? "" : "s") for now. Resume whenever you're ready.",
            canUndo: false
        )
    }

    func resumeDeferredReviewFiles() {
        guard let scopeKey = currentReviewChunkScopeKey,
              let deferredPaths = deferredReviewPathsByScope.removeValue(forKey: scopeKey),
              !deferredPaths.isEmpty else {
            return
        }

        deselectAll()
        objectWillChange.send()
        showToast(
            message: "Brought back \(deferredPaths.count) deferred file\(deferredPaths.count == 1 ? "" : "s").",
            canUndo: false
        )
    }

    func bulkEditDestination(_ destination: String, createRules: Bool, context: ModelContext? = nil) {
        bulkOperationViewModel.bulkEditDestination(destination, createRules: createRules, files: selectedFiles, context: context)
        filterViewModel.applyFilterImmediately()
    }

    func retryFailedFiles(context: ModelContext? = nil) {
        startBulkOperation { [weak self] in
            guard let self else { return }
            await self.bulkOperationViewModel.retryFailedFiles(context: context)
            self.filterViewModel.applyFilterImmediately()
        }
    }

    func dismissFailedFiles() {
        bulkOperationViewModel.dismissFailedFiles()
    }

    func organizeCluster(_ cluster: ProjectCluster, destinationBase: String, context: ModelContext) async {
        startBulkOperation { [weak self] in
            guard let self else { return }
            await self.bulkOperationViewModel.organizeCluster(
                cluster,
                destinationBase: destinationBase,
                allFiles: self.scanViewModel.allFiles,
                context: context
            )
        }
    }

    func cancelBulkOperation() {
        bulkOperationViewModel.cancelBulkOperation()
        bulkOperationTask?.cancel()
        bulkOperationTask = nil
        showToast(message: "Bulk operation cancelled", canUndo: false)
    }

    private func startBulkOperation(_ action: @escaping () async -> Void) {
        bulkOperationTask?.cancel()
        bulkOperationTask = Task { [weak self] in
            await action()
            self?.bulkOperationTask = nil
        }
    }

    // MARK: - Organization Controller
    private lazy var organizationController: DashboardOrganizationController = {
        let controller = DashboardOrganizationController(
            coordinator: organizationCoordinator,
            scanViewModel: scanViewModel,
            filterViewModel: filterViewModel,
            selectionViewModel: selectionViewModel,
            panelManager: panelManager
        )
        controller.onShowToast = { [weak self] message, canUndo in
            self?.showToast(message: message, canUndo: canUndo)
        }
        controller.onShowError = { [weak self] error in
            self?.errorMessage = error
        }
        controller.onShouldRequestReview = { [weak self] in
            self?.scheduleAppReviewRequest()
        }
        controller.onShowTrustedScopeRecommendation = { [weak self] recommendation in
            self?.panelManager.stageTrustedScopeRecommendation(recommendation)
        }
        return controller
    }()

    // MARK: - File Operations

    func organizeFile(
        _ file: FileItem,
        context: ModelContext? = nil,
        sourceSurface: PersonalMemorySourceSurface = .reviewFlow
    ) {
        organizationController.organizeFile(file, context: context, sourceSurface: sourceSurface)
    }

    func skipFile(_ file: FileItem) {
        organizationController.skipFile(file, context: modelContext)
    }

    func handleOrganizeAnimationComplete(for filePath: String) {
        organizationController.handleOrganizeAnimationComplete(for: filePath)
    }

    // MARK: - Panel Management

    private func updateRightPanelMode() {
        panelManager.updateRightPanelForSelection(selectedFiles)
    }

    func showRuleBuilderPanel(editingRule: Rule? = nil, fileContext: FileItem? = nil) {
        isRightPanelVisible = true
        panelManager.showRuleBuilderPanel(editingRule: editingRule, fileContext: fileContext)
    }

    func showRuleBuilderPanelForInspector(_ file: FileItem, editingRule: Rule? = nil) {
        isRightPanelVisible = true
        selectionViewModel.selectedFileIDs = [file.path]
        selectionViewModel.focusedFilePath = file.path
        panelManager.showRuleBuilderPanel(editingRule: editingRule, fileContext: file)
    }

    func restorePanel(afterRuleDraftReturnTarget returnTarget: RuleDraftReturnTarget) {
        switch returnTarget {
        case .none:
            panelManager.returnToDefaultPanel()
        case .defaultPanel:
            panelManager.returnToDefaultPanel()
        case .inspector(let filePath):
            guard let file = scanViewModel.allFiles.first(where: { $0.path == filePath }) else {
                if selectedFiles.isEmpty {
                    panelManager.returnToDefaultPanel()
                } else {
                    updateRightPanelMode()
                }
                return
            }

            isRightPanelVisible = true
            selectionViewModel.selectedFileIDs = [file.path]
            selectionViewModel.focusedFilePath = file.path
            panelManager.updateRightPanelForSelection([file])
        }
    }

    func returnToDefaultPanel() {
        panelManager.returnToDefaultPanel()
    }

    func shouldShowDefaultPanelPrimaryAction(
        for selection: NavigationSelection,
        hasActiveRuleDraft: Bool
    ) -> Bool {
        guard !hasActiveRuleDraft else { return false }
        guard !isSelectionMode else { return false }

        if reviewFilterMode == .needsReview,
           currentReviewChunkCount > 0 {
            return false
        }

        switch selection {
        case .rules, .analytics:
            return false
        default:
            return true
        }
    }

    func setRightPanelVisible(_ isVisible: Bool) {
        isRightPanelVisible = isVisible
        windowPresentationStore.setInspectorVisible(isVisible)
    }

    var rightPanelMode: PanelStateManager.RightPanelMode {
        get { panelManager.rightPanelMode }
        set { panelManager.rightPanelMode = newValue }
    }

    var celebrationShowsUndo: Bool {
        panelManager.celebrationStyle.showsUndo
    }

    var celebrationShowsNextActionSuggestion: Bool {
        panelManager.celebrationStyle.showsNextActionSuggestion
    }

    var trustedScopeRecommendation: TrustedAutomationScopeRecommendation? {
        panelManager.trustedScopeRecommendation
    }

    var isTrustedScopeRecommendationPresented: Bool {
        panelManager.isTrustedScopeRecommendationPresented
    }

    // MARK: - Panel State Delegation (Required for Views)

    /// Toast notification state - required by ToastHost
    var toastState: PanelStateManager.ToastState? {
        get { panelManager.toastState }
        set { panelManager.toastState = newValue }
    }

    /// File currently being edited for destination
    var editingDestinationFile: FileItem? {
        get { panelManager.editingDestinationFile }
        set { panelManager.editingDestinationFile = newValue }
    }

    /// QuickLook URL for preview
    var quickLookURL: URL? {
        get { panelManager.quickLookURL }
        set { panelManager.quickLookURL = newValue }
    }

    /// QuickLook sheet visibility
    var showQuickLookSheet: Bool {
        get { panelManager.showQuickLookSheet }
        set { panelManager.showQuickLookSheet = newValue }
    }

    /// Clusters view visibility
    var showClustersView: Bool {
        get { panelManager.showClustersView }
        set { panelManager.showClustersView = newValue }
    }

    /// Cluster detection state (delegated from analyticsViewModel)
    var isDetectingClusters: Bool {
        analyticsViewModel.isDetectingClusters
    }

    func showQuickLook(for file: FileItem) {
        panelManager.showQuickLook(for: file) { [weak self] errorMsg in
            self?.errorMessage = errorMsg
        }
    }

    func beginEditingDestination(for file: FileItem) {
        panelManager.beginEditingDestination(for: file)
    }

    func updateDestination(for file: FileItem, to newDestination: Destination) {
        panelManager.updateDestination(for: file, to: newDestination)
        filterViewModel.applyFilterImmediately()
    }

    @discardableResult
    func promoteExternalReviewFolder() -> Bool {
        guard let suggestion = externalReviewPromotionSuggestion else { return false }

        BookmarkFolderService.shared.saveBookmark(suggestion.bookmarkData, for: suggestion.folderType)

        let promotedFolder = BookmarkFolder(folderType: suggestion.folderType)
        let didSaveBookmark = promotedFolder.hasValidBookmark

        if didSaveBookmark && !promotedFolder.isEnabled {
            BookmarkFolderService.shared.setEnabled(true, for: promotedFolder)
        }

        objectWillChange.send()

        if didSaveBookmark {
            showToast(message: "Now monitoring \(suggestion.folderType.displayName).", canUndo: false)
        } else {
            showToast(message: "Couldn’t start monitoring \(suggestion.folderType.displayName).", canUndo: false)
        }

        return didSaveBookmark
    }

    private func showToast(message: String, canUndo: Bool) {
        let context = modelContext
        panelManager.showToast(message: message, canUndo: canUndo, undoAction: canUndo ? { [weak self] in
            self?.undoLastAction(context: context)
        } : nil)
    }

    // MARK: - Undo/Redo

    func canUndo() -> Bool {
        undoRedoController.canUndo()
    }

    func canRedo() -> Bool {
        undoRedoController.canRedo()
    }

    func undoLastAction(context: ModelContext? = nil) {
        let resolvedContext = context ?? modelContext
        panelManager.dismissTrustedScopeRecommendation(clearRecommendation: true)
        undoRedoController.undoLastAction(
            allFiles: scanViewModel.allFiles,
            context: resolvedContext,
            onUnavailable: { [weak self] in
                self?.showToast(message: "Undo unavailable. Please try again after reopening Forma.", canUndo: false)
            },
            onComplete: { [weak self] in
                self?.filterViewModel.applyFilterImmediately()
            }
        )
    }

    func redoLastAction(context: ModelContext? = nil) {
        let resolvedContext = context ?? modelContext
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.undoRedoController.redoLastAction(
                allFiles: self.scanViewModel.allFiles,
                context: resolvedContext,
                onUnavailable: { [weak self] in
                    self?.showToast(message: "Redo unavailable. Please try again after reopening Forma.", canUndo: false)
                },
                onComplete: { [weak self] in
                    self?.filterViewModel.applyFilterImmediately()
                }
            )
        }
    }

    // MARK: - Rules

    @discardableResult
    func loadRules(from context: ModelContext) -> [Rule] {
        let descriptor = FetchDescriptor<Rule>(
            sortBy: [SortDescriptor(\.creationDate, order: .forward)]
        )

        do {
            let fetchedRules = try context.fetch(descriptor)
            rules = fetchedRules.filter { $0.isEnabled }
            Log.info("Successfully loaded \(rules.count) enabled rules", category: .pipeline)
        } catch {
            Log.error("Failed to load rules: \(error.localizedDescription)", category: .pipeline)
            rules = []
        }

        return rules
    }

    func reEvaluateFilesAgainstRules(context: ModelContext) {
        guard !scanViewModel.allFiles.isEmpty else { return }

        _ = ruleEngine.evaluateFiles(scanViewModel.allFiles, rules: rules)

        do {
            try context.save()
        } catch {
            Log.error("Failed to save re-evaluated files: \(error.localizedDescription)", category: .pipeline)
        }

        filterViewModel.applyFilterImmediately()
        analyticsViewModel.updateAnalytics(from: scanViewModel.allFiles)
    }

    func matchingFilesForRulePreview(
        conditions: [RuleCondition],
        conditionType: Rule.ConditionType,
        conditionValue: String,
        logicalOperator: Rule.LogicalOperator,
        actionType: Rule.ActionType,
        destination: Destination?
    ) -> [FileItem] {
        struct EphemeralRule: Ruleable {
            let id: UUID = UUID()
            let conditionType: Rule.ConditionType
            let conditionValue: String
            let conditions: [RuleCondition]
            let logicalOperator: Rule.LogicalOperator
            let isEnabled: Bool = true
            let destination: Destination?
            let actionType: Rule.ActionType
            let sortOrder: Int = 0
            let exclusionConditions: [RuleCondition] = []
        }

        let rule = EphemeralRule(
            conditionType: conditions.isEmpty ? conditionType : (conditions.first?.type ?? conditionType),
            conditionValue: conditions.isEmpty ? conditionValue : (conditions.first?.value ?? conditionValue),
            conditions: conditions,
            logicalOperator: conditions.isEmpty ? .single : logicalOperator,
            destination: destination,
            actionType: actionType
        )

        return scanViewModel.allFiles.filter { file in
            ruleEngine.fileMatchesRule(file: file, rule: rule)
        }
    }

    // MARK: - Permissions

    typealias FolderType = DashboardPermissionState.FolderType
    typealias PermissionResult = DashboardPermissionState.PermissionResult

    var hasDesktopAccess: Bool { permissionState.hasDesktopAccess }
    var hasDownloadsAccess: Bool { permissionState.hasDownloadsAccess }
    var hasDocumentsAccess: Bool { permissionState.hasDocumentsAccess }
    var hasPicturesAccess: Bool { permissionState.hasPicturesAccess }
    var hasMusicAccess: Bool { permissionState.hasMusicAccess }
    var showOnboarding: Bool {
        get { permissionState.showOnboarding }
        set { permissionState.showOnboarding = newValue }
    }
    var permissionCancelledFolders: Set<FolderType> { permissionState.permissionCancelledFolders }

    func checkPermissions() {
        permissionState.checkPermissions(using: fileSystemService)
    }

    func requestDesktopAccess() async -> PermissionResult { await requestAccess(for: .desktop) }
    func requestDownloadsAccess() async -> PermissionResult { await requestAccess(for: .downloads) }
    func requestDocumentsAccess() async -> PermissionResult { await requestAccess(for: .documents) }
    func requestPicturesAccess() async -> PermissionResult { await requestAccess(for: .pictures) }
    func requestMusicAccess() async -> PermissionResult { await requestAccess(for: .music) }

    private func requestAccess(for folderType: FolderType) async -> PermissionResult {
        let result = await permissionState.requestAccess(for: folderType, using: fileSystemService)

        switch result {
        case .granted:
            refreshAvailableFolders()
            schedulePermissionRefreshIfNeeded()
        case .error(let details):
            errorMessage = "Failed to access \(folderType.displayName) folder: \(details)"
        case .cancelled:
            break
        }

        return result
    }

    private func schedulePermissionRefreshIfNeeded() {
        // DashboardView handles the first post-onboarding scan when this sheet closes.
        guard !permissionState.showOnboarding else { return }
        guard modelContext != nil else { return }

        permissionRefreshTask?.cancel()
        permissionRefreshTask = Task { @MainActor [weak self] in
            guard let self else { return }

            do {
                // Keep the delay short so unlocked folders feel immediate while
                // still collapsing truly back-to-back grants into one scan.
                try await Task.sleep(for: Self.permissionRefreshDebounceDelay)
            } catch {
                return
            }

            guard let context = self.modelContext else {
                self.permissionRefreshTask = nil
                return
            }

            await self.refresh(context: context)
            self.permissionRefreshTask = nil
        }
    }



    // MARK: - Content Search

    private func triggerContentSearch(query: String) {
        contentSearchController.triggerSearch(
            query: query,
            filesProvider: { [weak self] in
                self?.scanViewModel.allFiles ?? []
            },
            onMatchedPathsUpdated: { [weak self] matchedPaths in
                self?.filterViewModel.setContentMatchedPaths(matchedPaths)
            }
        )
    }

    // MARK: - Private Setup

    private func setupViewModelForwarding() {
        // Forward allFiles changes to FilterViewModel
        scanViewModel.$allFiles
            .sink { [weak self] files in
                guard let self else { return }
                self.synchronizeOrganizationProgressTotal(with: files)
                self.filterViewModel.updateSourceFiles(files)
                self.refreshContentTagQuickFilters(for: files)
                self.synchronizeExternalReviewSession(with: files)
                self.analyticsViewModel.updateAnalytics(from: files)
            }
            .store(in: &cancellables)

        // Forward filtered files changes to AnalyticsViewModel
        filterViewModel.$filteredFiles
            .sink { [weak self] files in
                self?.analyticsViewModel.updateFilteredAnalytics(from: files)
            }
            .store(in: &cancellables)

        // Forward objectWillChange from nested ViewModels
        scanViewModel.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        filterViewModel.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        selectionViewModel.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        analyticsViewModel.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        bulkOperationViewModel.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        contentSearchController.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        scanRefreshController.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        organizationCoordinator.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        panelManager.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        permissionState.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
    }

    func showCelebrationPanel(
        message: String,
        style: PanelStateManager.CelebrationStyle = .batchUndo,
        onDismiss: (() -> Void)? = nil
    ) {
        panelManager.showCelebrationPanel(message: message, style: style, onDismiss: onDismiss)
    }

    func dismissCelebrationPanel() {
        panelManager.dismissCelebration()
    }

    func presentTrustedScopeRecommendation() {
        panelManager.presentTrustedScopeRecommendation()
    }

    func dismissTrustedScopeRecommendation(clearRecommendation: Bool = false) {
        panelManager.dismissTrustedScopeRecommendation(clearRecommendation: clearRecommendation)
    }

    func confirmTrustedScopeRecommendation(
        selectedScopeType: TrustedAutomationScopeType,
        context: ModelContext
    ) {
        guard let recommendation = panelManager.trustedScopeRecommendation else { return }

        do {
            let trustedScope = try TrustedAutomationScopeService(modelContext: context).promoteFromReviewDecision(
                recommendation: recommendation,
                selectedScopeType: selectedScopeType
            )
            panelManager.dismissTrustedScopeRecommendation(clearRecommendation: true)
            showToast(
                message: "Autopilot enabled for \(trustedScope.displayName)",
                canUndo: false
            )
        } catch {
            errorMessage = error.localizedDescription
            showToast(message: error.localizedDescription, canUndo: false)
        }
    }

    func showRuleWorkflowCelebration(message: String, returnTarget: RuleDraftReturnTarget) {
        showCelebrationPanel(message: message, style: .ruleWorkflow) { [weak self] in
            guard let self else { return }

            switch returnTarget {
            case .none:
                self.returnToDefaultPanel()
            default:
                self.restorePanel(afterRuleDraftReturnTarget: returnTarget)
            }
        }
    }

    private func exitExternalReviewSession() {
        filterViewModel.clearExternalReviewPaths()
        if ExternalReviewSessionStore.shared.currentSession != nil {
            ExternalReviewSessionStore.shared.publish(nil)
        }
    }

    private func synchronizeExternalReviewSession(with files: [FileItem]) {
        guard let session = ExternalReviewSessionStore.shared.currentSession,
              !session.reviewPaths.isEmpty else {
            return
        }

        let activePaths = Set(
            files.compactMap { file in
                switch file.status {
                case .pending, .ready:
                    return file.path
                case .completed, .skipped:
                    return nil
                }
            }
        )
        let remainingReviewPaths = session.reviewPaths.filter { activePaths.contains($0) }

        guard remainingReviewPaths != session.reviewPaths else {
            return
        }

        if remainingReviewPaths.isEmpty {
            exitExternalReviewSession()
            return
        }

        ExternalReviewSessionStore.shared.publish(
            ExternalReviewSession(
                requestID: session.requestID,
                source: session.source,
                reviewPaths: remainingReviewPaths,
                scannedRootPaths: session.scannedRootPaths,
                skippedItems: session.skippedItems,
                statusText: session.statusText,
                promotionCandidate: session.promotionCandidate
            )
        )
    }

    private func setupBulkOperationCallbacks() {
        bulkOperationViewModel.onShowErrorToast = { [weak self] message in
            self?.errorMessage = message
            self?.showToast(message: message, canUndo: false)
        }

        bulkOperationViewModel.onShowCelebration = { [weak self] message in
            self?.panelManager.showCelebrationPanel(message: message)
        }

        bulkOperationViewModel.onShowToast = { [weak self] message, canUndo in
            self?.showToast(message: message, canUndo: canUndo)
        }

        bulkOperationViewModel.onOperationComplete = { [weak self] _, _ in
            self?.filterViewModel.applyFilterImmediately()
        }

        bulkOperationViewModel.onShouldRequestReview = { [weak self] in
            self?.scheduleAppReviewRequest()
        }
    }

    /// Delays the review prompt so it appears after the celebration animation.
    private func scheduleAppReviewRequest() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: FormaConfig.ReviewPrompt.delayAfterCelebration)
            self?.shouldRequestAppReview = true
        }
    }

    private func makeScanRefreshActions() -> DashboardScanRefreshController.Actions {
        DashboardScanRefreshController.Actions(
            onScanErrorSummary: { [weak self] summary in
                guard let self else { return }
                self.errorMessage = summary
                self.showToast(message: summary, canUndo: false)
            },
            onAutomationSummary: { [weak self] summary in
                guard let self else { return }
                if let summary, !summary.isEmpty {
                    self.errorMessage = summary
                    self.showToast(message: summary, canUndo: false)
                } else {
                    self.errorMessage = nil
                }
            },
            resetOrganizationProgress: { [weak self] files in
                self?.resetOrganizationProgress(with: files)
            },
            currentSearchText: { [weak self] in
                self?.searchText ?? ""
            },
            triggerContentSearch: { [weak self] query in
                self?.triggerContentSearch(query: query)
            },
            refreshAvailableFolders: { [weak self] in
                self?.refreshAvailableFolders()
            }
        )
    }

    // MARK: - Mock Data

    private func loadMockData() {
        // This would be implemented by FileScanViewModel
        Log.debug("Loading mock data for previews/UI tests", category: .pipeline)
    }

    // MARK: - Computed Properties (Delegation)

    var reviewChunkSize: Int { Self.defaultReviewChunkSize }
    var visibleFiles: [FileItem] {
        guard reviewFilterMode == .needsReview else {
            return filterViewModel.visibleFiles
        }

        return currentReviewChunkFiles
    }
    var needsReviewCount: Int { filterViewModel.needsReviewCount }
    var allFilesCount: Int { filterViewModel.allFilesCount }
    var reviewableFiles: [FileItem] {
        guard reviewFilterMode == .needsReview else {
            return filterViewModel.reviewableFiles
        }

        return currentReviewChunkFiles
    }
    var firstRunQuickWinSuggestion: FirstRunQuickWinSuggestion? { firstRunQuickWinBatch?.suggestion }
    var externalReviewPromotionSuggestion: ExternalReviewPromotionSuggestion? {
        guard let candidate = ExternalReviewSessionStore.shared.currentSession?.promotionCandidate else {
            return nil
        }

        guard !BookmarkFolder(folderType: candidate.folderType).hasValidBookmark else {
            return nil
        }

        return ExternalReviewPromotionSuggestion(
            folderType: candidate.folderType,
            bookmarkData: candidate.bookmarkData
        )
    }
    var groupedFiles: [FileGroup] { filterViewModel.groupedFiles }
    var allFiles: [FileItem] { scanViewModel.allFiles }
    var recentFiles: [FileItem] { scanViewModel.recentFiles }
    var availableFolders: [BookmarkFolder] { BookmarkFolderService.shared.availableFolders }
    var isLoading: Bool { scanViewModel.isScanning }
    var scanPhaseStatusText: String? { scanRefreshController.phaseStatusText }
    var contentSearchState: ContentSearchService.SearchState { contentSearchController.state }
    var contentSearchResults: [ContentSearchService.SearchResult] { contentSearchController.results }
    var latestUndoableBatchSummary: UndoBatchSummary? { organizationCoordinator.latestUndoableBatchSummary }

    func getMatchingRules(for file: FileItem) -> [Rule] {
        rules.filter { rule in
            ruleEngine.fileMatchesRule(file: file, rule: rule)
        }
    }

    func applyRule(_ rule: Rule, to file: FileItem) {
        if let destination = rule.destination {
            file.destination = destination
            file.status = .ready
            filterViewModel.applyFilterImmediately()
        }
    }

    func createRuleFromPattern(_ pattern: LearnedPattern, context: ModelContext) {
        _ = analyticsViewModel.createRuleFromPattern(pattern, context: context)
    }

    var cachedVisibleFiles: [FileItem] { filterViewModel.cachedVisibleFiles }
    var cachedGroupedFiles: [FileGroup] { filterViewModel.cachedGroupedFiles }
    var cachedNeedsReviewCount: Int { filterViewModel.cachedNeedsReviewCount }
    var cachedReviewableFiles: [FileItem] { filterViewModel.cachedReviewableFiles }
    var currentReviewChunkCount: Int { currentReviewChunkFiles.count }
    var currentReviewChunkPaths: [String] { currentReviewChunkFiles.map(\.path) }
    var currentReviewChunkReadyCount: Int {
        currentReviewChunkFiles.filter { $0.status == .ready }.count
    }
    var deferredReviewFileCount: Int {
        activeDeferredReviewPaths(in: filterViewModel.reviewableFiles).count
    }
    var hasDeferredReviewFiles: Bool { deferredReviewFileCount > 0 }
    var organizationProgressOrganizedCount: Int {
        max(0, organizationProgressTotalCount - organizationProgressRemainingCount)
    }

    func isOrganizing(_ file: FileItem) -> Bool {
        organizationCoordinator.isOrganizing(file)
    }

    var organizingFilePaths: Set<String> {
        organizationCoordinator.organizingFilePaths
    }

    var viewModeForSelectedCategory: ViewMode {
        filterViewModel.viewModeForCategory(filterViewModel.selectedCategory)
    }

    var canOrganizeAllSelected: Bool {
        selectionViewModel.canOrganizeAllSelected(from: scanViewModel.allFiles)
    }

    private var organizationProgressRemainingCount: Int {
        scanViewModel.allFiles.filter { $0.status != .completed }.count
    }

    // MARK: - Keyboard Navigation Delegation

    var isKeyboardNavigating: Bool {
        get { selectionViewModel.isKeyboardNavigating }
        set { selectionViewModel.isKeyboardNavigating = newValue }
    }

    // MARK: - Undo/Redo Stacks (Delegated from Coordinator)

    /// Undo stack for testing and UI status
    var undoStack: [any UndoableCommand] { undoRedoController.undoStack }

    /// Redo stack for testing and UI status
    var redoStack: [any UndoableCommand] { undoRedoController.redoStack }

    /// Type alias for backwards compatibility with tests
    typealias OrganizationAction = FileOrganizationCoordinator.OrganizationAction

    #if DEBUG
    /// Test helper to set allFiles directly (bypasses scanning)
    func _testSetFiles(_ files: [FileItem]) {
        scanViewModel._testSetFiles(files)
        filterViewModel.updateSourceFiles(files)
        refreshContentTagQuickFilters(for: files)
        resetOrganizationProgress(with: files)
    }

    /// Test helper to push an undo action without file operations
    func _testPushUndoAction(_ action: OrganizationAction) {
        organizationCoordinator._testPushUndoAction(action)
    }

    var _testPanelManager: PanelStateManager {
        panelManager
    }
    #endif

    // MARK: - Content Search Delegations

    func searchMatchType(for file: FileItem) -> ContentSearchService.MatchType? {
        contentSearchController.matchType(for: file)
    }

    func contentSnippet(for file: FileItem) -> String? {
        contentSearchController.contentSnippet(for: file)
    }

    var contentSearchResultsCount: Int {
        contentSearchController.resultCount
    }

    // MARK: - Panel State Delegations

    // MARK: - Template Controller
    private lazy var templateController: DashboardTemplateController = {
        DashboardTemplateController(
            modelContext: modelContext ?? (try! ModelContainer(for: Forma_File_OrganizingApp.appSchema)).mainContext,
            filterViewModel: filterViewModel
        )
    }()

    func completeOnboarding() {
        templateController.completeOnboarding(
            permissionState: permissionState,
            modelContext: modelContext
        )
        prepareFirstRunQuickWinPresentation()
    }

    private var firstRunQuickWinBatch: FirstRunQuickWinBatch? {
        guard !hasActiveExternalReviewSession else {
            return nil
        }

        let groupedReadyFiles = Dictionary(
            grouping: filterViewModel.visibleFiles.filter { $0.status == .ready && $0.destination != nil },
            by: Self.firstRunQuickWinBatchKey(for:)
        )

        guard let bestBatch = groupedReadyFiles
            .map({ key, files in
                FirstRunQuickWinBatch(
                    suggestion: FirstRunQuickWinSuggestion(
                        kind: key.kind,
                        folderName: key.folderName,
                        fileCount: files.count,
                        destinationSummary: key.destinationSummary,
                        primaryActionTitle: key.kind.primaryActionTitle,
                        candidateKey: key.storageKey
                    ),
                    files: files
                )
            })
            .filter({ $0.suggestion.fileCount >= Self.minimumFirstRunQuickWinFileCount })
            .filter({ !dismissedFirstRunQuickWinCandidateKeys.contains($0.suggestion.candidateKey) })
            .sorted(by: Self.isPreferredQuickWinBatch(_:_:))
            .first else {
            return nil
        }

        return bestBatch
    }

    private var hasActiveExternalReviewSession: Bool {
        filterViewModel.hasExternalReviewScope || ExternalReviewSessionStore.shared.currentSession != nil
    }

    private func resetOrganizationProgress(with files: [FileItem]) {
        organizationProgressTotalCount = files.filter { $0.status != .completed }.count
    }

    private func refreshContentTagQuickFilters(for files: [FileItem]? = nil) {
        guard featureFlags.isEnabled(.metadataFoundation),
              featureFlags.isEnabled(.autoContentTags),
              let modelContext else {
            filterViewModel.clearContentTagFilters()
            filterViewModel.setContentTagIndex([:])
            return
        }

        let sourceFiles = files ?? scanViewModel.allFiles
        let metadataService = FileMetadataFoundationService(modelContext: modelContext)
        let index = metadataService.contentTagIndex(for: sourceFiles.map(\.path))
        filterViewModel.setContentTagIndex(index)
    }

    private func synchronizeOrganizationProgressTotal(with files: [FileItem]) {
        let currentRemaining = files.filter { $0.status != .completed }.count
        if currentRemaining > organizationProgressTotalCount {
            organizationProgressTotalCount = currentRemaining
        }
    }

    private static func firstRunQuickWinBatchKey(for file: FileItem) -> FirstRunQuickWinBatchKey {
        let kind = firstRunQuickWinKind(for: file)
        let destinationSummary = file.destinationDisplayName ?? "Suggested folder"

        if let scanRootPath = file.scanRootPath,
           !scanRootPath.isEmpty {
            let normalizedRoot = URL(fileURLWithPath: scanRootPath).standardizedFileURL.path
            let folderName = URL(fileURLWithPath: normalizedRoot).lastPathComponent
            return FirstRunQuickWinBatchKey(
                identifier: normalizedRoot,
                folderName: folderName.isEmpty ? file.location.displayName : folderName,
                kind: kind,
                destinationSummary: destinationSummary
            )
        }

        return FirstRunQuickWinBatchKey(
            identifier: file.location.rawValue,
            folderName: file.location.displayName,
            kind: kind,
            destinationSummary: destinationSummary
        )
    }

    private static func isPreferredQuickWinBatch(
        _ lhs: FirstRunQuickWinBatch,
        _ rhs: FirstRunQuickWinBatch
    ) -> Bool {
        if lhs.suggestion.kind.priority != rhs.suggestion.kind.priority {
            return lhs.suggestion.kind.priority < rhs.suggestion.kind.priority
        }

        if lhs.suggestion.fileCount != rhs.suggestion.fileCount {
            return lhs.suggestion.fileCount > rhs.suggestion.fileCount
        }

        let folderComparison = lhs.suggestion.folderName.localizedCaseInsensitiveCompare(rhs.suggestion.folderName)
        if folderComparison != .orderedSame {
            return folderComparison == .orderedAscending
        }

        return lhs.suggestion.destinationSummary.localizedCaseInsensitiveCompare(rhs.suggestion.destinationSummary) == .orderedAscending
    }

    private var dismissedFirstRunQuickWinCandidateKeys: Set<String> {
        Set(userDefaults.stringArray(forKey: FirstRunQuickWinDefaultsKeys.dismissedCandidateKeys) ?? [])
    }

    private func prepareFirstRunQuickWinPresentation() {
        filterViewModel.searchText = ""
        filterViewModel.selectedCategory = .all
        filterViewModel.selectedFolder = .home
        filterViewModel.selectedRelativeFolderPath = nil
        filterViewModel.includeNestedSubfolders = false
        filterViewModel.selectedSecondaryFilter = .none
        filterViewModel.reviewFilterMode = .needsReview
        filterViewModel.applyFilterImmediately()
    }

    private static func firstRunQuickWinKind(for file: FileItem) -> FirstRunQuickWinSuggestion.Kind {
        let lowercasedName = file.name.lowercased()
        let destinationName = file.destinationDisplayName?.lowercased() ?? ""

        if file.category == .images &&
            (lowercasedName.contains("screenshot") ||
             lowercasedName.contains("screen shot") ||
             destinationName.contains("screenshot")) {
            return .screenshots
        }

        if file.category == .archives {
            return .archives
        }

        if file.location == .downloads &&
            file.creationDate <= Date().addingTimeInterval(-TimeInterval(Self.staleDownloadsThresholdDays * 86_400)) {
            return .staleDownloads
        }

        if file.category == .documents &&
            ["invoice", "receipt", "bill"].contains(where: lowercasedName.contains) {
            return .invoices
        }

        return .readyBatch
    }

    private var currentReviewChunkScopeKey: ReviewChunkScopeKey? {
        guard reviewFilterMode == .needsReview else { return nil }

        return ReviewChunkScopeKey(
            selectedCategory: selectedCategory,
            selectedFolder: selectedFolder,
            selectedRelativeFolderPath: selectedRelativeFolderPath,
            includeNestedSubfolders: includeNestedSubfolders,
            searchText: searchText,
            selectedSecondaryFilter: selectedSecondaryFilter,
            selectedContentTags: selectedContentTags,
            sortMode: sortMode,
            externalReviewRequestID: filterViewModel.hasExternalReviewScope
                ? ExternalReviewSessionStore.shared.currentSession?.requestID
                : nil
        )
    }

    private func activeDeferredReviewPaths(in files: [FileItem]) -> Set<String> {
        guard let scopeKey = currentReviewChunkScopeKey,
              let deferredPaths = deferredReviewPathsByScope[scopeKey],
              !deferredPaths.isEmpty else {
            return []
        }

        let activePaths = Set(files.map(\.path))
        return deferredPaths.intersection(activePaths)
    }

    private var currentReviewChunkFiles: [FileItem] {
        let baseVisibleFiles = filterViewModel.visibleFiles
        let deferredPaths = activeDeferredReviewPaths(in: baseVisibleFiles)

        return Array(
            baseVisibleFiles
                .filter { !deferredPaths.contains($0.path) }
                .prefix(reviewChunkSize)
        )
    }
}
