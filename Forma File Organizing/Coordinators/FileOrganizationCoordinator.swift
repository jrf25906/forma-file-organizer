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

    struct WorkflowMoveResult {
        let originalPath: String
        let destinationPath: String
        let destinationDisplayName: String?
        let projectAssociationWriteContext: ProjectAssociationWriteContext
    }

    struct WorkflowMoveError: Error {
        let result: WorkflowMoveResult
        let underlyingError: Error
    }

    private struct DiskCompensationMove {
        let sourcePath: String
        let destinationPath: String
    }

    private struct PendingActivityFailure {
        let fileName: String
        let fileExtension: String
        let errorMessage: String
    }

    private struct PendingNotification {
        let fileName: String
        let destination: String
    }

    private struct FileItemRestoreSnapshot {
        let file: FileItem
        let path: String
        let status: FileItem.OrganizationStatus
        let destination: Destination?
        let lastOrganizeError: String?
    }

    private struct FileMetadataRecordRestoreSnapshot {
        let record: FileMetadataRecord
        let canonicalIdentity: String
        let identityKind: FileMetadataRecord.IdentityKind
        let lastKnownPath: String
        let displayName: String
        let fileExtension: String
        let firstSeenAt: Date
        let lastSeenAt: Date
        let lastOrganizedAt: Date?
        let organizationCount: Int
        let latestOrganizationStatus: FileMetadataRecord.OrganizationStatus
        let workflowStatus: MetadataWorkflowStatus?
        let tags: [String]
        let projectAssociation: String?
        let notesSummary: String?
    }

    private struct HistoryEntryRestoreSnapshot {
        let entry: FileOrganizationHistoryEntry
        let metadataRecordID: PersistentIdentifier
    }

    private struct PersonalMemoryPreferenceRestoreSnapshot {
        let preference: PersonalMemoryPreference
        let key: String
        let fileExtension: String
        let fileTypeCategory: FileTypeCategory
        let sourceLocation: FileLocationKind
        let relativeParentPath: String?
        let destinationIdentity: String
        let preferredDestination: Destination?
        let acceptCount: Int
        let overrideCount: Int
        let correctionCount: Int
        let undoCount: Int
        let deferCount: Int
        let lastObservedAt: Date
    }

    private struct BatchPersistenceRestoreSnapshot {
        let fileItems: [FileItemRestoreSnapshot]
        let metadataRecords: [PersistentIdentifier: FileMetadataRecordRestoreSnapshot]
        let historyEntries: [PersistentIdentifier: HistoryEntryRestoreSnapshot]
        let activityItemIDs: Set<PersistentIdentifier>
        let personalMemoryPreferenceSnapshots: [PersistentIdentifier: PersonalMemoryPreferenceRestoreSnapshot]
        let personalMemoryEventIDs: Set<PersistentIdentifier>
    }

    enum BatchPersistenceStage: Equatable {
        case bulkOrganize
        case bulkUndo
        case bulkRedo
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

    /// Test hook that can force the first skip save attempt to fail after durable metadata mutation.
    /// Defaults to nil in debug builds.
    var metadataSkipSaveHook: (() throws -> Void)?

    /// Test hook that fires immediately before the single batched save for bulk organize/undo/redo.
    /// Defaults to nil in debug builds.
    var batchPersistenceSaveHook: ((BatchPersistenceStage) throws -> Void)?
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
                    destinationDisplayName: file.destination?.displayName,
                    projectAssociationWriteContext: projectAssociationWriteContext(
                        destinationPath: destinationPathForMetadata
                    )
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
                        projectAssociationWriteContext: metadataSnapshot.projectAssociationWriteContext,
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

    @discardableResult
    func executeWorkflowMove(
        _ file: FileItem,
        context: ModelContext?
    ) async throws -> WorkflowMoveResult {
        guard file.destination != nil else {
            throw FormaError.operation(.notReady("No destination specified"))
        }

        let originalPath = file.path
        let previousStatus = file.status

        try await operationCoordinator.beginOperation(fileID: originalPath)
        defer {
            Task {
                await operationCoordinator.finishOperation(fileID: originalPath)
            }
        }

        let moveResult = try await fileOperationsService.moveFile(file, modelContext: context)
        guard moveResult.success else {
            throw moveResult.error ?? FormaError.operationFailed("Workflow move failed")
        }

        let resolvedDestinationPath = moveResult.destinationPath
            ?? fileOperationsService.getDestinationPath(for: file)
            ?? originalPath

        _ = file.updatePath(resolvedDestinationPath)
        file.status = .completed

        let workflowMoveResult = WorkflowMoveResult(
            originalPath: originalPath,
            destinationPath: resolvedDestinationPath,
            destinationDisplayName: file.destination?.displayName,
            projectAssociationWriteContext: projectAssociationWriteContext(
                destinationPath: resolvedDestinationPath
            )
        )

        guard let context else {
            return workflowMoveResult
        }

        let transaction = SwiftDataTransaction(context: context)
        transaction.onRollback {
            _ = file.updatePath(originalPath)
            file.status = previousStatus
        }

        do {
            try transaction.saveOrRollback()
            return workflowMoveResult
        } catch {
            throw WorkflowMoveError(result: workflowMoveResult, underlyingError: error)
        }
    }
    
    /// Called when the organize animation completes. Removes the file from organizing set.
    func handleOrganizeAnimationComplete(for filePath: String) {
        organizingFilePaths.remove(filePath)
    }
    
    /// Skips a file (marks it as skipped)
    @discardableResult
    func skipFile(_ file: FileItem, context: ModelContext?) -> Bool {
        let originalStatus = file.status
        file.status = .skipped

        var durableWorkflowStatusSnapshot: SkipFileCommand.DurableWorkflowStatusSnapshot?

        if let context,
           FeatureFlagService.shared.isEnabled(.metadataFoundation),
           FeatureFlagService.shared.isEnabled(.durableWorkflowStatus) {
            do {
                durableWorkflowStatusSnapshot = try persistSkipMetadata(
                    for: file,
                    context: context
                )

                #if DEBUG
                if let metadataSkipSaveHook {
                    try metadataSkipSaveHook()
                }
                #endif

                try context.save()
            } catch {
                Log.error(
                    "Failed to persist durable skip metadata for '\(file.path)': \(error.localizedDescription)",
                    category: .undo
                )

                context.rollback()
                file.status = .skipped
                durableWorkflowStatusSnapshot = nil

                do {
                    try context.save()
                } catch {
                    Log.error("Failed to save transient skip for '\(file.path)': \(error.localizedDescription)", category: .undo)
                    context.rollback()
                    file.status = originalStatus
                    return false
                }
            }
        } else if let ctx = context {
            do {
                try ctx.save()
            } catch {
                ctx.rollback()
                file.status = originalStatus
                Log.error("Failed to skip file: \(error.localizedDescription)", category: .undo)
                return false
            }
        }

        // Record lightweight command for undo
        let command = SkipFileCommand(
            id: UUID(),
            timestamp: Date(),
            fileID: file.path,
            previousStatus: originalStatus,
            previousDestination: file.destination,
            durableWorkflowStatusSnapshot: durableWorkflowStatusSnapshot
        )
        pushUndoCommand(command)
        return true
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
        projectAssociationWriteContext explicitProjectAssociationWriteContext: ProjectAssociationWriteContext? = nil,
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
        var compensationMoves: [DiskCompensationMove] = []
        var pendingFailureLogs: [PendingActivityFailure] = []
        var pendingNotifications: [PendingNotification] = []
        /// Track rule usage for analytics: [ruleID: count of files matched]
        var ruleUsageCounts: [UUID: Int] = [:]
        let batchTimestamp = Date()
        let memoryService = context.map { PersonalMemoryService(modelContext: $0) }
        let activityService = context.map { ActivityLoggingService(modelContext: $0) }
        let batchSnapshot = context.map { captureBatchPersistenceSnapshot(context: $0, files: files) }
        var recordedPersonalMemory = false
        
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

                    if let destPath = result.destinationPath {
                        _ = file.updatePath(destPath)
                        compensationMoves.append(
                            DiskCompensationMove(
                                sourcePath: destPath,
                                destinationPath: result.originalPath
                            )
                        )
                    } else {
                        _ = file.updatePath(result.originalPath)
                    }
                    file.status = .completed

                    let destinationPathForMetadata = fileOperationsService.getDestinationPath(for: file)
                        ?? result.destinationPath
                        ?? result.originalPath
                    let metadataSnapshot = MetadataIdentitySnapshot(
                        sourcePath: result.originalPath,
                        destinationPath: destinationPathForMetadata,
                        displayName: file.name,
                        fileExtension: file.fileExtension,
                        destinationDisplayName: file.destination?.displayName,
                        projectAssociationWriteContext: explicitProjectAssociationWriteContext ?? projectAssociationWriteContext(
                            destinationPath: destinationPathForMetadata
                        )
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
                        try stageMetadataTransitionWithoutSaving(
                            from: metadataSnapshot.sourcePath,
                            to: metadataSnapshot.destinationPath,
                            displayName: metadataSnapshot.displayName,
                            fileExtension: metadataSnapshot.fileExtension,
                            destinationDisplayName: metadataSnapshot.destinationDisplayName,
                            projectAssociationWriteContext: metadataSnapshot.projectAssociationWriteContext,
                            eventKind: .organized,
                            sourceSurface: historySourceSurface(for: origin),
                            matchedRuleID: file.matchedRuleID,
                            context: ctx,
                            timestamp: batchTimestamp
                        )
                    }

                    successCount += 1

                    if let memoryService, let memorySnapshot {
                        try recordPersonalMemoryDecisionWithoutSaving(
                            snapshot: memorySnapshot,
                            sourceSurface: .bulkOrganize,
                            memoryService: memoryService,
                            timestamp: batchTimestamp
                        )
                        recordedPersonalMemory = true
                    }

                    // Track rule usage for analytics (v1.2.0)
                    if let ruleID = file.matchedRuleID {
                        ruleUsageCounts[ruleID, default: 0] += 1
                    }

                    // Notify
                    if let displayName = file.destination?.displayName {
                        pendingNotifications.append(
                            PendingNotification(
                                fileName: file.name,
                                destination: displayName
                            )
                        )
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
                pendingFailureLogs.append(
                    PendingActivityFailure(
                        fileName: file.name,
                        fileExtension: file.fileExtension,
                        errorMessage: error.localizedDescription
                    )
                )
            }
            
            // Update progress
            bulkOperationProgress = Double(index + 1) / Double(files.count)
        }

        if let context, let activityService {
            for failure in pendingFailureLogs {
                activityService.logOperationFailedWithoutSaving(
                    fileName: failure.fileName,
                    operation: "Organize",
                    errorMessage: failure.errorMessage,
                    fileExtension: failure.fileExtension
                )
            }

            if successCount > 0, origin == .reviewDriven {
                activityService.logBulkOrganizedWithoutSaving(
                    count: successCount,
                    origin: origin,
                    undoAvailable: true
                )
            }

            if !ruleUsageCounts.isEmpty {
                logRuleApplicationsWithoutSaving(
                    ruleUsageCounts: ruleUsageCounts,
                    activityService: activityService,
                    modelContext: context
                )
            }

            if failedCount > 0, origin == .reviewDriven {
                activityService.logBulkPartialFailureWithoutSaving(
                    successCount: successCount,
                    failedCount: failedCount,
                    firstError: firstError?.localizedDescription
                )
            }
        }

        var didPersistBatch = false
        if let context, (!fileActions.isEmpty || !pendingFailureLogs.isEmpty) {
            do {
                try saveBatchedContext(context, stage: .bulkOrganize)
                didPersistBatch = true

                if recordedPersonalMemory {
                    try? memoryService?.pruneRetainedHistory(now: batchTimestamp)
                }
            } catch {
                if let batchSnapshot {
                    rollbackBatchedContext(
                        context,
                        snapshot: batchSnapshot,
                        compensationMoves: compensationMoves
                    )
                } else {
                    compensateDiskMoves(compensationMoves)
                }
                successCount = 0
                failedCount = files.count
                failedFiles = files
                firstError = error
                fileActions.removeAll()
                bulkMoveOperations.removeAll()
                pendingNotifications.removeAll()
            }
        }

        if !fileActions.isEmpty, context == nil || didPersistBatch {
            let command = BulkMoveCommand(
                id: UUID(),
                timestamp: batchTimestamp,
                origin: origin,
                operations: bulkMoveOperations
            )
            pushUndoCommand(command)
        }

        if context == nil || didPersistBatch {
            for notification in pendingNotifications {
                notificationService.notifyFileOrganized(
                    fileName: notification.fileName,
                    destination: notification.destination
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
        if context == nil, let skipCommand = command as? SkipFileCommand {
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

        do {
            if let bulkCommand = command as? BulkMoveCommand {
                try undoBulkCommand(bulkCommand, context: context)
            } else {
                try command.undo(context: context)
                persistUndoMetadata(for: command, context: context)
                recordUndoMemory(for: command, context: context)
            }

            // Push to redo stack
            redoStack.append(command)
            if redoStack.count > Self.maxRedoActions {
                redoStack.removeFirst(redoStack.count - Self.maxRedoActions)
            }
            refreshLatestUndoableBatchSummary()

            #if DEBUG
            Log.info("Undo successful: \\(command.description)", category: .undo)
            #endif
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

        do {
            if let bulkCommand = command as? BulkMoveCommand {
                try redoBulkCommand(bulkCommand, context: context)
            } else {
                try await command.execute(context: context)
                persistRedoMetadata(for: command, context: context)
            }

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

    private func saveBatchedContext(_ context: ModelContext, stage: BatchPersistenceStage) throws {
        #if DEBUG
        if let batchPersistenceSaveHook {
            try batchPersistenceSaveHook(stage)
        }
        #endif

        try context.save()
    }

    private func captureBatchPersistenceSnapshot(
        context: ModelContext,
        files: [FileItem]
    ) -> BatchPersistenceRestoreSnapshot {
        let fileItemSnapshots = files.map {
            FileItemRestoreSnapshot(
                file: $0,
                path: $0.path,
                status: $0.status,
                destination: $0.destination,
                lastOrganizeError: $0.lastOrganizeError
            )
        }

        let metadataRecords = (try? context.fetch(FetchDescriptor<FileMetadataRecord>())) ?? []
        let metadataSnapshots = Dictionary(
            uniqueKeysWithValues: metadataRecords.map { record in
                (
                    record.persistentModelID,
                    FileMetadataRecordRestoreSnapshot(
                        record: record,
                        canonicalIdentity: record.canonicalIdentity,
                        identityKind: record.identityKind,
                        lastKnownPath: record.lastKnownPath,
                        displayName: record.displayName,
                        fileExtension: record.fileExtension,
                        firstSeenAt: record.firstSeenAt,
                        lastSeenAt: record.lastSeenAt,
                        lastOrganizedAt: record.lastOrganizedAt,
                        organizationCount: record.organizationCount,
                        latestOrganizationStatus: record.latestOrganizationStatus,
                        workflowStatus: record.workflowStatus,
                        tags: record.tags,
                        projectAssociation: record.projectAssociation,
                        notesSummary: record.notesSummary
                    )
                )
            }
        )

        let historyEntries = (try? context.fetch(FetchDescriptor<FileOrganizationHistoryEntry>())) ?? []
        let historySnapshots = Dictionary(
            uniqueKeysWithValues: historyEntries.map { entry in
                (
                    entry.persistentModelID,
                    HistoryEntryRestoreSnapshot(
                        entry: entry,
                        metadataRecordID: entry.metadataRecord.persistentModelID
                    )
                )
            }
        )

        let activityItemIDs = Set(
            ((try? context.fetch(FetchDescriptor<ActivityItem>())) ?? []).map(\.persistentModelID)
        )

        let personalMemoryPreferences: [PersonalMemoryPreference]
        let personalMemoryEvents: [PersonalMemoryEvent]
        if FeatureFlagService.shared.isEnabled(.patternLearning) {
            personalMemoryPreferences = (try? context.fetch(FetchDescriptor<PersonalMemoryPreference>())) ?? []
            personalMemoryEvents = (try? context.fetch(FetchDescriptor<PersonalMemoryEvent>())) ?? []
        } else {
            personalMemoryPreferences = []
            personalMemoryEvents = []
        }

        let personalMemoryPreferenceSnapshots = Dictionary(
            uniqueKeysWithValues: personalMemoryPreferences.map { preference in
                (
                    preference.persistentModelID,
                    PersonalMemoryPreferenceRestoreSnapshot(
                        preference: preference,
                        key: preference.key,
                        fileExtension: preference.fileExtension,
                        fileTypeCategory: preference.fileTypeCategory,
                        sourceLocation: preference.sourceLocation,
                        relativeParentPath: preference.relativeParentPath,
                        destinationIdentity: preference.destinationIdentity,
                        preferredDestination: preference.preferredDestination,
                        acceptCount: preference.acceptCount,
                        overrideCount: preference.overrideCount,
                        correctionCount: preference.correctionCount,
                        undoCount: preference.undoCount,
                        deferCount: preference.deferCount,
                        lastObservedAt: preference.lastObservedAt
                    )
                )
            }
        )

        return BatchPersistenceRestoreSnapshot(
            fileItems: fileItemSnapshots,
            metadataRecords: metadataSnapshots,
            historyEntries: historySnapshots,
            activityItemIDs: activityItemIDs,
            personalMemoryPreferenceSnapshots: personalMemoryPreferenceSnapshots,
            personalMemoryEventIDs: Set(personalMemoryEvents.map(\.persistentModelID))
        )
    }

    private func rollbackBatchedContext(
        _ context: ModelContext,
        snapshot: BatchPersistenceRestoreSnapshot,
        compensationMoves: [DiskCompensationMove]
    ) {
        restoreBatchPersistenceSnapshot(snapshot, in: context)
        compensateDiskMoves(compensationMoves)
    }

    private func restoreBatchPersistenceSnapshot(
        _ snapshot: BatchPersistenceRestoreSnapshot,
        in context: ModelContext
    ) {
        for fileSnapshot in snapshot.fileItems {
            if fileSnapshot.file.path != fileSnapshot.path {
                _ = fileSnapshot.file.updatePath(fileSnapshot.path)
            }
            fileSnapshot.file.status = fileSnapshot.status
            fileSnapshot.file.destination = fileSnapshot.destination
            fileSnapshot.file.lastOrganizeError = fileSnapshot.lastOrganizeError
        }

        let currentMetadataRecords = (try? context.fetch(FetchDescriptor<FileMetadataRecord>())) ?? []
        let currentMetadataIDs = Set(currentMetadataRecords.map(\.persistentModelID))
        for (recordID, snapshotRecord) in snapshot.metadataRecords where !currentMetadataIDs.contains(recordID) {
            context.insert(snapshotRecord.record)
        }
        let allMetadataRecords = (try? context.fetch(FetchDescriptor<FileMetadataRecord>())) ?? []
        let snapshotMetadataIDs = Set(snapshot.metadataRecords.keys)
        for record in allMetadataRecords where !snapshotMetadataIDs.contains(record.persistentModelID) {
            context.delete(record)
        }
        for snapshotRecord in snapshot.metadataRecords.values {
            let record = snapshotRecord.record
            record.canonicalIdentity = snapshotRecord.canonicalIdentity
            record.identityKind = snapshotRecord.identityKind
            record.lastKnownPath = snapshotRecord.lastKnownPath
            record.displayName = snapshotRecord.displayName
            record.fileExtension = snapshotRecord.fileExtension
            record.firstSeenAt = snapshotRecord.firstSeenAt
            record.lastSeenAt = snapshotRecord.lastSeenAt
            record.lastOrganizedAt = snapshotRecord.lastOrganizedAt
            record.organizationCount = snapshotRecord.organizationCount
            record.latestOrganizationStatus = snapshotRecord.latestOrganizationStatus
            record.workflowStatus = snapshotRecord.workflowStatus
            record.tags = snapshotRecord.tags
            record.projectAssociation = snapshotRecord.projectAssociation
            record.notesSummary = snapshotRecord.notesSummary
        }

        let currentHistoryEntries = (try? context.fetch(FetchDescriptor<FileOrganizationHistoryEntry>())) ?? []
        let currentHistoryIDs = Set(currentHistoryEntries.map(\.persistentModelID))
        for (entryID, snapshotEntry) in snapshot.historyEntries where !currentHistoryIDs.contains(entryID) {
            context.insert(snapshotEntry.entry)
        }
        let metadataRecordsByID = Dictionary(
            uniqueKeysWithValues: snapshot.metadataRecords.map { ($0.key, $0.value.record) }
        )
        for snapshotEntry in snapshot.historyEntries.values {
            guard let metadataRecord = metadataRecordsByID[snapshotEntry.metadataRecordID] else {
                continue
            }
            snapshotEntry.entry.metadataRecord = metadataRecord
        }
        let allHistoryEntries = (try? context.fetch(FetchDescriptor<FileOrganizationHistoryEntry>())) ?? []
        let snapshotHistoryIDs = Set(snapshot.historyEntries.keys)
        for entry in allHistoryEntries where !snapshotHistoryIDs.contains(entry.persistentModelID) {
            context.delete(entry)
        }
        let restoredHistoryByRecordID = Dictionary(
            grouping: snapshot.historyEntries.values,
            by: \.metadataRecordID
        )
        for snapshotRecord in snapshot.metadataRecords.values {
            guard let restoredEntries = restoredHistoryByRecordID[snapshotRecord.record.persistentModelID] else {
                continue
            }
            snapshotRecord.record.historyEntries = restoredEntries
                .map(\.entry)
                .sorted { $0.timestamp < $1.timestamp }
        }

        let currentActivities = (try? context.fetch(FetchDescriptor<ActivityItem>())) ?? []
        for activity in currentActivities where !snapshot.activityItemIDs.contains(activity.persistentModelID) {
            context.delete(activity)
        }

        if FeatureFlagService.shared.isEnabled(.patternLearning) {
            let currentPreferences = (try? context.fetch(FetchDescriptor<PersonalMemoryPreference>())) ?? []
            let currentPreferenceIDs = Set(currentPreferences.map(\.persistentModelID))
            for (preferenceID, snapshotPreference) in snapshot.personalMemoryPreferenceSnapshots
                where !currentPreferenceIDs.contains(preferenceID) {
                context.insert(snapshotPreference.preference)
            }
            let allPreferences = (try? context.fetch(FetchDescriptor<PersonalMemoryPreference>())) ?? []
            let snapshotPreferenceIDs = Set(snapshot.personalMemoryPreferenceSnapshots.keys)
            for preference in allPreferences where !snapshotPreferenceIDs.contains(preference.persistentModelID) {
                context.delete(preference)
            }
            for snapshotPreference in snapshot.personalMemoryPreferenceSnapshots.values {
                let preference = snapshotPreference.preference
                preference.key = snapshotPreference.key
                preference.fileExtension = snapshotPreference.fileExtension
                preference.fileTypeCategory = snapshotPreference.fileTypeCategory
                preference.sourceLocation = snapshotPreference.sourceLocation
                preference.relativeParentPath = snapshotPreference.relativeParentPath
                preference.destinationIdentity = snapshotPreference.destinationIdentity
                preference.preferredDestination = snapshotPreference.preferredDestination
                preference.acceptCount = snapshotPreference.acceptCount
                preference.overrideCount = snapshotPreference.overrideCount
                preference.correctionCount = snapshotPreference.correctionCount
                preference.undoCount = snapshotPreference.undoCount
                preference.deferCount = snapshotPreference.deferCount
                preference.lastObservedAt = snapshotPreference.lastObservedAt
            }

            let currentEvents = (try? context.fetch(FetchDescriptor<PersonalMemoryEvent>())) ?? []
            for event in currentEvents where !snapshot.personalMemoryEventIDs.contains(event.persistentModelID) {
                context.delete(event)
            }
        }
    }

    private func compensateDiskMoves(_ compensationMoves: [DiskCompensationMove]) {
        for move in compensationMoves.reversed() where FileManager.default.fileExists(atPath: move.sourcePath) {
            do {
                try fileOperationsService.secureMoveOnDisk(from: move.sourcePath, to: move.destinationPath)
            } catch {
                Log.error(
                    "Failed to compensate disk move from '\(move.sourcePath)' to '\(move.destinationPath)': \(error.localizedDescription)",
                    category: .fileOperations
                )
            }
        }
    }

    private func prefetchBulkMoveFiles(
        for operations: [BulkMoveOperation],
        context: ModelContext
    ) throws -> [String: FileItem] {
        let candidatePaths = Set(operations.flatMap { [$0.fromPath, $0.toPath] })
        let files = try context.fetch(FetchDescriptor<FileItem>())
        return Dictionary(
            files
                .filter { candidatePaths.contains($0.path) }
                .map { ($0.path, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private func undoBulkCommand(_ command: BulkMoveCommand, context: ModelContext) throws {
        let batchTimestamp = Date()
        var compensationMoves: [DiskCompensationMove] = []
        var filesByPath = try prefetchBulkMoveFiles(for: command.operations, context: context)
        let batchSnapshot = captureBatchPersistenceSnapshot(
            context: context,
            files: Array(Set(filesByPath.values.map(\.persistentModelID))).compactMap { id in
                filesByPath.values.first(where: { $0.persistentModelID == id })
            }
        )
        let memoryService = PersonalMemoryService(modelContext: context)

        do {
            for operation in command.operations {
                guard let file = filesByPath[operation.toPath] ?? filesByPath[operation.fromPath] else {
                    continue
                }

                if FileManager.default.fileExists(atPath: operation.toPath) {
                    try fileOperationsService.secureMoveOnDisk(from: operation.toPath, to: operation.fromPath)
                    compensationMoves.append(
                        DiskCompensationMove(
                            sourcePath: operation.fromPath,
                            destinationPath: operation.toPath
                        )
                    )
                    _ = file.updatePath(operation.fromPath)
                    filesByPath.removeValue(forKey: operation.toPath)
                    filesByPath[operation.fromPath] = file
                }

                file.status = operation.originalStatus
            }

            try persistUndoMetadataWithoutSaving(for: command, context: context, timestamp: batchTimestamp)
            let recordedPersonalMemory = try recordUndoMemoryWithoutSaving(
                for: command,
                memoryService: memoryService,
                timestamp: batchTimestamp
            )
            ActivityLoggingService(modelContext: context).logBulkUndoneWithoutSaving(
                count: command.operations.count,
                origin: command.origin
            )
            try saveBatchedContext(context, stage: .bulkUndo)

            if recordedPersonalMemory {
                try? memoryService.pruneRetainedHistory(now: batchTimestamp)
            }
        } catch {
            rollbackBatchedContext(
                context,
                snapshot: batchSnapshot,
                compensationMoves: compensationMoves
            )
            throw error
        }
    }

    private func redoBulkCommand(_ command: BulkMoveCommand, context: ModelContext) throws {
        let batchTimestamp = Date()
        var compensationMoves: [DiskCompensationMove] = []
        var filesByPath = try prefetchBulkMoveFiles(for: command.operations, context: context)
        let batchSnapshot = captureBatchPersistenceSnapshot(
            context: context,
            files: Array(Set(filesByPath.values.map(\.persistentModelID))).compactMap { id in
                filesByPath.values.first(where: { $0.persistentModelID == id })
            }
        )

        do {
            for operation in command.operations {
                guard let file = filesByPath[operation.fromPath] ?? filesByPath[operation.toPath] else {
                    continue
                }

                if FileManager.default.fileExists(atPath: operation.fromPath) {
                    try fileOperationsService.secureMoveOnDisk(from: operation.fromPath, to: operation.toPath)
                    compensationMoves.append(
                        DiskCompensationMove(
                            sourcePath: operation.toPath,
                            destinationPath: operation.fromPath
                        )
                    )
                    _ = file.updatePath(operation.toPath)
                    filesByPath.removeValue(forKey: operation.fromPath)
                    filesByPath[operation.toPath] = file
                }

                file.status = .completed
            }

            try persistRedoMetadataWithoutSaving(for: command, context: context, timestamp: batchTimestamp)
            try saveBatchedContext(context, stage: .bulkRedo)
        } catch {
            rollbackBatchedContext(
                context,
                snapshot: batchSnapshot,
                compensationMoves: compensationMoves
            )
            throw error
        }
    }

    private func stageMetadataTransitionWithoutSaving(
        from sourcePath: String,
        to destinationPath: String,
        displayName: String,
        fileExtension: String,
        destinationDisplayName: String?,
        projectAssociationWriteContext: ProjectAssociationWriteContext? = nil,
        eventKind: FileOrganizationHistoryEntry.EventKind,
        sourceSurface: FileOrganizationHistoryEntry.SourceSurface,
        matchedRuleID: UUID?,
        context: ModelContext,
        timestamp: Date
    ) throws {
        guard FeatureFlagService.shared.isEnabled(.metadataFoundation) else { return }

        let metadataService = FileMetadataFoundationService(modelContext: context)
        _ = try metadataService.recordTransitionWithoutSaving(
            from: sourcePath,
            to: destinationPath,
            displayName: displayName,
            fileExtension: fileExtension,
            eventKind: eventKind,
            sourceSurface: sourceSurface,
            destinationDisplayName: destinationDisplayName,
            projectAssociationWriteContext: projectAssociationWriteContext,
            matchedRuleID: matchedRuleID,
            timestamp: timestamp
        )
    }

    private func persistMetadataTransition(
        from sourcePath: String,
        to destinationPath: String,
        displayName: String,
        fileExtension: String,
        destinationDisplayName: String?,
        projectAssociationWriteContext: ProjectAssociationWriteContext? = nil,
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
                projectAssociationWriteContext: projectAssociationWriteContext,
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

    private func persistUndoMetadataWithoutSaving(
        for command: any UndoableCommand,
        context: ModelContext,
        timestamp: Date
    ) throws {
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

            #if DEBUG
            if let metadataUndoTransitionHook {
                try metadataUndoTransitionHook(snapshot)
            }
            #endif

            try stageMetadataTransitionWithoutSaving(
                from: snapshot.destinationPath,
                to: snapshot.sourcePath,
                displayName: snapshot.displayName,
                fileExtension: snapshot.fileExtension,
                destinationDisplayName: snapshot.destinationDisplayName,
                eventKind: .undone,
                sourceSurface: .undo,
                matchedRuleID: nil,
                context: context,
                timestamp: timestamp
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

                #if DEBUG
                if let metadataUndoTransitionHook {
                    try metadataUndoTransitionHook(snapshot)
                }
                #endif

                try stageMetadataTransitionWithoutSaving(
                    from: snapshot.destinationPath,
                    to: snapshot.sourcePath,
                    displayName: snapshot.displayName,
                    fileExtension: snapshot.fileExtension,
                    destinationDisplayName: snapshot.destinationDisplayName,
                    eventKind: .undone,
                    sourceSurface: .undo,
                    matchedRuleID: nil,
                    context: context,
                    timestamp: timestamp
                )
            }

        default:
            break
        }
    }

    private func persistRedoMetadataWithoutSaving(
        for command: any UndoableCommand,
        context: ModelContext,
        timestamp: Date
    ) throws {
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

            try stageMetadataTransitionWithoutSaving(
                from: snapshot.sourcePath,
                to: snapshot.destinationPath,
                displayName: snapshot.displayName,
                fileExtension: snapshot.fileExtension,
                destinationDisplayName: snapshot.destinationDisplayName,
                projectAssociationWriteContext: snapshot.projectAssociationWriteContext,
                eventKind: .organized,
                sourceSurface: .organize,
                matchedRuleID: nil,
                context: context,
                timestamp: timestamp
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

                try stageMetadataTransitionWithoutSaving(
                    from: snapshot.sourcePath,
                    to: snapshot.destinationPath,
                    displayName: snapshot.displayName,
                    fileExtension: snapshot.fileExtension,
                    destinationDisplayName: snapshot.destinationDisplayName,
                    projectAssociationWriteContext: snapshot.projectAssociationWriteContext,
                    eventKind: .organized,
                    sourceSurface: .organize,
                    matchedRuleID: nil,
                    context: context,
                    timestamp: timestamp
                )
            }

        default:
            break
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
                projectAssociationWriteContext: snapshot.projectAssociationWriteContext,
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
                    projectAssociationWriteContext: snapshot.projectAssociationWriteContext,
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

    private func persistSkipMetadata(
        for file: FileItem,
        context: ModelContext
    ) throws -> SkipFileCommand.DurableWorkflowStatusSnapshot? {
        let metadataService = FileMetadataFoundationService(modelContext: context)
        guard let preparation = try metadataService.prepareIgnoredHistoryWithoutSaving(
            for: file.path,
            detailsSummary: nil,
            timestamp: Date()
        ) else {
            return nil
        }

        let snapshot = SkipFileCommand.DurableWorkflowStatusSnapshot(
            previousValue: preparation.previousWorkflowStatus
        )
        return snapshot
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

    private func logRuleApplicationsWithoutSaving(
        ruleUsageCounts: [UUID: Int],
        activityService: ActivityLoggingService,
        modelContext: ModelContext
    ) {
        for (ruleID, matchCount) in ruleUsageCounts {
            let descriptor = FetchDescriptor<Rule>(
                predicate: #Predicate { $0.id == ruleID }
            )

            do {
                if let rule = try modelContext.fetch(descriptor).first {
                    activityService.logRuleAppliedWithoutSaving(
                        ruleName: rule.name,
                        ruleID: ruleID,
                        matchCount: matchCount
                    )
                } else {
                    activityService.logRuleAppliedWithoutSaving(
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

    private func projectAssociationWriteContext(
        destinationPath: String,
        explicitSourceMode: Bool = false
    ) -> ProjectAssociationWriteContext {
        let destinationFolderPath = URL(fileURLWithPath: destinationPath)
            .standardizedFileURL
            .deletingLastPathComponent()
            .path

        return ProjectAssociationWriteContext(
            resolvedExplicitDestinationFolderPath: destinationFolderPath,
            explicitSourceMode: explicitSourceMode,
            inferredCandidates: []
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

    private func recordPersonalMemoryDecisionWithoutSaving(
        snapshot: OrganizationMemorySnapshot,
        sourceSurface: PersonalMemorySourceSurface,
        memoryService: PersonalMemoryService,
        timestamp: Date
    ) throws {
        _ = try memoryService.recordDecisionWithoutSaving(
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
            matchedRuleID: snapshot.matchedRuleID,
            timestamp: timestamp
        )
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

    @discardableResult
    private func recordUndoMemoryWithoutSaving(
        for command: any UndoableCommand,
        memoryService: PersonalMemoryService,
        timestamp: Date
    ) throws -> Bool {
        guard FeatureFlagService.shared.isEnabled(.patternLearning) else { return false }

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
            _ = try memoryService.recordDecisionWithoutSaving(
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
                priorDestination: snapshot.chosenDestination,
                timestamp: timestamp
            )
        }

        return !snapshots.isEmpty
    }
}
