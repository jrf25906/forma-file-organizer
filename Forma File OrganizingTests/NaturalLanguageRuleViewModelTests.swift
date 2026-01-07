import XCTest
@testable import Forma_File_Organizing

@MainActor
final class NaturalLanguageRuleViewModelTests: XCTestCase {

    func testCanApplyToEditorAndShouldShowPreviewForCompleteRule() {
        let vm = NaturalLanguageRuleViewModel()

        // Build a minimal complete parsed rule
        let condition = RuleCondition.fileExtension("pdf")
        let parsed = NLParsedRule(
            originalText: "Move pdf to Archive",
            clauses: [],
            timeConstraints: [],
            candidateConditions: [condition],
            primaryAction: .move,
            destinationPath: "Archive",
            logicalOperator: .single,
            overallConfidence: 0.9,
            issues: []
        )

        vm.parsedRule = parsed

        XCTAssertTrue(vm.canApplyToEditor)
        XCTAssertTrue(vm.shouldShowPreview)
    }

    func testCannotApplyWhenRuleIncomplete() {
        let vm = NaturalLanguageRuleViewModel()

        // No conditions, no destination
        let parsed = NLParsedRule(
            originalText: "Move things",
            clauses: [],
            timeConstraints: [],
            candidateConditions: [],
            primaryAction: .move,
            destinationPath: nil,
            logicalOperator: .single,
            overallConfidence: 0.7,
            issues: []
        )

        vm.parsedRule = parsed

        XCTAssertFalse(vm.canApplyToEditor)
        // Preview may still hide if there is nothing useful to show
        XCTAssertFalse(vm.shouldShowPreview)
    }
}
