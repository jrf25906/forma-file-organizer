import XCTest
@testable import Forma_File_Organizing

@MainActor
final class ProjectSpaceSnapshotTests: XCTestCase {
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
}
