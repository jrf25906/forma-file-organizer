import XCTest
@testable import Forma_File_Organizing

@MainActor
final class ProjectSpaceSnapshotTests: XCTestCase {
    private func makeProjectSpaceDetail(now: Date = Date(timeIntervalSince1970: 1_710_000_000)) -> ProjectSpaceDetail {
        ProjectSpaceDetail(
            summary: ProjectSpaceSummary(
                projectLabel: "Alpha",
                fileCount: 2,
                lastActivityAt: now.addingTimeInterval(-3_600),
                sourceFolderHints: ["Desktop", "Projects"]
            ),
            files: [
                ProjectSpaceFileRow(
                    canonicalIdentity: "alpha-brief",
                    path: "/Users/test/Desktop/Alpha Brief.pdf",
                    displayName: "Alpha Brief.pdf",
                    fileExtension: "pdf",
                    lastActivityAt: now.addingTimeInterval(-1_800)
                ),
                ProjectSpaceFileRow(
                    canonicalIdentity: "alpha-notes",
                    path: "/Users/test/Projects/Alpha Notes.txt",
                    displayName: "Alpha Notes.txt",
                    fileExtension: "txt",
                    lastActivityAt: now.addingTimeInterval(-900),
                    workflowStatus: .organized,
                    tags: ["notes", "client"]
                )
            ]
        )
    }

    func testProjectSpaceCardSnapshot_IsNilWhenNoSummariesExist() {
        XCTAssertNil(ProjectSpacesSection.Snapshot(summaries: []))
    }

    func testProjectSpaceCardSnapshot_UsesLabelCountRecencyAndHints() throws {
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let summaries = [
            ProjectSpaceSummary(
                projectLabel: "Beta",
                fileCount: 2,
                lastActivityAt: now.addingTimeInterval(-21_600),
                sourceFolderHints: ["Downloads"]
            ),
            ProjectSpaceSummary(
                projectLabel: "Alpha",
                fileCount: 4,
                lastActivityAt: now.addingTimeInterval(-7_200),
                sourceFolderHints: ["Desktop", "Projects", "Archive"]
            )
        ]

        let snapshot = try XCTUnwrap(
            ProjectSpacesSection.Snapshot(
                summaries: summaries,
                now: now,
                recencyTextProvider: { _, _ in "2 hours ago" }
            )
        )

        XCTAssertEqual(snapshot.accessibilityIdentifier, "projectSpacesSection")
        XCTAssertEqual(snapshot.rows.map(\.title), ["Alpha", "Beta"])
        XCTAssertEqual(snapshot.rows.map(\.fileCountText), ["4 files", "2 files"])
        XCTAssertEqual(snapshot.rows.first?.recencyText, "2 hours ago")
        XCTAssertEqual(snapshot.rows.first?.sourceFolderSummary, "Desktop, Projects +1")
        XCTAssertEqual(snapshot.rows.first?.accessibilityIdentifier, "projectSpacesRow_Alpha")
    }

    func testProjectSpaceCardSnapshot_UsesExactLabelTieBreakWhenCaseInsensitiveLabelsMatch() throws {
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let summaries = [
            ProjectSpaceSummary(
                projectLabel: "alpha",
                fileCount: 2,
                lastActivityAt: now.addingTimeInterval(-3_600),
                sourceFolderHints: ["Desktop"]
            ),
            ProjectSpaceSummary(
                projectLabel: "Alpha",
                fileCount: 2,
                lastActivityAt: now.addingTimeInterval(-3_600),
                sourceFolderHints: ["Downloads"]
            )
        ]

        let snapshot = try XCTUnwrap(
            ProjectSpacesSection.Snapshot(
                summaries: summaries,
                now: now,
                recencyTextProvider: { _, _ in "1 hour ago" }
            )
        )

        XCTAssertEqual(snapshot.rows.map(\.title), ["Alpha", "alpha"])
    }

