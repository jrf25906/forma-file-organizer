import XCTest
@testable import Forma_File_Organizing

/// Behavior-focused tests for organization templates and generated rule semantics.
final class OrganizationTemplateTests: XCTestCase {

    private let basePath = FolderLocation.documents.displayName

    // MARK: - Shared Behavior

    func testTemplateMetadataIsPresent() {
        for template in OrganizationTemplate.allCases {
            XCTAssertFalse(template.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(template.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(template.iconName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(template.targetPersona.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(template.folderStructure.isEmpty)
        }
    }

    func testNonCustomTemplatesGenerateActionableRules() {
        for template in OrganizationTemplate.allCases where template != .custom {
            let rules = template.generateRules(baseDocumentsPath: basePath)
            XCTAssertFalse(rules.isEmpty, "\(template) should generate actionable default rules")
        }
    }

    func testCustomTemplateGeneratesNoRules() {
        let rules = OrganizationTemplate.custom.generateRules(baseDocumentsPath: basePath)
        XCTAssertTrue(rules.isEmpty)
    }

    func testMoveRulesStayWithinConfiguredBasePath() {
        for template in OrganizationTemplate.allCases where template != .custom {
            let rules = template.generateRules(baseDocumentsPath: basePath)

            for rule in rules where rule.actionType == .move {
                guard let destination = rule.destination?.displayName else {
                    XCTFail("\(template) rule '\(rule.name)' is missing a move destination")
                    continue
                }
                XCTAssertTrue(
                    destination.hasPrefix(basePath),
                    "\(template) rule '\(rule.name)' should route into configured base path"
                )
            }
        }
    }

    func testTemplateRulesHaveUniqueNamesPerTemplate() {
        for template in OrganizationTemplate.allCases where template != .custom {
            let names = template.generateRules(baseDocumentsPath: basePath).map(\.name)
            XCTAssertEqual(Set(names).count, names.count, "\(template) should not generate duplicate rule names")
        }
    }

    func testDefaultTemplateGenerationUsesCanonicalDocumentsRoot() {
        let rules = OrganizationTemplate.para.generateRules()
        XCTAssertFalse(rules.isEmpty)
        XCTAssertTrue(rules.allSatisfy { rule in
            guard rule.actionType == .move else { return true }
            return rule.destination?.displayName.hasPrefix("Documents/") == true
        })
    }

    // MARK: - Template-Specific Behavior

    func testPARATemplateRoutesAreasAndArchiveFlows() {
        let rules = OrganizationTemplate.para.generateRules(baseDocumentsPath: basePath)

        let financeRule = rules.first { $0.name == "Finance Documents" }
        XCTAssertEqual(financeRule?.destination?.displayName, "\(basePath)/Areas/Finance")

        let archiveRule = rules.first { $0.name == "Archive Old Documents" }
        XCTAssertEqual(archiveRule?.conditionType, .dateModifiedOlderThan)
        XCTAssertEqual(archiveRule?.destination?.displayName, "\(basePath)/Archive")
    }

    func testJohnnyDecimalTemplateRoutesIntoNumericBuckets() {
        let rules = OrganizationTemplate.johnnyDecimal.generateRules(baseDocumentsPath: basePath)
        XCTAssertFalse(rules.isEmpty)

        let bucketRegex = try! NSRegularExpression(pattern: #"/\d{2}-\d{2}\s"#, options: [])
        for rule in rules {
            guard let destination = rule.destination?.displayName else {
                XCTFail("Johnny Decimal rule '\(rule.name)' is missing a destination")
                continue
            }
            let range = NSRange(destination.startIndex..<destination.endIndex, in: destination)
            XCTAssertNotNil(bucketRegex.firstMatch(in: destination, options: [], range: range))
        }
    }

    func testCreativeTemplateIncludesWorkingAndDeliveredStages() {
        let rules = OrganizationTemplate.creativeProf.generateRules(baseDocumentsPath: basePath)

        XCTAssertTrue(rules.contains { $0.destination?.displayName.contains("/Projects/Active/Working Files") == true })
        XCTAssertTrue(rules.contains { $0.destination?.displayName.contains("/Projects/Delivered") == true })
        XCTAssertTrue(rules.contains { $0.conditionValue.lowercased() == "psd" })
        XCTAssertTrue(rules.contains { $0.conditionValue.lowercased() == "ai" })
    }

    func testMinimalTemplateCombinesRetentionAndCleanup() {
        let rules = OrganizationTemplate.minimal.generateRules(baseDocumentsPath: basePath)

        XCTAssertTrue(rules.contains { $0.actionType == .move })
        XCTAssertTrue(rules.contains { $0.actionType == .delete })
        XCTAssertTrue(rules.contains {
            $0.name == "Archive Old Inbox Items" && $0.destination?.displayName == "\(basePath)/Archive"
        })
    }

    func testAcademicTemplateSupportsResearchAndCitations() {
        let rules = OrganizationTemplate.academic.generateRules(baseDocumentsPath: basePath)

        XCTAssertTrue(rules.contains { $0.conditionType == .fileExtension && $0.conditionValue.lowercased() == "tex" })
        XCTAssertTrue(rules.contains { $0.conditionType == .fileExtension && $0.conditionValue.lowercased() == "bib" })
        XCTAssertTrue(rules.contains { $0.destination?.displayName.contains("/Research/Analysis") == true })
    }

    func testChronologicalTemplateUsesCurrentYearAndQuarter() {
        let rules = OrganizationTemplate.chronological.generateRules(baseDocumentsPath: basePath)
        let currentYear = Calendar.current.component(.year, from: Date())
        let quarter = (Calendar.current.component(.month, from: Date()) - 1) / 3 + 1

        XCTAssertTrue(rules.contains { $0.name.contains(String(currentYear)) })
        XCTAssertTrue(rules.contains {
            $0.destination?.displayName.contains("/\(currentYear)/Q\(quarter)") == true
        })
    }

    func testStudentTemplateRoutesAssignmentsToClassFolders() {
        let rules = OrganizationTemplate.student.generateRules(baseDocumentsPath: basePath)

        let assignmentRules = rules.filter {
            let value = $0.conditionValue.lowercased()
            return value.contains("assignment") || value.contains("homework")
        }

        XCTAssertFalse(assignmentRules.isEmpty)
        for rule in assignmentRules {
            XCTAssertTrue(rule.destination?.displayName.contains("/Classes/Current/Assignments") == true)
        }
    }

    // MARK: - Rule Validity

    func testGeneratedRulesAreValidForRuleContracts() {
        for template in OrganizationTemplate.allCases where template != .custom {
            for rule in template.generateRules(baseDocumentsPath: basePath) {
                XCTAssertFalse(rule.name.isEmpty)
                XCTAssertFalse(rule.conditionValue.isEmpty)

                if rule.actionType == .move {
                    XCTAssertNotNil(rule.destination)
                }
            }
        }
    }
}
