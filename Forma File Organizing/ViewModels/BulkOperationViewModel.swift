import Foundation
import SwiftUI
import SwiftData
import Combine

/// Manages bulk file operations and batch processing.
/// Responsible for:
/// - Batch organization operations
/// - Bulk destination editing
/// - Progress tracking
/// - Failed file retry logic
/// - Cluster organization
@MainActor
class BulkOperationViewModel: ObservableObject {
    enum ExecutionAttemptResult: Equatable {
        case notAttempted
        case executionAttempted
    }

    enum CelebrationDisplayStyle {
        case batchUndo
        case workflowExecution
    }

    private struct WorkflowExecutionPartition {
        let runnablePlan: WorkflowPlan
        let runnableFiles: [FileItem]
        let blockedFiles: [FileItem]
    }

    // MARK: - Published Properties

    /// Bulk operation progress (0.0 to 1.0)
    @Published private(set) var bulkOperationProgress: Double = 0.0

    /// Whether a bulk operation is in progress
    @Published private(set) var isBulkOperationInProgress: Bool = false

    /// Files that failed in the last batch operation
    @Published var lastBatchFailedFiles: [FileItem] = []

    /// Whether to show the failed files sheet
    @Published var showFailedFilesSheet: Bool = false

    /// Whether to show the bulk edit sheet
    @Published var showBulkEditSheet: Bool = false

    // MARK: - Dependencies

    private let organizationCoordinator: FileOrganizationCoordinator
    private let fileOperationsService: FileOperationsService
    private let notificationService: NotificationService
    private let appReviewEligibility: AppReviewEligibilityProviding
    private let workflowExecution: WorkflowExecutionClient

    // MARK: - Callbacks

    /// Callback when bulk operation completes
    var onOperationComplete: ((Int, Int) -> Void)?

    /// Callback when error toast should be shown
    var onShowErrorToast: ((String) -> Void)?

    /// Callback when celebration should be shown
    var onShowCelebration: ((String, CelebrationDisplayStyle) -> Void)?

    /// Callback when completion celebration should be shown
    var onShowCompletionCelebration: ((Int) -> Void)?

    /// Callback when toast should be shown
    var onShowToast: ((String, Bool) -> Void)?

    /// Callback when app review should be requested
    var onShouldRequestReview: (() -> Void)?

    // MARK: - Private State

    private var cancelRequested = false
    private var lastFailedFilesWorkflowTemplateID: String?

    // MARK: - Initialization

    init(
        organizationCoordinator: FileOrganizationCoordinator = FileOrganizationCoordinator(),
        fileOperationsService: FileOperationsService = FileOperationsService(),
        notificationService: NotificationService,
        appReviewEligibility: AppReviewEligibilityProviding = AppReviewEligibilityService(),
        workflowExecution: WorkflowExecutionClient = .live
    ) {
        self.organizationCoordinator = organizationCoordinator
        self.fileOperationsService = fileOperationsService
        self.notificationService = notificationService
        self.appReviewEligibility = appReviewEligibility
        self.workflowExecution = workflowExecution
        setupCoordinatorForwarding()
    }

    convenience init(services: AppServices) {
        self.init(
            notificationService: services.notificationService,
            appReviewEligibility: services.appReviewEligibility
        )
    }

    // MARK: - Bulk Operations

    /// Organize selected files
    func organizeSelectedFiles(
        _ files: [FileItem],
        context: ModelContext?,
        workflowTemplateID: String? = nil
    ) async -> ExecutionAttemptResult {
        guard !files.isEmpty else {
            return .notAttempted
        }

        if FeatureFlagService.shared.isEnabled(.workflowEngineV2) {
            return await organizeMultipleFilesWithWorkflowEngine(
                files,
                context: context,
                totalCount: files.count,
                workflowTemplateID: workflowTemplateID
            )
        }

        let readyFiles = files.filter { $0.destination != nil }
        guard !readyFiles.isEmpty else {
            onShowToast?("No selected files have a destination set.", false)
            return .notAttempted
        }

        #if DEBUG
        Log.debug("ORGANIZE SELECTED FILES — count: \(readyFiles.count)", category: .pipeline)
        let destinations = Set(readyFiles.compactMap { $0.destination?.displayName })
        Log.debug("Unique destinations: \(destinations.sorted().joined(separator: ", "))", category: .pipeline)
        #endif

        return await organizeMultipleFiles(readyFiles, context: context, totalCount: files.count)
    }

