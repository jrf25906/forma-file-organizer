import Foundation
import SwiftData

/// Represents a single condition within a rule with type-safe associated values.
///
/// This enum provides compile-time type safety for condition values, ensuring that
/// date conditions use integers, size conditions use Int64, and text conditions use strings.
/// The enum is fully Codable-compliant for SwiftData persistence.
enum RuleCondition: Codable, Equatable, Hashable {
    case fileExtension(String)
    case nameContains(String)
    case nameStartsWith(String)
    case nameEndsWith(String)
    case dateOlderThan(days: Int, extension: String?)
    case sizeLargerThan(bytes: Int64)
    case dateModifiedOlderThan(days: Int)
    case dateAccessedOlderThan(days: Int)
    case fileKind(String)
    case sourceLocation(FileLocationKind)

    /// Negates any condition - matches when the inner condition does NOT match.
    /// Example: `.not(.fileExtension("pdf"))` matches all non-PDF files.
    indirect case not(RuleCondition)

    // MARK: - Codable Implementation

    private enum CodingKeys: String, CodingKey {
        case type
        case stringValue
        case intValue
        case int64Value
        case extensionValue
        case innerCondition  // For NOT operator
    }

    private enum ConditionTypeCode: String, Codable {
        case fileExtension
        case nameContains
        case nameStartsWith
        case nameEndsWith
        case dateOlderThan
        case sizeLargerThan
        case dateModifiedOlderThan
        case dateAccessedOlderThan
        case fileKind
        case sourceLocation
        case not  // NOT operator
    }

    // Legacy struct format keys (for migration from old data)
    private enum LegacyCodingKeys: String, CodingKey {
        case conditionType
        case value
    }

