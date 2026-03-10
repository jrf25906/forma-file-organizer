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

    func testDuplicateOverlapTakesPriorityOverWillCreate() throws {
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

            guard case .duplicateOrOverlap? = healthByID[first.id]?.kind else {
                return XCTFail("Expected duplicate/overlap for first rule")
            }

            guard case .duplicateOrOverlap? = healthByID[second.id]?.kind else {
                return XCTFail("Expected duplicate/overlap for second rule")
            }
        }
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
