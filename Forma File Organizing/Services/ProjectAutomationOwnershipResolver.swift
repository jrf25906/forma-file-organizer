import Foundation

struct ProjectAutomationOwnershipResolver {
    func resolveOwner(
        projectDecision: ProjectSpaceAdmissionDecision?,
        trustedScope: TrustedAutomationScope?
    ) -> ProjectAutomationOwnerDecision {
        let activeTrustedScope = trustedScope.flatMap(activeOwner)

        // Deterministic tie-break order:
        // 1. Active rule scopes outrank every project claim.
        // 2. Existing-member project claims outrank generic folder/category scopes.
        // 3. Strong-confirmed project claims outrank only weaker generic scopes.
        // 4. Ambiguous or insufficient project claims never win automatic ownership.
        switch projectDecision {
        case let .existingMember(snapshot):
            if let activeTrustedScope, trustedScopeRank(activeTrustedScope.scopeType) > projectDecisionRank(.existingMember(snapshot)) {
                return .trustedScope(activeTrustedScope)
            }
            return .projectPolicy(snapshot)

        case let .strongConfirmed(snapshot):
            if let activeTrustedScope,
               trustedScopeRank(activeTrustedScope.scopeType) >= projectDecisionRank(.strongConfirmed(snapshot)) {
                return .trustedScope(activeTrustedScope)
            }
            return .projectPolicy(snapshot)

        case .insufficient:
            if let activeTrustedScope {
                return .trustedScope(activeTrustedScope)
            }
            return .none

        case nil:
            if let activeTrustedScope {
                return .trustedScope(activeTrustedScope)
            }
            return .none
        }
    }

    private func activeOwner(from scope: TrustedAutomationScope) -> ProjectAutomationTrustedScopeOwner? {
        guard scope.status == .active else {
            return nil
        }

        return ProjectAutomationTrustedScopeOwner(
            id: scope.id,
            scopeType: scope.scopeType,
            displayName: scope.displayName,
            status: scope.status
        )
    }

    private func trustedScopeRank(_ scopeType: TrustedAutomationScopeType) -> Int {
        switch scopeType {
        case .rule:
            return 3
        case .folder:
            return 2
        case .category:
            return 0
        }
    }

    private func projectDecisionRank(_ decision: ProjectSpaceAdmissionDecision) -> Int {
        switch decision {
        case .existingMember:
            return 2
        case .strongConfirmed:
            return 1
        case .insufficient:
            return -1
        }
    }
}
