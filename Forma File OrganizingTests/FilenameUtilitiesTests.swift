import XCTest
@testable import Forma_File_Organizing

/// Tests for FilenameUtilities - handling special characters in filenames
final class FilenameUtilitiesTests: XCTestCase {

    // MARK: - Display Name Tests

    func testDisplayName_ShortFilename_ReturnsUnchanged() {
        let filename = "document.pdf"
        XCTAssertEqual(FilenameUtilities.displayName(filename), filename)
    }

    func testDisplayName_LongFilename_TruncatesWithEllipsis() {
        let filename = "This is a very long filename that should be truncated for display purposes.pdf"
        let result = FilenameUtilities.displayName(filename, maxLength: 40)

        XCTAssertTrue(result.count <= 40, "Should be truncated to maxLength")
        XCTAssertTrue(result.contains("…"), "Should contain ellipsis")
        XCTAssertTrue(result.hasSuffix(".pdf"), "Should preserve extension")
    }

    func testDisplayName_UnicodeFilename_NormalizesCorrectly() {
        // café can be represented as composed (é) or decomposed (e + combining accent)
        let composed = "café.txt"
        let decomposed = "cafe\u{0301}.txt" // e + combining acute accent

        let result1 = FilenameUtilities.displayName(composed)
        let result2 = FilenameUtilities.displayName(decomposed)

        // Both should normalize to the same composed form
        XCTAssertEqual(result1, result2, "Unicode should normalize to same form")
    }

    func testDisplayName_EmojiFilename_DisplaysCorrectly() {
        let filename = "🎉 Party Planning 📋.docx"
        let result = FilenameUtilities.displayName(filename)

        XCTAssertTrue(result.contains("🎉"), "Should preserve emoji")
        XCTAssertTrue(result.contains("📋"), "Should preserve emoji")
    }

    func testDisplayName_ControlCharacters_ReplacesWithPlaceholder() {
        let filename = "file\u{0000}name.txt" // Contains null character
        let result = FilenameUtilities.displayName(filename)

        XCTAssertFalse(result.contains("\u{0000}"), "Should remove null character")
        XCTAssertTrue(result.contains("␀"), "Should contain replacement character")
    }

    func testDisplayName_TabsAndSpecialWhitespace_NormalizesToSpace() {
        let filename = "file\tname.txt" // Contains tab
        let result = FilenameUtilities.displayName(filename)

        XCTAssertFalse(result.contains("\t"), "Should not contain tab")
        XCTAssertTrue(result.contains(" "), "Tab should be replaced with space")
    }

    // MARK: - Truncate Middle Tests

    func testTruncateMiddle_ShortString_ReturnsUnchanged() {
        let input = "short"
        XCTAssertEqual(FilenameUtilities.truncateMiddle(input, maxLength: 10), input)
    }

    func testTruncateMiddle_LongString_TruncatesInMiddle() {
        let input = "This is a long string"
        let result = FilenameUtilities.truncateMiddle(input, maxLength: 10)

        XCTAssertTrue(result.count <= 10, "Should not exceed maxLength")
        XCTAssertTrue(result.contains("…"), "Should contain ellipsis")
        XCTAssertTrue(result.hasPrefix("This"), "Should preserve start")
        XCTAssertTrue(result.hasSuffix("ing"), "Should preserve end")
    }

    // MARK: - Pattern Matching Tests

    func testEscapeForRegex_BracketedFilename_EscapesCorrectly() {
        let pattern = "file[1].txt"
        let escaped = FilenameUtilities.escapeForRegex(pattern)

        XCTAssertEqual(escaped, "file\\[1\\]\\.txt", "Should escape brackets and dot")
    }

    func testEscapeForRegex_ParenthesesFilename_EscapesCorrectly() {
        let pattern = "document (copy).pdf"
        let escaped = FilenameUtilities.escapeForRegex(pattern)

        XCTAssertEqual(escaped, "document \\(copy\\)\\.pdf", "Should escape parentheses")
    }

    func testEscapeForRegex_AsteriskFilename_EscapesCorrectly() {
        let pattern = "important*.txt"
        let escaped = FilenameUtilities.escapeForRegex(pattern)

        XCTAssertEqual(escaped, "important\\*\\.txt", "Should escape asterisk")
    }

