import Foundation

/// Centralized error handling utility for consistent error processing across the app
///
/// Usage:
/// ```swift
/// // In services - wrap throwing operations:
/// try ErrorHandler.wrap(operation: "moving file") {
///     try fileManager.moveItem(at: source, to: destination)
/// }
///
/// // In ViewModels - handle errors with user feedback:
/// ErrorHandler.handle(error) { message in
///     self.errorMessage = message
/// }
/// ```
enum ErrorHandler {

    // MARK: - Error Wrapping

    /// Wraps a throwing operation and converts any error to FormaError
    /// - Parameters:
    ///   - operation: Description of the operation for logging
    ///   - category: Log category for this operation
    ///   - body: The throwing operation to execute
    /// - Returns: The result of the operation
    /// - Throws: FormaError converted from any caught error
    static func wrap<T>(
        operation: String,
        category: Log.Category = .general,
        _ body: () throws -> T
    ) throws -> T {
        do {
            return try body()
        } catch let error as FormaError {
            Log.error("\(operation) failed: \(error.localizedDescription)", category: category)
            throw error
        } catch {
            let formaError = FormaError.from(error)
            Log.error("\(operation) failed: \(formaError.localizedDescription)", category: category)
            throw formaError
        }
    }

    /// Async version of wrap for async throwing operations
    static func wrap<T>(
        operation: String,
        category: Log.Category = .general,
        _ body: () async throws -> T
    ) async throws -> T {
        do {
            return try await body()
        } catch let error as FormaError {
            Log.error("\(operation) failed: \(error.localizedDescription)", category: category)
            throw error
        } catch {
            let formaError = FormaError.from(error)
            Log.error("\(operation) failed: \(formaError.localizedDescription)", category: category)
            throw formaError
        }
    }

    // MARK: - Error Handling

    /// Handles an error by extracting user-friendly message and optionally logging
    /// - Parameters:
    ///   - error: The error to handle
    ///   - logCategory: Optional category for logging (if nil, doesn't log)
    ///   - handler: Closure receiving the user-friendly error message
    static func handle(
        _ error: Error,
        logCategory: Log.Category? = nil,
        handler: (String) -> Void
    ) {
        let message = userMessage(for: error)

        if let category = logCategory {
            Log.error(message, category: category)
        }

        handler(message)
    }

    /// Handles an error by extracting user-friendly message with recovery suggestion
    /// - Parameters:
    ///   - error: The error to handle
    ///   - logCategory: Optional category for logging
    ///   - handler: Closure receiving (message, recoverySuggestion?, isRecoverable)
    static func handleWithRecovery(
        _ error: Error,
        logCategory: Log.Category? = nil,
        handler: (String, String?, Bool) -> Void
    ) {
        let formaError = FormaError.from(error)
        let message = formaError.errorDescription ?? error.localizedDescription
        let recovery = formaError.recoverySuggestion
        let isRecoverable = formaError.isRecoverable

        if let category = logCategory {
            Log.error("\(message) (recoverable: \(isRecoverable))", category: category)
        }

        handler(message, recovery, isRecoverable)
    }

    // MARK: - Error Classification

    /// Extracts a user-friendly message from any error
    static func userMessage(for error: Error) -> String {
        if let formaError = error as? FormaError {
            return formaError.errorDescription ?? "An unexpected error occurred"
        }

        // Convert and get message
        let converted = FormaError.from(error)
        return converted.errorDescription ?? error.localizedDescription
    }

    /// Checks if an error represents a user cancellation
    static func isCancellation(_ error: Error) -> Bool {
        if let formaError = error as? FormaError {
            if case .operation(.cancelled) = formaError {
                return true
            }
        }

        // Check common cancellation patterns
        let nsError = error as NSError
        return nsError.code == NSUserCancelledError ||
               nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError
    }

    /// Checks if an error is recoverable
    static func isRecoverable(_ error: Error) -> Bool {
        FormaError.from(error).isRecoverable
    }

    /// Checks if an error is permission-related
    static func isPermissionError(_ error: Error) -> Bool {
        if let formaError = error as? FormaError {
            if case .fileSystem(.permissionDenied) = formaError {
                return true
            }
        }

        let nsError = error as NSError
        return nsError.code == NSFileWriteNoPermissionError ||
               nsError.code == NSFileReadNoPermissionError
    }

    // MARK: - Result Helpers

    /// Converts a throwing operation result to Result<T, FormaError>
    static func result<T>(of body: () throws -> T) -> Result<T, FormaError> {
        do {
            return .success(try body())
        } catch {
            return .failure(FormaError.from(error))
        }
    }

    /// Async version of result helper
    static func result<T>(of body: () async throws -> T) async -> Result<T, FormaError> {
        do {
            return .success(try await body())
        } catch {
            return .failure(FormaError.from(error))
        }
    }
}

// MARK: - Convenience Extensions

extension FormaError {
    /// Creates a file system permission denied error with standard messaging
    static func permissionDenied(for path: String) -> FormaError {
        .fileSystem(.permissionDenied(path))
    }

    /// Creates a file not found error
    static func fileNotFound(_ path: String) -> FormaError {
        .fileSystem(.notFound(path))
    }

    /// Creates a user cancelled operation error
    static var cancelled: FormaError {
        .operation(.cancelled)
    }

    /// Creates a generic operation failure
    static func operationFailed(_ message: String, underlying: Error? = nil) -> FormaError {
        .operation(.failed(message, underlying: underlying))
    }
}