    init(from decoder: Decoder) throws {
        // First, try the new enum format
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let type = try? container.decode(ConditionTypeCode.self, forKey: .type) {
            switch type {
            case .fileExtension:
                let value = try container.decode(String.self, forKey: .stringValue)
                self = .fileExtension(value)
                return

            case .nameContains:
                let value = try container.decode(String.self, forKey: .stringValue)
                self = .nameContains(value)
                return

            case .nameStartsWith:
                let value = try container.decode(String.self, forKey: .stringValue)
                self = .nameStartsWith(value)
                return

            case .nameEndsWith:
                let value = try container.decode(String.self, forKey: .stringValue)
                self = .nameEndsWith(value)
                return

            case .dateOlderThan:
                let days = try container.decode(Int.self, forKey: .intValue)
                let ext = try container.decodeIfPresent(String.self, forKey: .extensionValue)
                self = .dateOlderThan(days: days, extension: ext)
                return

            case .sizeLargerThan:
                let bytes = try container.decode(Int64.self, forKey: .int64Value)
                self = .sizeLargerThan(bytes: bytes)
                return

            case .dateModifiedOlderThan:
                let days = try container.decode(Int.self, forKey: .intValue)
                self = .dateModifiedOlderThan(days: days)
                return

            case .dateAccessedOlderThan:
                let days = try container.decode(Int.self, forKey: .intValue)
                self = .dateAccessedOlderThan(days: days)
                return

            case .fileKind:
                let value = try container.decode(String.self, forKey: .stringValue)
                self = .fileKind(value)
                return

            case .sourceLocation:
                let rawValue = try container.decode(String.self, forKey: .stringValue)
                let locationKind = FileLocationKind(rawValue: rawValue) ?? .unknown
                self = .sourceLocation(locationKind)
                return

            case .not:
                let innerCondition = try container.decode(RuleCondition.self, forKey: .innerCondition)
                self = .not(innerCondition)
                return
            }
        }

        // Fallback: Try legacy struct format (conditionType + value)
        if let container = try? decoder.container(keyedBy: LegacyCodingKeys.self),
           let typeString = try? container.decode(String.self, forKey: .conditionType),
           let legacyType = Rule.ConditionType(rawValue: typeString),
           let value = try? container.decode(String.self, forKey: .value) {
            // Use the legacy initializer to convert
            if let condition = try? RuleCondition(type: legacyType, value: value) {
                self = condition
                return
            }
        }
        
        // Final fallback: default to a safe empty condition
        // This prevents crashes for corrupted or incompatible data
        Log.error("RuleCondition: Failed to decode condition data, using default .fileExtension(\"\"). This rule may not work as expected.", category: .pipeline)
        self = .fileExtension("")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .fileExtension(let value):
            try container.encode(ConditionTypeCode.fileExtension, forKey: .type)
            try container.encode(value, forKey: .stringValue)

        case .nameContains(let value):
            try container.encode(ConditionTypeCode.nameContains, forKey: .type)
            try container.encode(value, forKey: .stringValue)

        case .nameStartsWith(let value):
            try container.encode(ConditionTypeCode.nameStartsWith, forKey: .type)
            try container.encode(value, forKey: .stringValue)

        case .nameEndsWith(let value):
            try container.encode(ConditionTypeCode.nameEndsWith, forKey: .type)
            try container.encode(value, forKey: .stringValue)

        case .dateOlderThan(let days, let ext):
            try container.encode(ConditionTypeCode.dateOlderThan, forKey: .type)
            try container.encode(days, forKey: .intValue)
            try container.encodeIfPresent(ext, forKey: .extensionValue)

        case .sizeLargerThan(let bytes):
            try container.encode(ConditionTypeCode.sizeLargerThan, forKey: .type)
            try container.encode(bytes, forKey: .int64Value)

        case .dateModifiedOlderThan(let days):
            try container.encode(ConditionTypeCode.dateModifiedOlderThan, forKey: .type)
            try container.encode(days, forKey: .intValue)

        case .dateAccessedOlderThan(let days):
            try container.encode(ConditionTypeCode.dateAccessedOlderThan, forKey: .type)
            try container.encode(days, forKey: .intValue)

        case .fileKind(let value):
            try container.encode(ConditionTypeCode.fileKind, forKey: .type)
            try container.encode(value, forKey: .stringValue)

        case .sourceLocation(let locationKind):
            try container.encode(ConditionTypeCode.sourceLocation, forKey: .type)
            try container.encode(locationKind.rawValue, forKey: .stringValue)

        case .not(let innerCondition):
            try container.encode(ConditionTypeCode.not, forKey: .type)
            try container.encode(innerCondition, forKey: .innerCondition)
        }
    }

    // MARK: - Legacy Compatibility

    /// The condition type (for compatibility with existing code)
    /// Note: For `.not` conditions, returns the inner condition's type for legacy compatibility
    var type: Rule.ConditionType {
        switch self {
        case .fileExtension: return .fileExtension
        case .nameContains: return .nameContains
        case .nameStartsWith: return .nameStartsWith
        case .nameEndsWith: return .nameEndsWith
        case .dateOlderThan: return .dateOlderThan
        case .sizeLargerThan: return .sizeLargerThan
        case .dateModifiedOlderThan: return .dateModifiedOlderThan
        case .dateAccessedOlderThan: return .dateAccessedOlderThan
        case .fileKind: return .fileKind
        case .sourceLocation: return .sourceLocation
        case .not(let inner): return inner.type  // Delegate to inner condition
        }
    }

    /// Legacy string value representation (for backward compatibility)
    /// Note: For `.not` conditions, returns the inner condition's value prefixed with "NOT:"
    var value: String {
        switch self {
        case .fileExtension(let ext):
            return ext
        case .nameContains(let text):
            return text
        case .nameStartsWith(let text):
            return text
        case .nameEndsWith(let text):
            return text
        case .dateOlderThan(let days, let ext):
            if let ext = ext, !ext.isEmpty {
                return "\(ext):\(days)"
            }
            return "\(days)"
        case .sizeLargerThan(let bytes):
            return ByteSizeFormatterUtil.format(bytes)
        case .dateModifiedOlderThan(let days):
            return "\(days)"
        case .dateAccessedOlderThan(let days):
            return "\(days)"
        case .fileKind(let kind):
            return kind
        case .sourceLocation(let locationKind):
            return locationKind.rawValue
        case .not(let inner):
            return "NOT:\(inner.value)"
        }
    }

    // MARK: - Type-Safe Accessors

    /// Get the integer value for date-based conditions
    var daysValue: Int? {
        switch self {
        case .dateOlderThan(let days, _),
             .dateModifiedOlderThan(let days),
             .dateAccessedOlderThan(let days):
            return days
        default:
            return nil
        }
    }

    /// Get the size value in bytes
    var sizeValue: Int64? {
        if case .sizeLargerThan(let bytes) = self {
            return bytes
        }
        return nil
    }

    /// Get the text value for string-based conditions
    var textValue: String? {
        switch self {
        case .fileExtension(let text),
             .nameContains(let text),
             .nameStartsWith(let text),
             .nameEndsWith(let text),
             .fileKind(let text):
            return text
        case .sourceLocation(let locationKind):
            return locationKind.rawValue
        default:
            return nil
        }
    }

    /// Get the extension filter for dateOlderThan conditions
    var extensionFilter: String? {
        if case .dateOlderThan(_, let ext) = self {
            return ext
        }
        return nil
    }

    /// Get the location value for source location conditions
    var locationValue: FileLocationKind? {
        if case .sourceLocation(let kind) = self {
            return kind
        }
        return nil
    }

    /// Get the inner condition for NOT conditions
    var innerCondition: RuleCondition? {
        if case .not(let inner) = self {
            return inner
        }
        return nil
    }

    /// Returns true if this is a negated condition
    var isNegated: Bool {
        if case .not = self {
            return true
        }
        return false
    }

    // MARK: - Initializers

    /// Initialize from legacy type and string value (for backward compatibility and migration)
    /// - Parameters:
    ///   - type: The condition type
    ///   - value: The string representation of the value
    /// - Throws: `ValidationError` if the value is invalid for the given type
    init(type: Rule.ConditionType, value: String) throws {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        switch type {
        case .fileExtension:
            guard !trimmedValue.isEmpty else {
                throw ValidationError.emptyValue(type: type)
            }
            self = .fileExtension(trimmedValue)

        case .nameContains:
            guard !trimmedValue.isEmpty else {
                throw ValidationError.emptyValue(type: type)
            }
            self = .nameContains(trimmedValue)

        case .nameStartsWith:
            guard !trimmedValue.isEmpty else {
                throw ValidationError.emptyValue(type: type)
            }
            self = .nameStartsWith(trimmedValue)

        case .nameEndsWith:
            guard !trimmedValue.isEmpty else {
                throw ValidationError.emptyValue(type: type)
            }
            self = .nameEndsWith(trimmedValue)

        case .dateOlderThan:
            // Parse "extension:days" or "days"
            let components = trimmedValue.split(separator: ":")
            if components.count == 2 {
                let ext = String(components[0])
                guard let days = Int(components[1]), days > 0 else {
                    throw ValidationError.invalidDays(value: String(components[1]))
                }
                self = .dateOlderThan(days: days, extension: ext)
            } else {
                guard let days = Int(trimmedValue), days > 0 else {
                    throw ValidationError.invalidDays(value: trimmedValue)
                }
                self = .dateOlderThan(days: days, extension: nil)
            }

        case .sizeLargerThan:
            // Use shared parser but map any parse errors to our validation error type
            let bytes: Int64
            do {
                bytes = try ByteSizeFormatterUtil.parse(trimmedValue)
            } catch {
                throw ValidationError.invalidSize(value: trimmedValue)
            }
            guard bytes > 0 else {
                throw ValidationError.invalidSize(value: trimmedValue)
            }
            self = .sizeLargerThan(bytes: bytes)

        case .dateModifiedOlderThan:
            guard let days = Int(trimmedValue), days > 0 else {
                throw ValidationError.invalidDays(value: trimmedValue)
            }
            self = .dateModifiedOlderThan(days: days)

        case .dateAccessedOlderThan:
            guard let days = Int(trimmedValue), days > 0 else {
                throw ValidationError.invalidDays(value: trimmedValue)
            }
            self = .dateAccessedOlderThan(days: days)

        case .fileKind:
            guard !trimmedValue.isEmpty else {
                throw ValidationError.emptyValue(type: type)
            }
            self = .fileKind(trimmedValue)

        case .sourceLocation:
            guard !trimmedValue.isEmpty else {
                throw ValidationError.emptyValue(type: type)
            }
            let locationKind = FileLocationKind(rawValue: trimmedValue) ?? .unknown
            self = .sourceLocation(locationKind)
        }
    }

    /// Validation errors thrown during initialization
    enum ValidationError: LocalizedError {
        case emptyValue(type: Rule.ConditionType)
        case invalidDays(value: String)
        case invalidSize(value: String)

        var errorDescription: String? {
            switch self {
            case .emptyValue(let type):
                return "Value cannot be empty for \(type.rawValue) condition"
            case .invalidDays(let value):
                return "Invalid days value: '\(value)'. Must be a positive integer."
            case .invalidSize(let value):
                return "Invalid size value: '\(value)'. Use format like '100MB', '1.5GB', etc."
            }
        }
    }

    // MARK: - Helpers

    /// Deprecated: use ByteSizeFormatterUtil.parse instead.
    private static func parseSizeString(_ sizeString: String) throws -> Int64 {
        let cleanString = sizeString.uppercased().trimmingCharacters(in: .whitespaces)

        var numberString = ""
        var unit = ""

        for char in cleanString {
            if char.isNumber || char == "." {
                numberString.append(char)
            } else {
                unit.append(char)
            }
        }

        guard let number = Double(numberString) else {
            throw ValidationError.invalidSize(value: sizeString)
        }

        let multiplier: Double
        switch unit {
        case "KB":
            multiplier = 1_024
        case "MB":
            multiplier = 1_024 * 1_024
        case "GB":
            multiplier = 1_024 * 1_024 * 1_024
        case "TB":
            multiplier = 1_024 * 1_024 * 1_024 * 1_024
        case "B", "":
            multiplier = 1
        default:
            throw ValidationError.invalidSize(value: sizeString)
        }

        return Int64(number * multiplier)
    }

    /// Deprecated: use ByteSizeFormatterUtil.format instead.
    private func formatBytes(_ bytes: Int64) -> String {
        return ByteSizeFormatterUtil.format(bytes)
    }
}

