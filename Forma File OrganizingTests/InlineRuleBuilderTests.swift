import XCTest
@testable import Forma_File_Organizing

/// Tests for compound rule building and matching.
/// Uses protocol-based TestFileItem/TestRule for faster, more reliable tests.
final class InlineRuleBuilderTests: XCTestCase {
    var testFiles: [TestFileItem] = []
    var ruleEngine: RuleEngine!

    override func setUp() {
        super.setUp()
        ruleEngine = RuleEngine()
        addTestFiles()
    }

    override func tearDown() {
        testFiles = []
        ruleEngine = nil
        super.tearDown()
    }

    private func addTestFiles() {
        testFiles = [
            TestFileItem(
                name: "Screenshot 2024-01-15.png",
                fileExtension: "png",
                path: "/Users/test/Desktop/Screenshot 2024-01-15.png",
                sizeInBytes: 1024 * 100
            ),
            TestFileItem(
                name: "Screenshot 2024-01-16.jpg",
                fileExtension: "jpg",
                path: "/Users/test/Desktop/Screenshot 2024-01-16.jpg",
                sizeInBytes: 1024 * 200
            ),
            TestFileItem(
                name: "Document.pdf",
                fileExtension: "pdf",
                path: "/Users/test/Desktop/Document.pdf",
                sizeInBytes: 1024 * 500
            ),
            TestFileItem(
                name: "Invoice_2024.pdf",
                fileExtension: "pdf",
                path: "/Users/test/Desktop/Invoice_2024.pdf",
                sizeInBytes: 1024 * 300
            )
        ]
    }
    
    // MARK: - Compound Condition Tests
    
    func testCompoundConditionWithAND() throws {
        // Create rule: extension is "pdf" AND name contains "Invoice"
        let condition1 = try RuleCondition(type: .fileExtension, value: "pdf")
        let condition2 = try RuleCondition(type: .nameContains, value: "Invoice")
        
        let rule = Rule(
            name: "PDF Invoices",
            conditions: [condition1, condition2],
            logicalOperator: .and,
            actionType: .move,
            destination: .folder(bookmark: Data(), displayName: "Documents/Invoices"),
            isEnabled: true
        )
        
        let matchedFiles = testFiles.filter { file in
            ruleEngine.fileMatchesRule(file: file, rule: rule)
        }
        
        // Should only match "Invoice_2024.pdf" (both conditions true)
        XCTAssertEqual(matchedFiles.count, 1)
        XCTAssertEqual(matchedFiles.first?.name, "Invoice_2024.pdf")
    }
    
    func testCompoundConditionWithOR() throws {
        // Create rule: name contains "Screenshot" OR name contains "Invoice"
        let condition1 = try RuleCondition(type: .nameContains, value: "Screenshot")
        let condition2 = try RuleCondition(type: .nameContains, value: "Invoice")
        
        let rule = Rule(
            name: "Screenshots or Invoices",
            conditions: [condition1, condition2],
            logicalOperator: .or,
            actionType: .move,
            destination: .folder(bookmark: Data(), displayName: "Documents/Archive"),
            isEnabled: true
        )
        
        let matchedFiles = testFiles.filter { file in
            ruleEngine.fileMatchesRule(file: file, rule: rule)
        }
        
        // Should match 3 files: two screenshots and one invoice
        XCTAssertEqual(matchedFiles.count, 3)
    }
    
    func testCompoundConditionWithThreeConditionsAND() throws {
        // Create rule: extension is "png" AND name contains "Screenshot" AND name contains "2024"
        let condition1 = try RuleCondition(type: .fileExtension, value: "png")
        let condition2 = try RuleCondition(type: .nameContains, value: "Screenshot")
        let condition3 = try RuleCondition(type: .nameContains, value: "2024")
        
        let rule = Rule(
            name: "2024 PNG Screenshots",
            conditions: [condition1, condition2, condition3],
            logicalOperator: .and,
            actionType: .move,
            destination: .folder(bookmark: Data(), displayName: "Pictures/Screenshots/2024"),
            isEnabled: true
        )
        
        let matchedFiles = testFiles.filter { file in
            ruleEngine.fileMatchesRule(file: file, rule: rule)
        }
        
        // Should only match "Screenshot 2024-01-15.png"
        XCTAssertEqual(matchedFiles.count, 1)
        XCTAssertEqual(matchedFiles.first?.name, "Screenshot 2024-01-15.png")
    }
    
    func testCompoundConditionWithMultipleExtensionsOR() throws {
        // Create rule: extension is "png" OR extension is "jpg"
        let condition1 = try RuleCondition(type: .fileExtension, value: "png")
        let condition2 = try RuleCondition(type: .fileExtension, value: "jpg")
        
        let rule = Rule(
            name: "All Images",
            conditions: [condition1, condition2],
            logicalOperator: .or,
            actionType: .move,
            destination: .folder(bookmark: Data(), displayName: "Pictures"),
            isEnabled: true
        )
        
        let matchedFiles = testFiles.filter { file in
            ruleEngine.fileMatchesRule(file: file, rule: rule)
        }
        
        // Should match both image files
        XCTAssertEqual(matchedFiles.count, 2)
    }
    
