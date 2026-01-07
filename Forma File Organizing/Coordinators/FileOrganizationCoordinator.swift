import Foundation
import SwiftData
import Combine

/// Manages file organization operations including organizing, skipping, bulk operations,
/// and undo/redo functionality.
@MainActor
class FileOrganizationCoordinator: ObservableObject {
    // MARK: - Types
    
    struct FileActionData {
        let filePath: String  // Using path as unique identifier (original path before move)
        let originalPath: String
        let originalStatus: FileItem.OrganizationStatus
        let originalSuggestedDestination: String?
        let destinationPath: String? // Actual path after move (for undo/redo)
    }
    
    enum ActionType {
        case organize(destination: String)
        case skip
        case delete
        case bulkOrganize(destinations: [String: String]) // fileID: destination
    }
    
    struct OrganizationAction {
        let id: UUID
        let type: ActionType
        let files: [FileActionData]
        let timestamp: Date
    }
    
    // MARK: - Published State
    
    /// Files currently being organized (animation in progress).
    @Published private(set) var organizingFilePaths: Set<String> = []
    
    /// Undo stack (using lightweight command pattern)
    @Published private(set) var undoStack: [any UndoableCommand] = []
    
    /// Redo stack (using lightweight command pattern)
    @Published private(set) var redoStack: [any UndoableCommand] = []
    
    /// Bulk operation progress (0.0 to 1.0)
    @Published var bulkOperationProgress: Double = 0.0
    
    /// Whether a bulk operation is currently in progress
    @Published var isBulkOperationInProgress: Bool = false
    
    // MARK: - Services
    
    private let fileOperationsService = FileOperationsService()
    private let notificationService = NotificationService.shared
    private let operationCoordinator = FileOperationCoordinator()
    
    // MARK: - Configuration
    
    private static let maxUndoActions = FormaConfig.Limits.maxUndoActions
    private static let maxRedoActions = FormaConfig.Limits.maxRedoActions
    
    // MARK: - File Organization
    
    /// Check if a file is currently being organized (animation in progress)
    func isOrganizing(_ file: FileItem) -> Bool {
        organizingFilePaths.contains(file.path)
    }
    
    /// Organizes a single file by moving it to its suggested destination.
    ///
    /// - Parameters:
    ///   - file: The file to organize
    ///   - context: Optional SwiftData context for persistence
    ///   - onSuccess: Callback invoked when the operation succeeds with the file action data
    ///   - onError: Callback invoked when the operation fails with the error
    func organizeFile(
        _ file: FileItem,
        context: ModelContext?,
        onSuccess: @escaping (FileActionData) -> Void,
        onError: @escaping (Error) -> Void
    ) async {
        guard file.destination != nil else { return }
        
        let originalPath = file.path
        
        // Mark as organizing (triggers animation)
        organizingFilePaths.insert(originalPath)
        
        do {
            // Use coordinator to prevent race conditions
            try await operationCoordinator.beginOperation(fileID: originalPath)
            defer {
                Task {
                    await operationCoordinator.finishOperation(fileID: originalPath)
                }
            }

            let result = try await fileOperationsService.moveFile(file, modelContext: context)
            
            if result.success {
                // Clear any previous error on success
                file.lastOrganizeError = nil

                // Update file state atomically with transaction-based rollback
                let previousStatus = file.status
                let previousPath = file.path

                if let destPath = result.destinationPath {
                    file.updatePath(destPath)
                    file.status = .completed

                    // Save with automatic rollback on failure
                    if let ctx = context {
                        let transaction = SwiftDataTransaction(context: ctx)
                        transaction.onRollback { [weak self] in
                            file.updatePath(previousPath)
                            file.status = previousStatus
                            self?.organizingFilePaths.remove(originalPath)
                        }
                        try transaction.saveOrRollback()
                    }
                } else {
                    file.status = .completed
                    if let ctx = context {
                        let transaction = SwiftDataTransaction(context: ctx)
                        transaction.onRollback {
                            file.status = previousStatus
                        }
                        try transaction.saveOrRollback()
                    }
                }
                
                // Create lightweight command for undo (~70% memory reduction)
                let command = MoveFileCommand(
                    id: UUID(),
                    timestamp: Date(),
                    fileID: result.originalPath,
                    fromPath: result.originalPath,
                    toPath: result.destinationPath ?? result.originalPath,
                    originalStatus: .pending,
                    originalDestination: file.destination
                )
                pushUndoCommand(command)

                // Notify success
                if let displayName = file.destination?.displayName {
                    notificationService.notifyFileOrganized(fileName: file.name, destination: displayName)
                }

                // Create legacy FileActionData for callback compatibility
                let fileAction = FileActionData(
                    filePath: result.originalPath,
                    originalPath: result.originalPath,
                    originalStatus: .pending,
                    originalSuggestedDestination: file.destination?.displayName,
                    destinationPath: result.destinationPath
                )
                onSuccess(fileAction)
            }
        } catch FileOperationCoordinator.CoordinatorError.alreadyInProgress {
            // Double-click protection - silently ignore
            organizingFilePaths.remove(originalPath)
            #if DEBUG
            Log.debug("Ignored duplicate organize request for: \(originalPath)", category: .undo)
            #endif
        } catch {
            organizingFilePaths.remove(originalPath)

            // Store error on file for user visibility
            file.lastOrganizeError = error.localizedDescription

            // Log failure to activity timeline
            if let ctx = context {
                let activityService = ActivityLoggingService(modelContext: ctx)
                activityService.logOperationFailed(
                    fileName: file.name,
                    operation: "Organize",
                    errorMessage: error.localizedDescription,
                    fileExtension: file.fileExtension
                )
            }

            onError(error)
        }
    }
    
