import Foundation

/// Kinds of semantic clauses we can extract from a natural-language rule description.
enum NLClauseKind: String {
    case action
    case fileType
    case fileKind
    case namePattern
    case timeConstraint
    case sizeConstraint
    case destination
    case logicalOperator
    case sourceLocation
}

/// Tags describing why a clause may be ambiguous or require clarification.
enum NLAmbiguityTag: String {
    case ambiguousTimePhrase
    case ambiguousGrouping
    case multipleFileKinds
    case missingDestination
    case unsupportedVerb
    case conflictingConditions
}

/// Severity for parse issues that should be surfaced in the UI.
enum NLParseIssueSeverity: String {
    case error
    case warning
    case info
}

/// A high-level issue detected while parsing.
struct NLParseIssue {
    let severity: NLParseIssueSeverity
    let message: String
    let relatedKinds: [NLClauseKind]
}

/// A single extracted clause from the user input.
struct NLParsedClause {
    let kind: NLClauseKind
    let rawText: String
    let normalizedValue: String
    let confidence: Double      // 0.0–1.0
    let ambiguityTags: [NLAmbiguityTag]
}

/// Time constraints supported by the parser.
/// These will ultimately be converted into RuleCondition date-based conditions.
enum NLTimeConstraint {
    case olderThan(days: Int)
}

/// High-level hints about how the user wants files grouped/organized.
/// These are intentionally coarse and may require a follow-up question in the UI.
enum NLGroupingHint {
    case byMonth
}

/// User-resolved interpretation for grouping hints.
/// This is only set after the user answers an ambiguity prompt.
enum NLGroupingResolution {
    case byCreationMonth
    case byModificationMonth
    case manual
}

/// A complete parse result for a natural-language rule.
/// This is an ephemeral representation used by the UI before a concrete Rule is created.
struct NLParsedRule {
    let originalText: String
    let clauses: [NLParsedClause]
    let timeConstraints: [NLTimeConstraint]
    let candidateConditions: [RuleCondition]
    let primaryAction: Rule.ActionType?
    let destinationPath: String?
    let logicalOperator: Rule.LogicalOperator
    let overallConfidence: Double
    let issues: [NLParseIssue]
    /// Optional grouping hint derived from phrases like "by month".
    let groupingHint: NLGroupingHint?
    /// Optional resolved interpretation of the grouping hint.
    let groupingResolution: NLGroupingResolution?

    init(
        originalText: String,
        clauses: [NLParsedClause],
        timeConstraints: [NLTimeConstraint],
        candidateConditions: [RuleCondition],
        primaryAction: Rule.ActionType?,
        destinationPath: String?,
        logicalOperator: Rule.LogicalOperator,
        overallConfidence: Double,
        issues: [NLParseIssue],
        groupingHint: NLGroupingHint? = nil,
        groupingResolution: NLGroupingResolution? = nil
    ) {
        self.originalText = originalText
        self.clauses = clauses
        self.timeConstraints = timeConstraints
        self.candidateConditions = candidateConditions
        self.primaryAction = primaryAction
        self.destinationPath = destinationPath
        self.logicalOperator = logicalOperator
        self.overallConfidence = overallConfidence
        self.issues = issues
        self.groupingHint = groupingHint
        self.groupingResolution = groupingResolution
    }

    /// Whether we have enough information to build a concrete Rule.
    var isComplete: Bool {
        guard let action = primaryAction else { return false }
        // Delete rules do not require a destination. Others do.
        if action != .delete && (destinationPath?.isEmpty ?? true) { return false }
        return !candidateConditions.isEmpty
    }

    /// Whether the parse contains any ambiguities the user should resolve.
    var isAmbiguous: Bool {
        return clauses.contains { !$0.ambiguityTags.isEmpty }
    }

    /// Convenience for the UI to know if there are blocking errors.
    var hasBlockingError: Bool {
        issues.contains { $0.severity == .error }
    }

    /// Convert this parsed rule into a concrete Rule model.
    /// - Parameters:
    ///   - name: Optional explicit rule name. If nil, a default name is generated.
    ///   - isEnabled: Whether the resulting rule should start enabled.
    func toRule(name: String? = nil, isEnabled: Bool = false) -> Rule? {
        guard isComplete, let action = primaryAction else { return nil }

        let ruleName: String
        if let explicit = name, !explicit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ruleName = explicit
        } else {
            // Use a short prefix of the original text as a fallback name.
            let trimmed = originalText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                ruleName = "Natural language rule"
            } else if trimmed.count <= 40 {
                ruleName = trimmed
            } else {
                let idx = trimmed.index(trimmed.startIndex, offsetBy: 40)
                ruleName = String(trimmed[..<idx]) + "…"
            }
        }

        // Create destination from path (uses placeholder bookmark)
        let destination: Destination?
        if action == .delete {
            destination = nil
        } else if let path = destinationPath {
            destination = .folder(bookmark: Data(), displayName: path)
        } else {
            destination = nil
        }

        return Rule(
            name: ruleName,
            conditions: candidateConditions,
            logicalOperator: logicalOperator,
            actionType: action,
            destination: destination,
            isEnabled: isEnabled
        )
    }
}

/// Natural-language parser that converts freeform text into NLParsedRule.
///
/// This parser is **fully on-device** and relies only on Foundation/NaturalLanguage.
/// It is intentionally conservative: when unsure, it exposes ambiguity instead of
/// silently guessing.
///
/// Note: This is a struct (not a class) because it's completely stateless.
/// Using a struct also avoids Swift 6 actor-isolated deinit issues when stored
/// in @MainActor classes like NaturalLanguageRuleViewModel.
struct NaturalLanguageRuleParser {

    // MARK: - Public API

    /// Parse user-entered text into a structured NLParsedRule.
    /// Always returns a result for non-empty input; call-sites should inspect
    /// `isComplete`, `isAmbiguous`, and `issues` before creating a Rule.
    func parse(_ text: String) -> NLParsedRule {
        let original = text
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return NLParsedRule(
                originalText: original,
                clauses: [],
                timeConstraints: [],
                candidateConditions: [],
                primaryAction: nil,
                destinationPath: nil,
                logicalOperator: .single,
                overallConfidence: 0.0,
                issues: []
            )
        }

        let lower = trimmed.lowercased()

        var clauses: [NLParsedClause] = []
        var issues: [NLParseIssue] = []
        var conditions: [RuleCondition] = []
        var timeConstraints: [NLTimeConstraint] = []
        var groupingHint: NLGroupingHint? = nil
        let groupingResolution: NLGroupingResolution? = nil

