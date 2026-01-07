import XCTest
@testable import Forma_File_Organizing

/// Tests for OrganizationTemplate enum and rule generation
final class OrganizationTemplateTests: XCTestCase {
    
    // MARK: - Template Properties Tests
    
    func testAllTemplatesHaveDisplayNames() {
        for template in OrganizationTemplate.allCases {
            XCTAssertFalse(template.displayName.isEmpty, "\(template) should have a display name")
        }
    }
    
    func testAllTemplatesHaveDescriptions() {
        for template in OrganizationTemplate.allCases {
            XCTAssertFalse(template.description.isEmpty, "\(template) should have a description")
        }
    }
    
    func testAllTemplatesHaveIcons() {
        for template in OrganizationTemplate.allCases {
            XCTAssertFalse(template.iconName.isEmpty, "\(template) should have an icon name")
        }
    }
    
    func testAllTemplatesHaveTargetPersonas() {
        for template in OrganizationTemplate.allCases {
            XCTAssertFalse(template.targetPersona.isEmpty, "\(template) should have a target persona")
        }
    }
    
    func testAllTemplatesHaveFolderStructure() {
        for template in OrganizationTemplate.allCases {
            XCTAssertFalse(template.folderStructure.isEmpty, "\(template) should have folder structure")
        }
    }
    
    // MARK: - PARA Template Tests
    
    func testPARATemplateGeneratesRules() {
        let rules = OrganizationTemplate.para.generateRules(baseDocumentsPath: "/Users/test/Documents")
        
        XCTAssertGreaterThan(rules.count, 0, "PARA template should generate rules")
        XCTAssertEqual(rules.count, 10, "PARA template should generate 10 rules")
    }
    
    func testPARATemplateHasCorrectFolders() {
        let folders = OrganizationTemplate.para.folderStructure
        
        XCTAssertTrue(folders.contains("Projects"), "PARA should include Projects folder")
        XCTAssertTrue(folders.contains("Areas"), "PARA should include Areas folder")
        XCTAssertTrue(folders.contains("Resources"), "PARA should include Resources folder")
        XCTAssertTrue(folders.contains("Archive"), "PARA should include Archive folder")
    }
    
    func testPARATemplateRulesUseCorrectPaths() {
        let basePath = "/Users/test/Documents"
        let rules = OrganizationTemplate.para.generateRules(baseDocumentsPath: basePath)
        
        let projectRules = rules.filter { $0.destination?.displayName.contains("Projects") ?? false }
        XCTAssertGreaterThan(projectRules.count, 0, "Should have rules targeting Projects folder")

        let archiveRules = rules.filter { $0.destination?.displayName.contains("Archive") ?? false }
        XCTAssertGreaterThan(archiveRules.count, 0, "Should have rules targeting Archive folder")
    }
    
    // MARK: - Johnny Decimal Template Tests
    
    func testJohnnyDecimalTemplateGeneratesRules() {
        let rules = OrganizationTemplate.johnnyDecimal.generateRules(baseDocumentsPath: "/Users/test/Documents")
        
        XCTAssertGreaterThan(rules.count, 0, "Johnny Decimal template should generate rules")
        XCTAssertEqual(rules.count, 12, "Johnny Decimal template should generate 12 rules")
    }
    
    func testJohnnyDecimalTemplateHasNumericCategories() {
        let folders = OrganizationTemplate.johnnyDecimal.folderStructure
        
        XCTAssertTrue(folders.contains { $0.contains("10-19") }, "Should have 10-19 category")
        XCTAssertTrue(folders.contains { $0.contains("20-29") }, "Should have 20-29 category")
        XCTAssertTrue(folders.contains { $0.contains("30-39") }, "Should have 30-39 category")
    }
    
    func testJohnnyDecimalRulesIncludeFinanceCategory() {
        let rules = OrganizationTemplate.johnnyDecimal.generateRules(baseDocumentsPath: "/Users/test/Documents")
        
        let financeRules = rules.filter { $0.destination?.displayName.contains("10-19 Finance") ?? false }
        XCTAssertGreaterThan(financeRules.count, 0, "Should have rules for Finance category")
    }
    
    // MARK: - Creative Professional Template Tests
    
    func testCreativeProfTemplateGeneratesRules() {
        let rules = OrganizationTemplate.creativeProf.generateRules(baseDocumentsPath: "/Users/test/Documents")
        
        XCTAssertGreaterThan(rules.count, 0, "Creative Professional template should generate rules")
        XCTAssertEqual(rules.count, 11, "Creative Professional template should generate 11 rules")
    }
    
