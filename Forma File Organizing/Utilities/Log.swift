import Foundation

/// Lightweight logging facade for the Forma app.
///
/// Goals:
/// - Centralize logging behavior and formatting.
/// - Allow verbose debug logging to be toggled via `FormaConfig.Performance.verboseLogging`.
/// - Avoid sprinkling raw `print` calls throughout the codebase.
///
/// Usage:
/// - `Log.debug("message", category: .filesystem)` for noisy debug logs.
/// - `Log.info("message", category: .security)` for high-level information.
/// - `Log.warning("message")` for non-fatal issues.
/// - `Log.error("message")` for errors.
///
/// In Release builds, only `.warning` and `.error` are emitted.
/// In Debug builds, `.debug` / `.info` respect `verboseLogging` when `verboseOnly == true`.
///
/// Thread Safety: All methods are nonisolated and safe to call from any actor or thread.
enum Log: Sendable {
    enum Level: String, Sendable {
        case debug
        case info
        case warning
        case error
    }

    enum Category: String, Sendable {
        case general
        case filesystem
        case fileOperations
        case bookmark
        case security
        case pipeline
        case undo
        case ui
        case analytics
        case automation
    }

    // MARK: - Public API

    // All methods are nonisolated for thread-safe logging from any context

    nonisolated static func debug(
        _ message: @autoclosure () -> String,
        category: Category = .general,
        verboseOnly: Bool = true,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .debug, message: message, category: category, verboseOnly: verboseOnly, file: file, function: function, line: line)
    }

    nonisolated static func info(
        _ message: @autoclosure () -> String,
        category: Category = .general,
        verboseOnly: Bool = true,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        log(level: .info, message: message, category: category, verboseOnly: verboseOnly, file: file, function: function, line: line)
    }

    nonisolated static func warning(
        _ message: @autoclosure () -> String,
        category: Category = .general,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        // Warnings are never "verbose only" - they should always be considered.
        log(level: .warning, message: message, category: category, verboseOnly: false, file: file, function: function, line: line)
    }

    nonisolated static func error(
        _ message: @autoclosure () -> String,
        category: Category = .general,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        // Errors are always logged when allowed by build configuration.
        log(level: .error, message: message, category: category, verboseOnly: false, file: file, function: function, line: line)
    }

    // MARK: - Internal

    /// Verbose logging config - captured at compile time to avoid actor isolation issues
    private nonisolated static var verboseLoggingEnabled: Bool {
        FormaConfig.Performance.verboseLogging
    }

    private nonisolated static func shouldLog(level: Level, verboseOnly: Bool) -> Bool {
        #if DEBUG
        if verboseOnly && !verboseLoggingEnabled {
            return false
        }
        return true
        #else
        // In Release, only warnings and errors are logged.
        switch level {
        case .warning, .error:
            return true
        case .debug, .info:
            return false
        }
        #endif
    }

    private nonisolated static func log(
        level: Level,
        message: () -> String,
        category: Category,
        verboseOnly: Bool,
        file: String,
        function: String,
        line: Int
    ) {
        guard shouldLog(level: level, verboseOnly: verboseOnly) else { return }

        let shortFile = file.components(separatedBy: "/").last ?? file
        let levelTag = level.rawValue.uppercased()
        let categoryTag = category.rawValue

        print("[\(levelTag)][\(categoryTag)] \(message()) - \(shortFile):\(line)")
    }
}
