import XCTest
@testable import Forma_File_Organizing

@MainActor
final class TrustedAutomationScopeSnapshotTests: XCTestCase {
    func testSmartFeaturesSection_KeepsManagementVisibleWhenScopesExistAndAutomationTogglesAreOff() {
        let scopeSections = [
            TrustedAutomationScopeSummarySection(
                status: .paused,
                title: "Paused",
                summaries: [
                    TrustedAutomationScopeSummary(
                        id: UUID(),
                        scopeType: .folder,
                        displayName: "Exports",
                        boundarySummary: "Exports -> Documents/Exports",
                        allowedActions: [.move],
                        lifecycle: TrustedAutomationScopeLifecycleSummary(
                            status: .paused,
                            createdAt: Date(timeIntervalSince1970: 100),
                            updatedAt: Date(timeIntervalSince1970: 200),
                            lastEvidenceAt: Date(timeIntervalSince1970: 150),
                            pausedAt: Date(timeIntervalSince1970: 200),
                            lastRunAt: nil,
                            revokedAt: nil
                        ),
                        health: TrustedAutomationScopeHealthSummary(
                            state: .quiet,
                            messages: [],
                            lastSuccessfulRunAt: nil,
                            lastBlockedRunAt: nil
                        ),
                        lastRun: nil
                    )
                ]
            )
        ]

        XCTAssertTrue(
            SmartFeaturesSection.shouldShowTrustedAutomationScopeManagement(
                masterAIEnabled: false,
                backgroundMonitoring: false,
                autoOrganize: false,
                scopeSections: scopeSections
            )
        )
    }

    func testTrustedAutomationScopesSection_ShowsAttentionStateAndRecentRunSummary() throws {
        let now = Date(timeIntervalSince1970: 2_000)
        let summary = TrustedAutomationScopeSummary(
            id: UUID(),
            scopeType: .folder,
            displayName: "Exports",
            boundarySummary: "Exports -> Documents/Exports",
            allowedActions: [.move, .notify],
            lifecycle: TrustedAutomationScopeLifecycleSummary(
                status: .active,
                createdAt: Date(timeIntervalSince1970: 1_000),
                updatedAt: Date(timeIntervalSince1970: 1_950),
                lastEvidenceAt: Date(timeIntervalSince1970: 1_900),
                pausedAt: nil,
                lastRunAt: Date(timeIntervalSince1970: 1_950),
                revokedAt: nil
            ),
            health: TrustedAutomationScopeHealthSummary(
                state: .needsAttention,
                messages: ["2 file(s) were held in a recent run."],
                lastSuccessfulRunAt: Date(timeIntervalSince1970: 1_850),
                lastBlockedRunAt: Date(timeIntervalSince1970: 1_950)
            ),
            lastRun: TrustedAutomationScopeRecentRunSummary(
                id: UUID(),
                triggerSource: .realtimeAutomationPass,
                status: .held,
                startedAt: Date(timeIntervalSince1970: 1_940),
                endedAt: Date(timeIntervalSince1970: 1_950),
                matchedCount: 4,
                eligibleCount: 4,
                organizedCount: 2,
                heldCount: 2,
                failedCount: 0,
                heldBuckets: [.init(bucket: "Needs Review", count: 2)],
                summaryText: "Held 2 files for review.",
                exampleFileNames: ["Invoice-1.pdf", "Invoice-2.pdf"]
            )
        )

        let snapshot = try XCTUnwrap(
            TrustedAutomationScopesSection.Snapshot(
                title: "Autopilot scopes",
                sections: [
                    TrustedAutomationScopeSummarySection(
                        status: .active,
                        title: "Active",
                        summaries: [summary]
                    )
                ],
                style: .compact,
                now: now,
                relativeDateProvider: { _, _ in "1 minute ago" }
            )
        )

        XCTAssertEqual(snapshot.title, "Autopilot scopes")
        XCTAssertEqual(snapshot.sections.map(\.title), ["Active"])
        XCTAssertEqual(snapshot.rows.map(\.title), ["Exports"])
        XCTAssertEqual(snapshot.rows.first?.scopeTypeText, "Folder")
        XCTAssertEqual(snapshot.rows.first?.boundarySummary, "Exports")
        XCTAssertEqual(snapshot.rows.first?.destinationSummary, "Documents/Exports")
        XCTAssertEqual(snapshot.rows.first?.statusText, "Active")
        XCTAssertEqual(snapshot.rows.first?.healthBadgeText, "Needs Attention")
        XCTAssertEqual(snapshot.rows.first?.healthMessage, "2 file(s) were held in a recent run.")
        XCTAssertEqual(snapshot.rows.first?.lastRunText, "Last run 1 minute ago")
        XCTAssertEqual(snapshot.rows.first?.recentActivityText, "Held 2 files for review.")
    }

