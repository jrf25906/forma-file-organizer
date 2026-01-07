import XCTest
@testable import Forma_File_Organizing

/// Regression tests for NaturalLanguageRuleParser edge cases.
///
/// Tests cover:
/// - Ambiguous time phrases ("last week", "last month")
/// - Grouping ambiguities ("by month")
/// - Invalid syntax (no action, conflicting actions)
/// - Missing required components (destination/action)
/// - Unsafe paths and validation
/// - Error messages and blocking behavior
///
/// Note: Parser is created locally in each test to avoid memory management
/// issues with Swift Task-local storage during deallocation.
final class NaturalLanguageRuleParserEdgeCaseTests: XCTestCase {

    // MARK: - Ambiguous Time Phrase Tests
    
    /// Test: "last week" is flagged as ambiguous
    func testAmbiguousTimePhrase_LastWeek() throws {
        let parser = NaturalLanguageRuleParser()
        let result = parser.parse("Move PDFs from last week to Archive")
        
        XCTAssertTrue(result.isAmbiguous, "Parse should be marked as ambiguous")
        
        // Verify ambiguity tag is present
        let timeClause = result.clauses.first { $0.kind == .timeConstraint }
        XCTAssertNotNil(timeClause, "Time constraint clause should exist")
        XCTAssertTrue(
            timeClause?.ambiguityTags.contains(.ambiguousTimePhrase) ?? false,
            "Time phrase should be flagged as ambiguous"
        )
        
        // Verify warning issue is raised
        let warnings = result.issues.filter { $0.severity == .warning }
        XCTAssertFalse(warnings.isEmpty, "Should have at least one warning")
        XCTAssertTrue(
            warnings.contains { $0.message.contains("Last week") },
            "Warning should explain the ambiguity"
        )
    }
    
    /// Test: "last month" is flagged as ambiguous
    func testAmbiguousTimePhrase_LastMonth() throws {
        let parser = NaturalLanguageRuleParser()
        let result = parser.parse("Delete images from last month")
        
        XCTAssertTrue(result.isAmbiguous, "Parse should be marked as ambiguous")
        
        let timeClause = result.clauses.first { $0.kind == .timeConstraint }
        XCTAssertNotNil(timeClause, "Time constraint should be parsed")
        XCTAssertTrue(
            timeClause?.ambiguityTags.contains(.ambiguousTimePhrase) ?? false,
            "Should flag ambiguous time phrase"
        )
        
        // Verify interpreted as 30 days
        XCTAssertTrue(
            timeClause?.normalizedValue.contains("30") ?? false,
            "Last month should default to 30 days"
        )
    }
    
    /// Test: Explicit "older than X days" is NOT ambiguous
    func testUnambiguousTimePhrase_ExplicitDays() throws {
        let parser = NaturalLanguageRuleParser()
        let result = parser.parse("Move PDFs older than 14 days to Archive")
        
        XCTAssertFalse(result.isAmbiguous, "Explicit time phrases should not be ambiguous")
        
        let timeClause = result.clauses.first { $0.kind == .timeConstraint }
        XCTAssertNotNil(timeClause, "Time constraint should be parsed")
        XCTAssertTrue(
            timeClause?.ambiguityTags.isEmpty ?? false,
            "Explicit day count should not have ambiguity tags"
        )
    }
    
    // MARK: - Grouping Ambiguity Tests
    
    /// Test: "by month" triggers grouping ambiguity
    func testGroupingAmbiguity_ByMonth() throws {
        let parser = NaturalLanguageRuleParser()
        let result = parser.parse("Organize photos by month to Pictures/Archive")
        
        XCTAssertTrue(result.isAmbiguous, "Grouping hint should trigger ambiguity")
        
        // Verify grouping hint is detected
        XCTAssertNotNil(result.groupingHint, "Grouping hint should be parsed")
        XCTAssertEqual(result.groupingHint, .byMonth, "Should detect 'by month' hint")
        
        // Verify ambiguity tag
        let groupingClause = result.clauses.first { $0.ambiguityTags.contains(.ambiguousGrouping) }
        XCTAssertNotNil(groupingClause, "Grouping clause should have ambiguity tag")
        
        // Verify warning issue
        let warnings = result.issues.filter { $0.severity == .warning }
        XCTAssertTrue(
            warnings.contains { $0.message.contains("By month") || $0.message.contains("creation month") },
            "Warning should explain grouping ambiguity"
        )
    }
    
