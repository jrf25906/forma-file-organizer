import Foundation

/// Service for analyzing and processing learned patterns.
///
/// This service extracts business logic from the LearnedPattern model,
/// following the Single Responsibility Principle. The model focuses on
/// data storage, while this service handles:
///
/// - Pattern-to-Rule conversion
/// - Temporal analysis (time category detection)
/// - Recommendation logic (should a pattern be suggested?)
///
/// ## Usage
/// ```swift
/// // Convert a pattern to a rule
/// let rule = PatternAnalysisService.convertToRule(pattern)
///
/// // Check if a pattern should be suggested
/// if PatternAnalysisService.shouldSuggest(pattern) {
///     showSuggestion(pattern)
/// }
/// ```
enum PatternAnalysisService {
    // MARK: - Recommendation Engine

    /// Determines whether a pattern should be suggested to the user.
    ///
    /// A pattern is suggested when:
    /// - It's not a negative pattern
    /// - It hasn't been converted to a rule yet
    /// - It hasn't been rejected too many times (< 3)
    /// - It has medium or high confidence (>= 0.5)
    ///
    /// - Parameter pattern: The pattern to evaluate
    /// - Returns: True if the pattern should be suggested
    static func shouldSuggest(_ pattern: LearnedPattern) -> Bool {
        // Never suggest negative patterns directly
        guard !pattern.isNegativePattern else { return false }

        // Don't suggest if already converted to a rule
        guard !pattern.convertedToRule else { return false }

        // Don't suggest if rejected too many times
        guard pattern.rejectionCount < 3 else { return false }

        // Only suggest patterns with medium or high confidence
        return pattern.confidenceScore >= 0.5
    }

    /// Calculates a confidence level string from a confidence score.
    ///
    /// - Parameter score: The confidence score (0.0-1.0)
    /// - Returns: "High", "Medium", or "Low"
    static func confidenceLevel(for score: Double) -> String {
        if score >= 0.7 {
            return "High"
        } else if score >= 0.5 {
            return "Medium"
        } else {
            return "Low"
        }
    }

    // MARK: - Pattern-to-Rule Conversion

    /// Converts a learned pattern to a Rule.
    ///
    /// Handles both compound patterns (multiple conditions) and
    /// legacy single-condition patterns.
    ///
    /// - Parameter pattern: The pattern to convert
    /// - Returns: A Rule configured from the pattern
    static func convertToRule(_ pattern: LearnedPattern) -> Rule {
        if pattern.isCompoundPattern && pattern.conditions.count > 1 {
            return convertCompoundPattern(pattern)
        } else {
            return convertSimplePattern(pattern)
        }
    }

    /// Converts a compound pattern (multiple conditions) to a Rule.
    private static func convertCompoundPattern(_ pattern: LearnedPattern) -> Rule {
        // Convert PatternConditions to RuleConditions
        let ruleConditions: [RuleCondition] = pattern.conditions.compactMap { patternCondition in
            switch patternCondition {
            case .fileExtension(let ext):
                return .fileExtension(ext)
            case .nameContains(let text):
                return .nameContains(text)
            case .nameStartsWith(let text):
                return .nameStartsWith(text)
            case .nameEndsWith(let text):
                return .nameEndsWith(text)
            case .sizeRange(let minBytes, _):
                // Use min as threshold for "larger than"
                return .sizeLargerThan(bytes: minBytes)
            case .timeOfDay, .dayOfWeek:
                // Time-based conditions aren't directly supported in Rule yet
                return nil
            }
        }

        // Generate rule name from conditions
        let conditionSummary = pattern.conditions.prefix(2).map { $0.displayDescription }.joined(separator: " + ")
        let folderName = URL(fileURLWithPath: pattern.destinationPath).lastPathComponent
        let ruleName = "\(conditionSummary) → \(folderName)"

        return Rule(
            name: ruleName,
            conditions: ruleConditions,
            logicalOperator: pattern.logicalOperator,
            actionType: .move,
            destination: .folder(bookmark: Data(), displayName: pattern.destinationPath)
        )
    }

