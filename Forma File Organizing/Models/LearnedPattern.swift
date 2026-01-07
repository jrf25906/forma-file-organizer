import Foundation
import SwiftData

// Note: PatternCondition and TemporalContext are defined in PatternCondition.swift
// to avoid MainActor isolation issues with the @Model macro.

// MARK: - Learned Pattern

/// Represents a learned pattern from user behavior that could be converted into a rule.
///
/// LearnedPattern tracks repeated file organization behaviors to suggest automation opportunities.
/// Supports both simple patterns (extension → destination) and compound patterns
/// (extension + name contains + time of day → destination).
///
/// Also supports **negative patterns** (anti-patterns) that track what users DON'T do,
/// allowing the system to suppress irrelevant suggestions.
@Model
final class LearnedPattern {
    /// Unique identifier
    var id: UUID

    /// Human-readable description of the pattern
    /// Example: "PDF files → Documents/Finance"
    var patternDescription: String

    /// The file extension this pattern applies to.
    ///
    /// **Schema Compatibility**: This stored property is maintained for SwiftData persistence.
    /// The `conditions` array is the canonical source of truth for pattern matching.
    /// This field is synchronized with conditions at initialization for quick access.
    ///
    /// For the authoritative extension value, use `primaryFileExtension` which extracts
    /// from the conditions array.
    var fileExtension: String

    /// The destination path where files are being moved (display name)
    var destinationPath: String

    /// Security-scoped bookmark data for the destination folder
    /// When available, this is the source of truth for file access
    var destinationBookmarkData: Data?

    /// How many times this pattern has been observed
    var occurrenceCount: Int

    /// Confidence score (0.0-1.0) calculated from frequency
    /// - 0.7+ (High): Pattern occurs >70% of the time
    /// - 0.5-0.69 (Medium): Pattern occurs 50-69% of the time
    /// - <0.5 (Low): Pattern is inconsistent, don't suggest
    var confidenceScore: Double {
        didSet {
            if confidenceScore < 0.0 || confidenceScore > 1.0 {
                Log.warning("LearnedPattern: confidenceScore \(confidenceScore) out of bounds [0.0-1.0], clamping", category: .analytics)
                confidenceScore = max(0.0, min(1.0, confidenceScore))
            }
        }
    }

    /// When this pattern was last observed
    var lastSeenDate: Date

    /// How many times the user has rejected this suggestion
    /// If rejectionCount >= 3, pattern should be suppressed
    var rejectionCount: Int

    /// Whether this pattern has been converted to a rule
    var convertedToRule: Bool

    /// The ID of the rule if this pattern was converted
    var convertedRuleId: UUID?

    // MARK: - New Properties for Enhanced AI

    /// Compound conditions for multi-condition patterns.
    ///
    /// **Source of Truth**: This is the canonical source for pattern matching logic.
    /// The `fileExtension` stored property is maintained for SwiftData schema compatibility
    /// and is synchronized at initialization.
    var conditions: [PatternCondition]

    /// Raw storage for logical operator.
    /// SwiftData cannot reliably persist nested enums directly, so we store as String.
    /// Use the `logicalOperator` computed property for type-safe access.
    private var logicalOperatorRaw: String

    /// Logical operator for combining multiple conditions.
    /// Defaults to `.and` for compound patterns.
    var logicalOperator: Rule.LogicalOperator {
        get { Rule.LogicalOperator(rawValue: logicalOperatorRaw) ?? .single }
        set { logicalOperatorRaw = newValue.rawValue }
    }

    /// Whether this is a negative pattern (anti-pattern).
    /// Negative patterns represent behaviors the user consistently avoids.
    /// Example: User NEVER moves screenshots to Documents
    var isNegativePattern: Bool

    /// IDs of rules that this negative pattern should suppress.
    /// When a positive pattern is created that conflicts with this negative pattern,
    /// the positive pattern should be filtered out.
    var suppressedRuleIds: [UUID]

    /// Keywords extracted from filenames for this pattern.
    /// Used for multi-condition pattern matching.
    var extractedKeywords: [String]

    /// Temporal context indicating when this pattern typically occurs.
    /// Used for time-based pattern detection.
    var temporalContexts: [TemporalContext]

    /// Raw storage for time category.
    /// SwiftData cannot reliably persist nested enums directly, so we store as String.
    /// Use the `timeCategory` computed property for type-safe access.
    private var timeCategoryRaw: String

    /// Type-safe accessor for time category
    var timeCategory: TimeCategory {
        get { TimeCategory(rawValue: timeCategoryRaw) ?? .anyTime }
        set { timeCategoryRaw = newValue.rawValue }
    }

    /// Time-based categorization for patterns
    enum TimeCategory: String, Codable {
        case workHours      // 9am-5pm weekdays
        case evenings       // 6pm-11pm
        case mornings       // 5am-9am
        case weekends       // Saturday-Sunday
        case anyTime        // No clear pattern
    }

    // MARK: - Initialization