    /// Test: Grouping resolution is initially nil
    func testGroupingResolution_InitiallyNil() throws {
        let parser = NaturalLanguageRuleParser()
        let result = parser.parse("Organize files by month to Documents")
        
        XCTAssertNotNil(result.groupingHint, "Should detect grouping hint")
        XCTAssertNil(result.groupingResolution, "Resolution should be nil before user clarifies")
    }
    
    // MARK: - Invalid Syntax Tests
    
    /// Test: No action keyword results in error
    func testInvalidSyntax_NoAction() throws {
        let parser = NaturalLanguageRuleParser()
        let result = parser.parse("PDFs to Archive")
        
        XCTAssertTrue(result.hasBlockingError, "Should have blocking error")
        XCTAssertNil(result.primaryAction, "No action should be parsed")
        
        let errors = result.issues.filter { $0.severity == .error }
        XCTAssertFalse(errors.isEmpty, "Should have at least one error")
        XCTAssertTrue(
            errors.contains { $0.message.contains("action") || $0.message.contains("move") },
            "Error should mention missing action"
        )
    }
    
    /// Test: Conflicting actions (move + delete) are flagged
    func testInvalidSyntax_ConflictingActions() throws {
        let parser = NaturalLanguageRuleParser()
        let result = parser.parse("Move and delete PDFs to Archive")
        
        // Conflicting actions should produce ambiguity or warning
        let actionClause = result.clauses.first { $0.kind == .action }
        XCTAssertNotNil(actionClause, "Action should be parsed")
        
        // Check for conflict tag
        XCTAssertTrue(
            actionClause?.ambiguityTags.contains(.conflictingConditions) ?? false,
            "Conflicting actions should be flagged"
        )
    }
    
    /// Test: Empty input returns safe empty result
    func testInvalidSyntax_EmptyInput() throws {
        let parser = NaturalLanguageRuleParser()
        let result = parser.parse("")
        
        XCTAssertEqual(result.originalText, "", "Should preserve original text")
        XCTAssertTrue(result.clauses.isEmpty, "No clauses should be parsed")
        XCTAssertNil(result.primaryAction, "No action for empty input")
        XCTAssertEqual(result.overallConfidence, 0.0, "Confidence should be 0")
    }
    
    /// Test: Whitespace-only input returns safe empty result
    func testInvalidSyntax_WhitespaceOnly() throws {
        let parser = NaturalLanguageRuleParser()
        let result = parser.parse("   \n\t  ")
        
        XCTAssertTrue(result.clauses.isEmpty, "Whitespace-only should be treated as empty")
        XCTAssertEqual(result.overallConfidence, 0.0, "Confidence should be 0")
    }
    
    // MARK: - Missing Component Tests
    
    /// Test: Move action without destination raises warning
    func testMissingComponent_NoDestination() throws {
        let parser = NaturalLanguageRuleParser()
        let result = parser.parse("Move PDFs older than 30 days")
        
        XCTAssertFalse(result.isComplete, "Rule should be incomplete without destination")
        XCTAssertNil(result.destinationPath, "No destination should be parsed")
        
        let warnings = result.issues.filter { $0.severity == .warning }
        XCTAssertTrue(
            warnings.contains { $0.message.contains("destination") || $0.message.contains("folder") },
            "Warning should mention missing destination"
        )
    }
    
    /// Test: Delete action without destination is valid
    func testMissingDestination_ValidForDelete() throws {
        let parser = NaturalLanguageRuleParser()
        let result = parser.parse("Delete screenshots older than 90 days")
        
        XCTAssertEqual(result.primaryAction, .delete, "Delete action should be parsed")
        XCTAssertTrue(result.isComplete, "Delete rules don't require destinations")
        XCTAssertNil(result.destinationPath, "Delete should have no destination")
    }
    
    /// Test: Action present but no file targets
    func testMissingComponent_NoFileTargets() throws {
        let parser = NaturalLanguageRuleParser()
        let result = parser.parse("Move to Archive")
        
        // This should parse but have very low confidence since no files are specified
        XCTAssertTrue(result.candidateConditions.isEmpty, "No conditions should be parsed")
        XCTAssertFalse(result.isComplete, "Rule should be incomplete without file conditions")
    }
    
