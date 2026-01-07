import Foundation
import os

/// Centralized performance monitoring utility using OSSignpost for Instruments integration.
///
/// ## Usage
///
/// ### Basic Timing (synchronous)
/// ```swift
/// PerformanceMonitor.shared.begin(.fileScan)
/// // ... do work ...
/// PerformanceMonitor.shared.end(.fileScan)
/// ```
///
/// ### Async Timing with Scope
/// ```swift
/// await PerformanceMonitor.shared.measure(.fileScan) {
///     await expensiveOperation()
/// }
/// ```
///
/// ### Per-Item Tracking
/// ```swift
/// let id = PerformanceMonitor.shared.beginItem(.fileHash, metadata: "photo.jpg")
/// // ... hash file ...
/// PerformanceMonitor.shared.endItem(.fileHash, id: id)
/// ```
///
/// ## Viewing Results
/// 1. Run app with Instruments attached
/// 2. Select "os_signpost" instrument
/// 3. Filter by "com.forma.performance" subsystem
///
final class PerformanceMonitor: @unchecked Sendable {

    // MARK: - Singleton

    static let shared = PerformanceMonitor()

    // MARK: - Operation Types

    /// Categories of operations to measure
    enum Operation: String, CaseIterable {
        case fileScan = "FileScan"
        case ruleEvaluation = "RuleEvaluation"
        case patternDetection = "PatternDetection"
        case clusterDetection = "ClusterDetection"
        case insightGeneration = "InsightGeneration"
        case fileHash = "FileHash"
        case mlPrediction = "MLPrediction"
        case duplicateDetection = "DuplicateDetection"
        case learningService = "LearningService"
        case uiUpdate = "UIUpdate"

        var category: String {
            switch self {
            case .fileScan, .ruleEvaluation, .patternDetection:
                return "pipeline"
            case .clusterDetection, .insightGeneration, .learningService:
                return "ai-services"
            case .fileHash, .duplicateDetection:
                return "io"
            case .mlPrediction:
                return "ml"
            case .uiUpdate:
                return "ui"
            }
        }
    }

    // MARK: - Properties

    private let subsystem = "com.forma.performance"

    /// Main signpost log for all operations
    private let signpostLog: OSLog

    /// Statistics tracking (thread-safe)
    private let statsLock = NSLock()
    private var operationStats: [Operation: OperationStats] = [:]

    /// Console logging enabled (useful for debugging without Instruments)
    var consoleLoggingEnabled: Bool = false

    /// Active signpost IDs for tracking nested/concurrent operations
    private var activeSignposts: [Operation: [OSSignpostID]] = [:]
    private let signpostLock = NSLock()

    // MARK: - Initialization

    private init() {
        signpostLog = OSLog(subsystem: subsystem, category: "timing")

        // Initialize stats for all operations
        for op in Operation.allCases {
            operationStats[op] = OperationStats()
        }
    }

    // MARK: - Basic Begin/End API

    /// Begin timing an operation
    /// - Parameter operation: The operation type to measure
    /// - Returns: A signpost ID for matching with end()
    @discardableResult
    func begin(_ operation: Operation, metadata: String? = nil) -> OSSignpostID {
        let signpostID = OSSignpostID(log: signpostLog)

        signpostLock.lock()
        activeSignposts[operation, default: []].append(signpostID)
        signpostLock.unlock()

        // Use static name "Timing" with operation type in format string
        // os_signpost requires StaticString for name parameter
        let opName = operation.rawValue
        if let metadata = metadata {
            os_signpost(.begin, log: signpostLog, name: "Timing", signpostID: signpostID, "[%{public}s] %{public}s", opName, metadata)
        } else {
            os_signpost(.begin, log: signpostLog, name: "Timing", signpostID: signpostID, "[%{public}s]", opName)
        }

        if consoleLoggingEnabled {
            let metaStr = metadata.map { " (\($0))" } ?? ""
            print("[PERF] BEGIN \(operation.rawValue)\(metaStr)")
        }

        // Track start time for stats
        statsLock.lock()
        operationStats[operation]?.recordStart(id: signpostID)
        statsLock.unlock()

        return signpostID
    }