/// A model representing a file organization rule.
///
/// Rules define criteria for matching files and actions to take when a match is found.
/// They are persisted using SwiftData.
@Model
final class Rule: Ruleable {
    /// Unique identifier for the rule.
    @Attribute(.unique) var id: UUID

    /// Descriptive name of the rule (e.g., "Screenshot Sweeper").
    var name: String

    /// Whether the rule is currently active.
    var isEnabled: Bool

    /// Raw storage for condition type (SwiftData schema compatibility).
    ///
    /// SwiftData requires stored properties for persistence. This field is derived from
    /// `conditions[0].type` during initialization and kept in sync for schema stability.
    /// The `conditions` array is the **source of truth** for rule matching.
    private var conditionTypeRaw: String

    /// Type-safe accessor for the first condition's type (for SwiftData schema compatibility).
    var conditionType: ConditionType {
        get { ConditionType(rawValue: conditionTypeRaw) ?? .fileExtension }
        set { conditionTypeRaw = newValue.rawValue }
    }

    /// The value for the first condition (SwiftData schema compatibility).
    ///
    /// Derived from `conditions[0].value` during initialization. The `conditions` array
    /// is the **source of truth** for rule matching.
    var conditionValue: String

    /// The conditions for rule matching. This is the **source of truth**.
    ///
    /// All rule matching uses this array. The `conditionType` and `conditionValue` fields
    /// are maintained for SwiftData schema compatibility but derived from `conditions[0]`.
    var conditions: [RuleCondition]

