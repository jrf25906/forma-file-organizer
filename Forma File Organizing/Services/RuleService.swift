import Foundation
import SwiftData
import Combine

/// Service responsible for managing `Rule` entities.
///
/// This is the **single source of truth** for all rule operations. All rule creation,
/// updates, and deletions should go through this service to ensure:
/// - Consistent activity logging
/// - Automatic observer notification
/// - Proper persistence handling
///
/// ## Usage
/// ```swift
/// let ruleService = RuleService(modelContext: context)
/// try ruleService.createRule(rule, source: .ruleEditor)
/// ```
@MainActor
class RuleService: ObservableObject {

    // MARK: - Types

    /// Describes where a rule was created from (for activity logging)
    enum RuleSource {
        case ruleEditor
        case inlineBuilder
        case quickSheet
        case naturalLanguage(text: String)
        case template(name: String)
        case defaultSeeding
        case learnedPattern

        var activityDescription: String {
            switch self {
            case .ruleEditor:
                return "Created in Rule Editor"
            case .inlineBuilder:
                return "Created with Inline Builder"
            case .quickSheet:
                return "Created via Quick Rule Sheet"
            case .naturalLanguage(let text):
                let shortText = text.count > 80 ? String(text.prefix(80)) + "…" : text
                return "From natural language: \"\(shortText)\""
            case .template(let name):
                return "From template: \(name)"
            case .defaultSeeding:
                return "Default rule"
            case .learnedPattern:
                return "Learned from file patterns"
            }
        }
    }

    /// Events published when rules change
    enum RuleChangeEvent {
        case created(Rule)
        case updated(Rule)
        case deleted(ruleName: String)
        case bulkCreated(count: Int)
        case bulkDeleted(count: Int)
    }

    // MARK: - Properties

    private let modelContext: ModelContext

    /// Publisher for rule change events. Views can subscribe to react to changes.
    let ruleChanges = PassthroughSubject<RuleChangeEvent, Never>()

    /// Published rule count for SwiftUI observation
    @Published private(set) var ruleCount: Int = 0

    // MARK: - Initialization

