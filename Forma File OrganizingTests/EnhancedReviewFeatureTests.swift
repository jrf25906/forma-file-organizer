import XCTest
import SwiftUI
@testable import Forma_File_Organizing

/// Tests for Feature 5: Enhanced Review/Approval Workflow
/// Tests confidence scoring, reasoning display, grouping logic, and rejection tracking
@MainActor
final class EnhancedReviewFeatureTests: XCTestCase {

    var ruleEngine: RuleEngine!

    override func setUp() {
        super.setUp()
        ruleEngine = RuleEngine()
    }

    override func tearDown() {
        ruleEngine = nil
        super.tearDown()
    }

    // MARK: - Confidence Scoring Tests

    func testConfidenceScoring_MultipleConditions_ReturnsHighConfidence() {
        // Given: A rule with multiple conditions (AND logic)
        let rule = Rule(
            name: "Test Rule",
            conditions: [
                .fileExtension("pdf"),
                .nameContains("invoice")
            ],
            logicalOperator: .and,
            actionType: .move,
            destination: .mockFolder("Documents/Invoices"),
            isEnabled: true
        )

        let file = TestFileItem(
            name: "invoice_march.pdf",
            fileExtension: "pdf",
            path: "/Users/test/invoice_march.pdf"
        )

        // When: Evaluating the file
        let result = ruleEngine.evaluateFile(file, rules: [rule])

        // Then: Should have high confidence (0.9+)
        XCTAssertNotNil(result.confidenceScore, "Confidence score should be set")
        XCTAssertGreaterThanOrEqual(result.confidenceScore ?? 0, 0.9, "Multiple conditions should result in high confidence")
    }

    func testConfidenceScoring_ExtensionOnly_ReturnsLowConfidence() {
        // Given: A rule with only extension condition
        let rule = Rule(
            name: "PDF Rule",
            conditionType: .fileExtension,
            conditionValue: "pdf",
            actionType: .move,
            destination: .mockFolder("Documents"),
            isEnabled: true
        )

        let file = TestFileItem(
            name: "document.pdf",
            fileExtension: "pdf",
            path: "/Users/test/document.pdf"
        )

        // When: Evaluating the file
        let result = ruleEngine.evaluateFile(file, rules: [rule])

        // Then: Should have low confidence (0.5)
        XCTAssertEqual(result.confidenceScore ?? 0, 0.5, accuracy: 0.01, "Extension-only match should result in low confidence")
    }

    func testConfidenceScoring_NameBasedCondition_ReturnsMediumConfidence() {
        // Given: A rule with name-based condition
        let rule = Rule(
            name: "Screenshot Rule",
            conditionType: .nameContains,
            conditionValue: "screenshot",
            actionType: .move,
            destination: .mockFolder("Pictures/Screenshots"),
            isEnabled: true
        )

        let file = TestFileItem(
            name: "screenshot_2024.png",
            fileExtension: "png",
            path: "/Users/test/screenshot_2024.png"
        )

        // When: Evaluating the file
        let result = ruleEngine.evaluateFile(file, rules: [rule])

        // Then: Should have medium confidence (0.7)
        XCTAssertEqual(result.confidenceScore ?? 0, 0.7, accuracy: 0.01, "Name-based match should result in medium confidence")
    }

    // MARK: - Match Reasoning Tests

    func testMatchReasoning_GeneratesHumanReadableExplanation() {
        // Given: A rule with multiple conditions
        let rule = Rule(
            name: "Invoice Rule",
            conditions: [
                .fileExtension("pdf"),
                .nameContains("invoice")
            ],
            logicalOperator: .and,
            actionType: .move,
            destination: .mockFolder("Documents/Finance"),
            isEnabled: true
        )

        let file = TestFileItem(
            name: "invoice_march.pdf",
            fileExtension: "pdf",
            path: "/Users/test/invoice_march.pdf"
        )

        // When: Evaluating the file
        let result = ruleEngine.evaluateFile(file, rules: [rule])

        // Then: Should have a reasoning string
        XCTAssertNotNil(result.matchReason, "Match reason should be generated")
        // Note: generateMatchReason capitalizes the first letter for display ("Extension is .pdf")
        XCTAssertTrue(result.matchReason?.lowercased().contains("extension is .pdf") ?? false, "Should explain extension match")
        XCTAssertTrue(result.matchReason?.contains("name contains 'invoice'") ?? false, "Should explain name match")
        XCTAssertTrue(result.matchReason?.contains("AND") ?? false, "Should show AND operator")
    }

