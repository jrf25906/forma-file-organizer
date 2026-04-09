import XCTest
@testable import Forma_File_Organizing

final class ProjectAutomationOwnershipResolverTests: XCTestCase {
    private let resolver = ProjectAutomationOwnershipResolver()

    func testResolveOwner_ProjectPolicyExistingMemberBeatsGenericCategoryScope() {
        let scope = makeTrustedScope(type: .category, status: .active)

        let decision = resolver.resolveOwner(
            projectDecision: .existingMember(
                .init(
                    projectLabel: "Alpha",
                    existingProjectAssociation: "Alpha",
                    alignedSignalCount: 1,
                    genericHintCount: 0,
                    conflictingProjectLabels: [],
                    supportingSignals: [.existingProjectAssociation]
                )
            ),
            trustedScope: scope
        )

        guard case let .projectPolicy(snapshot) = decision else {
            return XCTFail("Expected projectPolicy, got \(decision)")
        }

        XCTAssertEqual(snapshot.projectLabel, "Alpha")
    }

    func testResolveOwner_TrustedScopeWinsWhenProjectClaimIsWeaker() {
        let scope = makeTrustedScope(type: .folder, status: .active)

        let decision = resolver.resolveOwner(
            projectDecision: .strongConfirmed(
                .init(
                    projectLabel: "Alpha",
                    existingProjectAssociation: nil,
                    alignedSignalCount: 2,
                    genericHintCount: 0,
                    conflictingProjectLabels: [],
                    supportingSignals: [.dominantDestination, .sourceFolder]
                )
            ),
            trustedScope: scope
        )

        guard case let .trustedScope(winningScope) = decision else {
            return XCTFail("Expected trustedScope, got \(decision)")
        }

        XCTAssertEqual(winningScope.id, scope.id)
    }

    func testResolveOwner_AmbiguousProjectClaimReturnsNoAutomaticOwner() {
        let decision = resolver.resolveOwner(
            projectDecision: .insufficient(
                .init(
                    projectLabel: "Alpha",
                    existingProjectAssociation: nil,
                    alignedSignalCount: 1,
                    genericHintCount: 1,
                    conflictingProjectLabels: ["Beta"],
                    supportingSignals: [.genericDestinationHint, .sourceFolder]
                )
            ),
            trustedScope: nil
        )

        XCTAssertEqual(decision, ProjectAutomationOwnerDecision.none)
    }

    private func makeTrustedScope(
        type: TrustedAutomationScopeType,
        status: TrustedAutomationScopeStatus
    ) -> TrustedAutomationScope {
        TrustedAutomationScope(
            scopeType: type,
            scopeKey: "\(type.rawValue)-scope",
            displayName: "\(type.displayName) Scope",
            status: status,
            promotionSource: .reviewFlow,
            recommendationSource: .explicitRule,
            acceptedEvidenceCount: 3,
            overrideEvidenceCount: 0,
            undoEvidenceCount: 0,
            confidenceSnapshot: 0.92,
            rationaleSummary: "Test scope",
            allowedActions: [.move]
        )
    }
}
