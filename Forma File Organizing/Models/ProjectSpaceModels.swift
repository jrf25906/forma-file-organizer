import Foundation

struct ProjectSpaceSummary: Identifiable, Hashable, Sendable {
    let projectLabel: String
    let fileCount: Int
    let lastActivityAt: Date
    let sourceFolderHints: [String]

    var id: String { projectLabel }

    var normalizedLabel: String { projectLabel }

    var displayName: String {
        projectLabel
    }

    init(
        projectLabel: String,
        fileCount: Int,
        lastActivityAt: Date = .distantPast,
        sourceFolderHints: [String] = []
    ) {
        self.projectLabel = projectLabel
        self.fileCount = fileCount
        self.lastActivityAt = lastActivityAt
        self.sourceFolderHints = sourceFolderHints
    }

    init(
        normalizedLabel: String,
        fileCount: Int,
        lastActivityAt: Date = .distantPast,
        sourceFolderHints: [String] = []
    ) {
        self.init(
            projectLabel: normalizedLabel,
            fileCount: fileCount,
            lastActivityAt: lastActivityAt,
            sourceFolderHints: sourceFolderHints
        )
    }
}

struct ProjectSpaceFileRow: Identifiable, Hashable, Sendable {
    let canonicalIdentity: String
    let path: String
    let displayName: String
    let fileExtension: String
    let lastActivityAt: Date
    let workflowStatus: MetadataWorkflowStatus?
    let tags: [String]

    var id: String { canonicalIdentity }

    var normalizedPath: String { path }

    init(
        canonicalIdentity: String,
        path: String,
        displayName: String,
        fileExtension: String = "",
        lastActivityAt: Date = .distantPast,
        workflowStatus: MetadataWorkflowStatus? = nil,
        tags: [String] = []
    ) {
        self.canonicalIdentity = canonicalIdentity
        self.path = path
        self.displayName = displayName
        self.fileExtension = fileExtension
        self.lastActivityAt = lastActivityAt
        self.workflowStatus = workflowStatus
        self.tags = tags
    }
}

struct ProjectSpaceDetail: Identifiable, Hashable, Sendable {
    let summary: ProjectSpaceSummary
    let files: [ProjectSpaceFileRow]

    var id: String { summary.id }

    var projectLabel: String { summary.projectLabel }

    var fileCount: Int { summary.fileCount }

    var sourceFolderHints: [String] { summary.sourceFolderHints }

    var lastActivityAt: Date { summary.lastActivityAt }
}