    // MARK: - Unsafe Path Tests
    
    /// Test: Relative paths are accepted (validation happens later)
    func testUnsafePath_RelativePath() throws {
        let parser = NaturalLanguageRuleParser()
        let result = parser.parse("Move PDFs to Archive")
        
        XCTAssertEqual(result.destinationPath, "Archive", "Relative path should be parsed")
        // Note: actual path validation happens in Rule.isValidDestinationPath
    }
    
    /// Test: Absolute paths are parsed
    func testPath_AbsolutePath() throws {
        let parser = NaturalLanguageRuleParser()
        let result = parser.parse("Move images to /Users/test/Documents")
        
        XCTAssertEqual(result.destinationPath, "/Users/test/Documents", "Absolute path should be parsed")
    }
    
    /// Test: Path with spaces and special characters
    func testPath_WithSpacesAndSpecialChars() throws {
        let parser = NaturalLanguageRuleParser()
        let result = parser.parse("Move files to Documents/My Projects 2024")
        
        XCTAssertNotNil(result.destinationPath, "Path with spaces should be parsed")
        XCTAssertTrue(
            result.destinationPath?.contains("My Projects") ?? false,
            "Spaces should be preserved"
        )
    }
    
    // MARK: - Error Message Tests
    
    /// Test: Error messages are descriptive and actionable
    func testErrorMessages_Descriptive() throws {
        let parser = NaturalLanguageRuleParser()
        let noActionResult = parser.parse("PDFs to Archive")
        
        let errors = noActionResult.issues.filter { $0.severity == .error }
        XCTAssertFalse(errors.isEmpty, "Should have errors")
        
        let errorMessage = errors.first?.message ?? ""
        XCTAssertFalse(errorMessage.isEmpty, "Error message should not be empty")
        XCTAssertTrue(
            errorMessage.lowercased().contains("move") ||
            errorMessage.lowercased().contains("copy") ||
            errorMessage.lowercased().contains("delete"),
            "Error should suggest valid actions"
        )
    }
    
    /// Test: Warnings include explanations for ambiguous phrases
    func testErrorMessages_ExplainAmbiguity() throws {
        let parser = NaturalLanguageRuleParser()
        let result = parser.parse("Move images from last week to Pictures")
        
        let warnings = result.issues.filter { $0.severity == .warning }
        XCTAssertFalse(warnings.isEmpty, "Should have warnings for ambiguous time")
        
        let warningMessage = warnings.first?.message ?? ""
        XCTAssertTrue(
            warningMessage.contains("7 days") || warningMessage.contains("interpreted"),
            "Warning should explain how the ambiguity was resolved"
        )
    }
    
    // MARK: - Blocking Behavior Tests
    
    /// Test: Rules with errors cannot be converted to Rule
    func testBlockingBehavior_ErrorsPreventConversion() throws {
        let parser = NaturalLanguageRuleParser()
        let result = parser.parse("PDFs to Archive") // No action
        
        XCTAssertTrue(result.hasBlockingError, "Should have blocking error")
        XCTAssertNil(result.toRule(), "Should not convert to Rule with errors")
    }
    
    /// Test: Incomplete rules cannot be converted
    func testBlockingBehavior_IncompleteRulePreventsConversion() throws {
        let parser = NaturalLanguageRuleParser()
        let result = parser.parse("Move PDFs") // No destination
        
        XCTAssertFalse(result.isComplete, "Rule should be incomplete")
        XCTAssertNil(result.toRule(), "Incomplete rule should not convert")
    }
    
    /// Test: Ambiguous rules CAN be converted (user may accept default interpretation)
    func testBlockingBehavior_AmbiguousRulesCanConvert() throws {
        let parser = NaturalLanguageRuleParser()
        let result = parser.parse("Move PDFs from last week to Archive")
        
        XCTAssertTrue(result.isAmbiguous, "Should be ambiguous")
        XCTAssertFalse(result.hasBlockingError, "Ambiguity is warning, not error")
        XCTAssertTrue(result.isComplete, "Should be complete despite ambiguity")
        
        let rule = result.toRule()
        XCTAssertNotNil(rule, "Ambiguous but complete rules should convert")
    }
    