    /// Raw storage for logical operator.
    /// SwiftData cannot reliably persist nested enums directly, so we store as String.
    /// Use the `logicalOperator` computed property for type-safe access.
    private var logicalOperatorRaw: String

    /// Type-safe accessor for logical operator
    var logicalOperator: LogicalOperator {
        get { LogicalOperator(rawValue: logicalOperatorRaw) ?? .single }
        set { logicalOperatorRaw = newValue.rawValue }
    }

    /// Raw storage for action type.
    /// SwiftData cannot reliably persist nested enums directly, so we store as String.
    /// Use the `actionType` computed property for type-safe access.
    private var actionTypeRaw: String

    /// Type-safe accessor for action type
    var actionType: ActionType {
        get { ActionType(rawValue: actionTypeRaw) ?? .move }
        set { actionTypeRaw = newValue.rawValue }
    }

    // MARK: - Destination Storage (SwiftData-compatible primitives)

    /// Whether the destination is Trash. SwiftData cannot persist enums with associated values,
    /// so we decompose `Destination` into these three primitives.
    private var _destinationIsTrash: Bool = false

    /// Security-scoped bookmark data for folder destinations.
    private var _destinationBookmarkData: Data?

    /// Display name for folder destinations (e.g., "Documents/Finance").
    private var _destinationDisplayName: String?

