import XCTest
@testable import Forma_File_Organizing

@MainActor
final class RuleHealthServiceTests: XCTestCase {

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