    // MARK: - Confidence Scoring Tests
    
    /// Test: Well-formed rules have high confidence
    func testConfidence_WellFormedHigh() throws {
        let parser = NaturalLanguageRuleParser()
        let result = parser.parse("Move PDFs older than 30 days to Archive")
        
        XCTAssertGreaterThan(result.overallConfidence, 0.7, "Well-formed rule should have high confidence")
    }
    
    /// Test: Ambiguous phrases reduce confidence
    func testConfidence_AmbiguityReduces() throws {
        let parser = NaturalLanguageRuleParser()
        let clearResult = parser.parse("Move PDFs older than 30 days to Archive")
        let ambiguousResult = parser.parse("Move PDFs from last week to Archive")
        
        XCTAssertLessThan(
            ambiguousResult.overallConfidence,
            clearResult.overallConfidence,
            "Ambiguous time phrases should reduce confidence"
        )
    }
    
    /// Test: Missing components reduce confidence
    func testConfidence_MissingComponentsReduce() throws {
        let parser = NaturalLanguageRuleParser()
        let completeResult = parser.parse("Move PDFs to Archive")
        let incompleteResult = parser.parse("Move to Archive")
        
        XCTAssertLessThan(
            incompleteResult.overallConfidence,
            completeResult.overallConfidence,
            "Missing file targets should reduce confidence"
        )
    }
    
    /// Test: Errors significantly reduce confidence
    func testConfidence_ErrorsReduce() throws {
        let parser = NaturalLanguageRuleParser()
        let validResult = parser.parse("Move PDFs to Archive")
        let errorResult = parser.parse("PDFs to Archive") // No action
        
        XCTAssertLessThan(
            errorResult.overallConfidence,
            validResult.overallConfidence,
            "Errors should significantly reduce confidence"
        )
    }
    
    // MARK: - Complex Syntax Tests
    
    /// Test: Multiple conditions with AND operator
    func testComplexSyntax_MultipleConditionsAnd() throws {
        let parser = NaturalLanguageRuleParser()
        let result = parser.parse("Move PDFs and images older than 30 days to Archive")
        
        XCTAssertGreaterThan(result.candidateConditions.count, 0, "Should parse multiple conditions")
        XCTAssertEqual(result.logicalOperator, .and, "Should default to AND for implicit conjunction")
    }
    
    /// Test: Explicit OR operator
    func testComplexSyntax_ExplicitOr() throws {
        let parser = NaturalLanguageRuleParser()
        let result = parser.parse("Move PDFs or images to Documents")
        
        XCTAssertEqual(result.logicalOperator, .or, "Should detect explicit OR")
    }
    
    /// Test: Quoted strings in name patterns
    func testComplexSyntax_QuotedPatterns() throws {
        let parser = NaturalLanguageRuleParser()
        let result = parser.parse("Move files containing \"invoice\" to Documents/Finance")
        
        let nameCondition = result.candidateConditions.first { condition in
            if case .nameContains = condition { return true }
            return false
        }
        XCTAssertNotNil(nameCondition, "Should parse quoted name pattern")
    }
    
    /// Test: "starting with" pattern
    func testComplexSyntax_StartingWith() throws {
        let parser = NaturalLanguageRuleParser()
        let result = parser.parse("Move files starting with ClientA to Documents/ClientA")
        
        let nameCondition = result.candidateConditions.first { condition in
            if case .nameStartsWith = condition { return true }
            return false
        }
        XCTAssertNotNil(nameCondition, "Should parse 'starting with' pattern")
    }
    
    /// Test: "ending with" pattern
    func testComplexSyntax_EndingWith() throws {
        let parser = NaturalLanguageRuleParser()
        let result = parser.parse("Move files ending with backup to Archive")
        
        let nameCondition = result.candidateConditions.first { condition in
            if case .nameEndsWith = condition { return true }
            return false
        }
        XCTAssertNotNil(nameCondition, "Should parse 'ending with' pattern")
    }
    
    // MARK: - Rule Conversion Tests
    
