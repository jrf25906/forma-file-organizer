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
        try activeScopes()
            .sorted { lhs, rhs in
                if scopePriority(lhs.scopeType) == scopePriority(rhs.scopeType) {
                    return lhs.createdAt < rhs.createdAt
                }
                return scopePriority(lhs.scopeType) < scopePriority(rhs.scopeType)
            }
            .first { scope in
                guard let boundaryDescriptor = scope.boundaryDescriptor else {
                    return false
                }

                return boundaryDescriptor.matches(candidate: file, destination: destination)
            }
    }

    private func activeScopes() throws -> [TrustedAutomationScope] {
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
