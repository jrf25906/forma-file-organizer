import Foundation

/// Rule Engine that evaluates files against a set of rules to determine their destination.
///
/// ## Protocol-Based Architecture
///
/// This engine uses protocol-based generics (`Fileable` and `Ruleable`) instead of concrete
/// SwiftData types. This design provides several benefits:
///
/// - **Testability**: Tests can use simple structs instead of SwiftData models, avoiding
///   MainActor and ModelContainer complexity
/// - **Flexibility**: Any type conforming to the protocols can be evaluated, not just SwiftData models
/// - **Separation of Concerns**: Business logic is decoupled from persistence layer
///
/// ## Usage
///
/// ```swift
/// // With production SwiftData models (auto-conform to protocols):
/// let engine = RuleEngine()
/// let result = engine.evaluateFile(fileItem, rules: rules)
///
/// // With test models (in tests):
/// let engine = RuleEngine()
/// let testFile = TestFileItem(...)
/// let testRule = TestRule(...)
/// let result = engine.evaluateFile(testFile, rules: [testRule])
/// ```
class RuleEngine {

    // MARK: - Dependencies

    /// Resolver for converting placeholder destinations to real destinations
    private let destinationResolver = DestinationResolver()

    /// Cache of resolved destinations to avoid repeated resolution attempts
    private var resolvedDestinationCache: [String: Destination] = [:]

    // MARK: - Public API

    /// Evaluates a single file against a list of rules.
    ///
    /// It iterates through the rules in order. The first rule that matches the file
    /// determines the destination.
    ///
    /// - Parameters:
    ///   - fileItem: The file to evaluate (must conform to Fileable).
    ///   - rules: The list of rules to check against (must conform to Ruleable).
    /// - Returns: The same file object (or a copy) with `destination` and `status` updated.
    func evaluateFile<F: Fileable, R: Ruleable>(_ fileItem: F, rules: [R]) -> F {
        var file = fileItem

        // DEBUG: Temporary diagnostic logging
        print("🔍 RuleEngine: Evaluating '\(file.name)' against \(rules.count) rules")

        // Check each rule in order
        for rule in rules {
            // DEBUG: Check each rule
            print("🔍 RuleEngine: Checking rule '\(rule.conditionsSummary)' for '\(file.name)'")

            if matches(file: file, rule: rule) {
                print("✅ RuleEngine: MATCHED! Rule '\(rule.conditionsSummary)' matches '\(file.name)'")
                // For delete rules, set destination to trash
                if rule.actionType == .delete {
                    file.destination = .trash
                } else if let ruleDestination = rule.destination {
                    // Check if destination has valid bookmark data (not a placeholder)
                    // Trash destinations (.trash) don't need bookmarks, folder destinations do
                    if !ruleDestination.isTrash && ruleDestination.bookmarkData == nil {
                        // Placeholder destination - try to resolve it automatically
                        let cacheKey = ruleDestination.displayName
                        print("🔍 RuleEngine: Destination '\(cacheKey)' needs resolution (bookmarkData is nil)")

                        // Check cache first
                        if let cachedDestination = resolvedDestinationCache[cacheKey] {
                            print("✅ RuleEngine: Found cached resolution for '\(cacheKey)'")
                            file.destination = cachedDestination
                        } else if let resolvedDestination = destinationResolver.resolve(ruleDestination) {
                            // Successfully resolved - cache it and use it
                            print("✅ RuleEngine: Successfully resolved '\(cacheKey)'")
                            resolvedDestinationCache[cacheKey] = resolvedDestination
                            file.destination = resolvedDestination
                            Log.info("RuleEngine: Auto-resolved placeholder '\(ruleDestination.displayName)' for rule '\(rule.conditionsSummary)'", category: .pipeline)
                        } else {
                            // Resolution failed - skip this rule
                            print("❌ RuleEngine: Failed to resolve '\(cacheKey)' - skipping rule")
                            Log.warning("RuleEngine: Rule '\(rule.conditionsSummary)' matched but has unresolvable placeholder destination '\(ruleDestination.displayName)' - grant folder access or configure in rule settings", category: .pipeline)
                            continue
                        }
                    } else {
                        print("✅ RuleEngine: Destination already has valid bookmark")
                        // Valid destination - copy from rule
                        file.destination = ruleDestination
                    }
                } else {
                    // Rule has no destination configured - skip it
                    Log.warning("RuleEngine: Rule matched but has no destination configured, skipping", category: .pipeline)
                    continue
                }
                file.status = .ready

                // Generate match reason explanation
                file.matchReason = generateMatchReason(for: file, rule: rule)

                // Calculate confidence score
                file.confidenceScore = calculateConfidenceScore(for: rule)

                // Track which rule matched for analytics
                file.matchedRuleID = rule.id

                return file
            }
        }

        // No rule matched
        file.destination = nil
        file.matchReason = nil
        file.confidenceScore = nil
        file.matchedRuleID = nil
        file.status = .pending
        return file
    }
    