    /// Test: toRule() generates appropriate default name
    func testRuleConversion_DefaultName() throws {
        let parser = NaturalLanguageRuleParser()
        let result = parser.parse("Move PDFs to Archive")
        
        let rule = result.toRule()
        XCTAssertNotNil(rule, "Should convert to rule")
        XCTAssertFalse(rule?.name.isEmpty ?? true, "Rule should have a name")
        XCTAssertTrue(
            rule?.name.contains("PDFs") ?? false,
            "Name should derive from original text"
        )
    }
    
    /// Test: toRule() respects explicit name parameter
    func testRuleConversion_ExplicitName() throws {
        let parser = NaturalLanguageRuleParser()
        let result = parser.parse("Move PDFs to Archive")
        
        let rule = result.toRule(name: "My PDF Rule", isEnabled: true)
        XCTAssertEqual(rule?.name, "My PDF Rule", "Should use explicit name")
        XCTAssertTrue(rule?.isEnabled ?? false, "Should respect isEnabled flag")
    }
    
    /// Test: toRule() truncates long names
    func testRuleConversion_LongNameTruncated() throws {
        let parser = NaturalLanguageRuleParser()
        let longInput = "Move all PDF documents that are older than 30 days and contain the word invoice or receipt to the Documents folder"
        let result = parser.parse(longInput)
        
        let rule = result.toRule()
        XCTAssertNotNil(rule, "Should convert despite long text")
        XCTAssertLessThanOrEqual(rule?.name.count ?? 0, 45, "Name should be truncated with ellipsis")
    }
    
    /// Test: Delete rules don't require destinations
    func testRuleConversion_DeleteNoDestination() throws {
        let parser = NaturalLanguageRuleParser()
        let result = parser.parse("Delete screenshots older than 90 days")
        
        let rule = result.toRule()
        XCTAssertNotNil(rule, "Delete rule should convert")
        XCTAssertEqual(rule?.actionType, .delete, "Should be delete action")
        XCTAssertNil(rule?.destination, "Delete rule should have nil destination")
    }
    
    // MARK: - Regression Tests for Known Issues
    
    /// Test: Multiple file types are parsed correctly
    func testRegression_MultipleFileTypes() throws {
        let parser = NaturalLanguageRuleParser()
        let result = parser.parse("Move pdf and docx files to Documents")
        
        let extensions = result.candidateConditions.compactMap { condition -> String? in
            if case .fileExtension(let ext) = condition { return ext }
            return nil
        }
        
        XCTAssertTrue(extensions.contains("pdf"), "Should parse pdf extension")
        XCTAssertTrue(extensions.contains("docx") || extensions.contains("doc"), "Should parse docx extension")
    }
    
    /// Test: Screenshots are recognized as a special keyword
    func testRegression_ScreenshotKeyword() throws {
        let parser = NaturalLanguageRuleParser()
        let result = parser.parse("Move screenshots to Pictures/Screenshots")
        
        let hasScreenshotCondition = result.candidateConditions.contains { condition in
            if case .nameContains(let value) = condition {
                return value.lowercased().contains("screenshot")
            }
            return false
        }
        
        XCTAssertTrue(hasScreenshotCondition, "Should recognize 'screenshot' as name pattern")
    }
    
    /// Test: Time units are converted correctly
    func testRegression_TimeUnitConversion() throws {
        let parser = NaturalLanguageRuleParser()
        let weekResult = parser.parse("Move PDFs older than 2 weeks to Archive")
        let monthResult = parser.parse("Move PDFs older than 3 months to Archive")
        let yearResult = parser.parse("Move PDFs older than 1 year to Archive")
        
        // Verify conversions by checking normalized values
        let weekClause = weekResult.clauses.first { $0.kind == .timeConstraint }
        XCTAssertTrue(weekClause?.normalizedValue.contains("14") ?? false, "2 weeks = 14 days")
        
        let monthClause = monthResult.clauses.first { $0.kind == .timeConstraint }
        XCTAssertTrue(monthClause?.normalizedValue.contains("90") ?? false, "3 months = 90 days")
        
        let yearClause = yearResult.clauses.first { $0.kind == .timeConstraint }
        XCTAssertTrue(yearClause?.normalizedValue.contains("365") ?? false, "1 year = 365 days")
    }
}