    /// End timing an operation
    /// - Parameters:
    ///   - operation: The operation type that was measured
    ///   - id: Optional signpost ID (uses most recent if not provided)
    ///   - metadata: Optional completion metadata
    func end(_ operation: Operation, id: OSSignpostID? = nil, metadata: String? = nil) {
        signpostLock.lock()
        let signpostID: OSSignpostID
        if let providedID = id {
            signpostID = providedID
            activeSignposts[operation]?.removeAll { $0 == providedID }
        } else {
            signpostID = activeSignposts[operation]?.popLast() ?? OSSignpostID(log: signpostLog)
        }
        signpostLock.unlock()

        // Use static name "Timing" with operation type in format string
        let opName = operation.rawValue
        if let metadata = metadata {
            os_signpost(.end, log: signpostLog, name: "Timing", signpostID: signpostID, "[%{public}s] %{public}s", opName, metadata)
        } else {
            os_signpost(.end, log: signpostLog, name: "Timing", signpostID: signpostID, "[%{public}s]", opName)
        }

        // Record stats
        statsLock.lock()
        if let duration = operationStats[operation]?.recordEnd(id: signpostID) {
            if consoleLoggingEnabled {
                let metaStr = metadata.map { " (\($0))" } ?? ""
                print("[PERF] END \(operation.rawValue)\(metaStr) - \(String(format: "%.2f", duration * 1000))ms")
            }
        }
        statsLock.unlock()
    }

    // MARK: - Scoped Measurement API

    /// Measure a synchronous operation with automatic begin/end
    /// - Parameters:
    ///   - operation: The operation type to measure
    ///   - metadata: Optional metadata string
    ///   - work: The work to measure
    /// - Returns: The result of the work closure
    func measure<T>(_ operation: Operation, metadata: String? = nil, work: () throws -> T) rethrows -> T {
        let id = begin(operation, metadata: metadata)
        defer { end(operation, id: id) }
        return try work()
    }

    /// Measure an async operation with automatic begin/end
    /// - Parameters:
    ///   - operation: The operation type to measure
    ///   - metadata: Optional metadata string
    ///   - work: The async work to measure
    /// - Returns: The result of the work closure
    func measure<T>(_ operation: Operation, metadata: String? = nil, work: () async throws -> T) async rethrows -> T {
        let id = begin(operation, metadata: metadata)
        defer { end(operation, id: id) }
        return try await work()
    }

    // MARK: - Event Logging

    /// Log a single event (no duration)
    /// - Parameters:
    ///   - operation: The operation category
    ///   - message: Event message
    func event(_ operation: Operation, message: String) {
        os_signpost(.event, log: signpostLog, name: "Event", "[%{public}s] %{public}s", operation.rawValue, message)

        if consoleLoggingEnabled {
            print("[PERF] EVENT \(operation.rawValue): \(message)")
        }
    }

    // MARK: - Statistics

    /// Get statistics for an operation
    func stats(for operation: Operation) -> OperationStats? {
        statsLock.lock()
        defer { statsLock.unlock() }
        return operationStats[operation]
    }

    /// Get summary of all operations
    func summary() -> String {
        statsLock.lock()
        defer { statsLock.unlock() }

        var lines: [String] = ["=== Performance Summary ==="]

        for operation in Operation.allCases {
            guard let stats = operationStats[operation], stats.count > 0 else { continue }

            lines.append(String(format: "%@: count=%d, avg=%.2fms, total=%.2fms",
                               operation.rawValue,
                               stats.count,
                               stats.averageDuration * 1000,
                               stats.totalDuration * 1000))
        }

        return lines.joined(separator: "\n")
    }

    /// Reset all statistics
    func resetStats() {
        statsLock.lock()
        for op in Operation.allCases {
            operationStats[op] = OperationStats()
        }
        statsLock.unlock()
    }

    /// Print summary to console
    func printSummary() {
        print(summary())
    }
}

// MARK: - Statistics Tracking

/// Statistics for a single operation type
final class OperationStats: @unchecked Sendable {
    private(set) var count: Int = 0
    private(set) var totalDuration: TimeInterval = 0
    private(set) var minDuration: TimeInterval = .infinity
    private(set) var maxDuration: TimeInterval = 0

    // OSSignpostID isn't Hashable, so we use its rawValue (UInt64) as the key
    private var startTimes: [UInt64: Date] = [:]

    var averageDuration: TimeInterval {
        count > 0 ? totalDuration / Double(count) : 0
    }

    func recordStart(id: OSSignpostID) {
        startTimes[id.rawValue] = Date()
    }

    @discardableResult
    func recordEnd(id: OSSignpostID) -> TimeInterval? {
        guard let startTime = startTimes.removeValue(forKey: id.rawValue) else { return nil }

        let duration = Date().timeIntervalSince(startTime)
        count += 1
        totalDuration += duration
        minDuration = min(minDuration, duration)
        maxDuration = max(maxDuration, duration)

        return duration
    }
}

// MARK: - Convenience Extensions

extension PerformanceMonitor {
    /// Quick access for common operations
    static func beginFileScan(metadata: String? = nil) -> OSSignpostID {
        shared.begin(.fileScan, metadata: metadata)
    }

    static func endFileScan(id: OSSignpostID? = nil, fileCount: Int? = nil) {
        let metadata = fileCount.map { "\($0) files" }
        shared.end(.fileScan, id: id, metadata: metadata)
    }
}
