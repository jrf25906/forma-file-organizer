import Foundation
import SwiftUI
import SwiftData
import Combine

struct TrustedAutomationScopeRecommendationPreviewSummary: Hashable, Sendable {
    let matchedCount: Int
    let eligibleCount: Int
    let skippedMissingDestinationCount: Int
    let skippedPermissionIssueCount: Int
    let skippedConfidenceThresholdCount: Int
    let exampleFileNames: [String]

    var blockedBySetupCount: Int {
        skippedMissingDestinationCount + skippedPermissionIssueCount
    }

    var reviewCount: Int {
        max(matchedCount - eligibleCount - blockedBySetupCount, 0)
    }

    var summaryText: String {
        guard matchedCount > 0 else {
            return "No pending or ready files currently match this scope."
        }

        if eligibleCount == 0, reviewCount == 0, blockedBySetupCount > 0 {
            return blockerOnlySummaryText
        }

        if reviewCount == 0, blockedBySetupCount == 0 {
            if matchedCount == 1 {
                return "1 current match. It would move automatically on the first pass."
            }

            return "\(matchedCount) current matches. All \(eligibleCount) would move automatically on the first pass."
        }

        if eligibleCount == 0, blockedBySetupCount == 0 {
            if matchedCount == 1 {
                return "1 current match. It would stay in review."
            }

            return "\(matchedCount) current matches. All \(reviewCount) would stay in review."
        }

        var components: [String] = []

        if eligibleCount > 0 {
            components.append("\(eligibleCount) would move automatically on the first pass")
        }

        if reviewCount > 0 {
            components.append("\(reviewCount) would stay in review")
        }

        if blockedBySetupCount > 0 {
            components.append(blockedBySetupSummaryFragment)
        }

        return "\(matchedCount) current matches. \(joinedSummaryComponents(components))."
    }

    private var blockerOnlySummaryText: String {
        let blockerDescription = setupBlockerDescription

        if matchedCount == 1 {
            return "1 current match. It is blocked by \(blockerDescription)."
        }

        if matchedCount == 2 {
            return "2 current matches. Both are blocked by \(blockerDescription)."
        }

        return "\(matchedCount) current matches. All \(blockedBySetupCount) are blocked by \(blockerDescription)."
    }

    private var blockedBySetupSummaryFragment: String {
        let blockerDescription = setupBlockerDescription
        let verb = blockedBySetupCount == 1 ? "is" : "are"
        return "\(blockedBySetupCount) \(verb) blocked by \(blockerDescription)"
    }

    private var setupBlockerDescription: String {
        if skippedMissingDestinationCount > 0, skippedPermissionIssueCount == 0 {
            return skippedMissingDestinationCount == 1 ? "a missing destination" : "missing destinations"
        }

        if skippedPermissionIssueCount > 0, skippedMissingDestinationCount == 0 {
            return skippedPermissionIssueCount == 1 ? "destination permissions" : "destination permissions"
        }

        return "destination or permission setup"
    }

    private func joinedSummaryComponents(_ components: [String]) -> String {
        guard let first = components.first else { return "" }
        guard components.count > 1 else { return first }
        if components.count == 2 {
            return "\(components[0]), and \(components[1])"
        }

        return "\(components.dropLast().joined(separator: ", ")), and \(components.last ?? "")"
    }
}

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

enum ReviewFlowSectionKind: String, CaseIterable, Identifiable {
    case ready
    case review
    case destination

    var id: String { rawValue }
}

struct ReviewFlowSection: Identifiable {
    let kind: ReviewFlowSectionKind
    let files: [FileItem]

    var id: ReviewFlowSectionKind { kind }
}

private struct ReviewPassSnapshotState {
    let snapshotPaths: [String]
    let remainingFiles: [FileItem]
    let organizedPaths: Set<String>
}

struct DashboardAutomationStatusPresentation: Equatable {
    let watchedRootDisplayNames: [String]
    let latestMeaningfulRunSummary: String?
    let latestPreflightSummary: String?

    var headlineText: String {
        if !watchedRootDisplayNames.isEmpty {
            return "Watching \(Self.joinedRootNames(watchedRootDisplayNames))"
        }

        if latestMeaningfulRunSummary != nil {
            return "Recent automation activity"
        }

        if latestPreflightSummary != nil {
            return "Next automation pass"
        }

        return "Automation"
    }

    static func resolve(
        state: AutomationState,
        watchedRootDisplayNames: [String]
    ) -> DashboardAutomationStatusPresentation? {
        let cleanedRootNames = watchedRootDisplayNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let runSummary = meaningfulRunSummary(from: state)
        let preflightSummary = meaningfulPreflightSummary(from: state.lastPreflightSummary)

        guard !cleanedRootNames.isEmpty || runSummary != nil || preflightSummary != nil else {
            return nil
        }

        return DashboardAutomationStatusPresentation(
            watchedRootDisplayNames: cleanedRootNames,
            latestMeaningfulRunSummary: runSummary,
            latestPreflightSummary: preflightSummary
        )
    }

    private static func meaningfulRunSummary(from state: AutomationState) -> String? {
        guard state.lastRunDate != nil else { return nil }

        var fragments: [String] = []

        if state.lastRunSuccessCount > 0 {
            fragments.append(
                state.lastRunSuccessCount == 1
                    ? "organized 1 file"
                    : "organized \(state.lastRunSuccessCount) files"
            )
        }

        if state.lastRunSkippedCount > 0 {
            fragments.append(
                state.lastRunSkippedCount == 1
                    ? "skipped 1"
                    : "skipped \(state.lastRunSkippedCount)"
            )
        }

        if state.lastRunFailedCount > 0 {
            fragments.append(
                state.lastRunFailedCount == 1
                    ? "failed 1"
                    : "failed \(state.lastRunFailedCount)"
            )
        }

        guard !fragments.isEmpty else { return nil }

        if fragments.count == 1, let fragment = fragments.first {
            return "Last run \(fragment)"
        }

        if fragments.count == 2 {
            return "Last run \(fragments[0]) and \(fragments[1])"
        }

        let head = fragments.dropLast().joined(separator: ", ")
        return "Last run \(head), and \(fragments.last ?? "")"
    }

    private static func meaningfulPreflightSummary(from summary: AutomationPreflightSummary?) -> String? {
        guard let summary else { return nil }

        var fragments: [String] = []

        if summary.eligibleCount > 0 {
            fragments.append("\(summary.eligibleCount) ready now")
        }

        if summary.skippedMissingDestination > 0 {
            fragments.append(
                summary.skippedMissingDestination == 1
                    ? "1 missing destination"
                    : "\(summary.skippedMissingDestination) missing destinations"
            )
        }

        if summary.skippedPermissionIssues > 0 {
            fragments.append(
                summary.skippedPermissionIssues == 1
                    ? "1 waiting for access"
                    : "\(summary.skippedPermissionIssues) waiting for access"
            )
        }

        if summary.skippedConfidenceThreshold > 0 {
            fragments.append(
                summary.skippedConfidenceThreshold == 1
                    ? "1 held for review"
                    : "\(summary.skippedConfidenceThreshold) held for review"
            )
        }

        guard !fragments.isEmpty else { return nil }
        return Array(fragments.prefix(2)).joined(separator: " · ")
    }

    private static func joinedRootNames(_ names: [String]) -> String {
        guard let first = names.first else { return "folders" }
        guard names.count > 1 else { return first }
        if names.count == 2 {
            return "\(names[0]) and \(names[1])"
        }

        return "\(names.dropLast().joined(separator: ", ")), and \(names.last ?? "")"
    }
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

    func startupInspectorVisibility(savedPreference: Bool?) -> Bool {
        guard let savedPreference else {
            return defaultInspectorVisibility
        }

        guard savedPreference else {
            return false
        }

        return launchWidth >= Self.inspectorEligibleWidth
    }
}

struct WorkflowInspectorRunSummary: Equatable {
    let runID: UUID
    let templateDisplayName: String
    let statusText: String
    let rollbackText: String
    let triggerSurfaceLabel: String
    let ownerDisplayName: String?
    let policyName: String?
    let renameResultFileName: String?
    let appliedTags: [String]
    let projectAssociationDisplayName: String?
    let workflowStatusDisplayName: String?
    let moveDestinationDisplayName: String?

    var canOpenRunDetail: Bool { true }
}

struct ProjectSpaceWorkflowRunSummary: Equatable {
    let templateDisplayName: String
    let statusText: String
    let completedText: String

