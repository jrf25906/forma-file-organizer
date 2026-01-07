import XCTest
@testable import Forma_File_Organizing

final class NaturalLanguageRuleParserTests: XCTestCase {

    func testMovePdfOlderThan30DaysToArchive() {
        let parser = NaturalLanguageRuleParser()
        let text = "Move pdf files older than 30 days to Archive"

        let parsed = parser.parse(text)

        XCTAssertEqual(parsed.primaryAction, .move)
        XCTAssertEqual(parsed.destinationPath, "Archive")
        XCTAssertTrue(parsed.isComplete)

        // Should contain a file extension condition for pdf
        let hasPdfExtension = parsed.candidateConditions.contains { condition in
            if case .fileExtension(let ext) = condition {
                return ext.lowercased() == "pdf"
            }
            return false
        }
        XCTAssertTrue(hasPdfExtension, "Expected a fileExtension(pdf) condition")

        // Should contain a dateOlderThan >= 30 days condition
        let hasDateConstraint = parsed.candidateConditions.contains { condition in
            if case .dateOlderThan(let days, _) = condition {
                return days == 30
            }
            return false
        }
        XCTAssertTrue(hasDateConstraint, "Expected a dateOlderThan(30) condition")
    }

    func testDeleteScreenshotsFromLastWeek() {
        let parser = NaturalLanguageRuleParser()
        let text = "Delete screenshots from last week"

        let parsed = parser.parse(text)

        XCTAssertEqual(parsed.primaryAction, .delete)
        XCTAssertNil(parsed.destinationPath, "Delete rules should not require a destination")
        XCTAssertTrue(parsed.isComplete)

        let hasScreenshotName = parsed.candidateConditions.contains { condition in
            if case .nameContains(let text) = condition {
                return text.lowercased().contains("screenshot")
            }
            return false
        }
        XCTAssertTrue(hasScreenshotName, "Expected a nameContains('screenshot') condition")

        let hasSevenDayConstraint = parsed.candidateConditions.contains { condition in
            if case .dateOlderThan(let days, _) = condition {
                return days == 7
            }
            return false
        }
        XCTAssertTrue(hasSevenDayConstraint, "Expected last week to map to olderThan(7) days")
    }

    func testVagueInstructionIsIncomplete() {
        let parser = NaturalLanguageRuleParser()
        let text = "Organize stuff"

        let parsed = parser.parse(text)

        // We may find an action, but we should not consider this a complete rule
        XCTAssertFalse(parsed.isComplete)
        XCTAssertTrue(parsed.candidateConditions.isEmpty)
    }

    func testMoveImagesLargerThanSize() {
        let parser = NaturalLanguageRuleParser()
        let text = "Move images larger than 500MB to Archives"

        let parsed = parser.parse(text)

        XCTAssertEqual(parsed.primaryAction, .move)
        XCTAssertEqual(parsed.destinationPath, "Archives")

        let hasImageKind = parsed.candidateConditions.contains { condition in
            if case .fileKind(let kind) = condition {
                return kind.lowercased() == "image"
            }
            return false
        }
        XCTAssertTrue(hasImageKind)

        let hasSizeConstraint = parsed.candidateConditions.contains { condition in
            if case .sizeLargerThan(let bytes) = condition {
                return bytes > 0
            }
            return false
        }
        XCTAssertTrue(hasSizeConstraint)
    }

    func testOrganizeWorkDocumentsByMonthFlagsGroupingAmbiguity() {
        let parser = NaturalLanguageRuleParser()
        let text = "Organize work documents by month"

        let parsed = parser.parse(text)

        // We currently interpret "organize" as a move-style action.
        XCTAssertEqual(parsed.primaryAction, .move)

        // Should infer at least one condition (work/documents heuristics)
        XCTAssertFalse(parsed.candidateConditions.isEmpty)

        // No destination yet, so rule should not be complete.
        XCTAssertFalse(parsed.isComplete)

        // Grouping hint should be present and ambiguous.
        XCTAssertEqual(parsed.groupingHint, .byMonth)

        let hasGroupingAmbiguity = parsed.clauses.contains { clause in
            clause.ambiguityTags.contains(.ambiguousGrouping)
        }
        XCTAssertTrue(hasGroupingAmbiguity)
        XCTAssertTrue(parsed.isAmbiguous)
    }

    // MARK: - Bug Fix Tests (Extension Detection & Destination Path Exclusion)