    /// Evaluates a batch of files against a list of rules.
    ///
    /// - Parameters:
    ///   - files: The array of files to evaluate (must conform to Fileable).
    ///   - rules: The list of rules to check against (must conform to Ruleable).
    /// - Returns: An array of updated file objects.
    func evaluateFiles<F: Fileable, R: Ruleable>(_ files: [F], rules: [R]) -> [F] {
        return files.map { evaluateFile($0, rules: rules) }
    }
    
    /// Public method to check if a file matches a specific rule.
    ///
    /// - Parameters:
    ///   - file: The file to check (must conform to Fileable).
    ///   - rule: The rule to evaluate (must conform to Ruleable).
    /// - Returns: `true` if the file matches the rule's condition, `false` otherwise.
    func fileMatchesRule<F: Fileable, R: Ruleable>(file: F, rule: R) -> Bool {
        return matches(file: file, rule: rule)
    }
    
    /// Checks if a file matches a specific rule.
    ///
    /// A file matches if:
    /// 1. The rule is enabled
    /// 2. The rule's category is enabled (if it has one)
    /// 3. The file is within the category's scope (for folder-scoped categories)
    /// 4. The primary conditions match (using compound conditions with AND/OR logic)
    /// 5. NO exclusion conditions match (if any are defined)
    ///
    /// - Parameters:
    ///   - file: The file to check (must conform to Fileable).
    ///   - rule: The rule to evaluate (must conform to Ruleable).
    /// - Returns: `true` if the file matches the rule's condition, `false` otherwise.
    private func matches<F: Fileable, R: Ruleable>(file: F, rule: R) -> Bool {
        guard rule.isEnabled else { return false }

        // Check category scope - if rule has a scoped category, file must be in scope
        if !isFileInCategoryScope(file: file, rule: rule) {
            return false
        }

        // Check primary conditions using the compound conditions array
        let primaryMatch = matchesCompoundConditions(file: file, conditions: rule.conditions, logicalOperator: rule.logicalOperator)

        // If primary conditions don't match, no need to check exclusions
        guard primaryMatch else { return false }

        // Check exclusion conditions - if ANY exclusion matches, the rule does NOT match
        if !rule.exclusionConditions.isEmpty {
            let excluded = rule.exclusionConditions.contains { condition in
                matchesCondition(file: file, condition: condition)
            }
            if excluded {
                Log.debug("RuleEngine: File '\(file.name)' excluded from rule by exclusion condition", category: .pipeline)
                return false
            }
        }

        return true
    }
    