    /// Convenience initializer for simple extension-based patterns.
    ///
    /// This initializer automatically populates the `conditions` array from the
    /// provided `fileExtension` parameter. Both fields are synchronized for
    /// SwiftData persistence and quick access.
    ///
    /// - Parameters:
    ///   - patternDescription: Human-readable description of the pattern
    ///   - fileExtension: The file extension this pattern matches
    ///   - destinationPath: Display name for the destination folder
    ///   - destinationBookmarkData: Security-scoped bookmark for destination
    ///   - occurrenceCount: How many times this pattern was observed
    ///   - confidenceScore: Confidence level (0.0-1.0)
    init(
        patternDescription: String,
        fileExtension: String,
        destinationPath: String,
        destinationBookmarkData: Data? = nil,
        occurrenceCount: Int,
        confidenceScore: Double,
        lastSeenDate: Date = Date(),
        rejectionCount: Int = 0,
        convertedToRule: Bool = false,
        convertedRuleId: UUID? = nil
    ) {
        self.id = UUID()
        self.patternDescription = patternDescription
        self.fileExtension = fileExtension
        self.destinationPath = destinationPath
        self.destinationBookmarkData = destinationBookmarkData
        self.occurrenceCount = occurrenceCount
        self.confidenceScore = confidenceScore
        self.lastSeenDate = lastSeenDate
        self.rejectionCount = rejectionCount
        self.convertedToRule = convertedToRule
        self.convertedRuleId = convertedRuleId

        // Initialize new properties with defaults
        self.conditions = [.fileExtension(fileExtension)]
        self.logicalOperatorRaw = Rule.LogicalOperator.single.rawValue
        self.isNegativePattern = false
        self.suppressedRuleIds = []
        self.extractedKeywords = []
        self.temporalContexts = []
        self.timeCategoryRaw = TimeCategory.anyTime.rawValue
    }

    /// Full initializer with all enhanced AI properties.
    ///
    /// Use this initializer for compound patterns with multiple conditions.
    /// The `fileExtension` parameter should match the primary extension in the
    /// `conditions` array for consistency (used for SwiftData persistence).
    ///
    /// - Note: The `conditions` array is the source of truth for pattern matching.
    init(
        patternDescription: String,
        fileExtension: String,
        destinationPath: String,
        destinationBookmarkData: Data? = nil,
        occurrenceCount: Int,
        confidenceScore: Double,
        lastSeenDate: Date = Date(),
        rejectionCount: Int = 0,
        convertedToRule: Bool = false,
        convertedRuleId: UUID? = nil,
        conditions: [PatternCondition],
        logicalOperator: Rule.LogicalOperator = .and,
        isNegativePattern: Bool = false,
        suppressedRuleIds: [UUID] = [],
        extractedKeywords: [String] = [],
        temporalContexts: [TemporalContext] = [],
        timeCategory: TimeCategory = .anyTime
    ) {
        self.id = UUID()
        self.patternDescription = patternDescription
        self.fileExtension = fileExtension
        self.destinationPath = destinationPath
        self.destinationBookmarkData = destinationBookmarkData
        self.occurrenceCount = occurrenceCount
        self.confidenceScore = confidenceScore
        self.lastSeenDate = lastSeenDate
        self.rejectionCount = rejectionCount
        self.convertedToRule = convertedToRule
        self.convertedRuleId = convertedRuleId
        self.conditions = conditions
        self.logicalOperatorRaw = logicalOperator.rawValue
        self.isNegativePattern = isNegativePattern
        self.suppressedRuleIds = suppressedRuleIds
        self.extractedKeywords = extractedKeywords
        self.temporalContexts = temporalContexts
        self.timeCategoryRaw = timeCategory.rawValue
    }

    // MARK: - Computed Properties
    // Note: Business logic is delegated to PatternAnalysisService
    // These properties maintain backward compatibility

    /// Whether this pattern should be suggested to the user.
    /// Delegates to PatternAnalysisService for the recommendation logic.
    var shouldSuggest: Bool {
        PatternAnalysisService.shouldSuggest(self)
    }

    /// Confidence level as a readable string.
    /// Delegates to PatternAnalysisService.
    var confidenceLevel: String {
        PatternAnalysisService.confidenceLevel(for: confidenceScore)
    }

    /// Icon name for UI display.
    /// Delegates to PatternAnalysisService.
    var iconName: String {
        PatternAnalysisService.icon(for: self)
    }

    /// Whether this is a compound pattern (multiple conditions).
    var isCompoundPattern: Bool {
        conditions.count > 1
    }

    /// The primary file extension extracted from the conditions array.
    ///
    /// This is the authoritative source for the pattern's file extension,
    /// derived from the first `.fileExtension` condition in the conditions array.
    /// Returns an empty string if no file extension condition exists.
    var primaryFileExtension: String {
        for condition in conditions {
            if case .fileExtension(let ext) = condition {
                return ext
            }
        }
        return ""
    }

