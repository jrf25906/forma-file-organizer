import XCTest
@testable import Forma_File_Organizing

/// Tests for OrganizationPersonality model and preference application.
final class OrganizationPersonalityTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Clear any existing personality data
        OrganizationPersonality.clear()
    }
    
    override func tearDown() {
        // Clean up after each test
        OrganizationPersonality.clear()
        super.tearDown()
    }
    
    // MARK: - Model Tests
    
    func testPersonalityInitialization() {
        let personality = OrganizationPersonality(
            organizationStyle: .piler,
            thinkingStyle: .visual,
            mentalModel: .projectBased
        )
        
        XCTAssertEqual(personality.organizationStyle, .piler)
        XCTAssertEqual(personality.thinkingStyle, .visual)
        XCTAssertEqual(personality.mentalModel, .projectBased)
    }
    
    func testDefaultPersonality() {
        let defaultPersonality = OrganizationPersonality.default
        
        XCTAssertEqual(defaultPersonality.organizationStyle, .filer)
        XCTAssertEqual(defaultPersonality.thinkingStyle, .visual)
        XCTAssertEqual(defaultPersonality.mentalModel, .projectBased)
    }
    
    func testCreativePersonality() {
        let creative = OrganizationPersonality.creative
        
        XCTAssertEqual(creative.organizationStyle, .piler)
        XCTAssertEqual(creative.thinkingStyle, .visual)
        XCTAssertEqual(creative.mentalModel, .projectBased)
    }
    
    func testAcademicPersonality() {
        let academic = OrganizationPersonality.academic
        
        XCTAssertEqual(academic.organizationStyle, .filer)
        XCTAssertEqual(academic.thinkingStyle, .hierarchical)
        XCTAssertEqual(academic.mentalModel, .topicBased)
    }
    
    func testBusinessPersonality() {
        let business = OrganizationPersonality.business
        
        XCTAssertEqual(business.organizationStyle, .filer)
        XCTAssertEqual(business.thinkingStyle, .hierarchical)
        XCTAssertEqual(business.mentalModel, .timeBased)
    }
    
    // MARK: - Template Recommendations
    
    func testPilerRecommendation() {
        let piler = OrganizationPersonality(
            organizationStyle: .piler,
            thinkingStyle: .visual,
            mentalModel: .projectBased
        )
        
        XCTAssertEqual(piler.suggestedTemplate, .minimal)
    }
    
    func testFilerProjectBasedRecommendation() {
        let filer = OrganizationPersonality(
            organizationStyle: .filer,
            thinkingStyle: .visual,
            mentalModel: .projectBased
        )
        
        XCTAssertEqual(filer.suggestedTemplate, .creativeProf)
    }
    
    func testFilerTimeBasedRecommendation() {
        let filer = OrganizationPersonality(
            organizationStyle: .filer,
            thinkingStyle: .hierarchical,
            mentalModel: .timeBased
        )
        
        XCTAssertEqual(filer.suggestedTemplate, .chronological)
    }
    
    func testFilerTopicBasedHierarchicalRecommendation() {
        let filer = OrganizationPersonality(
            organizationStyle: .filer,
            thinkingStyle: .hierarchical,
            mentalModel: .topicBased
        )
        
        XCTAssertEqual(filer.suggestedTemplate, .johnnyDecimal)
    }
    
    func testFilerTopicBasedVisualRecommendation() {
        let filer = OrganizationPersonality(
            organizationStyle: .filer,
            thinkingStyle: .visual,
            mentalModel: .topicBased
        )
        
        // Should default to PARA when no specific match
        XCTAssertEqual(filer.suggestedTemplate, .para)
    }
    
    // MARK: - Persistence Tests
    
    func testSaveAndLoad() {
        let original = OrganizationPersonality(
            organizationStyle: .piler,
            thinkingStyle: .hierarchical,
            mentalModel: .timeBased
        )
        
        original.save()
        
        let loaded = OrganizationPersonality.load()
        
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.organizationStyle, original.organizationStyle)
        XCTAssertEqual(loaded?.thinkingStyle, original.thinkingStyle)
        XCTAssertEqual(loaded?.mentalModel, original.mentalModel)
    }
    
    func testLoadWithoutSaving() {
        let loaded = OrganizationPersonality.load()
        XCTAssertNil(loaded)
    }
    
    func testClear() {
        let personality = OrganizationPersonality.default
        personality.save()
        
        XCTAssertNotNil(OrganizationPersonality.load())
        
        OrganizationPersonality.clear()
        
        XCTAssertNil(OrganizationPersonality.load())
    }
    
    func testOverwriteSave() {
        let first = OrganizationPersonality(
            organizationStyle: .piler,
            thinkingStyle: .visual,
            mentalModel: .projectBased
        )
        first.save()
        
        let second = OrganizationPersonality(
            organizationStyle: .filer,
            thinkingStyle: .hierarchical,
            mentalModel: .topicBased
        )
        second.save()
        
        let loaded = OrganizationPersonality.load()
        
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.organizationStyle, .filer)
        XCTAssertEqual(loaded?.thinkingStyle, .hierarchical)
        XCTAssertEqual(loaded?.mentalModel, .topicBased)
    }
    
    // MARK: - Quiz Answer Mapping Tests
    
    func testQuizAnswerMapping_VisualOrganizer() {
        // Q1: Answer 0 (Scan Desktop visually)
        // Q2: Answer 0 (Covered with files)
        // Q3: Answer 0 (Projects and clients)
        
        let organizationStyle: OrganizationPersonality.OrganizationStyle = .piler
        let thinkingStyle: OrganizationPersonality.ThinkingStyle = .visual
        let mentalModel: OrganizationPersonality.MentalModel = .projectBased
        
        let personality = OrganizationPersonality(
            organizationStyle: organizationStyle,
            thinkingStyle: thinkingStyle,
            mentalModel: mentalModel
        )
        
        XCTAssertEqual(personality.suggestedTemplate, .minimal)
    }
    
    func testQuizAnswerMapping_SystematicOrganizer() {
        // Q1: Answer 2 (Navigate through folders)
        // Q2: Answer 2 (Empty/organized)
        // Q3: Answer 2 (Categories and topics)
        
        let organizationStyle: OrganizationPersonality.OrganizationStyle = .filer
        let thinkingStyle: OrganizationPersonality.ThinkingStyle = .hierarchical
        let mentalModel: OrganizationPersonality.MentalModel = .topicBased
        
        let personality = OrganizationPersonality(
            organizationStyle: organizationStyle,
            thinkingStyle: thinkingStyle,
            mentalModel: mentalModel
        )
        
        XCTAssertEqual(personality.suggestedTemplate, .johnnyDecimal)
    }
    
    func testQuizAnswerMapping_StructuredOrganizer() {
        // Q1: Answer 1 (Check Recent Files)
        // Q2: Answer 2 (Empty/organized)
        // Q3: Answer 1 (Weeks, months, quarters)
        
        let organizationStyle: OrganizationPersonality.OrganizationStyle = .filer
        let thinkingStyle: OrganizationPersonality.ThinkingStyle = .visual
        let mentalModel: OrganizationPersonality.MentalModel = .timeBased
        
        let personality = OrganizationPersonality(
            organizationStyle: organizationStyle,
            thinkingStyle: thinkingStyle,
            mentalModel: mentalModel
        )
        
        XCTAssertEqual(personality.suggestedTemplate, .chronological)
    }
    
    // MARK: - Edge Cases
    
    func testCodableRoundtrip() throws {
        let original = OrganizationPersonality(
            organizationStyle: .filer,
            thinkingStyle: .hierarchical,
            mentalModel: .projectBased
        )
        
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(OrganizationPersonality.self, from: encoded)
        
        XCTAssertEqual(decoded.organizationStyle, original.organizationStyle)
        XCTAssertEqual(decoded.thinkingStyle, original.thinkingStyle)
        XCTAssertEqual(decoded.mentalModel, original.mentalModel)
    }
}
