import XCTest
@testable import Forma_File_Organizing

final class ProjectSpaceAdmissionResolverTests: XCTestCase {
    private let resolver = ProjectSpaceAdmissionResolver()

    func testResolveAdmission_ReturnsExistingMemberForMatchingProjectAssociation() {
        let decision = resolver.resolveAdmission(
            projectLabel: "Alpha",
            evidence: ProjectSpaceAdmissionEvidence(
                existingProjectAssociation: "Alpha",
                dominantDestinationProjectLabel: "Alpha",
                dominantDestinationIsGenericHint: false,
                sourceFolderProjectLabel: nil,
                relatedFileProjectLabel: nil
            )
        )

        guard case let .existingMember(snapshot) = decision else {
            return XCTFail("Expected existingMember, got \(decision)")
        }

        XCTAssertEqual(snapshot.projectLabel, "Alpha")
        XCTAssertEqual(snapshot.existingProjectAssociation, "Alpha")
        XCTAssertEqual(snapshot.alignedSignalCount, 1)
        XCTAssertTrue(snapshot.conflictingProjectLabels.isEmpty)
    }

    func testResolveAdmission_ReturnsStrongConfirmedForAlignedDominantSignals() {
        let decision = resolver.resolveAdmission(
            projectLabel: "Alpha",
            evidence: ProjectSpaceAdmissionEvidence(
                existingProjectAssociation: nil,
                dominantDestinationProjectLabel: "Alpha",
                dominantDestinationIsGenericHint: false,
                sourceFolderProjectLabel: "Alpha",
                relatedFileProjectLabel: nil
            )
        )

        guard case let .strongConfirmed(snapshot) = decision else {
            return XCTFail("Expected strongConfirmed, got \(decision)")
        }

        XCTAssertEqual(snapshot.projectLabel, "Alpha")
        XCTAssertEqual(snapshot.alignedSignalCount, 2)
        XCTAssertEqual(snapshot.genericHintCount, 0)
        XCTAssertTrue(snapshot.conflictingProjectLabels.isEmpty)
    }

    func testResolveAdmission_ReturnsInsufficientForConflictingSignals() {
        let decision = resolver.resolveAdmission(
            projectLabel: "Alpha",
            evidence: ProjectSpaceAdmissionEvidence(
                existingProjectAssociation: nil,
                dominantDestinationProjectLabel: "Alpha",
                dominantDestinationIsGenericHint: true,
                sourceFolderProjectLabel: "Alpha",
                relatedFileProjectLabel: "Beta"
            )
        )

        guard case let .insufficient(snapshot) = decision else {
            return XCTFail("Expected insufficient, got \(decision)")
        }

        XCTAssertEqual(snapshot.projectLabel, "Alpha")
        XCTAssertEqual(snapshot.alignedSignalCount, 1)
        XCTAssertEqual(snapshot.genericHintCount, 1)
        XCTAssertEqual(snapshot.conflictingProjectLabels, ["Beta"])
    }
}
