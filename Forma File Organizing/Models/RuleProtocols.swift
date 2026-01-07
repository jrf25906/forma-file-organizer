import Foundation

/// Protocol defining the interface for rules that can evaluate files.
///
/// Both production `Rule` (SwiftData model) and test doubles can conform to this protocol,
/// enabling testability without SwiftData/MainActor complications.
///
/// All rules use the `conditions` array for matching. The Rule model maintains
/// `conditionType` and `conditionValue` fields for SwiftData schema compatibility,
/// but the RuleEngine only uses the `conditions` array.
protocol Ruleable {
    /// Unique identifier for the rule (used for analytics tracking)
    var id: UUID { get }

    /// Multiple conditions for compound rule matching.
    /// This is the primary source of truth for rule matching logic.
    var conditions: [RuleCondition] { get }

    /// Logical operator for combining multiple conditions
    var logicalOperator: Rule.LogicalOperator { get }

    /// Whether this rule is currently enabled
    var isEnabled: Bool { get }

    /// The unified destination for matched files.
    ///
    /// This replaces the previous three-field system:
    /// - `destinationFolder: String?` (legacy path)
    /// - `destinationBookmarkData: Data?` (bookmark)
    /// - `destinationDisplayName: String?` (display name)
    ///
    /// For delete actions, this should be `.trash`.
    /// For move/copy actions, this should be `.folder(bookmark:displayName:)`.
    var destination: Destination? { get }

    /// The action to perform when the rule matches (move, copy, delete)
    var actionType: Rule.ActionType { get }

    /// The priority order for rule evaluation (lower values = higher priority).
    ///
    /// Rules are evaluated in ascending sortOrder. When multiple rules could match
    /// a file, the rule with the lowest sortOrder wins (first-match-wins).
    var sortOrder: Int { get }

    /// Conditions that, when matched, exclude a file from this rule.
    ///
    /// Even if the primary conditions match, the rule will NOT apply if any
    /// exclusion condition matches. This enables exception handling like
    /// "move all PDFs except those containing 'invoice'".
    var exclusionConditions: [RuleCondition] { get }

    /// The category this rule belongs to.
    ///
    /// Rules are organized into categories for better management and optional
    /// folder-scoped evaluation. If nil, the rule is treated as belonging to
    /// the default "General" category.
    var category: RuleCategory? { get }

    /// The ID of the category this rule belongs to, for quick access.
    var categoryID: UUID? { get }

    /// The name of the category this rule belongs to, for display purposes.
    var categoryName: String { get }
}

// MARK: - Convenience Extensions

extension Ruleable {
    /// The display name for the destination (for UI display).
    /// Returns "No destination" if no destination is set.
    var destinationDisplayText: String {
        destination?.displayName ?? "No destination"
    }

    /// Whether this rule has a valid destination configured.
    var hasDestination: Bool {
        destination != nil
    }

    /// Default implementation: no category (treated as General)
    var category: RuleCategory? { nil }

    /// Default implementation: no category ID
    var categoryID: UUID? { category?.id }

    /// Default implementation: "General" for uncategorized rules
    var categoryName: String { category?.name ?? "General" }

    /// A summary string of the rule's conditions for display purposes.
    ///
    /// For single conditions, returns the condition value directly.
    /// For compound conditions, joins them with the logical operator.
    var conditionsSummary: String {
        guard !conditions.isEmpty else { return "" }
        if conditions.count == 1 {
            return conditions[0].value
        }
        let separator = logicalOperator == .and ? " & " : " | "
        return conditions.map { $0.value }.joined(separator: separator)
    }
}
