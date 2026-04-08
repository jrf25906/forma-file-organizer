import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class FileMetadataFoundationServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        FeatureFlagService.shared.resetToDefaults()
        FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
        FeatureFlagService.shared.setEnabled(.autoContentTags, true)
        FeatureFlagService.shared.setEnabled(.autoProjectAssociation, true)
    }

    override func tearDown() {
        FeatureFlagService.shared.resetToDefaults()
        #if DEBUG
        FileMetadataFoundationService.debugProjectSpacePathReachabilityHook = nil
        FileMetadataFoundationService.debugProjectSpaceBookmarkRootLoadHook = nil
        #endif
        super.tearDown()
    }

    private func makeService() throws -> (ModelContainer, ModelContext, FileMetadataFoundationService) {
        let schema = Schema([
            FileMetadataRecord.self,
            FileOrganizationHistoryEntry.self,
            ProjectCluster.self,
            Rule.self,
            RuleCategory.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        return (container, context, FileMetadataFoundationService(modelContext: context))
    }

    private func withService(
        _ body: (_ context: ModelContext, _ service: FileMetadataFoundationService) throws -> Void
    ) throws {
        let (container, context, service) = try makeService()
        try withExtendedLifetime(container) {
            try body(context, service)
        }
    }

    private func insertProjectCluster(
        in context: ModelContext,
        filePath: String,
        suggestedFolderName: String,
        confidenceScore: Double
    ) throws -> ProjectCluster {
        let cluster = ProjectCluster(
            clusterType: .nameSimilarity,
            filePaths: [filePath],
            confidenceScore: confidenceScore,
            suggestedFolderName: suggestedFolderName
        )
        context.insert(cluster)
        try context.save()
        return cluster
    }

    private func insertRule(
        in context: ModelContext,
        categoryName: String? = nil,
        destinationDisplayName: String? = nil
    ) throws -> Rule {
        let category = categoryName.map { name in
            RuleCategory(name: name)
        }

        if let category {
            context.insert(category)
        }

        let destination: Destination?
        if let destinationDisplayName {
            destination = .folder(bookmark: Data(), displayName: destinationDisplayName)
        } else {
            destination = nil
        }

        let rule = Rule(
            name: "Tagging Rule",
            conditionType: .fileExtension,
            conditionValue: "pdf",
            actionType: .move,
            destination: destination,
            category: category
        )
        context.insert(rule)
        try context.save()
        return rule
    }

    func testProjectSpaceSummaries_GroupByAssociationAndSortByRecentActivity() throws {
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)

        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let alphaOlderURL = try tempDir.createFile(name: "Inbox/alpha-older.txt", contents: "alpha")
            let alphaNewerURL = try tempDir.createFile(name: "Inbox/alpha-newer.txt", contents: "alpha")
            let betaURL = try tempDir.createFile(name: "Inbox/beta.txt", contents: "beta")

            let alphaOlder = try XCTUnwrap(
                service.upsertRecord(
                    for: alphaOlderURL.path,
                    displayName: "alpha-older.txt",
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 1_000)
                )
            )
            alphaOlder.projectAssociation = "Alpha"
            alphaOlder.lastSeenAt = Date(timeIntervalSince1970: 1_500)

            let alphaNewer = try XCTUnwrap(
                service.upsertRecord(
                    for: alphaNewerURL.path,
                    displayName: "alpha-newer.txt",
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 2_000)
                )
            )
            alphaNewer.projectAssociation = "Alpha"
            alphaNewer.lastSeenAt = Date(timeIntervalSince1970: 3_000)

            let beta = try XCTUnwrap(
                service.upsertRecord(
                    for: betaURL.path,
                    displayName: "beta.txt",
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 2_500)
                )
            )
            beta.projectAssociation = "Beta"
            beta.lastSeenAt = Date(timeIntervalSince1970: 2_700)

            try context.save()

            let summaries = service.fetchProjectSpaceSummaries()

            XCTAssertEqual(summaries.count, 2)
            XCTAssertEqual(summaries.first?.normalizedLabel, "Alpha")
            XCTAssertEqual(summaries.first?.fileCount, 2)
            XCTAssertEqual(summaries.first?.lastActivityAt, Date(timeIntervalSince1970: 3_000))
            XCTAssertEqual(summaries.last?.normalizedLabel, "Beta")
            XCTAssertEqual(summaries.last?.fileCount, 1)
            XCTAssertEqual(summaries.last?.lastActivityAt, Date(timeIntervalSince1970: 2_700))
        }
    }

    func testProjectSpaceSummaries_SortByFileCountThenLabelWhenRecencyMatches() throws {
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)

        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let alphaOneURL = try tempDir.createFile(name: "Inbox/alpha-1.txt", contents: "alpha")
            let alphaTwoURL = try tempDir.createFile(name: "Inbox/alpha-2.txt", contents: "alpha")
            let betaURL = try tempDir.createFile(name: "Inbox/beta.txt", contents: "beta")
            let gammaURL = try tempDir.createFile(name: "Inbox/gamma.txt", contents: "gamma")
            let sharedTimestamp = Date(timeIntervalSince1970: 3_000)

            for (url, label) in [
                (alphaOneURL, "Alpha"),
                (alphaTwoURL, "Alpha"),
                (betaURL, "Beta"),
                (gammaURL, "Gamma")
            ] {
                let record = try XCTUnwrap(
                    service.upsertRecord(
                        for: url.path,
                        displayName: url.lastPathComponent,
                        fileExtension: "txt",
                        timestamp: sharedTimestamp
                    )
                )
                record.projectAssociation = label
                record.lastSeenAt = sharedTimestamp
            }

            try context.save()

            let summaries = service.fetchProjectSpaceSummaries()

            XCTAssertEqual(summaries.map(\.normalizedLabel), ["Alpha", "Beta", "Gamma"])
            XCTAssertEqual(summaries.map(\.fileCount), [2, 1, 1])
            XCTAssertTrue(summaries.allSatisfy { $0.lastActivityAt == sharedTimestamp })
        }
    }

    func testProjectSpaceSummaries_UseExactLabelTieBreakWhenCaseInsensitiveLabelsMatch() throws {
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)

        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let lowercaseURL = try tempDir.createFile(name: "Inbox/lowercase.txt", contents: "alpha")
            let uppercaseURL = try tempDir.createFile(name: "Inbox/uppercase.txt", contents: "alpha")
            let sharedTimestamp = Date(timeIntervalSince1970: 3_000)

            let lowercaseRecord = try XCTUnwrap(
                service.upsertRecord(
                    for: lowercaseURL.path,
                    displayName: lowercaseURL.lastPathComponent,
                    fileExtension: "txt",
                    timestamp: sharedTimestamp
                )
            )
            lowercaseRecord.projectAssociation = "alpha"
            lowercaseRecord.lastSeenAt = sharedTimestamp

            let uppercaseRecord = try XCTUnwrap(
                service.upsertRecord(
                    for: uppercaseURL.path,
                    displayName: uppercaseURL.lastPathComponent,
                    fileExtension: "txt",
                    timestamp: sharedTimestamp
                )
            )
            uppercaseRecord.projectAssociation = "Alpha"
            uppercaseRecord.lastSeenAt = sharedTimestamp

            try context.save()

            let summaries = service.fetchProjectSpaceSummaries()

            XCTAssertEqual(summaries.map(\.normalizedLabel), ["Alpha", "alpha"])
        }
    }

    func testProjectSpaceSummaries_ExcludeUnlabeledRecords() throws {
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)

        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let labeledURL = try tempDir.createFile(name: "Inbox/labeled.txt", contents: "alpha")
            let unlabeledURL = try tempDir.createFile(name: "Inbox/unlabeled.txt", contents: "beta")

            let labeled = try XCTUnwrap(
                service.upsertRecord(
                    for: labeledURL.path,
                    displayName: labeledURL.lastPathComponent,
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 1_000)
                )
            )
            labeled.projectAssociation = "Alpha"

            let unlabeled = try XCTUnwrap(
                service.upsertRecord(
                    for: unlabeledURL.path,
                    displayName: unlabeledURL.lastPathComponent,
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 2_000)
                )
            )
            unlabeled.projectAssociation = "   "

            try context.save()

            let summaries = service.fetchProjectSpaceSummaries()

            XCTAssertEqual(summaries.map(\.normalizedLabel), ["Alpha"])
            XCTAssertEqual(summaries.first?.fileCount, 1)
        }
    }

    func testProjectSpaceSummaries_ExcludeUnresolvableRecords() throws {
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)

        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let resolvableURL = try tempDir.createFile(name: "Inbox/resolvable.txt", contents: "alpha")
            let staleURL = try tempDir.createFile(name: "Inbox/stale.txt", contents: "beta")

            let resolvable = try XCTUnwrap(
                service.upsertRecord(
                    for: resolvableURL.path,
                    displayName: resolvableURL.lastPathComponent,
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 1_000)
                )
            )
            resolvable.projectAssociation = "Alpha"

            let stale = try XCTUnwrap(
                service.upsertRecord(
                    for: staleURL.path,
                    displayName: staleURL.lastPathComponent,
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 2_000)
                )
            )
            stale.projectAssociation = "Alpha"
            try FileManager.default.removeItem(at: staleURL)

            try context.save()

            let summaries = service.fetchProjectSpaceSummaries()

            XCTAssertEqual(summaries.count, 1)
            XCTAssertEqual(summaries.first?.normalizedLabel, "Alpha")
            XCTAssertEqual(summaries.first?.fileCount, 1)
        }
    }

    func testProjectSpaceSummaries_UseBoundedSourceFolderHints() throws {
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)

        try withService { _, service in
            let syntheticHome = "/Users/project-space-tests"
            let projectsAliasName = "ProjectsZZ"

            let hints = service.projectSpaceSourceFolderHints(
                for: [
                    "\(syntheticHome)/Desktop/alpha-1.txt",
                    "\(syntheticHome)/Desktop/alpha-2.txt",
                    "\(syntheticHome)/Downloads/beta-1.txt",
                    "\(syntheticHome)/Downloads/beta-2.txt",
                    "\(syntheticHome)/\(projectsAliasName)/gamma-1.txt",
                    "\(syntheticHome)/\(projectsAliasName)/gamma-2.txt",
                    "\(syntheticHome)/Documents/notes.txt"
                ],
                homePath: syntheticHome
            )

            XCTAssertEqual(hints, ["Desktop", "Downloads", projectsAliasName])
        }
    }

    func testProjectSpaceSourceFolderHintRoot_UsesStandardFolderDisplayNameHelper() throws {
        try withService { _, service in
            XCTAssertEqual(service.projectSpaceStandardFolderDisplayName(for: "Desktop"), "Desktop")
            XCTAssertEqual(service.projectSpaceStandardFolderDisplayName(for: "Downloads"), "Downloads")
            XCTAssertNil(service.projectSpaceStandardFolderDisplayName(for: "Projects"))

            XCTAssertEqual(
                service.projectSpaceSourceFolderHintRoot(
                    for: "/Users/project-space-tests/Desktop/file.txt",
                    homePath: "/Users/project-space-tests"
                ),
                "Desktop"
            )

            XCTAssertEqual(
                service.projectSpaceSourceFolderHintRoot(for: "/Volumes/External Drive/project/file.txt"),
                "External Drive"
            )

            XCTAssertEqual(
                service.projectSpaceSourceFolderHintRoot(for: "/opt/shared/project/file.txt"),
                "opt"
            )
        }
    }

    func testProjectSpaceSourceFolderHintRoot_UsesRealHomePathWithoutOverride() throws {
        try withService { _, service in
            let path = BookmarkFolder.FolderType.desktop
                .standardRootPath()
                .appending("/file.txt")

            XCTAssertEqual(
                service.projectSpaceSourceFolderHintRoot(for: path),
                BookmarkFolder.FolderType.desktop.displayName
            )
        }
    }

    func testProjectSpaceSummaries_IncludeBookmarkBackedResolvableRecords() throws {
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)

        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let fileURL = try tempDir.createFile(name: "Downloads/bookmark-backed.txt", contents: "alpha")
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

                let record = try XCTUnwrap(
                    service.upsertRecord(
                        for: fileURL.path,
                        displayName: fileURL.lastPathComponent,
                        fileExtension: "txt",
                        timestamp: Date(timeIntervalSince1970: 1_000)
                    )
                )
                record.projectAssociation = "Alpha"
                try context.save()

                let summaries = service.fetchProjectSpaceSummaries()
                XCTAssertEqual(summaries.map(\.normalizedLabel), ["Alpha"])
                XCTAssertEqual(summaries.first?.fileCount, 1)
            }
        }
    }

    func testProjectSpaceSummaries_IncludeDisabledStandardBookmarkBackedRecords() throws {
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)

        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let fileURL = try tempDir.createFile(name: "Downloads/disabled-standard.txt", contents: "alpha")
            let bookmarkStore = InMemoryBookmarkStore()
            let destination = try Destination.folder(
                from: tempDir.url,
                displayName: BookmarkFolder.FolderType.downloads.displayName
            )
            try bookmarkStore.saveBookmark(
                try XCTUnwrap(destination.bookmarkData),
                forKey: BookmarkFolder.FolderType.downloads.bookmarkKey
            )

            let enabledDefaultsKey = "BookmarkFolder.isEnabled.\(BookmarkFolder.FolderType.downloads.bookmarkKey)"
            let previousEnabledValue = UserDefaults.standard.object(forKey: enabledDefaultsKey)
            UserDefaults.standard.set(false, forKey: enabledDefaultsKey)
            defer {
                if let previousEnabledValue {
                    UserDefaults.standard.set(previousEnabledValue, forKey: enabledDefaultsKey)
                } else {
                    UserDefaults.standard.removeObject(forKey: enabledDefaultsKey)
                }
            }

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

                let record = try XCTUnwrap(
                    service.upsertRecord(
                        for: fileURL.path,
                        displayName: fileURL.lastPathComponent,
                        fileExtension: "txt",
                        timestamp: Date(timeIntervalSince1970: 1_000)
                    )
                )
                record.projectAssociation = "Alpha"
                try context.save()

                let summaries = service.fetchProjectSpaceSummaries()
                XCTAssertEqual(summaries.map(\.normalizedLabel), ["Alpha"])
                XCTAssertEqual(summaries.first?.fileCount, 1)
            }
        }
    }

    func testProjectSpaceSummaries_IncludeCustomBookmarkBackedRecords() throws {
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)

        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let customRootURL = try tempDir.createDirectory(name: "CustomRoot")
            let fileURL = try tempDir.createFile(name: "CustomRoot/custom-bookmark.txt", contents: "alpha")
            let bookmarkStore = InMemoryBookmarkStore()
            let destination = try Destination.folder(
                from: customRootURL,
                displayName: "Custom Root"
            )
            try bookmarkStore.saveBookmark(
                try XCTUnwrap(destination.bookmarkData),
                forKey: "CustomFolder_ProjectSpaceTests"
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

                let record = try XCTUnwrap(
                    service.upsertRecord(
                        for: fileURL.path,
                        displayName: fileURL.lastPathComponent,
                        fileExtension: "txt",
                        timestamp: Date(timeIntervalSince1970: 1_000)
                    )
                )
                record.projectAssociation = "Alpha"
                try context.save()

                let summaries = service.fetchProjectSpaceSummaries()
                XCTAssertEqual(summaries.map(\.normalizedLabel), ["Alpha"])
                XCTAssertEqual(summaries.first?.fileCount, 1)
            }
        }
    }

    func testProjectSpaceSummaries_LoadBookmarkBackedRootsOncePerFetch() throws {
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)

        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let firstURL = try tempDir.createFile(name: "Downloads/first.txt", contents: "alpha")
            let secondURL = try tempDir.createFile(name: "Downloads/second.txt", contents: "beta")
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
                var bookmarkRootLoadCount = 0
                FileMetadataFoundationService.debugProjectSpaceBookmarkRootLoadHook = {
                    bookmarkRootLoadCount += 1
                }
                FileMetadataFoundationService.debugProjectSpacePathReachabilityHook = { path, usingSecurityScopedAccess in
                    guard path == firstURL.path || path == secondURL.path else { return nil }
                    return usingSecurityScopedAccess
                }
                defer {
                    FileMetadataFoundationService.debugProjectSpaceBookmarkRootLoadHook = nil
                    FileMetadataFoundationService.debugProjectSpacePathReachabilityHook = nil
                }
                #endif

                for fileURL in [firstURL, secondURL] {
                    let record = try XCTUnwrap(
                        service.upsertRecord(
                            for: fileURL.path,
                            displayName: fileURL.lastPathComponent,
                            fileExtension: "txt",
                            timestamp: Date(timeIntervalSince1970: 1_000)
                        )
                    )
                    record.projectAssociation = "Alpha"
                }
                try context.save()

                _ = service.fetchProjectSpaceSummaries()

                #if DEBUG
                XCTAssertEqual(bookmarkRootLoadCount, 1)
                #endif
            }
        }
    }

    func testProjectSpaceDetail_ReturnsOnlyMatchingResolvableFiles() throws {
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)

        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let alphaURL = try tempDir.createFile(name: "Inbox/alpha.txt", contents: "alpha")
            let spacedAlphaURL = try tempDir.createFile(name: "Inbox/spaced-alpha.txt", contents: "alpha")
            let lowercaseAlphaURL = try tempDir.createFile(name: "Inbox/lowercase-alpha.txt", contents: "alpha")
            let betaURL = try tempDir.createFile(name: "Inbox/beta.txt", contents: "beta")
            let staleURL = try tempDir.createFile(name: "Inbox/stale.txt", contents: "stale")

            let alpha = try XCTUnwrap(
                service.upsertRecord(
                    for: alphaURL.path,
                    displayName: alphaURL.lastPathComponent,
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 1_000)
                )
            )
            alpha.projectAssociation = "Alpha"

            let spacedAlpha = try XCTUnwrap(
                service.upsertRecord(
                    for: spacedAlphaURL.path,
                    displayName: spacedAlphaURL.lastPathComponent,
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 2_000)
                )
            )
            spacedAlpha.projectAssociation = " Alpha "

            let lowercaseAlpha = try XCTUnwrap(
                service.upsertRecord(
                    for: lowercaseAlphaURL.path,
                    displayName: lowercaseAlphaURL.lastPathComponent,
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 3_000)
                )
            )
            lowercaseAlpha.projectAssociation = "alpha"

            let beta = try XCTUnwrap(
                service.upsertRecord(
                    for: betaURL.path,
                    displayName: betaURL.lastPathComponent,
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 4_000)
                )
            )
            beta.projectAssociation = "Beta"

            let stale = try XCTUnwrap(
                service.upsertRecord(
                    for: staleURL.path,
                    displayName: staleURL.lastPathComponent,
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 5_000)
                )
            )
            stale.projectAssociation = "Alpha"
            try FileManager.default.removeItem(at: staleURL)

            try context.save()

            let detail = try XCTUnwrap(service.fetchProjectSpaceDetail(for: "Alpha"))
            XCTAssertEqual(detail.summary.normalizedLabel, "Alpha")
            XCTAssertEqual(detail.summary.fileCount, 2)
            XCTAssertEqual(
                Set(detail.files.map(\.displayName)),
                ["alpha.txt", "spaced-alpha.txt"]
            )
        }
    }

    func testFetchProjectSpaceDetail_V2IncludesOverviewPreferredDestinationsAndRecentActivity() throws {
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)
        FeatureFlagService.shared.setEnabled(.projectSpaceMemory, true)

        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let alphaOneURL = try tempDir.createFile(name: "Inbox/alpha-one.txt", contents: "alpha")
            let alphaTwoURL = try tempDir.createFile(name: "Inbox/alpha-two.txt", contents: "alpha")
            let betaURL = try tempDir.createFile(name: "Inbox/beta.txt", contents: "beta")

            let alphaOne = try XCTUnwrap(
                service.upsertRecord(
                    for: alphaOneURL.path,
                    displayName: alphaOneURL.lastPathComponent,
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 1_000)
                )
            )
            alphaOne.projectAssociation = "Alpha"

            let alphaTwo = try XCTUnwrap(
                service.upsertRecord(
                    for: alphaTwoURL.path,
                    displayName: alphaTwoURL.lastPathComponent,
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 1_100)
                )
            )
            alphaTwo.projectAssociation = "Alpha"

            let beta = try XCTUnwrap(
                service.upsertRecord(
                    for: betaURL.path,
                    displayName: betaURL.lastPathComponent,
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 1_200)
                )
            )
            beta.projectAssociation = "Beta"
            try context.save()

            _ = try XCTUnwrap(
                service.appendHistoryEntry(
                    for: alphaOne,
                    eventKind: .organized,
                    sourceSurface: .organize,
                    fromPath: alphaOneURL.path,
                    toPath: "/tmp/Alpha Archive/alpha-one.txt",
                    destinationDisplayName: "Alpha Archive",
                    matchedRuleID: nil,
                    detailsSummary: "Initial move to Alpha Archive.",
                    timestamp: Date(timeIntervalSince1970: 100)
                )
            )
            _ = try XCTUnwrap(
                service.appendHistoryEntry(
                    for: alphaOne,
                    eventKind: .rekeyed,
                    sourceSurface: .organize,
                    fromPath: alphaOneURL.path,
                    toPath: "/tmp/Alpha Archive/alpha-one-v2.txt",
                    destinationDisplayName: "Alpha Archive",
                    matchedRuleID: nil,
                    detailsSummary: "Rekeyed in Alpha Archive.",
                    timestamp: Date(timeIntervalSince1970: 200)
                )
            )
            _ = try XCTUnwrap(
                service.appendHistoryEntry(
                    for: alphaTwo,
                    eventKind: .organized,
                    sourceSurface: .organize,
                    fromPath: alphaTwoURL.path,
                    toPath: "/tmp/Beta Shared/alpha-two.txt",
                    destinationDisplayName: "Beta Shared",
                    matchedRuleID: nil,
                    detailsSummary: "Moved to Beta Shared.",
                    timestamp: Date(timeIntervalSince1970: 300)
                )
            )

            for offset in 0..<7 {
                _ = try XCTUnwrap(
                    service.appendHistoryEntry(
                        for: alphaOne,
                        eventKind: .noted,
                        sourceSurface: .review,
                        fromPath: alphaOneURL.path,
                        toPath: alphaOneURL.path,
                        destinationDisplayName: nil,
                        matchedRuleID: nil,
                        detailsSummary: "Note \(offset)",
                        timestamp: Date(timeIntervalSince1970: TimeInterval(1_000 + offset))
                    )
                )
            }

            let detail = try XCTUnwrap(service.fetchProjectSpaceDetail(for: "Alpha"))

            XCTAssertEqual(detail.summary.normalizedLabel, "Alpha")
            XCTAssertEqual(detail.summary.fileCount, 2)
            XCTAssertFalse(detail.summary.sourceFolderHints.isEmpty)
            XCTAssertEqual(Set(detail.files.map(\.displayName)), ["alpha-one.txt", "alpha-two.txt"])
            XCTAssertTrue(detail.files.allSatisfy { $0.projectAssociation == "Alpha" })

            XCTAssertEqual(detail.overview.currentFileCount, 2)
            XCTAssertEqual(detail.overview.activeFolderCount, detail.overview.activeFolderHints.count)
            XCTAssertEqual(detail.overview.preferredDestinationCount, 2)
            XCTAssertEqual(detail.overview.recentActivityCount, 10)
            XCTAssertEqual(detail.overview.lastActivityAt, Date(timeIntervalSince1970: 1_006))

            XCTAssertEqual(detail.preferredDestinations.map(\.destinationDisplayName), ["Alpha Archive", "Beta Shared"])
            XCTAssertEqual(detail.preferredDestinations.map(\.eventCount), [2, 1])

            XCTAssertEqual(detail.recentActivity.count, 8)
            XCTAssertEqual(detail.recentActivity.first?.eventKind, .noted)
            XCTAssertEqual(detail.recentActivity.first?.detailsSummary, "Note 6")
            XCTAssertEqual(detail.recentActivity.last?.eventKind, .organized)
            XCTAssertEqual(detail.recentActivity.last?.destinationDisplayName, "Beta Shared")
        }
    }

    func testFetchProjectSpaceDetail_UsesNotedAndIgnoredHistoryInRecentActivity() throws {
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)
        FeatureFlagService.shared.setEnabled(.projectSpaceMemory, true)

        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let alphaURL = try tempDir.createFile(name: "Inbox/alpha.txt", contents: "alpha")

            let alpha = try XCTUnwrap(
                service.upsertRecord(
                    for: alphaURL.path,
                    displayName: alphaURL.lastPathComponent,
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 1_000)
                )
            )
            alpha.projectAssociation = "Alpha"
            try context.save()

            _ = try XCTUnwrap(
                service.appendHistoryEntry(
                    for: alpha,
                    eventKind: .organized,
                    sourceSurface: .organize,
                    fromPath: alphaURL.path,
                    toPath: "/tmp/Alpha Archive/alpha.txt",
                    destinationDisplayName: "Alpha Archive",
                    matchedRuleID: nil,
                    detailsSummary: "Organized to archive.",
                    timestamp: Date(timeIntervalSince1970: 1_500)
                )
            )
            _ = try XCTUnwrap(
                service.appendHistoryEntry(
                    for: alpha,
                    eventKind: .ignored,
                    sourceSurface: .review,
                    fromPath: alphaURL.path,
                    toPath: alphaURL.path,
                    destinationDisplayName: nil,
                    matchedRuleID: nil,
                    detailsSummary: "Ignored during review.",
                    timestamp: Date(timeIntervalSince1970: 2_000)
                )
            )
            _ = try XCTUnwrap(
                service.appendHistoryEntry(
                    for: alpha,
                    eventKind: .noted,
                    sourceSurface: .review,
                    fromPath: alphaURL.path,
                    toPath: alphaURL.path,
                    destinationDisplayName: nil,
                    matchedRuleID: nil,
                    detailsSummary: "Needs project rename.",
                    timestamp: Date(timeIntervalSince1970: 3_000)
                )
            )
            _ = try XCTUnwrap(
                service.appendHistoryEntry(
                    for: alpha,
                    eventKind: .scanned,
                    sourceSurface: .scan,
                    fromPath: nil,
                    toPath: alphaURL.path,
                    destinationDisplayName: nil,
                    matchedRuleID: nil,
                    detailsSummary: "Scan-only event.",
                    timestamp: Date(timeIntervalSince1970: 4_000)
                )
            )

            let detail = try XCTUnwrap(service.fetchProjectSpaceDetail(for: "Alpha"))
            XCTAssertEqual(detail.recentActivity.map(\.eventKind), [.noted, .ignored, .organized])
            XCTAssertEqual(detail.recentActivity.map(\.detailsSummary), ["Needs project rename.", "Ignored during review.", "Organized to archive."])
            XCTAssertEqual(detail.recentActivity.map(\.destinationDisplayName), ["Inbox", "Inbox", "Alpha Archive"])
        }
    }

    func testProjectSpaceSummaryAndDetail_KeepRootSourceFolderHintsWhenProjectSpaceMemoryEnabled() throws {
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)
        FeatureFlagService.shared.setEnabled(.projectSpaceMemory, true)

        try withService { context, service in
            let homePath = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
            let docsPath = "\(homePath)/Downloads/Alpha/Docs/spec.txt"
            let designPath = "\(homePath)/Downloads/Alpha/Design/mockup.txt"

            let docsRecord = try XCTUnwrap(
                service.upsertRecord(
                    for: docsPath,
                    displayName: "spec.txt",
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 1_000)
                )
            )
            docsRecord.projectAssociation = "Alpha"

            let designRecord = try XCTUnwrap(
                service.upsertRecord(
                    for: designPath,
                    displayName: "mockup.txt",
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 1_100)
                )
            )
            designRecord.projectAssociation = "Alpha"

            try context.save()

            #if DEBUG
            FileMetadataFoundationService.debugProjectSpacePathReachabilityHook = { path, _ in
                if path == docsPath || path == designPath {
                    return true
                }
                return nil
            }
            defer {
                FileMetadataFoundationService.debugProjectSpacePathReachabilityHook = nil
            }
            #endif

            let summary = try XCTUnwrap(service.fetchProjectSpaceSummaries().first(where: { $0.normalizedLabel == "Alpha" }))
            let detail = try XCTUnwrap(service.fetchProjectSpaceDetail(for: "Alpha"))
            let expectedRootHint = try XCTUnwrap(service.projectSpaceSourceFolderHintRoot(for: docsPath))

            XCTAssertEqual(summary.sourceFolderHints, [expectedRootHint])
            XCTAssertEqual(detail.summary.sourceFolderHints, [expectedRootHint])

            XCTAssertEqual(detail.overview.activeFolderCount, 2)
            XCTAssertEqual(detail.overview.activeFolderHints, ["Design", "Docs"])
            XCTAssertNotEqual(detail.overview.activeFolderHints, detail.summary.sourceFolderHints)
        }
    }

    func testCorrectProjectAssociation_UpdatesNormalizedLabelAndAppendsNotedHistory() throws {
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)
        FeatureFlagService.shared.setEnabled(.projectSpaceMemory, true)

        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let alphaURL = try tempDir.createFile(name: "Inbox/alpha.txt", contents: "alpha")
            let betaURL = try tempDir.createFile(name: "Inbox/beta.txt", contents: "beta")

            let alphaRecord = try XCTUnwrap(
                service.upsertRecord(
                    for: alphaURL.path,
                    displayName: alphaURL.lastPathComponent,
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 1_000)
                )
            )
            alphaRecord.projectAssociation = "Alpha"

            let betaRecord = try XCTUnwrap(
                service.upsertRecord(
                    for: betaURL.path,
                    displayName: betaURL.lastPathComponent,
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 1_100)
                )
            )
            betaRecord.projectAssociation = "Beta"
            try context.save()

            let didCorrect = try service.correctProjectAssociation(
                forCanonicalIdentity: alphaRecord.canonicalIdentity,
                to: "  Beta  ",
                timestamp: Date(timeIntervalSince1970: 2_000)
            )
            XCTAssertTrue(didCorrect)

            XCTAssertEqual(alphaRecord.projectAssociation, "Beta")
            XCTAssertNil(service.fetchProjectSpaceDetail(for: "Alpha"))

            let betaDetail = try XCTUnwrap(service.fetchProjectSpaceDetail(for: "Beta"))
            XCTAssertEqual(betaDetail.summary.fileCount, 2)
            XCTAssertEqual(Set(betaDetail.files.map(\.displayName)), ["alpha.txt", "beta.txt"])

            let notedEntries = alphaRecord.historyEntries
                .filter { $0.eventKind == .noted }
                .sorted(by: { $0.timestamp < $1.timestamp })
            XCTAssertEqual(notedEntries.count, 1)
            XCTAssertEqual(notedEntries.last?.detailsSummary, "Corrected project association from Alpha to Beta.")

            let unchangedResult = try service.correctProjectAssociation(
                forCanonicalIdentity: alphaRecord.canonicalIdentity,
                to: "Beta",
                timestamp: Date(timeIntervalSince1970: 2_500)
            )
            XCTAssertFalse(unchangedResult)

            let emptyResult = try service.correctProjectAssociation(
                forCanonicalIdentity: alphaRecord.canonicalIdentity,
                to: "   ",
                timestamp: Date(timeIntervalSince1970: 3_000)
            )
            XCTAssertFalse(emptyResult)

            let postNoopNotedEntries = alphaRecord.historyEntries
                .filter { $0.eventKind == .noted }
            XCTAssertEqual(postNoopNotedEntries.count, 1)
        }
    }

    func testProjectSpaceSummaries_ExcludeMalformedRelativePaths() throws {
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)

        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let validURL = try tempDir.createFile(name: "Inbox/valid.txt", contents: "alpha")
            let malformedAbsoluteURL = try tempDir.createFile(name: "malformed.txt", contents: "beta")

            let valid = try XCTUnwrap(
                service.upsertRecord(
                    for: validURL.path,
                    displayName: validURL.lastPathComponent,
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 1_000)
                )
            )
            valid.projectAssociation = "Alpha"

            let malformed = FileMetadataRecord(
                canonicalIdentity: "relative-path-record",
                identityKind: .pathFallback,
                lastKnownPath: malformedAbsoluteURL.path,
                displayName: "malformed.txt",
                fileExtension: "txt",
                firstSeenAt: Date(timeIntervalSince1970: 2_000),
                lastSeenAt: Date(timeIntervalSince1970: 2_000)
            )
            malformed.projectAssociation = "Alpha"
            malformed.lastKnownPath = " malformed.txt "
            context.insert(malformed)

            try context.save()

            let originalDirectoryPath = FileManager.default.currentDirectoryPath
            XCTAssertTrue(FileManager.default.changeCurrentDirectoryPath(tempDir.url.path))
            defer {
                XCTAssertTrue(FileManager.default.changeCurrentDirectoryPath(originalDirectoryPath))
            }

            let summaries = service.fetchProjectSpaceSummaries()
            let detail = service.fetchProjectSpaceDetail(for: "Alpha")

            XCTAssertEqual(summaries.map(\.normalizedLabel), ["Alpha"])
            XCTAssertEqual(summaries.first?.fileCount, 1)
            XCTAssertEqual(detail?.files.map(\.displayName), ["valid.txt"])
        }
    }

    func testProjectSpaceSummaries_ExcludeWhitespacePaddedAbsolutePaths() throws {
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)

        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let validURL = try tempDir.createFile(name: "Inbox/valid.txt", contents: "alpha")
            let malformedAbsoluteURL = try tempDir.createFile(name: "Inbox/malformed.txt", contents: "beta")

            let valid = try XCTUnwrap(
                service.upsertRecord(
                    for: validURL.path,
                    displayName: validURL.lastPathComponent,
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 1_000)
                )
            )
            valid.projectAssociation = "Alpha"

            let malformed = FileMetadataRecord(
                canonicalIdentity: "absolute-whitespace-record",
                identityKind: .pathFallback,
                lastKnownPath: malformedAbsoluteURL.path,
                displayName: malformedAbsoluteURL.lastPathComponent,
                fileExtension: "txt",
                firstSeenAt: Date(timeIntervalSince1970: 2_000),
                lastSeenAt: Date(timeIntervalSince1970: 2_000)
            )
            malformed.projectAssociation = "Alpha"
            malformed.lastKnownPath = " \(malformedAbsoluteURL.path) "
            context.insert(malformed)

            try context.save()

            let summaries = service.fetchProjectSpaceSummaries()
            let detail = service.fetchProjectSpaceDetail(for: "Alpha")

            XCTAssertEqual(summaries.map(\.normalizedLabel), ["Alpha"])
            XCTAssertEqual(summaries.first?.fileCount, 1)
            XCTAssertEqual(detail?.files.map(\.displayName), ["valid.txt"])
        }
    }

    func testProjectSpaceSummaries_LastActivityPrefersDurableHistoryEntry() throws {
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)

        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let fileURL = try tempDir.createFile(name: "Inbox/project-alpha.txt", contents: "alpha")

            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: fileURL.path,
                    displayName: "project-alpha.txt",
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 1_000)
                )
            )
            record.projectAssociation = "Alpha"
            record.lastSeenAt = Date(timeIntervalSince1970: 6_000)
            record.lastOrganizedAt = Date(timeIntervalSince1970: 5_000)

            _ = try XCTUnwrap(
                service.appendHistoryEntry(
                    for: record,
                    eventKind: .organized,
                    sourceSurface: .organize,
                    fromPath: fileURL.path,
                    toPath: fileURL.path,
                    destinationDisplayName: "Alpha",
                    matchedRuleID: nil,
                    detailsSummary: "Initial durable history entry.",
                    timestamp: Date(timeIntervalSince1970: 1_000)
                )
            )
            _ = try XCTUnwrap(
                service.appendHistoryEntry(
                    for: record,
                    eventKind: .rekeyed,
                    sourceSurface: .organize,
                    fromPath: fileURL.path,
                    toPath: fileURL.path,
                    destinationDisplayName: "Alpha",
                    matchedRuleID: nil,
                    detailsSummary: "Follow-up durable history entry.",
                    timestamp: Date(timeIntervalSince1970: 2_000)
                )
            )
            _ = try XCTUnwrap(
                service.appendHistoryEntry(
                    for: record,
                    eventKind: .undone,
                    sourceSurface: .undo,
                    fromPath: fileURL.path,
                    toPath: fileURL.path,
                    destinationDisplayName: "Alpha",
                    matchedRuleID: nil,
                    detailsSummary: "Latest durable history entry.",
                    timestamp: Date(timeIntervalSince1970: 3_000)
                )
            )

            try context.save()

            let summary = try XCTUnwrap(service.fetchProjectSpaceSummaries().first)
            XCTAssertEqual(summary.normalizedLabel, "Alpha")
            XCTAssertEqual(summary.fileCount, 1)
            XCTAssertEqual(summary.lastActivityAt, Date(timeIntervalSince1970: 3_000))
        }
    }

    func testProjectSpaceSummaries_LastActivityPrefersIgnoredAndNotedHistoryEntries() throws {
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)

        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let fileURL = try tempDir.createFile(name: "Inbox/project-alpha.txt", contents: "alpha")

            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: fileURL.path,
                    displayName: "project-alpha.txt",
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 1_000)
                )
            )
            record.projectAssociation = "Alpha"
            record.lastOrganizedAt = Date(timeIntervalSince1970: 5_000)
            record.lastSeenAt = Date(timeIntervalSince1970: 6_000)

            _ = try XCTUnwrap(
                service.appendHistoryEntry(
                    for: record,
                    eventKind: .ignored,
                    sourceSurface: .review,
                    fromPath: fileURL.path,
                    toPath: fileURL.path,
                    destinationDisplayName: nil,
                    matchedRuleID: nil,
                    detailsSummary: "Ignored in review.",
                    timestamp: Date(timeIntervalSince1970: 7_000)
                )
            )
            _ = try XCTUnwrap(
                service.appendHistoryEntry(
                    for: record,
                    eventKind: .noted,
                    sourceSurface: .review,
                    fromPath: fileURL.path,
                    toPath: fileURL.path,
                    destinationDisplayName: nil,
                    matchedRuleID: nil,
                    detailsSummary: "Noted in review.",
                    timestamp: Date(timeIntervalSince1970: 8_000)
                )
            )

            try context.save()

            let summary = try XCTUnwrap(service.fetchProjectSpaceSummaries().first)
            XCTAssertEqual(summary.normalizedLabel, "Alpha")
            XCTAssertEqual(summary.lastActivityAt, Date(timeIntervalSince1970: 8_000))
        }
    }

    func testProjectSpaceSummaries_LastActivityUsesLastOrganizedAtBeforeLastSeenAt() throws {
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)

        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let fileURL = try tempDir.createFile(name: "Inbox/project-alpha.txt", contents: "alpha")

            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: fileURL.path,
                    displayName: fileURL.lastPathComponent,
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 1_000)
                )
            )
            record.projectAssociation = "Alpha"
            record.lastOrganizedAt = Date(timeIntervalSince1970: 5_000)
            record.lastSeenAt = Date(timeIntervalSince1970: 6_000)

            try context.save()

            let summary = try XCTUnwrap(service.fetchProjectSpaceSummaries().first)
            XCTAssertEqual(summary.normalizedLabel, "Alpha")
            XCTAssertEqual(summary.lastActivityAt, Date(timeIntervalSince1970: 5_000))
        }
    }

    func testProjectSpaceSummaries_LastActivityFallsBackToLastSeenAt() throws {
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)

        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let fileURL = try tempDir.createFile(name: "Inbox/project-alpha.txt", contents: "alpha")

            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: fileURL.path,
                    displayName: fileURL.lastPathComponent,
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 1_000)
                )
            )
            record.projectAssociation = "Alpha"
            record.lastSeenAt = Date(timeIntervalSince1970: 4_000)

            try context.save()

            let summary = try XCTUnwrap(service.fetchProjectSpaceSummaries().first)
            XCTAssertEqual(summary.normalizedLabel, "Alpha")
            XCTAssertEqual(summary.lastActivityAt, Date(timeIntervalSince1970: 4_000))
        }
    }

    func testProjectSpaceSummaries_LastActivityFallsBackToFirstSeenAt() throws {
        FeatureFlagService.shared.setEnabled(.projectSpaces, true)

        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let fileURL = try tempDir.createFile(name: "Inbox/project-alpha.txt", contents: "alpha")

            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: fileURL.path,
                    displayName: fileURL.lastPathComponent,
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 5_000)
                )
            )
            record.projectAssociation = "Alpha"
            record.lastSeenAt = Date(timeIntervalSince1970: 1_000)

            try context.save()

            let summary = try XCTUnwrap(service.fetchProjectSpaceSummaries().first)
            XCTAssertEqual(summary.normalizedLabel, "Alpha")
            XCTAssertEqual(summary.lastActivityAt, Date(timeIntervalSince1970: 5_000))
        }
    }

    func testProjectSpaceSummaries_AreHiddenWhenProjectSpacesFeatureIsDisabled() throws {
        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let fileURL = try tempDir.createFile(name: "Inbox/disabled-space.txt", contents: "alpha")

            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: fileURL.path,
                    displayName: "disabled-space.txt",
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 5_000)
                )
            )
            record.projectAssociation = "Alpha"
            try context.save()

            XCTAssertTrue(FeatureFlagService.shared.isEnabled(.metadataFoundation))
            XCTAssertFalse(FeatureFlagService.shared.isEnabled(.projectSpaces))
            XCTAssertTrue(service.fetchProjectSpaceSummaries().isEmpty)
        }
    }

    func testUpsertRecord_DeduplicatesByCanonicalIdentity() throws {
        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let sourceURL = try tempDir.createFile(name: "Inbox/report.txt", contents: "report")
            let firstTimestamp = Date(timeIntervalSince1970: 1_000)
            let secondTimestamp = Date(timeIntervalSince1970: 2_000)

            let firstRecord = try XCTUnwrap(
                service.upsertRecord(
                    for: sourceURL.path,
                    displayName: "report.txt",
                    fileExtension: "txt",
                    timestamp: firstTimestamp
                )
            )

            let movedURL = tempDir.url.appendingPathComponent("Archive/renamed-report.txt")
            try FileManager.default.createDirectory(
                at: movedURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try FileManager.default.moveItem(at: sourceURL, to: movedURL)

            let secondRecord = try XCTUnwrap(
                service.upsertRecord(
                    for: movedURL.path,
                    displayName: "renamed-report.txt",
                    fileExtension: "txt",
                    timestamp: secondTimestamp
                )
            )

            let records = try context.fetch(FetchDescriptor<FileMetadataRecord>())
            XCTAssertEqual(records.count, 1)
            XCTAssertEqual(firstRecord.canonicalIdentity, secondRecord.canonicalIdentity)
            XCTAssertEqual(records.first?.canonicalIdentity, secondRecord.canonicalIdentity)
            XCTAssertEqual(records.first?.lastKnownPath, movedURL.path)
            XCTAssertEqual(records.first?.firstSeenAt, firstTimestamp)
            XCTAssertEqual(records.first?.lastSeenAt, secondTimestamp)
        }
    }

    func testRekeyPathFallbackRecord_AfterManagedMove() throws {
        try withService { context, service in
            let oldPath = "/Users/example/Downloads/Legacy/invoice.txt"
            let newPath = "/Users/example/Documents/Invoices/invoice.txt"
            let firstTimestamp = Date(timeIntervalSince1970: 3_000)
            let secondTimestamp = Date(timeIntervalSince1970: 4_000)
            let thirdTimestamp = Date(timeIntervalSince1970: 5_000)

            let originalRecord = try XCTUnwrap(
                service.upsertRecord(
                    for: oldPath,
                    displayName: "invoice.txt",
                    fileExtension: "txt",
                    timestamp: firstTimestamp
                )
            )

            XCTAssertEqual(originalRecord.identityKind, .pathFallback)

            let rekeyedRecord = try XCTUnwrap(
                service.rekeyPathFallbackRecord(
                    oldPath: oldPath,
                    newPath: newPath,
                    timestamp: secondTimestamp
                )
            )

            XCTAssertEqual(rekeyedRecord.identityKind, .pathFallback)
            XCTAssertEqual(rekeyedRecord.canonicalIdentity, FileMetadataFoundationService.pathFallbackCanonicalIdentity(for: newPath))
            XCTAssertEqual(rekeyedRecord.lastKnownPath, newPath)

            let refreshedRecord = try XCTUnwrap(
                service.upsertRecord(
                    for: newPath,
                    displayName: "invoice.txt",
                    fileExtension: "txt",
                    timestamp: thirdTimestamp
                )
            )

            let records = try context.fetch(FetchDescriptor<FileMetadataRecord>())
            XCTAssertEqual(records.count, 1)
            XCTAssertEqual(refreshedRecord.canonicalIdentity, rekeyedRecord.canonicalIdentity)
            XCTAssertEqual(records.first?.lastKnownPath, newPath)
            XCTAssertEqual(records.first?.lastSeenAt, thirdTimestamp)
        }
    }

    func testAppendHistoryEntry_PreservesMetadataRelationshipAcrossFallbackRekey() throws {
        try withService { context, service in
            let oldPath = "/Users/example/Downloads/Legacy/receipt.pdf"
            let newPath = "/Users/example/Documents/Receipts/receipt.pdf"
            let eventTimestamp = Date(timeIntervalSince1970: 6_000)

            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: oldPath,
                    displayName: "receipt.pdf",
                    fileExtension: "pdf",
                    timestamp: Date(timeIntervalSince1970: 5_900)
                )
            )

            _ = try XCTUnwrap(
                service.appendHistoryEntry(
                    for: record,
                    eventKind: .organized,
                    sourceSurface: .organize,
                    fromPath: oldPath,
                    toPath: newPath,
                    destinationDisplayName: "Receipts",
                    matchedRuleID: nil,
                    detailsSummary: "Moved by Forma during a managed organization pass.",
                    timestamp: eventTimestamp
                )
            )

            _ = try XCTUnwrap(
                service.rekeyPathFallbackRecord(
                    oldPath: oldPath,
                    newPath: newPath,
                    timestamp: Date(timeIntervalSince1970: 6_100)
                )
            )

            let summary = try XCTUnwrap(service.inspectorSummary(for: newPath))
            XCTAssertEqual(summary.recentHistoryRows.count, 1)
            XCTAssertEqual(summary.recentHistoryRows.first?.fromPath, oldPath)
            XCTAssertEqual(summary.recentHistoryRows.first?.toPath, newPath)
            XCTAssertEqual(summary.recentHistoryRows.first?.destinationDisplayName, "Receipts")

            let records = try context.fetch(FetchDescriptor<FileMetadataRecord>())
            XCTAssertEqual(records.count, 1)
            XCTAssertEqual(records.first?.historyEntries.count, 1)
        }
    }

    func testInspectorSummary_UsesReservedDefaultsAndHistoryOrdering() throws {
        try withService { _, service in
            let tempDir = try TemporaryDirectory()
            let fileURL = try tempDir.createFile(name: "report.csv", contents: "alpha,beta")
            let firstSeen = Date(timeIntervalSince1970: 0)
            let olderHistory = Date(timeIntervalSince1970: 60)
            let middleHistory = Date(timeIntervalSince1970: 120)
            let newestHistory = Date(timeIntervalSince1970: 180)

            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: fileURL.path,
                    displayName: "report.csv",
                    fileExtension: "csv",
                    timestamp: firstSeen
                )
            )

            _ = try XCTUnwrap(
                service.appendHistoryEntry(
                    for: record,
                    eventKind: .scanned,
                    sourceSurface: .scan,
                    fromPath: nil,
                    toPath: fileURL.path,
                    destinationDisplayName: nil,
                    matchedRuleID: nil,
                    detailsSummary: "Initial metadata capture.",
                    timestamp: middleHistory
                )
            )

            _ = try XCTUnwrap(
                service.appendHistoryEntry(
                    for: record,
                    eventKind: .organized,
                    sourceSurface: .organize,
                    fromPath: fileURL.path,
                    toPath: "/Users/example/Documents/report.csv",
                    destinationDisplayName: "Documents",
                    matchedRuleID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"),
                    detailsSummary: "Moved into Documents.",
                    timestamp: newestHistory
                )
            )

            _ = try XCTUnwrap(
                service.appendHistoryEntry(
                    for: record,
                    eventKind: .noted,
                    sourceSurface: .inspector,
                    fromPath: fileURL.path,
                    toPath: nil,
                    destinationDisplayName: nil,
                    matchedRuleID: nil,
                    detailsSummary: "Inspector note.",
                    timestamp: olderHistory
                )
            )

            let summary = try XCTUnwrap(service.inspectorSummary(for: fileURL.path))
            XCTAssertEqual(summary.firstSeenSummary, "First seen: 1970-01-01 00:00:00 UTC")
            XCTAssertEqual(summary.lastOrganizedSummary, "Last organized: 1970-01-01 00:03:00 UTC")
            XCTAssertEqual(summary.organizationCountSummary, "1 organization")
            XCTAssertEqual(summary.tagsSummary, "")
            XCTAssertEqual(summary.projectAssociationSummary, "")
            XCTAssertEqual(summary.recentHistoryRows.map(\.detailsSummary), [
                "Moved into Documents.",
                "Initial metadata capture.",
                "Inspector note."
            ])
        }
    }

    func testInspectorSummary_IncludesHistoryAndReservedMetadataWhenAvailable() throws {
        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let fileURL = try tempDir.createFile(name: "archive/proof.txt", contents: "proof")
            let firstSeen = Date(timeIntervalSince1970: 10)
            let scannedAt = Date(timeIntervalSince1970: 20)
            let organizedAt = Date(timeIntervalSince1970: 30)

            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: fileURL.path,
                    displayName: "proof.txt",
                    fileExtension: "txt",
                    timestamp: firstSeen
                )
            )

            record.projectAssociation = "  Finance Vault  "
            record.tags = ["  Priority  ", "  Archived  "]
            try context.save()

            _ = try XCTUnwrap(
                service.appendHistoryEntry(
                    for: record,
                    eventKind: .scanned,
                    sourceSurface: .scan,
                    fromPath: nil,
                    toPath: fileURL.path,
                    destinationDisplayName: nil,
                    matchedRuleID: nil,
                    detailsSummary: "Scanned into metadata foundation.",
                    timestamp: scannedAt
                )
            )

            _ = try XCTUnwrap(
                service.appendHistoryEntry(
                    for: record,
                    eventKind: .organized,
                    sourceSurface: .organize,
                    fromPath: fileURL.path,
                    toPath: "/Users/example/Documents/proof.txt",
                    destinationDisplayName: "Documents",
                    matchedRuleID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"),
                    detailsSummary: "Moved into the durable archive.",
                    timestamp: organizedAt
                )
            )

            let summary = try XCTUnwrap(service.inspectorSummary(for: fileURL.path))
            XCTAssertEqual(summary.firstSeenSummary, "First seen: 1970-01-01 00:00:10 UTC")
            XCTAssertEqual(summary.lastOrganizedSummary, "Last organized: 1970-01-01 00:00:30 UTC")
            XCTAssertEqual(summary.organizationCountSummary, "1 organization")
            XCTAssertEqual(summary.projectAssociationSummary, "Finance Vault")
            XCTAssertEqual(summary.tagsSummary, "Priority, Archived")
            XCTAssertEqual(summary.recentHistoryRows.count, 2)
            XCTAssertEqual(summary.recentHistoryRows.map(\.eventKind), ["organized", "scanned"])
            XCTAssertEqual(summary.recentHistoryRows.map(\.detailsSummary), [
                "Moved into the durable archive.",
                "Scanned into metadata foundation."
            ])
        }
    }

    func testApplyProjectAssociation_ExplicitProjectLikeDestinationWritesNormalizedLabel() throws {
        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let fileURL = try tempDir.createFile(name: "Inbox/report.txt", contents: "report")
            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: fileURL.path,
                    displayName: "report.txt",
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 8_000)
                )
            )

            let writeContext = ProjectAssociationWriteContext(
                resolvedExplicitDestinationFolderPath: "/Users/example/Documents/Projects/  Alpha  ",
                explicitSourceMode: false,
                inferredCandidates: []
            )

            let sourceCategory = try XCTUnwrap(
                service.applyProjectAssociationWithoutSaving(
                    for: record,
                    writeContext: writeContext
                )
            )

            XCTAssertEqual(sourceCategory, .destinationFolder)
            XCTAssertEqual(record.projectAssociation, "Alpha")
            XCTAssertEqual(try context.fetch(FetchDescriptor<FileMetadataRecord>()).first?.projectAssociation, "Alpha")
        }
    }

    func testApplyProjectAssociation_InferencePopulatesEmptyRecordOnly() throws {
        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let sourceURL = try tempDir.createFile(name: "Inbox/alpha-note.txt", contents: "alpha")
            let candidate = try insertProjectCluster(
                in: context,
                filePath: sourceURL.path,
                suggestedFolderName: "Alpha",
                confidenceScore: 0.91
            )

            let emptyRecord = try XCTUnwrap(
                service.upsertRecord(
                    for: sourceURL.path,
                    displayName: "alpha-note.txt",
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 8_100)
                )
            )

            let emptyWriteContext = ProjectAssociationWriteContext(
                resolvedExplicitDestinationFolderPath: nil,
                explicitSourceMode: false,
                inferredCandidates: [
                    .init(
                        suggestedFolderName: candidate.suggestedFolderName,
                        normalizedLabel: candidate.suggestedFolderName,
                        confidence: candidate.confidenceScore
                    )
                ]
            )

            let sourceCategory = try XCTUnwrap(
                service.applyProjectAssociationWithoutSaving(
                    for: emptyRecord,
                    writeContext: emptyWriteContext
                )
            )

            XCTAssertEqual(sourceCategory, .relatedFilePattern)
            XCTAssertEqual(emptyRecord.projectAssociation, "Alpha")

            let existingRecord = try XCTUnwrap(
                service.upsertRecord(
                    for: tempDir.url.appendingPathComponent("Inbox/existing-alpha-note.txt").path,
                    displayName: "existing-alpha-note.txt",
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 8_200)
                )
            )
            existingRecord.projectAssociation = "Existing Label"
            try context.save()

            let existingWriteContext = ProjectAssociationWriteContext(
                resolvedExplicitDestinationFolderPath: nil,
                explicitSourceMode: false,
                inferredCandidates: [
                    .init(
                        suggestedFolderName: candidate.suggestedFolderName,
                        normalizedLabel: candidate.suggestedFolderName,
                        confidence: candidate.confidenceScore
                    )
                ]
            )

            _ = service.applyProjectAssociationWithoutSaving(
                for: existingRecord,
                writeContext: existingWriteContext
            )

            XCTAssertEqual(existingRecord.projectAssociation, "Existing Label")
        }
    }

    func testInspectorSummary_IncludesProjectAssociationSourceSummary() throws {
        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let fileURL = try tempDir.createFile(name: "Inbox/finance-report.txt", contents: "finance")

            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: fileURL.path,
                    displayName: "finance-report.txt",
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 8_300)
                )
            )
            record.projectAssociation = "Finance Vault"
            try context.save()

            _ = try XCTUnwrap(
                service.appendHistoryEntry(
                    for: record,
                    eventKind: .organized,
                    sourceSurface: .organize,
                    fromPath: fileURL.path,
                    toPath: "/Users/example/Documents/Projects/Finance Vault/finance-report.txt",
                    destinationDisplayName: "Finance Vault",
                    matchedRuleID: nil,
                    detailsSummary: "Moved into a project folder.",
                    timestamp: Date(timeIntervalSince1970: 8_400)
                )
            )

            let summary = try XCTUnwrap(service.inspectorSummary(for: fileURL.path))
            XCTAssertEqual(summary.projectAssociationSummary, "Finance Vault")
            XCTAssertEqual(summary.projectAssociationSourceSummary, "Derived from destination folder")
        }
    }

    func testInspectorSummary_DoesNotTreatScannedRowsAsDestinationFolderProof() throws {
        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let fileURL = try tempDir.createFile(name: "Inbox/scanned-project.txt", contents: "scan")

            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: fileURL.path,
                    displayName: "scanned-project.txt",
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 8_420)
                )
            )
            record.projectAssociation = "Finance Vault"
            try context.save()

            _ = try XCTUnwrap(
                service.appendHistoryEntry(
                    for: record,
                    eventKind: .scanned,
                    sourceSurface: .scan,
                    fromPath: nil,
                    toPath: "/Users/example/Documents/Projects/Finance Vault/scanned-project.txt",
                    destinationDisplayName: "Finance Vault",
                    matchedRuleID: nil,
                    detailsSummary: "Scan row with a project-like destination path.",
                    timestamp: Date(timeIntervalSince1970: 8_421)
                )
            )

            let summary = try XCTUnwrap(service.inspectorSummary(for: fileURL.path))
            XCTAssertEqual(summary.projectAssociationSummary, "Finance Vault")
            XCTAssertNil(summary.projectAssociationSourceSummary)
        }
    }

    func testInspectorSummary_DoesNotExposeDestinationFolderSourceSummaryForGenericDestination() throws {
        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let fileURL = try tempDir.createFile(name: "Inbox/screenshot.png", contents: "shot")

            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: fileURL.path,
                    displayName: "screenshot.png",
                    fileExtension: "png",
                    timestamp: Date(timeIntervalSince1970: 8_450)
                )
            )
            record.projectAssociation = "Screenshots"
            try context.save()

            _ = try XCTUnwrap(
                service.appendHistoryEntry(
                    for: record,
                    eventKind: .organized,
                    sourceSurface: .organize,
                    fromPath: fileURL.path,
                    toPath: "/Users/example/Pictures/Screenshots/screenshot.png",
                    destinationDisplayName: "Screenshots",
                    matchedRuleID: nil,
                    detailsSummary: "Moved into a generic destination folder.",
                    timestamp: Date(timeIntervalSince1970: 8_460)
                )
            )

            let summary = try XCTUnwrap(service.inspectorSummary(for: fileURL.path))
            XCTAssertEqual(summary.projectAssociationSummary, "Screenshots")
            XCTAssertNil(summary.projectAssociationSourceSummary)
        }
    }

    func testInspectorSummary_HidesProjectAssociationRowWhenAutoProjectAssociationDisabled() throws {
        try withService { context, service in
            FeatureFlagService.shared.setEnabled(.autoProjectAssociation, false)

            let tempDir = try TemporaryDirectory()
            let fileURL = try tempDir.createFile(name: "Inbox/project-note.txt", contents: "project")

            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: fileURL.path,
                    displayName: "project-note.txt",
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 8_500)
                )
            )
            record.projectAssociation = "Project Atlas"
            try context.save()

            _ = try XCTUnwrap(
                service.appendHistoryEntry(
                    for: record,
                    eventKind: .organized,
                    sourceSurface: .organize,
                    fromPath: fileURL.path,
                    toPath: "/Users/example/Documents/Projects/Project Atlas/project-note.txt",
                    destinationDisplayName: "Project Atlas",
                    matchedRuleID: nil,
                    detailsSummary: "Moved into a project folder.",
                    timestamp: Date(timeIntervalSince1970: 8_600)
                )
            )

            let summary = try XCTUnwrap(service.inspectorSummary(for: fileURL.path))
            XCTAssertEqual(summary.firstSeenSummary, "First seen: 1970-01-01 02:21:40 UTC")
            XCTAssertEqual(summary.lastOrganizedSummary, "Last organized: 1970-01-01 02:23:20 UTC")
            XCTAssertEqual(summary.organizationCountSummary, "1 organization")
            XCTAssertEqual(summary.projectAssociationSummary, "")
            XCTAssertNil(summary.projectAssociationSourceSummary)
        }
    }

    func testWorkflowStatus_RoundTripsThroughMetadataRecord() throws {
        let schema = Schema([FileMetadataRecord.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        let record = FileMetadataRecord(
            canonicalIdentity: "resource|volume|identifier",
            identityKind: .resourceIdentifier,
            lastKnownPath: "/Users/example/Documents/report.txt",
            displayName: "report.txt",
            fileExtension: "txt",
            firstSeenAt: Date(timeIntervalSince1970: 9_000),
            lastSeenAt: Date(timeIntervalSince1970: 9_100)
        )
        record.workflowStatus = .queued
        context.insert(record)
        try context.save()

        let fetchedRecord = try XCTUnwrap(try context.fetch(FetchDescriptor<FileMetadataRecord>()).first)
        XCTAssertEqual(fetchedRecord.workflowStatus, .queued)
        XCTAssertEqual(fetchedRecord.workflowStatusRaw, MetadataWorkflowStatus.queued.rawValue)
    }

    func testWorkflowStatus_DefaultsToNilForLegacyRows() throws {
        let schema = Schema([FileMetadataRecord.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        let record = FileMetadataRecord(
            canonicalIdentity: "resource|volume|legacy",
            identityKind: .pathFallback,
            lastKnownPath: "/Users/example/Documents/legacy.txt",
            displayName: "legacy.txt",
            fileExtension: "txt",
            firstSeenAt: Date(timeIntervalSince1970: 9_200),
            lastSeenAt: Date(timeIntervalSince1970: 9_300)
        )
        context.insert(record)
        try context.save()

        let fetchedRecord = try XCTUnwrap(try context.fetch(FetchDescriptor<FileMetadataRecord>()).first)
        XCTAssertNil(fetchedRecord.workflowStatus)
        XCTAssertNil(fetchedRecord.workflowStatusRaw)
    }

    func testInspectorSummary_HidesWorkflowStatusWhenFeatureDisabled() throws {
        try withService { context, service in
            XCTAssertFalse(FeatureFlagService.Feature.durableWorkflowStatus.defaultValue)
            XCTAssertFalse(FeatureFlagService.shared.isEnabled(.durableWorkflowStatus))

            FeatureFlagService.shared.setEnabled(.durableWorkflowStatus, false)

            let tempDir = try TemporaryDirectory()
            let fileURL = try tempDir.createFile(name: "Inbox/workflow-note.txt", contents: "workflow")

            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: fileURL.path,
                    displayName: "workflow-note.txt",
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 9_400)
                )
            )
            record.workflowStatus = .queued
            try context.save()

            let summary = try XCTUnwrap(service.inspectorSummary(for: fileURL.path))
            XCTAssertNil(summary.workflowStatusSummary)
            XCTAssertFalse(summary.durableSummaryLines.contains(where: { $0.contains("Status:") }))
        }
    }

    func testApplyWorkflowStatusForNewRecord_WritesQueuedAndScannedHistory() throws {
        try withService { context, service in
            FeatureFlagService.shared.setEnabled(.durableWorkflowStatus, true)

            let tempDir = try TemporaryDirectory()
            let fileURL = try tempDir.createFile(name: "Inbox/discovered.txt", contents: "discovered")
            let timestamp = Date(timeIntervalSince1970: 9_450)

            let record = try XCTUnwrap(
                service.upsertRecordWithoutSaving(
                    for: fileURL.path,
                    displayName: "discovered.txt",
                    fileExtension: "txt",
                    timestamp: timestamp
                )
            )

            let didWriteWorkflowStatus = try service.applyWorkflowStatusForDiscoveryWithoutSaving(
                to: record,
                wasCreated: true,
                timestamp: timestamp
            )
            try context.save()

            XCTAssertTrue(didWriteWorkflowStatus)
            XCTAssertEqual(record.workflowStatus, .queued)
            XCTAssertEqual(record.historyEntries.count, 1)
            XCTAssertEqual(record.historyEntries.first?.eventKind, .scanned)
            XCTAssertEqual(record.historyEntries.first?.sourceSurface, .scan)
        }
    }

    func testApplyWorkflowStatusForDiscovery_DoesNotDowngradeExistingWorkflowStatus() throws {
        try withService { context, service in
            FeatureFlagService.shared.setEnabled(.durableWorkflowStatus, true)

            let tempDir = try TemporaryDirectory()
            let fileURL = try tempDir.createFile(name: "Inbox/already-organized.txt", contents: "organized")
            let record = try XCTUnwrap(
                service.upsertRecordWithoutSaving(
                    for: fileURL.path,
                    displayName: "already-organized.txt",
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 9_451)
                )
            )
            record.workflowStatus = .organized

            let didWriteWorkflowStatus = try service.applyWorkflowStatusForDiscoveryWithoutSaving(
                to: record,
                wasCreated: true,
                timestamp: Date(timeIntervalSince1970: 9_452)
            )
            try context.save()

            XCTAssertFalse(didWriteWorkflowStatus)
            XCTAssertEqual(record.workflowStatus, .organized)
            XCTAssertTrue(record.historyEntries.isEmpty)
        }
    }

    func testRecordTransition_OrganizedWritesWorkflowStatus() throws {
        try withService { _, service in
            FeatureFlagService.shared.setEnabled(.durableWorkflowStatus, true)

            let tempDir = try TemporaryDirectory()
            let sourceURL = try tempDir.createFile(name: "Inbox/organized.txt", contents: "organized")
            let destinationURL = tempDir.url.appendingPathComponent("Archive/organized.txt")

            let record = try XCTUnwrap(
                service.recordTransition(
                    from: sourceURL.path,
                    to: destinationURL.path,
                    displayName: "organized.txt",
                    fileExtension: "txt",
                    eventKind: .organized,
                    sourceSurface: .organize,
                    destinationDisplayName: "Archive",
                    matchedRuleID: nil,
                    timestamp: Date(timeIntervalSince1970: 9_460)
                )
            )

            XCTAssertEqual(record.workflowStatus, .organized)
        }
    }

    func testAppendIgnoredHistory_WritesIgnoredWorkflowStatusAndReviewSource() throws {
        try withService { context, service in
            FeatureFlagService.shared.setEnabled(.durableWorkflowStatus, true)

            let tempDir = try TemporaryDirectory()
            let fileURL = try tempDir.createFile(name: "Inbox/ignored.txt", contents: "ignored")
            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: fileURL.path,
                    displayName: "ignored.txt",
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 9_470)
                )
            )

            let entry = try XCTUnwrap(
                service.appendIgnoredHistory(
                    for: record,
                    detailsSummary: "Skipped during review.",
                    timestamp: Date(timeIntervalSince1970: 9_471)
                )
            )
            try context.save()

            XCTAssertEqual(record.workflowStatus, .ignored)
            XCTAssertEqual(entry.eventKind, .ignored)
            XCTAssertEqual(entry.sourceSurface, .review)
        }
    }

    func testAppendIgnoredHistory_ReturnsNilWhenDurableWorkflowStatusDisabled() throws {
        try withService { context, service in
            FeatureFlagService.shared.setEnabled(.durableWorkflowStatus, false)

            let tempDir = try TemporaryDirectory()
            let fileURL = try tempDir.createFile(name: "Inbox/ignored-disabled.txt", contents: "ignored")
            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: fileURL.path,
                    displayName: "ignored-disabled.txt",
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 9_472)
                )
            )

            let entry = try service.appendIgnoredHistory(
                for: record,
                detailsSummary: "Should not persist.",
                timestamp: Date(timeIntervalSince1970: 9_473)
            )
            try context.save()

            XCTAssertNil(entry)
            XCTAssertNil(record.workflowStatus)
            XCTAssertTrue(record.historyEntries.isEmpty)
        }
    }

    func testInspectorSummary_IncludesWorkflowStatusWhenFeatureEnabled() throws {
        try withService { context, service in
            FeatureFlagService.shared.setEnabled(.durableWorkflowStatus, true)

            let tempDir = try TemporaryDirectory()
            let fileURL = try tempDir.createFile(name: "Inbox/status.txt", contents: "status")
            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: fileURL.path,
                    displayName: "status.txt",
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 9_480)
                )
            )
            record.workflowStatus = .organized
            try context.save()

            let summary = try XCTUnwrap(service.inspectorSummary(for: fileURL.path))
            XCTAssertTrue(summary.hasWorkflowStatusSummary)
            XCTAssertEqual(summary.workflowStatusSummary, "Status: organized")
        }
    }

    func testInspectorSummary_ReturnsNilWhenFeatureDisabledOrRecordMissing() throws {
        try withService { _, service in
            let tempDir = try TemporaryDirectory()
            let trackedURL = try tempDir.createFile(name: "vault/tracked.txt", contents: "tracked")

            _ = try XCTUnwrap(
                service.upsertRecord(
                    for: trackedURL.path,
                    displayName: "tracked.txt",
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 100)
                )
            )

            FeatureFlagService.shared.setEnabled(.metadataFoundation, false)
            XCTAssertNil(service.inspectorSummary(for: trackedURL.path))

            FeatureFlagService.shared.setEnabled(.metadataFoundation, true)
            XCTAssertNil(service.inspectorSummary(for: "/Users/example/does-not-exist.txt"))
        }
    }

    func testApplyContentTags_AppendsExplicitAndInferredTagsWithoutDuplicates() throws {
        try withService { context, service in
            let tempDir = try TemporaryDirectory()
            let fileURL = try tempDir.createFile(name: "Inbox/invoice-contract.pdf", contents: "invoice")
            let rule = try insertRule(in: context, categoryName: "Invoices")
            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: fileURL.path,
                    displayName: "invoice-contract.pdf",
                    fileExtension: "pdf",
                    timestamp: Date(timeIntervalSince1970: 8_700)
                )
            )
            record.tags = ["legacy-custom"]

            let appendedTags = service.applyContentTagsWithoutSaving(
                for: record,
                displayName: "invoice-contract.pdf",
                fileExtension: "pdf",
                destinationDisplayName: "Contracts",
                matchedRuleID: rule.id
            )

            XCTAssertEqual(appendedTags, [.contract, .invoice])
            XCTAssertEqual(record.tags, ["legacy-custom", "contract", "invoice"])
        }
    }

    func testApplyContentTags_FeatureFlagDisabledSkipsWrites() throws {
        try withService { context, service in
            FeatureFlagService.shared.setEnabled(.autoContentTags, false)

            let tempDir = try TemporaryDirectory()
            let fileURL = try tempDir.createFile(name: "Inbox/invoice.pdf", contents: "invoice")
            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: fileURL.path,
                    displayName: "invoice.pdf",
                    fileExtension: "pdf",
                    timestamp: Date(timeIntervalSince1970: 8_710)
                )
            )

            let appendedTags = service.applyContentTagsWithoutSaving(
                for: record,
                displayName: "invoice.pdf",
                fileExtension: "pdf",
                destinationDisplayName: "Invoices",
                matchedRuleID: nil
            )

            XCTAssertEqual(appendedTags, [])
            XCTAssertEqual(record.tags, [])
            XCTAssertEqual(try context.fetch(FetchDescriptor<FileMetadataRecord>()).count, 1)
        }
    }

    func testApplyContentTags_DoesNotEvictStoredTagsWhenRecordIsAlreadyAtCap() throws {
        try withService { _, service in
            let tempDir = try TemporaryDirectory()
            let fileURL = try tempDir.createFile(name: "Inbox/board-deck.pptx", contents: "deck")
            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: fileURL.path,
                    displayName: "board-deck.pptx",
                    fileExtension: "pptx",
                    timestamp: Date(timeIntervalSince1970: 8_720)
                )
            )
            record.tags = ["invoice", "receipt", "contract"]

            let appendedTags = service.applyContentTagsWithoutSaving(
                for: record,
                displayName: "board-deck.pptx",
                fileExtension: "pptx",
                destinationDisplayName: "Statements",
                matchedRuleID: nil
            )

            XCTAssertEqual(appendedTags, [.statement, .presentation])
            XCTAssertEqual(
                record.tags,
                ["invoice", "receipt", "contract", "statement", "presentation"]
            )
        }
    }

    func testApplyContentTags_RecognizesAliasShapedStoredTagsWhenSuppressingDuplicates() throws {
        try withService { _, service in
            let tempDir = try TemporaryDirectory()
            let fileURL = try tempDir.createFile(name: "Inbox/invoice.pdf", contents: "invoice")
            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: fileURL.path,
                    displayName: "invoice.pdf",
                    fileExtension: "pdf",
                    timestamp: Date(timeIntervalSince1970: 8_721)
                )
            )
            record.tags = ["Invoices"]

            let appendedTags = service.applyContentTagsWithoutSaving(
                for: record,
                displayName: "invoice.pdf",
                fileExtension: "pdf",
                destinationDisplayName: "Invoices",
                matchedRuleID: nil
            )

            XCTAssertEqual(appendedTags, [])
            XCTAssertEqual(record.tags, ["Invoices"])
        }
    }

    func testRecordTransition_AppliesContentTagsWhenFeatureEnabled() throws {
        try withService { _, service in
            let tempDir = try TemporaryDirectory()
            let sourceURL = try tempDir.createFile(name: "Inbox/invoice.pdf", contents: "invoice")
            let destinationURL = tempDir.url.appendingPathComponent("Archive/invoice.pdf")

            let record = try XCTUnwrap(
                service.recordTransition(
                    from: sourceURL.path,
                    to: destinationURL.path,
                    displayName: "invoice.pdf",
                    fileExtension: "pdf",
                    eventKind: .organized,
                    sourceSurface: .organize,
                    destinationDisplayName: "Invoices",
                    matchedRuleID: nil,
                    timestamp: Date(timeIntervalSince1970: 8_725)
                )
            )

            XCTAssertEqual(record.tags, ["invoice"])
        }
    }

    func testRecordTransition_RuleCategoryTagSurvivesUndoAndRedoWithoutMatchedRuleID() throws {
        try withService { context, service in
            let rule = try insertRule(
                in: context,
                categoryName: "Contracts",
                destinationDisplayName: "Reference"
            )
            let tempDir = try TemporaryDirectory()
            let sourceURL = try tempDir.createFile(name: "Inbox/q1-summary.pdf", contents: "summary")
            let destinationURL = tempDir.url.appendingPathComponent("Archive/q1-summary.pdf")

            let organizedRecord = try XCTUnwrap(
                service.recordTransition(
                    from: sourceURL.path,
                    to: destinationURL.path,
                    displayName: "q1-summary.pdf",
                    fileExtension: "pdf",
                    eventKind: .organized,
                    sourceSurface: .organize,
                    destinationDisplayName: "Reference",
                    matchedRuleID: rule.id,
                    timestamp: Date(timeIntervalSince1970: 8_726)
                )
            )
            XCTAssertEqual(organizedRecord.tags, ["contract"])

            let undoneRecord = try XCTUnwrap(
                service.recordTransition(
                    from: destinationURL.path,
                    to: sourceURL.path,
                    displayName: "q1-summary.pdf",
                    fileExtension: "pdf",
                    eventKind: .undone,
                    sourceSurface: .undo,
                    destinationDisplayName: "Reference",
                    matchedRuleID: nil,
                    timestamp: Date(timeIntervalSince1970: 8_727)
                )
            )
            XCTAssertEqual(undoneRecord.tags, ["contract"])

            let redoneRecord = try XCTUnwrap(
                service.recordTransition(
                    from: sourceURL.path,
                    to: destinationURL.path,
                    displayName: "q1-summary.pdf",
                    fileExtension: "pdf",
                    eventKind: .organized,
                    sourceSurface: .organize,
                    destinationDisplayName: "Reference",
                    matchedRuleID: nil,
                    timestamp: Date(timeIntervalSince1970: 8_728)
                )
            )
            XCTAssertEqual(redoneRecord.tags, ["contract"])
        }
    }

    func testContentTagIndex_ReturnsBuiltInTagsForRequestedPathsOnly() throws {
        try withService { _, service in
            let tempDir = try TemporaryDirectory()
            let invoiceURL = try tempDir.createFile(name: "Inbox/invoice.pdf", contents: "invoice")
            let receiptURL = try tempDir.createFile(name: "Inbox/receipt.pdf", contents: "receipt")
            let deckURL = try tempDir.createFile(name: "Inbox/deck.pptx", contents: "deck")

            let invoiceRecord = try XCTUnwrap(
                service.upsertRecord(
                    for: invoiceURL.path,
                    displayName: "invoice.pdf",
                    fileExtension: "pdf",
                    timestamp: Date(timeIntervalSince1970: 8_730)
                )
            )
            invoiceRecord.tags = ["Invoices", "legacy-custom"]

            let receiptRecord = try XCTUnwrap(
                service.upsertRecord(
                    for: receiptURL.path,
                    displayName: "receipt.pdf",
                    fileExtension: "pdf",
                    timestamp: Date(timeIntervalSince1970: 8_731)
                )
            )
            receiptRecord.tags = ["Receipts"]

            let deckRecord = try XCTUnwrap(
                service.upsertRecord(
                    for: deckURL.path,
                    displayName: "deck.pptx",
                    fileExtension: "pptx",
                    timestamp: Date(timeIntervalSince1970: 8_732)
                )
            )
            deckRecord.tags = ["Slides"]

            let index = service.contentTagIndex(for: [invoiceURL.path, receiptURL.path])

            XCTAssertEqual(index.count, 2)
            XCTAssertEqual(index[invoiceURL.path], [.invoice])
            XCTAssertEqual(index[receiptURL.path], [.receipt])
            XCTAssertNil(index[deckURL.path])
        }
    }

    func testContentTagIndex_AutoContentTagsDisabledReturnsEmptyIndex() throws {
        try withService { _, service in
            let tempDir = try TemporaryDirectory()
            let invoiceURL = try tempDir.createFile(name: "Inbox/invoice.pdf", contents: "invoice")

            let record = try XCTUnwrap(
                service.upsertRecord(
                    for: invoiceURL.path,
                    displayName: "invoice.pdf",
                    fileExtension: "pdf",
                    timestamp: Date(timeIntervalSince1970: 8_733)
                )
            )
            record.tags = ["invoice"]

            FeatureFlagService.shared.setEnabled(.autoContentTags, false)

            XCTAssertEqual(service.contentTagIndex(for: [invoiceURL.path]), [:])
        }
    }

    func testRekeyPathFallbackRecord_WhenDestinationCollisionExists_MergesIntoExistingRecord() throws {
        try withService { context, service in
            let oldPath = "/Users/example/Downloads/Legacy/invoice.txt"
            let newPath = "/Users/example/Documents/Invoices/invoice.txt"

            let sourceRecord = try XCTUnwrap(
                service.upsertRecord(
                    for: oldPath,
                    displayName: "invoice.txt",
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 7_000)
                )
            )
            _ = try XCTUnwrap(
                service.appendHistoryEntry(
                    for: sourceRecord,
                    eventKind: .organized,
                    sourceSurface: .organize,
                    fromPath: oldPath,
                    toPath: oldPath,
                    destinationDisplayName: "Legacy",
                    matchedRuleID: nil,
                    detailsSummary: "Old path organization.",
                    timestamp: Date(timeIntervalSince1970: 7_100)
                )
            )

            let targetRecord = try XCTUnwrap(
                service.upsertRecord(
                    for: newPath,
                    displayName: "invoice.txt",
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 7_200)
                )
            )
            _ = try XCTUnwrap(
                service.appendHistoryEntry(
                    for: targetRecord,
                    eventKind: .organized,
                    sourceSurface: .organize,
                    fromPath: newPath,
                    toPath: newPath,
                    destinationDisplayName: "Invoices",
                    matchedRuleID: nil,
                    detailsSummary: "Destination already had a record.",
                    timestamp: Date(timeIntervalSince1970: 7_300)
                )
            )

            let mergedRecord = try XCTUnwrap(
                service.rekeyPathFallbackRecord(
                    oldPath: oldPath,
                    newPath: newPath,
                    timestamp: Date(timeIntervalSince1970: 7_400)
                )
            )

            let records = try context.fetch(FetchDescriptor<FileMetadataRecord>())
            XCTAssertEqual(records.count, 1)
            XCTAssertEqual(mergedRecord.canonicalIdentity, FileMetadataFoundationService.pathFallbackCanonicalIdentity(for: newPath))
            XCTAssertEqual(mergedRecord.firstSeenAt, Date(timeIntervalSince1970: 7_000))
            XCTAssertEqual(mergedRecord.lastSeenAt, Date(timeIntervalSince1970: 7_400))
            XCTAssertEqual(mergedRecord.organizationCount, 2)
            XCTAssertEqual(mergedRecord.historyEntries.count, 2)
            XCTAssertEqual(mergedRecord.historyEntries.compactMap(\.detailsSummary).sorted(), [
                "Destination already had a record.",
                "Old path organization."
            ])
        }
    }

    func testRekeyPathFallbackRecord_WhenDestinationCollisionExists_PreservesSourceAndDestinationTags() throws {
        try withService { _, service in
            let oldPath = "/Users/example/Downloads/Legacy/invoice.txt"
            let newPath = "/Users/example/Documents/Invoices/invoice.txt"

            let sourceRecord = try XCTUnwrap(
                service.upsertRecord(
                    for: oldPath,
                    displayName: "invoice.txt",
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 7_500)
                )
            )
            sourceRecord.tags = ["Invoices", "legacy-source"]

            let targetRecord = try XCTUnwrap(
                service.upsertRecord(
                    for: newPath,
                    displayName: "invoice.txt",
                    fileExtension: "txt",
                    timestamp: Date(timeIntervalSince1970: 7_600)
                )
            )
            targetRecord.tags = ["receipt", "legacy-target"]

            let mergedRecord = try XCTUnwrap(
                service.rekeyPathFallbackRecord(
                    oldPath: oldPath,
                    newPath: newPath,
                    timestamp: Date(timeIntervalSince1970: 7_700)
                )
            )

            XCTAssertEqual(
                mergedRecord.tags,
                ["receipt", "legacy-target", "Invoices", "legacy-source"]
            )
        }
    }
}
