import Foundation

#if !DEBUG && UI_TESTS
#error("UI_TESTS must not be defined for Release app builds")
#endif

enum UITestFolderAccessConfiguration {
    static let accessibleFoldersEnvironmentKey = "FORMA_UI_TEST_ACCESSIBLE_FOLDERS"
    static let showOnboardingEnvironmentKey = "FORMA_UI_TEST_SHOW_ONBOARDING"

    #if DEBUG || UI_TESTS
    static let defaultAccessibleFolderNames: Set<String> = [
        "desktop",
        "downloads"
    ]

    static var isEnabled: Bool {
        isEnabled(arguments: CommandLine.arguments)
    }

    static func isEnabled(arguments: [String]) -> Bool {
        arguments.contains("--uitesting") ||
        arguments.contains("--perf-signpost-harness")
    }

    static func accessibleFolderNames(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Set<String> {
        guard let rawValue = environment[accessibleFoldersEnvironmentKey],
              !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return defaultAccessibleFolderNames
        }

        let parsed = Set(
            rawValue
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
        )

        return parsed.isEmpty ? defaultAccessibleFolderNames : parsed
    }
    #else
    static var isEnabled: Bool { false }

    static func isEnabled(arguments: [String] = []) -> Bool {
        false
    }

    static func accessibleFolderNames(
        environment: [String: String] = [:]
    ) -> Set<String> {
        []
    }
    #endif
}
