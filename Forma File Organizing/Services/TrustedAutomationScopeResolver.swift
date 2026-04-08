import Foundation
import SwiftData

@MainActor
final class TrustedAutomationScopeResolver {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func resolveMatch(
        for file: FileItem,
        destination: Destination?
    ) throws -> TrustedAutomationScope? {
        try resolveMatch(
            for: file,
            destination: destination,
            within: activeScopes()
        )
    }

    func resolveMatch(
        for file: FileItem,
        destination: Destination?,
        within scopes: [TrustedAutomationScope]
    ) throws -> TrustedAutomationScope? {
        scopes
            .compactMap { scope -> (scope: TrustedAutomationScope, boundary: TrustedAutomationScopeBoundaryDescriptor)? in
                guard let boundary = scope.boundaryDescriptor,
                      boundary.matches(candidate: file, destination: destination) else {
                    return nil
                }

                return (scope, boundary)
            }
            .sorted { lhs, rhs in
                let lhsPriority = scopePriority(lhs.scope.scopeType)
                let rhsPriority = scopePriority(rhs.scope.scopeType)
                if lhsPriority != rhsPriority {
                    return lhsPriority < rhsPriority
                }

                if lhs.boundary.matchingSpecificityScore != rhs.boundary.matchingSpecificityScore {
                    return lhs.boundary.matchingSpecificityScore > rhs.boundary.matchingSpecificityScore
                }

                if lhs.scope.updatedAt != rhs.scope.updatedAt {
                    return lhs.scope.updatedAt > rhs.scope.updatedAt
                }

                return lhs.scope.createdAt < rhs.scope.createdAt
            }
            .first?
            .scope
    }

    func activeScopes() throws -> [TrustedAutomationScope] {
        try modelContext.fetch(
            FetchDescriptor<TrustedAutomationScope>(
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
        ).filter { $0.status == .active }
    }

    private func scopePriority(_ scopeType: TrustedAutomationScopeType) -> Int {
        switch scopeType {
        case .rule:
            return 0
        case .folder:
            return 1
        case .category:
            return 2
        }
    }
}