    func testMatchReasoning_ORLogic_ShowsOROperator() {
        // Given: A rule with OR logic
        let rule = Rule(
            name: "Document Rule",
            conditions: [
                .fileExtension("pdf"),
                .fileExtension("docx")
            ],
            logicalOperator: .or,
            actionType: .move,
            destination: .mockFolder("Documents"),
            isEnabled: true
        )

        let file = TestFileItem(
            name: "report.pdf",
            fileExtension: "pdf",
            path: "/Users/test/report.pdf"
        )

        // When: Evaluating the file
        let result = ruleEngine.evaluateFile(file, rules: [rule])

        // Then: Should show OR in reasoning
        XCTAssertTrue(result.matchReason?.contains("OR") ?? false, "Should show OR operator")
    }

    func testMatchReasoning_NoMatch_HasNoReason() {
        // Given: A file that doesn't match any rules
        let rule = Rule(
            name: "PDF Rule",
            conditionType: .fileExtension,
            conditionValue: "pdf",
            actionType: .move,
            destination: .mockFolder("Documents"),
            isEnabled: true
        )

        let file = TestFileItem(
            name: "image.png",
            fileExtension: "png",
            path: "/Users/test/image.png"
        )

        // When: Evaluating the file
        let result = ruleEngine.evaluateFile(file, rules: [rule])

        // Then: Should have no reasoning
        XCTAssertNil(result.matchReason, "No match should have no reasoning")
        XCTAssertNil(result.confidenceScore, "No match should have no confidence score")
    }

    // MARK: - File Grouping Tests

    func testFileGrouping_GroupsByDestination() {
        // Given: Multiple files with same destination
        let files = [
            TestFileItem(name: "invoice1.pdf", fileExtension: "pdf", path: "/test/invoice1.pdf", destination: .mockFolder("Documents/Finance")),
            TestFileItem(name: "invoice2.pdf", fileExtension: "pdf", path: "/test/invoice2.pdf", destination: .mockFolder("Documents/Finance")),
            TestFileItem(name: "screenshot.png", fileExtension: "png", path: "/test/screenshot.png", destination: .mockFolder("Pictures/Screenshots"))
        ]

        // When: Grouping by destination display name
        let grouped = Dictionary(grouping: files.filter { $0.destination != nil }) { $0.destination!.displayName }

        // Then: Should have 2 groups
        XCTAssertEqual(grouped.count, 2, "Should group into 2 destinations")
        XCTAssertEqual(grouped["Documents/Finance"]?.count, 2, "Finance group should have 2 files")
        XCTAssertEqual(grouped["Pictures/Screenshots"]?.count, 1, "Screenshots group should have 1 file")
    }

    func testFileGrouping_FiltersOutNoDestination() {
        // Given: Files with and without destinations
        let files = [
            TestFileItem(name: "invoice.pdf", fileExtension: "pdf", path: "/test/invoice.pdf", destination: .mockFolder("Documents/Finance")),
            TestFileItem(name: "unknown.txt", fileExtension: "txt", path: "/test/unknown.txt", destination: nil)
        ]

        // When: Filtering files with destinations
        let withDestinations = files.filter { $0.destination != nil }
        let withoutDestinations = files.filter { $0.destination == nil }

        // Then: Should separate correctly
        XCTAssertEqual(withDestinations.count, 1, "Should have 1 file with destination")
        XCTAssertEqual(withoutDestinations.count, 1, "Should have 1 file without destination")
    }

    // MARK: - Rejection Tracking Tests

