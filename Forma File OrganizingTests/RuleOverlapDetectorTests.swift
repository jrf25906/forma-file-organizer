import XCTest
@testable import Forma_File_Organizing

@MainActor
final class RuleOverlapDetectorTests: XCTestCase {

    func testUnrelatedSingleConditionRulesDoNotOverlap() {
        let detector = RuleOverlapDetector()
        let rawPhotoRule = makeRule(
            name: "Raw Photo Vault",
            conditionType: .fileExtension,
            conditionValue: "CR2",
            destination: "Pictures/Raw Imports"
        )
        let envRule = makeRule(
            name: "Env Var Guard",
            conditionType: .nameStartsWith,
            conditionValue: ".env",
            destination: "Documents/Development/Secrets"
        )

        let overlaps = detector.detectOverlaps(for: rawPhotoRule, against: [envRule])

        XCTAssertTrue(overlaps.isEmpty)
    }

    func testCompoundRulesWithConflictingExtensionsDoNotOverlap() {
        let detector = RuleOverlapDetector()
        let invoicePDFs = Rule(
            name: "Invoice PDFs",
            conditions: [.fileExtension("pdf"), .nameContains("invoice")],
            logicalOperator: .and,
            actionType: .move,
            destination: .folder(bookmark: Data(), displayName: "Documents/Invoices")
        )
        let invoiceDOCX = Rule(
            name: "Invoice DOCX",
            conditions: [.fileExtension("docx"), .nameContains("invoice")],
            logicalOperator: .and,
            actionType: .move,
            destination: .folder(bookmark: Data(), displayName: "Documents/Contracts")
        )

        let overlaps = detector.detectOverlaps(for: invoicePDFs, against: [invoiceDOCX])

        XCTAssertTrue(overlaps.isEmpty)
    }

    func testExtensionRuleOverlapsMatchingFileKindRule() {
        let detector = RuleOverlapDetector()
        let pdfRule = makeRule(
            name: "PDF Parking",
            conditionType: .fileExtension,
            conditionValue: "pdf",
            destination: "Documents/PDF Archive"
        )
        let documentRule = makeRule(
            name: "Document Filing",
            conditionType: .fileKind,
            conditionValue: "document",
            destination: "Documents/General"
        )

        let overlaps = detector.detectOverlaps(for: pdfRule, against: [documentRule])

        XCTAssertEqual(overlaps.first?.overlapType, .subset)
    }

    private func makeRule(
        name: String,
        conditionType: Rule.ConditionType,
        conditionValue: String,
        destination: String
    ) -> Rule {
        Rule(
            name: name,
            conditionType: conditionType,
            conditionValue: conditionValue,
            actionType: .move,
            destination: .folder(bookmark: Data(), displayName: destination)
        )
    }
}
