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
    let workflowStatusSummary: String?
    let tagsSummary: String
    let projectAssociationSummary: String
    let projectAssociationSourceSummary: String?
    let recentHistoryRows: [HistoryRow]

    var durableSummaryLines: [String] {
        [
            workflowStatusSummary,
            firstSeenSummary,
            lastOrganizedSummary,
            organizationCountSummary
        ].compactMap { $0 }
    }

    var durableTimingSummaryLines: [String] {
        [
            firstSeenSummary,
            lastOrganizedSummary,
            organizationCountSummary
        ]
    }

    var hasWorkflowStatusSummary: Bool {
        workflowStatusSummary != nil
    }

    var hasProjectAssociationSummary: Bool {
        !projectAssociationSummary.isEmpty
    }

    var hasProjectAssociationSourceSummary: Bool {
        projectAssociationSourceSummary != nil
    }

    var hasTagsSummary: Bool {
        !tagsSummary.isEmpty
    }

    var hasRecentHistoryRows: Bool {
        !recentHistoryRows.isEmpty
    }
}
