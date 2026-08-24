import XCTest
@testable import Forma_File_Organizing

final class ImpactMetricCardTests: XCTestCase {
    func testOrganizationScoreZeroUsesGettingStartedCopy() {
        let card = ImpactMetricCard.organizationScore(0)

        XCTAssertEqual(card.subtitle, "Getting Started")
    }

    func testOrganizationScoreLowButNonzeroAvoidsPunitiveNeedsWorkCopy() {
        let card = ImpactMetricCard.organizationScore(45)

        XCTAssertEqual(card.subtitle, "Needs Attention")
    }
}
