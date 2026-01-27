//
//  RuleServiceTests.swift
//  Forma File OrganizingTests
//
//  Created by James Farmer on 11/19/25.
//

import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class RuleServiceTests: XCTestCase {

    var ruleService: RuleService!
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory model container with required models
        let schema = Schema([Rule.self, FileItem.self, ActivityItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = modelContainer.mainContext
        ruleService = RuleService(modelContext: modelContext)
    }

    override func tearDown() {
        ruleService = nil
        modelContext = nil
        modelContainer = nil
        super.tearDown()
    }

    func testAddRule() throws {
        let rule = Rule(name: "Test Rule", conditionType: .nameStartsWith, conditionValue: "Test", actionType: .move, destination: .folder(bookmark: Data(), displayName: "TestFolder"))

        ruleService.addRule(rule)

        let fetchedRules = try ruleService.fetchRules()
        XCTAssertEqual(fetchedRules.count, 1)
        XCTAssertEqual(fetchedRules.first?.name, "Test Rule")
    }

    func testDeleteRule() throws {
        let rule = Rule(name: "Test Rule", conditionType: .nameStartsWith, conditionValue: "Test", actionType: .move, destination: .folder(bookmark: Data(), displayName: "TestFolder"))
        ruleService.addRule(rule)

        try ruleService.deleteRule(rule)

        let fetchedRules = try ruleService.fetchRules()
        XCTAssertTrue(fetchedRules.isEmpty)
    }

    func testFetchRules() throws {
        let rule1 = Rule(name: "Rule 1", conditionType: .nameStartsWith, conditionValue: "A", actionType: .move, destination: .folder(bookmark: Data(), displayName: "A"))
        let rule2 = Rule(name: "Rule 2", conditionType: .nameStartsWith, conditionValue: "B", actionType: .move, destination: .folder(bookmark: Data(), displayName: "B"))

        ruleService.addRule(rule1)
        ruleService.addRule(rule2)

        let fetchedRules = try ruleService.fetchRules()
        XCTAssertEqual(fetchedRules.count, 2)
    }
    
    func testSeedDefaultRules() throws {
        try ruleService.seedDefaultRules()
        
        let fetchedRules = try ruleService.fetchRules()
        XCTAssertFalse(fetchedRules.isEmpty)
        XCTAssertTrue(fetchedRules.count > 10) // Assuming there are more than 10 default rules
    }
    
    func testSeedDefaultRulesOnlyOnce() throws {
        try ruleService.seedDefaultRules()
        let countAfterFirstSeed = try ruleService.fetchRules().count
        
        try ruleService.seedDefaultRules()
        let countAfterSecondSeed = try ruleService.fetchRules().count
        
        XCTAssertEqual(countAfterFirstSeed, countAfterSecondSeed)
    }
    func testUpdateRule() throws {
        let rule = Rule(name: "Original Name", conditionType: .nameStartsWith, conditionValue: "A", actionType: .move, destination: .folder(bookmark: Data(), displayName: "A"))
        ruleService.addRule(rule)

        // Modify the rule
        rule.name = "Updated Name"
        rule.destination = .folder(bookmark: Data(), displayName: "B")

        // Save context (although in-memory context might auto-save or not need explicit save for fetch to see changes in same context,
        // but good to verify persistence logic if we were using a real stack. Here we just check if the object updates are reflected).
        try modelContext.save()

        let fetchedRules = try ruleService.fetchRules()
        let updatedRule = fetchedRules.first

        XCTAssertEqual(updatedRule?.name, "Updated Name")
        XCTAssertEqual(updatedRule?.destination?.displayName, "B")
    }
}