    /// The unified destination for this rule.
    ///
    /// This computed property reconstructs the `Destination` enum from the underlying
    /// SwiftData-compatible storage fields. SwiftData cannot persist enums with associated
    /// values directly, so we store the components separately.
    ///
    /// For delete actions, this should be `.trash`.
    /// For move/copy actions, this should be `.folder(bookmark:displayName:)`.
    var destination: Destination? {
        get {
            if _destinationIsTrash {
                return .trash
            }
            guard let bookmark = _destinationBookmarkData,
                  let displayName = _destinationDisplayName else {
                return nil
            }
            return .folder(bookmark: bookmark, displayName: displayName)
        }
        set {
            switch newValue {
            case .trash:
                _destinationIsTrash = true
                _destinationBookmarkData = nil
                _destinationDisplayName = nil
            case .folder(let bookmark, let displayName):
                _destinationIsTrash = false
                _destinationBookmarkData = bookmark
                _destinationDisplayName = displayName
            case nil:
                _destinationIsTrash = false
                _destinationBookmarkData = nil
                _destinationDisplayName = nil
            }
        }
    }

    /// The date when the rule was created.
    var creationDate: Date

    /// The priority order for rule evaluation (lower values = higher priority).
    ///
    /// Rules are evaluated in ascending sortOrder. When multiple rules could match
    /// a file, the rule with the lowest sortOrder wins (first-match-wins).
    /// Default is 0, meaning rules with equal sortOrder use creation date as tiebreaker.
    var sortOrder: Int

    /// Conditions that, when matched, exclude a file from this rule.
    ///
    /// Even if the primary conditions match, the rule will NOT apply if any
    /// exclusion condition matches. This enables exception handling like
    /// "move all PDFs except those containing 'invoice'".
    var exclusionConditions: [RuleCondition]

    // MARK: - Category Relationship

    /// The category this rule belongs to.
    ///
    /// Rules are organized into categories for better management and optional
    /// folder-scoped evaluation. If nil, the rule is treated as belonging to
    /// the default "General" category.
    @Relationship(deleteRule: .nullify) var category: RuleCategory?

    /// The ID of the category this rule belongs to, for quick access without loading the relationship.
    var categoryID: UUID? {
        category?.id
    }

    /// The name of the category this rule belongs to, for display purposes.
    var categoryName: String {
        category?.name ?? "General"
    }

    // MARK: - Validation & Destination Access

    /// Whether this rule has a valid destination configured
    var hasValidDestination: Bool {
        // Delete actions should have .trash destination
        if actionType == .delete {
            return destination?.isTrash ?? false
        }

        // Move/copy actions need a folder destination
        guard let dest = destination else {
            return false
        }

        // Validate the destination is usable
        return dest.validate().isUsable
    }

    /// Resolves the destination to a URL for file operations
    /// - Returns: The resolved destination, or nil if resolution fails
    /// - Note: Caller is responsible for calling `startAccessingSecurityScopedResource()`
    ///         and `stopAccessingSecurityScopedResource()` on the returned URL
    func resolveDestination() -> Destination.ResolvedDestination? {
        destination?.resolve()
    }

    /// The display name for the destination, for use in the UI
    var destinationDisplayText: String {
        destination?.displayName ?? "No destination"
    }

