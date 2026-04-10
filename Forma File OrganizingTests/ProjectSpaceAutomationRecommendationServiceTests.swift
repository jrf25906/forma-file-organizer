import XCTest
@testable import Forma_File_Organizing

@MainActor
final class ProjectSpaceAutomationRecommendationServiceTests: XCTestCase {
    func testRecommendationService_PrefersRepeatedWorkflowTemplateEvidence() throws {
        let now = Date(timeIntervalSince1970: 20_000)
        let detail = ProjectSpaceDetail(
            summary: ProjectSpaceSummary(
                normalizedLabel: "Alpha",
                fileCount: 1,
                lastActivityAt: now.addingTimeInterval(-300),
                sourceFolderHints: ["Inbox"]
            ),
            files: [
                ProjectSpaceFileRow(
                    canonicalIdentity: "alpha-1",
                    path: "/tmp/alpha/spec.md",
                    displayName: "spec.md",
                    lastActivityAt: now.addingTimeInterval(-300),
                    sourceFolderHint: "Inbox"
                )
            ],
            overview: ProjectSpaceOverview(
                currentFileCount: 1,
                activeFolderCount: 1,
                activeFolderHints: ["Inbox"],
                preferredDestinationCount: 2,
                recentActivityCount: 3,
                lastActivityAt: now.addingTimeInterval(-300)
            ),
            preferredDestinations: [
                ProjectSpacePreferredDestination(
                    destinationDisplayName: "Alpha",
                    eventCount: 4,
                    lastUsedAt: now.addingTimeInterval(-300)
                ),
                ProjectSpacePreferredDestination(
                    destinationDisplayName: "Reference",
                    eventCount: 1,
                    lastUsedAt: now.addingTimeInterval(-1_800)
                )
            ],
            recentActivity: [
                ProjectSpaceRecentActivityRow(
                    canonicalIdentity: "alpha-1",
                    fileDisplayName: "spec.md",
                    eventKind: .organized,
                    timestamp: now.addingTimeInterval(-300),
                    destinationDisplayName: "Alpha",
                    detailsSummary: "Moved into Alpha."
                ),
                ProjectSpaceRecentActivityRow(
                    canonicalIdentity: "alpha-2",
                    fileDisplayName: "notes.md",
                    eventKind: .rekeyed,
                    timestamp: now.addingTimeInterval(-900),
                    destinationDisplayName: "Alpha",
                    detailsSummary: "Updated destination."
                )
            ],
            workflowMemory: ProjectSpaceWorkflowMemoryProjection(
                state: .stable,
                successfulTemplateID: BuiltInWorkflowTemplate.StableID.receipts,
                successfulTemplateCount: 5,
                successfulTemplateLastSucceededAt: now.addingTimeInterval(-600),
                dominantTriggerKind: .scheduledSweep,
                summaryText: "Stable workflow memory."
            )
        )

        let recommendations = ProjectSpaceAutomationRecommendationService()
            .recommendedPolicies(for: detail, now: now)
        let recommendation = try XCTUnwrap(recommendations.first)

        XCTAssertEqual(recommendation.workflowTemplateID, BuiltInWorkflowTemplate.StableID.receipts)
        XCTAssertEqual(recommendation.triggerKinds, [.scheduledSweep])
        XCTAssertEqual(recommendation.admissionMode, .automatic)
        XCTAssertTrue(recommendation.reasonSummary.contains("Receipt Intake"))
        XCTAssertTrue(recommendation.reasonSummary.contains("5 successful runs"))
        XCTAssertTrue(recommendation.reasonSummary.contains("scheduled"))
        XCTAssertNotEqual(recommendation.workflowTemplateID, BuiltInWorkflowTemplate.StableID.projectDrop)
    }

    func testRecommendationService_DoesNotFallBackWhenWorkflowMemoryIsStale() {
        let now = Date(timeIntervalSince1970: 21_000)
        let detail = ProjectSpaceDetail(
            summary: ProjectSpaceSummary(
                normalizedLabel: "Alpha",
                fileCount: 1,
                lastActivityAt: now.addingTimeInterval(-300),
                sourceFolderHints: ["Inbox"]
            ),
            files: [
                ProjectSpaceFileRow(
                    canonicalIdentity: "alpha-1",
                    path: "/tmp/alpha/spec.md",
                    displayName: "spec.md",
                    lastActivityAt: now.addingTimeInterval(-300),
                    sourceFolderHint: "Inbox"
                )
            ],
            overview: ProjectSpaceOverview(
                currentFileCount: 1,
                activeFolderCount: 1,
                activeFolderHints: ["Inbox"],
                preferredDestinationCount: 2,
                recentActivityCount: 3,
                lastActivityAt: now.addingTimeInterval(-300)
            ),
            preferredDestinations: [
                ProjectSpacePreferredDestination(
                    destinationDisplayName: "Alpha",
                    eventCount: 4,
                    lastUsedAt: now.addingTimeInterval(-300)
                ),
                ProjectSpacePreferredDestination(
                    destinationDisplayName: "Reference",
                    eventCount: 1,
                    lastUsedAt: now.addingTimeInterval(-1_800)
                )
            ],
            recentActivity: [
                ProjectSpaceRecentActivityRow(
                    canonicalIdentity: "alpha-1",
                    fileDisplayName: "spec.md",
                    eventKind: .organized,
                    timestamp: now.addingTimeInterval(-300),
                    destinationDisplayName: "Alpha",
                    detailsSummary: "Moved into Alpha."
                ),
                ProjectSpaceRecentActivityRow(
                    canonicalIdentity: "alpha-2",
                    fileDisplayName: "notes.md",
                    eventKind: .rekeyed,
                    timestamp: now.addingTimeInterval(-900),
                    destinationDisplayName: "Alpha",
                    detailsSummary: "Updated destination."
                )
            ],
            workflowMemory: ProjectSpaceWorkflowMemoryProjection(
                state: .stale,
                successfulTemplateID: BuiltInWorkflowTemplate.StableID.receipts,
                successfulTemplateCount: 5,
                successfulTemplateLastSucceededAt: now.addingTimeInterval(-60 * 60 * 24 * 45),
                dominantTriggerKind: .scheduledSweep,
                summaryText: "Workflow memory is stale."
            )
        )

        let recommendations = ProjectSpaceAutomationRecommendationService()
            .recommendedPolicies(for: detail, now: now)

        XCTAssertTrue(recommendations.isEmpty)
    }
}