    /// Organize all ready files (Review mode)
    func organizeAllReadyFiles(
        _ files: [FileItem],
        context: ModelContext?,
        workflowTemplateID: String? = nil
    ) async -> ExecutionAttemptResult {
        let readyFiles = files.filter { $0.status == .ready }

        guard !readyFiles.isEmpty else {
            onShowToast?("No files are ready to organize. Apply rules first.", false)
            return .notAttempted
        }

        if FeatureFlagService.shared.isEnabled(.workflowEngineV2) {
            return await organizeMultipleFilesWithWorkflowEngine(
                readyFiles,
                context: context,
                totalCount: readyFiles.count,
                workflowTemplateID: workflowTemplateID
            )
        }

        #if DEBUG
        Log.debug("ORGANIZE ALL READY FILES — count: \(readyFiles.count)", category: .pipeline)
        let destinations = Set(readyFiles.compactMap { $0.destination?.displayName })
        Log.debug("Unique destinations: \(destinations.sorted().joined(separator: ", "))", category: .pipeline)
        #endif

        return await organizeMultipleFiles(readyFiles, context: context, totalCount: readyFiles.count)
    }

    /// Skip selected files
    func skipSelectedFiles(_ files: [FileItem]) {
        guard !files.isEmpty else { return }

        for file in files {
            organizationCoordinator.skipFile(file, context: nil)
        }

        onShowToast?("Skipped \(files.count) file\(files.count == 1 ? "" : "s")", true)
    }

    /// Skip all pending files
    func skipAllPendingFiles(_ files: [FileItem]) {
        let pendingFiles = files.filter { $0.status == .pending || $0.status == .ready }
        guard !pendingFiles.isEmpty else { return }

        for file in pendingFiles {
            organizationCoordinator.skipFile(file, context: nil)
        }

        onShowToast?("Skipped \(pendingFiles.count) file\(pendingFiles.count == 1 ? "" : "s")", true)
    }

    /// Bulk edit destination for selected files
    func bulkEditDestination(_ destination: String, createRules: Bool, files: [FileItem], context: ModelContext?) {
        guard !files.isEmpty else { return }

        let trimmed = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Validate destination path
        guard PathValidator.isValid(trimmed) else {
            let validationError = PathValidator.validationError(for: trimmed)
            onShowErrorToast?(validationError?.errorDescription ?? "Invalid destination path")
            return
        }

        // Update destination for all selected files
        let bulkDestination = Destination.folder(bookmark: Data(), displayName: trimmed)
        for file in files {
            file.destination = bulkDestination
        }

        // Create rules if requested
        if createRules, let context = context {
            let extensionGroups = Dictionary(grouping: files, by: { $0.fileExtension })

            for (ext, _) in extensionGroups {
                let rule = Rule(
                    name: "\(ext.uppercased()) files → \(trimmed)",
                    conditionType: .fileExtension,
                    conditionValue: ext,
                    actionType: .move,
                    destination: bulkDestination,
                    isEnabled: true
                )
                context.insert(rule)
            }

            do {
                try context.save()
            } catch {
                Log.error("Failed to save bulk edit rules: \(error.localizedDescription)", category: .pipeline)
                onShowErrorToast?("Failed to create rules. Please try again.")
                return
            }
        }

        showBulkEditSheet = false
        onShowToast?("Updated destination for \(files.count) file\(files.count == 1 ? "" : "s")", false)
    }

    // MARK: - Cluster Organization

