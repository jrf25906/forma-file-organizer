import Foundation

/// Centralized error hierarchy for Forma
/// Provides consistent error handling across all services and ViewModels
enum FormaError: LocalizedError {
    // MARK: - File System Errors
    case fileSystem(FileSystemError)
    
    // MARK: - Validation Errors
    case validation(ValidationError)
    
    // MARK: - Operation Errors
    case operation(OperationError)
    
    // MARK: - Data Errors
    case data(DataError)
    
    var errorDescription: String? {
        switch self {
        case .fileSystem(let error):
            return error.errorDescription
        case .validation(let error):
            return error.errorDescription
        case .operation(let error):
            return error.errorDescription
        case .data(let error):
            return error.errorDescription
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .fileSystem(let error):
            return error.recoverySuggestion
        case .validation(let error):
            return error.recoverySuggestion
        case .operation(let error):
            return error.recoverySuggestion
        case .data(let error):
            return error.recoverySuggestion
        }
    }
    
    var isRecoverable: Bool {
        switch self {
        case .fileSystem(let error):
            return error.isRecoverable
        case .validation(let error):
            return error.isRecoverable
        case .operation(let error):
            return error.isRecoverable
        case .data(let error):
            return error.isRecoverable
        }
    }
}

// MARK: - File System Errors

enum FileSystemError: LocalizedError {
    case notFound(String)
    case permissionDenied(String)
    case alreadyExists(String)
    case diskFull
    case fileInUse(String)
    case invalidPath(String)
    case moveAcrossDevices(source: String, destination: String)
    case symlinkDetected(String)
    case ioError(String, underlying: Error?)
    
    var errorDescription: String? {
        switch self {
        case .notFound(let path):
            return "File not found: \(path)"
        case .permissionDenied(let path):
            return "Permission denied for: \(path)"
        case .alreadyExists(let path):
            return "File already exists: \(path)"
        case .diskFull:
            return "Not enough disk space to complete operation"
        case .fileInUse(let path):
            return "File is in use: \(path)"
        case .invalidPath(let path):
            return "Invalid file path: \(path)"
        case .moveAcrossDevices(let source, let destination):
            return "Cannot move file across devices: \(source) → \(destination)"
        case .symlinkDetected(let path):
            return "Symbolic link detected (security risk): \(path)"
        case .ioError(let message, _):
            return "I/O error: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .notFound:
            return "The file may have been moved or deleted. Try refreshing the file list."
        case .permissionDenied:
            return "Grant Forma access to the folder in System Settings → Privacy & Security → Files and Folders."
        case .alreadyExists:
            return "Choose a different destination or rename the existing file."
        case .diskFull:
            return "Free up disk space and try again."
        case .fileInUse:
            return "Close any applications using this file and try again."
        case .invalidPath:
            return "Use only valid characters in file paths. Avoid: < > : | ? * \""
        case .moveAcrossDevices:
            return "Files cannot be moved across different storage devices. Try copying instead."
        case .symlinkDetected:
            return "Symbolic links are not supported for security reasons."
        case .ioError:
            return "Check the file system and try again."
        }
    }
    
    var isRecoverable: Bool {
        switch self {
        case .notFound, .alreadyExists, .fileInUse, .invalidPath:
            return true
        case .permissionDenied, .diskFull, .symlinkDetected:
            return false
        case .moveAcrossDevices, .ioError:
            return true
        }
    }
}

// MARK: - Validation Errors

enum ValidationError: LocalizedError {
    case emptyPath
    case invalidCharacters(String)
    case pathTooLong(Int, max: Int)
    case invalidDestination(String)
    case invalidFileSize(Int64)
    case invalidDate
    
    var errorDescription: String? {
        switch self {
        case .emptyPath:
            return "Path cannot be empty"
        case .invalidCharacters(let chars):
            return "Path contains invalid characters: \(chars)"
        case .pathTooLong(let length, let max):
            return "Path is too long (\(length) characters, max: \(max))"
        case .invalidDestination(let path):
            return "Invalid destination: \(path)"
        case .invalidFileSize(let size):
            return "Invalid file size: \(size) bytes"
        case .invalidDate:
            return "Invalid date value"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .emptyPath:
            return "Provide a valid file path."
        case .invalidCharacters:
            return "Remove special characters from the path."
        case .pathTooLong:
            return "Shorten the file path or move files to a location with a shorter path."
        case .invalidDestination:
            return "Choose a valid destination folder within your home directory."
        case .invalidFileSize:
            return "Check the file and ensure it has a valid size."
        case .invalidDate:
            return "This shouldn't happen. Please report this bug."
        }
    }
    
