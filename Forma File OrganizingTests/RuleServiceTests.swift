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

    override func tearDown() {
        cancellables.removeAll()
        ruleService = nil
        modelContext = nil
        modelContainer = nil
        super.tearDown()
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