    func testCompoundConditionNaturalLanguageDescription() throws {
        // Test that compound rules generate proper natural language descriptions
        let condition1 = try RuleCondition(type: .fileExtension, value: "pdf")
        let condition2 = try RuleCondition(type: .nameContains, value: "Invoice")
        
        let ruleAND = Rule(
            name: "PDF Invoices",
            conditions: [condition1, condition2],
            logicalOperator: .and,
            actionType: .move,
            destination: .folder(bookmark: Data(), displayName: "Documents/Invoices"),
            isEnabled: true
        )

        let ruleOR = Rule(
            name: "PDFs or Invoices",
            conditions: [condition1, condition2],
            logicalOperator: .or,
            actionType: .move,
            destination: .folder(bookmark: Data(), displayName: "Documents/Archive"),
            isEnabled: true
        )
        
        // Check AND description
        let descAND = ruleAND.naturalLanguageDescription
        XCTAssertTrue(descAND.contains("extension is .pdf"))
        XCTAssertTrue(descAND.contains("name contains 'Invoice'"))
        XCTAssertTrue(descAND.contains("AND"))
        
        // Check OR description
        let descOR = ruleOR.naturalLanguageDescription
        XCTAssertTrue(descOR.contains("extension is .pdf"))
        XCTAssertTrue(descOR.contains("name contains 'Invoice'"))
        XCTAssertTrue(descOR.contains("OR"))
    }
    
    // MARK: - Backward Compatibility Tests
    
    func testLegacySingleConditionStillWorks() throws {
        // Create legacy single-condition rule
        let rule = Rule(
            name: "PDF Files",
            conditionType: .fileExtension,
            conditionValue: "pdf",
            actionType: .move,
            destination: .folder(bookmark: Data(), displayName: "Documents"),
            isEnabled: true
        )
        
        let matchedFiles = testFiles.filter { file in
            ruleEngine.fileMatchesRule(file: file, rule: rule)
        }
        
        // Should match both PDF files
        XCTAssertEqual(matchedFiles.count, 2)
    }
    
    func testRuleWithEmptyConditionsArrayUsesLegacyFields() throws {
        // Rule with empty conditions array should fall back to legacy fields
        let rule = Rule(
            name: "PNG Files",
            conditionType: .fileExtension,
            conditionValue: "png",
            actionType: .move,
            destination: .folder(bookmark: Data(), displayName: "Pictures"),
            isEnabled: true
        )
        
        // Verify conditions array is empty (legacy mode)
        XCTAssertTrue(rule.conditions.isEmpty)
        XCTAssertEqual(rule.logicalOperator, .single)
        
        let matchedFiles = testFiles.filter { file in
            ruleEngine.fileMatchesRule(file: file, rule: rule)
        }
        
        // Should match PNG file
        XCTAssertEqual(matchedFiles.count, 1)
        XCTAssertEqual(matchedFiles.first?.fileExtension, "png")
    }
    
    // MARK: - Edge Cases
    
    func testEmptyConditionsArrayReturnsFalse() throws {
        // Rule with no conditions should not match anything
        let rule = Rule(
            name: "Empty Rule",
            conditions: [],
            logicalOperator: .and,
            actionType: .move,
            destination: .folder(bookmark: Data(), displayName: "Nowhere"),
            isEnabled: true
        )
        
        // Manually clear legacy fields
        rule.conditionValue = ""
        
        let matchedFiles = testFiles.filter { file in
            ruleEngine.fileMatchesRule(file: file, rule: rule)
        }
        
        // Should match nothing if conditions are truly empty
        // Note: In practice, the Rule initializer sets legacy fields, so this is a theoretical edge case
        XCTAssertEqual(matchedFiles.count, 0)
    }
    
    func testDisabledCompoundRuleDoesNotMatch() throws {
        // Disabled compound rule should not match
        let condition1 = try RuleCondition(type: .fileExtension, value: "pdf")
        let condition2 = try RuleCondition(type: .nameContains, value: "Invoice")
        
        let rule = Rule(
            name: "Disabled Rule",
            conditions: [condition1, condition2],
            logicalOperator: .and,
            actionType: .move,
            destination: .folder(bookmark: Data(), displayName: "Documents"),
            isEnabled: false // Disabled
        )
        
        let matchedFiles = testFiles.filter { file in
            ruleEngine.fileMatchesRule(file: file, rule: rule)
        }
        
        XCTAssertEqual(matchedFiles.count, 0)
    }
    
    func testSingleConditionInConditionsArray() throws {
        // Rule with only one condition in the conditions array
        let condition = try RuleCondition(type: .fileExtension, value: "pdf")
        
        let rule = Rule(
            name: "Single in Array",
            conditions: [condition],
            logicalOperator: .single,
            actionType: .move,
            destination: .folder(bookmark: Data(), displayName: "Documents"),
            isEnabled: true
        )
        
        let matchedFiles = testFiles.filter { file in
            ruleEngine.fileMatchesRule(file: file, rule: rule)
        }
        
        // Should match both PDF files
        XCTAssertEqual(matchedFiles.count, 2)
    }
}
