import Foundation

enum PerformanceHarnessConfiguration {
    static let enableFlag = "--perf-signpost-harness"
    static let enableEnvironmentKey = "FORMA_PERF_SIGNPOST_HARNESS"
    static let warmupEnvironmentKey = "FORMA_PERF_HARNESS_WARMUP"
    static let iterationsEnvironmentKey = "FORMA_PERF_HARNESS_ITERATIONS"
    static let eventsFileEnvironmentKey = "FORMA_PERF_HARNESS_EVENTS_FILE"
    private static let warmupFlag = "--perf-harness-warmup"
    private static let iterationsFlag = "--perf-harness-iterations"
    private static let eventsFileFlag = "--perf-harness-events-file"

    static var isEnabled: Bool {
        isEnabled(
            arguments: CommandLine.arguments,
            environment: ProcessInfo.processInfo.environment
        )
    }

    static var warmupIterations: Int {
        warmupIterations(
            arguments: CommandLine.arguments,
            environment: ProcessInfo.processInfo.environment
        )
    }

    static var sampleIterations: Int {
        sampleIterations(
            arguments: CommandLine.arguments,
            environment: ProcessInfo.processInfo.environment
        )
    }

    static var eventsFilePath: String? {
        eventsFilePath(
            arguments: CommandLine.arguments,
            environment: ProcessInfo.processInfo.environment
        )
    }

    static func isEnabled(
        arguments: [String],
        environment: [String: String]
    ) -> Bool {
        arguments.contains(enableFlag) || environment[enableEnvironmentKey] == "1"
    }

    static func warmupIterations(
        arguments: [String],
        environment: [String: String]
    ) -> Int {
        intValue(
            for: warmupFlag,
            arguments: arguments,
            environmentKey: warmupEnvironmentKey,
            environment: environment,
            defaultValue: 3
        )
    }

    static func sampleIterations(
        arguments: [String],
        environment: [String: String]
    ) -> Int {
        intValue(
            for: iterationsFlag,
            arguments: arguments,
            environmentKey: iterationsEnvironmentKey,
            environment: environment,
            defaultValue: 24
        )
    }

    static func eventsFilePath(
        arguments: [String],
        environment: [String: String]
    ) -> String? {
        stringValue(for: eventsFileFlag, in: arguments) ??
        environment[eventsFileEnvironmentKey]
    }

    private static func intValue(
        for flag: String,
        arguments: [String],
        environmentKey: String,
        environment: [String: String],
        defaultValue: Int
    ) -> Int {
        if let rawValue = stringValue(for: flag, in: arguments) ?? environment[environmentKey],
           let parsed = Int(rawValue) {
            return parsed
        }

        return defaultValue
    }

    private static func stringValue(for flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1) else {
            return nil
        }

        return arguments[index + 1]
    }
}