    var isRecoverable: Bool {
        true
    }
}

// MARK: - Operation Errors

enum OperationError: LocalizedError {
    case cancelled
    case timeout
    case inProgress(String)
    case failed(String, underlying: Error?)
    case unsupported(String)
    case notReady(String)
    
    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Operation cancelled by user"
        case .timeout:
            return "Operation timed out"
        case .inProgress(let operation):
            return "Operation already in progress: \(operation)"
        case .failed(let message, _):
            return "Operation failed: \(message)"
        case .unsupported(let feature):
            return "Unsupported operation: \(feature)"
        case .notReady(let reason):
            return "Cannot perform operation: \(reason)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .cancelled:
            return "Try again if this was unintentional."
        case .timeout:
            return "Check your system resources and try again."
        case .inProgress:
            return "Wait for the current operation to complete."
        case .failed:
            return "Check the error details and try again."
        case .unsupported:
            return "This feature is not available."
        case .notReady:
            return "Ensure all prerequisites are met before trying again."
        }
    }
    
    var isRecoverable: Bool {
        switch self {
        case .cancelled, .timeout, .inProgress, .failed:
            return true
        case .unsupported, .notReady:
            return false
        }
    }
}

// MARK: - Data Errors

enum DataError: LocalizedError {
    case corruptedData(String)
    case saveFailed(underlying: Error?)
    case fetchFailed(underlying: Error?)
    case notFound(String)
    case invalidData(String)
    
    var errorDescription: String? {
        switch self {
        case .corruptedData(let description):
            return "Data is corrupted: \(description)"
        case .saveFailed:
            return "Failed to save data"
        case .fetchFailed:
            return "Failed to load data"
        case .notFound(let item):
            return "Data not found: \(item)"
        case .invalidData(let description):
            return "Invalid data: \(description)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .corruptedData:
            return "The data file may be corrupted. Try refreshing or restarting the app."
        case .saveFailed:
            return "Check disk space and permissions, then try again."
        case .fetchFailed:
            return "Restart the app and try again."
        case .notFound:
            return "The requested data could not be found. Try refreshing."
        case .invalidData:
            return "The data format is invalid. This may be a bug."
        }
    }
    
    var isRecoverable: Bool {
        switch self {
        case .corruptedData:
            return false
        case .saveFailed, .fetchFailed, .notFound, .invalidData:
            return true
        }
    }
}

// MARK: - Convenience Extensions

extension FormaError {
    /// Convert from NSError
    static func from(_ error: NSError) -> FormaError {
        switch error.code {
        case NSFileNoSuchFileError:
            return .fileSystem(.notFound(error.localizedDescription))
        case NSFileWriteOutOfSpaceError:
            return .fileSystem(.diskFull)
        case NSFileWriteNoPermissionError, NSFileReadNoPermissionError:
            return .fileSystem(.permissionDenied(error.localizedDescription))
        case NSFileWriteFileExistsError:
            return .fileSystem(.alreadyExists(error.localizedDescription))
        case NSFileLockingError:
            return .fileSystem(.fileInUse(error.localizedDescription))
        default:
            return .fileSystem(.ioError(error.localizedDescription, underlying: error))
        }
    }
    
    /// Convert from any Error
    static func from(_ error: Error) -> FormaError {
        if let formaError = error as? FormaError {
            return formaError
        }
        // All Swift errors bridge to NSError, so we use direct cast
        let nsError = error as NSError
        return from(nsError)
    }
}

// MARK: - Result Extensions

extension Result where Failure == FormaError {
    /// Map NSError to FormaError
    init(catching body: () throws -> Success) {
        do {
            self = .success(try body())
        } catch {
            self = .failure(FormaError.from(error))
        }
    }
}

// MARK: - Error Context