    /// Organize a project cluster
    func organizeCluster(_ cluster: ProjectCluster, destinationBase: String, allFiles: [FileItem], context: ModelContext) async {
        #if DEBUG
        Log.info("Organizing cluster: \(cluster.suggestedFolderName) — files: \(cluster.fileCount), destination: \(destinationBase)", category: .analytics)
        #endif

        let clusterFiles = allFiles.filter { cluster.filePaths.contains($0.path) }
        guard !clusterFiles.isEmpty else {
            Log.warning("No files found for cluster: \(cluster.suggestedFolderName)", category: .analytics)
            return
        }

        let clusterDestination = (destinationBase as NSString).appendingPathComponent(cluster.suggestedFolderName)
        let clusterDestinationURL = URL(fileURLWithPath: clusterDestination, isDirectory: true)
        let bulkDestination: Destination
        do {
            try FileManager.default.createDirectory(
                at: clusterDestinationURL,
                withIntermediateDirectories: true
            )
            bulkDestination = try Destination.folder(from: clusterDestinationURL, displayName: clusterDestination)
        } catch {
            Log.error("Failed to create cluster destination bookmark: \(error.localizedDescription)", category: .analytics)
            onShowErrorToast?("Failed to access cluster destination.")
            return
        }
        let projectAssociationWriteContext = ProjectAssociationWriteContext(
            resolvedExplicitDestinationFolderPath: clusterDestinationURL.standardizedFileURL.path,
            explicitSourceMode: true,
            inferredCandidates: []
        )

        for file in clusterFiles {
            file.destination = bulkDestination
        }

        await organizationCoordinator.organizeMultipleFiles(
            clusterFiles,
            projectAssociationWriteContext: projectAssociationWriteContext,
            context: context
        ) { [weak self] successCount, failedCount, failedFiles, error in
            guard let self else { return }

            if successCount > 0 {
                cluster.markAsOrganized()

                do {
                    try context.save()
                } catch {
                    Log.error("Failed to save cluster state: \(error.localizedDescription)", category: .analytics)
                }

                if failedCount == 0 {
                    self.notificationService.showNotification(
                        title: "Cluster Organized",
                        message: "Moved \(successCount) files to \(cluster.suggestedFolderName)"
                    )
                    self.onShowCelebration?("Organized \(successCount) files!", .batchUndo)
                } else {
                    self.notificationService.showNotification(
                        title: "Cluster Partially Organized",
                        message: "Moved \(successCount) files, \(failedCount) failed"
                    )
                    self.lastBatchFailedFiles = failedFiles
                    self.onShowToast?("Organized \(successCount) files, \(failedCount) failed", true)
                }
            } else if let error = error {
                Log.error("Failed to organize cluster '\(cluster.suggestedFolderName)': \(error.localizedDescription)", category: .analytics)
                self.lastBatchFailedFiles = failedFiles
                self.onShowErrorToast?("Failed to organize cluster: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Failed Files

    /// Retry organizing the files that failed in the last batch
    func retryFailedFiles(
        context: ModelContext?,
        workflowTemplateID: String? = nil
    ) async -> ExecutionAttemptResult {
        guard !lastBatchFailedFiles.isEmpty else { return .notAttempted }

        let filesToRetry = lastBatchFailedFiles
        lastBatchFailedFiles = []
        showFailedFilesSheet = false

        if FeatureFlagService.shared.isEnabled(.workflowEngineV2) {
            return await organizeMultipleFilesWithWorkflowEngine(
                filesToRetry,
                context: context,
                totalCount: filesToRetry.count,
                workflowTemplateID: workflowTemplateID ?? lastFailedFilesWorkflowTemplateID
            )
        }

        return await organizeMultipleFiles(filesToRetry, context: context, totalCount: filesToRetry.count)
    }

    /// Cancel the active bulk operation.
    func cancelBulkOperation() {
        cancelRequested = true
        organizationCoordinator.requestCancelBulkOperation()
    }

    /// Dismiss failed files sheet
    func dismissFailedFiles() {
        lastBatchFailedFiles = []
        showFailedFilesSheet = false
    }

    // MARK: - Private Helpers

    /// Organize multiple files and track progress
    private func organizeMultipleFiles(
        _ files: [FileItem],
        projectAssociationWriteContext: ProjectAssociationWriteContext? = nil,
        context: ModelContext?,
        totalCount: Int
    ) async -> ExecutionAttemptResult {
        cancelRequested = false
        await organizationCoordinator.organizeMultipleFiles(
            files,
            projectAssociationWriteContext: projectAssociationWriteContext,
            context: context
        ) { [weak self] successCount, failedCount, failedFiles, firstError in
            guard let self else { return }
            if self.cancelRequested || self.isCancellationError(firstError) {
                self.cancelRequested = false
                self.onOperationComplete?(successCount, failedCount)
                return
            }
            self.showOrganizeFeedback(
                successCount: successCount,
                totalCount: totalCount,
                failedCount: failedCount,
                failedFiles: failedFiles
            )
            self.onOperationComplete?(successCount, failedCount)
        }
        return .executionAttempted
    }

    private func organizeMultipleFilesWithWorkflowEngine(
        _ files: [FileItem],
        context: ModelContext?,
        totalCount: Int,
        workflowTemplateID: String?
    ) async -> ExecutionAttemptResult {
        guard let template = WorkflowTemplateCatalog.template(for: workflowTemplateID) else {
            onShowToast?("Choose a built-in workflow template before organizing with Workflow Engine v2.", false)
            return .notAttempted
        }

        guard let context else {
            onShowToast?("Workflow Engine v2 needs a model context before it can run.", false)
            return .notAttempted
        }

        let plan = workflowExecution.plan(template.id, files)
        let partition = partitionWorkflowPlan(plan, files: files)
        lastFailedFilesWorkflowTemplateID = template.id

        guard !partition.runnableFiles.isEmpty else {
            showOrganizeFeedback(
                successCount: 0,
                totalCount: totalCount,
                failedCount: partition.blockedFiles.count,
                failedFiles: partition.blockedFiles
            )
            return .notAttempted
        }

        isBulkOperationInProgress = true
        bulkOperationProgress = 0.0
        let workflowScopeID = UUID()
        defer {
            isBulkOperationInProgress = false
            bulkOperationProgress = 0.0
        }

        do {
            try await workflowExecution.run(
                partition.runnablePlan,
                partition.runnableFiles,
                workflowScopeID,
                context
            )
            ActivityLoggingService.logWorkflowRunSummaryIfAvailable(
                from: context,
                scopeID: workflowScopeID,
                workflowTemplateID: template.id,
                triggerSurface: .bulkOrganize,
                affectedFileCount: partition.runnableFiles.count
            )
            bulkOperationProgress = 1.0
            for file in partition.runnableFiles {
                file.status = .completed
            }
            showOrganizeFeedback(
                successCount: partition.runnableFiles.count,
                totalCount: totalCount,
                failedCount: partition.blockedFiles.count,
                failedFiles: partition.blockedFiles,
                celebrationStyle: .workflowExecution
            )
            onOperationComplete?(partition.runnableFiles.count, partition.blockedFiles.count)
            return .executionAttempted
        } catch {
            ActivityLoggingService.logWorkflowRunSummaryIfAvailable(
                from: context,
                scopeID: workflowScopeID,
                workflowTemplateID: template.id,
                triggerSurface: .bulkOrganize,
                affectedFileCount: partition.runnableFiles.count
            )
            let failedFiles = partition.blockedFiles + partition.runnableFiles
            lastBatchFailedFiles = failedFiles
            showFailedFilesSheet = !failedFiles.isEmpty
            onShowToast?(error.localizedDescription, false)
            onOperationComplete?(0, totalCount)
            return .executionAttempted
        }
    }

    /// Show appropriate feedback based on operation results
    private func showOrganizeFeedback(
        successCount: Int,
        totalCount: Int,
        failedCount: Int,
        failedFiles: [FileItem],
        celebrationStyle: CelebrationDisplayStyle = .batchUndo
    ) {
        if !failedFiles.isEmpty {
            lastBatchFailedFiles = failedFiles
        } else {
            lastBatchFailedFiles = []
        }

        if successCount > 0 {
            appReviewEligibility.recordSuccessfulOperation(count: successCount)
            if appReviewEligibility.shouldRequestReview() {
                onShouldRequestReview?()
            }
        }

        if successCount == totalCount {
            showFailedFilesSheet = false
            onShowCelebration?(
                "Organized \(successCount) file\(successCount == 1 ? "" : "s")",
                celebrationStyle
            )
        } else if successCount > 0 && failedCount > 0 {
            onShowToast?(
                "Organized \(successCount) of \(totalCount). Open failed files for details.",
                celebrationStyle == .batchUndo
            )
            showFailedFilesSheet = true
        } else if failedCount > 0 {
            onShowToast?("Failed to organize \(failedCount) file\(failedCount == 1 ? "" : "s"). Open failed files to retry.", false)
            showFailedFilesSheet = true
        }
    }

    private func partitionWorkflowPlan(
        _ plan: WorkflowPlan,
        files: [FileItem]
    ) -> WorkflowExecutionPartition {
        let runnablePaths = Set(plan.files.filter { !$0.isBlocked }.map(\.sourcePath))
        let blockedPaths = Set(plan.files.filter(\.isBlocked).map(\.sourcePath))
        let runnableFiles = files.filter { runnablePaths.contains(standardizedPath(for: $0)) }
        let blockedFiles = files.filter { blockedPaths.contains(standardizedPath(for: $0)) }
        let runnablePlan = WorkflowPlan(
            definition: plan.definition,
            files: plan.files.filter { runnablePaths.contains($0.sourcePath) },
            simulation: WorkflowSimulationReport(
                files: plan.simulation.files.filter { runnablePaths.contains($0.sourcePath) }
            )
        )

        return WorkflowExecutionPartition(
            runnablePlan: runnablePlan,
            runnableFiles: runnableFiles,
            blockedFiles: blockedFiles
        )
    }

    private func standardizedPath(for file: FileItem) -> String {
        URL(fileURLWithPath: file.path).standardizedFileURL.path
    }

    /// Setup forwarding from OrganizationCoordinator
    private func setupCoordinatorForwarding() {
        organizationCoordinator.$bulkOperationProgress
            .assign(to: &$bulkOperationProgress)

        organizationCoordinator.$isBulkOperationInProgress
            .assign(to: &$isBulkOperationInProgress)
    }

    private func isCancellationError(_ error: Error?) -> Bool {
        if error is CancellationError {
            return true
        }

        if let formaError = error as? FormaError,
           case .operation(.cancelled) = formaError {
            return true
        }

        return false
    }
}