    func testProjectSpaceDetailSnapshot_UsesSummaryAndCurrentFiles() {
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let detail = ProjectSpaceDetail(
            summary: ProjectSpaceSummary(
                projectLabel: "Alpha",
                fileCount: 2,
                lastActivityAt: now.addingTimeInterval(-3_600),
                sourceFolderHints: ["Desktop", "Projects"]
            ),
            files: [
                ProjectSpaceFileRow(
                    canonicalIdentity: "alpha-brief",
                    path: "/Users/test/Desktop/Alpha Brief.pdf",
                    displayName: "Alpha Brief.pdf",
                    fileExtension: "pdf",
                    lastActivityAt: now.addingTimeInterval(-1_800)
                ),
                ProjectSpaceFileRow(
                    canonicalIdentity: "alpha-notes",
                    path: "/Users/test/Projects/Alpha Notes.txt",
                    displayName: "Alpha Notes.txt",
                    fileExtension: "txt",
                    lastActivityAt: now.addingTimeInterval(-900),
                    workflowStatus: .organized,
                    tags: ["notes", "client"]
                )
            ]
        )

        let snapshot = ProjectSpaceDetailView.Snapshot(
            detail: detail,
            now: now,
            recencyTextProvider: { _, _ in "1 hour ago" },
            fileRecencyTextProvider: { _, _ in "just now" }
        )

        XCTAssertEqual(snapshot.title, "Alpha")
        XCTAssertEqual(snapshot.fileCountText, "2 files")
        XCTAssertEqual(snapshot.recencyText, "1 hour ago")
        XCTAssertEqual(snapshot.sourceFolderSummary, "Desktop, Projects")
        XCTAssertEqual(snapshot.files.map(\.displayName), ["Alpha Notes.txt", "Alpha Brief.pdf"])
        XCTAssertEqual(snapshot.files.first?.statusText, "Organized")
        XCTAssertEqual(snapshot.files.first?.tagsText, "notes, client")
    }

    func testProjectSpaceDetailSnapshot_PreservesCanonicalIdentityTieBreakOrder() {
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let sharedActivityAt = now.addingTimeInterval(-900)
        let detail = ProjectSpaceDetail(
            summary: ProjectSpaceSummary(
                projectLabel: "Alpha",
                fileCount: 2,
                lastActivityAt: sharedActivityAt,
                sourceFolderHints: ["Desktop"]
            ),
            files: [
                ProjectSpaceFileRow(
                    canonicalIdentity: "identity-zeta",
                    path: "/Users/test/Desktop/Brief.pdf",
                    displayName: "Brief.pdf",
                    fileExtension: "pdf",
                    lastActivityAt: sharedActivityAt
                ),
                ProjectSpaceFileRow(
                    canonicalIdentity: "identity-alpha",
                    path: "/Users/test/Desktop/Brief.pdf",
                    displayName: "Brief.pdf",
                    fileExtension: "pdf",
                    lastActivityAt: sharedActivityAt
                )
            ]
        )

        let snapshot = ProjectSpaceDetailView.Snapshot(
            detail: detail,
            now: now,
            recencyTextProvider: { _, _ in "15 minutes ago" },
            fileRecencyTextProvider: { _, _ in "15 minutes ago" }
        )

        XCTAssertEqual(snapshot.files.map(\.fileRow.canonicalIdentity), ["identity-alpha", "identity-zeta"])
    }

    func testProjectSpaceDetailSnapshot_RemainsUsableAfterSourceDetailChanges() {
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        var detail = ProjectSpaceDetail(
            summary: ProjectSpaceSummary(
                projectLabel: "Alpha",
                fileCount: 1,
                lastActivityAt: now,
                sourceFolderHints: ["Desktop"]
            ),
            files: [
                ProjectSpaceFileRow(
                    canonicalIdentity: "alpha-plan",
                    path: "/Users/test/Desktop/Alpha Plan.md",
                    displayName: "Alpha Plan.md",
                    fileExtension: "md",
                    lastActivityAt: now
                )
            ]
        )

        let snapshot = ProjectSpaceDetailView.Snapshot(
            detail: detail,
            now: now,
            recencyTextProvider: { _, _ in "today" },
            fileRecencyTextProvider: { _, _ in "today" }
        )

        detail = ProjectSpaceDetail(
            summary: ProjectSpaceSummary(
                projectLabel: "Alpha",
                fileCount: 0,
                lastActivityAt: .distantPast,
                sourceFolderHints: []
            ),
            files: []
        )

        XCTAssertEqual(detail.files.count, 0)
        XCTAssertEqual(snapshot.title, "Alpha")
        XCTAssertEqual(snapshot.fileCountText, "1 file")
        XCTAssertEqual(snapshot.sourceFolderSummary, "Desktop")
        XCTAssertEqual(snapshot.files.map(\.displayName), ["Alpha Plan.md"])
    }

