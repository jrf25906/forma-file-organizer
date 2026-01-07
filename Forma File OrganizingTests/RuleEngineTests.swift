//
//  RuleEngineTests.swift
//  Forma File OrganizingTests
//
//  Created by James Farmer on 11/19/25.
//
//  Tests for the RuleEngine using protocol-based test models.
//  No SwiftData or MainActor required.

import XCTest
@testable import Forma_File_Organizing

final class RuleEngineTests: XCTestCase {

    var ruleEngine: RuleEngine!

    override func setUpWithError() throws {
        ruleEngine = RuleEngine()
    }

    override func tearDown() {
        ruleEngine = nil
    }

    func testExactMatch() {
        let rule = TestRule(conditionType: .nameStartsWith, conditionValue: "Test", destination: .mockFolder("TestFolder"))
        let file = TestFileItem(name: "TestFile.txt", fileExtension: "txt", path: "/path/to/TestFile.txt")

        let result = ruleEngine.evaluateFile(file, rules: [rule])

        XCTAssertEqual(result.status, .ready)
        XCTAssertEqual(result.destination?.displayName, "TestFolder")
    }

    func testExtensionMatch() {
        let rule = TestRule(conditionType: .fileExtension, conditionValue: "pdf", destination: .mockFolder("PDFs"))
        let file = TestFileItem(name: "Document.pdf", fileExtension: "pdf", path: "/path/to/Document.pdf")

        let result = ruleEngine.evaluateFile(file, rules: [rule])

        XCTAssertEqual(result.status, .ready)
        XCTAssertEqual(result.destination?.displayName, "PDFs")
    }

    func testCaseInsensitivity() {
        let rule = TestRule(conditionType: .fileExtension, conditionValue: "PDF", destination: .mockFolder("PDFs"))
        let file = TestFileItem(name: "Document.pdf", fileExtension: "pdf", path: "/path/to/Document.pdf")

        let result = ruleEngine.evaluateFile(file, rules: [rule])

        XCTAssertEqual(result.status, .ready)
        XCTAssertEqual(result.destination?.displayName, "PDFs")
    }

    func testNoMatch() {
        let rule = TestRule(conditionType: .fileExtension, conditionValue: "pdf", destination: .mockFolder("PDFs"))
        let file = TestFileItem(name: "Image.png", fileExtension: "png", path: "/path/to/Image.png")

        let result = ruleEngine.evaluateFile(file, rules: [rule])

        XCTAssertEqual(result.status, .pending)
        XCTAssertNil(result.destination)
    }

    func testDisabledRule() {
        let rule = TestRule(conditionType: .fileExtension, conditionValue: "pdf", isEnabled: false, destination: .mockFolder("PDFs"))
        let file = TestFileItem(name: "Document.pdf", fileExtension: "pdf", path: "/path/to/Document.pdf")

        let result = ruleEngine.evaluateFile(file, rules: [rule])

        XCTAssertEqual(result.status, .pending)
        XCTAssertNil(result.destination)
    }
    func testNameContainsMatch() {
        let rule = TestRule(conditionType: .nameContains, conditionValue: "Invoice", destination: .mockFolder("Invoices"))
        let file = TestFileItem(name: "2023_Invoice_001.pdf", fileExtension: "pdf", path: "/path/to/2023_Invoice_001.pdf")

        let result = ruleEngine.evaluateFile(file, rules: [rule])

        XCTAssertEqual(result.status, .ready)
        XCTAssertEqual(result.destination?.displayName, "Invoices")
    }

    func testNameEndsWithMatch() {
        // Test nameEndsWith with a filename that ends with .log
        // Note: nameEndsWith checks the full filename (file.name.lowercased().hasSuffix(conditionValue))
        let rule = TestRule(conditionType: .nameEndsWith, conditionValue: ".log", actionType: .delete)
        let file = TestFileItem(name: "server.log", fileExtension: "log", path: "/path/to/server.log")

        let result = ruleEngine.evaluateFile(file, rules: [rule])

        XCTAssertEqual(result.status, .ready)
        XCTAssertEqual(result.destination, .trash) // Delete action sets destination to trash
    }