    /// Evaluates compound conditions (multiple conditions with AND/OR logic).
    ///
    /// Now uses type-safe RuleCondition directly for compile-time safety.
    ///
    /// - Parameters:
    ///   - file: The file to check.
    ///   - conditions: Array of typed conditions to evaluate.
    ///   - logicalOperator: How to combine the conditions (.and or .or).
    /// - Returns: `true` if the compound condition matches, `false` otherwise.
    private func matchesCompoundConditions<F: Fileable>(file: F, conditions: [RuleCondition], logicalOperator: Rule.LogicalOperator) -> Bool {
        switch logicalOperator {
        case .and:
            // All conditions must match
            return conditions.allSatisfy { condition in
                matchesCondition(file: file, condition: condition)
            }
        case .or:
            // At least one condition must match
            return conditions.contains { condition in
                matchesCondition(file: file, condition: condition)
            }
        case .single:
            // Should not reach here in compound mode, but handle gracefully
            return conditions.first.map { condition in
                matchesCondition(file: file, condition: condition)
            } ?? false
        }
    }
    
    /// Checks if a file matches a single condition.
    ///
    /// This method now accepts RuleCondition directly for type-safe matching,
    /// but maintains backward compatibility with type/value parameters.
    ///
    /// - Parameters:
    ///   - file: The file to check.
    ///   - condition: The typed condition to evaluate (preferred).
    /// - Returns: `true` if the condition matches, `false` otherwise.
    private func matchesCondition<F: Fileable>(file: F, condition: RuleCondition) -> Bool {
        switch condition {
        case .fileExtension(let ext):
            return file.fileExtension.lowercased() == ext.lowercased()

        case .nameStartsWith(let text):
            return FilenameUtilities.startsWithLiteral(file.name, prefix: text)

        case .nameContains(let text):
            return FilenameUtilities.containsLiteral(file.name, pattern: text)

        case .nameEndsWith(let text):
            return FilenameUtilities.endsWithLiteral(file.name, suffix: text)

        case .dateOlderThan(let days, let extensionFilter):
            // Validate days is positive (should be caught at construction, but defensive)
            guard days > 0 else {
                Log.warning("RuleEngine: Days value must be positive in dateOlderThan condition: \(days)", category: .pipeline)
                return false
            }

            // Check extension if specified
            if let ext = extensionFilter, !ext.isEmpty {
                let cleanExt = ext.replacingOccurrences(of: ".", with: "")
                if file.fileExtension.lowercased() != cleanExt.lowercased() {
                    return false
                }
            }

            // Check date
            let calendar = Calendar.current
            guard let dateThreshold = calendar.date(byAdding: .day, value: -days, to: Date()) else {
                Log.error("RuleEngine: Failed to calculate date threshold for \(days) days ago", category: .pipeline)
                return false
            }

            return file.creationDate < dateThreshold

        case .sizeLargerThan(let bytes):
            return file.sizeInBytes > bytes

        case .dateModifiedOlderThan(let days):
            guard days > 0 else {
                Log.warning("RuleEngine: Days value must be positive in dateModifiedOlderThan condition: \(days)", category: .pipeline)
                return false
            }

            let calendar = Calendar.current
            guard let dateThreshold = calendar.date(byAdding: .day, value: -days, to: Date()) else {
                Log.error("RuleEngine: Failed to calculate date threshold for \(days) days ago (modified)", category: .pipeline)
                return false
            }
            return file.modificationDate < dateThreshold

        case .dateAccessedOlderThan(let days):
            guard days > 0 else {
                Log.warning("RuleEngine: Days value must be positive in dateAccessedOlderThan condition: \(days)", category: .pipeline)
                return false
            }

            let calendar = Calendar.current
            guard let dateThreshold = calendar.date(byAdding: .day, value: -days, to: Date()) else {
                Log.error("RuleEngine: Failed to calculate date threshold for \(days) days ago (accessed)", category: .pipeline)
                return false
            }
            return file.lastAccessedDate < dateThreshold

        case .fileKind(let kind):
            return matchesFileKind(extension: file.fileExtension, kind: kind)

        case .sourceLocation(let locationKind):
            return file.location == locationKind

        case .not(let innerCondition):
            // NOT operator: returns true when inner condition does NOT match
            return !matchesCondition(file: file, condition: innerCondition)
        }
    }

