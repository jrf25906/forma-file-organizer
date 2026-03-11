import Foundation

/// Service for detecting potential overlaps between rules.
///
/// Rule overlap detection helps users understand when their rules might conflict or
/// duplicate functionality. This service analyzes rule conditions to identify:
///
/// - **Exact duplicates**: Rules with identical conditions and destinations
/// - **Conflicting overlaps**: Rules matching the same files but with different destinations
/// - **Subset/superset relationships**: One rule is broader or narrower than another
///
/// ## Usage
///
/// ```swift
/// let detector = RuleOverlapDetector()
/// let overlaps = detector.detectOverlaps(for: newRule, against: existingRules)
///
/// if !overlaps.isEmpty {
///     // Show warning dialog to user
/// }
/// ```
///
/// ## Design
///
/// - **Warn but allow**: The detector provides warnings, but doesn't block rule creation
/// - **Category-aware**: Only compares rules whose category scopes could overlap
/// - **Human-readable**: Each overlap includes an explanation for UI display
///
class RuleOverlapDetector {

    // MARK: - Types

    /// Represents a detected overlap between a new rule and an existing rule.
    struct RuleOverlap: Identifiable {
        let id = UUID()

        /// The existing rule that overlaps with the new rule
        let existingRule: any Ruleable

        /// The type/severity of the overlap
        let overlapType: OverlapType

        /// Human-readable explanation of why these rules overlap
        let explanation: String

        /// Optional suggestion for resolving the overlap
        let suggestion: String?
    }

    /// Types of overlap between rules, ordered by severity.
    enum OverlapType: Comparable {
        /// Exact duplicate: same conditions AND same destination
        case exactDuplicate

        /// Conflicting: same conditions but different destinations
        case conflictingDestination

        /// The new rule is a subset (narrower) of the existing rule
        case subset

        /// The new rule is a superset (broader) of the existing rule
        case superset

        /// The conditions partially overlap (could match some of the same files)
        case partialOverlap

        /// Severity level for UI display (higher = more severe)
        var severity: Int {
            switch self {
            case .exactDuplicate: return 3
            case .conflictingDestination: return 2
            case .subset, .superset: return 1
            case .partialOverlap: return 0
            }
        }

        /// Human-readable name for the overlap type
        var displayName: String {
            switch self {
            case .exactDuplicate: return "Exact Duplicate"
            case .conflictingDestination: return "Conflicting Destination"
            case .subset: return "Subset Rule"
            case .superset: return "Broader Rule"
            case .partialOverlap: return "Partial Overlap"
            }
        }

        /// SF Symbol for UI display
        var iconName: String {
            switch self {
            case .exactDuplicate: return "doc.on.doc.fill"
            case .conflictingDestination: return "arrow.triangle.branch"
            case .subset: return "arrow.down.right.and.arrow.up.left"
            case .superset: return "arrow.up.left.and.arrow.down.right"
            case .partialOverlap: return "circle.lefthalf.filled"
            }
        }
    }

    // MARK: - Detection

    /// Detects overlaps between a new rule and existing rules.
    ///
    /// - Parameters:
    ///   - newRule: The rule being created or edited.
    ///   - existingRules: All existing rules to compare against.
    ///   - excludeRuleID: Optional ID to exclude (for editing an existing rule).
    /// - Returns: Array of detected overlaps, sorted by severity (most severe first).
    func detectOverlaps<R: Ruleable>(
        for newRule: R,
        against existingRules: [R],
        excludeRuleID: UUID? = nil
    ) -> [RuleOverlap] {
        var overlaps: [RuleOverlap] = []

        for existingRule in existingRules {
            // Skip the rule being edited
            if let excludeID = excludeRuleID, existingRule.id == excludeID {
                continue
            }

            // Skip disabled rules
            guard existingRule.isEnabled else { continue }

            // Check if category scopes could overlap
            guard categoryScopesCouldOverlap(newRule: newRule, existingRule: existingRule) else {
                continue
            }

            // Check for condition overlap
            if let overlap = detectConditionOverlap(newRule: newRule, existingRule: existingRule) {
                overlaps.append(overlap)
            }
        }

        // Sort by severity (highest first)
        return overlaps.sorted { $0.overlapType.severity > $1.overlapType.severity }
    }

    // MARK: - Category Scope Comparison