    var summaryText: String {
        "Latest run: \(templateDisplayName) \(statusText.lowercased()) \(completedText)."
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
    @Published var selectedWorkflowTemplateID: String? {
        didSet {
            guard selectedWorkflowTemplateID != oldValue else { return }
            WorkflowTemplateSelectionStore(defaults: userDefaults).selectedTemplateID = selectedWorkflowTemplateID
        }
    }
    @Published var selectedProjectSpaceWorkflowTemplateID: String? {
        didSet {
            guard !isSynchronizingProjectSpaceWorkflowState,
                  selectedProjectSpaceWorkflowTemplateID != oldValue else { return }
            persistSelectedProjectSpaceWorkflowTemplate()
            refreshProjectSpaceWorkflowPreview()
            if featureFlags.isEnabled(.workflowEngineV2),
               selectedProjectSpaceDetail != nil,
               projectSpaceWorkflowCandidateFiles.isEmpty {
                scheduleProjectSpaceWorkflowPreparation()
            }
        }
    }
    @Published private(set) var projectSpaces: [ProjectSpaceSummary] = []
    @Published private(set) var selectedProjectSpace: ProjectSpaceSummary?
    @Published private(set) var selectedProjectSpaceDetail: ProjectSpaceDetail?
    @Published private(set) var isShowingProjectSpaceDetail: Bool = false
    @Published private(set) var selectedProjectSpaceAutomationBoard: ProjectSpaceAutomationBoard?
    @Published private(set) var selectedProjectSpaceAutomationPolicyDetail: ProjectSpaceAutomationPolicyDetail?
    @Published private(set) var isProjectSpaceAutomationPolicySheetPresented: Bool = false
    @Published private(set) var isProjectSpaceAutomationComposerPresented: Bool = false
    @Published var projectSpaceAutomationComposerDraft: ProjectSpaceAutomationComposerDraft?
    @Published private(set) var isProjectSpaceWorkflowInProgress: Bool = false
    @Published private(set) var isPreparingProjectSpaceWorkflowPreview: Bool = false
    @Published private(set) var projectSpaceWorkflowSimulationPreview: WorkflowTemplateSimulationPreview?
    @Published private(set) var selectedProjectSpaceWorkflowLatestRunSummary: ProjectSpaceWorkflowRunSummary?
    @Published private(set) var projectSpaceAssociationCorrectionFileRow: ProjectSpaceFileRow?
    @Published var projectSpaceAssociationCorrectionProposedLabel: String = ""
    @Published private(set) var projectSpaceAssociationSuggestedLabels: [String] = []
    @Published private(set) var trustedAutomationScopeSections: [TrustedAutomationScopeSummarySection] = []
    @Published private(set) var defaultPanelTrustedAutomationScopes: [TrustedAutomationScopeSummary] = []
    @Published private(set) var selectedTrustedAutomationScopeDetail: TrustedAutomationScopeDetail?
    @Published private(set) var isTrustedAutomationScopeDetailPresented: Bool = false

    // MARK: - Organization Progress State
    /// Baseline count of actionable files captured at the start of the current scan session.
    @Published private(set) var organizationProgressTotalCount: Int = 0

    // MARK: - Services
    private let fileSystemService: FileSystemServiceProtocol
    private let fileScanPipeline: FileScanPipelineProtocol
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
    private var lastObservedProjectSpaceFeatureState: (
        metadataFoundation: Bool,
        projectSpaces: Bool,
        automationBoard: Bool
    )
    private var bulkOperationTask: Task<Void, Never>?
    private var permissionRefreshTask: Task<Void, Never>?
    private var projectSpaceWorkflowPreparationTask: Task<Void, Never>?
    private var trustedAutomationScopeRefreshTask: Task<Void, Never>?
    private var lastPresentedExternalSessionID: UUID?
    private var deferredReviewPathsByScope: [ReviewChunkScopeKey: Set<String>] = [:]
    private var reviewPassPathsByScope: [ReviewChunkScopeKey: [String]] = [:]
    private var organizedReviewPathsByScope: [ReviewChunkScopeKey: Set<String>] = [:]
    private var projectSpaceWorkflowCandidateFiles: [FileItem] = []
    private var isSynchronizingProjectSpaceWorkflowState = false
    private var selectedProjectSpaceAutomationPolicyID: UUID?

    // MARK: - Initialization

    init(
        services: AppServices,
        fileSystemService: FileSystemServiceProtocol,
        fileScanPipeline: FileScanPipelineProtocol,
        workflowExecution: WorkflowExecutionClient = .live,
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
        self.isRightPanelVisible = launchPresentation.startupInspectorVisibility(
            savedPreference: windowPresentationStore.savedInspectorVisibility
        )
        self.fileSystemService = fileSystemService
        self.fileScanPipeline = fileScanPipeline
        self.storageService = services.storageService
        self.notificationService = services.notificationService
        self.quickLookService = services.quickLookService
        self.insightsService = services.insightsService
        self.userDefaults = userDefaults
        self.selectedWorkflowTemplateID = WorkflowTemplateSelectionStore(defaults: userDefaults).selectedTemplateID
        self.lastObservedProjectSpaceFeatureState = (
            featureFlags.isEnabled(.metadataFoundation),
            featureFlags.isEnabled(.projectSpaces),
            featureFlags.isEnabled(.projectSpaceAutomationBoard)
        )
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
            notificationService: notificationService,
            workflowExecution: workflowExecution
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
        setupFeatureFlagObservation()
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
        projectSpaceWorkflowPreparationTask?.cancel()
        trustedAutomationScopeRefreshTask?.cancel()
    }

    @discardableResult
    func adoptModelContextIfNeeded(_ context: ModelContext) -> Bool {
        if let modelContext, modelContext === context {
            return false
        }

        modelContext = context
        return true
    }

    func setModelContext(_ context: ModelContext) {
        guard adoptModelContextIfNeeded(context) else { return }

        refreshContentTagQuickFilters()
        refreshProjectSpaces()

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

    func scheduleTrustedAutomationScopeRefresh(referenceDate: Date = Date()) {
        trustedAutomationScopeRefreshTask?.cancel()
        trustedAutomationScopeRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(75))
            guard !Task.isCancelled else { return }
            self?.refreshTrustedAutomationScopes(referenceDate: referenceDate)
        }
    }