    /// Called when the organize animation completes. Removes the file from organizing set.
    func handleOrganizeAnimationComplete(for filePath: String) {
        organizingFilePaths.remove(filePath)
    }
    
    /// Skips a file (marks it as skipped)
    func skipFile(_ file: FileItem, context: ModelContext?) {
        let originalStatus = file.status
        file.status = .skipped
        
        // Save to context
        if let ctx = context {
            do {
                try ctx.save()
            } catch {
                // Rollback on error
                file.status = originalStatus
                Log.error("Failed to skip file: \(error.localizedDescription)", category: .undo)
            }
        }
        
        // Record lightweight command for undo
        let command = SkipFileCommand(
            id: UUID(),
            timestamp: Date(),
            fileID: file.path,
            previousStatus: originalStatus,
            previousDestination: file.destination
        )
        pushUndoCommand(command)
    }
    
    /// Organizes multiple files in bulk
    ///
    /// - Parameters:
    ///   - files: Files to organize
    ///   - context: Optional SwiftData context
    ///   - onComplete: Callback invoked when all operations complete with success/failure counts
    func organizeMultipleFiles(
        _ files: [FileItem],
        context: ModelContext?,
        onComplete: @escaping (Int, Int, [FileItem], Error?) -> Void
    ) async {
        guard !files.isEmpty else {
            onComplete(0, 0, [], nil)
            return
        }

        isBulkOperationInProgress = true
        bulkOperationProgress = 0.0

        var successCount = 0
        var failedCount = 0
        var failedFiles: [FileItem] = []
        var firstError: Error?
        var fileActions: [FileActionData] = []
        var destinations: [String: String] = [:]
        /// Track rule usage for analytics: [ruleID: count of files matched]
        var ruleUsageCounts: [UUID: Int] = [:]
        
        for (index, file) in files.enumerated() {
            // Check for task cancellation
            if Task.isCancelled {
                break
            }
            
            do {
                let result = try await fileOperationsService.moveFile(file, modelContext: context)
                if result.success {
                    // Clear any previous error on success
                    file.lastOrganizeError = nil

                    // Update file atomically
                    if let destPath = result.destinationPath {
                        file.updatePath(destPath)
                        file.status = .completed
                        
                        // Save immediately
                        if let ctx = context {
                            try ctx.save()
                        }
                    } else {
                        file.status = .completed
                        if let ctx = context {
                            try ctx.save()
                        }
                    }
                    
                    // Record action
                    let fileAction = FileActionData(
                        filePath: result.originalPath,
                        originalPath: result.originalPath,
                        originalStatus: .pending,
                        originalSuggestedDestination: file.destination?.displayName,
                        destinationPath: result.destinationPath
                    )
                    fileActions.append(fileAction)
                    if let dest = result.destinationPath {
                        destinations[file.path] = dest
                    }

                    successCount += 1

                    // Track rule usage for analytics (v1.2.0)
                    if let ruleID = file.matchedRuleID {
                        ruleUsageCounts[ruleID, default: 0] += 1
                    }

                    // Notify
                    if let displayName = file.destination?.displayName {
                        notificationService.notifyFileOrganized(fileName: file.name, destination: displayName)
                    }
                }
            } catch {
                failedCount += 1
                failedFiles.append(file)
                if firstError == nil {
                    firstError = error
                }

                // Store error on file for user visibility
                file.lastOrganizeError = error.localizedDescription

                Log.error("FileOrganizationCoordinator: Failed to organize '\(file.name)' - \(error.localizedDescription)", category: .fileOperations)

                // Log individual failure to activity timeline
                if let ctx = context {
                    let activityService = ActivityLoggingService(modelContext: ctx)
                    activityService.logOperationFailed(
                        fileName: file.name,
                        operation: "Organize",
                        errorMessage: error.localizedDescription,
                        fileExtension: file.fileExtension
                    )
                }
            }
            
            // Update progress
            bulkOperationProgress = Double(index + 1) / Double(files.count)
        }
        
        // Record lightweight bulk command for undo
        if !fileActions.isEmpty {
            let operations = fileActions.map { action in
                (fileID: action.filePath,
                 fromPath: action.originalPath,
                 toPath: action.destinationPath ?? action.originalPath,
                 originalStatus: action.originalStatus)
            }
            let command = BulkMoveCommand(
                id: UUID(),
                timestamp: Date(),
                operations: operations
            )
            pushUndoCommand(command)

            // Log bulk organize activity
            if let ctx = context, successCount > 0 {
                let activityService = ActivityLoggingService(modelContext: ctx)
                activityService.logBulkOrganized(count: successCount)

                // Log rule applications for analytics (v1.2.0)
                if !ruleUsageCounts.isEmpty {
                    logRuleApplications(
                        ruleUsageCounts: ruleUsageCounts,
                        activityService: activityService,
                        modelContext: ctx
                    )
                }
            }
        }

        // Log bulk partial failure summary if any files failed
        if failedCount > 0, let ctx = context {
            let activityService = ActivityLoggingService(modelContext: ctx)
            activityService.logBulkPartialFailure(
                successCount: successCount,
                failedCount: failedCount,
                firstError: firstError?.localizedDescription
            )
        }

        isBulkOperationInProgress = false
        bulkOperationProgress = 0.0

        onComplete(successCount, failedCount, failedFiles, firstError)
    }
    