    /// Initializes a new Rule with a single condition.
    /// Convenience initializer for single-condition rules.
    ///
    /// This creates a rule with a single condition. Internally, it populates the `conditions`
    /// array with the specified condition, which is used for all rule matching.
    ///
    /// - Parameters:
    ///   - name: The name of the rule.
    ///   - conditionType: The type of condition to evaluate.
    ///   - conditionValue: The value to compare against.
    ///   - actionType: The action to take on match.
    ///   - destination: The unified destination for the rule.
    ///   - isEnabled: Whether the rule is enabled by default.
    ///   - sortOrder: Priority for evaluation (default 0, lower = higher priority).
    ///   - exclusionConditions: Conditions that exclude files even when primary conditions match.
    ///   - category: The category this rule belongs to (nil = General).
    init(name: String, conditionType: ConditionType, conditionValue: String, actionType: ActionType, destination: Destination? = nil, isEnabled: Bool = true, sortOrder: Int = 0, exclusionConditions: [RuleCondition] = [], category: RuleCategory? = nil) {
        self.id = UUID()
        self.name = name
        // Store raw values for SwiftData persistence
        self.conditionTypeRaw = conditionType.rawValue
        self.conditionValue = conditionValue
        // Populate the conditions array from the single condition (this is now the source of truth)
        if let condition = try? RuleCondition(type: conditionType, value: conditionValue) {
            self.conditions = [condition]
        } else {
            self.conditions = []
        }
        self.logicalOperatorRaw = LogicalOperator.single.rawValue
        self.actionTypeRaw = actionType.rawValue
        self.isEnabled = isEnabled
        self.creationDate = Date()
        self.sortOrder = sortOrder
        self.exclusionConditions = exclusionConditions
        self.category = category

        // Initialize destination storage (decomposed for SwiftData compatibility)
        switch destination {
        case .trash:
            self._destinationIsTrash = true
            self._destinationBookmarkData = nil
            self._destinationDisplayName = nil
        case .folder(let bookmark, let displayName):
            self._destinationIsTrash = false
            self._destinationBookmarkData = bookmark
            self._destinationDisplayName = displayName
        case nil:
            self._destinationIsTrash = false
            self._destinationBookmarkData = nil
            self._destinationDisplayName = nil
        }
    }

    /// Initializes a new Rule with multiple conditions (compound mode).
    /// - Parameters:
    ///   - name: The name of the rule.
    ///   - conditions: Array of conditions to evaluate.
    ///   - logicalOperator: How to combine the conditions (.and or .or).
    ///   - actionType: The action to take on match.
    ///   - destination: The unified destination for the rule.
    ///   - isEnabled: Whether the rule is enabled by default.
    ///   - sortOrder: Priority for evaluation (default 0, lower = higher priority).
    ///   - exclusionConditions: Conditions that exclude files even when primary conditions match.
    ///   - category: The category this rule belongs to (nil = General).
    init(name: String, conditions: [RuleCondition], logicalOperator: LogicalOperator, actionType: ActionType, destination: Destination? = nil, isEnabled: Bool = true, sortOrder: Int = 0, exclusionConditions: [RuleCondition] = [], category: RuleCategory? = nil) {
        self.id = UUID()
        self.name = name
        // For compound rules, set legacy fields to first condition or defaults
        if let first = conditions.first {
            self.conditionTypeRaw = first.type.rawValue
            self.conditionValue = first.value
        } else {
            self.conditionTypeRaw = ConditionType.fileExtension.rawValue
            self.conditionValue = ""
        }
        self.conditions = conditions
        self.logicalOperatorRaw = logicalOperator.rawValue
        self.actionTypeRaw = actionType.rawValue
        self.isEnabled = isEnabled
        self.creationDate = Date()
        self.sortOrder = sortOrder
        self.exclusionConditions = exclusionConditions
        self.category = category

        // Initialize destination storage (decomposed for SwiftData compatibility)
        switch destination {
        case .trash:
            self._destinationIsTrash = true
            self._destinationBookmarkData = nil
            self._destinationDisplayName = nil
        case .folder(let bookmark, let displayName):
            self._destinationIsTrash = false
            self._destinationBookmarkData = bookmark
            self._destinationDisplayName = displayName
        case nil:
            self._destinationIsTrash = false
            self._destinationBookmarkData = nil
            self._destinationDisplayName = nil
        }
    }

    /// Defines how multiple conditions are combined in a rule.
    enum LogicalOperator: String, Codable, CaseIterable {
        /// All conditions must match (logical AND).
        case and
        /// At least one condition must match (logical OR).
        case or
        /// Single condition mode (legacy, uses conditionType/conditionValue).
        case single
    }

    /// Defines the type of condition used to match files.
    enum ConditionType: String, Codable, CaseIterable {
        /// Matches the file extension (case-insensitive).
        case fileExtension
        /// Matches if the filename contains the value.
        case nameContains
        /// Matches if the filename starts with the value.
        case nameStartsWith
        /// Matches if the filename ends with the value.
        case nameEndsWith
        /// Matches if the file is older than the specified number of days.
        case dateOlderThan
        /// Matches if the file size is larger than the specified value (e.g., "100MB").
        case sizeLargerThan
        /// Matches if the file's modification date is older than the specified number of days.
        case dateModifiedOlderThan
        /// Matches if the file's last access date is older than the specified number of days.
        case dateAccessedOlderThan
        /// Matches if the file kind matches the specified type (e.g., "image", "audio", "video", "document").
        case fileKind
        /// Matches if the file's source location matches (e.g., desktop, downloads, documents).
        case sourceLocation
    }