    /// Checks if two rules' category scopes could overlap.
    ///
    /// Rules in completely separate folder scopes can't overlap because they
    /// evaluate different sets of files.
    private func categoryScopesCouldOverlap<R: Ruleable>(newRule: R, existingRule: R) -> Bool {
        let newScope = newRule.category?.scope ?? .global
        let existingScope = existingRule.category?.scope ?? .global

        // Global scope overlaps with everything
        if newScope.isGlobal || existingScope.isGlobal {
            return true
        }

        // Both folder-scoped: check if any folders overlap
        let newFolders = newScope.scopedFolders
        let existingFolders = existingScope.scopedFolders

        // Resolve bookmarks to paths for comparison
        let newPaths = newFolders.compactMap { $0.resolve()?.standardizedFileURL.path }
        let existingPaths = existingFolders.compactMap { $0.resolve()?.standardizedFileURL.path }

        // Check if any paths overlap (one contains the other)
        for newPath in newPaths {
            for existingPath in existingPaths {
                if newPath.hasPrefix(existingPath) || existingPath.hasPrefix(newPath) {
                    return true
                }
            }
        }

        return false
    }

    // MARK: - Condition Comparison

    /// Detects if there's a condition overlap between two rules.
    private func detectConditionOverlap<R: Ruleable>(newRule: R, existingRule: R) -> RuleOverlap? {
        // Get conditions for comparison
        let newConditions = getEffectiveConditions(from: newRule)
        let existingConditions = getEffectiveConditions(from: existingRule)

        // Determine the type of overlap
        let conditionRelation = compareConditions(newConditions, existingConditions, newRule.logicalOperator, existingRule.logicalOperator)

        guard let relation = conditionRelation else {
            return nil // No overlap
        }

        // Check destination similarity
        let sameDestination = destinationsMatch(newRule.destination, existingRule.destination)

        // Determine overlap type based on condition relation and destination
        let overlapType: OverlapType
        let explanation: String
        var suggestion: String?

        switch relation {
        case .identical:
            if sameDestination {
                overlapType = .exactDuplicate
                explanation = "This rule has identical conditions and destination as '\(existingRule.categoryName)/\(existingRule.conditionsSummary)'."
                suggestion = "Consider deleting one of these rules."
            } else {
                overlapType = .conflictingDestination
                explanation = "This rule matches the same files as '\(existingRule.categoryName)/\(existingRule.conditionsSummary)' but sends them to a different location."
                suggestion = "The higher-priority rule will take precedence. Adjust rule order if needed."
            }

        case .subset:
            overlapType = .subset
            explanation = "This rule is more specific than '\(existingRule.categoryName)/\(existingRule.conditionsSummary)'. Files matching your rule would also match the existing rule."
            if !sameDestination {
                suggestion = "Ensure your rule has higher priority if you want it to take precedence."
            }

        case .superset:
            overlapType = .superset
            explanation = "This rule is broader than '\(existingRule.categoryName)/\(existingRule.conditionsSummary)'. It may match files the existing rule was meant to handle."
            suggestion = "Consider making conditions more specific to avoid unexpected matches."

        case .partial:
            if !sameDestination {
                overlapType = .partialOverlap
                explanation = "This rule may match some of the same files as '\(existingRule.categoryName)/\(existingRule.conditionsSummary)'."
            } else {
                return nil // Partial overlap with same destination is usually fine
            }
        }

        return RuleOverlap(
            existingRule: existingRule,
            overlapType: overlapType,
            explanation: explanation,
            suggestion: suggestion
        )
    }

    /// Gets the conditions from a rule.
    private func getEffectiveConditions<R: Ruleable>(from rule: R) -> [RuleCondition] {
        rule.conditions
    }

    /// Result of comparing two sets of conditions.
    private enum ConditionRelation {
        case identical   // Same conditions
        case subset      // First is subset of second
        case superset    // First is superset of second
        case partial     // Some overlap
    }

    /// Compares two sets of conditions to determine their relationship.
    private func compareConditions(
        _ first: [RuleCondition],
        _ second: [RuleCondition],
        _ firstOp: Rule.LogicalOperator,
        _ secondOp: Rule.LogicalOperator
    ) -> ConditionRelation? {
        guard !first.isEmpty && !second.isEmpty else { return nil }

        // For single conditions, direct comparison
        if first.count == 1 && second.count == 1 {
            return compareSingleConditions(first[0], second[0])
        }

        // For compound conditions, simplified analysis
        // Check if conditions sets are identical
        if conditionSetsEqual(first, second) {
            return .identical
        }

        if conditionSetsAreMutuallyExclusive(first, second) {
            return nil
        }

        // Check for partial overlap using only high-confidence condition pairs.
        var hasOverlap = false
        for c1 in first {
            for c2 in second {
                if conditionsCouldOverlap(c1, c2) {
                    hasOverlap = true
                    break
                }
            }
            if hasOverlap { break }
        }

        return hasOverlap ? .partial : nil
    }