    // MARK: - Undo/Redo
    
    func canUndo() -> Bool {
        !undoStack.isEmpty
    }
    
    func canRedo() -> Bool {
        !redoStack.isEmpty
    }
    
    func undoLastAction(allFiles: [FileItem], context: ModelContext?, onComplete: @escaping () -> Void) {
        guard let command = undoStack.popLast() else { return }
        
        // Fast-path for skip commands when we only have in-memory FileItem instances
        // Note: Skip only changes status, not destination - destination remains on file
        if let skipCommand = command as? SkipFileCommand {
            if let file = allFiles.first(where: { $0.path == skipCommand.fileID }) {
                file.status = skipCommand.previousStatus
                // Destination is not modified by skip, so no need to restore it
            }
            
            // Push to redo stack
            redoStack.append(skipCommand)
            if redoStack.count > Self.maxRedoActions {
                redoStack.removeFirst(redoStack.count - Self.maxRedoActions)
            }
            
            #if DEBUG
            Log.info("Undo (in-memory skip) successful: \\(skipCommand.description)", category: .undo)
            #endif
            onComplete()
            return
        }
        
        guard let context else {
            undoStack.append(command)
            #if DEBUG
            Log.error("Undo failed: missing ModelContext for \\(command.description)", category: .undo)
            #endif
            onComplete()
            return
        }

        // Fallback: execute undo via command pattern (requires a ModelContext)
        do {
            try command.undo(context: context)

            // Push to redo stack
            redoStack.append(command)
            if redoStack.count > Self.maxRedoActions {
                redoStack.removeFirst(redoStack.count - Self.maxRedoActions)
            }

            #if DEBUG
            Log.info("Undo successful: \\(command.description)", category: .undo)
            #endif
        } catch {
            undoStack.append(command)
            #if DEBUG
            Log.error("Undo failed: \\(error.localizedDescription)", category: .undo)
            #endif
        }
        
        onComplete()
    }
    
