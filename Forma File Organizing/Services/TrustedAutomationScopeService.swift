import Foundation
import SwiftData

@MainActor
final class TrustedAutomationScopeService {
    enum ServiceError: LocalizedError {
        case scopeNotFound(UUID)

        var errorDescription: String? {
            switch self {
            case .scopeNotFound(let id):
                return "Trusted automation scope \(id.uuidString) was not found."
            }
        }
    }

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    @discardableResult
    func createOrReactivateScope(
        scopeType: TrustedAutomationScopeType,
        scopeKey: String,
        displayName: String,
        promotionSource: TrustedAutomationScopePromotionSource,
        recommendationSource: TrustedAutomationScopeRecommendationSource,
        acceptedEvidenceCount: Int,
        overrideEvidenceCount: Int,
        undoEvidenceCount: Int,
        confidenceSnapshot: Double,
        rationaleSummary: String,
        allowedActions: [TrustedAutomationAllowedAction],
        refreshedAt: Date = Date()
    ) throws -> TrustedAutomationScope {
        if let existing = try scope(scopeType: scopeType, scopeKey: scopeKey) {
            existing.status = .active
            existing.revokedAt = nil
            existing.refresh(
                displayName: displayName,
                promotionSource: promotionSource,
                recommendationSource: recommendationSource,
                acceptedEvidenceCount: acceptedEvidenceCount,
                overrideEvidenceCount: overrideEvidenceCount,
                undoEvidenceCount: undoEvidenceCount,
                confidenceSnapshot: confidenceSnapshot,
                rationaleSummary: rationaleSummary,
                allowedActions: allowedActions,
                refreshedAt: refreshedAt
            )
            try modelContext.save()
            return existing
        }

        let scope = TrustedAutomationScope(
            scopeType: scopeType,
            scopeKey: scopeKey,
            displayName: displayName,
            promotionSource: promotionSource,
            recommendationSource: recommendationSource,
            acceptedEvidenceCount: acceptedEvidenceCount,
            overrideEvidenceCount: overrideEvidenceCount,
            undoEvidenceCount: undoEvidenceCount,
            confidenceSnapshot: confidenceSnapshot,
            rationaleSummary: rationaleSummary,
            allowedActions: allowedActions,
            createdAt: refreshedAt
        )
        modelContext.insert(scope)
        try modelContext.save()
        return scope
    }

    func pauseScope(id: UUID, at timestamp: Date = Date()) throws {
        let scope = try requireScope(id: id)
        scope.status = .paused
        scope.updatedAt = timestamp
        try modelContext.save()
    }

    func resumeScope(id: UUID, at timestamp: Date = Date()) throws {
        let scope = try requireScope(id: id)
        scope.status = .active
        scope.revokedAt = nil
        scope.updatedAt = timestamp
        try modelContext.save()
    }

    func removeScope(id: UUID, at timestamp: Date = Date()) throws {
        let scope = try requireScope(id: id)
        scope.status = .revoked
        scope.revokedAt = timestamp
        scope.updatedAt = timestamp
        try modelContext.save()
    }

    func activeScopes() throws -> [TrustedAutomationScope] {
        try allScopes().filter { $0.status == .active }
    }

    func pausedScopes() throws -> [TrustedAutomationScope] {
        try allScopes().filter { $0.status == .paused }
    }

    private func allScopes() throws -> [TrustedAutomationScope] {
        let descriptor = FetchDescriptor<TrustedAutomationScope>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func scope(
        scopeType: TrustedAutomationScopeType,
        scopeKey: String
    ) throws -> TrustedAutomationScope? {
        let lookupKey = TrustedAutomationScope.makeKey(scopeType: scopeType, scopeKey: scopeKey)
        return try allScopes().first { $0.key == lookupKey }
    }

    private func requireScope(id: UUID) throws -> TrustedAutomationScope {
        if let scope = try allScopes().first(where: { $0.id == id }) {
            return scope
        }
        throw ServiceError.scopeNotFound(id)
    }
}