/// Wraps a FormaError with additional context for debugging and logging
/// Use this when you need rich error information beyond the basic error type
struct ErrorContext: LocalizedError, CustomStringConvertible {
    /// The underlying error
    let error: FormaError

    /// When the error occurred
    let timestamp: Date

    /// What operation was being performed (e.g., "moving file", "scanning Desktop")
    let operation: String?

    /// The file path involved, if any
    let filePath: String?

    /// Additional context for debugging (not shown to users)
    let debugInfo: [String: String]

    /// Unique identifier for correlating related errors in logs
    let correlationId: String

    // MARK: - Initialization

    init(
        _ error: FormaError,
        operation: String? = nil,
        filePath: String? = nil,
        debugInfo: [String: String] = [:],
        correlationId: String? = nil
    ) {
        self.error = error
        self.timestamp = Date()
        self.operation = operation
        self.filePath = filePath
        self.debugInfo = debugInfo
        self.correlationId = correlationId ?? UUID().uuidString.prefix(8).lowercased()
    }

    // MARK: - LocalizedError Conformance

    var errorDescription: String? {
        error.errorDescription
    }

    var recoverySuggestion: String? {
        error.recoverySuggestion
    }

    var failureReason: String? {
        if let operation = operation {
            return "Error occurred while \(operation)"
        }
        return nil
    }

    // MARK: - CustomStringConvertible

    var description: String {
        var parts: [String] = []
        parts.append("[\(correlationId)]")

        if let operation = operation {
            parts.append("Operation: \(operation)")
        }

        if let filePath = filePath {
            parts.append("File: \(filePath)")
        }

        parts.append("Error: \(error.errorDescription ?? "Unknown")")

        return parts.joined(separator: " | ")
    }

    // MARK: - Debug Description

    /// Full debug description including all context for logging
    var debugDescription: String {
        var lines: [String] = []
        lines.append("=== Error Context [\(correlationId)] ===")
        lines.append("Timestamp: \(ISO8601DateFormatter().string(from: timestamp))")

        if let operation = operation {
            lines.append("Operation: \(operation)")
        }

        if let filePath = filePath {
            lines.append("File: \(filePath)")
        }

        lines.append("Error Type: \(String(describing: type(of: error)))")
        lines.append("Description: \(error.errorDescription ?? "None")")

        if let recovery = error.recoverySuggestion {
            lines.append("Recovery: \(recovery)")
        }

        lines.append("Recoverable: \(error.isRecoverable)")

        if !debugInfo.isEmpty {
            lines.append("Debug Info:")
            for (key, value) in debugInfo.sorted(by: { $0.key < $1.key }) {
                lines.append("  \(key): \(value)")
            }
        }

        lines.append("================================")
        return lines.joined(separator: "\n")
    }

    // MARK: - Convenience Properties

    /// Whether the underlying error is recoverable
    var isRecoverable: Bool {
        error.isRecoverable
    }

    /// The underlying FormaError for pattern matching
    var underlyingError: FormaError {
        error
    }
}

// MARK: - ErrorContext Builder

extension ErrorContext {
    /// Builder pattern for adding context incrementally
    func with(operation: String) -> ErrorContext {
        ErrorContext(
            error,
            operation: operation,
            filePath: filePath,
            debugInfo: debugInfo,
            correlationId: correlationId
        )
    }

    func with(filePath: String) -> ErrorContext {
        ErrorContext(
            error,
            operation: operation,
            filePath: filePath,
            debugInfo: debugInfo,
            correlationId: correlationId
        )
    }

    func with(debugInfo key: String, value: String) -> ErrorContext {
        var newDebugInfo = debugInfo
        newDebugInfo[key] = value
        return ErrorContext(
            error,
            operation: operation,
            filePath: filePath,
            debugInfo: newDebugInfo,
            correlationId: correlationId
        )
    }
}

// MARK: - FormaError Context Extension

extension FormaError {
    /// Wrap this error with context for enhanced debugging
    func with(
        operation: String? = nil,
        filePath: String? = nil,
        debugInfo: [String: String] = [:]
    ) -> ErrorContext {
        ErrorContext(
            self,
            operation: operation,
            filePath: filePath,
            debugInfo: debugInfo
        )
    }
}
