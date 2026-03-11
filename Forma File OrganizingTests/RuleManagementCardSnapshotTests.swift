import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class RuleManagementCardSnapshotTests: XCTestCase {
    func testSnapshotForSingleConditionRule_UsesLegacyDescription() {
        let rule = Rule(
            name: "Screenshot Sweeper",
            conditionType: .nameContains,
            conditionValue: "Screenshot",
            actionType: .move,
            destination: .mockFolder("Pictures/Screenshots")
        )

        let snapshot = RuleManagementCard.Snapshot(rule: rule)

        XCTAssertEqual(snapshot.name, "Screenshot Sweeper")
        XCTAssertEqual(snapshot.iconName, "text.quote")
        XCTAssertEqual(snapshot.destinationDisplayText, "Pictures/Screenshots")

        switch snapshot.description {
        case .legacy(let typeLabel, let value):
            XCTAssertEqual(typeLabel, "Name Contains")
            XCTAssertEqual(value, "Screenshot")
        case .compound:
            XCTFail("Expected single-condition rules to use the legacy description.")
        }
    }

    func testSnapshotForCompoundRule_UsesCompoundDescription() {
        let rule = Rule(
            name: "Archive Old PDFs",
            conditions: [
                .fileExtension("pdf"),
                .dateOlderThan(days: 30, extension: nil)
            ],
            logicalOperator: .and,
            actionType: .move,
            destination: .mockFolder("Documents/Archive")
        )

        let snapshot = RuleManagementCard.Snapshot(rule: rule)

        switch snapshot.description {
        case .compound:
            XCTAssertEqual(snapshot.iconName, "doc.text")
        case .legacy:
            XCTFail("Expected compound rules to render a compound summary.")
        }
    }

    func testSnapshotRemainsUsableAfterRuleDeletion() throws {
        let schema = Schema([Rule.self, RuleCategory.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let rule = Rule(
            name: "Temp Cleanup",
            conditionType: .fileExtension,
            conditionValue: "tmp",
            actionType: .delete,
            destination: .trash
        )
        context.insert(rule)
        try context.save()

        let snapshot = RuleManagementCard.Snapshot(rule: rule)

        context.delete(rule)
        try context.save()

        XCTAssertEqual(snapshot.name, "Temp Cleanup")
        XCTAssertEqual(snapshot.destinationDisplayText, "Delete")

        switch snapshot.description {
        case .legacy(let typeLabel, let value):
            XCTAssertEqual(typeLabel, "File Extension")
            XCTAssertEqual(value, "tmp")
        case .compound:
            XCTFail("Expected delete rule snapshot to preserve legacy description data.")
        }
    }
}
