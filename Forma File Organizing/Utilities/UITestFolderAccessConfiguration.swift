import Foundation

enum UITestFolderAccessConfiguration {
    static let accessibleFoldersEnvironmentKey = "FORMA_UI_TEST_ACCESSIBLE_FOLDERS"
    static let showOnboardingEnvironmentKey = "FORMA_UI_TEST_SHOW_ONBOARDING"

    static let defaultAccessibleFolderNames: Set<String> = [
        "desktop",
        "downloads"
    ]

    static var isEnabled: Bool {
        CommandLine.arguments.contains("--uitesting") ||
        CommandLine.arguments.contains("--perf-signpost-harness")
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
}