    func testRecommendationSheet_ShowsBoundaryPreviewAndImmediatePreflightSummary() throws {
        let destination = Destination.mockFolder("Documents/Exports")
        let recommendation = TrustedAutomationScopeRecommendation(
            recommendedScope: TrustedAutomationScopeRecommendationOption(
                scopeType: .folder,
                scopeKey: "/Users/example/Downloads/Exports",
                displayName: "Exports",
                recommendationSource: .repeatedReviewAcceptance,
                acceptedEvidenceCount: 6,
                overrideEvidenceCount: 0,
                undoEvidenceCount: 0,
                confidenceSnapshot: 0.94,
                rationaleSummary: "You’ve approved this folder pattern 6 times with no recent undo in Exports."
            ),
            alternativeScopes: [
                TrustedAutomationScopeRecommendationOption(
                    scopeType: .category,
                    scopeKey: "documents|/Users/example/Downloads/Exports|Documents/Exports",
                    displayName: "Documents",
                    recommendationSource: .personalMemoryPattern,
                    acceptedEvidenceCount: 6,
                    overrideEvidenceCount: 1,
                    undoEvidenceCount: 0,
                    confidenceSnapshot: 0.88,
                    rationaleSummary: "You often send document files from this folder to the same destination."
                )
            ],
            snapshot: OrganizationMemorySnapshot(
                fileName: "Quarterly Report.csv",
                fileExtension: "csv",
                fileTypeCategory: .documents,
                sourceLocation: .downloads,
                scanRootPath: "/Users/example/Downloads",
                relativeParentPath: "Exports",
                suggestionSource: .personalMemory,
                suggestedDestination: destination,
                chosenDestination: destination,
                confidenceScore: 0.94,
                matchedRuleID: nil
            )
        )

        let snapshot = TrustedAutomationScopeRecommendationSheet.Snapshot(
            recommendation: recommendation,
            selectedScopeType: .folder,
            previewSummary: TrustedAutomationScopeRecommendationPreviewSummary(
                matchedCount: 3,
                eligibleCount: 2,
                skippedMissingDestinationCount: 0,
                skippedPermissionIssueCount: 0,
                skippedConfidenceThresholdCount: 1,
                exampleFileNames: ["Quarterly Report.csv", "Quarterly Summary.csv"]
            )
        )

        XCTAssertEqual(snapshot.recommendedBadgeText, "Recommended")
        XCTAssertEqual(snapshot.selectedScopeTitle, "Folder")
        XCTAssertEqual(snapshot.selectedScopeDisplayName, "Exports")
        XCTAssertEqual(snapshot.sourceBoundaryTitle, "Source boundary")
        XCTAssertEqual(snapshot.sourceBoundarySummary, "Downloads > Exports")
        XCTAssertEqual(snapshot.destinationTitle, "Trusted destination")
        XCTAssertEqual(snapshot.destinationSummary, "Documents/Exports")
        XCTAssertEqual(
            snapshot.automaticBehaviorSummary,
            "Files from this folder can move automatically to Documents/Exports."
        )
        XCTAssertEqual(
            snapshot.preflightSummary,
            "3 current matches. 2 would move automatically on the first pass, and 1 would stay in review."
        )
        XCTAssertEqual(snapshot.alternativeScopeTitles, ["Category"])
    }

    func testTrustedAutomationScopeDetailSheet_ShowsNoPreflightYetWhenHistoryOnlyHasExecutedRuns() {
        let detail = TrustedAutomationScopeDetail(
            id: UUID(),
            summary: TrustedAutomationScopeSummary(
                id: UUID(),
                scopeType: .folder,
                displayName: "Exports",
                boundarySummary: "Exports -> Documents/Exports",
                allowedActions: [.move],
                lifecycle: TrustedAutomationScopeLifecycleSummary(
                    status: .active,
                    createdAt: Date(timeIntervalSince1970: 100),
                    updatedAt: Date(timeIntervalSince1970: 250),
                    lastEvidenceAt: Date(timeIntervalSince1970: 200),
                    pausedAt: nil,
                    lastRunAt: Date(timeIntervalSince1970: 250),
                    revokedAt: nil
                ),
                health: TrustedAutomationScopeHealthSummary(
                    state: .healthy,
                    messages: [],
                    lastSuccessfulRunAt: Date(timeIntervalSince1970: 250),
                    lastBlockedRunAt: nil
                ),
                lastRun: nil
            ),
            boundaryDescriptor: .folder(
                source: .init(
                    sourceLocation: .downloads,
                    scanRootPath: "/Users/example/Downloads",
                    relativeParentPath: "Exports"
                ),
                destination: .init(.mockFolder("Documents/Exports"))
            ),
            promotionSource: .reviewFlow,
            recommendationSource: .repeatedReviewAcceptance,
            acceptedEvidenceCount: 6,
            overrideEvidenceCount: 0,
            undoEvidenceCount: 0,
            confidenceSnapshot: 0.94,
            rationaleSummary: "You’ve approved this folder pattern 6 times with no recent undo in Exports.",
            recentRuns: [
                TrustedAutomationScopeRecentRunSummary(
                    id: UUID(),
                    triggerSource: .scheduledAutomationPass,
                    status: .executed,
                    startedAt: Date(timeIntervalSince1970: 240),
                    endedAt: Date(timeIntervalSince1970: 250),
                    matchedCount: 4,
                    eligibleCount: 4,
                    organizedCount: 4,
                    heldCount: 0,
                    failedCount: 0,
                    heldBuckets: [],
                    summaryText: "Executed 4 matching files.",
                    exampleFileNames: ["Quarterly Report.csv"]
                )
            ]
        )

        let snapshot = TrustedAutomationScopeDetailSheet.Snapshot(
            detail: detail,
            now: Date(timeIntervalSince1970: 300),
            relativeDateProvider: { _, _ in "just now" }
        )

        XCTAssertEqual(snapshot.latestPreflightSummary, "No scope-specific preflight has run yet.")
        XCTAssertEqual(snapshot.recentRuns.first?.statusText, "Executed")
        XCTAssertEqual(snapshot.recentRuns.first?.summaryText, "Executed 4 matching files.")
    }
}