    func testEscapeForRegex_DollarAndCaret_EscapesCorrectly() {
        let pattern = "$100^2"
        let escaped = FilenameUtilities.escapeForRegex(pattern)

        XCTAssertEqual(escaped, "\\$100\\^2", "Should escape dollar and caret")
    }

    func testContainsLiteral_BracketedPattern_MatchesLiterally() {
        let filename = "Project [2024] Final.docx"
        let pattern = "[2024]"

        XCTAssertTrue(
            FilenameUtilities.containsLiteral(filename, pattern: pattern),
            "Should match brackets literally"
        )
    }

    func testContainsLiteral_CaseInsensitive_Matches() {
        let filename = "IMPORTANT_DOCUMENT.PDF"
        let pattern = "important"

        XCTAssertTrue(
            FilenameUtilities.containsLiteral(filename, pattern: pattern),
            "Should match case-insensitively"
        )
    }

    func testContainsLiteral_UnicodeNormalization_Matches() {
        let filename = "café report.txt" // composed
        let pattern = "cafe\u{0301}" // decomposed

        XCTAssertTrue(
            FilenameUtilities.containsLiteral(filename, pattern: pattern),
            "Should match with Unicode normalization"
        )
    }

    func testStartsWithLiteral_BracketPrefix_Matches() {
        let filename = "[DRAFT] Report.pdf"
        XCTAssertTrue(FilenameUtilities.startsWithLiteral(filename, prefix: "[draft]"))
    }

    func testEndsWithLiteral_ParenthesisSuffix_Matches() {
        let filename = "Document (final).docx"
        XCTAssertTrue(FilenameUtilities.endsWithLiteral(filename, suffix: "(final).docx"))
    }

    // MARK: - Log Safety Tests

    func testLogSafe_PercentSign_Escapes() {
        let filename = "100% Complete.txt"
        let result = FilenameUtilities.logSafe(filename)

        XCTAssertEqual(result, "100%% Complete.txt", "Should escape percent signs")
    }

    func testLogSafe_Newlines_Escapes() {
        let filename = "file\nname.txt"
        let result = FilenameUtilities.logSafe(filename)

        XCTAssertFalse(result.contains("\n"), "Should not contain actual newline")
        XCTAssertTrue(result.contains("\\n"), "Should contain escaped newline")
    }

    func testLogSafe_VeryLongFilename_Truncates() {
        let filename = String(repeating: "a", count: 200)
        let result = FilenameUtilities.logSafe(filename)

        XCTAssertTrue(result.count <= 100, "Should truncate to maxDetailDisplayLength")
        XCTAssertTrue(result.contains("…"), "Should contain ellipsis")
    }

    // MARK: - Validation Tests

    func testIsValidMacOSFilename_ValidNames_ReturnsTrue() {
        XCTAssertTrue(FilenameUtilities.isValidMacOSFilename("document.pdf"))
        XCTAssertTrue(FilenameUtilities.isValidMacOSFilename("file [1].txt"))
        XCTAssertTrue(FilenameUtilities.isValidMacOSFilename("🎉 Party.docx"))
        XCTAssertTrue(FilenameUtilities.isValidMacOSFilename("日本語ファイル.txt"))
        XCTAssertTrue(FilenameUtilities.isValidMacOSFilename("file with spaces.txt"))
        XCTAssertTrue(FilenameUtilities.isValidMacOSFilename("file-with-dashes.txt"))
        XCTAssertTrue(FilenameUtilities.isValidMacOSFilename("file_with_underscores.txt"))
    }

    func testIsValidMacOSFilename_Colon_ReturnsFalse() {
        XCTAssertFalse(FilenameUtilities.isValidMacOSFilename("file:name.txt"))
    }

    func testIsValidMacOSFilename_ForwardSlash_ReturnsFalse() {
        XCTAssertFalse(FilenameUtilities.isValidMacOSFilename("file/name.txt"))
    }

    func testIsValidMacOSFilename_Empty_ReturnsFalse() {
        XCTAssertFalse(FilenameUtilities.isValidMacOSFilename(""))
    }

    func testSanitizeForMacOS_Colon_ReplacesWithUnderscore() {
        let filename = "Meeting: Notes.txt"
        let result = FilenameUtilities.sanitizeForMacOS(filename)

        XCTAssertEqual(result, "Meeting_ Notes.txt")
    }

    func testSanitizeForMacOS_ForwardSlash_ReplacesWithUnderscore() {
        let filename = "Q1/Q2 Report.pdf"
        let result = FilenameUtilities.sanitizeForMacOS(filename)

        XCTAssertEqual(result, "Q1_Q2 Report.pdf")
    }

