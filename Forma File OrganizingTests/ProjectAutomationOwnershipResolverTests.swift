import XCTest
@testable import Forma_File_Organizing

final class ProjectAutomationOwnershipResolverTests: XCTestCase {
    private let resolver = ProjectAutomationOwnershipResolver()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

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

    func testResolveOwner_MalformedStrongConfirmedClaimFailsClosed() {
        let decision = resolver.resolveOwner(
            projectDecision: .strongConfirmed(
                .init(
                    projectLabel: "Alpha",
                    existingProjectAssociation: nil,
                    alignedSignalCount: 1,
                    genericHintCount: 0,
                    conflictingProjectLabels: ["Beta"],
                    supportingSignals: [.dominantDestination]
                )
            ),
            trustedScope: nil
        )

        XCTAssertEqual(decision, ProjectAutomationOwnerDecision.none)
    }

    func testOwnerDecision_RoundTripsThroughCodableSerialization() throws {
        let decision = ProjectAutomationOwnerDecision.trustedScope(
            .init(
                id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
                scopeType: .folder,
                displayName: "Folder Scope",
                status: .active
            )
        )

        let data = try encoder.encode(decision)
        let decoded = try decoder.decode(ProjectAutomationOwnerDecision.self, from: data)

        XCTAssertEqual(decoded, decision)
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