    /// Human-readable description of all conditions.
    /// Delegates to PatternAnalysisService.
    var conditionsDescription: String {
        PatternAnalysisService.conditionsDescription(for: self)
    }

    /// Description suitable for negative pattern display.
    /// Delegates to PatternAnalysisService.
    var negativePatternDescription: String {
        PatternAnalysisService.negativePatternDescription(for: self)
    }

    /// Time category display name.
    /// Delegates to PatternAnalysisService.
    var timeCategoryDisplayName: String {
        PatternAnalysisService.displayName(for: timeCategory)
    }

    // MARK: - Methods

    /// Increment rejection count when user dismisses the suggestion
    func recordRejection() {
        rejectionCount += 1
    }

    /// Mark this pattern as converted to a rule
    func markAsConverted(ruleId: UUID) {
        convertedToRule = true
        convertedRuleId = ruleId
    }

    /// Update the pattern with a new occurrence
    func recordNewOccurrence(confidenceScore: Double, timestamp: Date = Date()) {
        occurrenceCount += 1
        self.confidenceScore = confidenceScore
        lastSeenDate = timestamp

        // Record temporal context
        let context = TemporalContext(from: timestamp)
        temporalContexts.append(context)

        // Update time category based on accumulated contexts
        updateTimeCategory()
    }

    /// Add a keyword extracted from a filename
    func addKeyword(_ keyword: String) {
        let normalizedKeyword = keyword.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKeyword.isEmpty, !extractedKeywords.contains(normalizedKeyword) else { return }
        extractedKeywords.append(normalizedKeyword)
    }

    /// Add a condition to this pattern (for compound patterns)
    func addCondition(_ condition: PatternCondition) {
        guard !conditions.contains(condition) else { return }
        conditions.append(condition)

        // If we now have multiple conditions, upgrade to compound mode
        if conditions.count > 1 && logicalOperator == .single {
            logicalOperator = .and
        }
    }

    /// Convert this pattern to a negative pattern (anti-pattern)
    func convertToNegativePattern() {
        isNegativePattern = true
        // Negative patterns have 100% confidence that the user DOESN'T want this
        confidenceScore = 1.0
    }

    /// Add a rule ID that this negative pattern should suppress
    func addSuppressedRule(_ ruleId: UUID) {
        guard !suppressedRuleIds.contains(ruleId) else { return }
        suppressedRuleIds.append(ruleId)
    }

    /// Check if this negative pattern should suppress a given positive pattern.
    ///
    /// Suppression is based on condition overlap. If this negative pattern
    /// has conditions that match the positive pattern's conditions AND they
    /// target the same destination, the positive pattern is suppressed.
    func shouldSuppress(pattern: LearnedPattern) -> Bool {
        guard isNegativePattern else { return false }

        // Check condition overlap using array comparison (avoids Hashable in MainActor context)
        // This is O(n*m) but condition arrays are typically small (< 10 elements)
        // PatternCondition has nonisolated Equatable so this works across actor boundaries
        let hasOverlap = conditions.contains { myCondition in
            pattern.conditions.contains { theirCondition in
                myCondition == theirCondition
            }
        }

        // If significant overlap AND same destination, suppress
        return hasOverlap && pattern.destinationPath == destinationPath
    }

    /// Convenience method to check suppression by extension and destination.
    ///
    /// - Parameters:
    ///   - fileExtension: The file extension to check
    ///   - destination: The destination path to check
    /// - Returns: True if this negative pattern should suppress suggestions for this extension/destination combo
    func shouldSuppress(fileExtension ext: String, destination: String) -> Bool {
        guard isNegativePattern else { return false }
        return primaryFileExtension == ext && destinationPath == destination
    }

    // MARK: - Private Methods

    /// Update the time category based on accumulated temporal contexts.
    /// Delegates to PatternAnalysisService for the temporal analysis logic.
    private func updateTimeCategory() {
        PatternAnalysisService.updateTimeCategory(for: self)
    }

    /// Convert this learned pattern to a Rule.
    /// Delegates to PatternAnalysisService for the conversion logic.
    func toRule() -> Rule {
        PatternAnalysisService.convertToRule(self)
    }
}

// MARK: - Mock Data

extension LearnedPattern {
    static var mocks: [LearnedPattern] {
        [
            LearnedPattern(
                patternDescription: "You moved 5 PDF files to Documents/Finance",
                fileExtension: "pdf",
                destinationPath: "~/Documents/Finance",
                occurrenceCount: 5,
                confidenceScore: 0.83
            ),
            LearnedPattern(
                patternDescription: "You moved 8 PNG files to Pictures/Screenshots",
                fileExtension: "png",
                destinationPath: "~/Pictures/Screenshots",
                occurrenceCount: 8,
                confidenceScore: 0.94
            ),
            LearnedPattern(
                patternDescription: "You moved 3 DOCX files to Documents/Work",
                fileExtension: "docx",
                destinationPath: "~/Documents/Work",
                occurrenceCount: 3,
                confidenceScore: 0.6
            )
        ]
    }
}