    func redoLastAction(allFiles: [FileItem], context: ModelContext?, onComplete: @escaping () -> Void) async {
        guard let command = redoStack.popLast() else { return }
        
        // Fast-path for skip commands when running without a ModelContext (unit tests,
        // in-memory usage). In this mode we simply flip the FileItem state back to
        // .skipped and update the undo stack accordingly.
        if context == nil, let skipCommand = command as? SkipFileCommand {
            if let file = allFiles.first(where: { $0.path == skipCommand.fileID }) {
                file.status = .skipped
            }
            
            // Push back to undo stack
            undoStack.append(skipCommand)
            if undoStack.count > Self.maxUndoActions {
                undoStack.removeFirst(undoStack.count - Self.maxUndoActions)
            }
            
            #if DEBUG
            Log.info("Redo (in-memory skip) successful: \\(skipCommand.description)", category: .undo)
            #endif
            onComplete()
            return
        }
        
        guard let context else {
            redoStack.append(command)
            #if DEBUG
            Log.error("Redo failed: missing ModelContext for \\(command.description)", category: .undo)
            #endif
            onComplete()
            return
        }

        // Fallback: execute redo via command pattern (requires a ModelContext)
        do {
            try await command.execute(context: context)

            // Push back to undo stack
            undoStack.append(command)
            if undoStack.count > Self.maxUndoActions {
                undoStack.removeFirst(undoStack.count - Self.maxUndoActions)
            }

            #if DEBUG
            Log.info("Redo successful: \\(command.description)", category: .undo)
            #endif
        } catch {
            redoStack.append(command)
            #if DEBUG
            Log.error("Redo failed: \\(error.localizedDescription)", category: .undo)
            #endif
        }
        
        onComplete()
    }
    
    // MARK: - Private Helpers
    
    private func pushUndoCommand(_ command: any UndoableCommand) {
        undoStack.append(command)
        if undoStack.count > Self.maxUndoActions {
            undoStack.removeFirst(undoStack.count - Self.maxUndoActions)
        }
        // Clear redo stack when new action is performed
        redoStack.removeAll(keepingCapacity: false)
    }
    
    private func reverseOrganize(_ files: [FileActionData], from destination: String, allFiles: [FileItem]) {
        for fileAction in files {
            // Find the file by its current path (destination) or original path
            let file = allFiles.first(where: { file in
                file.path == fileAction.destinationPath || file.path == fileAction.originalPath
            })
            
            guard let file = file else { continue }
            
            // Move file back to original location if it was moved
            if let destinationPath = fileAction.destinationPath,
               FileManager.default.fileExists(atPath: destinationPath) {
                do {
                    try fileOperationsService.secureMoveOnDisk(from: destinationPath, to: fileAction.originalPath)
                    file.updatePath(fileAction.originalPath)
                } catch {
                    Log.error("Failed to undo file move securely: \(error.localizedDescription)", category: .undo)
                }
            }
            
            // Restore original status (destination is restored via file move)
            file.status = fileAction.originalStatus
            // Note: Destination restoration would require bookmark data;
            // for now the file move itself restores access
        }
    }
    
    private func reverseSkip(_ files: [FileActionData], allFiles: [FileItem]) {
        for fileAction in files {
            if let file = allFiles.first(where: { $0.path == fileAction.filePath }) {
                file.status = fileAction.originalStatus
            }
        }
    }

    /// Log rule applications for analytics (v1.2.0).
    /// Queries the Rule model by ID to get rule names, then logs each rule's usage.
    private func logRuleApplications(
        ruleUsageCounts: [UUID: Int],
        activityService: ActivityLoggingService,
        modelContext: ModelContext
    ) {
        for (ruleID, matchCount) in ruleUsageCounts {
            // Fetch rule name from model context
            let descriptor = FetchDescriptor<Rule>(
                predicate: #Predicate { $0.id == ruleID }
            )

            do {
                if let rule = try modelContext.fetch(descriptor).first {
                    activityService.logRuleApplied(
                        ruleName: rule.name,
                        ruleID: ruleID,
                        matchCount: matchCount
                    )
                } else {
                    // Rule may have been deleted; log with placeholder name
                    activityService.logRuleApplied(
                        ruleName: "Unknown Rule",
                        ruleID: ruleID,
                        matchCount: matchCount
                    )
                }
            } catch {
                Log.error("Failed to fetch rule for analytics: \(error.localizedDescription)", category: .analytics)
            }
        }
    }
    
    #if DEBUG
    /// Test-only helper to push an undo action without performing any file operations.
    func _testPushUndoAction(_ action: OrganizationAction) {
        // Legacy support - convert OrganizationAction to command
        // Create a placeholder Destination from the display name string for test compatibility
        let placeholderDestination: Destination? = action.files.first?.originalSuggestedDestination.map {
            .folder(bookmark: Data(), displayName: $0)
        }
        let command = MoveFileCommand(
            id: action.id,
            timestamp: action.timestamp,
            fileID: action.files.first?.filePath ?? "",
            fromPath: action.files.first?.originalPath ?? "",
            toPath: action.files.first?.destinationPath ?? "",
            originalStatus: action.files.first?.originalStatus ?? .pending,
            originalDestination: placeholderDestination
        )
        pushUndoCommand(command)
    }
    #endif
}
