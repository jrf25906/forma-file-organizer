import XCTest
@testable import Forma_File_Organizing

@MainActor
final class NavigationViewModelTests: XCTestCase {
    func testBeginRuleDraftFromFileContextCreatesPanelSession() {
        let navigation = NavigationViewModel()
        let file = makeFile(path: "/Users/test/Downloads/invoice.pdf", location: .downloads)

        navigation.beginRuleDraft(
            fileContext: file,
            presentation: .panel,
            returnTarget: .inspector(filePath: file.path)
        )

        XCTAssertNotNil(navigation.ruleDraftSession)
        XCTAssertEqual(navigation.ruleDraftSession?.presentation, .panel)
        XCTAssertEqual(navigation.ruleDraftSession?.returnTarget, .inspector(filePath: file.path))
        XCTAssertEqual(navigation.ruleDraftSession?.source, .newFromFile)
        XCTAssertTrue(navigation.ruleDraftSession?.fileContext === file)
        XCTAssertFalse(navigation.isShowingRuleEditor)
    }

    func testBeginRuleDraftFromExistingRuleCreatesModalSession() {
        let navigation = NavigationViewModel()
        let rule = makeRule(name: "Invoices")

        navigation.beginRuleDraft(
            editingRule: rule,
            presentation: .modal,
            returnTarget: .defaultPanel
        )

        XCTAssertNotNil(navigation.ruleDraftSession)
        XCTAssertEqual(navigation.ruleDraftSession?.presentation, .modal)
        XCTAssertEqual(navigation.ruleDraftSession?.returnTarget, .defaultPanel)
        XCTAssertEqual(navigation.ruleDraftSession?.source, .editExisting)
        XCTAssertTrue(navigation.ruleDraftSession?.editingRule === rule)
        XCTAssertTrue(navigation.isShowingRuleEditor)
    }

    func testOpenRuleEditorFromFileContextCreatesModalSession() {
        let navigation = NavigationViewModel()
        let file = makeFile(path: "/Users/test/Downloads/receipt.pdf", location: .downloads)

        navigation.openRuleEditor(
            fileContext: file,
            returnTarget: .inspector(filePath: file.path)
        )

        XCTAssertEqual(navigation.ruleDraftSession?.presentation, .modal)
        XCTAssertEqual(navigation.ruleDraftSession?.returnTarget, .inspector(filePath: file.path))
        XCTAssertTrue(navigation.ruleDraftSession?.fileContext === file)
        XCTAssertTrue(navigation.isShowingRuleEditor)
    }

    func testOpenRuleBuilderPanelCreatesPanelSession() {
        let navigation = NavigationViewModel()

        navigation.openRuleBuilderPanel(returnTarget: .defaultPanel)

        XCTAssertEqual(navigation.ruleDraftSession?.presentation, .panel)
        XCTAssertEqual(navigation.ruleDraftSession?.returnTarget, .defaultPanel)
        XCTAssertEqual(navigation.ruleDraftSession?.source, .genericNew)
        XCTAssertFalse(navigation.isShowingRuleEditor)
    }

    func testPresentRuleDraftModalPreservesExistingFormState() throws {
        let navigation = NavigationViewModel()
        let file = makeFile(path: "/Users/test/Downloads/receipt.pdf", location: .downloads)

        navigation.beginRuleDraft(
            fileContext: file,
            presentation: .panel,
            returnTarget: .inspector(filePath: file.path)
        )

        var session = try XCTUnwrap(navigation.ruleDraftSession)
        session.formState.name = "Custom Draft Name"
        navigation.ruleDraftSession = session

        navigation.presentRuleDraftModal()

        XCTAssertEqual(navigation.ruleDraftSession?.presentation, .modal)
        XCTAssertEqual(navigation.ruleDraftSession?.formState.name, "Custom Draft Name")
        XCTAssertTrue(navigation.isShowingRuleEditor)
    }