    /// Compares two single conditions.
    private func compareSingleConditions(_ first: RuleCondition, _ second: RuleCondition) -> ConditionRelation? {
        switch (first, second) {
        // Identical extension conditions
        case let (.fileExtension(ext1), .fileExtension(ext2)):
            if ext1.lowercased() == ext2.lowercased() {
                return .identical
            }
            return nil

        // Identical name conditions
        case let (.nameContains(t1), .nameContains(t2)):
            let lower1 = t1.lowercased()
            let lower2 = t2.lowercased()
            if lower1 == lower2 { return .identical }
            if lower1.contains(lower2) { return .subset }
            if lower2.contains(lower1) { return .superset }
            return nil

        case let (.nameStartsWith(t1), .nameStartsWith(t2)):
            let lower1 = t1.lowercased()
            let lower2 = t2.lowercased()
            if lower1 == lower2 { return .identical }
            if lower1.hasPrefix(lower2) { return .subset }
            if lower2.hasPrefix(lower1) { return .superset }
            return nil

        case let (.nameEndsWith(t1), .nameEndsWith(t2)):
            let lower1 = t1.lowercased()
            let lower2 = t2.lowercased()
            if lower1 == lower2 { return .identical }
            if lower1.hasSuffix(lower2) { return .subset }
            if lower2.hasSuffix(lower1) { return .superset }
            return nil

        case let (.nameContains(text), .nameStartsWith(prefix)):
            return compareNameContainsToStartsWith(text, prefix)

        case let (.nameStartsWith(prefix), .nameContains(text)):
            return inverted(compareNameContainsToStartsWith(text, prefix))

        case let (.nameContains(text), .nameEndsWith(suffix)):
            return compareNameContainsToEndsWith(text, suffix)

        case let (.nameEndsWith(suffix), .nameContains(text)):
            return inverted(compareNameContainsToEndsWith(text, suffix))

        // Size conditions
        case let (.sizeLargerThan(s1), .sizeLargerThan(s2)):
            if s1 == s2 { return .identical }
            if s1 > s2 { return .subset }   // s1 > X matches fewer files than s2 > Y when X > Y
            return .superset

        // Date conditions
        case let (.dateOlderThan(d1, e1), .dateOlderThan(d2, e2)):
            // Only compare if extensions match or both are nil
            if e1?.lowercased() != e2?.lowercased() { return nil }
            if d1 == d2 { return .identical }
            if d1 > d2 { return .subset }  // Older than 30 days is subset of older than 7 days
            return .superset

        case let (.dateModifiedOlderThan(d1), .dateModifiedOlderThan(d2)):
            if d1 == d2 { return .identical }
            if d1 > d2 { return .subset }
            return .superset

        case let (.dateAccessedOlderThan(d1), .dateAccessedOlderThan(d2)):
            if d1 == d2 { return .identical }
            if d1 > d2 { return .subset }
            return .superset

        // File kind conditions
        case let (.fileKind(k1), .fileKind(k2)):
            if normalizedFileKind(k1) == normalizedFileKind(k2) { return .identical }
            return nil

        // Source location conditions
        case let (.sourceLocation(l1), .sourceLocation(l2)):
            if l1 == l2 { return .identical }
            return nil

        // Cross-type comparisons with meaningful shared file-type constraints
        case let (.fileExtension(ext), .fileKind(kind)):
            return extensionMatchesFileKind(ext, kind) ? .subset : nil

        case let (.fileKind(kind), .fileExtension(ext)):
            return extensionMatchesFileKind(ext, kind) ? .superset : nil

        case let (.dateOlderThan(_, extension: ext?), .fileExtension(otherExt)):
            return ext.caseInsensitiveCompare(otherExt) == .orderedSame ? .subset : nil

        case let (.fileExtension(ext), .dateOlderThan(_, extension: otherExt?)):
            return ext.caseInsensitiveCompare(otherExt) == .orderedSame ? .superset : nil

        case let (.dateOlderThan(_, extension: ext?), .fileKind(kind)):
            return extensionMatchesFileKind(ext, kind) ? .subset : nil

        case let (.fileKind(kind), .dateOlderThan(_, extension: ext?)):
            return extensionMatchesFileKind(ext, kind) ? .superset : nil

        default:
            return nil
        }
    }

    /// Checks if two conditions could match the same file.
    private func conditionsCouldOverlap(_ first: RuleCondition, _ second: RuleCondition) -> Bool {
        compareSingleConditions(first, second) != nil
    }