        // 1) Action
        let actionResult = extractAction(from: trimmed, lower: lower)
        if let clause = actionResult.clause { clauses.append(clause) }
        if let issue = actionResult.issue { issues.append(issue) }
        let primaryAction = actionResult.action

        // 2) File types & kinds
        let fileResult = extractFileTypesAndKinds(from: trimmed, lower: lower)
        clauses.append(contentsOf: fileResult.clauses)
        conditions.append(contentsOf: fileResult.conditions)

        // 3) Name patterns
        let nameResult = extractNamePatterns(from: trimmed, lower: lower)
        clauses.append(contentsOf: nameResult.clauses)
        conditions.append(contentsOf: nameResult.conditions)

        // 4) Time constraints
        let timeResult = extractTimeConstraints(from: trimmed, lower: lower)
        clauses.append(contentsOf: timeResult.clauses)
        timeConstraints.append(contentsOf: timeResult.timeConstraints)
        conditions.append(contentsOf: timeResult.conditions)
        issues.append(contentsOf: timeResult.issues)

        // 4.5) Size constraints (e.g., "larger than 500MB")
        let sizeResult = extractSizeConstraints(from: trimmed, lower: lower)
        clauses.append(contentsOf: sizeResult.clauses)
        conditions.append(contentsOf: sizeResult.conditions)

        // 5) Grouping hints (e.g., "by month")
        let groupingResult = extractGroupingHint(from: trimmed, lower: lower)
        clauses.append(contentsOf: groupingResult.clauses)
        issues.append(contentsOf: groupingResult.issues)
        if groupingResult.hint != nil {
            groupingHint = groupingResult.hint
        }

        // 6) Source location (from Desktop, in Downloads, etc.)
        let locationResult = extractSourceLocation(from: trimmed, lower: lower)
        clauses.append(contentsOf: locationResult.clauses)
        conditions.append(contentsOf: locationResult.conditions)

        // 7) Destination
        let destResult = extractDestination(from: trimmed)
        if let clause = destResult.clause { clauses.append(clause) }
        if let issue = destResult.issue { issues.append(issue) }
        let destination = destResult.destination

        // 8) Logical operator
        let logicalOperator = inferLogicalOperator(from: lower, conditionCount: conditions.count)
        if let opClause = destResult.logicalOperatorClause {
            clauses.append(opClause)
        }

        // 9) Compute overall confidence
        let overall = computeOverallConfidence(clauses: clauses, issues: issues)

