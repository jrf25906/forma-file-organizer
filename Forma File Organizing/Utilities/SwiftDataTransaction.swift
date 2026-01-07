import Foundation
import SwiftData

/// Provides transactional save operations for SwiftData with automatic rollback on failure.
///
/// SwiftData doesn't have built-in transaction support like Core Data's `perform` blocks.
/// This utility registers rollback closures that execute if save fails.
///
/// Usage:
/// ```swift
/// let transaction = SwiftDataTransaction(context: modelContext)
///
/// // Capture state before changes
/// let previousStatus = file.status
/// transaction.onRollback { file.status = previousStatus }
///
/// // Make changes
/// file.status = .completed
///
/// // Save with automatic rollback on failure
/// try transaction.saveOrRollback()
/// ```
@MainActor
final class SwiftDataTransaction {
    private let context: ModelContext
    private var rollbackActions: [() -> Void] = []

    init(context: ModelContext) {
        self.context = context
    }

    /// Registers a rollback action to be executed on save failure.
    /// Actions are executed in reverse order (LIFO - last registered, first executed).
    func onRollback(_ action: @escaping () -> Void) {
        rollbackActions.append(action)
    }

    /// Attempts to save the context. On failure, executes all rollback actions.
    func saveOrRollback() throws {
        do {
            try context.save()
        } catch {
            executeRollback()
            throw error
        }
    }

    /// Attempts to save without throwing. Returns success status.
    @discardableResult
    func trySaveOrRollback() -> Bool {
        do {
            try context.save()
            return true
        } catch {
            executeRollback()
            Log.error("SwiftData save failed, rolled back: \(error.localizedDescription)", category: .fileOperations)
            return false
        }
    }

    private func executeRollback() {
        // Execute rollback actions in reverse order (LIFO)
        for action in rollbackActions.reversed() {
            action()
        }

        #if DEBUG
        Log.debug("SwiftDataTransaction: Executed \(rollbackActions.count) rollback actions", category: .fileOperations)
        #endif
    }
}

// MARK: - Convenience Extension for ModelContext

extension ModelContext {
    /// Performs a transaction with automatic rollback on save failure.
    ///
    /// Example:
    /// ```swift
    /// try context.withTransaction { tx in
    ///     tx.onRollback { file.status = .pending }
    ///     file.status = .completed
    /// }
    /// ```
    @MainActor
    func withTransaction(_ block: (SwiftDataTransaction) throws -> Void) throws {
        let transaction = SwiftDataTransaction(context: self)
        try block(transaction)
        try transaction.saveOrRollback()
    }

    /// Async version of withTransaction for async operations.
    @MainActor
    func withTransaction(_ block: (SwiftDataTransaction) async throws -> Void) async throws {
        let transaction = SwiftDataTransaction(context: self)
        try await block(transaction)
        try transaction.saveOrRollback()
    }
}

// MARK: - Batch Save Helper

extension ModelContext {
    /// Saves multiple inserts/updates with a single error handler.
    /// On failure, deletes any newly inserted objects.
    @MainActor
    func saveBatchInserts<T: PersistentModel>(_ objects: [T]) throws {
        for object in objects {
            insert(object)
        }

        do {
            try save()
        } catch {
            // Remove inserted objects on failure
            for object in objects {
                delete(object)
            }
            throw error
        }
    }
}
