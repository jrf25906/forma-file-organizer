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

    func testScopedFolderResolutionIsCachedAcrossRepeatedOverlapChecks() {
        var resolveCallCount = 0
        let detector = RuleOverlapDetector(
            scopedFolderPathResolver: { folder in
                resolveCallCount += 1
                return "/Users/test/\(folder.displayName)"
            }
        )

        let desktopFolder = CategoryScope.ScopedFolder(
            bookmark: Data([0x01]),
            displayName: "Desktop"
        )
        let workCategory = RuleCategory(
            name: "Work",
            scope: .folders([desktopFolder])
        )
        let first = Rule(
            name: "Desktop PDFs",
            conditionType: .fileExtension,
            conditionValue: "pdf",
            actionType: .move,
            destination: .folder(bookmark: Data(), displayName: "Documents/Desktop PDFs"),
            category: workCategory
        )
        let second = Rule(
            name: "Desktop Documents",
            conditionType: .fileKind,
            conditionValue: "document",
            actionType: .move,
            destination: .folder(bookmark: Data(), displayName: "Documents/Desktop Documents"),
            category: workCategory
        )

        _ = detector.detectOverlaps(for: first, against: [second])
        _ = detector.detectOverlaps(for: second, against: [first])

        XCTAssertEqual(resolveCallCount, 1, "Expected one scoped-folder resolution per shared category, even across repeated overlap checks.")
    }

    func testCategoryScopeResolutionIsCachedAcrossRepeatedOverlapChecks() {
        var scopeResolutionCount = 0
        let workCategory = RuleCategory(name: "Work")
        let sharedScope = CategoryScope.folders([
            CategoryScope.ScopedFolder(
                bookmark: Data([0x02]),
                displayName: "Desktop"
            )
        ])
        let detector = RuleOverlapDetector(
            categoryScopeResolver: { category in
                scopeResolutionCount += 1
                XCTAssertEqual(category.id, workCategory.id)
                return sharedScope
            },
            scopedFolderPathResolver: { folder in
                "/Users/test/\(folder.displayName)"
            }
        )

        let first = Rule(
            name: "Desktop PDFs",
            conditionType: .fileExtension,
            conditionValue: "pdf",
            actionType: .move,
            destination: .folder(bookmark: Data(), displayName: "Documents/Desktop PDFs"),
            category: workCategory
        )
        let second = Rule(
            name: "Desktop Documents",
            conditionType: .fileKind,
            conditionValue: "document",
            actionType: .move,
            destination: .folder(bookmark: Data(), displayName: "Documents/Desktop Documents"),
            category: workCategory
        )

        _ = detector.detectOverlaps(for: first, against: [second])
        _ = detector.detectOverlaps(for: second, against: [first])

        XCTAssertEqual(scopeResolutionCount, 1, "Expected one category-scope decode per shared category, even across repeated overlap checks.")
    }

    func testBatchedOverlapDetectionMatchesPerRuleResults() {
        let detector = RuleOverlapDetector()
        let duplicateA = makeRule(
            name: "PDF Archive A",
            conditionType: .fileExtension,
            conditionValue: "pdf",
            destination: "Documents/PDF Archive"
        )
        let duplicateB = makeRule(
            name: "PDF Archive B",
            conditionType: .fileExtension,
            conditionValue: "pdf",
            destination: "Documents/PDF Archive"
        )
        let overlapA = makeRule(
            name: "Screenshot Filing",
            conditionType: .nameStartsWith,
            conditionValue: "Screenshot",
            destination: "Documents/Screenshots"
        )
        let overlapB = makeRule(
            name: "Screenshot Review",
            conditionType: .nameStartsWith,
            conditionValue: "Screenshot",
            destination: "Documents/Review"
        )
        let unrelated = makeRule(
            name: "Env Guard",
            conditionType: .nameStartsWith,
            conditionValue: ".env",
            destination: "Documents/Secrets"
        )
        let rules = [duplicateA, duplicateB, overlapA, overlapB, unrelated]

        let expected = Dictionary(uniqueKeysWithValues: rules.map { rule in
            (
                rule.id,
                overlapSnapshots(
                    detector.detectOverlaps(
                        for: rule,
                        against: rules,
                        excludeRuleID: rule.id
                    )
                )
            )
        })

        let actual = detector.detectOverlaps(in: rules).mapValues(overlapSnapshots)

        XCTAssertEqual(actual, expected)
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

    private func overlapSnapshots(_ overlaps: [RuleOverlapDetector.RuleOverlap]) -> [String] {
        overlaps.map { overlap in
            [
                overlap.existingRule.id.uuidString,
                overlapTypeName(overlap.overlapType),
                overlap.explanation,
                overlap.suggestion ?? "nil"
            ]
            .joined(separator: "|")
        }
    }

    private func overlapTypeName(_ overlapType: RuleOverlapDetector.OverlapType) -> String {
        switch overlapType {
        case .exactDuplicate:
            return "exactDuplicate"
        case .conflictingDestination:
            return "conflictingDestination"
        case .subset:
            return "subset"
        case .superset:
            return "superset"
        case .partialOverlap:
            return "partialOverlap"
        }
    }
}
