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

    func fetchRule(id: UUID) throws -> Rule? {
        let descriptor = FetchDescriptor<Rule>(
            predicate: #Predicate<Rule> { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    func findMatchingMoveRule(
        conditions: [RuleCondition],
        logicalOperator: Rule.LogicalOperator,
        destination: Destination?
    ) throws -> Rule? {
        let destinationIdentity = RuleService.destinationIdentity(for: destination)
        let descriptor = FetchDescriptor<Rule>()
        return try modelContext.fetch(descriptor).first { rule in
            rule.actionType == .move &&
            rule.conditions == conditions &&
            rule.logicalOperator == logicalOperator &&
            RuleService.destinationIdentity(for: rule.destination) == destinationIdentity
        }
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
        let signature = RuleService.semanticSignature(for: rule)
        let existingSignatures = try self.existingRuleSignatureSet()
        guard !existingSignatures.contains(signature) else {
            #if DEBUG
            Log.info("RuleService: Skipped semantic duplicate rule '\(rule.name)' from \(source.activityDescription)", category: .analytics)
            #endif
            return
        }

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

        var knownSignatures = try self.existingRuleSignatureSet()
        var insertedRules: [Rule] = []
        for rule in rules {
            let signature = RuleService.semanticSignature(for: rule)
            guard !knownSignatures.contains(signature) else {
                #if DEBUG
                Log.info("RuleService: Skipped semantic duplicate rule '\(rule.name)' in batch from \(source.activityDescription)", category: .analytics)
                #endif
                continue
            }

            modelContext.insert(rule)
            insertedRules.append(rule)
            knownSignatures.insert(signature)
        }

        guard !insertedRules.isEmpty else {
            #if DEBUG
            Log.info("RuleService: Skipped batch create from \(source.activityDescription); all rules were semantic duplicates", category: .analytics)
            #endif
            return
        }

        // Log bulk activity
        let activityService = ActivityLoggingService(modelContext: modelContext)
        activityService.logBulkRulesCreated(count: insertedRules.count, source: source.activityDescription)

        try modelContext.save()
        updateRuleCount()
        ruleChanges.send(.bulkCreated(count: insertedRules.count))

        #if DEBUG
        Log.info("RuleService: Created \(insertedRules.count) rules from \(source.activityDescription)", category: .analytics)
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
        let previousCount = ruleCount
        do {
            ruleCount = try fetchRules().count
        } catch {
            Log.warning("RuleService: Failed to fetch rule count: \(error.localizedDescription)", category: .analytics)
            ruleCount = previousCount
        }
    }

    private func existingRuleSignatureSet() throws -> Set<String> {
        Set(try fetchRules().map(RuleService.semanticSignature(for:)))
    }

    private static func semanticSignature(for rule: Rule) -> String {
        let primaryConditions = canonicalConditionSet(
            rule.conditions,
            fallbackType: rule.conditionType,
            fallbackValue: rule.conditionValue
        )
        let exclusionConditions = canonicalConditionSet(
            rule.exclusionConditions,
            fallbackType: nil,
            fallbackValue: nil
        )
        let logicalOperator = rule.logicalOperator.rawValue
        let actionType = rule.actionType.rawValue
        let destinationIdentity = destinationIdentity(for: rule.destination)
        let scopeIdentity = scopeIdentity(for: rule)

        return [
            "conditions:\(primaryConditions)",
            "exclusions:\(exclusionConditions)",
            "operator:\(logicalOperator)",
            "action:\(actionType)",
            "destination:\(destinationIdentity)",
            "scope:\(scopeIdentity)"
        ].joined(separator: "|")
    }

    private static func destinationIdentity(for destination: Destination?) -> String {
        guard let destination else { return "none" }

        switch destination {
        case .trash:
            return "trash"

        case .folder(let bookmarkData, let displayName):
            if !bookmarkData.isEmpty,
               let resolvedPath = destination.resolve()?.url.standardizedFileURL.path {
                return "folder:\(resolvedPath)"
            }

            if !bookmarkData.isEmpty {
                return "folder-bookmark:\(fnv1a64(bookmarkData))"
            }

            let normalizedDisplayName = displayName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            return normalizedDisplayName.isEmpty ? "folder-name:<empty>" : "folder-name:\(normalizedDisplayName)"
        }
    }

    private static func canonicalConditionSet(
        _ conditions: [RuleCondition],
        fallbackType: Rule.ConditionType?,
        fallbackValue: String?
    ) -> String {
        let sourceConditions: [RuleCondition]
        if conditions.isEmpty, let fallbackType, let fallbackValue,
           let fallbackCondition = try? RuleCondition(type: fallbackType, value: fallbackValue) {
            sourceConditions = [fallbackCondition]
        } else {
            sourceConditions = conditions
        }

        return sourceConditions
            .map(canonicalConditionSignature)
            .sorted()
            .joined(separator: ",")
    }

    private static func canonicalConditionSignature(_ condition: RuleCondition) -> String {
        switch condition {
        case .fileExtension(let ext):
            return "fileExtension(\(normalizedExtension(ext)))"
        case .nameContains(let value):
            return "nameContains(\(normalizedText(value)))"
        case .nameStartsWith(let value):
            return "nameStartsWith(\(normalizedText(value)))"
        case .nameEndsWith(let value):
            return "nameEndsWith(\(normalizedText(value)))"
        case .dateOlderThan(let days, let ext):
            return "dateOlderThan(\(days),\(normalizedOptionalExtension(ext)))"
        case .sizeLargerThan(let bytes):
            return "sizeLargerThan(\(bytes))"
        case .dateModifiedOlderThan(let days):
            return "dateModifiedOlderThan(\(days))"
        case .dateAccessedOlderThan(let days):
            return "dateAccessedOlderThan(\(days))"
        case .fileKind(let kind):
            return "fileKind(\(normalizedText(kind)))"
        case .sourceLocation(let location):
            return "sourceLocation(\(location.rawValue.lowercased()))"
        case .not(let inner):
            return "not(\(canonicalConditionSignature(inner)))"
        }
    }

    private static func scopeIdentity(for rule: Rule) -> String {
        guard let category = rule.category else {
            return "global"
        }

        switch category.scope {
        case .global:
            return "global"
        case .folders(let folders):
            let normalizedFolders = folders
                .map { normalizedText($0.displayName) }
                .sorted()
                .joined(separator: ",")
            return "folders:\(normalizedFolders)"
        }
    }

    private static func normalizedText(_ value: String) -> String {
        value
            .precomposedStringWithCanonicalMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func normalizedExtension(_ value: String) -> String {
        normalizedText(value).trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }

    private static func normalizedOptionalExtension(_ value: String?) -> String {
        guard let value else { return "nil" }
        return normalizedExtension(value)
    }

    private static func fnv1a64(_ data: Data) -> String {
        let prime: UInt64 = 1_099_511_628_211
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in data {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        return String(hash, radix: 16)
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
            Rule(name: "PSD Parker", conditionType: .fileExtension, conditionValue: "psd", actionType: .move, destination: dest("Documents/Creative/PSDs")),
            Rule(name: "SVG Stash", conditionType: .fileExtension, conditionValue: "svg", actionType: .move, destination: dest("Documents/Assets/Icons")),
            Rule(name: "Font Finder", conditionType: .fileExtension, conditionValue: "otf", actionType: .move, destination: dest("Documents/Fonts/To Install")),
            Rule(name: "Video Rush Reel", conditionType: .fileExtension, conditionValue: "mov", actionType: .move, destination: dest("Documents/Video/Rushes")),

            // Developer Tools
            Rule(name: "SQL Dump Diver", conditionType: .fileExtension, conditionValue: "sql", actionType: .move, destination: dest("Documents/Database Backups")),
            Rule(name: "Log File Limbo", conditionType: .fileExtension, conditionValue: "log", actionType: .delete),
            Rule(name: "CSV Silo", conditionType: .fileExtension, conditionValue: "csv", actionType: .move, destination: dest("Documents/Data Exports")),
            Rule(name: "Env Var Guard", conditionType: .nameStartsWith, conditionValue: ".env", actionType: .move, destination: dest("Documents/Development/Secrets")),

            // Documents
            Rule(name: "Invoice Ingest", conditionType: .nameContains, conditionValue: "Invoice", actionType: .move, destination: dest("Documents/Financial/Invoices")),
            Rule(name: "Contract Corral", conditionType: .nameContains, conditionValue: "NDA", actionType: .move, destination: dest("Documents/Legal")),
            Rule(name: "Slide Deck Docker", conditionType: .fileExtension, conditionValue: "key", actionType: .move, destination: dest("Documents/Presentations")),
            Rule(name: "PDF Parking", conditionType: .fileExtension, conditionValue: "pdf", actionType: .move, destination: dest("Documents/PDF Archive")),

            // Audio
            Rule(name: "Sample Sorter", conditionType: .fileExtension, conditionValue: "wav", actionType: .move, destination: dest("Music/Samples")),
            Rule(name: "Voice Memo Vault", conditionType: .fileExtension, conditionValue: "m4a", actionType: .move, destination: dest("Music/Voice Memos"))
        ]

        try createRules(defaultRules, source: .defaultSeeding)
    }

    /// Restores the default screenshot rule when it appears to have been deleted accidentally.
    ///
    /// This is intentionally narrow: it only restores the rule when there is no current
    /// screenshot-routing rule and the activity timeline shows a recent deletion of the
    /// default screenshot rule after it had been used.
    ///
    /// - Returns: `true` when the rule was restored.
    /// - Throws: An error if fetching or saving fails.
    @discardableResult
    func restoreDeletedScreenshotRuleIfNeeded() throws -> Bool {
        let existingRules = try fetchRules()
        guard !existingRules.contains(where: Self.isScreenshotRoutingRule) else {
            return false
        }

        let activities = try modelContext.fetch(
            FetchDescriptor<ActivityItem>(
                sortBy: [SortDescriptor(\ActivityItem.timestamp, order: .reverse)]
            )
        )

        guard shouldRestoreDeletedScreenshotRule(from: activities) else {
            return false
        }

        let nextSortOrder = (existingRules.map(\.sortOrder).max() ?? -1) + 1
        let restoredRule = Rule(
            name: "Screenshot Sweeper",
            conditionType: .nameStartsWith,
            conditionValue: "Screenshot",
            actionType: .move,
            destination: .folder(bookmark: Data(), displayName: "Pictures/Screenshots"),
            sortOrder: nextSortOrder
        )

        try createRule(restoredRule, source: .defaultSeeding)
        return true
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
            try modelContext.save()
        }

        // Generate and insert template rules
        let templateRules = template.generateRules()
        try createRules(templateRules, source: .template(name: template.displayName))
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

    private func shouldRestoreDeletedScreenshotRule(from activities: [ActivityItem]) -> Bool {
        guard let deletedAt = activities.first(where: {
            $0.activityType == .ruleDeleted && $0.fileName == "Screenshot Sweeper"
        })?.timestamp else {
            return false
        }

        guard let deletionCutoff = Calendar.current.date(byAdding: .day, value: -2, to: Date()),
              deletedAt >= deletionCutoff else {
            return false
        }

        let wasRecentlyUsed = activities.contains { activity in
            guard activity.timestamp <= deletedAt else { return false }

            switch activity.activityType {
            case .ruleApplied:
                return activity.fileName == "Screenshot Sweeper"
            case .fileOrganized:
                return activity.details.localizedCaseInsensitiveContains("Screenshots")
            default:
                return false
            }
        }

        return wasRecentlyUsed
    }

    private static func isScreenshotRoutingRule(_ rule: Rule) -> Bool {
        guard rule.actionType != .delete else { return false }

        return rule.conditions.contains { condition in
            switch condition {
            case .nameStartsWith(let value),
                 .nameContains(let value):
                return value.localizedCaseInsensitiveContains("screenshot") ||
                    value.localizedCaseInsensitiveContains("screen shot")
            default:
                return false
            }
        }
    }
}