    func testProjectSpaceDetailSnapshot_ShowsOverviewPreferredDestinationsAndRecentActivity() {
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let detail = ProjectSpaceDetail(
            summary: ProjectSpaceSummary(
                projectLabel: "Alpha",
                fileCount: 2,
                lastActivityAt: now.addingTimeInterval(-3_600),
                sourceFolderHints: ["Desktop", "Projects"]
            ),
            files: [
                ProjectSpaceFileRow(
                    canonicalIdentity: "alpha-brief",
                    path: "/Users/test/Desktop/Alpha Brief.pdf",
                    displayName: "Alpha Brief.pdf",
                    fileExtension: "pdf",
                    lastActivityAt: now.addingTimeInterval(-1_800),
                    projectAssociation: "Alpha",
                    sourceFolderHint: "Desktop"
                )
            ],
            overview: ProjectSpaceOverview(
                currentFileCount: 2,
                activeFolderCount: 2,
                activeFolderHints: ["Desktop", "Projects"],
                preferredDestinationCount: 2,
                recentActivityCount: 3,
                lastActivityAt: now.addingTimeInterval(-1_200)
            ),
            preferredDestinations: [
                ProjectSpacePreferredDestination(
                    destinationDisplayName: "Clients/Alpha",
                    eventCount: 4,
                    lastUsedAt: now.addingTimeInterval(-7_200)
                ),
                ProjectSpacePreferredDestination(
                    destinationDisplayName: "Archive/Alpha",
                    eventCount: 1,
                    lastUsedAt: now.addingTimeInterval(-86_400)
                )
            ],
            recentActivity: [
                ProjectSpaceRecentActivityRow(
                    canonicalIdentity: "activity-1",
                    fileDisplayName: "Alpha Brief.pdf",
                    eventKind: .noted,
                    timestamp: now.addingTimeInterval(-300),
                    destinationDisplayName: "Desktop",
                    detailsSummary: "Corrected project association."
                ),
                ProjectSpaceRecentActivityRow(
                    canonicalIdentity: "activity-2",
                    fileDisplayName: "Alpha Plan.md",
                    eventKind: .organized,
                    timestamp: now.addingTimeInterval(-3_600),
                    destinationDisplayName: "Clients/Alpha",
                    detailsSummary: "Moved to client folder."
                )
            ]
        )

        let snapshot = ProjectSpaceDetailView.Snapshot(
            detail: detail,
            now: now,
            recencyTextProvider: { _, _ in "1 hour ago" },
            fileRecencyTextProvider: { _, _ in "30 minutes ago" },
            destinationRecencyTextProvider: { _, _ in "2 hours ago" },
            activityRecencyTextProvider: { _, _ in "5 minutes ago" }
        )

        XCTAssertEqual(snapshot.overviewTitle, "Overview")
        XCTAssertEqual(snapshot.overviewFileCountText, "2 current files")
        XCTAssertEqual(snapshot.overviewActiveFoldersText, "2 active folders")
        XCTAssertEqual(snapshot.overviewPreferredDestinationsText, "2 preferred destinations")
        XCTAssertEqual(snapshot.overviewRecentActivityText, "3 recent events")
        XCTAssertEqual(snapshot.overviewSourceFoldersText, "Desktop, Projects")
        XCTAssertEqual(snapshot.preferredDestinationsTitle, "Preferred Destinations")
        XCTAssertEqual(snapshot.preferredDestinations.map(\.destinationDisplayName), ["Clients/Alpha", "Archive/Alpha"])
        XCTAssertEqual(snapshot.preferredDestinations.map(\.eventCountText), ["4 moves", "1 move"])
        XCTAssertEqual(snapshot.preferredDestinations.first?.lastUsedText, "2 hours ago")
        XCTAssertEqual(snapshot.recentActivityTitle, "Recent Activity")
        XCTAssertEqual(snapshot.recentActivity.map(\.fileDisplayName), ["Alpha Brief.pdf", "Alpha Plan.md"])
        XCTAssertEqual(snapshot.recentActivity.map(\.eventSummaryText), ["Corrected project association.", "Moved to client folder."])
        XCTAssertEqual(snapshot.recentActivity.map(\.destinationText), ["Desktop", "Clients/Alpha"])
        XCTAssertEqual(snapshot.recentActivity.first?.timestampText, "5 minutes ago")
    }

    func testProjectSpaceDetailSnapshot_ShowsCorrectionAffordanceForFiles() {
        let now = Date(timeIntervalSince1970: 1_710_000_000)
        let detail = ProjectSpaceDetail(
            summary: ProjectSpaceSummary(
                projectLabel: "Alpha",
                fileCount: 1,
                lastActivityAt: now.addingTimeInterval(-3_600),
                sourceFolderHints: ["Downloads"]
            ),
            files: [
                ProjectSpaceFileRow(
                    canonicalIdentity: "alpha-brief",
                    path: "/Users/test/Downloads/Alpha Brief.pdf",
                    displayName: "Alpha Brief.pdf",
                    fileExtension: "pdf",
                    lastActivityAt: now.addingTimeInterval(-1_800),
                    workflowStatus: .organized,
                    tags: ["client"],
                    projectAssociation: "Alpha",
                    sourceFolderHint: "Downloads"
                )
            ]
        )

        let snapshot = ProjectSpaceDetailView.Snapshot(
            detail: detail,
            now: now,
            recencyTextProvider: { _, _ in "1 hour ago" },
            fileRecencyTextProvider: { _, _ in "30 minutes ago" }
        )

        let file = snapshot.files.first
        XCTAssertEqual(file?.projectAssociationText, "Alpha")
        XCTAssertEqual(file?.sourceFolderText, "Downloads")
        XCTAssertEqual(file?.correctionButtonTitle, "Correct Label")
    }