    /// Defines the action to take when a rule matches.
    enum ActionType: String, Codable, CaseIterable {
        /// Moves the file to the destination folder.
        case move
        /// Copies the file to the destination folder.
        case copy
        /// Deletes the file (moves to Trash).
        case delete
        // Future: rename, tag
    }

    /// Returns a natural language description of the rule.
    var naturalLanguageDescription: String {
        // Handle compound conditions
        if !conditions.isEmpty {
            let conditionDescriptions = conditions.map { conditionDescription(for: $0) }
            let joiner = logicalOperator == .and ? " AND " : " OR "
            let combinedConditions = conditionDescriptions.joined(separator: joiner)
            return "\(actionDescription.capitalized) files when \(combinedConditions)"
        }

        // Legacy single condition
        switch conditionType {
        case .fileExtension:
            return "Automatically \(actionDescription) all \(conditionValue.uppercased()) files to \(destinationFolderName) folder"
        case .nameContains:
            return "Move files containing \"\(conditionValue)\" keywords"
        case .nameStartsWith:
            return "Move files starting with \"\(conditionValue)\""
        case .nameEndsWith:
            return "Move files ending with \"\(conditionValue)\""
        case .dateOlderThan:
            let days = conditionValue.contains(":") ? (conditionValue.split(separator: ":").last.map(String.init) ?? "0") : conditionValue
            return "Automatically \(actionDescription) \(fileExtensionDescription) older than \(days) days"
        case .sizeLargerThan:
            let sizeDisplay = conditionValue.uppercased()
            return "Automatically \(actionDescription) files larger than \(sizeDisplay)"
        case .dateModifiedOlderThan:
            return "Automatically \(actionDescription) files not modified in \(conditionValue) days"
        case .dateAccessedOlderThan:
            return "Automatically \(actionDescription) files not opened in \(conditionValue) days"
        case .fileKind:
            return "Automatically \(actionDescription) all \(conditionValue) files"
        case .sourceLocation:
            return "Automatically \(actionDescription) files from \(conditionValue.capitalized)"
        }
    }

    /// Returns a natural language description for a single condition.
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
            return "larger than \(formatBytes(bytes))"
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

    /// Returns a tag string for the UI based on the condition type.
    var conditionTag: String {
        switch conditionType {
        case .fileExtension, .fileKind:
            return "FILE-TYPE"
        case .nameContains, .nameStartsWith, .nameEndsWith:
            return "KEYWORD"
        case .dateOlderThan, .dateModifiedOlderThan, .dateAccessedOlderThan:
            return "DATE"
        case .sizeLargerThan:
            return "SIZE"
        case .sourceLocation:
            return "LOCATION"
        }
    }

    private var actionDescription: String {
        switch actionType {
        case .move: return "move"
        case .copy: return "copy"
        case .delete: return "delete"
        }
    }

    private var destinationFolderName: String {
        destination?.displayName ?? "Trash"
    }

    private var fileExtensionDescription: String {
        if conditionType == .dateOlderThan {
            let components = conditionValue.split(separator: ":")
            if components.count == 2 {
                return ".\(components[0])"
            }
            return "files"
        }
        return ""
    }

    /// Format bytes to a human-readable string
    private func formatBytes(_ bytes: Int64) -> String {
        let kb: Double = 1_024
        let mb = kb * 1_024
        let gb = mb * 1_024
        let tb = gb * 1_024

        let bytesDouble = Double(bytes)

        if bytesDouble >= tb {
            return String(format: "%.1fTB", bytesDouble / tb)
        } else if bytesDouble >= gb {
            return String(format: "%.1fGB", bytesDouble / gb)
        } else if bytesDouble >= mb {
            return String(format: "%.0fMB", bytesDouble / mb)
        } else if bytesDouble >= kb {
            return String(format: "%.0fKB", bytesDouble / kb)
        } else {
            return "\(bytes)B"
        }
    }
}
