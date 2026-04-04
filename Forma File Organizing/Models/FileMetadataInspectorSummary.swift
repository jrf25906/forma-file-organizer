import Foundation

struct FileMetadataInspectorSummary: Sendable, Equatable {
    struct HistoryRow: Identifiable, Sendable, Equatable {
        let id: UUID
        let timestampSummary: String
        let eventKind: String
        let sourceSurface: String
        let fromPath: String?
        let toPath: String?
        let destinationDisplayName: String?
        let matchedRuleID: UUID?
        let detailsSummary: String?
    }

    let firstSeenSummary: String
    let lastOrganizedSummary: String
    let organizationCountSummary: String
    let tagsSummary: String
    let projectAssociationSummary: String
    let recentHistoryRows: [HistoryRow]
}
