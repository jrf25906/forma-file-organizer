import Foundation

/// Actor that coordinates file operations to prevent race conditions and concurrent access.
///
/// This actor ensures that:
/// 1. Only one operation per file can run at a time
/// 2. File state mutations are serialized
/// 3. Operations can be safely cancelled
///
/// Usage:
/// ```swift
/// let coordinator = FileOperationCoordinator()
/// try await coordinator.organize(fileID: file.path) {
///     // Perform file operation
///     try await fileOperationsService.moveFile(file)
/// }
/// ```
actor FileOperationCoordinator {
    
    /// Tracks files currently being organized
    private var operationsInProgress: Set<String> = []
    
    /// Tracks cancelled operation IDs
    private var cancelledOperations: Set<String> = []
    
    enum CoordinatorError: LocalizedError {
        case alreadyInProgress(fileID: String)
        case operationCancelled
        
        var errorDescription: String? {
            switch self {
            case .alreadyInProgress(let fileID):
                return "Operation already in progress for file: \(fileID)"
            case .operationCancelled:
                return "Operation was cancelled"
            }
        }
    }
    
    /// Begins an exclusive operation for a file.
    ///
    /// Call `finishOperation(fileID:)` when your work completes (use a `defer` to ensure cleanup).
    func beginOperation(fileID: String) throws {
        guard !operationsInProgress.contains(fileID) else {
            throw CoordinatorError.alreadyInProgress(fileID: fileID)
        }

        guard !cancelledOperations.contains(fileID) else {
            cancelledOperations.remove(fileID)
            throw CoordinatorError.operationCancelled
        }

        operationsInProgress.insert(fileID)

        guard !cancelledOperations.contains(fileID) else {
            operationsInProgress.remove(fileID)
            throw CoordinatorError.operationCancelled
        }
    }

    /// Finishes an operation started via `beginOperation(fileID:)`.
    func finishOperation(fileID: String) {
        operationsInProgress.remove(fileID)
        cancelledOperations.remove(fileID)
    }
    
    /// Checks if an operation is currently in progress for a file.
    ///
    /// - Parameter fileID: The file identifier to check
    /// - Returns: `true` if an operation is running, `false` otherwise
    func isOperationInProgress(fileID: String) -> Bool {
        operationsInProgress.contains(fileID)
    }
    
    /// Cancels an in-progress operation for a file.
    ///
    /// This marks the operation as cancelled, but the actual cancellation
    /// is cooperative - the operation must check for cancellation.
    ///
    /// - Parameter fileID: The file identifier to cancel
    func cancelOperation(fileID: String) {
        if operationsInProgress.contains(fileID) {
            cancelledOperations.insert(fileID)
        }
    }
    
    /// Returns the set of files currently being organized.
    ///
    /// - Returns: Set of file identifiers with operations in progress
    func getOperationsInProgress() -> Set<String> {
        operationsInProgress
    }
    
    /// Cancels all in-progress operations.
    func cancelAllOperations() {
        cancelledOperations.formUnion(operationsInProgress)
    }
}