    private func conditionSetsAreMutuallyExclusive(_ first: [RuleCondition], _ second: [RuleCondition]) -> Bool {
        fileTypeConstraintsConflict(first, second) ||
        sourceLocationConstraintsConflict(first, second) ||
        prefixConstraintsConflict(first, second) ||
        suffixConstraintsConflict(first, second)
    }

    private func sourceLocationConstraintsConflict(_ first: [RuleCondition], _ second: [RuleCondition]) -> Bool {
        let firstLocations = first.compactMap(sourceLocationConstraint(from:))
        let secondLocations = second.compactMap(sourceLocationConstraint(from:))

        guard !firstLocations.isEmpty, !secondLocations.isEmpty else {
            return false
        }

        return !firstLocations.contains { firstLocation in
            secondLocations.contains(firstLocation)
        }
    }

    private func prefixConstraintsConflict(_ first: [RuleCondition], _ second: [RuleCondition]) -> Bool {
        let firstPrefixes = first.compactMap(prefixConstraint(from:))
        let secondPrefixes = second.compactMap(prefixConstraint(from:))

        guard !firstPrefixes.isEmpty, !secondPrefixes.isEmpty else {
            return false
        }

        return !firstPrefixes.contains { firstPrefix in
            secondPrefixes.contains { secondPrefix in
                firstPrefix.hasPrefix(secondPrefix) || secondPrefix.hasPrefix(firstPrefix)
            }
        }
    }

    private func suffixConstraintsConflict(_ first: [RuleCondition], _ second: [RuleCondition]) -> Bool {
        let firstSuffixes = first.compactMap(suffixConstraint(from:))
        let secondSuffixes = second.compactMap(suffixConstraint(from:))

        guard !firstSuffixes.isEmpty, !secondSuffixes.isEmpty else {
            return false
        }

        return !firstSuffixes.contains { firstSuffix in
            secondSuffixes.contains { secondSuffix in
                firstSuffix.hasSuffix(secondSuffix) || secondSuffix.hasSuffix(firstSuffix)
            }
        }
    }

    private enum FileTypeConstraint {
        case fileExtension(String)
        case fileKind(String)
    }

    private func fileTypeConstraintsConflict(_ first: [RuleCondition], _ second: [RuleCondition]) -> Bool {
        let firstConstraints = first.compactMap(fileTypeConstraint(from:))
        let secondConstraints = second.compactMap(fileTypeConstraint(from:))

        guard !firstConstraints.isEmpty, !secondConstraints.isEmpty else {
            return false
        }

        return !firstConstraints.contains { firstConstraint in
            secondConstraints.contains { secondConstraint in
                fileTypeConstraintsCouldOverlap(firstConstraint, secondConstraint)
            }
        }
    }

    private func fileTypeConstraint(from condition: RuleCondition) -> FileTypeConstraint? {
        switch condition {
        case .fileExtension(let ext):
            return .fileExtension(ext.lowercased())
        case .fileKind(let kind):
            return .fileKind(normalizedFileKind(kind))
        case .dateOlderThan(_, extension: let ext?):
            return .fileExtension(ext.lowercased())
        default:
            return nil
        }
    }

    private func fileTypeConstraintsCouldOverlap(_ first: FileTypeConstraint, _ second: FileTypeConstraint) -> Bool {
        switch (first, second) {
        case let (.fileExtension(firstExt), .fileExtension(secondExt)):
            return firstExt == secondExt
        case let (.fileKind(firstKind), .fileKind(secondKind)):
            return firstKind == secondKind
        case let (.fileExtension(ext), .fileKind(kind)),
             let (.fileKind(kind), .fileExtension(ext)):
            return extensionMatchesFileKind(ext, kind)
        }
    }

    private func sourceLocationConstraint(from condition: RuleCondition) -> FileLocationKind? {
        guard case .sourceLocation(let location) = condition else {
            return nil
        }
        return location
    }

    private func prefixConstraint(from condition: RuleCondition) -> String? {
        guard case .nameStartsWith(let prefix) = condition else {
            return nil
        }
        return prefix.lowercased()
    }

    private func suffixConstraint(from condition: RuleCondition) -> String? {
        guard case .nameEndsWith(let suffix) = condition else {
            return nil
        }
        return suffix.lowercased()
    }

    private func compareNameContainsToStartsWith(_ containsText: String, _ prefix: String) -> ConditionRelation? {
        let contains = containsText.lowercased()
        let startsWith = prefix.lowercased()

        if contains == startsWith {
            return .superset
        }

        if startsWith.contains(contains) {
            return .superset
        }

        return nil
    }

