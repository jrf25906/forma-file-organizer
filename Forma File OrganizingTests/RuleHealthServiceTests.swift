import XCTest
@testable import Forma_File_Organizing

@MainActor
final class RuleHealthServiceTests: XCTestCase {

    func testClassifyReadyRuleAsStaleWhenThresholdExceeded() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let rule = Rule(
            name: "Old Archive Rule",
            conditionType: .nameContains,
            conditionValue: "archive",
            actionType: .delete,
            destination: .trash
        )
        rule.lastTriggeredDate = now.addingTimeInterval(-(31 * 86_400))

        let health = RuleHealthService().classify(
            rules: [rule],
            staleRuleThresholdDays: 30,
            evaluationDate: now
        )[rule.id]

        guard case .stale? = health?.kind else {
            return XCTFail("Expected stale health state")
        }
        XCTAssertEqual(health?.badgeLabel, "Stale")
    }

    func testClassifyNeverTriggeredRuleUsesCreationDateForStaleness() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let rule = Rule(
            name: "Never Used Rule",
            conditionType: .nameContains,
            conditionValue: "unused",
            actionType: .delete,
            destination: .trash
        )
        rule.creationDate = now.addingTimeInterval(-(45 * 86_400))

        let health = RuleHealthService().classify(
            rules: [rule],
            staleRuleThresholdDays: 30,
            evaluationDate: now
        )[rule.id]

        guard case .stale? = health?.kind else {
            return XCTFail("Expected stale health state when creation date is older than the threshold")
        }
    }

    func testNeedsPermissionTakesPriorityOverStale() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let rule = Rule(
            name: "Broken Archive Rule",
            conditionType: .nameContains,
            conditionValue: "archive",
            actionType: .move,
            destination: .folder(bookmark: Data(), displayName: "ExternalDrive/Archive")
        )
        rule.lastTriggeredDate = now.addingTimeInterval(-(45 * 86_400))

        let health = RuleHealthService().classify(
            rules: [rule],
            staleRuleThresholdDays: 30,
            evaluationDate: now
        )[rule.id]

        guard case .needsPermission? = health?.kind else {
            return XCTFail("Expected needsPermission to take priority over stale")
        }
    }

    func testFolderHealthAlertServiceFlagsFolderAtOrAboveThreshold() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let downloadsRoot = try TemporaryDirectory()
        defer { downloadsRoot.cleanup() }
        let store = InMemoryBookmarkStore()
        let destination = try Destination.folder(from: downloadsRoot.url, displayName: "Downloads")
        try store.saveBookmark(
            try XCTUnwrap(destination.bookmarkData),
            forKey: FormaConfig.Security.downloadsBookmarkKey
        )

        let downloadsFile = FileItem(
            path: downloadsRoot.url.appendingPathComponent("archive.zip").path,
            sizeInBytes: 10 * 1024 * 1024 * 1024,
            creationDate: now,
            location: .downloads,
            scanRootPath: downloadsRoot.url.path
        )

        let evaluation = try BookmarkStoreProvider.$override.withValue(store) {
            FolderHealthAlertService().evaluate(
                files: [downloadsFile],
                rules: [],
                settings: FolderHealthAlertSettings(
                    folderSizeThresholdBytesByFolder: [.downloads: 10 * 1024 * 1024 * 1024],
                    staleRuleThresholdDays: nil
                ),
                monitoredRootPathsByFolder: [.downloads: downloadsRoot.url.standardizedFileURL.path],
                now: now
            )
        }

        XCTAssertEqual(evaluation.folderSizeAlerts.map(\.folderType), [.downloads])
        XCTAssertNil(evaluation.staleRuleAlert)
    }

    func testFolderHealthAlertServiceIgnoresInaccessibleFolders() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let downloadsFile = FileItem(
            path: "/Users/test/Downloads/archive.zip",
            sizeInBytes: 12 * 1024 * 1024 * 1024,
            creationDate: now,
            location: .downloads,
            scanRootPath: "/Users/test/Downloads"
        )

        let evaluation = FolderHealthAlertService().evaluate(
            files: [downloadsFile],
            rules: [],
            settings: FolderHealthAlertSettings(
                folderSizeThresholdBytesByFolder: [.downloads: 10 * 1024 * 1024 * 1024],
                staleRuleThresholdDays: nil
            ),
            monitoredRootPathsByFolder: [:],
            now: now
        )

        XCTAssertTrue(evaluation.folderSizeAlerts.isEmpty)
    }

    func testFolderHealthAlertServiceBuildsStaleRulesSummaryFromHealthyRulesOnly() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let healthyRule = Rule(
            name: "Healthy But Stale",
            conditionType: .nameContains,
            conditionValue: "archive",
            actionType: .delete,
            destination: .trash
        )
        healthyRule.lastTriggeredDate = now.addingTimeInterval(-(45 * 86_400))

        let brokenRule = Rule(
            name: "Broken And Old",
            conditionType: .nameContains,
            conditionValue: "broken",
            actionType: .move,
            destination: .folder(bookmark: Data(), displayName: "ExternalDrive/Broken")
        )
        brokenRule.lastTriggeredDate = now.addingTimeInterval(-(45 * 86_400))

        let evaluation = FolderHealthAlertService().evaluate(
            files: [],
            rules: [healthyRule, brokenRule],
            settings: FolderHealthAlertSettings(
                folderSizeThresholdBytesByFolder: [:],
                staleRuleThresholdDays: 30
            ),
            monitoredRootPathsByFolder: [:],
            now: now
        )

        XCTAssertEqual(evaluation.staleRuleAlert?.rules.map(\.ruleName), ["Healthy But Stale"])
    }

    func testClassifyResolvablePlaceholderAsWillCreate() throws {
        let tempDir = try TemporaryDirectory()
        defer { tempDir.cleanup() }

        let documentsRoot = try Destination.folder(from: tempDir.url, displayName: "Documents")
        let store = InMemoryBookmarkStore()
        try store.saveBookmark(
            try XCTUnwrap(documentsRoot.bookmarkData),
            forKey: FormaConfig.Security.documentsBookmarkKey
        )

        try BookmarkStoreProvider.$override.withValue(store) {
            let rule = Rule(
                name: "Health Records",
                conditionType: .nameContains,
                conditionValue: "health",
                actionType: .move,
                destination: .folder(bookmark: Data(), displayName: "Documents/Areas/Health")
            )

            let health = RuleHealthService().classify(rules: [rule])[rule.id]
            guard case .willCreate? = health?.kind else {
                return XCTFail("Expected willCreate health state, got \(String(describing: health?.badgeLabel))")
            }
        }
    }

    func testDuplicateTakesPriorityOverWillCreate() throws {
        let tempDir = try TemporaryDirectory()
        defer { tempDir.cleanup() }

        let documentsRoot = try Destination.folder(from: tempDir.url, displayName: "Documents")
        let store = InMemoryBookmarkStore()
        try store.saveBookmark(
            try XCTUnwrap(documentsRoot.bookmarkData),
            forKey: FormaConfig.Security.documentsBookmarkKey
        )

        try BookmarkStoreProvider.$override.withValue(store) {
            let first = Rule(
                name: "Health Records A",
                conditionType: .nameContains,
                conditionValue: "health",
                actionType: .move,
                destination: .folder(bookmark: Data(), displayName: "Documents/Areas/Health")
            )
            let second = Rule(
                name: "Health Records B",
                conditionType: .nameContains,
                conditionValue: "health",
                actionType: .move,
                destination: .folder(bookmark: Data(), displayName: "Documents/Areas/Health")
            )

            let healthByID = RuleHealthService().classify(rules: [first, second])

            guard case .duplicate? = healthByID[first.id]?.kind else {
                return XCTFail("Expected duplicate for first rule")
            }

            guard case .duplicate? = healthByID[second.id]?.kind else {
                return XCTFail("Expected duplicate for second rule")
            }
        }
    }

    func testConflictingDestinationsClassifyAsOverlap() throws {
        let tempDir = try TemporaryDirectory()
        defer { tempDir.cleanup() }

        let documentsRoot = try Destination.folder(from: tempDir.url, displayName: "Documents")
        let store = InMemoryBookmarkStore()
        try store.saveBookmark(
            try XCTUnwrap(documentsRoot.bookmarkData),
            forKey: FormaConfig.Security.documentsBookmarkKey
        )

        try BookmarkStoreProvider.$override.withValue(store) {
            let first = Rule(
                name: "Screenshot Archive A",
                conditionType: .nameStartsWith,
                conditionValue: "Screenshot",
                actionType: .move,
                destination: .folder(bookmark: Data(), displayName: "Documents/Screenshots")
            )
            let second = Rule(
                name: "Screenshot Archive B",
                conditionType: .nameStartsWith,
                conditionValue: "Screenshot",
                actionType: .move,
                destination: .folder(bookmark: Data(), displayName: "Documents/Review")
            )

            let healthByID = RuleHealthService().classify(rules: [first, second])

            guard case .overlap? = healthByID[first.id]?.kind else {
                return XCTFail("Expected overlap for first rule")
            }

            XCTAssertEqual(healthByID[first.id]?.badgeLabel, "Conflict")

            guard case .overlap? = healthByID[second.id]?.kind else {
                return XCTFail("Expected overlap for second rule")
            }
        }
    }

    func testExactDuplicateCleanupPlanKeepsOneRulePerSignature() {
        let original = Rule(
            name: "Health Records A",
            conditionType: .nameContains,
            conditionValue: "health",
            actionType: .move,
            destination: .folder(bookmark: Data(), displayName: "Documents/Areas/Health"),
            sortOrder: 0
        )
        let duplicate = Rule(
            name: "Health Records B",
            conditionType: .nameContains,
            conditionValue: "health",
            actionType: .move,
            destination: .folder(bookmark: Data(), displayName: "Documents/Areas/Health"),
            sortOrder: 1
        )
        let unrelated = Rule(
            name: "Tax Documents",
            conditionType: .nameContains,
            conditionValue: "tax",
            actionType: .move,
            destination: .folder(bookmark: Data(), displayName: "Documents/Areas/Finance/Taxes")
        )

        let healthService = RuleHealthService()
        let healthByID = healthService.classify(rules: [original, duplicate, unrelated])
        let duplicateRules = [original, duplicate, unrelated].filter {
            healthByID[$0.id]?.kind == .duplicate
        }
        let cleanupPlan = healthService.exactDuplicateCleanupPlan(duplicateRules: duplicateRules)

        XCTAssertEqual(cleanupPlan?.duplicateCount, 1)
        XCTAssertEqual(cleanupPlan?.preservedRuleCount, 1)
        XCTAssertEqual(cleanupPlan?.groups.first?.keeperRuleID, original.id)
        XCTAssertEqual(cleanupPlan?.groups.first?.duplicateRuleIDs, [duplicate.id])
    }

    func testClassifyUnresolvablePlaceholderAsNeedsPermission() {
        let rule = Rule(
            name: "External Archive",
            conditionType: .nameContains,
            conditionValue: "archive",
            actionType: .move,
            destination: .folder(bookmark: Data(), displayName: "ExternalDrive/Archive")
        )

        let health = RuleHealthService().classify(rules: [rule])[rule.id]
        guard case .needsPermission? = health?.kind else {
            return XCTFail("Expected needsPermission health state")
        }
    }
}