    func testPresentRuleDraftPanelPreservesExistingFormState() throws {
        let navigation = NavigationViewModel()
        let rule = makeRule(name: "Invoices")

        navigation.beginRuleDraft(
            editingRule: rule,
            presentation: .modal,
            returnTarget: .defaultPanel
        )

        var session = try XCTUnwrap(navigation.ruleDraftSession)
        session.formState.name = "Panel Draft Name"
        navigation.ruleDraftSession = session

        navigation.presentRuleDraftPanel()

        XCTAssertEqual(navigation.ruleDraftSession?.presentation, .panel)
        XCTAssertEqual(navigation.ruleDraftSession?.formState.name, "Panel Draft Name")
        XCTAssertFalse(navigation.isShowingRuleEditor)
    }

    func testUpdateRuleDraftFormStateSurvivesModalPanelRoundTrip() {
        let navigation = NavigationViewModel()
        let file = makeFile(path: "/Users/test/Downloads/receipt.pdf", location: .downloads)

        navigation.openRuleEditor(
            fileContext: file,
            returnTarget: .inspector(filePath: file.path)
        )

        var updatedState = navigation.ruleDraftSession?.formState ?? RuleFormState()
        updatedState.name = "Workflow Draft"
        updatedState.conditionValue = "receipt"
        updatedState.destinationDisplayPath = "Documents/Receipts"
        navigation.updateRuleDraftFormState(updatedState)

        navigation.presentRuleDraftPanel()
        navigation.presentRuleDraftModal()

        XCTAssertEqual(navigation.ruleDraftSession?.presentation, .modal)
        XCTAssertEqual(navigation.ruleDraftSession?.formState.name, "Workflow Draft")
        XCTAssertEqual(navigation.ruleDraftSession?.formState.conditionValue, "receipt")
        XCTAssertEqual(navigation.ruleDraftSession?.formState.destinationDisplayPath, "Documents/Receipts")
    }

    func testBeginRuleDraftFromSuggestedTextClearsStaleFileContext() {
        let navigation = NavigationViewModel()
        let file = makeFile(path: "/Users/test/Downloads/receipt.pdf", location: .downloads)

        navigation.beginRuleDraft(
            fileContext: file,
            presentation: .modal,
            returnTarget: .inspector(filePath: file.path)
        )

        navigation.beginRuleDraft(
            suggestedNaturalLanguageText: "Move files older than 30 days to Archive",
            presentation: .modal,
            returnTarget: .none
        )

        XCTAssertEqual(navigation.ruleDraftSession?.source, .suggestedPrompt)
        XCTAssertEqual(
            navigation.ruleDraftSession?.suggestedNaturalLanguageText,
            "Move files older than 30 days to Archive"
        )
        XCTAssertNil(navigation.ruleDraftSession?.fileContext)
        XCTAssertNil(navigation.ruleDraftSession?.editingRule)
        XCTAssertNil(navigation.ruleEditorFileContext)
        XCTAssertNil(navigation.editingRule)
    }

    func testClearRuleDraftResetsSessionAndLegacyEditorState() {
        let navigation = NavigationViewModel()
        let file = makeFile(path: "/Users/test/Downloads/receipt.pdf", location: .downloads)

        navigation.beginRuleDraft(
            fileContext: file,
            presentation: .modal,
            returnTarget: .inspector(filePath: file.path)
        )

        navigation.clearRuleDraft()

        XCTAssertNil(navigation.ruleDraftSession)
        XCTAssertNil(navigation.ruleEditorFileContext)
        XCTAssertNil(navigation.editingRule)
        XCTAssertNil(navigation.ruleEditorSuggestedText)
        XCTAssertFalse(navigation.isShowingRuleEditor)
    }

    private func makeFile(path: String, location: FileLocationKind) -> FileItem {
        FileItem(
            path: path,
            sizeInBytes: 128,
            creationDate: Date(),
            location: location,
            scanRootPath: "/Users/test/Downloads",
            destination: FileItem.mockDestination(displayName: "Documents/Finance"),
            status: .ready
        )
    }

    private func makeRule(name: String) -> Rule {
        Rule(
            name: name,
            conditionType: .fileExtension,
            conditionValue: "pdf",
            actionType: .move,
            destination: FileItem.mockDestination(displayName: "Documents/Finance")
        )
    }
}
