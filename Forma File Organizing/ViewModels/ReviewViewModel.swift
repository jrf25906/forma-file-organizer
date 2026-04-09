import Foundation
import SwiftUI
import Combine
import SwiftData

/// ViewModel for ReviewView that manages file scanning, evaluation, and organization
@MainActor
class ReviewViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var files: [FileItem] = []
    @Published var loadingState: LoadingState = .idle
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var selectedWorkflowTemplateID: String?
    
    private var modelContext: ModelContext?

    // MARK: - State

    enum LoadingState {
        case idle
        case loading
        case loaded
        case error
    }

    // MARK: - Services

    private let fileSystemService: FileSystemServiceProtocol
    private let ruleEngine = RuleEngine()
    private let fileOperationsService = FileOperationsService()
    private let notificationService = NotificationService.shared
    private let fileScanPipeline: FileScanPipelineProtocol
    private let organizationCoordinator: FileOrganizationCoordinator
    private let workflowExecution: WorkflowExecutionClient

    // MARK: - Initialization

    init(
        fileSystemService: FileSystemServiceProtocol,
        fileScanPipeline: FileScanPipelineProtocol,
        organizationCoordinator: FileOrganizationCoordinator = FileOrganizationCoordinator(),
        workflowExecution: WorkflowExecutionClient = .live
    ) {
        self.fileSystemService = fileSystemService
        self.fileScanPipeline = fileScanPipeline
        self.organizationCoordinator = organizationCoordinator
        self.workflowExecution = workflowExecution
        // We defer scanning until setModelContext is called
    }

    convenience init() {
        self.init(
            fileSystemService: FileSystemService(),
            fileScanPipeline: FileScanPipeline()
        )
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        guard !isRunningTests else { return }
        Task { await scanDesktop() }
    }

    var selectedWorkflowTemplate: BuiltInWorkflowTemplate? {
        WorkflowTemplateCatalog.template(for: selectedWorkflowTemplateID)
    }

    var workflowSimulationPreview: WorkflowTemplateSimulationPreview? {
        guard FeatureFlagService.shared.isEnabled(.workflowEngineV2) else {
            return nil
        }

        return WorkflowTemplateSimulationPreview.make(
            templateID: selectedWorkflowTemplateID,
            files: files,
            invocationContext: .reviewView
        )
    }

    // MARK: - Public Methods

    /// Scans the Desktop folder and evaluates files
    func scanDesktop() async {
        guard let context = modelContext else { return }
        
        loadingState = .loading
        errorMessage = nil

        do {
            // Load enabled rules
            let descriptor = FetchDescriptor<Rule>(predicate: #Predicate { $0.isEnabled })
            let activeRules = try context.fetch(descriptor)

            // Use shared pipeline for Desktop-only scan
            let scanOptions = ScanOptionsResolver.current()
            let result = await fileScanPipeline.scanAndPersist(
                baseFolders: [.desktop],
                scanOptions: scanOptions,
                fileSystemService: fileSystemService,
                ruleEngine: ruleEngine,
                rules: activeRules,
                context: context
            )

            if let summary = result.errorSummary {
                errorMessage = summary
            }

            // Filter to Desktop files explicitly in case pipeline ever broadens scope
            files = result.files.filter { $0.location == .desktop }
            loadingState = .loaded

        } catch {
            loadingState = .error

            if ErrorHandler.isCancellation(error) {
                errorMessage = "Please grant access to your Desktop folder to continue."
            } else {
                ErrorHandler.handle(error, logCategory: .filesystem) { message in
                    self.errorMessage = message
                }
            }
        }
    }

    /// Moves a single file to its suggested destination
    func moveFile(_ fileItem: FileItem) async {
        guard fileItem.destination != nil else {
            errorMessage = "No destination specified for this file"
            return
        }

        if FeatureFlagService.shared.isEnabled(.workflowEngineV2) {
            await organizeFileWithWorkflowEngine(fileItem)
            return
        }

        do {
            // Perform the move operation
            let result = try await fileOperationsService.moveFile(fileItem)

            if result.success {
                // Update status in SwiftData
                fileItem.status = .completed

                // Remove file from the visible list (or move to completed section)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    files.removeAll { $0.path == fileItem.path }
                }

                // Show success message briefly
                successMessage = "Moved to \(fileItem.destination?.displayName ?? "destination")"
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    successMessage = nil
                }

                // Show system notification
                if let displayName = fileItem.destination?.displayName {
                    notificationService.notifyFileOrganized(
                        fileName: fileItem.name,
                        destination: displayName
                    )
                }
            }

        } catch {
            // Use centralized error handling
            if ErrorHandler.isCancellation(error) {
                errorMessage = "Permission request cancelled. File not moved."
            } else if ErrorHandler.isPermissionError(error) {
                errorMessage = "Permission denied. Forma needs access to the destination folder. If you've already granted access, try resetting permissions below."
            } else {
                ErrorHandler.handle(error, logCategory: .fileOperations) { message in
                    self.errorMessage = message
                }
            }
        }
    }

    /// Moves all files that have suggested destinations
    func moveAllFiles() async {
        let usesWorkflowEngineV2 = FeatureFlagService.shared.isEnabled(.workflowEngineV2)
        let filesToMove = usesWorkflowEngineV2 ? files : files.filter { $0.destination != nil }

        guard !filesToMove.isEmpty else {
            errorMessage = "No files with suggested destinations"
            return
        }

        if usesWorkflowEngineV2 {
            await organizeFilesWithWorkflowEngine(filesToMove)
            return
        }
        
        Log.info("Starting batch move of \(filesToMove.count) files", category: .fileOperations)
        
        // Move files
        let results = await fileOperationsService.moveFiles(filesToMove)

        // Count successes, failures, and cancellations
        let successCount = results.filter { $0.success }.count
        let totalCount = results.count
        let failureCount = totalCount - successCount
        
        Log.info("Batch move complete: \(successCount) succeeded, \(failureCount) failed", category: .fileOperations)

        // Update UI and Database
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            for result in results where result.success {
                if let file = files.first(where: { $0.path == result.originalPath }) {
                    file.status = .completed
                    files.removeAll { $0.path == result.originalPath }
                }
            }
        }

        // Show result message
        if failureCount == 0 {
            successMessage = "Successfully moved \(successCount) file\(successCount == 1 ? "" : "s")"
        } else if successCount > 0 {
            successMessage = "Moved \(successCount) of \(totalCount) files"
            errorMessage = "\(failureCount) file\(failureCount == 1 ? "" : "s") could not be moved (check permissions)"
        } else {
            errorMessage = "No files were moved. Please grant folder permissions when prompted."
        }

        // Show system notification for successful moves
        if successCount > 0 {
            notificationService.notifyBatchOrganized(
                successCount: successCount,
                totalCount: totalCount
            )
        }

        // Clear messages after delay
        Task {
            try? await Task.sleep(for: .seconds(4))
            successMessage = nil
            errorMessage = nil
        }
    }

    /// Skips a file (removes from list without moving) and tracks rejection for learning
    func skipFile(_ fileItem: FileItem) {
        // Track rejection for learning purposes
        if let displayName = fileItem.destination?.displayName {
            fileItem.rejectedDestination = displayName
            fileItem.rejectionCount += 1
            Log.info("Learning: User rejected suggestion '\(displayName)' for \(fileItem.name) (rejection count: \(fileItem.rejectionCount))", category: .analytics)
        }

        let didSkip = organizationCoordinator.skipFile(fileItem, context: modelContext)
        guard didSkip else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            files.removeAll { $0.path == fileItem.path }
        }
    }

    /// Refreshes the file list
    func refresh() async {
        await scanDesktop()
    }

    /// Resets Desktop folder access (for troubleshooting)
    func resetDesktopAccess() {
        fileSystemService.resetDesktopAccess()
    }

    /// Resets all folder permissions (Desktop + Destinations)
    func resetAllPermissions() {
        fileSystemService.resetDesktopAccess()
        fileOperationsService.resetDestinationAccess()
        errorMessage = "All permissions cleared. Please restart the app."
    }

    /// Clears error message
    func clearError() {
        errorMessage = nil
    }

    /// Clears success message
    func clearSuccess() {
        successMessage = nil
    }

    private func organizeFileWithWorkflowEngine(_ fileItem: FileItem) async {
        await organizeFilesWithWorkflowEngine([fileItem])
    }

    private func organizeFilesWithWorkflowEngine(_ filesToMove: [FileItem]) async {
        guard let template = WorkflowTemplateCatalog.template(for: selectedWorkflowTemplateID) else {
            errorMessage = "Choose a built-in workflow template before organizing with Workflow Engine v2."
            return
        }

        guard let modelContext else {
            errorMessage = "Workflow Engine v2 needs a model context before it can run."
            return
        }

        let executionRequest = WorkflowExecutionRequest(
            templateID: template.id,
            invocationContext: .reviewView
        )
        let plan = workflowExecution.plan(executionRequest, filesToMove)
        let runnablePaths = Set(plan.files.filter { !$0.isBlocked }.map(\.sourcePath))
        let blockedPaths = Set(plan.files.filter(\.isBlocked).map(\.sourcePath))
        let runnableFiles = filesToMove.filter { runnablePaths.contains(standardizedPath(for: $0)) }
        let blockedFiles = filesToMove.filter { blockedPaths.contains(standardizedPath(for: $0)) }

        guard !runnableFiles.isEmpty else {
            successMessage = nil
            errorMessage = "No files were organized. \(blockedFiles.count) file\(blockedFiles.count == 1 ? " is" : "s are") blocked in the workflow plan."
            return
        }

        let runnablePlan = WorkflowPlan(
            definition: plan.definition,
            files: plan.files.filter { runnablePaths.contains($0.sourcePath) },
            simulation: WorkflowSimulationReport(
                files: plan.simulation.files.filter { runnablePaths.contains($0.sourcePath) }
            )
        )
        do {
            _ = try await workflowExecution.run(
                executionRequest,
                runnablePlan,
                runnableFiles,
                modelContext
            )
            for file in runnableFiles {
                file.status = .completed
            }

            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                let movedPaths = Set(runnableFiles.map(\.path))
                files.removeAll { movedPaths.contains($0.path) }
            }

            if blockedFiles.isEmpty {
                successMessage = "Organized \(runnableFiles.count) file\(runnableFiles.count == 1 ? "" : "s") with \(template.displayName)"
                errorMessage = nil
            } else {
                successMessage = "Organized \(runnableFiles.count) of \(filesToMove.count) files with \(template.displayName)"
                errorMessage = "\(blockedFiles.count) file\(blockedFiles.count == 1 ? " is" : "s are") blocked in the workflow plan."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func standardizedPath(for file: FileItem) -> String {
        URL(fileURLWithPath: file.path).standardizedFileURL.path
    }
}