    private func compareNameContainsToEndsWith(_ containsText: String, _ suffix: String) -> ConditionRelation? {
        let contains = containsText.lowercased()
        let endsWith = suffix.lowercased()

        if contains == endsWith {
            return .superset
        }

        if endsWith.contains(contains) {
            return .superset
        }

        return nil
    }

    private func inverted(_ relation: ConditionRelation?) -> ConditionRelation? {
        guard let relation else { return nil }

        switch relation {
        case .identical:
            return .identical
        case .subset:
            return .superset
        case .superset:
            return .subset
        case .partial:
            return .partial
        }
    }

    private func normalizedFileKind(_ kind: String) -> String {
        let lowercased = kind.lowercased()
        switch lowercased {
        case "images": return "image"
        case "videos": return "video"
        case "documents": return "document"
        case "spreadsheets": return "spreadsheet"
        case "presentations": return "presentation"
        case "archives": return "archive"
        default: return lowercased
        }
    }

    private func extensionMatchesFileKind(_ fileExtension: String, _ kind: String) -> Bool {
        let ext = fileExtension.lowercased()

        switch normalizedFileKind(kind) {
        case "image":
            return ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "heic", "heif", "webp", "svg", "ico", "cr2"].contains(ext)
        case "audio":
            return ["mp3", "wav", "aac", "flac", "ogg", "m4a", "wma", "aiff", "ape"].contains(ext)
        case "video":
            return ["mp4", "mov", "avi", "mkv", "flv", "wmv", "m4v", "mpg", "mpeg", "webm"].contains(ext)
        case "document":
            return ["pdf", "doc", "docx", "txt", "rtf", "odt", "pages", "tex"].contains(ext)
        case "spreadsheet":
            return ["xls", "xlsx", "csv", "numbers", "ods"].contains(ext)
        case "presentation":
            return ["ppt", "pptx", "key", "odp"].contains(ext)
        case "archive":
            return ["zip", "rar", "7z", "tar", "gz", "bz2", "xz", "dmg", "pkg", "iso"].contains(ext)
        case "code":
            return ["swift", "py", "js", "ts", "java", "cpp", "c", "h", "cs", "rb", "go", "rs", "php", "html", "css", "json", "xml", "yaml", "yml"].contains(ext)
        default:
            return false
        }
    }

    /// Checks if two condition sets are equal (order-independent).
    private func conditionSetsEqual(_ first: [RuleCondition], _ second: [RuleCondition]) -> Bool {
        guard first.count == second.count else { return false }

        // Simple equality check for each condition
        for condition in first {
            if !second.contains(where: { conditionEquals(condition, $0) }) {
                return false
            }
        }
        return true
    }

    /// Checks if two conditions are equal.
    private func conditionEquals(_ first: RuleCondition, _ second: RuleCondition) -> Bool {
        switch (first, second) {
        case let (.fileExtension(e1), .fileExtension(e2)):
            return e1.lowercased() == e2.lowercased()
        case let (.nameContains(t1), .nameContains(t2)):
            return t1.lowercased() == t2.lowercased()
        case let (.nameStartsWith(t1), .nameStartsWith(t2)):
            return t1.lowercased() == t2.lowercased()
        case let (.nameEndsWith(t1), .nameEndsWith(t2)):
            return t1.lowercased() == t2.lowercased()
        case let (.sizeLargerThan(s1), .sizeLargerThan(s2)):
            return s1 == s2
        case let (.dateOlderThan(d1, e1), .dateOlderThan(d2, e2)):
            return d1 == d2 && e1?.lowercased() == e2?.lowercased()
        case let (.dateModifiedOlderThan(d1), .dateModifiedOlderThan(d2)):
            return d1 == d2
        case let (.dateAccessedOlderThan(d1), .dateAccessedOlderThan(d2)):
            return d1 == d2
        case let (.fileKind(k1), .fileKind(k2)):
            return k1.lowercased() == k2.lowercased()
        case let (.sourceLocation(l1), .sourceLocation(l2)):
            return l1 == l2
        case let (.not(inner1), .not(inner2)):
            return conditionEquals(inner1, inner2)
        default:
            return false
        }
    }

    /// Checks if two destinations are the same.
    private func destinationsMatch(_ first: Destination?, _ second: Destination?) -> Bool {
        guard let d1 = first, let d2 = second else {
            return first == nil && second == nil
        }

        switch (d1, d2) {
        case (.trash, .trash):
            return true
        case let (.folder(_, name1), .folder(_, name2)):
            // Compare by display name (bookmarks are harder to compare)
            return name1 == name2
        default:
            return false
        }
    }
}
