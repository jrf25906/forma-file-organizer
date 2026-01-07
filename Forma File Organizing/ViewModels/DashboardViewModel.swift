import Foundation
import SwiftUI
import SwiftData
import Combine

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

    // MARK: - Legacy Coordinators (Still Needed)

    @ObservedObject private var organizationCoordinator = FileOrganizationCoordinator()
    @ObservedObject private var panelManager = PanelStateManager()

    // MARK: - Permissions State
    @Published var hasDesktopAccess: Bool = false
    @Published var hasDownloadsAccess: Bool = false
    @Published var hasDocumentsAccess: Bool = false
    @Published var hasPicturesAccess: Bool = false
    @Published var hasMusicAccess: Bool = false
    @Published var showOnboarding: Bool = false
    @Published var permissionCancelledFolders: Set<FolderType> = []

    // MARK: - UI State
    @Published var isRightPanelVisible: Bool = true
    @Published var errorMessage: String?

    // MARK: - Content Search State
    @Published private(set) var contentSearchState: ContentSearchService.SearchState = .idle
    @Published private(set) var contentSearchResults: [ContentSearchService.SearchResult] = []
    private var contentSearchTask: Task<Void, Never>?
    private static let contentSearchDebounceDelay: Duration = .milliseconds(300)

    // MARK: - Services
    private let fileSystemService: FileSystemServiceProtocol
    private let storageService: StorageService
    private let ruleEngine = RuleEngine()
    private let fileOperationsService = FileOperationsService()
    private let notificationService: NotificationService
    private let quickLookService: QuickLookService
    private let learningService = LearningService()
    private let contextDetectionService = ContextDetectionService()
    private let insightsService: InsightsService
    private let contentSearchService = ContentSearchService.shared

    // MARK: - Private State
    private var modelContext: ModelContext?
    private var rules: [Rule] = []
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        services: AppServices,
        fileSystemService: FileSystemServiceProtocol,
        fileScanPipeline: FileScanPipelineProtocol
    ) {
        self.fileSystemService = fileSystemService
        self.storageService = services.storageService
        self.notificationService = services.notificationService
        self.quickLookService = services.quickLookService
        self.insightsService = services.insightsService

        // Initialize focused ViewModels
        self.scanViewModel = FileScanViewModel(
            fileSystemService: fileSystemService,
            fileScanPipeline: fileScanPipeline
        )
        self.filterViewModel = FilterViewModel()
        self.selectionViewModel = SelectionViewModel()
        self.analyticsViewModel = AnalyticsDashboardViewModel(
            storageService: storageService,
            insightsService: insightsService
        )
        self.bulkOperationViewModel = BulkOperationViewModel(
            notificationService: notificationService
        )

        // Setup inter-ViewModel communication
        setupViewModelForwarding()
        setupBulkOperationCallbacks()

        #if DEBUG
        if CommandLine.arguments.contains("--force-onboarding") {
            if let concreteFS = fileSystemService as? FileSystemService {
                concreteFS.resetAllAccess()
            }
        }

        if !CommandLine.arguments.contains("--uitesting") {
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
            fileSystemService: FileSystemService(),
            fileScanPipeline: FileScanPipeline()
        )
    }

    convenience init() {
        self.init(services: AppServices())
    }

    func setModelContext(_ context: ModelContext) {
        modelContext = context
    }

    // MARK: - File Scanning (Delegated to FileScanViewModel)

    func scanFiles(context: ModelContext) async {
        loadRules(from: context)
        await scanViewModel.scanFiles(context: context, rules: rules)
        if let summary = scanViewModel.errorMessage {
            errorMessage = summary
            showToast(message: summary, canUndo: false)
        }

        // Update dependent ViewModels
        filterViewModel.updateSourceFiles(scanViewModel.allFiles)
        analyticsViewModel.updateAnalytics(from: scanViewModel.allFiles)
        await analyticsViewModel.detectClusters(from: scanViewModel.allFiles, context: context)
    }

    func refresh(context: ModelContext) async {
        await scanFiles(context: context)
    }

    func loadCustomFolders(from context: ModelContext) {
        scanViewModel.loadCustomFolders(from: context)
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

    func selectCategory(_ category: FileTypeCategory) {
        filterViewModel.selectedCategory = category
    }

    func selectFolder(_ folder: FolderLocation) {
        filterViewModel.selectedFolder = folder
    }

    func setSecondaryFilter(_ filter: SecondaryFilter) {
        filterViewModel.selectedSecondaryFilter = filter
    }

    func updateSearchText(_ text: String) {
        searchText = text
    }

    func clearAllFilters() {
        filterViewModel.clearAllFilters()
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

    func toggleSelection(for file: FileItem) {
        selectionViewModel.toggleSelection(for: file)
        updateRightPanelMode()
    }

    func selectAll() {
        selectionViewModel.selectAll(visibleFiles: filterViewModel.visibleFiles)
        updateRightPanelMode()
    }

    func deselectAll() {
        selectionViewModel.deselectAll()
        updateRightPanelMode()
    }

    func selectRange(from startFile: FileItem, to endFile: FileItem) {
        selectionViewModel.selectRange(from: startFile, to: endFile, in: filterViewModel.visibleFiles)
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
        selectionViewModel.focusNextFile(in: filterViewModel.visibleFiles)
    }

    func focusPreviousFile() {
        selectionViewModel.focusPreviousFile(in: filterViewModel.visibleFiles)
    }

    func organizeFocusedFile(context: ModelContext? = nil) {
        guard let file = selectionViewModel.getFocusedFile(in: filterViewModel.visibleFiles) else { return }
        organizeFile(file, context: context)
    }

    func skipFocusedFile() {
        guard let file = selectionViewModel.getFocusedFile(in: filterViewModel.visibleFiles) else { return }
        skipFile(file)
    }

    func quickLookFocusedFile() {
        guard let file = selectionViewModel.getFocusedFile(in: filterViewModel.visibleFiles) else { return }
        showQuickLook(for: file)
    }

    func editDestinationForFocusedFile() {
        guard let file = selectionViewModel.getFocusedFile(in: filterViewModel.visibleFiles) else { return }
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
        Task {
            await bulkOperationViewModel.organizeSelectedFiles(selectedFiles, context: context)
            deselectAll()
            filterViewModel.applyFilterImmediately()
        }
    }

    func skipSelectedFiles() {
        bulkOperationViewModel.skipSelectedFiles(selectedFiles)
        deselectAll()
        filterViewModel.applyFilterImmediately()
    }

    func organizeAllReadyFiles(context: ModelContext? = nil) {
        Task {
            await bulkOperationViewModel.organizeAllReadyFiles(filteredFiles, context: context)
            filterViewModel.applyFilterImmediately()
        }
    }

    func skipAllPendingFiles() {
        bulkOperationViewModel.skipAllPendingFiles(filteredFiles)
        filterViewModel.applyFilterImmediately()
    }

    func bulkEditDestination(_ destination: String, createRules: Bool, context: ModelContext? = nil) {
        bulkOperationViewModel.bulkEditDestination(destination, createRules: createRules, files: selectedFiles, context: context)
        filterViewModel.applyFilterImmediately()
    }

    func retryFailedFiles(context: ModelContext? = nil) {
        Task {
            await bulkOperationViewModel.retryFailedFiles(context: context)
            filterViewModel.applyFilterImmediately()
        }
    }

    func dismissFailedFiles() {
        bulkOperationViewModel.dismissFailedFiles()
    }

    func organizeCluster(_ cluster: ProjectCluster, destinationBase: String, context: ModelContext) async {
        await bulkOperationViewModel.organizeCluster(cluster, destinationBase: destinationBase, allFiles: scanViewModel.allFiles, context: context)
    }

    // MARK: - File Operations

    func organizeFile(_ file: FileItem, context: ModelContext? = nil) {
        guard file.destination != nil else { return }
        deselectAll()

        Task { @MainActor [weak self] in
            guard let self else { return }

            await self.organizationCoordinator.organizeFile(
                file,
                context: context,
                onSuccess: { [weak self] _ in
                    guard let self else { return }
                    if let displayName = file.destination?.displayName {
                        self.panelManager.showCelebrationPanel(message: "Organized to \(displayName)")
                    }
                },
                onError: { [weak self] error in
                    guard let self else { return }
                    self.errorMessage = error.localizedDescription
                    self.showToast(message: self.errorMessage ?? "Operation failed", canUndo: false)
                }
            )

            // Update scan ViewModel
            self.scanViewModel.removeFile(at: file.path)
            self.filterViewModel.updateSourceFiles(self.scanViewModel.allFiles)
        }
    }

    func skipFile(_ file: FileItem) {
        file.status = .skipped
        filterViewModel.applyFilterImmediately()
    }

    func handleOrganizeAnimationComplete(for filePath: String) {
        organizationCoordinator.handleOrganizeAnimationComplete(for: filePath)
        withAnimation(.easeInOut(duration: 0.3)) {
            filterViewModel.applyFilterImmediately()
        }
    }

    // MARK: - Panel Management

    private func updateRightPanelMode() {
        panelManager.updateRightPanelForSelection(selectedFiles)
    }

    func showRuleBuilderPanel(editingRule: Rule? = nil, fileContext: FileItem? = nil) {
        panelManager.showRuleBuilderPanel(editingRule: editingRule, fileContext: fileContext)
    }

    func returnToDefaultPanel() {
        panelManager.returnToDefaultPanel()
    }

    var rightPanelMode: PanelStateManager.RightPanelMode {
        get { panelManager.rightPanelMode }
        set { panelManager.rightPanelMode = newValue }
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

    private func showToast(message: String, canUndo: Bool) {
        let context = modelContext
        panelManager.showToast(message: message, canUndo: canUndo, undoAction: canUndo ? { [weak self] in
            self?.undoLastAction(context: context)
        } : nil)
    }

    // MARK: - Undo/Redo

    func canUndo() -> Bool {
        organizationCoordinator.canUndo()
    }

    func canRedo() -> Bool {
        organizationCoordinator.canRedo()
    }

    func undoLastAction(context: ModelContext? = nil) {
        let resolvedContext = context ?? modelContext
        if resolvedContext == nil,
           let lastCommand = organizationCoordinator.undoStack.last,
           !(lastCommand is SkipFileCommand) {
            showToast(message: "Undo unavailable. Please try again after reopening Forma.", canUndo: false)
            return
        }
        organizationCoordinator.undoLastAction(allFiles: scanViewModel.allFiles, context: resolvedContext) { [weak self] in
            self?.filterViewModel.applyFilterImmediately()
        }
    }

    func redoLastAction(context: ModelContext? = nil) {
        let resolvedContext = context ?? modelContext
        if resolvedContext == nil,
           let lastCommand = organizationCoordinator.redoStack.last,
           !(lastCommand is SkipFileCommand) {
            showToast(message: "Redo unavailable. Please try again after reopening Forma.", canUndo: false)
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.organizationCoordinator.redoLastAction(
                allFiles: self.scanViewModel.allFiles,
                context: resolvedContext,
                onComplete: { [weak self] in
                    self?.filterViewModel.applyFilterImmediately()
                }
            )
        }
    }

    // MARK: - Rules

    func loadRules(from context: ModelContext) {
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

    func checkPermissions() {
        #if DEBUG
        if CommandLine.arguments.contains("--uitesting") {
            hasDesktopAccess = true
            hasDownloadsAccess = true
            hasDocumentsAccess = true
            hasPicturesAccess = true
            hasMusicAccess = true
            showOnboarding = false
            return
        }
        #endif

        hasDesktopAccess = fileSystemService.hasDesktopAccess()
        hasDownloadsAccess = fileSystemService.hasDownloadsAccess()
        hasDocumentsAccess = fileSystemService.hasDocumentsAccess()
        hasPicturesAccess = fileSystemService.hasPicturesAccess()
        hasMusicAccess = fileSystemService.hasMusicAccess()

        showOnboarding = !hasDesktopAccess || !hasDownloadsAccess || !hasDocumentsAccess || !hasPicturesAccess || !hasMusicAccess
    }

    enum FolderType: Hashable {
        case desktop, downloads, documents, pictures, music

        var displayName: String {
            switch self {
            case .desktop: return "Desktop"
            case .downloads: return "Downloads"
            case .documents: return "Documents"
            case .pictures: return "Pictures"
            case .music: return "Music"
            }
        }
    }

    enum PermissionResult {
        case granted, cancelled, error(String)
    }

    func requestDesktopAccess() async -> PermissionResult { await requestAccess(for: .desktop) }
    func requestDownloadsAccess() async -> PermissionResult { await requestAccess(for: .downloads) }
    func requestDocumentsAccess() async -> PermissionResult { await requestAccess(for: .documents) }
    func requestPicturesAccess() async -> PermissionResult { await requestAccess(for: .pictures) }
    func requestMusicAccess() async -> PermissionResult { await requestAccess(for: .music) }

    private func requestAccess(for folderType: FolderType) async -> PermissionResult {
        permissionCancelledFolders.remove(folderType)

        do {
            let granted = try await {
                switch folderType {
                case .desktop: return try await fileSystemService.requestDesktopAccess()
                case .downloads: return try await fileSystemService.requestDownloadsAccess()
                case .documents: return try await fileSystemService.requestDocumentsAccess()
                case .pictures: return try await fileSystemService.requestPicturesAccess()
                case .music: return try await fileSystemService.requestMusicAccess()
                }
            }()

            if granted {
                switch folderType {
                case .desktop: hasDesktopAccess = true
                case .downloads: hasDownloadsAccess = true
                case .documents: hasDocumentsAccess = true
                case .pictures: hasPicturesAccess = true
                case .music: hasMusicAccess = true
                }
                updateOnboardingVisibility()

                // Auto-rescan to pick up files from newly accessible folder
                if let context = modelContext {
                    Task { @MainActor in
                        await refresh(context: context)
                    }
                }

                return .granted
            } else {
                permissionCancelledFolders.insert(folderType)
                return .cancelled
            }
        } catch {
            errorMessage = "Failed to access \(folderType.displayName) folder: \(error.localizedDescription)"
            return .error(error.localizedDescription)
        }
    }

    private func updateOnboardingVisibility() {
        showOnboarding = !hasDesktopAccess || !hasDownloadsAccess || !hasDocumentsAccess || !hasPicturesAccess || !hasMusicAccess
    }

    func completeOnboarding() {
        showOnboarding = false
    }

    // MARK: - Content Search

    private func triggerContentSearch(query: String) {
        contentSearchTask?.cancel()

        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            contentSearchState = .idle
            contentSearchResults = []
            filterViewModel.setContentMatchedPaths([])
            return
        }

        contentSearchTask = Task { [weak self] in
            do {
                try await Task.sleep(for: Self.contentSearchDebounceDelay)
            } catch {
                return
            }

            guard let self, !Task.isCancelled else { return }

            let results = await self.contentSearchService.search(query: query, in: self.scanViewModel.allFiles)

            guard !Task.isCancelled else { return }

            self.contentSearchResults = results
            self.contentSearchState = self.contentSearchService.searchState
            self.filterViewModel.setContentMatchedPaths(Set(results.map { $0.file.path }))
        }
    }

    func contentSearchResult(for file: FileItem) -> ContentSearchService.SearchResult? {
        contentSearchService.result(for: file)
    }

    // MARK: - Private Setup

    private func setupViewModelForwarding() {
        // Forward allFiles changes to FilterViewModel
        scanViewModel.$allFiles
            .sink { [weak self] files in
                guard let self else { return }
                self.filterViewModel.updateSourceFiles(files)
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
        panelManager.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
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
    }

    // MARK: - Mock Data

    private func loadMockData() {
        // This would be implemented by FileScanViewModel
        Log.debug("Loading mock data for previews/UI tests", category: .pipeline)
    }

    // MARK: - Computed Properties (Delegation)

    var visibleFiles: [FileItem] { filterViewModel.visibleFiles }
    var needsReviewCount: Int { filterViewModel.needsReviewCount }
    var allFilesCount: Int { filterViewModel.allFilesCount }
    var reviewableFiles: [FileItem] { filterViewModel.reviewableFiles }
    var groupedFiles: [FileGroup] { filterViewModel.groupedFiles }
    var allFiles: [FileItem] { scanViewModel.allFiles }
    var recentFiles: [FileItem] { scanViewModel.recentFiles }
    var customFolders: [CustomFolder] { scanViewModel.customFolders }
    var isLoading: Bool { scanViewModel.isScanning }

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

    // MARK: - Keyboard Navigation Delegation

    var isKeyboardNavigating: Bool {
        get { selectionViewModel.isKeyboardNavigating }
        set { selectionViewModel.isKeyboardNavigating = newValue }
    }

    // MARK: - Undo/Redo Stacks (Delegated from Coordinator)

    /// Undo stack for testing and UI status
    var undoStack: [any UndoableCommand] { organizationCoordinator.undoStack }

    /// Redo stack for testing and UI status
    var redoStack: [any UndoableCommand] { organizationCoordinator.redoStack }

    /// Type alias for backwards compatibility with tests
    typealias OrganizationAction = FileOrganizationCoordinator.OrganizationAction

    #if DEBUG
    /// Test helper to set allFiles directly (bypasses scanning)
    func _testSetFiles(_ files: [FileItem]) {
        scanViewModel._testSetFiles(files)
        filterViewModel.updateSourceFiles(files)
    }

    /// Test helper to push an undo action without file operations
    func _testPushUndoAction(_ action: OrganizationAction) {
        organizationCoordinator._testPushUndoAction(action)
    }
    #endif

    // MARK: - Content Search Delegations

    func searchMatchType(for file: FileItem) -> ContentSearchService.MatchType? {
        contentSearchResults.first { $0.file.path == file.path }?.matchType
    }

    func contentSnippet(for file: FileItem) -> String? {
        contentSearchResults.first { $0.file.path == file.path }?.contentSnippet
    }

    var contentSearchResultsCount: Int {
        contentSearchResults.count
    }

    // MARK: - Panel State Delegations

    func showCelebrationPanel(message: String) {
        panelManager.showCelebrationPanel(message: message)
    }

    // Template & Personality (kept for backwards compatibility)
    func applyTemplate(_ template: OrganizationTemplate, context: ModelContext) {
        // Implementation kept in DashboardViewModel for now
    }

    func applyPerFolderTemplates(
        folderSelection: OnboardingFolderSelection,
        templateSelection: FolderTemplateSelection,
        personality: OrganizationPersonality?,
        context: ModelContext
    ) {
        // Implementation kept in DashboardViewModel for now
    }

    func completePersonalityQuiz(_ personality: OrganizationPersonality) {
        filterViewModel.applyPersonalityPreferences()
    }
}