    /// Converts a simple single-condition pattern to a Rule.
    private static func convertSimplePattern(_ pattern: LearnedPattern) -> Rule {
        let folderName = URL(fileURLWithPath: pattern.destinationPath).lastPathComponent
        let ruleName = "\(pattern.fileExtension.uppercased()) → \(folderName)"

        return Rule(
            name: ruleName,
            conditionType: .fileExtension,
            conditionValue: pattern.fileExtension,
            actionType: .move,
            destination: .folder(bookmark: Data(), displayName: pattern.destinationPath)
        )
    }

    // MARK: - Temporal Analysis

    /// Time-based categorization for patterns.
    typealias TimeCategory = LearnedPattern.TimeCategory

    /// Analyzes temporal contexts and determines the appropriate time category.
    ///
    /// Requires at least 3 temporal contexts to make a determination.
    /// Uses a 60% threshold to classify into a specific category.
    ///
    /// - Parameter contexts: Array of temporal contexts to analyze
    /// - Returns: The determined time category
    static func categorize(contexts: [TemporalContext]) -> TimeCategory {
        guard contexts.count >= 3 else {
            return .anyTime
        }

        // Count occurrences in each category
        var workHoursCount = 0
        var eveningCount = 0
        var morningCount = 0
        var weekendCount = 0

        for context in contexts {
            let isWeekend = context.dayOfWeek == 1 || context.dayOfWeek == 7

            if isWeekend {
                weekendCount += 1
            } else if context.isWorkHours {
                workHoursCount += 1
            } else if context.hourOfDay >= 18 && context.hourOfDay <= 23 {
                eveningCount += 1
            } else if context.hourOfDay >= 5 && context.hourOfDay < 9 {
                morningCount += 1
            }
        }

        let total = contexts.count
        let threshold = Int(Double(total) * 0.6) // 60% threshold

        if workHoursCount >= threshold {
            return .workHours
        } else if eveningCount >= threshold {
            return .evenings
        } else if morningCount >= threshold {
            return .mornings
        } else if weekendCount >= threshold {
            return .weekends
        } else {
            return .anyTime
        }
    }

    /// Updates the time category for a pattern based on its temporal contexts.
    ///
    /// This is a convenience method that analyzes the pattern's contexts
    /// and updates its timeCategory property.
    ///
    /// - Parameter pattern: The pattern to update
    static func updateTimeCategory(for pattern: LearnedPattern) {
        pattern.timeCategory = categorize(contexts: pattern.temporalContexts)
    }

    // MARK: - Icon Selection

    /// Returns the appropriate icon for a pattern.
    ///
    /// - Parameter pattern: The pattern to get icon for
    /// - Returns: SF Symbol name
    static func icon(for pattern: LearnedPattern) -> String {
        if pattern.isNegativePattern {
            return "hand.raised.slash.fill"
        } else if pattern.isCompoundPattern {
            return "sparkles"
        } else {
            return "wand.and.stars"
        }
    }

    // MARK: - Description Helpers

    /// Generates a human-readable description of pattern conditions.
    ///
    /// - Parameter pattern: The pattern to describe
    /// - Returns: Human-readable conditions string
    static func conditionsDescription(for pattern: LearnedPattern) -> String {
        if pattern.conditions.isEmpty {
            return ".\(pattern.fileExtension) files"
        }

        let descriptions = pattern.conditions.map { $0.displayDescription }
        let joiner = pattern.logicalOperator == .and ? " AND " : " OR "
        return descriptions.joined(separator: joiner)
    }

    /// Generates a description for a negative pattern.
    ///
    /// - Parameter pattern: The negative pattern to describe
    /// - Returns: Human-readable negative pattern description
    static func negativePatternDescription(for pattern: LearnedPattern) -> String {
        guard pattern.isNegativePattern else { return pattern.patternDescription }
        return "Never move \(conditionsDescription(for: pattern)) to \(pattern.destinationPath)"
    }

    /// Returns the display name for a time category.
    ///
    /// - Parameter category: The time category
    /// - Returns: Human-readable display name
    static func displayName(for category: TimeCategory) -> String {
        switch category {
        case .workHours: return "Work Hours"
        case .evenings: return "Evenings"
        case .mornings: return "Mornings"
        case .weekends: return "Weekends"
        case .anyTime: return "Any Time"
        }
    }
}
