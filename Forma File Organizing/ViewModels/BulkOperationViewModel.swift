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

    // MARK: - Callbacks

    /// Callback when bulk operation completes
    var onOperationComplete: ((Int, Int) -> Void)?

    /// Callback when error toast should be shown
    var onShowErrorToast: ((String) -> Void)?

    /// Callback when celebration should be shown
    var onShowCelebration: ((String) -> Void)?

    /// Callback when completion celebration should be shown
    var onShowCompletionCelebration: ((Int) -> Void)?

    /// Callback when toast should be shown
    var onShowToast: ((String, Bool) -> Void)?

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        organizationCoordinator: FileOrganizationCoordinator = FileOrganizationCoordinator(),
        fileOperationsService: FileOperationsService = FileOperationsService(),
        notificationService: NotificationService
    ) {
        self.organizationCoordinator = organizationCoordinator
        self.fileOperationsService = fileOperationsService
        self.notificationService = notificationService
        setupCoordinatorForwarding()
    }

    convenience init(services: AppServices) {
        self.init(
            notificationService: services.notificationService
        )
    }

    // MARK: - Bulk Operations

    /// Organize selected files
    func organizeSelectedFiles(_ files: [FileItem], context: ModelContext?) async {
        let readyFiles = files.filter { $0.destination != nil }
        guard !readyFiles.isEmpty else {
            onShowToast?("No selected files have a destination set.", false)
            return
        }

        #if DEBUG
        Log.debug("ORGANIZE SELECTED FILES — count: \(readyFiles.count)", category: .pipeline)
        let destinations = Set(readyFiles.compactMap { $0.destination?.displayName })
        Log.debug("Unique destinations: \(destinations.sorted().joined(separator: ", "))", category: .pipeline)
        #endif

        await organizeMultipleFiles(readyFiles, context: context, totalCount: files.count)
    }

    /// Organize all ready files (Review mode)
    func organizeAllReadyFiles(_ files: [FileItem], context: ModelContext?) async {
        let readyFiles = files.filter { $0.status == .ready }

        guard !readyFiles.isEmpty else {
            onShowToast?("No files are ready to organize. Apply rules first.", false)
            return
        }

        #if DEBUG
        Log.debug("ORGANIZE ALL READY FILES — count: \(readyFiles.count)", category: .pipeline)
        let destinations = Set(readyFiles.compactMap { $0.destination?.displayName })
        Log.debug("Unique destinations: \(destinations.sorted().joined(separator: ", "))", category: .pipeline)
        #endif

        await organizeMultipleFiles(readyFiles, context: context, totalCount: readyFiles.count)
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
        let bulkDestination = Destination.folder(bookmark: Data(), displayName: clusterDestination)

        for file in clusterFiles {
            file.destination = bulkDestination
        }

        await organizationCoordinator.organizeMultipleFiles(
            clusterFiles,
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
                    self.onShowCelebration?("Organized \(successCount) files!")
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
    func retryFailedFiles(context: ModelContext?) async {
        guard !lastBatchFailedFiles.isEmpty else { return }

        let filesToRetry = lastBatchFailedFiles
        lastBatchFailedFiles = []
        showFailedFilesSheet = false

        await organizeMultipleFiles(filesToRetry, context: context, totalCount: filesToRetry.count)
    }

    /// Dismiss failed files sheet
    func dismissFailedFiles() {
        lastBatchFailedFiles = []
        showFailedFilesSheet = false
    }

    // MARK: - Private Helpers

    /// Organize multiple files and track progress
    private func organizeMultipleFiles(_ files: [FileItem], context: ModelContext?, totalCount: Int) async {
        await organizationCoordinator.organizeMultipleFiles(
            files,
            context: context
        ) { [weak self] successCount, failedCount, failedFiles, firstError in
            guard let self else { return }
            self.showOrganizeFeedback(
                successCount: successCount,
                totalCount: totalCount,
                failedCount: failedCount,
                failedFiles: failedFiles
            )
            self.onOperationComplete?(successCount, failedCount)
        }
    }

    /// Show appropriate feedback based on operation results
    private func showOrganizeFeedback(successCount: Int, totalCount: Int, failedCount: Int, failedFiles: [FileItem]) {
        if !failedFiles.isEmpty {
            lastBatchFailedFiles = failedFiles
        }

        if successCount == totalCount {
            lastBatchFailedFiles = []
            onShowCelebration?("Organized \(successCount) file\(successCount == 1 ? "" : "s")")
        } else if successCount > 0 && failedCount > 0 {
            onShowToast?("Organized \(successCount) of \(totalCount). Tap to see \(failedCount) failed.", true)
            showFailedFilesSheet = true
        } else if failedCount > 0 {
            onShowToast?("Failed to organize \(failedCount) file\(failedCount == 1 ? "" : "s"). Tap to retry.", false)
            showFailedFilesSheet = true
        }
    }

    /// Setup forwarding from OrganizationCoordinator
    private func setupCoordinatorForwarding() {
        organizationCoordinator.$bulkOperationProgress
            .assign(to: &$bulkOperationProgress)

        organizationCoordinator.$isBulkOperationInProgress
            .assign(to: &$isBulkOperationInProgress)
    }
}