    func testDotPrefixedExtensionMdFiles() {
        let parser = NaturalLanguageRuleParser()
        let text = "move .md files older than one month to Documents/Archive"

        let parsed = parser.parse(text)

        XCTAssertEqual(parsed.primaryAction, .move)
        XCTAssertEqual(parsed.destinationPath, "Documents/Archive")
        XCTAssertTrue(parsed.isComplete)

        // Should contain a file extension condition for md
        let hasMdExtension = parsed.candidateConditions.contains { condition in
            if case .fileExtension(let ext) = condition {
                return ext.lowercased() == "md"
            }
            return false
        }
        XCTAssertTrue(hasMdExtension, "Expected a fileExtension(md) condition for '.md files'")

        // Should contain a dateOlderThan condition (one month ≈ 30 days)
        let hasDateConstraint = parsed.candidateConditions.contains { condition in
            if case .dateOlderThan(let days, _) = condition {
                return days >= 28 && days <= 31 // approximately one month
            }
            return false
        }
        XCTAssertTrue(hasDateConstraint, "Expected a dateOlderThan condition for 'older than one month'")
    }

    func testDestinationPathWordsNotParsedAsFileKinds() {
        let parser = NaturalLanguageRuleParser()
        let text = "move .md files to Documents/Archive"

        let parsed = parser.parse(text)

        // Should NOT contain fileKind("document") - "Documents" is in the destination path
        let hasDocumentKind = parsed.candidateConditions.contains { condition in
            if case .fileKind(let kind) = condition {
                return kind.lowercased() == "document"
            }
            return false
        }
        XCTAssertFalse(hasDocumentKind, "Should NOT create fileKind(document) from destination path 'Documents'")

        // Should NOT contain fileKind("archive") - "Archive" is in the destination path
        let hasArchiveKind = parsed.candidateConditions.contains { condition in
            if case .fileKind(let kind) = condition {
                return kind.lowercased() == "archive"
            }
            return false
        }
        XCTAssertFalse(hasArchiveKind, "Should NOT create fileKind(archive) from destination path 'Archive'")

        // Should ONLY have the .md extension condition
        let hasMdExtension = parsed.candidateConditions.contains { condition in
            if case .fileExtension(let ext) = condition {
                return ext.lowercased() == "md"
            }
            return false
        }
        XCTAssertTrue(hasMdExtension, "Expected a fileExtension(md) condition")
    }

    func testSemanticKindWorksWhenNotInDestination() {
        let parser = NaturalLanguageRuleParser()
        // Here "documents" appears BEFORE the destination, so it SHOULD trigger fileKind
        let text = "move old documents to Backup"

        let parsed = parser.parse(text)

        XCTAssertEqual(parsed.primaryAction, .move)
        XCTAssertEqual(parsed.destinationPath, "Backup")

        // "documents" is in the query part, not the destination, so fileKind should be present
        let hasDocumentKind = parsed.candidateConditions.contains { condition in
            if case .fileKind(let kind) = condition {
                return kind.lowercased() == "document"
            }
            return false
        }
        XCTAssertTrue(hasDocumentKind, "Expected fileKind(document) when 'documents' appears before destination")
    }

    func testExplicitExtensionWithoutDotPrefix() {
        let parser = NaturalLanguageRuleParser()
        let text = "move markdown files to Notes"

        let parsed = parser.parse(text)

        XCTAssertEqual(parsed.primaryAction, .move)
        XCTAssertEqual(parsed.destinationPath, "Notes")

        // Should contain a file extension condition for md (markdown → md)
        let hasMdExtension = parsed.candidateConditions.contains { condition in
            if case .fileExtension(let ext) = condition {
                return ext.lowercased() == "md"
            }
            return false
        }
        XCTAssertTrue(hasMdExtension, "Expected fileExtension(md) for 'markdown files'")
    }

    // MARK: - Name Pattern Tests (Quote Variations)

    func testSingleQuotedNamePattern() {
        let parser = NaturalLanguageRuleParser()
        let text = "Move .md files with 'RepoPrompt' in the name to Documents"

        let parsed = parser.parse(text)

        XCTAssertEqual(parsed.primaryAction, .move)
        XCTAssertEqual(parsed.destinationPath, "Documents")

        // Should contain nameContains for "RepoPrompt" (preserving case)
        let hasRepoPrompt = parsed.candidateConditions.contains { condition in
            if case .nameContains(let value) = condition {
                return value == "RepoPrompt"
            }
            return false
        }
        XCTAssertTrue(hasRepoPrompt, "Expected nameContains('RepoPrompt') for single-quoted pattern")

        // Should also have the .md extension
        let hasMdExtension = parsed.candidateConditions.contains { condition in
            if case .fileExtension(let ext) = condition {
                return ext.lowercased() == "md"
            }
            return false
        }
        XCTAssertTrue(hasMdExtension, "Expected fileExtension(md)")
    }

