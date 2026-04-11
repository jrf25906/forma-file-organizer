import XCTest
import SwiftData
import Combine
@testable import Forma_File_Organizing

@MainActor
final class RuleServiceTests: XCTestCase {

    private var ruleService: RuleService!
    private var modelContainer: ModelContainer!
    private var modelContext: ModelContext!
    private var cancellables: Set<AnyCancellable> = []

    override func setUp() async throws {
        try await super.setUp()

        let schema = Schema([Rule.self, FileItem.self, ActivityItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = modelContainer.mainContext
        ruleService = RuleService(modelContext: modelContext)
        cancellables = []
    }

    override func tearDown() async throws {
        await MainActor.run {
            cancellables.removeAll()
            ruleService = nil
            modelContext = nil
            modelContainer = nil
        }
        try await super.tearDown()
    }

    func testCreateRulePersistsAndPublishesCreatedEvent() throws {
        let createdExpectation = expectation(description: "created event")
        var createdRuleName: String?

        ruleService.ruleChanges
            .sink { event in
                if case .created(let rule) = event {
                    createdRuleName = rule.name
                    createdExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        let rule = makeRule(name: "Test Rule", conditionValue: "invoice")
        try ruleService.createRule(rule, source: .ruleEditor)

        wait(for: [createdExpectation], timeout: 1.0)

        let fetched = try ruleService.fetchRules()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Test Rule")
        XCTAssertEqual(createdRuleName, "Test Rule")
        XCTAssertEqual(ruleService.ruleCount, 1)
    }

    func testFetchRulesReturnsAlphabeticallySortedRules() throws {
        try ruleService.createRule(makeRule(name: "Z Rule", conditionValue: "z"), source: .ruleEditor)
        try ruleService.createRule(makeRule(name: "A Rule", conditionValue: "a"), source: .ruleEditor)
        try ruleService.createRule(makeRule(name: "M Rule", conditionValue: "m"), source: .ruleEditor)

        let fetched = try ruleService.fetchRules()
        XCTAssertEqual(fetched.map(\.name), ["A Rule", "M Rule", "Z Rule"])
    }

    func testUpdateRulePersistsAndPublishesUpdatedEvent() throws {
        let rule = makeRule(name: "Original", conditionValue: "invoice")
        try ruleService.createRule(rule, source: .ruleEditor)

        let updatedExpectation = expectation(description: "updated event")
        var updatedRuleName: String?

        ruleService.ruleChanges
            .sink { event in
                if case .updated(let updatedRule) = event {
                    updatedRuleName = updatedRule.name
                    updatedExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        rule.name = "Updated"
        rule.destination = .folder(bookmark: Data(), displayName: "UpdatedDestination")
        try ruleService.updateRule(rule)

        wait(for: [updatedExpectation], timeout: 1.0)

        let fetched = try ruleService.fetchRules()
        XCTAssertEqual(fetched.first?.name, "Updated")
        XCTAssertEqual(fetched.first?.destination?.displayName, "UpdatedDestination")
        XCTAssertEqual(updatedRuleName, "Updated")
    }

    func testDeleteRuleRemovesAndPublishesDeletedEvent() throws {
        let rule = makeRule(name: "To Delete", conditionValue: "temp")
        try ruleService.createRule(rule, source: .ruleEditor)

        let deletedExpectation = expectation(description: "deleted event")
        var deletedRuleName: String?

        ruleService.ruleChanges
            .sink { event in
                if case .deleted(let ruleName) = event {
                    deletedRuleName = ruleName
                    deletedExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        try ruleService.deleteRule(rule)

        wait(for: [deletedExpectation], timeout: 1.0)

        let fetched = try ruleService.fetchRules()
        XCTAssertTrue(fetched.isEmpty)
        XCTAssertEqual(deletedRuleName, "To Delete")
        XCTAssertEqual(ruleService.ruleCount, 0)
    }

    func testCreateRulesBatchPersistsAndPublishesBulkCreatedEvent() throws {
        let bulkExpectation = expectation(description: "bulk created event")
        var bulkCount: Int?

        ruleService.ruleChanges
            .sink { event in
                if case .bulkCreated(let count) = event {
                    bulkCount = count
                    bulkExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        let rules = [
            makeRule(name: "Batch A", conditionValue: "invoice"),
            makeRule(name: "Batch B", conditionValue: "report"),
            makeRule(name: "Batch C", conditionValue: "contract")
        ]

        try ruleService.createRules(rules, source: .template(name: "Test Template"))

        wait(for: [bulkExpectation], timeout: 1.0)

        let fetched = try ruleService.fetchRules()
        XCTAssertEqual(fetched.count, 3)
        XCTAssertEqual(bulkCount, 3)
    }

    func testCreateRuleSkipsSemanticDuplicateAlreadyPersisted() throws {
        let original = makeRule(name: "Original Name", conditionValue: "invoice")
        try ruleService.createRule(original, source: .ruleEditor)

        let semanticDuplicate = makeRule(name: "Different Name", conditionValue: "invoice")
        try ruleService.createRule(semanticDuplicate, source: .quickSheet)

        let fetched = try ruleService.fetchRules()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.name, "Original Name")
    }

    func testCreateRulesBatchSkipsSemanticDuplicatesInStoreAndWithinBatch() throws {
        let existingRule = makeRule(name: "Existing", conditionValue: "report")
        try ruleService.createRule(existingRule, source: .ruleEditor)

        let duplicateOfExisting = makeRule(name: "Same Behavior Existing Duplicate", conditionValue: "report")
        let duplicateWithinBatchA = makeRule(name: "Batch Duplicate A", conditionValue: "contract")
        let duplicateWithinBatchB = makeRule(name: "Batch Duplicate B", conditionValue: "contract")
        let uniqueRule = makeRule(name: "Unique", conditionValue: "proposal")

        try ruleService.createRules(
            [duplicateOfExisting, duplicateWithinBatchA, duplicateWithinBatchB, uniqueRule],
            source: .template(name: "Test Template")
        )

        let fetched = try ruleService.fetchRules()
        XCTAssertEqual(fetched.count, 3)
        XCTAssertEqual(fetched.filter { $0.conditions == [RuleCondition.nameContains("report")] }.count, 1)
        XCTAssertEqual(fetched.filter { $0.conditions == [RuleCondition.nameContains("contract")] }.count, 1)
        XCTAssertEqual(fetched.filter { $0.conditions == [RuleCondition.nameContains("proposal")] }.count, 1)
    }

    func testCreateRuleDoesNotCollapseDistinctFoldersSharingDisplayName() throws {
        let firstRoot = try TemporaryDirectory()
        let secondRoot = try TemporaryDirectory()
        defer {
            firstRoot.cleanup()
            secondRoot.cleanup()
        }

        let firstDestination = try Destination.folder(from: try firstRoot.createDirectory(name: "Shared"))
        let secondDestination = try Destination.folder(from: try secondRoot.createDirectory(name: "Shared"))

        let firstRule = Rule(
            name: "Shared Folder A",
            conditionType: .fileExtension,
            conditionValue: "pdf",
            actionType: .move,
            destination: firstDestination
        )
        let secondRule = Rule(
            name: "Shared Folder B",
            conditionType: .fileExtension,
            conditionValue: "pdf",
            actionType: .move,
            destination: secondDestination
        )

        try ruleService.createRule(firstRule, source: .ruleEditor)
        try ruleService.createRule(secondRule, source: .ruleEditor)

        let fetched = try ruleService.fetchRules()
        XCTAssertEqual(fetched.count, 2)
        XCTAssertNotNil(
            try ruleService.findMatchingMoveRule(
                conditions: firstRule.conditions,
                logicalOperator: firstRule.logicalOperator,
                destination: firstDestination
            )
        )
        XCTAssertNotNil(
            try ruleService.findMatchingMoveRule(
                conditions: secondRule.conditions,
                logicalOperator: secondRule.logicalOperator,
                destination: secondDestination
            )
        )
    }

    func testDeleteRulesBatchRemovesAndPublishesBulkDeletedEvent() throws {
        let rules = [
            makeRule(name: "Delete A", conditionValue: "invoice"),
            makeRule(name: "Delete B", conditionValue: "report")
        ]
        try ruleService.createRules(rules, source: .template(name: "Test Template"))

        let bulkExpectation = expectation(description: "bulk deleted event")
        var bulkCount: Int?

        ruleService.ruleChanges
            .sink { event in
                if case .bulkDeleted(let count) = event {
                    bulkCount = count
                    bulkExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        try ruleService.deleteRules(rules)

        wait(for: [bulkExpectation], timeout: 1.0)

        let fetched = try ruleService.fetchRules()
        XCTAssertTrue(fetched.isEmpty)
        XCTAssertEqual(bulkCount, 2)
    }

    func testSeedDefaultRulesIsIdempotentAndCreatesMixedActions() throws {
        try ruleService.seedDefaultRules()
        let firstSeed = try ruleService.fetchRules()

        XCTAssertFalse(firstSeed.isEmpty)
        XCTAssertTrue(firstSeed.contains { $0.actionType == .move })
        XCTAssertTrue(firstSeed.contains { $0.actionType == .delete })

        for rule in firstSeed where rule.actionType == .move {
            XCTAssertNotNil(rule.destination, "Move rule '\(rule.name)' should have destination")
        }

        let firstNames = Set(firstSeed.map(\.name))

        try ruleService.seedDefaultRules()
        let secondSeed = try ruleService.fetchRules()
        let secondNames = Set(secondSeed.map(\.name))

        XCTAssertEqual(secondSeed.count, firstSeed.count)
        XCTAssertEqual(secondNames, firstNames)
    }

    func testAddTemplateRulesSkipsSemanticDuplicateWithExistingRule() throws {
        let existing = Rule(
            name: "Already Have This",
            conditionType: .fileExtension,
            conditionValue: "dmg",
            actionType: .delete
        )
        try ruleService.createRule(existing, source: .ruleEditor)

        try ruleService.addTemplateRules(template: .minimal)
        let fetched = try ruleService.fetchRules()

        let minimalTemplateRuleCount = OrganizationTemplate.minimal.generateRules().count
        XCTAssertEqual(fetched.count, minimalTemplateRuleCount)
        XCTAssertEqual(
            fetched.filter { $0.actionType == .delete && $0.conditions == [RuleCondition.fileExtension("dmg")] }.count,
            1
        )
    }

    func testRestoreDeletedScreenshotRuleIfNeededRestoresRecentlyDeletedActiveRule() throws {
        let applied = ActivityItem(
            activityType: .ruleApplied,
            fileName: "Screenshot Sweeper",
            details: "Applied to 2 file(s)"
        )
        applied.timestamp = Date().addingTimeInterval(-3_600)

        let deleted = ActivityItem(
            activityType: .ruleDeleted,
            fileName: "Screenshot Sweeper",
            details: "Rule removed"
        )
        deleted.timestamp = Date().addingTimeInterval(-1_800)

        modelContext.insert(applied)
        modelContext.insert(deleted)
        try modelContext.save()

        let restored = try ruleService.restoreDeletedScreenshotRuleIfNeeded()
        let rules = try ruleService.fetchRules()

        XCTAssertTrue(restored)
        XCTAssertEqual(rules.filter { $0.name == "Screenshot Sweeper" }.count, 1)
        XCTAssertEqual(rules.first(where: { $0.name == "Screenshot Sweeper" })?.destination?.displayName, "Pictures/Screenshots")
    }

    func testRestoreDeletedScreenshotRuleIfNeededSkipsOldDeletion() throws {
        let applied = ActivityItem(
            activityType: .ruleApplied,
            fileName: "Screenshot Sweeper",
            details: "Applied to 2 file(s)"
        )
        applied.timestamp = Date().addingTimeInterval(-4 * 86_400)

        let deleted = ActivityItem(
            activityType: .ruleDeleted,
            fileName: "Screenshot Sweeper",
            details: "Rule removed"
        )
        deleted.timestamp = Date().addingTimeInterval(-3 * 86_400)

        modelContext.insert(applied)
        modelContext.insert(deleted)
        try modelContext.save()

        let restored = try ruleService.restoreDeletedScreenshotRuleIfNeeded()

        XCTAssertFalse(restored)
        XCTAssertFalse(try ruleService.fetchRules().contains { $0.name == "Screenshot Sweeper" })
    }

    // MARK: - Helpers

    private func makeRule(name: String, conditionValue: String) -> Rule {
        Rule(
            name: name,
            conditionType: .nameContains,
            conditionValue: conditionValue,
            actionType: .move,
            destination: .folder(bookmark: Data(), displayName: "Documents/Test")
        )
    }
}