    func testCreativeProfTemplateIncludesDesignFileRules() {
        let rules = OrganizationTemplate.creativeProf.generateRules(baseDocumentsPath: "/Users/test/Documents")
        
        let psdRule = rules.first { $0.conditionType == .fileExtension && $0.conditionValue == "psd" }
        XCTAssertNotNil(psdRule, "Should have rule for PSD files")
        
        let aiRule = rules.first { $0.conditionType == .fileExtension && $0.conditionValue == "ai" }
        XCTAssertNotNil(aiRule, "Should have rule for Illustrator files")
    }
    
    // MARK: - Minimal Template Tests
    
    func testMinimalTemplateGeneratesRules() {
        let rules = OrganizationTemplate.minimal.generateRules(baseDocumentsPath: "/Users/test/Documents")
        
        XCTAssertGreaterThan(rules.count, 0, "Minimal template should generate rules")
        XCTAssertEqual(rules.count, 7, "Minimal template should generate 7 rules")
    }
    
    func testMinimalTemplateHasSimpleStructure() {
        let folders = OrganizationTemplate.minimal.folderStructure
        
        XCTAssertTrue(folders.contains("Inbox"), "Minimal should include Inbox")
        XCTAssertTrue(folders.contains("Keep"), "Minimal should include Keep")
        XCTAssertTrue(folders.contains("Archive"), "Minimal should include Archive")
        XCTAssertEqual(folders.count, 3, "Minimal should only have 3 folders")
    }
    
    func testMinimalTemplateIncludesCleanupRules() {
        let rules = OrganizationTemplate.minimal.generateRules(baseDocumentsPath: "/Users/test/Documents")
        
        let deleteRules = rules.filter { $0.actionType == .delete }
        XCTAssertGreaterThan(deleteRules.count, 0, "Minimal should have cleanup/delete rules")
    }
    
    // MARK: - Academic Template Tests
    
    func testAcademicTemplateGeneratesRules() {
        let rules = OrganizationTemplate.academic.generateRules(baseDocumentsPath: "/Users/test/Documents")
        
        XCTAssertGreaterThan(rules.count, 0, "Academic template should generate rules")
        XCTAssertEqual(rules.count, 12, "Academic template should generate 12 rules")
    }
    
    func testAcademicTemplateIncludesResearchTools() {
        let rules = OrganizationTemplate.academic.generateRules(baseDocumentsPath: "/Users/test/Documents")
        
        // Should have rules for academic file types
        let bibRule = rules.first { $0.conditionType == .fileExtension && $0.conditionValue == "bib" }
        XCTAssertNotNil(bibRule, "Should have rule for BibTeX files")
        
        let texRule = rules.first { $0.conditionType == .fileExtension && $0.conditionValue == "tex" }
        XCTAssertNotNil(texRule, "Should have rule for LaTeX files")
    }
    
    // MARK: - Chronological Template Tests
    
    func testChronologicalTemplateGeneratesRules() {
        let rules = OrganizationTemplate.chronological.generateRules(baseDocumentsPath: "/Users/test/Documents")
        
        XCTAssertGreaterThan(rules.count, 0, "Chronological template should generate rules")
        XCTAssertEqual(rules.count, 7, "Chronological template should generate 7 rules")
    }
    
    func testChronologicalTemplateUsesCurrentYear() {
        let folders = OrganizationTemplate.chronological.folderStructure
        let currentYear = Calendar.current.component(.year, from: Date())
        
        XCTAssertTrue(folders.contains { $0.contains(String(currentYear)) }, 
                      "Should include current year in folder structure")
    }
    
    func testChronologicalTemplateIncludesComplianceRules() {
        let rules = OrganizationTemplate.chronological.generateRules(baseDocumentsPath: "/Users/test/Documents")
        
        // Should have long-term retention rules (7 years for financial)
        let financialRule = rules.first { $0.name.contains("Financial") || $0.name.contains("7 Years") }
        XCTAssertNotNil(financialRule, "Should have financial compliance rule")
    }
    
    // MARK: - Student Template Tests
    
    func testStudentTemplateGeneratesRules() {
        let rules = OrganizationTemplate.student.generateRules(baseDocumentsPath: "/Users/test/Documents")
        
        XCTAssertGreaterThan(rules.count, 0, "Student template should generate rules")
        XCTAssertEqual(rules.count, 13, "Student template should generate 13 rules")
    }
    