    func testSanitizeForMacOS_LeadingDots_Trimmed() {
        let filename = "...hidden.txt"
        let result = FilenameUtilities.sanitizeForMacOS(filename)

        XCTAssertEqual(result, "hidden.txt")
    }

    func testSanitizeForMacOS_OnlyInvalidChars_ReturnsUnnamed() {
        let filename = ":::"
        let result = FilenameUtilities.sanitizeForMacOS(filename)

        XCTAssertEqual(result, "___") // Colons replaced with underscores
    }

    func testSanitizeForMacOS_Empty_ReturnsUnnamed() {
        XCTAssertEqual(FilenameUtilities.sanitizeForMacOS(""), "unnamed")
    }

    // MARK: - Comparison Tests

    func testAreEquivalent_SameString_ReturnsTrue() {
        XCTAssertTrue(FilenameUtilities.areEquivalent("document.pdf", "document.pdf"))
    }

    func testAreEquivalent_UnicodeNormalization_ReturnsTrue() {
        let composed = "café.txt"
        let decomposed = "cafe\u{0301}.txt"

        XCTAssertTrue(
            FilenameUtilities.areEquivalent(composed, decomposed),
            "Unicode equivalent strings should be equivalent"
        )
    }

    func testAreEquivalent_DifferentStrings_ReturnsFalse() {
        XCTAssertFalse(FilenameUtilities.areEquivalent("file1.txt", "file2.txt"))
    }

    func testNormalizedForComparison_Lowercase() {
        let filename = "UPPERCASE.PDF"
        let result = FilenameUtilities.normalizedForComparison(filename)

        XCTAssertEqual(result, "uppercase.pdf")
    }

    func testNormalizedForComparison_UnicodeNormalized() {
        let decomposed = "cafe\u{0301}.txt"
        let result = FilenameUtilities.normalizedForComparison(decomposed)

        // Should be composed form (NFC) and lowercase
        XCTAssertEqual(result, "café.txt")
    }

    // MARK: - Edge Cases

    func testSpecialCharacters_QuotesInFilename() {
        let filename = "\"Important\" Document.pdf"

        XCTAssertTrue(FilenameUtilities.isValidMacOSFilename(filename))
        XCTAssertTrue(FilenameUtilities.containsLiteral(filename, pattern: "\"Important\""))
    }

    func testSpecialCharacters_BackslashInFilename() {
        // Note: Backslash is valid in macOS filenames (unlike Windows)
        let filename = "file\\backup.txt"

        XCTAssertTrue(FilenameUtilities.isValidMacOSFilename(filename))

        let escaped = FilenameUtilities.escapeForRegex("\\backup")
        XCTAssertEqual(escaped, "\\\\backup", "Backslash should be escaped for regex")
    }

    func testSpecialCharacters_PipeInFilename() {
        let filename = "Choice A | Choice B.txt"

        XCTAssertTrue(FilenameUtilities.isValidMacOSFilename(filename))

        let escaped = FilenameUtilities.escapeForRegex("|")
        XCTAssertEqual(escaped, "\\|", "Pipe should be escaped for regex")
    }

    func testSpecialCharacters_QuestionMarkInFilename() {
        let filename = "Why not?.txt"

        XCTAssertTrue(FilenameUtilities.isValidMacOSFilename(filename))

        let escaped = FilenameUtilities.escapeForRegex("?")
        XCTAssertEqual(escaped, "\\?", "Question mark should be escaped for regex")
    }

    func testSpecialCharacters_PlusInFilename() {
        let filename = "C++ Tutorial.pdf"

        XCTAssertTrue(FilenameUtilities.isValidMacOSFilename(filename))
        XCTAssertTrue(FilenameUtilities.containsLiteral(filename, pattern: "C++"))

        let escaped = FilenameUtilities.escapeForRegex("C++")
        XCTAssertEqual(escaped, "C\\+\\+", "Plus should be escaped for regex")
    }

    func testSpecialCharacters_BracesInFilename() {
        let filename = "config{dev}.json"

        XCTAssertTrue(FilenameUtilities.isValidMacOSFilename(filename))

        let escaped = FilenameUtilities.escapeForRegex("{dev}")
        XCTAssertEqual(escaped, "\\{dev\\}", "Braces should be escaped for regex")
    }
}