    func testEvaluateFiles() {
        let rule1 = TestRule(conditionType: .fileExtension, conditionValue: "pdf", destination: .mockFolder("PDFs"))
        let rule2 = TestRule(conditionType: .fileExtension, conditionValue: "png", destination: .mockFolder("Images"))

        let file1 = TestFileItem(name: "doc.pdf", fileExtension: "pdf", path: "/path/doc.pdf")
        let file2 = TestFileItem(name: "img.png", fileExtension: "png", path: "/path/img.png")
        let file3 = TestFileItem(name: "notes.txt", fileExtension: "txt", path: "/path/notes.txt")

        let results = ruleEngine.evaluateFiles([file1, file2, file3], rules: [rule1, rule2])

        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results[0].destination?.displayName, "PDFs")
        XCTAssertEqual(results[1].destination?.displayName, "Images")
        XCTAssertNil(results[2].destination)
    }
    func testDateOlderThanMatch() {
        // Test file older than 7 days
        let oldDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let rule = TestRule(conditionType: .dateOlderThan, conditionValue: "7", destination: .mockFolder("OldFiles"))
        let file = TestFileItem(name: "old.txt", fileExtension: "txt", path: "/path/old.txt", creationDate: oldDate)

        let result = ruleEngine.evaluateFile(file, rules: [rule])

        XCTAssertEqual(result.status, .ready)
        XCTAssertEqual(result.destination?.displayName, "OldFiles")
    }

    func testDateOlderThanNoMatch() {
        // Test file only 2 days old (rule needs > 7)
        let newDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let rule = TestRule(conditionType: .dateOlderThan, conditionValue: "7", destination: .mockFolder("OldFiles"))
        let file = TestFileItem(name: "new.txt", fileExtension: "txt", path: "/path/new.txt", creationDate: newDate)

        let result = ruleEngine.evaluateFile(file, rules: [rule])

        XCTAssertEqual(result.status, .pending)
        XCTAssertNil(result.destination)
    }

    func testDateAndExtensionMatch() {
        // Test "dmg:7" logic
        let oldDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let rule = TestRule(conditionType: .dateOlderThan, conditionValue: "dmg:7", destination: .trash)

        // Matching file
        let file1 = TestFileItem(name: "installer.dmg", fileExtension: "dmg", path: "/path/installer.dmg", creationDate: oldDate)
        let result1 = ruleEngine.evaluateFile(file1, rules: [rule])
        XCTAssertEqual(result1.status, .ready)

        // Non-matching extension
        let file2 = TestFileItem(name: "image.png", fileExtension: "png", path: "/path/image.png", creationDate: oldDate)
        let result2 = ruleEngine.evaluateFile(file2, rules: [rule])
        XCTAssertEqual(result2.status, .pending)
    }

    // MARK: - Size Tests

    func testSizeLargerThanMatch() {
        // File is 200MB, rule requires > 100MB = should match
        let rule = TestRule(conditionType: .sizeLargerThan, conditionValue: "100MB", destination: .mockFolder("Large Files"))
        let file = TestFileItem(name: "big_file.zip", fileExtension: "zip", path: "/path/big_file.zip", sizeInBytes: 200 * 1024 * 1024)

        let result = ruleEngine.evaluateFile(file, rules: [rule])

        XCTAssertEqual(result.status, .ready)
        XCTAssertEqual(result.destination?.displayName, "Large Files")
    }

    func testSizeLargerThanNoMatch() {
        // File is 50MB, rule requires > 100MB = should NOT match
        let rule = TestRule(conditionType: .sizeLargerThan, conditionValue: "100MB", destination: .mockFolder("Large Files"))
        let file = TestFileItem(name: "small_file.zip", fileExtension: "zip", path: "/path/small_file.zip", sizeInBytes: 50 * 1024 * 1024)

        let result = ruleEngine.evaluateFile(file, rules: [rule])

        XCTAssertEqual(result.status, .pending)
        XCTAssertNil(result.destination)
    }

    func testSizeLargerThanBoundaryCondition() {
        // File is exactly 100MB, rule requires > 100MB = should NOT match (boundary case)
        let rule = TestRule(conditionType: .sizeLargerThan, conditionValue: "100MB", destination: .mockFolder("Large Files"))
        let file = TestFileItem(name: "exact_file.zip", fileExtension: "zip", path: "/path/exact_file.zip", sizeInBytes: 100 * 1024 * 1024)

        let result = ruleEngine.evaluateFile(file, rules: [rule])

        XCTAssertEqual(result.status, .pending, "File exactly at threshold should NOT match > condition")
        XCTAssertNil(result.destination)
    }

    func testSizeLargerThanWithKilobytes() {
        // Test with KB units: 2MB file vs 1000KB (976.5625KB) threshold
        let rule = TestRule(conditionType: .sizeLargerThan, conditionValue: "1000KB", destination: .mockFolder("Large Files"))
        let file = TestFileItem(name: "file.zip", fileExtension: "zip", path: "/path/file.zip", sizeInBytes: 2 * 1024 * 1024)

        let result = ruleEngine.evaluateFile(file, rules: [rule])

        XCTAssertEqual(result.status, .ready)
        XCTAssertEqual(result.destination?.displayName, "Large Files")
    }

    func testSizeLargerThanWithGigabytes() {
        // Test with GB units: 2GB file vs 1GB threshold
        let rule = TestRule(conditionType: .sizeLargerThan, conditionValue: "1GB", destination: .mockFolder("Huge Files"))
        let file = TestFileItem(name: "huge_file.dmg", fileExtension: "dmg", path: "/path/huge_file.dmg", sizeInBytes: 2 * 1024 * 1024 * 1024)
    }

    // MARK: - Match Reason Tests

    func testMatchReasonForExtension() {
        let rule = TestRule(conditionType: .fileExtension, conditionValue: "pdf", destination: .mockFolder("PDFs"))
        let file = TestFileItem(name: "document.pdf", fileExtension: "pdf", path: "/path/document.pdf")

        let result = ruleEngine.evaluateFile(file, rules: [rule])

        XCTAssertNotNil(result.matchReason)
        // Note: generateMatchReason capitalizes the first letter for display
        XCTAssert(result.matchReason!.lowercased().contains("extension"))
        XCTAssert(result.matchReason!.contains(".pdf"))
    }

    func testMatchReasonForNameContains() {
        let rule = TestRule(conditionType: .nameContains, conditionValue: "invoice", destination: .mockFolder("Invoices"))
        let file = TestFileItem(name: "2024_invoice_001.pdf", fileExtension: "pdf", path: "/path/2024_invoice_001.pdf")

        let result = ruleEngine.evaluateFile(file, rules: [rule])

        XCTAssertNotNil(result.matchReason)
        XCTAssert(result.matchReason!.contains("contains"))
        XCTAssert(result.matchReason!.contains("invoice"))
    }

    func testMatchReasonForCompoundConditions() {
        // Create compound rule with AND logic
        let conditions: [RuleCondition] = [
            .fileExtension("pdf"),
            .nameContains("invoice")
        ]
        let rule = TestRule(conditions: conditions, logicalOperator: .and, destination: .mockFolder("Invoices"))
        let file = TestFileItem(name: "invoice_2024.pdf", fileExtension: "pdf", path: "/path/invoice_2024.pdf")

        let result = ruleEngine.evaluateFile(file, rules: [rule])

        XCTAssertNotNil(result.matchReason)
        XCTAssert(result.matchReason!.contains("AND"))
        // Note: generateMatchReason capitalizes the first letter for display
        XCTAssert(result.matchReason!.lowercased().contains("extension"))
        XCTAssert(result.matchReason!.contains("contains"))
    }

    func testMatchReasonClearedWhenNoMatch() {
        let rule = TestRule(conditionType: .fileExtension, conditionValue: "pdf", destination: .mockFolder("PDFs"))
        var file = TestFileItem(name: "image.png", fileExtension: "png", path: "/path/image.png")
        file.matchReason = "Previous reason" // Set a previous reason

        let result = ruleEngine.evaluateFile(file, rules: [rule])

        XCTAssertNil(result.matchReason, "Match reason should be cleared when no rule matches")
        XCTAssertEqual(result.status, .pending)
    }

    func testSizeLargerThanWithTerabytes() {
        // Test with TB units: 1.5TB file vs 1TB threshold
        let rule = TestRule(conditionType: .sizeLargerThan, conditionValue: "1TB", destination: .mockFolder("Archive"))
        let fileSizeBytes = Int64(1.5 * Double(1024 * 1024 * 1024) * 1024.0)
        let file = TestFileItem(name: "massive_backup.tar", fileExtension: "tar", path: "/path/massive_backup.tar", sizeInBytes: fileSizeBytes)

        let result = ruleEngine.evaluateFile(file, rules: [rule])

        XCTAssertEqual(result.status, .ready)
        XCTAssertEqual(result.destination?.displayName, "Archive")
    }

    func testSizeLargerThanWithDecimalValue() {
        // Test with decimal values: 200MB file vs 150.5MB threshold
        let rule = TestRule(conditionType: .sizeLargerThan, conditionValue: "150.5MB", destination: .mockFolder("Large Files"))
        let file = TestFileItem(name: "file.zip", fileExtension: "zip", path: "/path/file.zip", sizeInBytes: 200 * 1024 * 1024)

        let result = ruleEngine.evaluateFile(file, rules: [rule])

        XCTAssertEqual(result.status, .ready)
        XCTAssertEqual(result.destination?.displayName, "Large Files")
    }

    func testSizeLargerThanWithBytes() {
        // Test with explicit bytes unit: 2048B file vs 1024B threshold
        let rule = TestRule(conditionType: .sizeLargerThan, conditionValue: "1024B", destination: .mockFolder("Small Files"))
        let file = TestFileItem(name: "tiny.txt", fileExtension: "txt", path: "/path/tiny.txt", sizeInBytes: 2048)

        let result = ruleEngine.evaluateFile(file, rules: [rule])

        XCTAssertEqual(result.status, .ready)
        XCTAssertEqual(result.destination?.displayName, "Small Files")
    }

    func testSizeLargerThanZeroSizeFile() {
        // Test edge case: 0 byte file should not match any positive threshold
        let rule = TestRule(conditionType: .sizeLargerThan, conditionValue: "1MB", destination: .mockFolder("Large Files"))
        let file = TestFileItem(name: "empty.txt", fileExtension: "txt", path: "/path/empty.txt", sizeInBytes: 0)

        let result = ruleEngine.evaluateFile(file, rules: [rule])

        XCTAssertEqual(result.status, .pending)
        XCTAssertNil(result.destination)
    }

    func testSizeLargerThanVerySmallThreshold() {
        // Test that 1KB file matches > 1B threshold
        let rule = TestRule(conditionType: .sizeLargerThan, conditionValue: "1B", destination: .mockFolder("Any Files"))
        let file = TestFileItem(name: "small.txt", fileExtension: "txt", path: "/path/small.txt", sizeInBytes: 1024)

        let result = ruleEngine.evaluateFile(file, rules: [rule])

        XCTAssertEqual(result.status, .ready)
        XCTAssertEqual(result.destination?.displayName, "Any Files")
    }

    // MARK: - Modification Date Tests

    func testDateModifiedOlderThanMatch() {
        let oldModDate = Calendar.current.date(byAdding: .day, value: -40, to: Date())!
        let rule = TestRule(conditionType: .dateModifiedOlderThan, conditionValue: "30", destination: .mockFolder("Stale Files"))
        let file = TestFileItem(name: "old.txt", fileExtension: "txt", path: "/path/old.txt", modificationDate: oldModDate)

        let result = ruleEngine.evaluateFile(file, rules: [rule])

        XCTAssertEqual(result.status, .ready)
        XCTAssertEqual(result.destination?.displayName, "Stale Files")
    }

    func testDateModifiedOlderThanNoMatch() {
        let recentModDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let rule = TestRule(conditionType: .dateModifiedOlderThan, conditionValue: "30", destination: .mockFolder("Stale Files"))
        let file = TestFileItem(name: "recent.txt", fileExtension: "txt", path: "/path/recent.txt", modificationDate: recentModDate)

        let result = ruleEngine.evaluateFile(file, rules: [rule])

        XCTAssertEqual(result.status, .pending)
        XCTAssertNil(result.destination)
    }

    // MARK: - Last Accessed Date Tests

    func testDateAccessedOlderThanMatch() {
        let oldAccessDate = Calendar.current.date(byAdding: .day, value: -100, to: Date())!
        let rule = TestRule(conditionType: .dateAccessedOlderThan, conditionValue: "90", destination: .mockFolder("Unused Files"))
        let file = TestFileItem(name: "unused.txt", fileExtension: "txt", path: "/path/unused.txt", lastAccessedDate: oldAccessDate)

        let result = ruleEngine.evaluateFile(file, rules: [rule])

        XCTAssertEqual(result.status, .ready)
        XCTAssertEqual(result.destination?.displayName, "Unused Files")
    }

    func testDateAccessedOlderThanNoMatch() {
        let recentAccessDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let rule = TestRule(conditionType: .dateAccessedOlderThan, conditionValue: "90", destination: .mockFolder("Unused Files"))
        let file = TestFileItem(name: "recent.txt", fileExtension: "txt", path: "/path/recent.txt", lastAccessedDate: recentAccessDate)

        let result = ruleEngine.evaluateFile(file, rules: [rule])

        XCTAssertEqual(result.status, .pending)
        XCTAssertNil(result.destination)
    }

    // MARK: - File Kind Tests

    func testFileKindImageMatch() {
        let rule = TestRule(conditionType: .fileKind, conditionValue: "image", destination: .mockFolder("Pictures"))
        let file1 = TestFileItem(name: "photo.jpg", fileExtension: "jpg", path: "/path/photo.jpg")
        let file2 = TestFileItem(name: "graphic.png", fileExtension: "png", path: "/path/graphic.png")
        let file3 = TestFileItem(name: "shot.heic", fileExtension: "heic", path: "/path/shot.heic")

        for file in [file1, file2, file3] {
            let result = ruleEngine.evaluateFile(file, rules: [rule])
            XCTAssertEqual(result.status, .ready)
            XCTAssertEqual(result.destination?.displayName, "Pictures")
        }
    }

    func testFileKindVideoMatch() {
        let rule = TestRule(conditionType: .fileKind, conditionValue: "video", destination: .mockFolder("Movies"))
        let file1 = TestFileItem(name: "clip.mp4", fileExtension: "mp4", path: "/path/clip.mp4")
        let file2 = TestFileItem(name: "movie.mov", fileExtension: "mov", path: "/path/movie.mov")

        for file in [file1, file2] {
            let result = ruleEngine.evaluateFile(file, rules: [rule])
            XCTAssertEqual(result.status, .ready)
            XCTAssertEqual(result.destination?.displayName, "Movies")
        }
    }

    func testFileKindDocumentMatch() {
        let rule = TestRule(conditionType: .fileKind, conditionValue: "document", destination: .mockFolder("Docs"))
        let file1 = TestFileItem(name: "report.pdf", fileExtension: "pdf", path: "/path/report.pdf")
        let file2 = TestFileItem(name: "letter.docx", fileExtension: "docx", path: "/path/letter.docx")

        for file in [file1, file2] {
            let result = ruleEngine.evaluateFile(file, rules: [rule])
            XCTAssertEqual(result.status, .ready)
            XCTAssertEqual(result.destination?.displayName, "Docs")
        }
    }

    func testFileKindNoMatch() {
        let rule = TestRule(conditionType: .fileKind, conditionValue: "image", destination: .mockFolder("Pictures"))
        let file = TestFileItem(name: "report.pdf", fileExtension: "pdf", path: "/path/report.pdf")

        let result = ruleEngine.evaluateFile(file, rules: [rule])

        XCTAssertEqual(result.status, .pending)
        XCTAssertNil(result.destination)
    }

    // MARK: - Compound Condition Tests (AND/OR Logic)

    func testCompoundConditionAND_BothMatch() throws {
        // Rule: file is .dmg AND older than 7 days
        let oldDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let conditions = [
            try RuleCondition(type: .fileExtension, value: "dmg"),
            try RuleCondition(type: .dateOlderThan, value: "7")
        ]
        let rule = TestRule(conditions: conditions, logicalOperator: .and, destination: .mockFolder("Old Installers"))

        let file = TestFileItem(name: "installer.dmg", fileExtension: "dmg", path: "/path/installer.dmg", creationDate: oldDate)
        let result = ruleEngine.evaluateFile(file, rules: [rule])

        XCTAssertEqual(result.status, .ready)
        XCTAssertEqual(result.destination?.displayName, "Old Installers")
    }

    func testCompoundConditionAND_FirstMatchesOnly() throws {
        // Rule: file is .dmg AND older than 7 days
        let recentDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let conditions = [
            try RuleCondition(type: .fileExtension, value: "dmg"),
            try RuleCondition(type: .dateOlderThan, value: "7")
        ]
        let rule = TestRule(conditions: conditions, logicalOperator: .and, destination: .mockFolder("Old Installers"))

        // File is .dmg but only 2 days old (should NOT match)
        let file = TestFileItem(name: "installer.dmg", fileExtension: "dmg", path: "/path/installer.dmg", creationDate: recentDate)
        let result = ruleEngine.evaluateFile(file, rules: [rule])

        XCTAssertEqual(result.status, .pending)
        XCTAssertNil(result.destination)
    }

    func testCompoundConditionAND_SecondMatchesOnly() throws {
        // Rule: file is .dmg AND older than 7 days
        let oldDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let conditions = [
            try RuleCondition(type: .fileExtension, value: "dmg"),
            try RuleCondition(type: .dateOlderThan, value: "7")
        ]
        let rule = TestRule(conditions: conditions, logicalOperator: .and, destination: .mockFolder("Old Installers"))

        // File is old but not .dmg (should NOT match)
        let file = TestFileItem(name: "image.png", fileExtension: "png", path: "/path/image.png", creationDate: oldDate)
        let result = ruleEngine.evaluateFile(file, rules: [rule])

        XCTAssertEqual(result.status, .pending)
        XCTAssertNil(result.destination)
    }

    func testCompoundConditionAND_NeitherMatches() throws {
        // Rule: file is .dmg AND older than 7 days
        let recentDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let conditions = [
            try RuleCondition(type: .fileExtension, value: "dmg"),
            try RuleCondition(type: .dateOlderThan, value: "7")
        ]
        let rule = TestRule(conditions: conditions, logicalOperator: .and, destination: .mockFolder("Old Installers"))

        // File is neither .dmg nor old (should NOT match)
        let file = TestFileItem(name: "image.png", fileExtension: "png", path: "/path/image.png", creationDate: recentDate)
        let result = ruleEngine.evaluateFile(file, rules: [rule])

        XCTAssertEqual(result.status, .pending)
        XCTAssertNil(result.destination)
    }

    func testCompoundConditionOR_BothMatch() throws {
        // Rule: file is .pdf OR .docx
        let conditions = [
            try RuleCondition(type: .fileExtension, value: "pdf"),
            try RuleCondition(type: .fileExtension, value: "docx")
        ]
        let rule = TestRule(conditions: conditions, logicalOperator: .or, destination: .mockFolder("Documents"))

        let pdfFile = TestFileItem(name: "report.pdf", fileExtension: "pdf", path: "/path/report.pdf")
        let docxFile = TestFileItem(name: "letter.docx", fileExtension: "docx", path: "/path/letter.docx")

        let pdfResult = ruleEngine.evaluateFile(pdfFile, rules: [rule])
        XCTAssertEqual(pdfResult.status, .ready)
        XCTAssertEqual(pdfResult.destination?.displayName, "Documents")

        let docxResult = ruleEngine.evaluateFile(docxFile, rules: [rule])
        XCTAssertEqual(docxResult.status, .ready)
        XCTAssertEqual(docxResult.destination?.displayName, "Documents")
    }

    func testCompoundConditionOR_OneMatches() throws {
        // Rule: file is .pdf OR .docx
        let conditions = [
            try RuleCondition(type: .fileExtension, value: "pdf"),
            try RuleCondition(type: .fileExtension, value: "docx")
        ]
        let rule = TestRule(conditions: conditions, logicalOperator: .or, destination: .mockFolder("Documents"))

        let pdfFile = TestFileItem(name: "report.pdf", fileExtension: "pdf", path: "/path/report.pdf")
        let result = ruleEngine.evaluateFile(pdfFile, rules: [rule])

        XCTAssertEqual(result.status, .ready)
        XCTAssertEqual(result.destination?.displayName, "Documents")
    }

    func testCompoundConditionOR_NeitherMatches() throws {
        // Rule: file is .pdf OR .docx
        let conditions = [
            try RuleCondition(type: .fileExtension, value: "pdf"),
            try RuleCondition(type: .fileExtension, value: "docx")
        ]
        let rule = TestRule(conditions: conditions, logicalOperator: .or, destination: .mockFolder("Documents"))

        let pngFile = TestFileItem(name: "image.png", fileExtension: "png", path: "/path/image.png")
        let result = ruleEngine.evaluateFile(pngFile, rules: [rule])

        XCTAssertEqual(result.status, .pending)
        XCTAssertNil(result.destination)
    }

    func testCompoundConditionAND_ThreeConditions() throws {
        // Rule: nameContains "Invoice" AND .pdf AND older than 30 days
        let oldDate = Calendar.current.date(byAdding: .day, value: -40, to: Date())!
        let conditions = [
            try RuleCondition(type: .nameContains, value: "Invoice"),
            try RuleCondition(type: .fileExtension, value: "pdf"),
            try RuleCondition(type: .dateOlderThan, value: "30")
        ]
        let rule = TestRule(conditions: conditions, logicalOperator: .and, destination: .mockFolder("Old Invoices"))

        // All conditions match
        let matchingFile = TestFileItem(name: "Invoice_2023_001.pdf", fileExtension: "pdf", path: "/path/Invoice_2023_001.pdf", creationDate: oldDate)
        let matchResult = ruleEngine.evaluateFile(matchingFile, rules: [rule])
        XCTAssertEqual(matchResult.status, .ready)
        XCTAssertEqual(matchResult.destination?.displayName, "Old Invoices")

        // Missing "Invoice" in name
        let noNameFile = TestFileItem(name: "Receipt_2023_001.pdf", fileExtension: "pdf", path: "/path/Receipt_2023_001.pdf", creationDate: oldDate)
        let noNameResult = ruleEngine.evaluateFile(noNameFile, rules: [rule])
        XCTAssertEqual(noNameResult.status, .pending)

        // Wrong extension
        let wrongExtFile = TestFileItem(name: "Invoice_2023_001.docx", fileExtension: "docx", path: "/path/Invoice_2023_001.docx", creationDate: oldDate)
        let wrongExtResult = ruleEngine.evaluateFile(wrongExtFile, rules: [rule])
        XCTAssertEqual(wrongExtResult.status, .pending)

        // Too recent
        let recentDate = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        let recentFile = TestFileItem(name: "Invoice_2024_001.pdf", fileExtension: "pdf", path: "/path/Invoice_2024_001.pdf", creationDate: recentDate)
        let recentResult = ruleEngine.evaluateFile(recentFile, rules: [rule])
        XCTAssertEqual(recentResult.status, .pending)
    }

    func testBackwardCompatibility_LegacySingleCondition() {
        // Ensure old single-condition rules still work
        let rule = TestRule(conditionType: .fileExtension, conditionValue: "pdf", destination: .mockFolder("PDFs"))
        let file = TestFileItem(name: "document.pdf", fileExtension: "pdf", path: "/path/document.pdf")

        let result = ruleEngine.evaluateFile(file, rules: [rule])

        XCTAssertEqual(result.status, .ready)
        XCTAssertEqual(result.destination?.displayName, "PDFs")
    }

    // MARK: - Delete Rule Tests

    func testDeleteRuleSetsTrashAsDestination() {
        // Delete rules should set destination to .trash so UI displays correctly
        let rule = TestRule(conditionType: .fileExtension, conditionValue: "dmg", destination: nil, actionType: .delete)
        let file = TestFileItem(name: "installer.dmg", fileExtension: "dmg", path: "/path/installer.dmg")

        let result = ruleEngine.evaluateFile(file, rules: [rule])

        XCTAssertEqual(result.status, .ready)
        XCTAssertTrue(result.destination?.isTrash ?? false, "Delete rules should set destination to trash")
    }

    func testCompoundDeleteRuleSetsTrashAsDestination() throws {
        // Compound delete rule: .dmg AND older than 3 days
        let oldDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        let conditions = [
            try RuleCondition(type: .fileExtension, value: "dmg"),
            try RuleCondition(type: .dateOlderThan, value: "3")
        ]
        let rule = TestRule(conditions: conditions, logicalOperator: .and, destination: nil, actionType: .delete)

        let file = TestFileItem(name: "Sonos_90.0-67171.dmg", fileExtension: "dmg", path: "/path/Sonos_90.0-67171.dmg", creationDate: oldDate)
        let result = ruleEngine.evaluateFile(file, rules: [rule])

        XCTAssertEqual(result.status, .ready, "5-day-old DMG should match rule requiring > 3 days")
        XCTAssertTrue(result.destination?.isTrash ?? false, "Delete rules should set destination to trash")
    }

    // MARK: - NOT Operator Tests

    func testNotOperator_NegatesExtensionMatch() {
        // Rule: NOT .pdf (matches all non-PDF files)
        let conditions: [RuleCondition] = [.not(.fileExtension("pdf"))]
        let rule = TestRule(conditions: conditions, logicalOperator: .single, destination: .mockFolder("Non-PDFs"))

        let pngFile = TestFileItem(name: "image.png", fileExtension: "png", path: "/path/image.png")
        let pngResult = ruleEngine.evaluateFile(pngFile, rules: [rule])
        XCTAssertEqual(pngResult.status, .ready, "PNG should match NOT .pdf rule")
        XCTAssertEqual(pngResult.destination?.displayName, "Non-PDFs")

        let pdfFile = TestFileItem(name: "document.pdf", fileExtension: "pdf", path: "/path/document.pdf")
        let pdfResult = ruleEngine.evaluateFile(pdfFile, rules: [rule])
        XCTAssertEqual(pdfResult.status, .pending, "PDF should NOT match NOT .pdf rule")
        XCTAssertNil(pdfResult.destination)
    }

    func testNotOperator_NegatesNameContains() {
        // Rule: NOT nameContains("temp") - matches files without "temp" in name
        let conditions: [RuleCondition] = [.not(.nameContains("temp"))]
        let rule = TestRule(conditions: conditions, logicalOperator: .single, destination: .mockFolder("Permanent"))

        let normalFile = TestFileItem(name: "document.pdf", fileExtension: "pdf", path: "/path/document.pdf")
        let normalResult = ruleEngine.evaluateFile(normalFile, rules: [rule])
        XCTAssertEqual(normalResult.status, .ready, "Normal file should match NOT nameContains('temp') rule")

        let tempFile = TestFileItem(name: "temp_file.txt", fileExtension: "txt", path: "/path/temp_file.txt")
        let tempResult = ruleEngine.evaluateFile(tempFile, rules: [rule])
        XCTAssertEqual(tempResult.status, .pending, "Temp file should NOT match NOT nameContains('temp') rule")
    }

    func testNotOperator_CombinedWithAND() {
        // Rule: .pdf AND NOT nameContains("invoice")
        // Matches PDFs that don't have "invoice" in the name
        let conditions: [RuleCondition] = [
            .fileExtension("pdf"),
            .not(.nameContains("invoice"))
        ]
        let rule = TestRule(conditions: conditions, logicalOperator: .and, destination: .mockFolder("Non-Invoice PDFs"))

        // PDF without "invoice" - should match
        let regularPDF = TestFileItem(name: "report.pdf", fileExtension: "pdf", path: "/path/report.pdf")
        let regularResult = ruleEngine.evaluateFile(regularPDF, rules: [rule])
        XCTAssertEqual(regularResult.status, .ready, "Regular PDF should match")

        // PDF with "invoice" - should NOT match
        let invoicePDF = TestFileItem(name: "invoice_2024.pdf", fileExtension: "pdf", path: "/path/invoice_2024.pdf")
        let invoiceResult = ruleEngine.evaluateFile(invoicePDF, rules: [rule])
        XCTAssertEqual(invoiceResult.status, .pending, "Invoice PDF should NOT match")

        // Non-PDF without "invoice" - should NOT match (fails .pdf condition)
        let txtFile = TestFileItem(name: "report.txt", fileExtension: "txt", path: "/path/report.txt")
        let txtResult = ruleEngine.evaluateFile(txtFile, rules: [rule])
        XCTAssertEqual(txtResult.status, .pending, "TXT file should NOT match")
    }

    func testNotOperator_DoubleNegation() {
        // Rule: NOT (NOT .pdf) should be equivalent to .pdf
        let conditions: [RuleCondition] = [.not(.not(.fileExtension("pdf")))]
        let rule = TestRule(conditions: conditions, logicalOperator: .single, destination: .mockFolder("PDFs"))

        let pdfFile = TestFileItem(name: "document.pdf", fileExtension: "pdf", path: "/path/document.pdf")
        let pdfResult = ruleEngine.evaluateFile(pdfFile, rules: [rule])
        XCTAssertEqual(pdfResult.status, .ready, "PDF should match double-negated .pdf rule")

        let pngFile = TestFileItem(name: "image.png", fileExtension: "png", path: "/path/image.png")
        let pngResult = ruleEngine.evaluateFile(pngFile, rules: [rule])
        XCTAssertEqual(pngResult.status, .pending, "PNG should NOT match double-negated .pdf rule")
    }

    // MARK: - Exclusion Condition Tests

    func testExclusionCondition_BasicExclusion() {
        // Rule: Move all PDFs, EXCEPT those containing "confidential"
        let rule = TestRule(
            conditionType: .fileExtension,
            conditionValue: "pdf",
            destination: .mockFolder("PDFs"),
            exclusionConditions: [.nameContains("confidential")]
        )

        // Regular PDF - should match
        let regularPDF = TestFileItem(name: "report.pdf", fileExtension: "pdf", path: "/path/report.pdf")
        let regularResult = ruleEngine.evaluateFile(regularPDF, rules: [rule])
        XCTAssertEqual(regularResult.status, .ready, "Regular PDF should match")
        XCTAssertEqual(regularResult.destination?.displayName, "PDFs")

        // Confidential PDF - should be excluded
        let confidentialPDF = TestFileItem(name: "confidential_report.pdf", fileExtension: "pdf", path: "/path/confidential_report.pdf")
        let confidentialResult = ruleEngine.evaluateFile(confidentialPDF, rules: [rule])
        XCTAssertEqual(confidentialResult.status, .pending, "Confidential PDF should be excluded")
        XCTAssertNil(confidentialResult.destination)
    }

    func testExclusionCondition_MultipleExclusions() {
        // Rule: Move all PDFs, EXCEPT those containing "temp" OR "draft"
        let rule = TestRule(
            conditionType: .fileExtension,
            conditionValue: "pdf",
            destination: .mockFolder("PDFs"),
            exclusionConditions: [
                .nameContains("temp"),
                .nameContains("draft")
            ]
        )

        // Regular PDF - should match
        let regularPDF = TestFileItem(name: "final_report.pdf", fileExtension: "pdf", path: "/path/final_report.pdf")
        let regularResult = ruleEngine.evaluateFile(regularPDF, rules: [rule])
        XCTAssertEqual(regularResult.status, .ready)

        // Temp PDF - should be excluded
        let tempPDF = TestFileItem(name: "temp_report.pdf", fileExtension: "pdf", path: "/path/temp_report.pdf")
        let tempResult = ruleEngine.evaluateFile(tempPDF, rules: [rule])
        XCTAssertEqual(tempResult.status, .pending, "Temp PDF should be excluded")

        // Draft PDF - should be excluded
        let draftPDF = TestFileItem(name: "draft_v2.pdf", fileExtension: "pdf", path: "/path/draft_v2.pdf")
        let draftResult = ruleEngine.evaluateFile(draftPDF, rules: [rule])
        XCTAssertEqual(draftResult.status, .pending, "Draft PDF should be excluded")
    }

    func testExclusionCondition_WithCompoundPrimaryConditions() throws {
        // Rule: Move files that are (.pdf AND nameContains "invoice"), EXCEPT those larger than 10MB
        let primaryConditions = [
            try RuleCondition(type: .fileExtension, value: "pdf"),
            try RuleCondition(type: .nameContains, value: "invoice")
        ]
        let rule = TestRule(
            conditions: primaryConditions,
            logicalOperator: .and,
            destination: .mockFolder("Invoices"),
            exclusionConditions: [.sizeLargerThan(bytes: Int64(10 * 1024 * 1024))]
        )

        // Small invoice PDF - should match
        let smallInvoice = TestFileItem(name: "invoice_2024.pdf", fileExtension: "pdf", path: "/path/invoice_2024.pdf", sizeInBytes: 1 * 1024 * 1024)
        let smallResult = ruleEngine.evaluateFile(smallInvoice, rules: [rule])
        XCTAssertEqual(smallResult.status, .ready, "Small invoice should match")

        // Large invoice PDF - should be excluded
        let largeInvoice = TestFileItem(name: "invoice_attachments.pdf", fileExtension: "pdf", path: "/path/invoice_attachments.pdf", sizeInBytes: 20 * 1024 * 1024)
        let largeResult = ruleEngine.evaluateFile(largeInvoice, rules: [rule])
        XCTAssertEqual(largeResult.status, .pending, "Large invoice should be excluded")
    }

    func testExclusionCondition_NoExclusionMatch() {
        // Rule with exclusions, but file doesn't match any exclusion
        let rule = TestRule(
            conditionType: .fileExtension,
            conditionValue: "pdf",
            destination: .mockFolder("PDFs"),
            exclusionConditions: [.nameContains("temp"), .nameContains("draft")]
        )

        let file = TestFileItem(name: "final_report.pdf", fileExtension: "pdf", path: "/path/final_report.pdf")
        let result = ruleEngine.evaluateFile(file, rules: [rule])

        XCTAssertEqual(result.status, .ready, "File should match when no exclusion applies")
        XCTAssertEqual(result.destination?.displayName, "PDFs")
    }

    // MARK: - Priority (sortOrder) Tests

    func testPriorityOrder_FirstMatchWins() {
        // Two rules that could both match - first by sortOrder should win
        let highPriorityRule = TestRule(
            conditionType: .fileExtension,
            conditionValue: "pdf",
            destination: .mockFolder("High Priority"),
            sortOrder: 0
        )
        let lowPriorityRule = TestRule(
            conditionType: .fileExtension,
            conditionValue: "pdf",
            destination: .mockFolder("Low Priority"),
            sortOrder: 10
        )

        let file = TestFileItem(name: "document.pdf", fileExtension: "pdf", path: "/path/document.pdf")

        // Sorted by priority (sortOrder ascending)
        let sortedRules = [highPriorityRule, lowPriorityRule].sorted { $0.sortOrder < $1.sortOrder }
        let result = ruleEngine.evaluateFile(file, rules: sortedRules)

        XCTAssertEqual(result.destination?.displayName, "High Priority", "Higher priority rule (lower sortOrder) should win")
    }

    func testPriorityOrder_MoreSpecificFirst() {
        // Common pattern: specific rules before generic rules
        let specificRule = TestRule(
            conditions: [.fileExtension("pdf"), .nameContains("invoice")],
            logicalOperator: .and,
            destination: .mockFolder("Invoices"),
            sortOrder: 0  // Higher priority
        )
        let genericRule = TestRule(
            conditionType: .fileExtension,
            conditionValue: "pdf",
            destination: .mockFolder("All PDFs"),
            sortOrder: 10  // Lower priority
        )

        // Invoice PDF - should go to Invoices (specific rule)
        let invoicePDF = TestFileItem(name: "invoice_2024.pdf", fileExtension: "pdf", path: "/path/invoice_2024.pdf")
        let sortedRules = [specificRule, genericRule].sorted { $0.sortOrder < $1.sortOrder }
        let invoiceResult = ruleEngine.evaluateFile(invoicePDF, rules: sortedRules)
        XCTAssertEqual(invoiceResult.destination?.displayName, "Invoices", "Specific rule should match invoice PDF")

        // Regular PDF - should go to All PDFs (generic rule, since specific doesn't match)
        let regularPDF = TestFileItem(name: "report.pdf", fileExtension: "pdf", path: "/path/report.pdf")
        let regularResult = ruleEngine.evaluateFile(regularPDF, rules: sortedRules)
        XCTAssertEqual(regularResult.destination?.displayName, "All PDFs", "Generic rule should match regular PDF")
    }

    // MARK: - Unicode and Special Character Tests

    func testUnicodeNormalization_NameContains_ComposedVsDecomposed() {
        // Test that composed (é = U+00E9) and decomposed (e + U+0301) forms match
        let rule = TestRule(
            conditionType: .nameContains,
            conditionValue: "café",  // Composed form
            destination: .mockFolder("Coffee")
        )

        // File with decomposed form (e + combining acute accent)
        let decomposedFile = TestFileItem(
            name: "cafe\u{0301}_menu.pdf",  // Decomposed: e + combining accent
            fileExtension: "pdf",
            path: "/path/cafe\u{0301}_menu.pdf"
        )

        let result = ruleEngine.evaluateFile(decomposedFile, rules: [rule])
        XCTAssertEqual(result.status, .ready, "Decomposed form should match composed pattern via Unicode normalization")
        XCTAssertEqual(result.destination?.displayName, "Coffee")
    }

    func testUnicodeNormalization_NameStartsWith_ComposedPattern() {
        // Rule uses composed form, file uses decomposed
        let rule = TestRule(
            conditionType: .nameStartsWith,
            conditionValue: "résumé",  // Composed
            destination: .mockFolder("Resumes")
        )

        let decomposedFile = TestFileItem(
            name: "re\u{0301}sume\u{0301}_2024.docx",  // Decomposed
            fileExtension: "docx",
            path: "/path/re\u{0301}sume\u{0301}_2024.docx"
        )

        let result = ruleEngine.evaluateFile(decomposedFile, rules: [rule])
        XCTAssertEqual(result.status, .ready, "Decomposed filename should match composed pattern")
    }

    func testUnicodeNormalization_NameEndsWith_Bidirectional() {
        // Rule uses decomposed form, file uses composed
        let rule = TestRule(
            conditionType: .nameEndsWith,
            conditionValue: "cafe\u{0301}.txt",  // Decomposed pattern
            destination: .mockFolder("Coffee")
        )

        let composedFile = TestFileItem(
            name: "paris_café.txt",  // Composed: é
            fileExtension: "txt",
            path: "/path/paris_café.txt"
        )

        let result = ruleEngine.evaluateFile(composedFile, rules: [rule])
        XCTAssertEqual(result.status, .ready, "Composed filename should match decomposed pattern")
    }

    func testSpecialCharacters_Brackets_NameContains() {
        // Brackets are regex metacharacters but should be matched literally
        let rule = TestRule(
            conditionType: .nameContains,
            conditionValue: "[2024]",
            destination: .mockFolder("2024 Projects")
        )

        let file = TestFileItem(
            name: "Project [2024] Final.docx",
            fileExtension: "docx",
            path: "/path/Project [2024] Final.docx"
        )

        let result = ruleEngine.evaluateFile(file, rules: [rule])
        XCTAssertEqual(result.status, .ready, "Brackets should be matched literally")
        XCTAssertEqual(result.destination?.displayName, "2024 Projects")
    }

    func testSpecialCharacters_Parentheses_NameEndsWith() {
        // Parentheses are regex metacharacters
        let rule = TestRule(
            conditionType: .nameEndsWith,
            conditionValue: "(copy).txt",
            destination: .mockFolder("Copies")
        )

        let file = TestFileItem(
            name: "document (copy).txt",
            fileExtension: "txt",
            path: "/path/document (copy).txt"
        )

        let result = ruleEngine.evaluateFile(file, rules: [rule])
        XCTAssertEqual(result.status, .ready, "Parentheses should be matched literally")
    }

    func testSpecialCharacters_Asterisk_NameContains() {
        // Asterisk is a regex quantifier
        let rule = TestRule(
            conditionType: .nameContains,
            conditionValue: "*IMPORTANT*",
            destination: .mockFolder("Important")
        )

        let file = TestFileItem(
            name: "file *IMPORTANT* notes.txt",
            fileExtension: "txt",
            path: "/path/file *IMPORTANT* notes.txt"
        )

        let result = ruleEngine.evaluateFile(file, rules: [rule])
        XCTAssertEqual(result.status, .ready, "Asterisks should be matched literally")
    }

    func testSpecialCharacters_DollarSign_NameStartsWith() {
        // Dollar sign is a regex anchor
        let rule = TestRule(
            conditionType: .nameStartsWith,
            conditionValue: "$",
            destination: .mockFolder("Cash")
        )

        let file = TestFileItem(
            name: "$money.csv",
            fileExtension: "csv",
            path: "/path/$money.csv"
        )

        let result = ruleEngine.evaluateFile(file, rules: [rule])
        XCTAssertEqual(result.status, .ready, "Dollar sign should be matched literally")
    }

    func testSpecialCharacters_Plus_NameContains() {
        // Plus is a regex quantifier
        let rule = TestRule(
            conditionType: .nameContains,
            conditionValue: "C++",
            destination: .mockFolder("Code")
        )

        let file = TestFileItem(
            name: "C++ Tutorial.pdf",
            fileExtension: "pdf",
            path: "/path/C++ Tutorial.pdf"
        )

        let result = ruleEngine.evaluateFile(file, rules: [rule])
        XCTAssertEqual(result.status, .ready, "Plus signs should be matched literally")
    }

    func testSpecialCharacters_Question_NameContains() {
        // Question mark is a regex quantifier
        let rule = TestRule(
            conditionType: .nameContains,
            conditionValue: "Why?",
            destination: .mockFolder("Questions")
        )

        let file = TestFileItem(
            name: "Why? notes.txt",
            fileExtension: "txt",
            path: "/path/Why? notes.txt"
        )

        let result = ruleEngine.evaluateFile(file, rules: [rule])
        XCTAssertEqual(result.status, .ready, "Question marks should be matched literally")
    }

    func testSpecialCharacters_Emoji_NameContains() {
        // Emoji in filenames
        let rule = TestRule(
            conditionType: .nameContains,
            conditionValue: "🎉",
            destination: .mockFolder("Celebrations")
        )

        let file = TestFileItem(
            name: "Party 🎉 Planning.docx",
            fileExtension: "docx",
            path: "/path/Party 🎉 Planning.docx"
        )

        let result = ruleEngine.evaluateFile(file, rules: [rule])
        XCTAssertEqual(result.status, .ready, "Emoji should be matched correctly")
    }

    func testSpecialCharacters_Japanese_NameContains() {
        // Japanese characters
        let rule = TestRule(
            conditionType: .nameContains,
            conditionValue: "日本語",
            destination: .mockFolder("Japanese")
        )

        let file = TestFileItem(
            name: "日本語ファイル.txt",
            fileExtension: "txt",
            path: "/path/日本語ファイル.txt"
        )

        let result = ruleEngine.evaluateFile(file, rules: [rule])
        XCTAssertEqual(result.status, .ready, "Japanese characters should be matched correctly")
    }

    func testCombinedUnicodeAndSpecialChars_CompoundCondition() {
        // Compound rule with Unicode and special characters
        let conditions: [RuleCondition] = [
            .nameContains("café"),
            .nameContains("[draft]")
        ]
        let rule = TestRule(
            conditions: conditions,
            logicalOperator: .and,
            destination: .mockFolder("Coffee Drafts")
        )

        let file = TestFileItem(
            name: "cafe\u{0301} menu [draft].pdf",  // Decomposed café + brackets
            fileExtension: "pdf",
            path: "/path/cafe\u{0301} menu [draft].pdf"
        )

        let result = ruleEngine.evaluateFile(file, rules: [rule])
        XCTAssertEqual(result.status, .ready, "Compound conditions should handle Unicode and special chars together")
        XCTAssertEqual(result.destination?.displayName, "Coffee Drafts")
    }
}