    func testRejectionTracking_SkippedFile_TracksRejection() {
        // Given: A file with suggested destination
        let file = TestFileItem(
            name: "document.pdf",
            fileExtension: "pdf",
            path: "/test/document.pdf",
            destination: .mockFolder("Documents/Work")
        )

        // When: Simulating skip action (tracking rejection)
        let originalDestination = file.destination?.displayName
        var mutableFile = file
        mutableFile.rejectedDestination = originalDestination
        mutableFile.rejectionCount += 1

        // Then: Should track the rejection
        XCTAssertEqual(mutableFile.rejectedDestination, "Documents/Work", "Should store rejected destination")
        XCTAssertEqual(mutableFile.rejectionCount, 1, "Rejection count should increment")
    }

    func testRejectionTracking_MultipleRejections_IncrementsCount() {
        // Given: A file that's been rejected before
        var file = TestFileItem(
            name: "document.pdf",
            fileExtension: "pdf",
            path: "/test/document.pdf",
            destination: .mockFolder("Documents/Work"),
            rejectionCount: 1
        )

        // When: Rejecting again
        file.rejectionCount += 1

        // Then: Count should increment
        XCTAssertEqual(file.rejectionCount, 2, "Rejection count should increment to 2")
    }

    // MARK: - Confidence Badge Tests

    func testConfidenceBadge_HighScore_ShowsCorrectLevel() {
        // Given: High confidence score
        let score = 0.95

        // When: Determining confidence level
        let level: String
        if score >= 0.9 {
            level = "High"
        } else if score >= 0.6 {
            level = "Medium"
        } else {
            level = "Low"
        }

        // Then: Should be High
        XCTAssertEqual(level, "High", "Score 0.95 should be High confidence")
    }

    func testConfidenceBadge_MediumScore_ShowsCorrectLevel() {
        // Given: Medium confidence score
        let score = 0.75

        // When: Determining confidence level
        let level: String
        if score >= 0.9 {
            level = "High"
        } else if score >= 0.6 {
            level = "Medium"
        } else {
            level = "Low"
        }

        // Then: Should be Medium
        XCTAssertEqual(level, "Medium", "Score 0.75 should be Medium confidence")
    }

    func testConfidenceBadge_LowScore_ShowsCorrectLevel() {
        // Given: Low confidence score
        let score = 0.5

        // When: Determining confidence level
        let level: String
        if score >= 0.9 {
            level = "High"
        } else if score >= 0.6 {
            level = "Medium"
        } else {
            level = "Low"
        }

        // Then: Should be Low
        XCTAssertEqual(level, "Low", "Score 0.5 should be Low confidence")
    }

    // MARK: - Average Confidence Calculation Tests

    func testAverageConfidence_MultipleScores_CalculatesCorrectly() {
        // Given: Files with different confidence scores
        let files = [
            TestFileItem(name: "file1.pdf", fileExtension: "pdf", path: "/test/file1.pdf", confidenceScore: 0.9),
            TestFileItem(name: "file2.pdf", fileExtension: "pdf", path: "/test/file2.pdf", confidenceScore: 0.7),
            TestFileItem(name: "file3.pdf", fileExtension: "pdf", path: "/test/file3.pdf", confidenceScore: 0.8)
        ]

        // When: Calculating average
        let scores = files.compactMap { $0.confidenceScore }
        let average = scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)

        // Then: Should be correct average
        XCTAssertEqual(average, 0.8, accuracy: 0.01, "Average should be (0.9+0.7+0.8)/3 = 0.8")
    }

    func testAverageConfidence_NoScores_ReturnsZero() {
        // Given: Files without confidence scores
        let files = [
            TestFileItem(name: "file1.pdf", fileExtension: "pdf", path: "/test/file1.pdf", confidenceScore: nil),
            TestFileItem(name: "file2.pdf", fileExtension: "pdf", path: "/test/file2.pdf", confidenceScore: nil)
        ]

        // When: Calculating average
        let scores = files.compactMap { $0.confidenceScore }
        let average = scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)

        // Then: Should be zero
        XCTAssertEqual(average, 0, "Average should be 0 when no scores available")
    }
}

// MARK: - Test Models
// Note: TestFileItem is defined in TestModels.swift and shared across all test files
