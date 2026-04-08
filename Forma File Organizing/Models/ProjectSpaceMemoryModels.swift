import Foundation

struct ProjectSpaceOverview: Hashable, Sendable {
    let currentFileCount: Int
    let activeFolderCount: Int
    let activeFolderHints: [String]
    let preferredDestinationCount: Int
    let recentActivityCount: Int
    let lastActivityAt: Date?

    init(
        currentFileCount: Int = 0,
        activeFolderCount: Int = 0,
        activeFolderHints: [String] = [],
        preferredDestinationCount: Int = 0,
        recentActivityCount: Int = 0,
        lastActivityAt: Date? = nil
    ) {
        self.currentFileCount = currentFileCount
        self.activeFolderCount = activeFolderCount
        self.activeFolderHints = activeFolderHints
        self.preferredDestinationCount = preferredDestinationCount
        self.recentActivityCount = recentActivityCount
        self.lastActivityAt = lastActivityAt
    }
}

struct ProjectSpacePreferredDestination: Hashable, Sendable {
    let destinationDisplayName: String
    let eventCount: Int
    let lastUsedAt: Date
}

struct ProjectSpaceRecentActivityRow: Hashable, Sendable {
    let canonicalIdentity: String
    let fileDisplayName: String
    let eventKind: FileOrganizationHistoryEntry.EventKind
    let timestamp: Date
    let destinationDisplayName: String?
    let detailsSummary: String?
}

struct ProjectSpaceMemorySuggestion: Hashable, Sendable {
    let destinationDisplayName: String
    let destinationFolderPath: String?
    let confidence: Double
    let reasonSummary: String
    let lastUsedAt: Date
}