        return NLParsedRule(
            originalText: original,
            clauses: clauses,
            timeConstraints: timeConstraints,
            candidateConditions: conditions,
            primaryAction: primaryAction,
            destinationPath: destination,
            logicalOperator: logicalOperator,
            overallConfidence: overall,
            issues: issues,
            groupingHint: groupingHint,
            groupingResolution: groupingResolution
        )
    }

    // MARK: - Private helpers

    private struct ActionParseResult {
        let action: Rule.ActionType?
        let clause: NLParsedClause?
        let issue: NLParseIssue?
    }

    private func extractAction(from text: String, lower: String) -> ActionParseResult {
        var foundAction: Rule.ActionType?
        var ambiguityTags: [NLAmbiguityTag] = []

        let deleteRange = range(ofAny: ["delete", "trash", "remove"], in: lower)
        let moveRange = range(ofAny: ["move", "organize", "file", "sort"], in: lower)
        let copyRange = range(ofAny: ["copy", "duplicate"], in: lower)

        if deleteRange != nil { foundAction = .delete }
        if moveRange != nil {
            if foundAction != nil && foundAction != .move {
                ambiguityTags.append(.conflictingConditions)
            }
            if foundAction == nil { foundAction = .move }
        }
        if copyRange != nil {
            if foundAction != nil && foundAction != .copy {
                ambiguityTags.append(.conflictingConditions)
            }
            if foundAction == nil { foundAction = .copy }
        }

        var issue: NLParseIssue?
        if foundAction == nil {
            issue = NLParseIssue(
                severity: .error,
                message: "I couldn't find an action like move, copy, or delete.",
                relatedKinds: [.action]
            )
        }

        let clause: NLParsedClause?
        if let action = foundAction {
            let normalized: String
            switch action {
            case .move: normalized = "move"
            case .copy: normalized = "copy"
            case .delete: normalized = "delete"
            }
            clause = NLParsedClause(
                kind: .action,
                rawText: text,
                normalizedValue: normalized,
                confidence: 0.95,
                ambiguityTags: ambiguityTags
            )
        } else {
            clause = nil
        }

        return ActionParseResult(action: foundAction, clause: clause, issue: issue)
    }

    private struct FileParseResult {
        let clauses: [NLParsedClause]
        let conditions: [RuleCondition]
    }

    // Maps common file type names to their canonical extensions
    private static let extensionAliases: [String: String] = [
        "markdown": "md",
        "javascript": "js",
        "typescript": "ts",
        "python": "py",
        "ruby": "rb",
        "golang": "go",
        "plaintext": "txt",
        "text": "txt"
    ]

    private func extractFileTypesAndKinds(from text: String, lower: String) -> FileParseResult {
        var clauses: [NLParsedClause] = []
        var conditions: [RuleCondition] = []
        var foundExtensions: Set<String> = []

        // Helper to add an extension condition (avoids duplicates)
        func addExtension(_ ext: String, rawText: String, confidence: Double) {
            // Resolve aliases (e.g., "markdown" → "md")
            let normalized = Self.extensionAliases[ext.lowercased()] ?? ext.lowercased()
            guard !foundExtensions.contains(normalized) else { return }
            foundExtensions.insert(normalized)
            conditions.append(.fileExtension(normalized))
            clauses.append(NLParsedClause(
                kind: .fileType,
                rawText: rawText,
                normalizedValue: normalized,
                confidence: confidence,
                ambiguityTags: []
            ))
        }

        // 1a) Dot-prefixed extensions (e.g., ".md", ".txt", ".pdf")
        // This handles the common user pattern of writing ".ext files"
        let dotPrefixPattern = #"\.([a-zA-Z0-9]{1,10})\s+files?"#
        if let regex = try? NSRegularExpression(pattern: dotPrefixPattern, options: [.caseInsensitive]) {
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = regex.matches(in: text, options: [], range: nsRange)
            for match in matches {
                if let r = Range(match.range(at: 1), in: text) {
                    let ext = String(text[r])
                    addExtension(ext, rawText: ".\(ext)", confidence: 0.95)
                }
            }
        }

        // 1b) Explicit common extensions (expanded list, without leading dot)
        // Includes: documents, images, audio, video, archives, code, data, config
        // Also includes aliases like "markdown" which get resolved via extensionAliases
        // The trailing `s?` handles plurals (e.g., "PDFs" → captures "pdf")
        let explicitPattern = #"\b(pdf|docx?|xlsx?|pptx?|png|jpe?g|heic|gif|bmp|tiff?|svg|webp|mov|mp4|avi|mkv|wmv|flv|webm|mp3|wav|aac|flac|ogg|m4a|zip|dmg|tar|gz|rar|7z|iso|md|markdown|txt|plaintext|rtf|csv|json|xml|html?|css|js|javascript|ts|typescript|jsx|tsx|py|python|swift|rb|ruby|go|golang|rs|java|c|cpp|h|hpp|sh|bash|zsh|yml|yaml|toml|ini|cfg|log|sql|db|sqlite|plist|ics|vcf|eml|epub|mobi|azw3?)s?\b"#
        if let regex = try? NSRegularExpression(pattern: explicitPattern, options: [.caseInsensitive]) {
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = regex.matches(in: text, options: [], range: nsRange)
            for match in matches {
                if let r = Range(match.range(at: 1), in: text) {
                    let ext = String(text[r])
                    addExtension(ext, rawText: ext, confidence: 0.95)
                }
            }
        }

        // 2) Semantic kinds - but EXCLUDE destination path to avoid false positives
        // e.g., "move .md to Documents/Archive" should NOT trigger fileKind("document") or fileKind("archive")
        let destinationPattern = #"(?:to|into)\s+[A-Za-z0-9 _.\-]+(?:/[A-Za-z0-9 _.\-]+)*"#
        var textBeforeDestination = lower
        if let regex = try? NSRegularExpression(pattern: destinationPattern, options: [.caseInsensitive]) {
            let nsRange = NSRange(lower.startIndex..<lower.endIndex, in: lower)
            if let match = regex.firstMatch(in: lower, options: [], range: nsRange),
               let range = Range(match.range, in: lower) {
                textBeforeDestination = String(lower[..<range.lowerBound])
            }
        }

        func addKind(_ kind: String, token: String) {
            conditions.append(.fileKind(kind))
            clauses.append(NLParsedClause(
                kind: .fileKind,
                rawText: token,
                normalizedValue: kind,
                confidence: 0.75,
                ambiguityTags: []
            ))
        }

        // Check for "screenshot" in full text (it's a name pattern, not a path word)
        if lower.contains("screenshot") {
            conditions.append(.nameContains("screenshot"))
            clauses.append(NLParsedClause(
                kind: .namePattern,
                rawText: "screenshot",
                normalizedValue: "screenshot",
                confidence: 0.85,
                ambiguityTags: []
            ))
        }

        // Semantic file kinds - only check text BEFORE the destination phrase
        // Use word boundaries to avoid partial matches (e.g., "archived" shouldn't match)
        let imageKeywords = ["image", "images", "photo", "photos", "picture", "pictures"]
        if imageKeywords.contains(where: { textBeforeDestination.range(of: "\\b\($0)\\b", options: .regularExpression) != nil }) {
            addKind("image", token: "images")
        }

        // Only match "document(s)" as a standalone word, not as part of a path
        if textBeforeDestination.range(of: "\\bdocuments?\\b", options: .regularExpression) != nil {
            addKind("document", token: "documents")
        }

        // Only match "archive(s)" or "zip" as standalone words for file kind
        // Note: "zip" as extension is handled above; here we check for semantic meaning
        if textBeforeDestination.range(of: "\\barchives?\\b", options: .regularExpression) != nil ||
           textBeforeDestination.range(of: "\\bzip\\b", options: .regularExpression) != nil {
            addKind("archive", token: "archives")
        }

        return FileParseResult(clauses: clauses, conditions: conditions)
    }

    private struct NameParseResult {
        let clauses: [NLParsedClause]
        let conditions: [RuleCondition]
    }

    private func extractNamePatterns(from text: String, lower: String) -> NameParseResult {
        var clauses: [NLParsedClause] = []
        var conditions: [RuleCondition] = []
        var foundValues: Set<String> = [] // Avoid duplicate conditions

        // Helper to add a nameContains condition (avoids duplicates)
        func addContains(_ value: String, rawText: String, confidence: Double) {
            let normalized = value.lowercased()
            guard !normalized.isEmpty, !foundValues.contains("contains:\(normalized)") else { return }
            foundValues.insert("contains:\(normalized)")
            conditions.append(.nameContains(value))
            clauses.append(NLParsedClause(
                kind: .namePattern,
                rawText: rawText,
                normalizedValue: normalized,
                confidence: confidence,
                ambiguityTags: []
            ))
        }

        // Helper to add a nameStartsWith condition (avoids duplicates)
        func addStartsWith(_ value: String, rawText: String, confidence: Double) {
            let normalized = value.lowercased()
            guard !normalized.isEmpty, !foundValues.contains("starts:\(normalized)") else { return }
            foundValues.insert("starts:\(normalized)")
            conditions.append(.nameStartsWith(value))
            clauses.append(NLParsedClause(
                kind: .namePattern,
                rawText: rawText,
                normalizedValue: normalized,
                confidence: confidence,
                ambiguityTags: []
            ))
        }

        // Helper to add a nameEndsWith condition (avoids duplicates)
        func addEndsWith(_ value: String, rawText: String, confidence: Double) {
            let normalized = value.lowercased()
            guard !normalized.isEmpty, !foundValues.contains("ends:\(normalized)") else { return }
            foundValues.insert("ends:\(normalized)")
            conditions.append(.nameEndsWith(value))
            clauses.append(NLParsedClause(
                kind: .namePattern,
                rawText: rawText,
                normalizedValue: normalized,
                confidence: confidence,
                ambiguityTags: []
            ))
        }

        // Helper to extract value after a pattern match (quoted or unquoted word)
        func extractValueAfterMatch(in str: String, from index: String.Index) -> String? {
            let remaining = str[index...].trimmingCharacters(in: .whitespaces)
            guard !remaining.isEmpty else { return nil }

            // Check for quoted value first
            let quoteChars: [(open: Character, close: Character)] = [
                ("'", "'"), ("\"", "\""), ("`", "`"),
                ("\u{2018}", "\u{2019}"), // Smart single quotes ''
                ("\u{201C}", "\u{201D}")  // Smart double quotes ""
            ]
            for (open, close) in quoteChars {
                if remaining.first == open {
                    let afterOpen = remaining.dropFirst()
                    if let closeIndex = afterOpen.firstIndex(of: close) {
                        return String(afterOpen[..<closeIndex])
                    }
                }
            }

            // Otherwise, extract first word (stop at common stop words)
            let stopWords = Set(["to", "into", "in", "from", "older", "newer", "larger", "smaller", "and", "or", "files", "file"])
            var word = ""
            for char in remaining {
                if char.isWhitespace { break }
                word.append(char)
            }
            // Check if word is a stop word or too short
            if stopWords.contains(word.lowercased()) || word.count < 2 {
                return nil
            }
            return word
        }

        // ═══════════════════════════════════════════════════════════════════════════
        // 1. QUOTED STRINGS (highest confidence)
        // Handles: "value", 'value', `value`, "value", 'value'
        // ═══════════════════════════════════════════════════════════════════════════
        // Note: Raw strings don't interpret \u{} escapes, so we insert Unicode chars directly
        let smartQuotes = "\u{2018}\u{2019}\u{201C}\u{201D}" // ''""
        let openSmartQuotes = "\u{2018}\u{201C}"  // ' "  (left single/double)
        let closeSmartQuotes = "\u{2019}\u{201D}" // ' "  (right single/double)
        let allQuotesPattern = "[\"'`\(smartQuotes)]([^\"'`\(smartQuotes)]+)[\"'`\(smartQuotes)]"
        if let regex = try? NSRegularExpression(pattern: allQuotesPattern, options: []) {
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = regex.matches(in: text, options: [], range: nsRange)
            for match in matches {
                if let r = Range(match.range(at: 1), in: text) {
                    let value = String(text[r])
                    // Skip if value looks like a destination path
                    if !value.contains("/") {
                        addContains(value, rawText: "'\(value)'", confidence: 0.92)
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════════════════
        // 2. "IN THE NAME/FILENAME" PATTERNS (high priority - reported bug)
        // Handles: "with X in the name", "X in the filename", "X in their name"
        // ═══════════════════════════════════════════════════════════════════════════
        let inNamePatterns = [
            // "with 'X' in the name" - quoted value before "in the name"
            "with\\s+[\"'`\(openSmartQuotes)]([^\"'`\(closeSmartQuotes)]+)[\"'`\(closeSmartQuotes)]\\s+in\\s+(?:the\\s+)?(?:file)?name",
            // "with X in the name" - unquoted value
            "with\\s+(\\S+)\\s+in\\s+(?:the\\s+)?(?:file)?name",
            // "X in the name/filename" - value followed by "in the name"
            "(\\S+)\\s+in\\s+(?:the\\s+)?(?:file)?name",
            // "in their name(s)"
            "with\\s+[\"'`\(openSmartQuotes)]([^\"'`\(closeSmartQuotes)]+)[\"'`\(closeSmartQuotes)]\\s+in\\s+their\\s+names?",
            "with\\s+(\\S+)\\s+in\\s+their\\s+names?"
        ]
        for pattern in inNamePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let nsRange = NSRange(lower.startIndex..<lower.endIndex, in: lower)
                if let match = regex.firstMatch(in: lower, options: [], range: nsRange),
                   let valueRange = Range(match.range(at: 1), in: lower) {
                    // Get the original case value from text
                    let lowerValue = String(lower[valueRange])
                    // Find corresponding range in original text
                    if let textRange = text.range(of: lowerValue, options: .caseInsensitive) {
                        let value = String(text[textRange])
                        addContains(value, rawText: "'\(value)' in name", confidence: 0.88)
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════════════════
        // 3. "NAMED/CALLED" PATTERNS
        // Handles: "files named X", "files called X", "named X"
        // ═══════════════════════════════════════════════════════════════════════════
        let namedPatterns = [
            "(?:files?\\s+)?named\\s+[\"'`\(openSmartQuotes)]([^\"'`\(closeSmartQuotes)]+)[\"'`\(closeSmartQuotes)]",
            "(?:files?\\s+)?named\\s+(\\S+)",
            "(?:files?\\s+)?called\\s+[\"'`\(openSmartQuotes)]([^\"'`\(closeSmartQuotes)]+)[\"'`\(closeSmartQuotes)]",
            "(?:files?\\s+)?called\\s+(\\S+)"
        ]
        for pattern in namedPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let nsRange = NSRange(lower.startIndex..<lower.endIndex, in: lower)
                if let match = regex.firstMatch(in: lower, options: [], range: nsRange),
                   let valueRange = Range(match.range(at: 1), in: lower) {
                    let lowerValue = String(lower[valueRange])
                    // Skip stop words
                    let stopWords = Set(["to", "into", "in", "from", "the", "a", "an"])
                    if !stopWords.contains(lowerValue) {
                        if let textRange = text.range(of: lowerValue, options: .caseInsensitive) {
                            let value = String(text[textRange])
                            addContains(value, rawText: "named '\(value)'", confidence: 0.85)
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════════════════
        // 4. "CONTAINING/CONTAINS" PATTERNS
        // Handles: "containing X", "that contain X", "which contain X"
        // ═══════════════════════════════════════════════════════════════════════════
        let containingPatterns = [
            "containing\\s+[\"'`\(openSmartQuotes)]([^\"'`\(closeSmartQuotes)]+)[\"'`\(closeSmartQuotes)]",
            "containing\\s+(\\S+)",
            "(?:that|which)\\s+contains?\\s+[\"'`\(openSmartQuotes)]([^\"'`\(closeSmartQuotes)]+)[\"'`\(closeSmartQuotes)]",
            "(?:that|which)\\s+contains?\\s+(\\S+)",
            "files?\\s+with\\s+[\"'`\(openSmartQuotes)]([^\"'`\(closeSmartQuotes)]+)[\"'`\(closeSmartQuotes)](?:\\s+in)?"
        ]
        for pattern in containingPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let nsRange = NSRange(lower.startIndex..<lower.endIndex, in: lower)
                if let match = regex.firstMatch(in: lower, options: [], range: nsRange),
                   let valueRange = Range(match.range(at: 1), in: lower) {
                    let lowerValue = String(lower[valueRange])
                    let stopWords = Set(["to", "into", "in", "from", "the", "a", "an", "files", "file"])
                    if !stopWords.contains(lowerValue) {
                        if let textRange = text.range(of: lowerValue, options: .caseInsensitive) {
                            let value = String(text[textRange])
                            addContains(value, rawText: "containing '\(value)'", confidence: 0.85)
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════════════════
        // 5. PREFIX PATTERNS (starting with, beginning with, prefixed with)
        // ═══════════════════════════════════════════════════════════════════════════
        let prefixPatterns = [
            "(?:starting|beginning|start|begin)\\s+with\\s+[\"'`\(openSmartQuotes)]([^\"'`\(closeSmartQuotes)]+)[\"'`\(closeSmartQuotes)]",
            "(?:starting|beginning|start|begin)\\s+with\\s+(\\S+)",
            "(?:that|which)\\s+(?:starts?|begins?)\\s+with\\s+[\"'`\(openSmartQuotes)]([^\"'`\(closeSmartQuotes)]+)[\"'`\(closeSmartQuotes)]",
            "(?:that|which)\\s+(?:starts?|begins?)\\s+with\\s+(\\S+)",
            "prefixed\\s+(?:with\\s+)?[\"'`\(openSmartQuotes)]([^\"'`\(closeSmartQuotes)]+)[\"'`\(closeSmartQuotes)]",
            "prefixed\\s+(?:with\\s+)?(\\S+)"
        ]
        for pattern in prefixPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let nsRange = NSRange(lower.startIndex..<lower.endIndex, in: lower)
                if let match = regex.firstMatch(in: lower, options: [], range: nsRange),
                   let valueRange = Range(match.range(at: 1), in: lower) {
                    let lowerValue = String(lower[valueRange])
                    let stopWords = Set(["to", "into", "in", "from", "the", "a", "an"])
                    if !stopWords.contains(lowerValue) {
                        if let textRange = text.range(of: lowerValue, options: .caseInsensitive) {
                            let value = String(text[textRange])
                            addStartsWith(value, rawText: "starting with '\(value)'", confidence: 0.88)
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════════════════
        // 6. SUFFIX PATTERNS (ending with, ending in, suffixed with)
        // ═══════════════════════════════════════════════════════════════════════════
        let suffixPatterns = [
            "(?:ending|end)\\s+(?:with|in)\\s+[\"'`\(openSmartQuotes)]([^\"'`\(closeSmartQuotes)]+)[\"'`\(closeSmartQuotes)]",
            "(?:ending|end)\\s+(?:with|in)\\s+(\\S+)",
            "(?:that|which)\\s+ends?\\s+(?:with|in)\\s+[\"'`\(openSmartQuotes)]([^\"'`\(closeSmartQuotes)]+)[\"'`\(closeSmartQuotes)]",
            "(?:that|which)\\s+ends?\\s+(?:with|in)\\s+(\\S+)",
            "suffixed\\s+(?:with\\s+)?[\"'`\(openSmartQuotes)]([^\"'`\(closeSmartQuotes)]+)[\"'`\(closeSmartQuotes)]",
            "suffixed\\s+(?:with\\s+)?(\\S+)"
        ]
        for pattern in suffixPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let nsRange = NSRange(lower.startIndex..<lower.endIndex, in: lower)
                if let match = regex.firstMatch(in: lower, options: [], range: nsRange),
                   let valueRange = Range(match.range(at: 1), in: lower) {
                    let lowerValue = String(lower[valueRange])
                    let stopWords = Set(["to", "into", "in", "from", "the", "a", "an"])
                    if !stopWords.contains(lowerValue) {
                        if let textRange = text.range(of: lowerValue, options: .caseInsensitive) {
                            let value = String(text[textRange])
                            addEndsWith(value, rawText: "ending with '\(value)'", confidence: 0.88)
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════════════════
        // 7. WILDCARD/GLOB PATTERNS
        // Handles: "project-*", "*-backup", "*temp*"
        // ═══════════════════════════════════════════════════════════════════════════
        // Pattern: word-* (prefix wildcard)
        let prefixWildcardPattern = #"\b([a-zA-Z0-9_-]+)-\*"#
        if let regex = try? NSRegularExpression(pattern: prefixWildcardPattern, options: []) {
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = regex.matches(in: text, options: [], range: nsRange)
            for match in matches {
                if let r = Range(match.range(at: 1), in: text) {
                    let prefix = String(text[r]) + "-"
                    addStartsWith(prefix, rawText: "\(prefix)*", confidence: 0.85)
                }
            }
        }

        // Pattern: *-word (suffix wildcard)
        let suffixWildcardPattern = #"\*-([a-zA-Z0-9_-]+)\b"#
        if let regex = try? NSRegularExpression(pattern: suffixWildcardPattern, options: []) {
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = regex.matches(in: text, options: [], range: nsRange)
            for match in matches {
                if let r = Range(match.range(at: 1), in: text) {
                    let suffix = "-" + String(text[r])
                    addEndsWith(suffix, rawText: "*\(suffix)", confidence: 0.85)
                }
            }
        }

        // Pattern: *word* (contains wildcard)
        let containsWildcardPattern = #"\*([a-zA-Z0-9_-]+)\*"#
        if let regex = try? NSRegularExpression(pattern: containsWildcardPattern, options: []) {
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = regex.matches(in: text, options: [], range: nsRange)
            for match in matches {
                if let r = Range(match.range(at: 1), in: text) {
                    let value = String(text[r])
                    addContains(value, rawText: "*\(value)*", confidence: 0.85)
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════════════════
        // 8. LEGACY HEURISTICS (lower confidence fallbacks)
        // Handles: "work documents", "invoice files"
        // ═══════════════════════════════════════════════════════════════════════════
        if lower.range(of: "\\bwork\\s+documents?\\b", options: .regularExpression) != nil {
            addContains("work", rawText: "work documents", confidence: 0.6)
        }

        // "invoice" as standalone word (not already captured)
        if lower.range(of: "\\binvoices?\\b", options: .regularExpression) != nil {
            addContains("invoice", rawText: "invoice", confidence: 0.7)
        }

        // "screenshot" as standalone word
        if lower.range(of: "\\bscreenshots?\\b", options: .regularExpression) != nil {
            addContains("screenshot", rawText: "screenshot", confidence: 0.75)
        }

        // "backup" as standalone word (when not in destination context)
        // Be careful: "to Backup" is a destination, "backup files" is a name pattern
        if lower.range(of: "\\bbackup\\s+files?\\b", options: .regularExpression) != nil ||
           lower.range(of: "\\bfiles?\\s+(?:named|called)?\\s*backup\\b", options: .regularExpression) != nil {
            addContains("backup", rawText: "backup", confidence: 0.7)
        }

        return NameParseResult(clauses: clauses, conditions: conditions)
    }

    private struct TimeParseResult {
        let clauses: [NLParsedClause]
        let timeConstraints: [NLTimeConstraint]
        let conditions: [RuleCondition]
        let issues: [NLParseIssue]
    }

    // Maps word numbers to integers for time parsing
    private static let wordToNumber: [String: Int] = [
        "one": 1, "a": 1, "an": 1,
        "two": 2,
        "three": 3,
        "four": 4,
        "five": 5,
        "six": 6,
        "seven": 7,
        "eight": 8,
        "nine": 9,
        "ten": 10,
        "eleven": 11,
        "twelve": 12
    ]

    private func extractTimeConstraints(from text: String, lower: String) -> TimeParseResult {
        var clauses: [NLParsedClause] = []
        var constraints: [NLTimeConstraint] = []
        var conditions: [RuleCondition] = []
        var issues: [NLParseIssue] = []

        // "older than X days/weeks/months/years" - supports both numeric and word numbers
        // Examples: "older than 30 days", "older than one month", "older than a week"
        let pattern = #"older than\s+(\d+|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|a|an)\s+(day|days|week|weeks|month|months|year|years)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, options: [], range: nsRange),
               let valueRange = Range(match.range(at: 1), in: text),
               let unitRange = Range(match.range(at: 2), in: text) {
                let numberString = String(text[valueRange]).lowercased()
                let unitString = String(text[unitRange]).lowercased()
                // Parse number from digits or word
                let number = Int(numberString) ?? Self.wordToNumber[numberString] ?? 0
                if number > 0 {
                    let days = convertToDays(number: number, unit: unitString)
                    constraints.append(.olderThan(days: days))
                    conditions.append(.dateOlderThan(days: days, extension: nil))
                    let raw = String(text[Range(match.range, in: text)!])
                    clauses.append(NLParsedClause(
                        kind: .timeConstraint,
                        rawText: raw,
                        normalizedValue: "older_than_\(days)_days",
                        confidence: 0.9,
                        ambiguityTags: []
                    ))
                }
            }
        }

        // Phrases "last week" / "last month" as shortcuts
        if lower.contains("last week") {
            constraints.append(.olderThan(days: 7))
            conditions.append(.dateOlderThan(days: 7, extension: nil))
            clauses.append(NLParsedClause(
                kind: .timeConstraint,
                rawText: "last week",
                normalizedValue: "older_than_7_days",
                confidence: 0.8,
                ambiguityTags: [.ambiguousTimePhrase]
            ))
            issues.append(NLParseIssue(
                severity: .warning,
                message: "‘Last week’ was interpreted as older than 7 days.",
                relatedKinds: [.timeConstraint]
            ))
        }
        if lower.contains("last month") {
            constraints.append(.olderThan(days: 30))
            conditions.append(.dateOlderThan(days: 30, extension: nil))
            clauses.append(NLParsedClause(
                kind: .timeConstraint,
                rawText: "last month",
                normalizedValue: "older_than_30_days",
                confidence: 0.8,
                ambiguityTags: [.ambiguousTimePhrase]
            ))
            issues.append(NLParseIssue(
                severity: .warning,
                message: "‘Last month’ was interpreted as older than 30 days.",
                relatedKinds: [.timeConstraint]
            ))
        }

        return TimeParseResult(
            clauses: clauses,
            timeConstraints: constraints,
            conditions: conditions,
            issues: issues
        )
    }

    // MARK: - Size Constraint Extraction

    private struct SizeParseResult {
        let clauses: [NLParsedClause]
        let conditions: [RuleCondition]
    }

    // Maps size units to their byte multipliers
    private static let sizeUnitMultipliers: [String: Int64] = [
        "b": 1,
        "byte": 1,
        "bytes": 1,
        "kb": 1024,
        "kilobyte": 1024,
        "kilobytes": 1024,
        "mb": 1024 * 1024,
        "megabyte": 1024 * 1024,
        "megabytes": 1024 * 1024,
        "gb": 1024 * 1024 * 1024,
        "gigabyte": 1024 * 1024 * 1024,
        "gigabytes": 1024 * 1024 * 1024,
        "tb": 1024 * 1024 * 1024 * 1024,
        "terabyte": 1024 * 1024 * 1024 * 1024,
        "terabytes": 1024 * 1024 * 1024 * 1024
    ]

    /// Extracts size constraints like "larger than 500MB" or "bigger than 1GB"
    private func extractSizeConstraints(from text: String, lower: String) -> SizeParseResult {
        var clauses: [NLParsedClause] = []
        var conditions: [RuleCondition] = []

        // Pattern: "larger than X MB", "bigger than X GB", "over X MB", "more than X bytes"
        // Supports optional decimal like "1.5GB"
        let pattern = #"(?:larger|bigger|over|more)\s+than\s+(\d+(?:\.\d+)?)\s*(b|bytes?|kb|kilobytes?|mb|megabytes?|gb|gigabytes?|tb|terabytes?)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, options: [], range: nsRange),
               let valueRange = Range(match.range(at: 1), in: text),
               let unitRange = Range(match.range(at: 2), in: text) {

                let valueStr = String(text[valueRange])
                let unitStr = String(text[unitRange]).lowercased()

                if let value = Double(valueStr),
                   let multiplier = Self.sizeUnitMultipliers[unitStr] {
                    let bytes = Int64(value * Double(multiplier))

                    clauses.append(NLParsedClause(
                        kind: .sizeConstraint,
                        rawText: String(text[Range(match.range, in: text)!]),
                        normalizedValue: "larger_than_\(bytes)_bytes",
                        confidence: 0.95,
                        ambiguityTags: []
                    ))

                    conditions.append(.sizeLargerThan(bytes: bytes))
                }
            }
        }

        return SizeParseResult(clauses: clauses, conditions: conditions)
    }

    private struct GroupingParseResult {
        let clauses: [NLParsedClause]
        let issues: [NLParseIssue]
        let hint: NLGroupingHint?
    }

    /// Extracts high-level grouping hints like "organize by month" and marks them as
    /// ambiguous so the UI can ask follow-up questions.
    private func extractGroupingHint(from text: String, lower: String) -> GroupingParseResult {
        var clauses: [NLParsedClause] = []
        var issues: [NLParseIssue] = []
        var hint: NLGroupingHint? = nil

        if lower.contains("by month") || lower.contains("per month") || lower.contains("each month") {
            hint = .byMonth
            clauses.append(NLParsedClause(
                kind: .timeConstraint,
                rawText: "by month",
                normalizedValue: "group_by_month",
                confidence: 0.7,
                ambiguityTags: [.ambiguousGrouping]
            ))
            issues.append(NLParseIssue(
                severity: .warning,
                message: "“By month” can mean organizing by creation month or modification month.",
                relatedKinds: [.timeConstraint]
            ))
        }

        return GroupingParseResult(clauses: clauses, issues: issues, hint: hint)
    }

    // MARK: - Source Location Extraction

    private struct SourceLocationParseResult {
        let clauses: [NLParsedClause]
        let conditions: [RuleCondition]
    }

    /// Extracts source location conditions from phrases like "from Desktop", "in Downloads",
    /// "on the Desktop", "from the Downloads folder", "files located in Downloads",
    /// "that are in Desktop", "within Documents", "out of Downloads", etc.
    ///
    /// This function handles a wide variety of natural language patterns for specifying
    /// where files are currently located (as opposed to where they should be moved TO).
    private func extractSourceLocation(from text: String, lower: String) -> SourceLocationParseResult {
        var clauses: [NLParsedClause] = []
        var conditions: [RuleCondition] = []
        var foundLocations: Set<FileLocationKind> = []

        // Helper to add a source location condition (avoids duplicates)
        func addLocation(_ location: FileLocationKind, rawText: String, confidence: Double) {
            guard !foundLocations.contains(location), location != .unknown, location != .custom else { return }
            foundLocations.insert(location)
            conditions.append(.sourceLocation(location))
            clauses.append(NLParsedClause(
                kind: .sourceLocation,
                rawText: rawText,
                normalizedValue: location.rawValue,
                confidence: confidence,
                ambiguityTags: []
            ))
        }

        // Map of location keywords to FileLocationKind
        // Each entry has multiple patterns that should map to the same location
        let locationKeywords: [(patterns: [String], kind: FileLocationKind)] = [
            (["desktop", "my desktop"], .desktop),
            (["downloads", "download folder", "download directory"], .downloads),
            (["documents", "my documents", "document folder"], .documents),
            (["pictures", "photos", "my pictures", "picture folder"], .pictures),
            (["music", "my music", "music folder"], .music),
            (["home", "home folder", "home directory"], .home)
        ]

        // ═══════════════════════════════════════════════════════════════════════════
        // SOURCE/DESTINATION CONFLICT HANDLING
        // ═══════════════════════════════════════════════════════════════════════════
        // Extract text BEFORE any destination phrase to avoid confusing source with dest.
        // e.g., "move files from Desktop to Documents" - we only want "Desktop" as source
        var textForSourceExtraction = lower
        let destinationPattern = #"\s+(?:to|into)\s+[A-Za-z0-9 _.\-/]+"#
        if let regex = try? NSRegularExpression(pattern: destinationPattern, options: [.caseInsensitive]) {
            let nsRange = NSRange(lower.startIndex..<lower.endIndex, in: lower)
            if let match = regex.firstMatch(in: lower, options: [], range: nsRange),
               let range = Range(match.range, in: lower) {
                textForSourceExtraction = String(lower[..<range.lowerBound])
            }
        }

        // Helper to run pattern matching against the source-safe text
        func matchPatterns(_ patterns: [String], confidence: Double) {
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                    let nsRange = NSRange(textForSourceExtraction.startIndex..<textForSourceExtraction.endIndex, in: textForSourceExtraction)
                    let matches = regex.matches(in: textForSourceExtraction, options: [], range: nsRange)
                    for match in matches {
                        if let r = Range(match.range(at: 1), in: textForSourceExtraction) {
                            let captured = String(textForSourceExtraction[r]).lowercased()

                            // Check if captured word matches a known location
                            for (keywords, kind) in locationKeywords {
                                if keywords.contains(captured) {
                                    let raw = String(textForSourceExtraction[Range(match.range, in: textForSourceExtraction)!])
                                    addLocation(kind, rawText: raw, confidence: confidence)
                                    break
                                }
                            }
                        }
                    }
                }
            }
        }

        // ═══════════════════════════════════════════════════════════════════════════
        // 1. BASIC PREPOSITION PATTERNS (high confidence)
        // "from Desktop", "in Downloads", "on the Desktop", "from my Downloads folder"
        // ═══════════════════════════════════════════════════════════════════════════
        let basicPatterns = [
            #"(?:from|in|on)\s+(?:the\s+)?(?:my\s+)?(\w+)(?:\s+folder|\s+directory)?"#,
            #"files?\s+(?:from|in|on)\s+(?:the\s+)?(?:my\s+)?(\w+)"#
        ]
        matchPatterns(basicPatterns, confidence: 0.85)

        // ═══════════════════════════════════════════════════════════════════════════
        // 2. "LOCATED/STORED/SITTING/FOUND IN" PATTERNS (high confidence)
        // "files located in Downloads", "stored on Desktop", "sitting in Documents"
        // ═══════════════════════════════════════════════════════════════════════════
        let locatedPatterns = [
            #"(?:located|stored|sitting|found|living)\s+(?:in|on|at)\s+(?:the\s+)?(?:my\s+)?(\w+)"#,
            #"files?\s+(?:located|stored|sitting|found|living)\s+(?:in|on|at)\s+(?:the\s+)?(?:my\s+)?(\w+)"#
        ]
        matchPatterns(locatedPatterns, confidence: 0.88)

        // ═══════════════════════════════════════════════════════════════════════════
        // 3. "THAT ARE IN/ON" RELATIVE CLAUSE PATTERNS (high confidence)
        // "files that are in Downloads", "that are on Desktop"
        // ═══════════════════════════════════════════════════════════════════════════
        let relativeClausePatterns = [
            #"that\s+(?:are|is|sit|live)\s+(?:in|on|at)\s+(?:the\s+)?(?:my\s+)?(\w+)"#,
            #"which\s+(?:are|is)\s+(?:in|on|at)\s+(?:the\s+)?(?:my\s+)?(\w+)"#
        ]
        matchPatterns(relativeClausePatterns, confidence: 0.88)

        // ═══════════════════════════════════════════════════════════════════════════
        // 4. "WITHIN" KEYWORD PATTERN (high confidence)
        // "files within Downloads", "within the Desktop folder"
        // ═══════════════════════════════════════════════════════════════════════════
        let withinPatterns = [
            #"within\s+(?:the\s+)?(?:my\s+)?(\w+)(?:\s+folder|\s+directory)?"#,
            #"files?\s+within\s+(?:the\s+)?(?:my\s+)?(\w+)"#
        ]
        matchPatterns(withinPatterns, confidence: 0.85)

        // ═══════════════════════════════════════════════════════════════════════════
        // 5. "OUT OF" PATTERN (high confidence - implies source)
        // "move files out of Downloads", "out of Desktop"
        // ═══════════════════════════════════════════════════════════════════════════
        let outOfPatterns = [
            #"out\s+of\s+(?:the\s+)?(?:my\s+)?(\w+)(?:\s+folder|\s+directory)?"#,
            #"files?\s+out\s+of\s+(?:the\s+)?(?:my\s+)?(\w+)"#
        ]
        matchPatterns(outOfPatterns, confidence: 0.88)

        // ═══════════════════════════════════════════════════════════════════════════
        // 6. "CURRENTLY IN/ON" EMPHASIS PATTERNS (high confidence)
        // "files currently in Downloads", "currently on Desktop"
        // ═══════════════════════════════════════════════════════════════════════════
        let currentlyPatterns = [
            #"currently\s+(?:in|on|at)\s+(?:the\s+)?(?:my\s+)?(\w+)"#,
            #"files?\s+currently\s+(?:in|on|at)\s+(?:the\s+)?(?:my\s+)?(\w+)"#
        ]
        matchPatterns(currentlyPatterns, confidence: 0.90)

        // ═══════════════════════════════════════════════════════════════════════════
        // 7. "SAVED TO/IN" PATTERNS (medium-high confidence)
        // Past action implies current location
        // "files saved to Downloads", "saved in Desktop"
        // ═══════════════════════════════════════════════════════════════════════════
        let savedPatterns = [
            #"saved\s+(?:to|in|on)\s+(?:the\s+)?(?:my\s+)?(\w+)"#,
            #"files?\s+saved\s+(?:to|in|on)\s+(?:the\s+)?(?:my\s+)?(\w+)"#,
            #"downloaded\s+(?:to|in)\s+(?:the\s+)?(?:my\s+)?(\w+)"#
        ]
        matchPatterns(savedPatterns, confidence: 0.82)

        // ═══════════════════════════════════════════════════════════════════════════
        // 8. PATH-STYLE PATTERNS (high confidence)
        // "~/Desktop", "~/Downloads", "files at ~/Documents"
        // ═══════════════════════════════════════════════════════════════════════════
        let pathPatterns = [
            #"~/(\w+)"#,  // ~/Desktop, ~/Downloads
            #"(?:at|in|from)\s+~/(\w+)"#  // at ~/Desktop, from ~/Downloads
        ]
        matchPatterns(pathPatterns, confidence: 0.90)

        // Also check for standalone ~ meaning home
        if textForSourceExtraction.contains("~/") == false && textForSourceExtraction.range(of: #"\b~\b"#, options: .regularExpression) != nil {
            addLocation(.home, rawText: "~", confidence: 0.85)
        }

        // ═══════════════════════════════════════════════════════════════════════════
        // 9. "INSIDE" KEYWORD PATTERN (medium-high confidence)
        // "files inside Downloads", "inside the Desktop folder"
        // ═══════════════════════════════════════════════════════════════════════════
        let insidePatterns = [
            #"inside\s+(?:the\s+)?(?:my\s+)?(\w+)(?:\s+folder|\s+directory)?"#,
            #"files?\s+inside\s+(?:the\s+)?(?:my\s+)?(\w+)"#
        ]
        matchPatterns(insidePatterns, confidence: 0.85)

        // ═══════════════════════════════════════════════════════════════════════════
        // 10. LOWER CONFIDENCE: "Desktop files" pattern (location before "files")
        // Only match if no higher-confidence patterns already found
        // ═══════════════════════════════════════════════════════════════════════════
        if foundLocations.isEmpty {
            let prefixPattern = #"(\w+)\s+files?\b"#
            if let regex = try? NSRegularExpression(pattern: prefixPattern, options: [.caseInsensitive]) {
                let nsRange = NSRange(textForSourceExtraction.startIndex..<textForSourceExtraction.endIndex, in: textForSourceExtraction)
                let matches = regex.matches(in: textForSourceExtraction, options: [], range: nsRange)
                for match in matches {
                    if let r = Range(match.range(at: 1), in: textForSourceExtraction) {
                        let captured = String(textForSourceExtraction[r]).lowercased()

                        // Check if captured word matches a known location
                        for (keywords, kind) in locationKeywords {
                            if keywords.contains(captured) {
                                let raw = String(textForSourceExtraction[Range(match.range, in: textForSourceExtraction)!])
                                addLocation(kind, rawText: raw, confidence: 0.70)
                                break
                            }
                        }
                    }
                }
            }
        }

        return SourceLocationParseResult(clauses: clauses, conditions: conditions)
    }

    private struct DestinationParseResult {
        let clause: NLParsedClause?
        let destination: String?
        let logicalOperatorClause: NLParsedClause?
        let issue: NLParseIssue?
    }

    private func extractDestination(from text: String) -> DestinationParseResult {
        // Pattern supports both relative paths (Documents/Archive) and absolute paths (/Users/test/Documents)
        let pattern = #"(?:to|into)\s+(/?[A-Za-z0-9 _.-]+(?:/[A-Za-z0-9 _.-]+)*)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..<text.endIndex, in: text)),
           let range = Range(match.range(at: 1), in: text) {
            let raw = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            let clause = NLParsedClause(
                kind: .destination,
                rawText: raw,
                normalizedValue: raw,
                confidence: 0.9,
                ambiguityTags: []
            )
            return DestinationParseResult(
                clause: clause,
                destination: raw,
                logicalOperatorClause: nil,
                issue: nil
            )
        }

        // No destination is acceptable for delete rules but we don't know the action here,
        // so we simply emit a warning; the view model can decide whether this is blocking.
        let issue = NLParseIssue(
            severity: .warning,
            message: "No destination was found. Move/Copy rules will need a folder before they can be created.",
            relatedKinds: [.destination]
        )
        return DestinationParseResult(
            clause: nil,
            destination: nil,
            logicalOperatorClause: nil,
            issue: issue
        )
    }

    private func inferLogicalOperator(from lower: String, conditionCount: Int) -> Rule.LogicalOperator {
        if conditionCount <= 1 { return .single }
        var sawAnd = false
        var sawOr = false

        if lower.contains(" and ") || lower.contains(" as well as ") {
            sawAnd = true
        }
        if lower.contains(" or ") {
            sawOr = true
        }

        switch (sawAnd, sawOr) {
        case (true, false):
            return .and
        case (false, true):
            return .or
        case (true, true):
            // Mixed conjunctions – default to .and for safety.
            return .and
        case (false, false):
            // Multiple conditions but no operators mentioned – also default to AND.
            return .and
        }
    }

    private func computeOverallConfidence(clauses: [NLParsedClause], issues: [NLParseIssue]) -> Double {
        guard !clauses.isEmpty else { return 0.0 }
        let base = clauses.map { $0.confidence }.reduce(0.0, +) / Double(clauses.count)

        // Penalize for warnings and errors.
        let warningPenalty = issues.filter { $0.severity == .warning }.isEmpty ? 0.0 : 0.05
        let errorPenalty = issues.filter { $0.severity == .error }.isEmpty ? 0.0 : 0.15

        let score = max(0.0, min(1.0, base - warningPenalty - errorPenalty))
        return score
    }

    private func convertToDays(number: Int, unit: String) -> Int {
        switch unit {
        case "day", "days":
            return number
        case "week", "weeks":
            return number * 7
        case "month", "months":
            return number * 30
        case "year", "years":
            return number * 365
        default:
            return number
        }
    }

    private func range(ofAny tokens: [String], in lower: String) -> Range<String.Index>? {
        for token in tokens {
            if let range = lower.range(of: token) { return range }
        }
        return nil
    }
}