    /// Initializes the service with a SwiftData model context.
    /// - Parameter modelContext: The context used for database operations.
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        updateRuleCount()
    }

    // MARK: - Fetch

    /// Fetches all rules from the database, sorted by name.
    /// - Returns: An array of `Rule` objects.
    /// - Throws: An error if the fetch fails.
    func fetchRules() throws -> [Rule] {
        let descriptor = FetchDescriptor<Rule>(sortBy: [SortDescriptor(\Rule.name)])
        return try modelContext.fetch(descriptor)
    }

    /// Fetches only enabled rules, sorted by name.
    /// - Returns: An array of enabled `Rule` objects.
    /// - Throws: An error if the fetch fails.
    func fetchEnabledRules() throws -> [Rule] {
        let descriptor = FetchDescriptor<Rule>(
            predicate: #Predicate<Rule> { $0.isEnabled },
            sortBy: [SortDescriptor(\Rule.name)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetches rules sorted by priority for rule engine evaluation.
    ///
    /// Rules are sorted by `sortOrder` (ascending) so that lower values are
    /// evaluated first (higher priority). Within the same sortOrder, rules are
    /// sorted by `creationDate` (ascending) for deterministic ordering.
    ///
    /// This is the preferred method for getting rules to pass to RuleEngine.
    ///
    /// - Parameter enabledOnly: If true, only returns enabled rules (default: true).
    /// - Returns: An array of `Rule` objects sorted by priority.
    /// - Throws: An error if the fetch fails.
    func fetchRulesByPriority(enabledOnly: Bool = true) throws -> [Rule] {
        var descriptor: FetchDescriptor<Rule>

        if enabledOnly {
            descriptor = FetchDescriptor<Rule>(
                predicate: #Predicate<Rule> { $0.isEnabled },
                sortBy: [
                    SortDescriptor(\Rule.sortOrder, order: .forward),
                    SortDescriptor(\Rule.creationDate, order: .forward)
                ]
            )
        } else {
            descriptor = FetchDescriptor<Rule>(
                sortBy: [
                    SortDescriptor(\Rule.sortOrder, order: .forward),
                    SortDescriptor(\Rule.creationDate, order: .forward)
                ]
            )
        }

        return try modelContext.fetch(descriptor)
    }

    /// Updates the sort order of multiple rules atomically.
    ///
    /// Use this when reordering rules via drag-and-drop in the UI.
    /// Each rule's sortOrder is updated to match its position in the provided array.
    ///
    /// - Parameter rules: Rules in their new priority order (index 0 = highest priority).
    /// - Throws: An error if saving fails.
    func updateRulePriorities(_ rules: [Rule]) throws {
        for (index, rule) in rules.enumerated() {
            rule.sortOrder = index
        }

        let activityService = ActivityLoggingService(modelContext: modelContext)
        activityService.logRulePrioritiesUpdated(count: rules.count)

        try modelContext.save()

        #if DEBUG
        Log.info("RuleService: Updated priorities for \(rules.count) rules", category: .analytics)
        #endif
    }

    // MARK: - Create

    /// Creates and persists a new rule with activity logging.
    ///
    /// This is the preferred method for creating rules. It handles:
    /// - Inserting the rule into the database
    /// - Logging the creation to the activity timeline
    /// - Notifying observers of the change
    /// - Saving the context
    ///
    /// - Parameters:
    ///   - rule: The rule to create.
    ///   - source: Where the rule was created from (for activity logging).
    ///   - save: Whether to save the context immediately (default: true).
    /// - Throws: An error if saving fails.
    func createRule(_ rule: Rule, source: RuleSource, save: Bool = true) throws {
        modelContext.insert(rule)

        // Log activity
        let activityService = ActivityLoggingService(modelContext: modelContext)
        activityService.logRuleCreated(ruleName: rule.name, conditionSummary: source.activityDescription)

        if save {
            try modelContext.save()
        }

        updateRuleCount()
        ruleChanges.send(.created(rule))

        #if DEBUG
        Log.info("RuleService: Created rule '\(rule.name)' from \(source.activityDescription)", category: .analytics)
        #endif
    }

    /// Creates multiple rules in a batch operation.
    ///
    /// More efficient than calling `createRule` multiple times as it only
    /// saves once and sends a single bulk event.
    ///
    /// - Parameters:
    ///   - rules: The rules to create.
    ///   - source: Where the rules were created from.
    /// - Throws: An error if saving fails.
    func createRules(_ rules: [Rule], source: RuleSource) throws {
        guard !rules.isEmpty else { return }

        for rule in rules {
            modelContext.insert(rule)
        }

        // Log bulk activity
        let activityService = ActivityLoggingService(modelContext: modelContext)
        activityService.logBulkRulesCreated(count: rules.count, source: source.activityDescription)

        try modelContext.save()
        updateRuleCount()
        ruleChanges.send(.bulkCreated(count: rules.count))

        #if DEBUG
        Log.info("RuleService: Created \(rules.count) rules from \(source.activityDescription)", category: .analytics)
        #endif
    }

    // MARK: - Update

    /// Saves changes to an existing rule with activity logging.
    ///
    /// Call this after modifying a rule's properties to persist changes
    /// and notify observers.
    ///
    /// - Parameter rule: The rule that was modified.
    /// - Throws: An error if saving fails.
    func updateRule(_ rule: Rule) throws {
        let activityService = ActivityLoggingService(modelContext: modelContext)
        activityService.logRuleUpdated(ruleName: rule.name)

        try modelContext.save()
        ruleChanges.send(.updated(rule))

        #if DEBUG
        Log.info("RuleService: Updated rule '\(rule.name)'", category: .analytics)
        #endif
    }

    // MARK: - Delete

    /// Deletes a rule with activity logging.
    ///
    /// - Parameters:
    ///   - rule: The rule to delete.
    ///   - save: Whether to save the context immediately (default: true).
    /// - Throws: An error if saving fails.
    func deleteRule(_ rule: Rule, save: Bool = true) throws {
        let ruleName = rule.name

        let activityService = ActivityLoggingService(modelContext: modelContext)
        activityService.logRuleDeleted(ruleName: ruleName)

        modelContext.delete(rule)

        if save {
            try modelContext.save()
        }

        updateRuleCount()
        ruleChanges.send(.deleted(ruleName: ruleName))

        #if DEBUG
        Log.info("RuleService: Deleted rule '\(ruleName)'", category: .analytics)
        #endif
    }

    /// Deletes multiple rules in a batch operation.
    ///
    /// - Parameter rules: The rules to delete.
    /// - Throws: An error if saving fails.
    func deleteRules(_ rules: [Rule]) throws {
        guard !rules.isEmpty else { return }

        for rule in rules {
            modelContext.delete(rule)
        }

        let activityService = ActivityLoggingService(modelContext: modelContext)
        activityService.logBulkRulesDeleted(count: rules.count)

        try modelContext.save()
        updateRuleCount()
        ruleChanges.send(.bulkDeleted(count: rules.count))

        #if DEBUG
        Log.info("RuleService: Deleted \(rules.count) rules", category: .analytics)
        #endif
    }

    // MARK: - Private Helpers

    private func updateRuleCount() {
        ruleCount = (try? fetchRules().count) ?? 0
    }
    
    /// Seeds the database with a set of default rules if none exist.
    ///
    /// This method checks if any rules exist. If the database is empty, it creates
    /// a predefined set of rules for common file types and organizes them into categories.
    /// - Throws: An error if saving the context fails.
    func seedDefaultRules() throws {
        let existingRules = try fetchRules()
        guard existingRules.isEmpty else { return }
        
        // Helper to create folder destinations with placeholder bookmarks
        // Note: Real bookmarks will be created when user selects folders via picker
        func dest(_ displayName: String) -> Destination {
            .folder(bookmark: Data(), displayName: displayName)
        }

        let defaultRules: [Rule] = [
            // Cleanup
            Rule(name: "Screenshot Sweeper", conditionType: .nameStartsWith, conditionValue: "Screenshot", actionType: .move, destination: dest("Pictures/Screenshots")),
            Rule(name: "DMG Destroyer", conditionType: .fileExtension, conditionValue: "dmg", actionType: .delete),
            Rule(name: "Zip Zap", conditionType: .fileExtension, conditionValue: "zip", actionType: .move, destination: dest("Downloads/Archives")),
            Rule(name: "Temp File Triage", conditionType: .nameStartsWith, conditionValue: "temp_", actionType: .move, destination: dest("Desktop/To Review")),

            // Creative Assets
            Rule(name: "Raw Photo Vault", conditionType: .fileExtension, conditionValue: "CR2", actionType: .move, destination: dest("Pictures/Raw Imports")),
            Rule(name: "PSD Parker", conditionType: .fileExtension, conditionValue: "psd", actionType: .move, destination: dest("Creative Cloud Files/Archived/PSDs")),
            Rule(name: "SVG Stash", conditionType: .fileExtension, conditionValue: "svg", actionType: .move, destination: dest("Assets/Icons")),
            Rule(name: "Font Finder", conditionType: .fileExtension, conditionValue: "otf", actionType: .move, destination: dest("Library/Fonts/To Install")),
            Rule(name: "Video Rush Reel", conditionType: .fileExtension, conditionValue: "mov", actionType: .move, destination: dest("Movies/Rushes")),

            // Developer Tools
            Rule(name: "SQL Dump Diver", conditionType: .fileExtension, conditionValue: "sql", actionType: .move, destination: dest("Documents/Database Backups")),
            Rule(name: "Log File Limbo", conditionType: .fileExtension, conditionValue: "log", actionType: .delete),
            Rule(name: "CSV Silo", conditionType: .fileExtension, conditionValue: "csv", actionType: .move, destination: dest("Documents/Data Exports")),
            Rule(name: "Env Var Guard", conditionType: .nameStartsWith, conditionValue: ".env", actionType: .move, destination: dest("Development/Secrets")),

            // Documents
            Rule(name: "Invoice Ingest", conditionType: .nameContains, conditionValue: "Invoice", actionType: .move, destination: dest("Documents/Financial/Invoices")),
            Rule(name: "Contract Corral", conditionType: .nameContains, conditionValue: "NDA", actionType: .move, destination: dest("Documents/Legal")),
            Rule(name: "Slide Deck Docker", conditionType: .fileExtension, conditionValue: "key", actionType: .move, destination: dest("Documents/Presentations")),
            Rule(name: "PDF Parking", conditionType: .fileExtension, conditionValue: "pdf", actionType: .move, destination: dest("Documents/PDF Archive")),

            // Audio
            Rule(name: "Sample Sorter", conditionType: .fileExtension, conditionValue: "wav", actionType: .move, destination: dest("Music/Samples")),
            Rule(name: "Voice Memo Vault", conditionType: .fileExtension, conditionValue: "m4a", actionType: .move, destination: dest("Music/Voice Memos"))
        ]
        
        for rule in defaultRules {
            modelContext.insert(rule)
        }
        
        try modelContext.save()
    }
    
    /// Seeds the database with rules from a specific organization template.
    ///
    /// This method replaces any existing rules with the template's default rules.
    /// Use this when the user selects a new template during onboarding or in settings.
    ///
    /// - Parameter template: The organization template to apply.
    /// - Parameter clearExisting: Whether to delete existing rules before seeding (default: true).
    /// - Throws: An error if saving the context fails.
    func seedTemplateRules(template: OrganizationTemplate, clearExisting: Bool = true) throws {
        // Optionally clear existing rules
        if clearExisting {
            let existingRules = try fetchRules()
            for rule in existingRules {
                modelContext.delete(rule)
            }
        }
        
        // Generate and insert template rules
        let templateRules = template.generateRules()
        for rule in templateRules {
            modelContext.insert(rule)
        }
        
        try modelContext.save()
    }
    
    /// Seeds the database with additional rules without clearing existing ones.
    ///
    /// Useful for adding template rules while preserving custom rules.
    ///
    /// - Parameter template: The organization template to apply.
    /// - Throws: An error if saving the context fails.
    func addTemplateRules(template: OrganizationTemplate) throws {
        try seedTemplateRules(template: template, clearExisting: false)
    }
}
