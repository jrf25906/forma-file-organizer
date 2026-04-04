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
        let memorySnapshot: OrganizationMemorySnapshot?
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

    /// Metadata for the most recent bulk batch that is still immediately undoable.
    @Published private(set) var latestUndoableBatchSummary: UndoBatchSummary?
    
    /// Bulk operation progress (0.0 to 1.0)
    @Published var bulkOperationProgress: Double = 0.0
    
    /// Whether a bulk operation is currently in progress
    @Published var isBulkOperationInProgress: Bool = false

    #if DEBUG
    /// Test hook that can force an undo metadata transition to fail for a specific snapshot.
    /// Defaults to nil in debug builds.
    var metadataUndoTransitionHook: ((MetadataIdentitySnapshot) throws -> Void)?
    #endif

    // MARK: - Cancellation

    private var cancelBulkOperationRequested = false
    
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
        sourceSurface: PersonalMemorySourceSurface = .reviewFlow,
        onSuccess: @escaping (FileActionData) -> Void,
        onError: @escaping (Error) -> Void
    ) async {
        guard file.destination != nil else { return }
        
        let originalPath = file.path
        
        // Mark as organizing (triggers animation)
        organizingFilePaths.insert(originalPath)
        
        let memorySnapshot = makeMemorySnapshot(for: file)

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
                let destinationPathForMetadata = fileOperationsService.getDestinationPath(for: file)
                    ?? result.destinationPath
                    ?? originalPath

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
                let metadataSnapshot = MetadataIdentitySnapshot(
                    sourcePath: originalPath,
                    destinationPath: destinationPathForMetadata,
                    displayName: file.name,
                    fileExtension: file.fileExtension,
                    destinationDisplayName: file.destination?.displayName
                )
                let command = MoveFileCommand(
                    id: UUID(),
                    timestamp: Date(),
                    fileID: result.originalPath,
                    fromPath: result.originalPath,
                    toPath: result.destinationPath ?? result.originalPath,
                    originalStatus: .pending,
                    originalDestination: file.destination,
                    memorySnapshot: memorySnapshot,
                    metadataSnapshot: metadataSnapshot
                )
                pushUndoCommand(command)

                if let ctx = context {
                    persistMetadataTransition(
                        from: metadataSnapshot.sourcePath,
                        to: metadataSnapshot.destinationPath,
                        displayName: metadataSnapshot.displayName,
                        fileExtension: metadataSnapshot.fileExtension,
                        destinationDisplayName: metadataSnapshot.destinationDisplayName,
                        eventKind: .organized,
                        sourceSurface: historySourceSurface(for: sourceSurface),
                        matchedRuleID: file.matchedRuleID,
                        context: ctx
                    )
                }

                if let ctx = context, let memorySnapshot {
                    recordPersonalMemoryDecision(
                        snapshot: memorySnapshot,
                        sourceSurface: sourceSurface,
                        memoryService: PersonalMemoryService(modelContext: ctx)
                    )
                }

                // Notify success
                if let displayName = file.destination?.displayName {
                    notificationService.notifyFileOrganized(fileName: file.name, destination: displayName)
                }

                // Create legacy FileActionData for callback compatibility
                let fileAction = FileActionData(
                    filePath: result.originalPath,
                    originalPath: result.originalPath,
                    originalStatus: .pending,
                    originalSuggestedDestination: file.originalSuggestedDestination?.displayName,
                    destinationPath: result.destinationPath,
                    memorySnapshot: memorySnapshot
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
        origin: OrganizationRunOrigin = .reviewDriven,
        context: ModelContext?,
        onComplete: @escaping (Int, Int, [FileItem], Error?) -> Void
    ) async {
        guard !files.isEmpty else {
            onComplete(0, 0, [], nil)
            return
        }

        let shouldCancelImmediately = cancelBulkOperationRequested
        cancelBulkOperationRequested = false
        if shouldCancelImmediately {
            onComplete(0, 0, [], FormaError.cancelled)
            return
        }

        isBulkOperationInProgress = true
        bulkOperationProgress = 0.0

        var successCount = 0
        var failedCount = 0
        var failedFiles: [FileItem] = []
        var firstError: Error?
        var wasCancelled = false
        var fileActions: [FileActionData] = []
        var bulkMoveOperations: [BulkMoveOperation] = []
        /// Track rule usage for analytics: [ruleID: count of files matched]
        var ruleUsageCounts: [UUID: Int] = [:]
        let memoryService = context.map { PersonalMemoryService(modelContext: $0) }
        
        for (index, file) in files.enumerated() {
            // Check for task cancellation
            if Task.isCancelled || cancelBulkOperationRequested {
                wasCancelled = true
                break
            }
            
            do {
                let memorySnapshot = makeMemorySnapshot(for: file)
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

                    let destinationPathForMetadata = fileOperationsService.getDestinationPath(for: file)
                        ?? result.destinationPath
                        ?? result.originalPath
                    let metadataSnapshot = MetadataIdentitySnapshot(
                        sourcePath: result.originalPath,
                        destinationPath: destinationPathForMetadata,
                        displayName: file.name,
                        fileExtension: file.fileExtension,
                        destinationDisplayName: file.destination?.displayName
                    )
                    
                    // Record action
                    let fileAction = FileActionData(
                        filePath: result.originalPath,
                        originalPath: result.originalPath,
                        originalStatus: .pending,
                        originalSuggestedDestination: file.originalSuggestedDestination?.displayName,
                        destinationPath: result.destinationPath,
                        memorySnapshot: memorySnapshot
                    )
                    fileActions.append(fileAction)
                    bulkMoveOperations.append(
                        BulkMoveOperation(
                            fileID: result.originalPath,
                            fromPath: result.originalPath,
                            toPath: result.destinationPath ?? result.originalPath,
                            originalStatus: .pending,
                            memorySnapshot: memorySnapshot,
                            metadataSnapshot: metadataSnapshot
                        )
                    )

                    if let ctx = context {
                        persistMetadataTransition(
                            from: metadataSnapshot.sourcePath,
                            to: metadataSnapshot.destinationPath,
                            displayName: metadataSnapshot.displayName,
                            fileExtension: metadataSnapshot.fileExtension,
                            destinationDisplayName: metadataSnapshot.destinationDisplayName,
                            eventKind: .organized,
                            sourceSurface: historySourceSurface(for: origin),
                            matchedRuleID: file.matchedRuleID,
                            context: ctx
                        )
                    }

                    successCount += 1

                    if let memoryService, let memorySnapshot {
                        recordPersonalMemoryDecision(
                            snapshot: memorySnapshot,
                            sourceSurface: .bulkOrganize,
                            memoryService: memoryService
                        )
                    }

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
            let command = BulkMoveCommand(
                id: UUID(),
                timestamp: Date(),
                origin: origin,
                operations: bulkMoveOperations
            )
            pushUndoCommand(command)

            // Log bulk organize activity
            if let ctx = context, successCount > 0 {
                let activityService = ActivityLoggingService(modelContext: ctx)
                if origin == .reviewDriven {
                    activityService.logBulkOrganized(
                        count: successCount,
                        origin: origin,
                        undoAvailable: true
                    )
                }

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
            if origin == .reviewDriven {
                let activityService = ActivityLoggingService(modelContext: ctx)
                activityService.logBulkPartialFailure(
                    successCount: successCount,
                    failedCount: failedCount,
                    firstError: firstError?.localizedDescription
                )
            }
        }

        isBulkOperationInProgress = false
        bulkOperationProgress = 0.0
        cancelBulkOperationRequested = false

        if wasCancelled && firstError == nil {
            firstError = FormaError.cancelled
        }

        onComplete(successCount, failedCount, failedFiles, firstError)
    }

    func requestCancelBulkOperation() {
        cancelBulkOperationRequested = true
        Task { await operationCoordinator.cancelAllOperations() }
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
            refreshLatestUndoableBatchSummary()
            
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
            refreshLatestUndoableBatchSummary()

            #if DEBUG
            Log.info("Undo successful: \\(command.description)", category: .undo)
            #endif

            if let bulkCommand = command as? BulkMoveCommand {
                ActivityLoggingService.create(from: context)?.logBulkUndone(
                    count: bulkCommand.operations.count,
                    origin: bulkCommand.origin
                )
            }
            persistUndoMetadata(for: command, context: context)
            recordUndoMemory(for: command, context: context)
        } catch {
            undoStack.append(command)
            refreshLatestUndoableBatchSummary()
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
            refreshLatestUndoableBatchSummary()
            
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

            persistRedoMetadata(for: command, context: context)

            // Push back to undo stack
            undoStack.append(command)
            if undoStack.count > Self.maxUndoActions {
                undoStack.removeFirst(undoStack.count - Self.maxUndoActions)
            }
            refreshLatestUndoableBatchSummary()

            #if DEBUG
            Log.info("Redo successful: \\(command.description)", category: .undo)
            #endif
        } catch {
            redoStack.append(command)
            refreshLatestUndoableBatchSummary()
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
        refreshLatestUndoableBatchSummary()
    }

    private func refreshLatestUndoableBatchSummary() {
        latestUndoableBatchSummary = (undoStack.last as? BulkMoveCommand)?.undoBatchSummary
    }

    private func historySourceSurface(for sourceSurface: PersonalMemorySourceSurface) -> FileOrganizationHistoryEntry.SourceSurface {
        switch sourceSurface {
        case .undoSurface:
            return .undo
        case .reviewFlow, .inspector, .bulkOrganize, .ruleSuggestion:
            return .organize
        }
    }

    private func historySourceSurface(for origin: OrganizationRunOrigin) -> FileOrganizationHistoryEntry.SourceSurface {
        switch origin {
        case .reviewDriven, .automation:
            return .organize
        }
    }

    private func persistMetadataTransition(
        from sourcePath: String,
        to destinationPath: String,
        displayName: String,
        fileExtension: String,
        destinationDisplayName: String?,
        eventKind: FileOrganizationHistoryEntry.EventKind,
        sourceSurface: FileOrganizationHistoryEntry.SourceSurface,
        matchedRuleID: UUID?,
        context: ModelContext
    ) {
        guard FeatureFlagService.shared.isEnabled(.metadataFoundation) else { return }

        let metadataContext = ModelContext(context.container)
        let metadataService = FileMetadataFoundationService(modelContext: metadataContext)
        do {
            _ = try metadataService.recordTransition(
                from: sourcePath,
                to: destinationPath,
                displayName: displayName,
                fileExtension: fileExtension,
                eventKind: eventKind,
                sourceSurface: sourceSurface,
                destinationDisplayName: destinationDisplayName,
                matchedRuleID: matchedRuleID,
                timestamp: Date()
            )
        } catch {
            Log.error(
                "Failed to persist metadata transition from '\(sourcePath)' to '\(destinationPath)': \(error.localizedDescription)",
                category: .fileOperations
            )
        }
    }

    private func persistUndoMetadata(for command: any UndoableCommand, context: ModelContext) {
        guard FeatureFlagService.shared.isEnabled(.metadataFoundation) else { return }

        switch command {
        case let moveCommand as MoveFileCommand:
            do {
                let snapshot = moveCommand.metadataSnapshot ?? MetadataIdentitySnapshot(
                    sourcePath: moveCommand.fromPath,
                    destinationPath: moveCommand.toPath,
                    displayName: URL(fileURLWithPath: moveCommand.fromPath).lastPathComponent,
                    fileExtension: URL(fileURLWithPath: moveCommand.fromPath).pathExtension,
                    destinationDisplayName: moveCommand.originalDestination?.displayName
                )

                #if DEBUG
                if let metadataUndoTransitionHook {
                    try metadataUndoTransitionHook(snapshot)
                }
                #endif

                persistMetadataTransition(
                    from: snapshot.destinationPath,
                    to: snapshot.sourcePath,
                    displayName: snapshot.displayName,
                    fileExtension: snapshot.fileExtension,
                    destinationDisplayName: snapshot.destinationDisplayName,
                    eventKind: .undone,
                    sourceSurface: .undo,
                    matchedRuleID: nil,
                    context: context
                )
            } catch {
                Log.error(
                    "Failed to persist undo metadata for \(command.description): \(error.localizedDescription)",
                    category: .fileOperations
                )
            }

        case let bulkCommand as BulkMoveCommand:
            for operation in bulkCommand.operations {
                do {
                    let snapshot = operation.metadataSnapshot ?? MetadataIdentitySnapshot(
                        sourcePath: operation.fromPath,
                        destinationPath: operation.toPath,
                        displayName: URL(fileURLWithPath: operation.fromPath).lastPathComponent,
                        fileExtension: URL(fileURLWithPath: operation.fromPath).pathExtension,
                        destinationDisplayName: nil
                    )

                    #if DEBUG
                    if let metadataUndoTransitionHook {
                        try metadataUndoTransitionHook(snapshot)
                    }
                    #endif

                    persistMetadataTransition(
                        from: snapshot.destinationPath,
                        to: snapshot.sourcePath,
                        displayName: snapshot.displayName,
                        fileExtension: snapshot.fileExtension,
                        destinationDisplayName: snapshot.destinationDisplayName,
                        eventKind: .undone,
                        sourceSurface: .undo,
                        matchedRuleID: nil,
                        context: context
                    )
                } catch {
                    Log.error(
                        "Failed to persist undo metadata for \(bulkCommand.description): \(error.localizedDescription)",
                        category: .fileOperations
                    )
                }
            }

        default:
            break
        }
    }

    private func persistRedoMetadata(for command: any UndoableCommand, context: ModelContext) {
        guard FeatureFlagService.shared.isEnabled(.metadataFoundation) else { return }

        switch command {
        case let moveCommand as MoveFileCommand:
            let snapshot = moveCommand.metadataSnapshot ?? MetadataIdentitySnapshot(
                sourcePath: moveCommand.fromPath,
                destinationPath: moveCommand.toPath,
                displayName: URL(fileURLWithPath: moveCommand.fromPath).lastPathComponent,
                fileExtension: URL(fileURLWithPath: moveCommand.fromPath).pathExtension,
                destinationDisplayName: moveCommand.originalDestination?.displayName
            )

            persistMetadataTransition(
                from: snapshot.sourcePath,
                to: snapshot.destinationPath,
                displayName: snapshot.displayName,
                fileExtension: snapshot.fileExtension,
                destinationDisplayName: snapshot.destinationDisplayName,
                eventKind: .organized,
                sourceSurface: .organize,
                matchedRuleID: nil,
                context: context
            )

        case let bulkCommand as BulkMoveCommand:
            for operation in bulkCommand.operations {
                let snapshot = operation.metadataSnapshot ?? MetadataIdentitySnapshot(
                    sourcePath: operation.fromPath,
                    destinationPath: operation.toPath,
                    displayName: URL(fileURLWithPath: operation.fromPath).lastPathComponent,
                    fileExtension: URL(fileURLWithPath: operation.fromPath).pathExtension,
                    destinationDisplayName: nil
                )

                persistMetadataTransition(
                    from: snapshot.sourcePath,
                    to: snapshot.destinationPath,
                    displayName: snapshot.displayName,
                    fileExtension: snapshot.fileExtension,
                    destinationDisplayName: snapshot.destinationDisplayName,
                    eventKind: .organized,
                    sourceSurface: .organize,
                    matchedRuleID: nil,
                    context: context
                )
            }

        default:
            break
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
            originalDestination: placeholderDestination,
            memorySnapshot: action.files.first?.memorySnapshot
        )
        pushUndoCommand(command)
    }
    #endif

    private func makeMemorySnapshot(for file: FileItem) -> OrganizationMemorySnapshot? {
        guard FeatureFlagService.shared.isEnabled(.patternLearning),
              let chosenDestination = file.destination else {
            return nil
        }

        return OrganizationMemorySnapshot(
            fileName: file.name,
            fileExtension: file.fileExtension,
            fileTypeCategory: FileTypeCategory.category(for: file.fileExtension),
            sourceLocation: file.location,
            scanRootPath: file.scanRootPath,
            relativeParentPath: file.relativeParentPath,
            suggestionSource: explicitSuggestionSource(for: file),
            suggestedDestination: file.originalSuggestedDestination,
            chosenDestination: chosenDestination,
            confidenceScore: file.confidenceScore,
            matchedRuleID: file.matchedRuleID
        )
    }

    private func explicitSuggestionSource(for file: FileItem) -> SuggestionSource? {
        if file.matchedRuleID != nil {
            return .rule
        }
        guard let raw = file.suggestionSourceRaw else {
            return nil
        }
        return SuggestionSource(rawValue: raw)
    }

    private func recordPersonalMemoryDecision(
        snapshot: OrganizationMemorySnapshot,
        sourceSurface: PersonalMemorySourceSurface,
        memoryService: PersonalMemoryService
    ) {
        do {
            _ = try memoryService.recordDecision(
                fileName: snapshot.fileName,
                fileExtension: snapshot.fileExtension,
                fileTypeCategory: snapshot.fileTypeCategory,
                sourceLocation: snapshot.sourceLocation,
                scanRootPath: snapshot.scanRootPath,
                relativeParentPath: snapshot.relativeParentPath,
                sourceSurface: sourceSurface,
                suggestionSource: snapshot.suggestionSource,
                suggestedDestination: snapshot.suggestedDestination,
                chosenDestination: snapshot.chosenDestination,
                confidenceScore: snapshot.confidenceScore,
                matchedRuleID: snapshot.matchedRuleID
            )
        } catch {
            Log.error("Failed to record personal memory decision: \(error.localizedDescription)", category: .analytics)
        }
    }

    private func recordUndoMemory(for command: any UndoableCommand, context: ModelContext) {
        guard FeatureFlagService.shared.isEnabled(.patternLearning) else { return }

        let memoryService = PersonalMemoryService(modelContext: context)

        let snapshots: [OrganizationMemorySnapshot]
        switch command {
        case let moveCommand as MoveFileCommand:
            snapshots = moveCommand.memorySnapshot.map { [$0] } ?? []
        case let bulkCommand as BulkMoveCommand:
            snapshots = bulkCommand.operations.compactMap(\.memorySnapshot)
        default:
            snapshots = []
        }

        for snapshot in snapshots {
            do {
                _ = try memoryService.recordDecision(
                    fileName: snapshot.fileName,
                    fileExtension: snapshot.fileExtension,
                    fileTypeCategory: snapshot.fileTypeCategory,
                    sourceLocation: snapshot.sourceLocation,
                    scanRootPath: snapshot.scanRootPath,
                    relativeParentPath: snapshot.relativeParentPath,
                    sourceSurface: .undoSurface,
                    suggestionSource: snapshot.suggestionSource,
                    suggestedDestination: snapshot.suggestedDestination,
                    chosenDestination: nil,
                    confidenceScore: snapshot.confidenceScore,
                    matchedRuleID: snapshot.matchedRuleID,
                    eventKind: .undoRecovery,
                    priorDestination: snapshot.chosenDestination
                )
            } catch {
                Log.error("Failed to record personal memory undo: \(error.localizedDescription)", category: .analytics)
            }
        }
    }
}