    func testDoubleQuotedNamePattern() {
        let parser = NaturalLanguageRuleParser()
        let text = "Move files with \"invoice\" in the name to Finance"

        let parsed = parser.parse(text)

        let hasInvoice = parsed.candidateConditions.contains { condition in
            if case .nameContains(let value) = condition {
                return value.lowercased() == "invoice"
            }
            return false
        }
        XCTAssertTrue(hasInvoice, "Expected nameContains('invoice') for double-quoted pattern")
    }

    func testBacktickQuotedNamePattern() {
        let parser = NaturalLanguageRuleParser()
        let text = "Move files with `config` in the name to Settings"

        let parsed = parser.parse(text)

        let hasConfig = parsed.candidateConditions.contains { condition in
            if case .nameContains(let value) = condition {
                return value.lowercased() == "config"
            }
            return false
        }
        XCTAssertTrue(hasConfig, "Expected nameContains('config') for backtick-quoted pattern")
    }

    // MARK: - Name Pattern Tests (Named/Called Patterns)

    func testFilesNamedPattern() {
        let parser = NaturalLanguageRuleParser()
        let text = "Move files named backup to Archive"

        let parsed = parser.parse(text)

        XCTAssertEqual(parsed.primaryAction, .move)
        XCTAssertEqual(parsed.destinationPath, "Archive")

        let hasBackup = parsed.candidateConditions.contains { condition in
            if case .nameContains(let value) = condition {
                return value.lowercased() == "backup"
            }
            return false
        }
        XCTAssertTrue(hasBackup, "Expected nameContains('backup') for 'files named backup'")
    }

    func testFilesCalledPattern() {
        let parser = NaturalLanguageRuleParser()
        let text = "Delete files called temp"

        let parsed = parser.parse(text)

        XCTAssertEqual(parsed.primaryAction, .delete)

        let hasTemp = parsed.candidateConditions.contains { condition in
            if case .nameContains(let value) = condition {
                return value.lowercased() == "temp"
            }
            return false
        }
        XCTAssertTrue(hasTemp, "Expected nameContains('temp') for 'files called temp'")
    }

    // MARK: - Name Pattern Tests (Containing Variations)

    func testContainingPattern() {
        let parser = NaturalLanguageRuleParser()
        let text = "Move files containing invoice to Finance"

        let parsed = parser.parse(text)

        let hasInvoice = parsed.candidateConditions.contains { condition in
            if case .nameContains(let value) = condition {
                return value.lowercased() == "invoice"
            }
            return false
        }
        XCTAssertTrue(hasInvoice, "Expected nameContains('invoice') for 'containing invoice'")
    }

    func testThatContainPattern() {
        let parser = NaturalLanguageRuleParser()
        let text = "Move pdf files that contain Q1 to Reports"

        let parsed = parser.parse(text)

        let hasQ1 = parsed.candidateConditions.contains { condition in
            if case .nameContains(let value) = condition {
                return value.uppercased() == "Q1"
            }
            return false
        }
        XCTAssertTrue(hasQ1, "Expected nameContains('Q1') for 'that contain Q1'")
    }

    // MARK: - Name Pattern Tests (Prefix/Suffix Patterns)

    func testStartingWithPattern() {
        let parser = NaturalLanguageRuleParser()
        let text = "Move files starting with project to Projects"

        let parsed = parser.parse(text)

        let hasPrefix = parsed.candidateConditions.contains { condition in
            if case .nameStartsWith(let value) = condition {
                return value.lowercased() == "project"
            }
            return false
        }
        XCTAssertTrue(hasPrefix, "Expected nameStartsWith('project')")
    }

    func testBeginningWithQuotedPattern() {
        let parser = NaturalLanguageRuleParser()
        let text = "Move files beginning with 'Draft-' to Drafts"

        let parsed = parser.parse(text)

        let hasPrefix = parsed.candidateConditions.contains { condition in
            if case .nameStartsWith(let value) = condition {
                return value == "Draft-"
            }
            return false
        }
        XCTAssertTrue(hasPrefix, "Expected nameStartsWith('Draft-')")
    }