    func cancelScheduledTrustedAutomationScopeRefresh() {
        trustedAutomationScopeRefreshTask?.cancel()
        trustedAutomationScopeRefreshTask = nil
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
        refreshTrustedAutomationScopes(referenceDate: Date())
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

    // MARK: - Project Spaces

    func refreshProjectSpaces() {
        let featureState = currentProjectSpaceFeatureState()
        lastObservedProjectSpaceFeatureState = featureState

        guard let modelContext,
              featureState.metadataFoundation,
              featureState.projectSpaces else {
            clearProjectSpaceState()
            return
        }

        let metadataService = FileMetadataFoundationService(modelContext: modelContext)
        let summaries = metadataService.fetchProjectSpaceSummaries()
        projectSpaces = summaries

        guard let selectedProjectSpace else {
            clearProjectSpaceAssociationCorrection()
            if summaries.isEmpty {
                selectedProjectSpaceDetail = nil
                isShowingProjectSpaceDetail = false
            }
            return
        }

        guard let refreshedSummary = summaries.first(where: { $0.id == selectedProjectSpace.id }),
              let detail = metadataService.fetchProjectSpaceDetail(for: refreshedSummary.normalizedLabel) else {
            closeProjectSpaceDetail()
            return
        }

        self.selectedProjectSpace = refreshedSummary
        selectedProjectSpaceDetail = detail
        isShowingProjectSpaceDetail = true
        reconcileProjectSpaceAssociationCorrection(with: detail)
        loadProjectSpaceWorkflowState(for: detail)
    }

    func selectProjectSpace(_ summary: ProjectSpaceSummary) {
        guard let modelContext,
              featureFlags.isEnabled(.metadataFoundation),
              featureFlags.isEnabled(.projectSpaces) else {
            closeProjectSpaceDetail()
            return
        }

        let metadataService = FileMetadataFoundationService(modelContext: modelContext)
        guard let detail = metadataService.fetchProjectSpaceDetail(for: summary.normalizedLabel) else {
            closeProjectSpaceDetail()
            refreshProjectSpaces()
            return
        }

        if selectedProjectSpace?.id != detail.summary.id {
            clearProjectSpaceAssociationCorrection()
        }

        selectedProjectSpace = projectSpaces.first(where: { $0.id == detail.summary.id }) ?? detail.summary
        selectedProjectSpaceDetail = detail
        isShowingProjectSpaceDetail = true
        loadProjectSpaceWorkflowState(for: detail)
    }

    func organizeSelectedProjectSpace() async {
        guard let modelContext,
              featureFlags.isEnabled(.metadataFoundation),
              featureFlags.isEnabled(.projectSpaces),
              featureFlags.isEnabled(.workflowEngineV2) else {
            return
        }

        guard let detail = resolveCurrentProjectSpaceDetail(for: modelContext) else {
            refreshProjectSpaces()
            return
        }

        guard let template = WorkflowTemplateCatalog.template(for: selectedProjectSpaceWorkflowTemplateID) else {
            showToast(
                message: "Choose a built-in workflow template before organizing this project space.",
                canUndo: false
            )
            return
        }

        isProjectSpaceWorkflowInProgress = true
        defer { isProjectSpaceWorkflowInProgress = false }

        let profileService = ProjectSpaceWorkflowProfileService(modelContext: modelContext)
        do {
            try profileService.upsertPreferredTemplate(
                template.id,
                for: detail.summary.normalizedLabel,
                at: Date()
            )
        } catch {
            errorMessage = error.localizedDescription
            showToast(message: error.localizedDescription, canUndo: false)
            return
        }

        let preparedFiles = await prepareProjectSpaceWorkflowCandidateFiles(
            for: detail,
            context: modelContext,
            showsErrors: true
        )
        projectSpaceWorkflowCandidateFiles = preparedFiles
        refreshProjectSpaceWorkflowPreview()

        let execution = bulkOperationViewModel.prepareWorkflowExecution(
            preparedFiles,
            template: template,
            invocationContext: .projectSpace(projectLabel: detail.projectLabel)
        )
        let workflowScopeID = UUID()

        guard !execution.partition.runnableFiles.isEmpty else {
            if preparedFiles.isEmpty {
                showToast(
                    message: "No reachable files in this project space are available to organize.",
                    canUndo: false
                )
            } else {
                bulkOperationViewModel.presentPreparedWorkflowExecutionFeedback(
                    execution,
                    totalCount: preparedFiles.count
                )
            }
            refreshProjectSpaces()
            return
        }

        do {
            let runRecord = try await bulkOperationViewModel.runPreparedWorkflowExecution(
                execution,
                scopeID: workflowScopeID,
                context: modelContext
            )

            persistProjectSpaceLatestRunBestEffort(
                runRecord,
                profileService: profileService,
                normalizedProjectLabel: detail.summary.normalizedLabel,
                at: Date()
            )
            bulkOperationViewModel.presentPreparedWorkflowExecutionFeedback(
                execution,
                totalCount: preparedFiles.count
            )
            handleMetadataMutationCompletion()
        } catch {
            if let failedRun = latestWorkflowRun(
                scopeID: workflowScopeID,
                workflowTemplateID: template.id,
                context: modelContext
            ) {
                persistProjectSpaceLatestRunBestEffort(
                    failedRun,
                    profileService: profileService,
                    normalizedProjectLabel: detail.summary.normalizedLabel,
                    at: Date()
                )
            }

            bulkOperationViewModel.presentPreparedWorkflowExecutionFailure(execution, error: error)
            errorMessage = error.localizedDescription
            handleMetadataMutationCompletion()
        }
    }

    func presentProjectSpaceAutomationComposer() {
        guard isProjectSpaceAutomationBoardEnabled,
              let selectedProjectSpace else {
            return
        }

        let recommendation: ProjectSpaceAutomationRecommendation? = {
            guard let detail = selectedProjectSpaceDetail,
                  detail.summary.normalizedLabel == selectedProjectSpace.normalizedLabel else {
                return nil
            }

            return ProjectSpaceAutomationRecommendationService()
                .recommendedPolicies(for: detail, now: Date())
                .first
        }()

        projectSpaceAutomationComposerDraft = ProjectSpaceAutomationComposerDraft(
            normalizedProjectLabel: selectedProjectSpace.normalizedLabel,
            workflowTemplateID: recommendation?.workflowTemplateID,
            triggerKinds: recommendation?.triggerKinds ?? [.manual],
            admissionMode: recommendation?.admissionMode ?? .manualReview
        )
        isProjectSpaceAutomationComposerPresented = true
    }

    func dismissProjectSpaceAutomationComposer() {
        isProjectSpaceAutomationComposerPresented = false
        projectSpaceAutomationComposerDraft = nil
    }

    func createProjectSpaceAutomationPolicyFromComposer() {
        guard isProjectSpaceAutomationBoardEnabled,
              let modelContext,
              let draft = projectSpaceAutomationComposerDraft,
              let selectedProjectSpaceDetail else {
            return
        }

        do {
            let service = ProjectSpaceAutomationService(modelContext: modelContext)
            _ = try service.createOrUpdatePolicy(
                normalizedProjectLabel: draft.normalizedProjectLabel,
                workflowTemplateID: draft.workflowTemplateID ?? "",
                triggerKinds: draft.triggerKinds,
                admissionMode: draft.admissionMode,
                state: draft.state,
                updatedAt: Date()
            )
            dismissProjectSpaceAutomationComposer()
            loadProjectSpaceAutomationState(for: selectedProjectSpaceDetail)
        } catch {
            errorMessage = error.localizedDescription
            showToast(message: error.localizedDescription, canUndo: false)
        }
    }

    func presentProjectSpaceAutomationPolicy(id: UUID) {
        selectedProjectSpaceAutomationPolicyID = id
        isProjectSpaceAutomationPolicySheetPresented = true
        refreshSelectedProjectSpaceAutomationPolicyDetail()
    }

    func dismissProjectSpaceAutomationPolicy() {
        isProjectSpaceAutomationPolicySheetPresented = false
        selectedProjectSpaceAutomationPolicyID = nil
        selectedProjectSpaceAutomationPolicyDetail = nil
    }

    func pauseSelectedProjectSpaceAutomationPolicy() {
        guard isProjectSpaceAutomationBoardEnabled,
              let modelContext,
              let policyID = selectedProjectSpaceAutomationPolicyID else {
            return
        }

        do {
            try ProjectSpaceAutomationService(modelContext: modelContext).pausePolicy(id: policyID, at: Date())
            if let detail = selectedProjectSpaceDetail {
                loadProjectSpaceAutomationState(for: detail)
            }
        } catch {
            errorMessage = error.localizedDescription
            showToast(message: error.localizedDescription, canUndo: false)
        }
    }

    func activateSelectedProjectSpaceAutomationPolicy() {
        guard isProjectSpaceAutomationBoardEnabled,
              let modelContext,
              let policyID = selectedProjectSpaceAutomationPolicyID else {
            return
        }

        do {
            try ProjectSpaceAutomationService(modelContext: modelContext).activatePolicy(id: policyID, at: Date())
            if let detail = selectedProjectSpaceDetail {
                loadProjectSpaceAutomationState(for: detail)
            }
        } catch {
            errorMessage = error.localizedDescription
            showToast(message: error.localizedDescription, canUndo: false)
        }
    }

    func resumeSelectedProjectSpaceAutomationPolicy() {
        guard isProjectSpaceAutomationBoardEnabled,
              let modelContext,
              let policyID = selectedProjectSpaceAutomationPolicyID else {
            return
        }

        do {
            try ProjectSpaceAutomationService(modelContext: modelContext).resumePolicy(id: policyID, at: Date())
            if let detail = selectedProjectSpaceDetail {
                loadProjectSpaceAutomationState(for: detail)
            }
        } catch {
            errorMessage = error.localizedDescription
            showToast(message: error.localizedDescription, canUndo: false)
        }
    }

    func runSelectedProjectSpaceAutomationPolicyManually() async {
        guard isProjectSpaceAutomationBoardEnabled,
              let modelContext,
              featureFlags.isEnabled(.metadataFoundation),
              featureFlags.isEnabled(.projectSpaces),
              featureFlags.isEnabled(.workflowEngineV2),
              let policyID = selectedProjectSpaceAutomationPolicyID,
              let detail = resolveCurrentProjectSpaceDetail(for: modelContext),
              let policy = ProjectSpaceAutomationService(modelContext: modelContext).policy(id: policyID),
              let template = WorkflowTemplateCatalog.template(for: policy.workflowTemplateID) else {
            return
        }

        isProjectSpaceWorkflowInProgress = true
        defer { isProjectSpaceWorkflowInProgress = false }
        let now = Date()
        let profileService = ProjectSpaceWorkflowProfileService(modelContext: modelContext)
        let automationService = ProjectSpaceAutomationService(modelContext: modelContext)

        let preparedFiles = await prepareProjectSpaceWorkflowCandidateFiles(
            for: detail,
            context: modelContext,
            showsErrors: true
        )
        let executionCandidateFiles: [FileItem]
        do {
            executionCandidateFiles = try ProjectSpaceAutomationCoordinator(
                modelContext: modelContext,
                metadataAdmissionWriter: FileMetadataFoundationService(modelContext: modelContext),
                automationService: automationService
            ).eligibleFilesForExecution(
                policy,
                detail: detail,
                files: preparedFiles,
                now: now
            )
        } catch {
            errorMessage = error.localizedDescription
            showToast(message: error.localizedDescription, canUndo: false)
            loadProjectSpaceAutomationState(for: detail)
            return
        }

        projectSpaceWorkflowCandidateFiles = executionCandidateFiles
        refreshProjectSpaceWorkflowPreview()
        refreshSelectedProjectSpaceAutomationPolicyDetail()

        let workflowScopeID = UUID()
        let execution = bulkOperationViewModel.prepareWorkflowExecution(
            executionCandidateFiles,
            template: template,
            request: automationService.workflowExecutionRequest(
                for: policy,
                projectLabel: detail.projectLabel,
                triggerKind: .manual,
                scopeID: workflowScopeID
            )
        )

        guard !execution.partition.runnableFiles.isEmpty else {
            if preparedFiles.isEmpty {
                showToast(
                    message: "No reachable files in this project space are available to organize.",
                    canUndo: false
                )
            } else if executionCandidateFiles.isEmpty {
                showToast(
                    message: "No files met this policy's project-admission requirements.",
                    canUndo: false
                )
            } else {
                bulkOperationViewModel.presentPreparedWorkflowExecutionFeedback(
                    execution,
                    totalCount: executionCandidateFiles.count
                )
            }
            loadProjectSpaceAutomationState(for: detail)
            return
        }

        do {
            let runRecord = try await bulkOperationViewModel.runPreparedWorkflowExecution(
                execution,
                scopeID: workflowScopeID,
                context: modelContext
            )
            persistProjectSpaceLatestRunBestEffort(
                runRecord,
                profileService: profileService,
                normalizedProjectLabel: detail.summary.normalizedLabel,
                at: now
            )
            _ = try? automationService.recordRun(
                policyID: policy.id,
                workflowTemplateID: template.id,
                triggerKind: .manual,
                workflowRunID: runRecord.id,
                status: automationRunStatus(for: runRecord.primaryStatus),
                startedAt: runRecord.startedAt,
                endedAt: runRecord.endedAt ?? now,
                createdAt: now
            )
            bulkOperationViewModel.presentPreparedWorkflowExecutionFeedback(
                execution,
                totalCount: executionCandidateFiles.count
            )
            handleMetadataMutationCompletion()
        } catch {
            if let failedRun = latestWorkflowRun(
                scopeID: workflowScopeID,
                workflowTemplateID: template.id,
                context: modelContext
            ) {
                persistProjectSpaceLatestRunBestEffort(
                    failedRun,
                    profileService: profileService,
                    normalizedProjectLabel: detail.summary.normalizedLabel,
                    at: now
                )
                _ = try? automationService.recordRun(
                    policyID: policy.id,
                    workflowTemplateID: template.id,
                    triggerKind: .manual,
                    workflowRunID: failedRun.id,
                    status: automationRunStatus(for: failedRun.primaryStatus),
                    startedAt: failedRun.startedAt,
                    endedAt: failedRun.endedAt ?? now,
                    createdAt: now
                )
            }

            bulkOperationViewModel.presentPreparedWorkflowExecutionFailure(execution, error: error)
            errorMessage = error.localizedDescription
            handleMetadataMutationCompletion()
        }
    }

    func openFileFromProjectSpace(_ fileRow: ProjectSpaceFileRow) {
        if let file = scanViewModel.allFiles.first(where: { $0.path == fileRow.normalizedPath }) {
            openInspector(for: file)
            return
        }

        guard let fallbackFile = makeInspectorFallbackFile(for: fileRow) else {
            return
        }

        openInspector(for: fallbackFile)
    }

    func beginProjectSpaceAssociationCorrection(_ fileRow: ProjectSpaceFileRow) {
        projectSpaceAssociationCorrectionFileRow = fileRow
        projectSpaceAssociationCorrectionProposedLabel = fileRow.projectAssociation ?? selectedProjectSpaceDetail?.projectLabel ?? ""

        let excludedLabels = Set(
            [fileRow.projectAssociation, selectedProjectSpaceDetail?.projectLabel]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
        projectSpaceAssociationSuggestedLabels = projectSpaces
            .map(\.displayName)
            .filter { !excludedLabels.contains($0) }
    }

    func saveProjectSpaceAssociationCorrection() {
        guard let modelContext,
              let correctionFileRow = projectSpaceAssociationCorrectionFileRow else {
            return
        }

        let proposedLabel = projectSpaceAssociationCorrectionProposedLabel
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !proposedLabel.isEmpty else { return }

        do {
            let metadataService = FileMetadataFoundationService(modelContext: modelContext)
            _ = try metadataService.correctProjectAssociation(
                forCanonicalIdentity: correctionFileRow.canonicalIdentity,
                to: proposedLabel,
                timestamp: Date()
            )
            refreshProjectSpaces()
            clearProjectSpaceAssociationCorrection()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancelProjectSpaceAssociationCorrection() {
        clearProjectSpaceAssociationCorrection()
    }

    func closeProjectSpaceDetail() {
        clearProjectSpaceAssociationCorrection()
        clearProjectSpaceWorkflowState()
        selectedProjectSpace = nil
        selectedProjectSpaceDetail = nil
        isShowingProjectSpaceDetail = false
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
            return session.summary.statusText
        }

        return ([session.summary.statusText] + uniqueSkipMessages).joined(separator: " ")
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
    var selectedWorkflowTemplate: BuiltInWorkflowTemplate? {
        WorkflowTemplateCatalog.template(for: selectedWorkflowTemplateID)
    }
    var showsDashboardWorkflowTemplatePicker: Bool {
        featureFlags.isEnabled(.workflowEngineV2) && !dashboardWorkflowCandidateFiles.isEmpty
    }
    var dashboardWorkflowSimulationPreview: WorkflowTemplateSimulationPreview? {
        guard showsDashboardWorkflowTemplatePicker else {
            return nil
        }

        return WorkflowTemplateSimulationPreview.make(
            templateID: selectedWorkflowTemplateID,
            files: dashboardWorkflowCandidateFiles,
            invocationContext: .dashboardReview
        )
    }
    var inspectorWorkflowSimulationPreview: WorkflowTemplateSimulationPreview? {
        guard featureFlags.isEnabled(.workflowEngineV2) else {
            return nil
        }

        return WorkflowTemplateSimulationPreview.make(
            templateID: selectedWorkflowTemplateID,
            files: selectedFiles,
            invocationContext: .inspector
        )
    }
    var isProjectSpaceAutomationBoardEnabled: Bool {
        featureFlags.isEnabled(.projectSpaceAutomationBoard)
    }
    var isProjectSpaceWorkflowTemplatePickerEnabled: Bool {
        featureFlags.isEnabled(.workflowEngineV2) &&
            !isProjectSpaceWorkflowInProgress &&
            !isProjectSpaceAutomationBoardEnabled
    }
    var selectedProjectSpaceAutomationPolicyPreview: WorkflowTemplateSimulationPreview? {
        guard isProjectSpaceAutomationBoardEnabled,
              let detail = selectedProjectSpaceDetail,
              let policy = selectedProjectSpaceAutomationPolicyDetail else {
            return nil
        }

        return WorkflowTemplateSimulationPreview.make(
            templateID: policy.workflowTemplateID,
            files: projectSpaceWorkflowCandidateFiles,
            invocationContext: .projectPolicyManual(
                projectLabel: detail.projectLabel,
                policyName: policy.workflowTemplateDisplayName
            )
        )
    }
    var selectedProjectSpaceAutomationManualRunDisabledReason: String? {
        guard isProjectSpaceAutomationBoardEnabled else {
            return nil
        }

        guard selectedProjectSpaceDetail != nil else {
            return nil
        }

        if isProjectSpaceWorkflowInProgress {
            return "Project policy execution is already running."
        }

        guard let policy = selectedProjectSpaceAutomationPolicyDetail,
              WorkflowTemplateCatalog.template(for: policy.workflowTemplateID) != nil else {
            return "Choose a project policy before running it."
        }

        if policy.state == .revoked {
            return "Revoked policies cannot run until they are recreated."
        }

        if isPreparingProjectSpaceWorkflowPreview {
            return "Preparing reachable files for this project space."
        }

        if let preview = selectedProjectSpaceAutomationPolicyPreview {
            if preview.readyToRunCount == 0 {
                return preview.blockedCount > 0
                    ? "All reachable files in this project space are blocked in simulation."
                    : "No reachable files in this project space are available to organize."
            }

            return nil
        }

        return projectSpaceWorkflowCandidateFiles.isEmpty
            ? "No reachable files in this project space are available to organize."
            : nil
    }
    var projectSpaceWorkflowDisabledReason: String? {
        guard selectedProjectSpaceDetail != nil else {
            return nil
        }

        guard featureFlags.isEnabled(.workflowEngineV2) else {
            return "Workflow templates are unavailable right now."
        }

        if isProjectSpaceWorkflowInProgress {
            return "Project space organization is already running."
        }

        guard WorkflowTemplateCatalog.template(for: selectedProjectSpaceWorkflowTemplateID) != nil else {
            return "Choose a built-in workflow template to organize this project space."
        }

        if isPreparingProjectSpaceWorkflowPreview {
            return "Preparing reachable files for this project space."
        }

        if let preview = projectSpaceWorkflowSimulationPreview {
            if preview.readyToRunCount == 0 {
                return preview.blockedCount > 0
                    ? "All reachable files in this project space are blocked in simulation."
                    : "No reachable files in this project space are available to organize."
            }

            return nil
        }

        return projectSpaceWorkflowCandidateFiles.isEmpty
            ? "No reachable files in this project space are available to organize."
            : nil
    }
    func latestWorkflowInspectorSummary(
        for filePath: String,
        context: ModelContext? = nil
    ) -> WorkflowInspectorRunSummary? {
        guard featureFlags.isEnabled(.workflowEngineV2),
              let context else {
            return nil
        }

        let store = WorkflowAuditStore(modelContext: context)
        guard let lookup = try? store.latestRunLookup(forPath: filePath) else {
            return nil
        }

        let run = lookup.run
        let fileIdentity = lookup.fileIdentity
        let stepRuns = (try? store.stepRuns(runID: run.id)) ?? []
        let stepRunsByID = Dictionary(uniqueKeysWithValues: stepRuns.map { ($0.id, $0) })
        let fileActions = ((try? store.fileActions(runID: run.id)) ?? [])
            .filter { $0.fileIdentity == fileIdentity }

        let renameAction = fileActions.last {
            workflowStepKind(for: $0, using: stepRunsByID) == .rename && $0.destinationPath != nil
        }
        let moveAction = fileActions.last {
            workflowStepKind(for: $0, using: stepRunsByID) == .move && $0.destinationPath != nil
        }
        let appliedTags = Array(
            Set(
                fileActions.flatMap { action -> [String] in
                    if let metadataDelta = action.metadataDelta,
                       !metadataDelta.addedTags.isEmpty {
                        return metadataDelta.addedTags
                    }

                    guard workflowStepKind(for: action, using: stepRunsByID) == .tag,
                          case .tagRemoval(_, let tagsToRemove)? = WorkflowCompensationPayloadCodec.decode(action.compensationPayload) else {
                        return []
                    }
                    return tagsToRemove
                }
            )
        ).sorted()
        let projectAssociationDisplayName = fileActions
            .compactMap { action -> String? in
                guard workflowStepKind(for: action, using: stepRunsByID) == .projectAssociation else {
                    return nil
                }
                return action.metadataDelta?.resultingProjectAssociation
            }
            .last
        let workflowStatusDisplayName = fileActions
            .compactMap { action -> String? in
                guard workflowStepKind(for: action, using: stepRunsByID) == .workflowStatus else {
                    return nil
                }
                guard let status = action.metadataDelta?.resultingWorkflowStatus else {
                    return nil
                }
                return status.rawValue.capitalized
            }
            .last

        return WorkflowInspectorRunSummary(
            runID: run.id,
            templateDisplayName: WorkflowTemplateCatalog.template(for: run.workflowTemplateID)?.displayName ?? "Workflow",
            statusText: ActivityItem.workflowStatusText(
                primaryStatus: run.primaryStatus,
                rollbackStatus: run.rollbackStatus
            ),
            rollbackText: ActivityItem.workflowRollbackText(
                primaryStatus: run.primaryStatus,
                rollbackStatus: run.rollbackStatus
            ),
            triggerSurfaceLabel: ActivityItem.workflowTriggerSurfaceLabel(run.triggerSurface),
            ownerDisplayName: run.ownerDisplayName,
            policyName: run.policyName,
            renameResultFileName: renameAction?.destinationPath.flatMap { path in
                URL(fileURLWithPath: path).lastPathComponent
            },
            appliedTags: appliedTags,
            projectAssociationDisplayName: projectAssociationDisplayName,
            workflowStatusDisplayName: workflowStatusDisplayName,
            moveDestinationDisplayName: moveAction?.destinationPath.flatMap { path in
                URL(fileURLWithPath: path).deletingLastPathComponent().lastPathComponent
            }
        )
    }
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
            let result = await self.bulkOperationViewModel.organizeSelectedFiles(
                self.selectedFiles,
                context: context,
                workflowTemplateID: self.selectedWorkflowTemplateID
            )
            if result == .executionAttempted {
                self.deselectAll()
                self.filterViewModel.applyFilterImmediately()
            }
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
            _ = await self.bulkOperationViewModel.organizeAllReadyFiles(
                self.reviewableFiles,
                context: context,
                workflowTemplateID: self.selectedWorkflowTemplateID
            )
            self.filterViewModel.applyFilterImmediately()
        }
    }

    func organizeFirstRunQuickWin(context: ModelContext? = nil) {
        let quickWinFiles = firstRunQuickWinBatch?.files ?? []
        guard !quickWinFiles.isEmpty else { return }

        startBulkOperation { [weak self] in
            guard let self else { return }
            _ = await self.bulkOperationViewModel.organizeSelectedFiles(
                quickWinFiles,
                context: context,
                workflowTemplateID: self.selectedWorkflowTemplateID
            )
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
        reviewPassPathsByScope.removeValue(forKey: scopeKey)
        organizedReviewPathsByScope.removeValue(forKey: scopeKey)

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

        reviewPassPathsByScope.removeValue(forKey: scopeKey)
        organizedReviewPathsByScope.removeValue(forKey: scopeKey)
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
            _ = await self.bulkOperationViewModel.retryFailedFiles(
                context: context,
                workflowTemplateID: self.selectedWorkflowTemplateID
            )
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
        controller.onDidOrganizeFile = { [weak self] filePath in
            self?.markFileOrganizedInCurrentPass(filePath)
        }
        return controller
    }()

    // MARK: - File Operations

    func organizeFile(
        _ file: FileItem,
        context: ModelContext? = nil,
        sourceSurface: PersonalMemorySourceSurface = .reviewFlow
    ) {
        organizationController.organizeFile(
            file,
            context: context,
            sourceSurface: sourceSurface,
            workflowTemplateID: selectedWorkflowTemplateID
        )
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

    private func selectFileForInspector(_ file: FileItem) {
        isRightPanelVisible = true
        selectionViewModel.selectedFileIDs = [file.path]
        selectionViewModel.focusedFilePath = file.path
    }

    private func openInspector(for file: FileItem) {
        selectFileForInspector(file)
        panelManager.updateRightPanelForSelection([file])
    }

    private func makeInspectorFallbackFile(for fileRow: ProjectSpaceFileRow) -> FileItem? {
        let fallbackTimestamp = fileRow.lastActivityAt == .distantPast ? Date() : fileRow.lastActivityAt
        return FileItem(
            path: fileRow.normalizedPath,
            sizeInBytes: 0,
            creationDate: fallbackTimestamp,
            modificationDate: fallbackTimestamp,
            lastAccessedDate: fallbackTimestamp,
            location: .unknown,
            destination: nil,
            status: fallbackInspectorStatus(for: fileRow.workflowStatus)
        )
    }

    private func fallbackInspectorStatus(for workflowStatus: MetadataWorkflowStatus?) -> FileItem.OrganizationStatus {
        switch workflowStatus {
        case .organized, .archived:
            return .completed
        case .ignored:
            return .skipped
        case .queued, .recovered, .none:
            return .pending
        }
    }

    func showRuleBuilderPanel(editingRule: Rule? = nil, fileContext: FileItem? = nil) {
        isRightPanelVisible = true
        panelManager.showRuleBuilderPanel(editingRule: editingRule, fileContext: fileContext)
    }

    func showRulesManagementPanel() {
        isRightPanelVisible = true
        panelManager.showRulesManagementPanel()
    }

    func showAnalyticsPanel() {
        isRightPanelVisible = true
        panelManager.showAnalyticsPanel()
    }

    func showRuleBuilderPanelForInspector(_ file: FileItem, editingRule: Rule? = nil) {
        selectFileForInspector(file)
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

            openInspector(for: file)
        }
    }

    func returnToDefaultPanel() {
        panelManager.returnToDefaultPanel()
    }

    func shouldShowDefaultPanelPrimaryAction(
        for _: NavigationSelection,
        hasActiveRuleDraft: Bool
    ) -> Bool {
        guard !hasActiveRuleDraft else { return false }
        guard !isSelectionMode else { return false }

        if reviewFilterMode == .needsReview,
           currentReviewChunkCount > 0 {
            return false
        }

        return true
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

    func trustedScopeRecommendationPreviewSummary(
        for scopeType: TrustedAutomationScopeType
    ) -> TrustedAutomationScopeRecommendationPreviewSummary? {
        guard let recommendation = panelManager.trustedScopeRecommendation,
              let option = recommendation.option(for: scopeType) else {
            return nil
        }

        let candidates = scanViewModel.allFiles.filter {
            $0.status == .pending || $0.status == .ready
        }
        let matchedCandidates = trustedScopeMatchingCandidates(
            for: option,
            snapshot: recommendation.snapshot,
            within: candidates
        )
        let preflight = AutomationEngine.buildPreflightSummary(
            candidates: matchedCandidates,
            confidenceThreshold: recommendedTrustedScopePreviewConfidenceThreshold
        )

        return TrustedAutomationScopeRecommendationPreviewSummary(
            matchedCount: matchedCandidates.count,
            eligibleCount: preflight.eligibleCount,
            skippedMissingDestinationCount: preflight.skippedMissingDestination,
            skippedPermissionIssueCount: preflight.skippedPermissionIssues,
            skippedConfidenceThresholdCount: preflight.skippedConfidenceThreshold,
            exampleFileNames: Array(matchedCandidates.prefix(3).map(\.name))
        )
    }

    var isTrustedScopeRecommendationPresented: Bool {
        panelManager.isTrustedScopeRecommendationPresented
    }

    var trustedAutomationActiveScopeCount: Int {
        trustedAutomationScopeSections
            .first(where: { $0.status == .active })?
            .summaries.count ?? 0
    }

    var trustedAutomationAttentionScopeCount: Int {
        trustedAutomationScopeSections
            .filter { $0.status != .revoked }
            .flatMap(\.summaries)
            .filter { $0.health.state == .needsAttention }
            .count
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
                self?.handleMetadataMutationCompletion()
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
                    self?.handleMetadataMutationCompletion()
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
                self.refreshProjectSpaces()
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

    private func setupFeatureFlagObservation() {
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleProjectSpaceFeatureFlagChange()
            }
            .store(in: &cancellables)
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

    func refreshTrustedAutomationScopes(referenceDate: Date = Date()) {
        guard let modelContext else {
            trustedAutomationScopeSections = []
            defaultPanelTrustedAutomationScopes = []
            selectedTrustedAutomationScopeDetail = nil
            isTrustedAutomationScopeDetailPresented = false
            return
        }

        do {
            let catalogService = TrustedAutomationScopeCatalogService(modelContext: modelContext)
            let sections = try catalogService.buildSummarySections(referenceDate: referenceDate)
            trustedAutomationScopeSections = sections
            defaultPanelTrustedAutomationScopes = Self.makeDefaultPanelTrustedAutomationScopes(from: sections)

            if let selectedScopeID = selectedTrustedAutomationScopeDetail?.id {
                selectedTrustedAutomationScopeDetail = try catalogService.buildDetail(
                    for: selectedScopeID,
                    referenceDate: referenceDate
                )
                if selectedTrustedAutomationScopeDetail == nil {
                    isTrustedAutomationScopeDetailPresented = false
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            trustedAutomationScopeSections = []
            defaultPanelTrustedAutomationScopes = []
            selectedTrustedAutomationScopeDetail = nil
            isTrustedAutomationScopeDetailPresented = false
        }
    }

    func presentTrustedAutomationScopeDetail(
        id: UUID,
        referenceDate: Date = Date()
    ) {
        guard let modelContext else { return }

        do {
            let catalogService = TrustedAutomationScopeCatalogService(modelContext: modelContext)
            selectedTrustedAutomationScopeDetail = try catalogService.buildDetail(
                for: id,
                referenceDate: referenceDate
            )
            isTrustedAutomationScopeDetailPresented = selectedTrustedAutomationScopeDetail != nil
        } catch {
            errorMessage = error.localizedDescription
            showToast(message: error.localizedDescription, canUndo: false)
        }
    }

    func dismissTrustedAutomationScopeDetail() {
        isTrustedAutomationScopeDetailPresented = false
        selectedTrustedAutomationScopeDetail = nil
    }

    func pauseSelectedTrustedAutomationScope(
        at timestamp: Date = Date(),
        referenceDate: Date = Date()
    ) {
        mutateSelectedTrustedAutomationScope(
            timestamp: timestamp,
            referenceDate: referenceDate
        ) { service, id, mutationTimestamp in
            try service.pauseScope(id: id, at: mutationTimestamp)
        }
    }

    func resumeSelectedTrustedAutomationScope(
        at timestamp: Date = Date(),
        referenceDate: Date = Date()
    ) {
        mutateSelectedTrustedAutomationScope(
            timestamp: timestamp,
            referenceDate: referenceDate
        ) { service, id, mutationTimestamp in
            try service.resumeScope(id: id, at: mutationTimestamp)
        }
    }

    func revokeSelectedTrustedAutomationScope(
        at timestamp: Date = Date(),
        referenceDate: Date = Date()
    ) {
        mutateSelectedTrustedAutomationScope(
            timestamp: timestamp,
            referenceDate: referenceDate
        ) { service, id, mutationTimestamp in
            try service.removeScope(id: id, at: mutationTimestamp)
        }
    }

    func presentTrustedScopeRecommendation() {
        panelManager.presentTrustedScopeRecommendation()
    }

    func dismissTrustedScopeRecommendation(clearRecommendation: Bool = false) {
        panelManager.dismissTrustedScopeRecommendation(clearRecommendation: clearRecommendation)
    }

    func confirmTrustedScopeRecommendation(
        selectedScopeType: TrustedAutomationScopeType,
        selectedWorkflowTemplateID: String? = nil,
        context: ModelContext
    ) {
        guard let recommendation = panelManager.trustedScopeRecommendation else { return }

        do {
            let trustedScope = try TrustedAutomationScopeService(modelContext: context).promoteFromReviewDecision(
                recommendation: recommendation,
                selectedScopeType: selectedScopeType,
                selectedWorkflowTemplateID: selectedWorkflowTemplateID
            )
            panelManager.dismissTrustedScopeRecommendation(clearRecommendation: true)
            refreshTrustedAutomationScopes(referenceDate: trustedScope.updatedAt)
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

    private var recommendedTrustedScopePreviewConfidenceThreshold: Double {
        AutomationPolicy.resolve(
            flags: featureFlags,
            userSettings: .current
        ).mlConfidenceThreshold
    }

    private func trustedScopeMatchingCandidates(
        for option: TrustedAutomationScopeRecommendationOption,
        snapshot: OrganizationMemorySnapshot,
        within candidates: [FileItem]
    ) -> [FileItem] {
        switch option.scopeType {
        case .folder, .category:
            guard let boundaryDescriptor = trustedScopeBoundaryDescriptor(
                for: option,
                snapshot: snapshot
            ) else {
                return []
            }

            return candidates.filter { file in
                boundaryDescriptor.matches(candidate: file, destination: file.destination)
            }
        case .rule:
            return candidates.filter { file in
                trustedScopeRuleMatches(
                    file,
                    option: option,
                    snapshot: snapshot
                )
            }
        }
    }

    private func trustedScopeBoundaryDescriptor(
        for option: TrustedAutomationScopeRecommendationOption,
        snapshot: OrganizationMemorySnapshot
    ) -> TrustedAutomationScopeBoundaryDescriptor? {
        guard let destination = snapshot.chosenDestination else {
            return nil
        }

        let sourceBoundary = TrustedAutomationScopeBoundaryDescriptor.SourceBoundary(
            sourceLocation: snapshot.sourceLocation,
            scanRootPath: snapshot.scanRootPath,
            relativeParentPath: snapshot.relativeParentPath
        )
        let destinationSnapshot = TrustedAutomationScopeBoundaryDescriptor.DestinationSnapshot(destination)

        switch option.scopeType {
        case .rule:
            guard let ruleID = trustedScopeRuleID(from: option.scopeKey) else {
                return nil
            }

            return .rule(
                rule: .init(id: ruleID, name: option.displayName),
                source: sourceBoundary,
                destination: destinationSnapshot
            )
        case .folder:
            return .folder(source: sourceBoundary, destination: destinationSnapshot)
        case .category:
            return .category(
                fileTypeCategory: snapshot.fileTypeCategory,
                source: sourceBoundary,
                destination: destinationSnapshot
            )
        }
    }

    private func trustedScopeRuleMatches(
        _ file: FileItem,
        option: TrustedAutomationScopeRecommendationOption,
        snapshot: OrganizationMemorySnapshot
    ) -> Bool {
        guard trustedScopeDestinationMatches(file.destination, snapshot.chosenDestination) else {
            return false
        }

        if let boundaryDescriptor = trustedScopeBoundaryDescriptor(
            for: option,
            snapshot: snapshot
        ) {
            return boundaryDescriptor.matches(candidate: file, destination: file.destination)
        }

        let ruleConditions = trustedScopeDerivedRuleConditions(for: snapshot)
        let logicalOperator: Rule.LogicalOperator = ruleConditions.count > 1 ? .and : .single
        return matchingRule(file: file, conditions: ruleConditions, logicalOperator: logicalOperator)
    }

    private func matchingRule(
        file: FileItem,
        conditions: [RuleCondition],
        logicalOperator: Rule.LogicalOperator
    ) -> Bool {
        struct EphemeralRule: Ruleable {
            let id = UUID()
            let conditionType: Rule.ConditionType
            let conditionValue: String
            let conditions: [RuleCondition]
            let logicalOperator: Rule.LogicalOperator
            let isEnabled = true
            let destination: Destination?
            let actionType: Rule.ActionType = .move
            let sortOrder = 0
            let exclusionConditions: [RuleCondition] = []
        }

        guard let firstCondition = conditions.first else {
            return false
        }

        let rule = EphemeralRule(
            conditionType: firstCondition.type,
            conditionValue: firstCondition.value,
            conditions: conditions,
            logicalOperator: logicalOperator,
            destination: file.destination
        )
        return ruleEngine.fileMatchesRule(file: file, rule: rule)
    }

    private func trustedScopeDerivedRuleConditions(
        for snapshot: OrganizationMemorySnapshot
    ) -> [RuleCondition] {
        var conditions: [RuleCondition] = [.fileExtension(snapshot.fileExtension.lowercased())]
        if snapshot.sourceLocation != .unknown {
            conditions.append(.sourceLocation(snapshot.sourceLocation))
        }
        return conditions
    }

    private func trustedScopeRuleID(from scopeKey: String) -> UUID? {
        guard scopeKey.hasPrefix("rule:") else {
            return nil
        }

        return UUID(uuidString: String(scopeKey.dropFirst("rule:".count)))
    }

    private func trustedScopeDestinationMatches(_ lhs: Destination?, _ rhs: Destination?) -> Bool {
        switch (lhs, rhs) {
        case (.trash, .trash), (nil, nil):
            return true
        case (.folder(let lhsBookmark, _), .folder(let rhsBookmark, _)):
            return lhsBookmark == rhsBookmark
        default:
            return false
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
                summary: session.summary,
                promotionCandidate: session.promotionCandidate
            )
        )
    }

    private func setupBulkOperationCallbacks() {
        bulkOperationViewModel.onShowErrorToast = { [weak self] message in
            self?.errorMessage = message
            self?.showToast(message: message, canUndo: false)
        }

        bulkOperationViewModel.onShowCelebration = { [weak self] message, style in
            let celebrationStyle: PanelStateManager.CelebrationStyle
            switch style {
            case .batchUndo:
                celebrationStyle = .batchUndo
            case .workflowExecution:
                celebrationStyle = .workflowExecution
            }

            self?.panelManager.showCelebrationPanel(
                message: message,
                style: celebrationStyle
            )
        }

        bulkOperationViewModel.onShowToast = { [weak self] message, canUndo in
            self?.showToast(message: message, canUndo: canUndo)
        }

        bulkOperationViewModel.onOperationComplete = { [weak self] _, _ in
            self?.handleMetadataMutationCompletion()
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
    var needsReviewCount: Int { totalPendingCount }
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
    var readyFiles: [FileItem] { reviewFiles(for: .ready, in: currentReviewChunkFiles) }
    var needsReviewFiles: [FileItem] { reviewFiles(for: .review, in: currentReviewChunkFiles) }
    var needsDestinationFiles: [FileItem] { reviewFiles(for: .destination, in: currentReviewChunkFiles) }
    var reviewSections: [ReviewFlowSection] {
        ReviewFlowSectionKind.allCases.compactMap { kind in
            let files = reviewFiles(for: kind, in: currentReviewChunkFiles)
            guard !files.isEmpty else { return nil }
            return ReviewFlowSection(kind: kind, files: files)
        }
    }
    var currentPassCount: Int { currentPassTotalCount }
    var currentPassTotalCount: Int { currentReviewPassState.snapshotPaths.count }
    var currentPassRemainingCount: Int { currentReviewChunkFiles.count }
    var currentPassOrganizedCount: Int { currentReviewPassState.organizedPaths.count }
    var currentPassProgress: Double {
        let total = currentPassTotalCount
        guard total > 0 else { return 1.0 }
        return Double(currentPassOrganizedCount) / Double(total)
    }
    var currentPassReadyCount: Int { readyFiles.count }
    var totalPendingCount: Int { filterViewModel.needsReviewCount }
    var currentReviewChunkCount: Int { currentPassTotalCount }
    var currentReviewChunkPaths: [String] { currentReviewChunkFiles.map(\.path) }
    var currentReviewChunkReadyCount: Int { currentPassReadyCount }
    var automationStatusPresentation: DashboardAutomationStatusPresentation? {
        DashboardAutomationStatusPresentation.resolve(
            state: AutomationEngine.shared.state,
            watchedRootDisplayNames: BookmarkFolderService.shared.enabledFolders.map(\.displayName)
        )
    }
    private var dashboardWorkflowCandidateFiles: [FileItem] {
        if isSelectionMode {
            return selectedFiles
        }

        return reviewableFiles.filter { $0.status == .ready }
    }

    private func workflowStepKind(
        for action: WorkflowFileActionRecord,
        using stepRunsByID: [UUID: WorkflowStepRunRecord]
    ) -> WorkflowStepKind? {
        guard let stepRunID = action.stepRunID,
              let stepID = stepRunsByID[stepRunID]?.stepID else {
            return nil
        }

        let parts = stepID.split(separator: "|")
        guard parts.count >= 2 else {
            return nil
        }

        return WorkflowStepKind(rawValue: String(parts[1]))
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
        refreshProjectSpaces()
        resetOrganizationProgress(with: files)
    }

    func _testSimulateBulkOperationCompletion(successCount: Int = 0, failedCount: Int = 0) {
        bulkOperationViewModel.onOperationComplete?(successCount, failedCount)
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

    private func clearProjectSpaceState() {
        projectSpaces = []
        closeProjectSpaceDetail()
    }

    private func clearProjectSpaceWorkflowState() {
        projectSpaceWorkflowPreparationTask?.cancel()
        projectSpaceWorkflowPreparationTask = nil
        projectSpaceWorkflowCandidateFiles = []
        isSynchronizingProjectSpaceWorkflowState = true
        selectedProjectSpaceWorkflowTemplateID = nil
        isSynchronizingProjectSpaceWorkflowState = false
        isPreparingProjectSpaceWorkflowPreview = false
        projectSpaceWorkflowSimulationPreview = nil
        selectedProjectSpaceWorkflowLatestRunSummary = nil
        isProjectSpaceWorkflowInProgress = false
        selectedProjectSpaceAutomationBoard = nil
        selectedProjectSpaceAutomationPolicyDetail = nil
        selectedProjectSpaceAutomationPolicyID = nil
        isProjectSpaceAutomationPolicySheetPresented = false
        isProjectSpaceAutomationComposerPresented = false
        projectSpaceAutomationComposerDraft = nil
    }

    private func clearProjectSpaceAssociationCorrection() {
        projectSpaceAssociationCorrectionFileRow = nil
        projectSpaceAssociationCorrectionProposedLabel = ""
        projectSpaceAssociationSuggestedLabels = []
    }

    private func reconcileProjectSpaceAssociationCorrection(with detail: ProjectSpaceDetail) {
        guard let correctionFileRow = projectSpaceAssociationCorrectionFileRow else { return }

        guard let refreshedFileRow = detail.files.first(where: {
            $0.canonicalIdentity == correctionFileRow.canonicalIdentity
        }) else {
            clearProjectSpaceAssociationCorrection()
            return
        }

        projectSpaceAssociationCorrectionFileRow = refreshedFileRow
    }

    private func loadProjectSpaceWorkflowState(for detail: ProjectSpaceDetail) {
        guard let modelContext else {
            clearProjectSpaceWorkflowState()
            return
        }

        let profileService = ProjectSpaceWorkflowProfileService(modelContext: modelContext)
        let profile = profileService.profile(normalizedProjectLabel: detail.summary.normalizedLabel)
        let memoryResolver = ProjectSpaceMemoryResolver()
        let projectedDetail = ProjectSpaceDetail(
            summary: detail.summary,
            files: detail.files,
            overview: detail.overview,
            preferredDestinations: detail.preferredDestinations,
            recentActivity: detail.recentActivity,
            workflowMemory: memoryResolver.resolveWorkflowMemoryProjection(
                for: detail,
                profile: profile
            )
        )

        isSynchronizingProjectSpaceWorkflowState = true
        selectedProjectSpaceWorkflowTemplateID = featureFlags.isEnabled(.workflowEngineV2)
            ? profile?.preferredWorkflowTemplateID
            : nil
        isSynchronizingProjectSpaceWorkflowState = false
        selectedProjectSpaceWorkflowLatestRunSummary = profile?.lastWorkflowRunID.flatMap { runID in
            projectSpaceWorkflowRunSummary(runID: runID, context: modelContext)
        }
        selectedProjectSpaceDetail = projectedDetail
        loadProjectSpaceAutomationState(for: projectedDetail)

        if featureFlags.isEnabled(.workflowEngineV2) {
            scheduleProjectSpaceWorkflowPreparation()
        } else {
            projectSpaceWorkflowPreparationTask?.cancel()
            projectSpaceWorkflowPreparationTask = nil
            projectSpaceWorkflowCandidateFiles = []
            isPreparingProjectSpaceWorkflowPreview = false
            refreshProjectSpaceWorkflowPreview()
        }
    }

    private func loadProjectSpaceAutomationState(for detail: ProjectSpaceDetail) {
        guard isProjectSpaceAutomationBoardEnabled,
              let modelContext else {
            selectedProjectSpaceAutomationBoard = nil
            dismissProjectSpaceAutomationPolicy()
            dismissProjectSpaceAutomationComposer()
            return
        }

        let automationService = ProjectSpaceAutomationService(modelContext: modelContext)
        let policies = automationService.policies(normalizedProjectLabel: detail.summary.normalizedLabel)
        let groupedPolicies = Dictionary(grouping: policies) { policy in
            automationGroupKind(for: policy.state)
        }

        let groups = ProjectSpaceAutomationBoardGroupKind.allCases.compactMap { kind -> ProjectSpaceAutomationBoardGroup? in
            guard let policies = groupedPolicies[kind], !policies.isEmpty else {
                return nil
            }

            return ProjectSpaceAutomationBoardGroup(
                kind: kind,
                title: automationGroupTitle(for: kind),
                policies: policies.map {
                    makeProjectSpaceAutomationPolicyDetail(
                        $0,
                        projectLabel: detail.projectLabel,
                        workflowMemory: detail.workflowMemory,
                        service: automationService
                    )
                }
            )
        }

        selectedProjectSpaceAutomationBoard = ProjectSpaceAutomationBoard(
            title: "Automation Board",
            subtitle: projectSpaceAutomationBoardSubtitle(for: detail.workflowMemory),
            composerButtonTitle: "New Policy",
            groups: groups
        )
        refreshSelectedProjectSpaceAutomationPolicyDetail()
    }

    private func refreshSelectedProjectSpaceAutomationPolicyDetail() {
        guard isProjectSpaceAutomationBoardEnabled,
              let modelContext,
              let selectedProjectSpaceDetail,
              let policyID = selectedProjectSpaceAutomationPolicyID else {
            selectedProjectSpaceAutomationPolicyDetail = nil
            return
        }

        let automationService = ProjectSpaceAutomationService(modelContext: modelContext)
        guard let policy = automationService.policy(id: policyID) else {
            dismissProjectSpaceAutomationPolicy()
            return
        }

        selectedProjectSpaceAutomationPolicyDetail = makeProjectSpaceAutomationPolicyDetail(
            policy,
            projectLabel: selectedProjectSpaceDetail.projectLabel,
            workflowMemory: selectedProjectSpaceDetail.workflowMemory,
            service: automationService
        )

        if selectedProjectSpace?.normalizedLabel != selectedProjectSpaceDetail.summary.normalizedLabel {
            dismissProjectSpaceAutomationPolicy()
        }
    }

    private func makeProjectSpaceAutomationPolicyDetail(
        _ policy: ProjectSpaceAutomationPolicy,
        projectLabel: String,
        workflowMemory: ProjectSpaceWorkflowMemoryProjection?,
        service: ProjectSpaceAutomationService
    ) -> ProjectSpaceAutomationPolicyDetail {
        let template = WorkflowTemplateCatalog.template(for: policy.workflowTemplateID)
        let latestRun = service.latestRun(policyID: policy.id)
        return ProjectSpaceAutomationPolicyDetail(
            id: policy.id,
            projectLabel: projectLabel,
            workflowTemplateID: policy.workflowTemplateID,
            workflowTemplateDisplayName: template?.displayName ?? policy.workflowTemplateID,
            state: policy.state,
            stateText: automationStateText(for: policy.state),
            triggerSummaryText: automationTriggerSummaryText(for: policy.triggerKinds),
            admissionSummaryText: automationAdmissionSummaryText(for: policy.admissionMode),
            admissionExplanationText: automationAdmissionExplanationText(
                projectLabel: projectLabel,
                workflowTemplateDisplayName: template?.displayName ?? policy.workflowTemplateID,
                admissionMode: policy.admissionMode
            ),
            healthBadgeText: automationHealthBadgeText(policy: policy, latestRun: latestRun),
            healthMessageText: automationHealthMessageText(
                policy: policy,
                latestRun: latestRun,
                workflowMemory: workflowMemory
            ),
            latestRunSummaryText: automationLatestRunSummaryText(latestRun, fallbackTemplateName: template?.displayName ?? "Workflow")
        )
    }

    private func projectSpaceAutomationBoardSubtitle(
        for workflowMemory: ProjectSpaceWorkflowMemoryProjection?
    ) -> String {
        workflowMemory?.summaryText ?? "Manage project-owned policies without leaving this project space."
    }

    private func automationGroupKind(
        for state: ProjectSpaceAutomationPolicyState
    ) -> ProjectSpaceAutomationBoardGroupKind {
        switch state {
        case .recommended:
            return .recommended
        case .draft:
            return .draft
        case .active:
            return .active
        case .paused:
            return .paused
        case .revoked:
            return .revoked
        }
    }

    private func automationGroupTitle(for kind: ProjectSpaceAutomationBoardGroupKind) -> String {
        switch kind {
        case .recommended:
            return "Recommended Policies"
        case .draft:
            return "Draft Policies"
        case .active:
            return "Active Policies"
        case .paused:
            return "Paused Policies"
        case .revoked:
            return "Revoked Policies"
        }
    }

    private func automationStateText(for state: ProjectSpaceAutomationPolicyState) -> String {
        switch state {
        case .recommended:
            return "Recommended"
        case .draft:
            return "Draft"
        case .active:
            return "Active"
        case .paused:
            return "Paused"
        case .revoked:
            return "Revoked"
        }
    }

    private func automationTriggerSummaryText(
        for triggerKinds: [ProjectSpaceAutomationTriggerKind]
    ) -> String {
        let text = ProjectSpaceAutomationPolicy.normalizedTriggerKindRaws(triggerKinds).compactMap { rawValue -> String? in
            switch ProjectSpaceAutomationTriggerKind(rawValue: rawValue) {
            case .manual:
                return "Manual run"
            case .folderWatch:
                return "Realtime ingress"
            case .scheduledSweep:
                return "Scheduled sweep"
            case .none:
                return nil
            }
        }

        return text.joined(separator: ", ")
    }

    private func automationAdmissionSummaryText(
        for admissionMode: ProjectSpaceAutomationAdmissionMode
    ) -> String {
        switch admissionMode {
        case .manualReview:
            return "Manual review"
        case .automatic:
            return "Automatic admission"
        }
    }

    private func automationAdmissionExplanationText(
        projectLabel: String,
        workflowTemplateDisplayName: String,
        admissionMode: ProjectSpaceAutomationAdmissionMode
    ) -> String {
        switch admissionMode {
        case .manualReview:
            return "Runs \(workflowTemplateDisplayName) on files already in \(projectLabel), and only admits unlabeled files after you confirm they belong to this project."
        case .automatic:
            return "Runs \(workflowTemplateDisplayName) on files already in \(projectLabel) and automatically admits unlabeled files when project association is strong enough to write safely first."
        }
    }

    private func automationHealthBadgeText(
        policy: ProjectSpaceAutomationPolicy,
        latestRun: ProjectSpaceAutomationRunRecord?
    ) -> String {
        if policy.state == .recommended {
            return "Recommended"
        }

        if policy.state == .draft {
            return "Draft"
        }

        if policy.state == .revoked {
            return "Revoked"
        }

        if policy.state == .paused {
            return latestRun?.status == .completedWithIssues ? "Needs Attention" : "Paused"
        }

        switch latestRun?.status {
        case .failed:
            return "Needs Attention"
        case .completedWithIssues:
            return "Needs Attention"
        default:
            return "Healthy"
        }
    }

    private func automationHealthMessageText(
        policy: ProjectSpaceAutomationPolicy,
        latestRun: ProjectSpaceAutomationRunRecord?,
        workflowMemory: ProjectSpaceWorkflowMemoryProjection?
    ) -> String {
        if policy.state == .recommended {
            return workflowMemory?.summaryText
                ?? "Bootstrapped from the legacy project workflow selection."
        }

        if policy.state == .draft {
            return "Draft policy. Inspect it before enabling or relying on it."
        }

        if policy.state == .revoked {
            return "Revoked policies stay visible for audit history but no longer run in the background."
        }

        if policy.state == .paused {
            if latestRun?.status == .completedWithIssues {
                return "Last run completed with issues. Review before resuming."
            }

            return "Automatic runs are paused for this policy."
        }

        switch latestRun?.status {
        case .failed:
            return "Last run failed. Review the policy before running it again."
        case .completedWithIssues:
            return "Last run completed with issues. Review before resuming."
        default:
            return "Ready for manual and background runs."
        }
    }

    private func automationLatestRunSummaryText(
        _ latestRun: ProjectSpaceAutomationRunRecord?,
        fallbackTemplateName: String
    ) -> String? {
        guard let latestRun else {
            return nil
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let referenceDate = latestRun.endedAt ?? latestRun.startedAt
        let relative = formatter.localizedString(for: referenceDate, relativeTo: Date())
        let statusText: String
        switch latestRun.status {
        case .queued:
            statusText = "queued"
        case .running:
            statusText = "running"
        case .succeeded:
            statusText = "succeeded"
        case .completedWithIssues:
            statusText = "completed with issues"
        case .failed:
            statusText = "failed"
        case .revoked:
            statusText = "was revoked"
        }

        return "Latest run: \(fallbackTemplateName) \(statusText) \(relative)."
    }

    private func automationRunStatus(
        for primaryStatus: WorkflowRunPrimaryStatus
    ) -> ProjectSpaceAutomationRunStatus {
        switch primaryStatus {
        case .queued:
            return .queued
        case .running:
            return .running
        case .succeeded:
            return .succeeded
        case .completedWithIssues:
            return .completedWithIssues
        case .failed, .canceled:
            return .failed
        }
    }

    private func scheduleProjectSpaceWorkflowPreparation() {
        projectSpaceWorkflowPreparationTask?.cancel()
        projectSpaceWorkflowPreparationTask = nil
        projectSpaceWorkflowCandidateFiles = []
        isPreparingProjectSpaceWorkflowPreview = false
        refreshProjectSpaceWorkflowPreview()

        guard featureFlags.isEnabled(.workflowEngineV2),
              let detail = selectedProjectSpaceDetail,
              let modelContext else {
            return
        }

        isPreparingProjectSpaceWorkflowPreview = true
        projectSpaceWorkflowPreparationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let preparedFiles = await self.prepareProjectSpaceWorkflowCandidateFiles(
                for: detail,
                context: modelContext,
                showsErrors: false
            )

            guard !Task.isCancelled,
                  self.selectedProjectSpaceDetail?.id == detail.id else {
                return
            }

            self.projectSpaceWorkflowCandidateFiles = preparedFiles
            self.isPreparingProjectSpaceWorkflowPreview = false
            self.refreshProjectSpaceWorkflowPreview()
        }
    }

    private func prepareProjectSpaceWorkflowCandidateFiles(
        for detail: ProjectSpaceDetail,
        context: ModelContext,
        showsErrors: Bool
    ) async -> [FileItem] {
        let candidateURLs = detail.files
            .map { URL(fileURLWithPath: $0.normalizedPath).standardizedFileURL }

        guard !candidateURLs.isEmpty else {
            return []
        }

        let explicitSelection: ExplicitSelectionScanResult
        do {
            explicitSelection = try await fileSystemService.scanExplicitSelection(
                urls: candidateURLs,
                options: .defaults
            )
        } catch {
            if showsErrors {
                errorMessage = error.localizedDescription
                showToast(message: error.localizedDescription, canUndo: false)
            }
            return []
        }

        let enabledRules = loadRules(from: context)
        let pipelineResult = await fileScanPipeline.evaluateAndPersistExplicitFiles(
            files: explicitSelection.files,
            scannedRootPaths: explicitSelection.scannedRootPaths,
            reconcileMissingFiles: false,
            ruleEngine: ruleEngine,
            rules: enabledRules,
            context: context
        )

        if showsErrors, let summary = pipelineResult.errorSummary {
            errorMessage = summary
            showToast(message: summary, canUndo: false)
        }

        let fileRowsByPath = Dictionary(
            uniqueKeysWithValues: detail.files.map { ($0.normalizedPath, $0) }
        )
        let skippedFiles = explicitSelection.skippedItems.map { skippedItem in
            makeProjectSpaceSkippedWorkflowCandidate(
                skippedItem,
                fileRow: fileRowsByPath[skippedItem.path]
            )
        }

        return pipelineResult.files + skippedFiles
    }

    private func refreshProjectSpaceWorkflowPreview() {
        guard featureFlags.isEnabled(.workflowEngineV2),
              let detail = selectedProjectSpaceDetail else {
            projectSpaceWorkflowSimulationPreview = nil
            return
        }

        projectSpaceWorkflowSimulationPreview = WorkflowTemplateSimulationPreview.make(
            templateID: selectedProjectSpaceWorkflowTemplateID,
            files: projectSpaceWorkflowCandidateFiles,
            invocationContext: .projectSpace(projectLabel: detail.projectLabel)
        )
    }

    private func persistSelectedProjectSpaceWorkflowTemplate() {
        guard featureFlags.isEnabled(.workflowEngineV2),
              let selectedProjectSpace,
              let modelContext else {
            return
        }

        do {
            try ProjectSpaceWorkflowProfileService(modelContext: modelContext).upsertPreferredTemplate(
                selectedProjectSpaceWorkflowTemplateID,
                for: selectedProjectSpace.normalizedLabel,
                at: Date()
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resolveCurrentProjectSpaceDetail(for context: ModelContext) -> ProjectSpaceDetail? {
        guard let selectedProjectSpace else {
            closeProjectSpaceDetail()
            return nil
        }

        let metadataService = FileMetadataFoundationService(modelContext: context)
        guard let detail = metadataService.fetchProjectSpaceDetail(for: selectedProjectSpace.normalizedLabel) else {
            closeProjectSpaceDetail()
            return nil
        }

        self.selectedProjectSpace = projectSpaces.first(where: { $0.id == detail.summary.id }) ?? detail.summary
        selectedProjectSpaceDetail = detail
        isShowingProjectSpaceDetail = true
        reconcileProjectSpaceAssociationCorrection(with: detail)
        return detail
    }

    private func latestWorkflowRun(
        scopeID: UUID,
        workflowTemplateID: String,
        context: ModelContext
    ) -> WorkflowRunRecord? {
        let store = WorkflowAuditStore(modelContext: context)
        return try? store.latestRunSummary(scopeID: scopeID, workflowTemplateID: workflowTemplateID)
    }

    private func persistProjectSpaceLatestRunBestEffort(
        _ runRecord: WorkflowRunRecord,
        profileService: ProjectSpaceWorkflowProfileService,
        normalizedProjectLabel: String,
        at timestamp: Date
    ) {
        guard runRecord.primaryStatus != .queued,
              runRecord.primaryStatus != .running else {
            return
        }

        do {
            try profileService.recordLatestRun(
                runRecord,
                for: normalizedProjectLabel,
                at: timestamp
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func projectSpaceWorkflowRunSummary(
        runID: UUID,
        context: ModelContext
    ) -> ProjectSpaceWorkflowRunSummary? {
        let store = WorkflowAuditStore(modelContext: context)
        guard let run = try? store.run(id: runID) else {
            return nil
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let completedAt = run.endedAt ?? run.updatedAt

        return ProjectSpaceWorkflowRunSummary(
            templateDisplayName: WorkflowTemplateCatalog.template(for: run.workflowTemplateID)?.displayName ?? "Workflow",
            statusText: ActivityItem.workflowStatusText(
                primaryStatus: run.primaryStatus,
                rollbackStatus: run.rollbackStatus
            ),
            completedText: formatter.localizedString(for: completedAt, relativeTo: Date())
        )
    }

    private func makeProjectSpaceSkippedWorkflowCandidate(
        _ skippedItem: ExternalIngressSkippedItem,
        fileRow: ProjectSpaceFileRow?
    ) -> FileItem {
        let timestamp = fileRow?.lastActivityAt ?? Date()
        return FileItem(
            path: skippedItem.path,
            sizeInBytes: 0,
            creationDate: timestamp,
            modificationDate: timestamp,
            lastAccessedDate: timestamp,
            location: .custom,
            scanRootPath: URL(fileURLWithPath: skippedItem.path).deletingLastPathComponent().path,
            destination: nil,
            status: .pending
        )
    }

    private func currentProjectSpaceFeatureState() -> (
        metadataFoundation: Bool,
        projectSpaces: Bool,
        automationBoard: Bool
    ) {
        (
            featureFlags.isEnabled(.metadataFoundation),
            featureFlags.isEnabled(.projectSpaces),
            featureFlags.isEnabled(.projectSpaceAutomationBoard)
        )
    }

    private func handleProjectSpaceFeatureFlagChange() {
        let currentState = currentProjectSpaceFeatureState()
        guard currentState != lastObservedProjectSpaceFeatureState else { return }

        lastObservedProjectSpaceFeatureState = currentState

        guard currentState.metadataFoundation, currentState.projectSpaces else {
            clearProjectSpaceState()
            return
        }

        refreshProjectSpaces()
    }

    private func handleMetadataMutationCompletion() {
        filterViewModel.applyFilterImmediately()
        refreshProjectSpaces()
        refreshTrustedAutomationScopes()
    }

    private func mutateSelectedTrustedAutomationScope(
        timestamp: Date,
        referenceDate: Date,
        mutation: (TrustedAutomationScopeService, UUID, Date) throws -> Void
    ) {
        guard let modelContext,
              let selectedScopeID = selectedTrustedAutomationScopeDetail?.id else {
            return
        }

        do {
            let scopeService = TrustedAutomationScopeService(modelContext: modelContext)
            try mutation(scopeService, selectedScopeID, timestamp)
            refreshTrustedAutomationScopes(referenceDate: referenceDate)
            presentTrustedAutomationScopeDetail(id: selectedScopeID, referenceDate: referenceDate)
        } catch {
            errorMessage = error.localizedDescription
            showToast(message: error.localizedDescription, canUndo: false)
        }
    }

    private static func makeDefaultPanelTrustedAutomationScopes(
        from sections: [TrustedAutomationScopeSummarySection]
    ) -> [TrustedAutomationScopeSummary] {
        sections
            .filter { $0.status != .revoked }
            .flatMap(\.summaries)
            .sorted(by: isPreferredDefaultPanelSummary)
            .prefix(3)
            .map { $0 }
    }

    private static func isPreferredDefaultPanelSummary(
        _ lhs: TrustedAutomationScopeSummary,
        _ rhs: TrustedAutomationScopeSummary
    ) -> Bool {
        let lhsRank = defaultPanelSummaryRank(lhs)
        let rhsRank = defaultPanelSummaryRank(rhs)
        if lhsRank != rhsRank {
            return lhsRank < rhsRank
        }

        let lhsDate = lhs.lastRun?.endedAt
            ?? lhs.lastRun?.startedAt
            ?? lhs.lifecycle.lastRunAt
            ?? lhs.lifecycle.updatedAt
        let rhsDate = rhs.lastRun?.endedAt
            ?? rhs.lastRun?.startedAt
            ?? rhs.lifecycle.lastRunAt
            ?? rhs.lifecycle.updatedAt
        if lhsDate != rhsDate {
            return lhsDate > rhsDate
        }

        return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
    }

    private static func defaultPanelSummaryRank(_ summary: TrustedAutomationScopeSummary) -> Int {
        if summary.health.state == .needsAttention {
            return 0
        }

        switch summary.lifecycle.status {
        case .active:
            return 1
        case .paused:
            return 2
        case .revoked:
            return 3
        }
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

    private var currentReviewPassState: ReviewPassSnapshotState {
        guard let scopeKey = currentReviewChunkScopeKey else {
            return ReviewPassSnapshotState(snapshotPaths: [], remainingFiles: [], organizedPaths: [])
        }

        let baseVisibleFiles = filterViewModel.visibleFiles
        let deferredPaths = activeDeferredReviewPaths(in: baseVisibleFiles)
        let availableFiles = baseVisibleFiles.filter { !deferredPaths.contains($0.path) }
        let availablePaths = Set(availableFiles.map(\.path))
        let allKnownPaths = Set(scanViewModel.allFiles.map(\.path))

        var snapshotPaths = reviewPassPathsByScope[scopeKey] ?? []
        var organizedPaths = organizedReviewPathsByScope[scopeKey] ?? []
        snapshotPaths = snapshotPaths.filter { allKnownPaths.contains($0) || organizedPaths.contains($0) }
        organizedPaths.subtract(availablePaths)
        organizedPaths.formIntersection(snapshotPaths)

        let hasRemainingSnapshotItems = snapshotPaths.contains(where: availablePaths.contains)
        if snapshotPaths.isEmpty || (!hasRemainingSnapshotItems && !availableFiles.isEmpty) {
            snapshotPaths = Array(availableFiles.prefix(reviewChunkSize).map(\.path))
            reviewPassPathsByScope[scopeKey] = snapshotPaths
            organizedPaths = []
            organizedReviewPathsByScope.removeValue(forKey: scopeKey)
        } else if !hasRemainingSnapshotItems {
            snapshotPaths = []
            reviewPassPathsByScope.removeValue(forKey: scopeKey)
            organizedPaths = []
            organizedReviewPathsByScope.removeValue(forKey: scopeKey)
        } else if reviewPassPathsByScope[scopeKey] != snapshotPaths {
            reviewPassPathsByScope[scopeKey] = snapshotPaths
        }

        if snapshotPaths.isEmpty || organizedPaths.isEmpty {
            organizedReviewPathsByScope.removeValue(forKey: scopeKey)
        } else if organizedReviewPathsByScope[scopeKey] != organizedPaths {
            organizedReviewPathsByScope[scopeKey] = organizedPaths
        }

        let availableFilesByPath = Dictionary(uniqueKeysWithValues: availableFiles.map { ($0.path, $0) })
        let remainingFiles = prioritizedReviewFiles(
            in: snapshotPaths.compactMap { availableFilesByPath[$0] }
        )

        return ReviewPassSnapshotState(
            snapshotPaths: snapshotPaths,
            remainingFiles: remainingFiles,
            organizedPaths: organizedPaths
        )
    }

    private var currentReviewChunkFiles: [FileItem] {
        currentReviewPassState.remainingFiles
    }

    private func markFileOrganizedInCurrentPass(_ filePath: String) {
        guard let scopeKey = currentReviewChunkScopeKey else { return }

        let snapshotPaths = reviewPassPathsByScope[scopeKey] ?? currentReviewPassState.snapshotPaths
        guard snapshotPaths.contains(filePath) else { return }

        var organizedPaths = organizedReviewPathsByScope[scopeKey] ?? []
        let inserted = organizedPaths.insert(filePath).inserted
        guard inserted else { return }

        organizedReviewPathsByScope[scopeKey] = organizedPaths
        objectWillChange.send()
    }

    private func prioritizedReviewFiles(in files: [FileItem]) -> [FileItem] {
        reviewFiles(for: .ready, in: files)
        + reviewFiles(for: .review, in: files)
        + reviewFiles(for: .destination, in: files)
    }

    private func reviewFiles(for kind: ReviewFlowSectionKind, in files: [FileItem]) -> [FileItem] {
        files.filter { file in
            switch kind {
            case .ready:
                return file.status == .ready && file.destination != nil
            case .review:
                return file.status == .pending && file.destination != nil
            case .destination:
                return file.status == .pending && file.destination == nil
            }
        }
    }
}