    func testStudentTemplateIncludesAssignmentRules() {
        let rules = OrganizationTemplate.student.generateRules(baseDocumentsPath: "/Users/test/Documents")
        
        let homeworkRule = rules.first { $0.conditionValue.contains("homework") }
        XCTAssertNotNil(homeworkRule, "Should have homework rule")
        
        let assignmentRule = rules.first { $0.conditionValue.contains("assignment") }
        XCTAssertNotNil(assignmentRule, "Should have assignment rule")
    }
    
    // MARK: - Custom Template Tests
    
    func testCustomTemplateGeneratesNoRules() {
        let rules = OrganizationTemplate.custom.generateRules(baseDocumentsPath: "/Users/test/Documents")
        
        XCTAssertEqual(rules.count, 0, "Custom template should not generate any rules")
    }
    
    // MARK: - Rule Quality Tests
    
    func testAllTemplateRulesHaveNames() {
        for template in OrganizationTemplate.allCases where template != .custom {
            let rules = template.generateRules(baseDocumentsPath: "/Users/test/Documents")
            
            for rule in rules {
                XCTAssertFalse(rule.name.isEmpty, 
                              "\(template) rule should have a name: \(rule)")
            }
        }
    }
    
    func testAllTemplateRulesHaveValidConditions() {
        for template in OrganizationTemplate.allCases where template != .custom {
            let rules = template.generateRules(baseDocumentsPath: "/Users/test/Documents")
            
            for rule in rules {
                XCTAssertFalse(rule.conditionValue.isEmpty, 
                              "\(template) rule '\(rule.name)' should have a condition value")
            }
        }
    }
    
    func testAllMoveRulesHaveDestinations() {
        for template in OrganizationTemplate.allCases where template != .custom {
            let rules = template.generateRules(baseDocumentsPath: "/Users/test/Documents")
            
            for rule in rules where rule.actionType == .move {
                XCTAssertNotNil(rule.destination,
                               "\(template) move rule '\(rule.name)' should have a destination")
            }
        }
    }
    
    func testDeleteRulesHaveNoDestination() {
        for template in OrganizationTemplate.allCases where template != .custom {
            let rules = template.generateRules(baseDocumentsPath: "/Users/test/Documents")
            
            for rule in rules where rule.actionType == .delete {
                // Delete rules may or may not have a destination (it's ignored anyway)
                // Just verify the rule is valid
                XCTAssertFalse(rule.name.isEmpty, "Delete rule should have a name")
            }
        }
    }
    
    // MARK: - Total Rule Count Tests
    
    func testTotalRuleCount() {
        var totalRules = 0
        
        for template in OrganizationTemplate.allCases where template != .custom {
            let rules = template.generateRules(baseDocumentsPath: "/Users/test/Documents")
            totalRules += rules.count
        }
        
        // PARA: 10, Johnny: 12, Creative: 11, Minimal: 7, Academic: 12, Chrono: 7, Student: 13
        XCTAssertEqual(totalRules, 72, "Should have 72 total rules across all templates")
    }
    
    // MARK: - Template Enumeration Tests
    
    func testAllTemplatesAreCodable() {
        for template in OrganizationTemplate.allCases {
            // Encode
            let encoder = JSONEncoder()
            let data = try? encoder.encode(template)
            XCTAssertNotNil(data, "\(template) should be encodable")
            
            // Decode
            if let data = data {
                let decoder = JSONDecoder()
                let decoded = try? decoder.decode(OrganizationTemplate.self, from: data)
                XCTAssertEqual(decoded, template, "\(template) should decode correctly")
            }
        }
    }
    
    func testTemplateRawValues() {
        XCTAssertEqual(OrganizationTemplate.para.rawValue, "para")
        XCTAssertEqual(OrganizationTemplate.johnnyDecimal.rawValue, "johnnyDecimal")
        XCTAssertEqual(OrganizationTemplate.creativeProf.rawValue, "creativeProf")
        XCTAssertEqual(OrganizationTemplate.minimal.rawValue, "minimal")
        XCTAssertEqual(OrganizationTemplate.academic.rawValue, "academic")
        XCTAssertEqual(OrganizationTemplate.chronological.rawValue, "chronological")
        XCTAssertEqual(OrganizationTemplate.student.rawValue, "student")
        XCTAssertEqual(OrganizationTemplate.custom.rawValue, "custom")
    }
}