    /// Legacy method for backward compatibility with string-based condition values.
    /// - Parameters:
    ///   - file: The file to check.
    ///   - conditionType: The type of condition to evaluate.
    ///   - conditionValue: The value to match against.
    /// - Returns: `true` if the condition matches, `false` otherwise.
    private func matchesCondition<F: Fileable>(file: F, conditionType: Rule.ConditionType, conditionValue: String) -> Bool {
        // Try to create a typed condition from the legacy parameters
        // If validation fails, return false (invalid condition)
        guard let typedCondition = try? RuleCondition(type: conditionType, value: conditionValue) else {
            Log.error("RuleEngine: Failed to create typed condition from \(conditionType): '\(conditionValue)'. Rule will not match any files.", category: .pipeline)
            return false
        }

        return matchesCondition(file: file, condition: typedCondition)
    }
    
    /// Deprecated: use ByteSizeFormatterUtil.parse instead.
    private func parseSizeString(_ sizeString: String) -> Int64 {
        return (try? ByteSizeFormatterUtil.parse(sizeString)) ?? 0
    }
    
    /// Checks if a file extension matches a file kind category
    private func matchesFileKind(extension fileExtension: String, kind: String) -> Bool {
        let ext = fileExtension.lowercased()
        let kindLower = kind.lowercased()
        
        switch kindLower {
        case "image", "images":
            return ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "heic", "heif", "webp", "svg", "ico"].contains(ext)
        case "audio":
            return ["mp3", "wav", "aac", "flac", "ogg", "m4a", "wma", "aiff", "ape"].contains(ext)
        case "video", "videos":
            return ["mp4", "mov", "avi", "mkv", "flv", "wmv", "m4v", "mpg", "mpeg", "webm"].contains(ext)
        case "document", "documents":
            return ["pdf", "doc", "docx", "txt", "rtf", "odt", "pages", "tex"].contains(ext)
        case "spreadsheet", "spreadsheets":
            return ["xls", "xlsx", "csv", "numbers", "ods"].contains(ext)
        case "presentation", "presentations":
            return ["ppt", "pptx", "key", "odp"].contains(ext)
        case "archive", "archives":
            return ["zip", "rar", "7z", "tar", "gz", "bz2", "xz", "dmg", "pkg", "iso"].contains(ext)
        case "code":
            return ["swift", "py", "js", "ts", "java", "cpp", "c", "h", "cs", "rb", "go", "rs", "php", "html", "css", "json", "xml", "yaml", "yml"].contains(ext)
        default:
            return false
        }
    }
    
    /// Calculates a confidence score for a matched rule based on condition complexity.
    ///
    /// Scoring logic:
    /// - **High (0.9+)**: Multiple conditions (AND/OR), indicating strong pattern recognition
    /// - **Medium (0.7)**: Single specific condition (name-based, size, date), contextual match
    /// - **Low (0.5)**: Extension-only match, generic pattern
    ///
    /// - Parameter rule: The rule that matched.
    /// - Returns: A confidence score between 0.0 and 1.0.
    private func calculateConfidenceScore<R: Ruleable>(for rule: R) -> Double {
        let conditions = rule.conditions

        // Multiple conditions = High confidence (0.9)
        if conditions.count > 1 {
            return 0.9
        }

        // Empty conditions = Low confidence
        guard let condition = conditions.first else {
            return 0.5
        }

        // Single condition - score based on specificity
        switch condition.type {
        case .fileExtension:
            // Extension-only is generic, low confidence
            return 0.5

        case .nameContains, .nameStartsWith, .nameEndsWith:
            // Name-based conditions are more specific, medium confidence
            return 0.7

        case .dateOlderThan, .dateModifiedOlderThan, .dateAccessedOlderThan:
            // Date-based conditions are contextual, medium confidence
            return 0.7

        case .sizeLargerThan:
            // Size-based conditions are contextual, medium confidence
            return 0.7

        case .fileKind:
            // File kind is somewhat generic, medium-low confidence
            return 0.6

        case .sourceLocation:
            // Source location is highly specific, high confidence
            return 0.8
        }
    }
    
    /// Generates a human-readable explanation of why a file matched a rule.
    ///
    /// - Parameters:
    ///   - file: The file that matched.
    ///   - rule: The rule that was matched.
    /// - Returns: A string explaining the match reason.
    private func generateMatchReason<F: Fileable, R: Ruleable>(for file: F, rule: R) -> String {
        guard !rule.conditions.isEmpty else {
            return "Matches rule condition"
        }

        let conditionDescriptions = rule.conditions.map { conditionDescription(for: $0) }
        let joiner = rule.logicalOperator == .and ? " AND " : " OR "
        let combinedConditions = conditionDescriptions.joined(separator: joiner)
        return combinedConditions.prefix(1).uppercased() + combinedConditions.dropFirst()
    }
    
    /// Generates a human-readable description for a single condition.
    /// Mirrors the logic in Rule.conditionDescription but accessible here.
    private func conditionDescription(for condition: RuleCondition) -> String {
        switch condition {
        case .fileExtension(let ext):
            return "extension is .\(ext)"
        case .nameContains(let text):
            return "name contains '\(text)'"
        case .nameStartsWith(let text):
            return "name starts with '\(text)'"
        case .nameEndsWith(let text):
            return "name ends with '\(text)'"
        case .dateOlderThan(let days, let ext):
            if let ext = ext {
                return ".\(ext) older than \(days) days"
            }
            return "older than \(days) days"
        case .sizeLargerThan(let bytes):
            return "larger than \(ByteSizeFormatterUtil.format(bytes))"
        case .dateModifiedOlderThan(let days):
            return "not modified in \(days) days"
        case .dateAccessedOlderThan(let days):
            return "not opened in \(days) days"
        case .fileKind(let kind):
            return "file kind is \(kind)"
        case .sourceLocation(let locationKind):
            return "from \(locationKind.rawValue.capitalized)"
        case .not(let inner):
            return "NOT (\(conditionDescription(for: inner)))"
        }
    }

    /// Deprecated: use ByteSizeFormatterUtil.format instead.
    private func formatBytes(_ bytes: Int64) -> String {
        return ByteSizeFormatterUtil.format(bytes)
    }

    // MARK: - Category Scope Validation

    /// Checks if a file is within the scope of a rule's category.
    ///
    /// This method handles the folder-scoped category feature:
    /// - **Global categories**: Always return true (files from anywhere can match)
    /// - **Folder-scoped categories**: Only return true if the file is from one of the specified folders
    /// - **Disabled categories**: Return false (rules in disabled categories don't match)
    /// - **No category (nil)**: Treated as General category (global scope, always matches)
    ///
    /// - Parameters:
    ///   - file: The file being evaluated.
    ///   - rule: The rule whose category scope should be checked.
    /// - Returns: `true` if the file is in scope for evaluation by this rule.
    private func isFileInCategoryScope<F: Fileable, R: Ruleable>(file: F, rule: R) -> Bool {
        // If rule has no category, treat as General (global scope)
        guard let category = rule.category else {
            return true
        }

        // If category is disabled, rules in it don't match
        guard category.isEnabled else {
            Log.debug("RuleEngine: Skipping rule '\(rule.conditionsSummary)' - category '\(category.name)' is disabled", category: .pipeline)
            return false
        }

        // Check the category's scope
        let scope = category.scope

        // Global scope always matches
        if scope.isGlobal {
            return true
        }

        // For folder-scoped categories, check if file is within the scoped folders
        let fileURL = URL(fileURLWithPath: file.path)
        let inScope = scope.matches(fileURL: fileURL)

        if !inScope {
            Log.debug("RuleEngine: File '\(file.name)' not in scope for category '\(category.name)'", category: .pipeline)
        }

        return inScope
    }

}
