import Foundation

struct ProjectSpaceSummary: Identifiable, Hashable, Sendable {
    let normalizedLabel: String
    let fileCount: Int
    let lastActivityAt: Date

    var id: String { normalizedLabel }

    var displayName: String {
        normalizedLabel
    }
}

struct ProjectSpaceFileRow: Identifiable, Hashable, Sendable {
    let normalizedPath: String
    let displayName: String
    let lastActivityAt: Date

    var id: String { normalizedPath }
}

struct ProjectSpaceDetail: Identifiable, Hashable, Sendable {
    let summary: ProjectSpaceSummary
    let files: [ProjectSpaceFileRow]

    var id: String { summary.id }
}