    func testEndingWithPattern() {
        let parser = NaturalLanguageRuleParser()
        let text = "Move files ending with -backup to Backups"

        let parsed = parser.parse(text)

        let hasSuffix = parsed.candidateConditions.contains { condition in
            if case .nameEndsWith(let value) = condition {
                return value.lowercased() == "-backup"
            }
            return false
        }
        XCTAssertTrue(hasSuffix, "Expected nameEndsWith('-backup')")
    }

    func testEndingInPattern() {
        let parser = NaturalLanguageRuleParser()
        let text = "Delete files ending in _old"

        let parsed = parser.parse(text)

        let hasSuffix = parsed.candidateConditions.contains { condition in
            if case .nameEndsWith(let value) = condition {
                return value == "_old"
            }
            return false
        }
        XCTAssertTrue(hasSuffix, "Expected nameEndsWith('_old') for 'ending in'")
    }

    // MARK: - Name Pattern Tests (Wildcard/Glob Patterns)

    func testPrefixWildcard() {
        let parser = NaturalLanguageRuleParser()
        let text = "Move project-* files to Projects"

        let parsed = parser.parse(text)

        let hasPrefix = parsed.candidateConditions.contains { condition in
            if case .nameStartsWith(let value) = condition {
                return value == "project-"
            }
            return false
        }
        XCTAssertTrue(hasPrefix, "Expected nameStartsWith('project-') for 'project-*'")
    }

    func testSuffixWildcard() {
        let parser = NaturalLanguageRuleParser()
        let text = "Move *-backup files to Backups"

        let parsed = parser.parse(text)

        let hasSuffix = parsed.candidateConditions.contains { condition in
            if case .nameEndsWith(let value) = condition {
                return value == "-backup"
            }
            return false
        }
        XCTAssertTrue(hasSuffix, "Expected nameEndsWith('-backup') for '*-backup'")
    }

    func testContainsWildcard() {
        let parser = NaturalLanguageRuleParser()
        let text = "Delete *temp* files"

        let parsed = parser.parse(text)

        let hasContains = parsed.candidateConditions.contains { condition in
            if case .nameContains(let value) = condition {
                return value.lowercased() == "temp"
            }
            return false
        }
        XCTAssertTrue(hasContains, "Expected nameContains('temp') for '*temp*'")
    }

    // MARK: - Name Pattern Tests (Combined Patterns)

    func testCombinedExtensionAndNamePattern() {
        let parser = NaturalLanguageRuleParser()
        let text = "Move pdf files with 'Q1' in the name older than 30 days to Archive"

        let parsed = parser.parse(text)

        XCTAssertEqual(parsed.primaryAction, .move)
        XCTAssertEqual(parsed.destinationPath, "Archive")

        // Should have extension condition
        let hasPdf = parsed.candidateConditions.contains { condition in
            if case .fileExtension(let ext) = condition {
                return ext.lowercased() == "pdf"
            }
            return false
        }
        XCTAssertTrue(hasPdf, "Expected fileExtension(pdf)")

        // Should have name pattern condition
        let hasQ1 = parsed.candidateConditions.contains { condition in
            if case .nameContains(let value) = condition {
                return value == "Q1"
            }
            return false
        }
        XCTAssertTrue(hasQ1, "Expected nameContains('Q1')")

        // Should have date condition
        let hasDateConstraint = parsed.candidateConditions.contains { condition in
            if case .dateOlderThan(let days, _) = condition {
                return days == 30
            }
            return false
        }
        XCTAssertTrue(hasDateConstraint, "Expected dateOlderThan(30)")
    }

    func testNamePatternDoesNotCaptureDestination() {
        let parser = NaturalLanguageRuleParser()
        // Tricky case: "Invoice" is in quotes but NOT in "in the name" context
        // It should still capture "Invoice" as nameContains since it's quoted
        let text = "Move files named 'Invoice' to Documents/Finance"

        let parsed = parser.parse(text)

        // Should have Invoice as nameContains
        let hasInvoice = parsed.candidateConditions.contains { condition in
            if case .nameContains(let value) = condition {
                return value == "Invoice"
            }
            return false
        }
        XCTAssertTrue(hasInvoice, "Expected nameContains('Invoice')")

        // Should NOT have "Documents" or "Finance" as nameContains
        let hasDocuments = parsed.candidateConditions.contains { condition in
            if case .nameContains(let value) = condition {
                return value.lowercased() == "documents"
            }
            return false
        }
        XCTAssertFalse(hasDocuments, "Should NOT capture 'Documents' from destination")
    }
}
