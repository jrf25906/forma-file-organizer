import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class ProjectSpaceMemoryResolverTests: XCTestCase {
    private let resolver = ProjectSpaceMemoryResolver()

    override func setUp() {
        super.setUp()
        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.autoProjectAssociation, true)
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)
        FeatureFlagService.shared.setEnabled(.projectSpaceMemory, true)
    }

    override func tearDown() {
        FeatureFlagService.shared.resetToDefaults()
        #if DEBUG
        FileMetadataFoundationService.debugProjectSpacePathReachabilityHook = nil
        FileMetadataFoundationService.debugProjectSpaceBookmarkRootLoadHook = nil
        #endif
        super.tearDown()
    }

    private func makeContext() throws -> (ModelContainer, ModelContext) {
        let schema = Schema([
            FileMetadataRecord.self,
            FileOrganizationHistoryEntry.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return (container, container.mainContext)
    }

    private func withContext(
        _ body: (_ container: ModelContainer, _ context: ModelContext) throws -> Void
    ) throws {
        let (container, context) = try makeContext()
        try withExtendedLifetime(container) {
            try body(container, context)
        }
    }

    private func makeRecord(
        in context: ModelContext,
        path: String,
        displayName: String,
        projectAssociation: String?
    ) -> FileMetadataRecord {
        let identity = FileMetadataRecord.Identity.pathFallback(path: path)
        let record = FileMetadataRecord(
            canonicalIdentity: identity.canonicalIdentity,
            identityKind: identity.kind,
            lastKnownPath: path,
            displayName: displayName,
            fileExtension: URL(fileURLWithPath: path).pathExtension,
            firstSeenAt: Date(timeIntervalSince1970: 100),
            lastSeenAt: Date(timeIntervalSince1970: 100)
        )
        record.projectAssociation = projectAssociation
        context.insert(record)
        return record
    }

    private func addHistory(
        in context: ModelContext,
        to record: FileMetadataRecord,
        eventKind: FileOrganizationHistoryEntry.EventKind,
        timestamp: Date,
        toPath: String? = nil,
        destinationDisplayName: String? = nil,
        detailsSummary: String? = nil
    ) {
        let entry = FileOrganizationHistoryEntry(
            timestamp: timestamp,
            metadataRecord: record,
            fileIdentitySnapshot: record.canonicalIdentity,
            eventKind: eventKind,
            sourceSurface: .review,
            fromPath: record.lastKnownPath,
            toPath: toPath,
            destinationDisplayName: destinationDisplayName,
            detailsSummary: detailsSummary
        )
        context.insert(entry)
        record.historyEntries.append(entry)
    }

    private func memberContext(for record: FileMetadataRecord) -> ProjectSpaceMemoryResolver.MemberContext {
        .init(record: record, normalizedPath: record.lastKnownPath)
    }

    func testBuildOverview_AggregatesPreferredDestinationsActiveFoldersAndRecentActivity() throws {
        try withContext { _, context in
            let tempDir = try TemporaryDirectory()
            let now = Date(timeIntervalSince1970: 1_000_000)
            let day: TimeInterval = 24 * 60 * 60

            let alphaFile = try tempDir.createFile(name: "Workspace/Alpha/Docs/report.txt", contents: "alpha")
            let betaFile = try tempDir.createFile(name: "Workspace/Alpha/Reference/spec.md", contents: "beta")
            let gammaFile = try tempDir.createFile(name: "Workspace/Alpha/Notes/notes.md", contents: "gamma")

            let alpha = makeRecord(
                in: context,
                path: alphaFile.path,
                displayName: "report.txt",
                projectAssociation: "Alpha"
            )
            let beta = makeRecord(
                in: context,
                path: betaFile.path,
                displayName: "spec.md",
                projectAssociation: "Alpha"
            )
            let gamma = makeRecord(
                in: context,
                path: gammaFile.path,
                displayName: "notes.md",
                projectAssociation: "Alpha"
            )

            addHistory(
                in: context,
                to: alpha,
                eventKind: .organized,
                timestamp: now.addingTimeInterval(-6 * day),
                toPath: "/tmp/Alpha Archive/report.txt",
                destinationDisplayName: "Alpha Archive",
                detailsSummary: "Moved into the archive."
            )
            addHistory(
                in: context,
                to: alpha,
                eventKind: .rekeyed,
                timestamp: now.addingTimeInterval(-5 * day),
                toPath: "/tmp/Alpha Archive/report-v2.txt",
                destinationDisplayName: "Alpha Archive",
                detailsSummary: "Retargeted to the archive."
            )
            addHistory(
                in: context,
                to: alpha,
                eventKind: .organized,
                timestamp: now.addingTimeInterval(-4 * day),
                toPath: "/tmp/Alpha Archive/report-v3.txt",
                destinationDisplayName: "Alpha Archive",
                detailsSummary: "Moved again to the archive."
            )
            addHistory(
                in: context,
                to: alpha,
                eventKind: .rekeyed,
                timestamp: now.addingTimeInterval(-3 * day),
                toPath: "/tmp/Alpha Archive/report-v4.txt",
                destinationDisplayName: "Alpha Archive",
                detailsSummary: "Retargeted again to the archive."
            )
            addHistory(
                in: context,
                to: alpha,
                eventKind: .undone,
                timestamp: now.addingTimeInterval(-2 * day),
                detailsSummary: "Reverted once."
            )
            addHistory(
                in: context,
                to: alpha,
                eventKind: .ignored,
                timestamp: now.addingTimeInterval(-1 * day),
                detailsSummary: "Ignored during review."
            )
            addHistory(
                in: context,
                to: alpha,
                eventKind: .noted,
                timestamp: now.addingTimeInterval(-12 * 60 * 60),
                detailsSummary: "Keep in mind for later."
            )
            addHistory(
                in: context,
                to: alpha,
                eventKind: .scanned,
                timestamp: now.addingTimeInterval(-6 * 60 * 60),
                detailsSummary: "Scan only, should not surface."
            )

            addHistory(
                in: context,
                to: beta,
                eventKind: .organized,
                timestamp: now.addingTimeInterval(-2 * 60 * 60),
                toPath: "/tmp/Beta Vault/spec.md",
                destinationDisplayName: "Beta Vault",
                detailsSummary: "Moved to Beta Vault."
            )

            addHistory(
                in: context,
                to: gamma,
                eventKind: .rekeyed,
                timestamp: now.addingTimeInterval(-1 * 60 * 60),
                toPath: "/tmp/Gamma Vault/notes.md",
                destinationDisplayName: nil,
                detailsSummary: "Rekeyed to the active folder."
            )

            try context.save()

            let memberContexts = [alpha, beta, gamma].map { memberContext(for: $0) }

            let overview = resolver.buildOverview(for: memberContexts, now: now)
            let preferredDestinations = resolver.buildPreferredDestinations(for: memberContexts, now: now)
            let recentActivityRows = resolver.buildRecentActivityRows(for: memberContexts)
            let suggestion = resolver.suggestDominantDestination(for: memberContexts, now: now)

            XCTAssertEqual(overview.currentFileCount, 3)
            XCTAssertEqual(overview.activeFolderCount, 3)
            XCTAssertEqual(overview.activeFolderHints, ["Docs", "Notes", "Reference"])
            XCTAssertEqual(overview.preferredDestinationCount, 3)
            XCTAssertEqual(overview.recentActivityCount, 9)
            XCTAssertEqual(overview.lastActivityAt, now.addingTimeInterval(-1 * 60 * 60))

            XCTAssertEqual(preferredDestinations.map(\.destinationDisplayName), ["Alpha Archive", "Gamma Vault", "Beta Vault"])
            XCTAssertEqual(preferredDestinations.map(\.eventCount), [4, 1, 1])
            XCTAssertEqual(preferredDestinations[0].lastUsedAt, now.addingTimeInterval(-3 * day))
            XCTAssertEqual(preferredDestinations[1].lastUsedAt, now.addingTimeInterval(-1 * 60 * 60))
            XCTAssertEqual(preferredDestinations[2].lastUsedAt, now.addingTimeInterval(-2 * 60 * 60))

            XCTAssertEqual(
                recentActivityRows.map(\.eventKind),
                [.rekeyed, .organized, .noted, .ignored, .undone, .rekeyed, .organized, .rekeyed, .organized]
            )
            XCTAssertEqual(
                recentActivityRows.map(\.canonicalIdentity),
                [gamma.canonicalIdentity, beta.canonicalIdentity, alpha.canonicalIdentity, alpha.canonicalIdentity, alpha.canonicalIdentity, alpha.canonicalIdentity, alpha.canonicalIdentity, alpha.canonicalIdentity, alpha.canonicalIdentity]
            )
            XCTAssertEqual(recentActivityRows.first?.destinationDisplayName, "Gamma Vault")
            XCTAssertEqual(recentActivityRows.last?.detailsSummary, "Moved into the archive.")

            XCTAssertEqual(suggestion?.destinationDisplayName, "Alpha Archive")
            XCTAssertEqual(suggestion?.destinationFolderPath, "/tmp/Alpha Archive")
            XCTAssertEqual(suggestion?.confidence, 2.0 / 3.0)
            XCTAssertEqual(suggestion?.reasonSummary, "Most recent project activity favored Alpha Archive in 4 of 6 moves.")
            XCTAssertEqual(suggestion?.lastUsedAt, now.addingTimeInterval(-3 * day))
        }
    }

    func testBuildOverview_ExcludesUnresolvableOrNonProjectRecords() throws {
        try withContext { _, context in
            let tempDir = try TemporaryDirectory()
            let validFile = try tempDir.createFile(name: "Workspace/Alpha/Docs/valid.txt", contents: "valid")
            let deletedFile = try tempDir.createFile(name: "Workspace/Beta/Docs/deleted.txt", contents: "deleted")
            try FileManager.default.removeItem(at: deletedFile)

            let valid = makeRecord(
                in: context,
                path: validFile.path,
                displayName: "valid.txt",
                projectAssociation: "Alpha"
            )
            let nonProject = makeRecord(
                in: context,
                path: tempDir.url(for: "Workspace/Alpha/Docs/non-project.txt").path,
                displayName: "non-project.txt",
                projectAssociation: nil
            )
            let unresolvable = makeRecord(
                in: context,
                path: deletedFile.path,
                displayName: "deleted.txt",
                projectAssociation: "Beta"
            )

            addHistory(
                in: context,
                to: valid,
                eventKind: .organized,
                timestamp: Date(timeIntervalSince1970: 300),
                toPath: "/tmp/Alpha Archive/valid.txt",
                destinationDisplayName: "Alpha Archive",
                detailsSummary: "Valid project activity."
            )
            addHistory(
                in: context,
                to: nonProject,
                eventKind: .rekeyed,
                timestamp: Date(timeIntervalSince1970: 600),
                toPath: "/tmp/Should Not Count/non-project.txt",
                destinationDisplayName: "Should Not Count",
                detailsSummary: "Should be ignored because it is not a project record."
            )
            addHistory(
                in: context,
                to: unresolvable,
                eventKind: .ignored,
                timestamp: Date(timeIntervalSince1970: 900),
                detailsSummary: "Should be ignored because the file cannot be resolved."
            )

            try context.save()

            let memberContexts = [valid, nonProject, unresolvable].map { memberContext(for: $0) }

            let overview = resolver.buildOverview(for: memberContexts, now: Date(timeIntervalSince1970: 1_000))
            let preferredDestinations = resolver.buildPreferredDestinations(for: memberContexts, now: Date(timeIntervalSince1970: 1_000))
            let recentActivityRows = resolver.buildRecentActivityRows(for: memberContexts)

            XCTAssertEqual(overview.currentFileCount, 1)
            XCTAssertEqual(overview.activeFolderCount, 1)
            XCTAssertEqual(overview.activeFolderHints, ["Docs"])
            XCTAssertEqual(overview.preferredDestinationCount, 1)
            XCTAssertEqual(overview.recentActivityCount, 1)
            XCTAssertEqual(overview.lastActivityAt, Date(timeIntervalSince1970: 300))

            XCTAssertEqual(preferredDestinations.map(\.destinationDisplayName), ["Alpha Archive"])
            XCTAssertEqual(preferredDestinations.map(\.eventCount), [1])

            XCTAssertEqual(recentActivityRows.count, 1)
            XCTAssertEqual(recentActivityRows.first?.canonicalIdentity, valid.canonicalIdentity)
            XCTAssertEqual(recentActivityRows.first?.eventKind, .organized)
            XCTAssertEqual(recentActivityRows.first?.destinationDisplayName, "Alpha Archive")
        }
    }

    func testSuggestion_ReturnsNilWhenNoDominantDestinationExists() throws {
        try withContext { _, context in
            let tempDir = try TemporaryDirectory()
            let firstFile = try tempDir.createFile(name: "Workspace/Alpha/Docs/first.txt", contents: "first")
            let secondFile = try tempDir.createFile(name: "Workspace/Alpha/Reference/second.txt", contents: "second")

            let first = makeRecord(
                in: context,
                path: firstFile.path,
                displayName: "first.txt",
                projectAssociation: "Alpha"
            )
            let second = makeRecord(
                in: context,
                path: secondFile.path,
                displayName: "second.txt",
                projectAssociation: "Alpha"
            )

            addHistory(
                in: context,
                to: first,
                eventKind: .organized,
                timestamp: Date(timeIntervalSince1970: 100),
                toPath: "/tmp/Alpha Archive/first.txt",
                destinationDisplayName: "Alpha Archive"
            )
            addHistory(
                in: context,
                to: first,
                eventKind: .rekeyed,
                timestamp: Date(timeIntervalSince1970: 200),
                toPath: "/tmp/Alpha Archive/first-v2.txt",
                destinationDisplayName: "Alpha Archive"
            )
            addHistory(
                in: context,
                to: first,
                eventKind: .organized,
                timestamp: Date(timeIntervalSince1970: 300),
                toPath: "/tmp/Alpha Archive/first-v3.txt",
                destinationDisplayName: "Alpha Archive"
            )

            addHistory(
                in: context,
                to: second,
                eventKind: .organized,
                timestamp: Date(timeIntervalSince1970: 400),
                toPath: "/tmp/Beta Vault/second.txt",
                destinationDisplayName: "Beta Vault"
            )
            addHistory(
                in: context,
                to: second,
                eventKind: .rekeyed,
                timestamp: Date(timeIntervalSince1970: 500),
                toPath: "/tmp/Beta Vault/second-v2.txt",
                destinationDisplayName: "Beta Vault"
            )

            try context.save()

            let memberContexts = [first, second].map { memberContext(for: $0) }
            let suggestion = resolver.suggestDominantDestination(
                for: memberContexts,
                now: Date(timeIntervalSince1970: 1_000_000)
            )

            XCTAssertNil(suggestion)
        }
    }

    func testBuildOverview_UsesBookmarkAwareReachabilityForResolvedMembers() throws {
        try withContext { _, context in
            let tempDir = try TemporaryDirectory()
            let fileURL = tempDir.url.appendingPathComponent("Downloads/bookmark-backed.txt")
            let bookmarkStore = InMemoryBookmarkStore()
            let destination = try Destination.folder(
                from: tempDir.url,
                displayName: BookmarkFolder.FolderType.downloads.displayName
            )
            try bookmarkStore.saveBookmark(
                try XCTUnwrap(destination.bookmarkData),
                forKey: BookmarkFolder.FolderType.downloads.bookmarkKey
            )

            try BookmarkStoreProvider.$override.withValue(bookmarkStore) {
                #if DEBUG
                FileMetadataFoundationService.debugProjectSpacePathReachabilityHook = { path, usingSecurityScopedAccess in
                    guard path == fileURL.path else { return nil }
                    return usingSecurityScopedAccess
                }
                defer {
                    FileMetadataFoundationService.debugProjectSpacePathReachabilityHook = nil
                }
                #endif

                let record = makeRecord(
                    in: context,
                    path: fileURL.path,
                    displayName: fileURL.lastPathComponent,
                    projectAssociation: "Alpha"
                )
                try context.save()

                let overview = resolver.buildOverview(
                    for: [record].map { memberContext(for: $0) },
                    now: Date(timeIntervalSince1970: 1_000)
                )

                XCTAssertEqual(overview.currentFileCount, 1)
                XCTAssertEqual(overview.activeFolderHints, ["Downloads"])
            }
        }
    }

    func testBuildPreferredDestinations_DistinguishesSameLabelDifferentPaths() throws {
        try withContext { _, context in
            let tempDir = try TemporaryDirectory()
            let alphaURL = try tempDir.createFile(name: "Project/alpha.txt", contents: "alpha")
            let betaURL = try tempDir.createFile(name: "Project/beta.txt", contents: "beta")

            let alpha = makeRecord(
                in: context,
                path: alphaURL.path,
                displayName: alphaURL.lastPathComponent,
                projectAssociation: "Alpha"
            )
            let beta = makeRecord(
                in: context,
                path: betaURL.path,
                displayName: betaURL.lastPathComponent,
                projectAssociation: "Alpha"
            )

            addHistory(
                in: context,
                to: alpha,
                eventKind: .organized,
                timestamp: Date(timeIntervalSince1970: 100),
                toPath: "/tmp/Team One/Shared/report.txt",
                destinationDisplayName: "Shared"
            )
            addHistory(
                in: context,
                to: alpha,
                eventKind: .rekeyed,
                timestamp: Date(timeIntervalSince1970: 200),
                toPath: "/tmp/Team One/Shared/report-2.txt",
                destinationDisplayName: "Shared"
            )
            addHistory(
                in: context,
                to: alpha,
                eventKind: .organized,
                timestamp: Date(timeIntervalSince1970: 300),
                toPath: "/tmp/Team One/Shared/report-3.txt",
                destinationDisplayName: "Shared"
            )
            addHistory(
                in: context,
                to: beta,
                eventKind: .organized,
                timestamp: Date(timeIntervalSince1970: 400),
                toPath: "/tmp/Team Two/Shared/report.txt",
                destinationDisplayName: "Shared"
            )

            try context.save()

            let memberContexts = [alpha, beta].map { memberContext(for: $0) }
            let preferredDestinations = resolver.buildPreferredDestinations(for: memberContexts, now: Date(timeIntervalSince1970: 1_000))
            let suggestion = resolver.suggestDominantDestination(for: memberContexts, now: Date(timeIntervalSince1970: 1_000))

            XCTAssertEqual(preferredDestinations.count, 2)
            XCTAssertEqual(preferredDestinations.map(\.eventCount), [3, 1])
            XCTAssertEqual(preferredDestinations.map(\.destinationDisplayName), ["Shared", "Shared"])
            XCTAssertEqual(suggestion?.destinationFolderPath, "/tmp/Team One/Shared")
            XCTAssertEqual(suggestion?.destinationDisplayName, "Shared")
        }
    }

    func testResolveDestination_ReturnsBookmarkBackedDestinationForReachablePath() throws {
        let tempDir = try TemporaryDirectory()
        let destinationFolderURL = try tempDir.createDirectory(name: "Workspace/Alpha Archive")
        let suggestion = ProjectSpaceMemorySuggestion(
            destinationDisplayName: "Alpha Archive",
            destinationFolderPath: destinationFolderURL.path,
            confidence: 0.82,
            reasonSummary: "Dominant project activity.",
            lastUsedAt: Date(timeIntervalSince1970: 1_000)
        )

        let destination = resolver.resolveDestination(for: suggestion)

        XCTAssertEqual(destination?.displayName, "Alpha Archive")
        XCTAssertNotNil(destination?.bookmarkData)
        XCTAssertEqual(destination?.resolve()?.url.standardizedFileURL.path, destinationFolderURL.standardizedFileURL.path)
    }

    func testResolveDestination_ReturnsNilForUnresolvablePath() {
        let suggestion = ProjectSpaceMemorySuggestion(
            destinationDisplayName: "Missing",
            destinationFolderPath: "/tmp/forma-tests-\(UUID().uuidString)/does-not-exist",
            confidence: 0.9,
            reasonSummary: "Dominant project activity.",
            lastUsedAt: Date(timeIntervalSince1970: 2_000)
        )

        XCTAssertNil(resolver.resolveDestination(for: suggestion))
    }

    func testMemoryResolver_FallsBackToDestinationDominanceWhenWorkflowMemoryMissing() throws {
        let now = Date(timeIntervalSince1970: 30_000)
        let detail = ProjectSpaceDetail(
            summary: ProjectSpaceSummary(
                normalizedLabel: "Alpha",
                fileCount: 1,
                lastActivityAt: now.addingTimeInterval(-200),
                sourceFolderHints: ["Inbox"]
            ),
            files: [
                ProjectSpaceFileRow(
                    canonicalIdentity: "alpha-1",
                    path: "/tmp/alpha/brief.md",
                    displayName: "brief.md",
                    lastActivityAt: now.addingTimeInterval(-200),
                    sourceFolderHint: "Inbox"
                )
            ],
            overview: ProjectSpaceOverview(
                currentFileCount: 1,
                activeFolderCount: 1,
                activeFolderHints: ["Inbox"],
                preferredDestinationCount: 2,
                recentActivityCount: 2,
                lastActivityAt: now.addingTimeInterval(-200)
            ),
            preferredDestinations: [
                ProjectSpacePreferredDestination(
                    destinationDisplayName: "Alpha",
                    eventCount: 3,
                    lastUsedAt: now.addingTimeInterval(-200)
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
                    fileDisplayName: "brief.md",
                    eventKind: .organized,
                    timestamp: now.addingTimeInterval(-200),
                    destinationDisplayName: "Alpha",
                    detailsSummary: "Moved into Alpha."
                ),
                ProjectSpaceRecentActivityRow(
                    canonicalIdentity: "alpha-2",
                    fileDisplayName: "outline.md",
                    eventKind: .rekeyed,
                    timestamp: now.addingTimeInterval(-800),
                    destinationDisplayName: "Alpha",
                    detailsSummary: "Retargeted into Alpha."
                )
            ]
        )

        let projection = resolver.resolveWorkflowMemoryProjection(
            for: detail,
            profile: nil,
            now: now
        )

        XCTAssertEqual(projection?.state, .destinationFallback)
        XCTAssertNil(projection?.successfulTemplateID)
        XCTAssertNil(projection?.dominantTriggerKind)
        XCTAssertTrue(projection?.summaryText.localizedCaseInsensitiveContains("fall back") == true)
        XCTAssertTrue(projection?.summaryText.contains("Alpha") == true)
    }
}