    func testProjectSpaceDetailSnapshot_ShowsWorkflowEmptyStateWhenNoTemplateSelected() {
        let snapshot = ProjectSpaceDetailView.Snapshot(
            detail: makeProjectSpaceDetail(),
            workflowSection: .init(
                sectionTitle: "Workflow",
                selectedTemplateText: "No workflow template selected",
                helperText: "Pick a built-in workflow template, preview it here, then run it manually for this project space.",
                previewText: nil,
                organizeButtonTitle: "Organize Project Space",
                isOrganizeButtonEnabled: false,
                disabledReasonText: "Choose a built-in workflow template to organize this project space.",
                latestRunSummaryText: nil
            )
        )

        XCTAssertEqual(snapshot.workflowSection?.sectionTitle, "Workflow")
        XCTAssertEqual(snapshot.workflowSection?.selectedTemplateText, "No workflow template selected")
        XCTAssertEqual(
            snapshot.workflowSection?.helperText,
            "Pick a built-in workflow template, preview it here, then run it manually for this project space."
        )
        XCTAssertEqual(snapshot.workflowSection?.organizeButtonTitle, "Organize Project Space")
        XCTAssertEqual(
            snapshot.workflowSection?.disabledReasonText,
            "Choose a built-in workflow template to organize this project space."
        )
        XCTAssertEqual(snapshot.workflowSection?.isOrganizeButtonEnabled, false)
    }

    func testProjectSpaceDetailSnapshot_ShowsWorkflowPreviewAndPrimaryAction() {
        let snapshot = ProjectSpaceDetailView.Snapshot(
            detail: makeProjectSpaceDetail(),
            workflowSection: .init(
                sectionTitle: "Workflow",
                selectedTemplateText: "Project Drop",
                helperText: "Run this workflow manually for the files currently reachable in this project space.",
                previewText: "2 selected, 1 ready to run, 1 blocked in simulation",
                organizeButtonTitle: "Organize Project Space",
                isOrganizeButtonEnabled: true,
                disabledReasonText: nil,
                latestRunSummaryText: nil
            )
        )

        XCTAssertEqual(snapshot.workflowSection?.selectedTemplateText, "Project Drop")
        XCTAssertEqual(
            snapshot.workflowSection?.previewText,
            "2 selected, 1 ready to run, 1 blocked in simulation"
        )
        XCTAssertNil(snapshot.workflowSection?.disabledReasonText)
        XCTAssertEqual(snapshot.workflowSection?.isOrganizeButtonEnabled, true)
    }

    func testProjectSpaceDetailSnapshot_ShowsWorkflowDisabledReasonWhenNoReachableFiles() {
        let snapshot = ProjectSpaceDetailView.Snapshot(
            detail: makeProjectSpaceDetail(),
            workflowSection: .init(
                sectionTitle: "Workflow",
                selectedTemplateText: "Receipts",
                helperText: "Run this workflow manually for the files currently reachable in this project space.",
                previewText: nil,
                organizeButtonTitle: "Organize Project Space",
                isOrganizeButtonEnabled: false,
                disabledReasonText: "No reachable files in this project space are available to organize.",
                latestRunSummaryText: nil
            )
        )

        XCTAssertEqual(snapshot.workflowSection?.selectedTemplateText, "Receipts")
        XCTAssertEqual(
            snapshot.workflowSection?.disabledReasonText,
            "No reachable files in this project space are available to organize."
        )
        XCTAssertEqual(snapshot.workflowSection?.isOrganizeButtonEnabled, false)
    }

    func testProjectSpaceDetailSnapshot_ShowsLatestWorkflowRunSummary() {
        let snapshot = ProjectSpaceDetailView.Snapshot(
            detail: makeProjectSpaceDetail(),
            workflowSection: .init(
                sectionTitle: "Workflow",
                selectedTemplateText: "Project Drop",
                helperText: "Run this workflow manually for the files currently reachable in this project space.",
                previewText: "2 selected, 2 ready to run",
                organizeButtonTitle: "Organize Project Space",
                isOrganizeButtonEnabled: true,
                disabledReasonText: nil,
                latestRunSummaryText: "Latest run: Project Drop succeeded 5 minutes ago."
            )
        )

        XCTAssertEqual(
            snapshot.workflowSection?.latestRunSummaryText,
            "Latest run: Project Drop succeeded 5 minutes ago."
        )
    }
}
