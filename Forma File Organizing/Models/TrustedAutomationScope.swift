import Foundation
import SwiftData

enum TrustedAutomationScopeType: String, Codable, Sendable, CaseIterable {
    case rule
    case folder
    case category

    var displayName: String {
        switch self {
        case .rule:
            return "Rule"
        case .folder:
            return "Folder"
        case .category:
            return "Category"
        }
    }
}

enum TrustedAutomationScopeStatus: String, Codable, Sendable {
    case active
    case paused
    case revoked
}

enum TrustedAutomationScopePromotionSource: String, Codable, Sendable {
    case reviewFlow
    case manualSettings
    case suggestionSurface
}

enum TrustedAutomationScopeRecommendationSource: String, Codable, Sendable {
    case personalMemoryPattern
    case explicitRule
    case repeatedReviewAcceptance
}

enum TrustedAutomationAllowedAction: String, Codable, Sendable, CaseIterable {
    case move
    case rename
    case tag
    case notify
}

@Model
final class TrustedAutomationScope {
    @Attribute(.unique) var key: String

    var id: UUID
    private var scopeTypeRaw: String
    private(set) var scopeKey: String
    var displayName: String
    private var statusRaw: String
    private var promotionSourceRaw: String
    private var recommendationSourceRaw: String

    var acceptedEvidenceCount: Int
    var overrideEvidenceCount: Int
    var undoEvidenceCount: Int
    var confidenceSnapshot: Double
    var rationaleSummary: String
    private var allowedActionRaws: [String]

    var createdAt: Date
    var updatedAt: Date
    var lastEvidenceAt: Date
    var revokedAt: Date?

    var scopeType: TrustedAutomationScopeType {
        TrustedAutomationScopeType(rawValue: scopeTypeRaw) ?? .rule
    }

    var status: TrustedAutomationScopeStatus {
        get { TrustedAutomationScopeStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var promotionSource: TrustedAutomationScopePromotionSource {
        get { TrustedAutomationScopePromotionSource(rawValue: promotionSourceRaw) ?? .reviewFlow }
        set { promotionSourceRaw = newValue.rawValue }
    }

    var recommendationSource: TrustedAutomationScopeRecommendationSource {
        get { TrustedAutomationScopeRecommendationSource(rawValue: recommendationSourceRaw) ?? .repeatedReviewAcceptance }
        set { recommendationSourceRaw = newValue.rawValue }
    }

    var allowedActions: [TrustedAutomationAllowedAction] {
        get { allowedActionRaws.compactMap(TrustedAutomationAllowedAction.init(rawValue:)) }
        set { allowedActionRaws = newValue.map(\.rawValue) }
    }

    init(
        id: UUID = UUID(),
        scopeType: TrustedAutomationScopeType,
        scopeKey: String,
        displayName: String,
        status: TrustedAutomationScopeStatus = .active,
        promotionSource: TrustedAutomationScopePromotionSource,
        recommendationSource: TrustedAutomationScopeRecommendationSource,
        acceptedEvidenceCount: Int,
        overrideEvidenceCount: Int,
        undoEvidenceCount: Int,
        confidenceSnapshot: Double,
        rationaleSummary: String,
        allowedActions: [TrustedAutomationAllowedAction],
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        lastEvidenceAt: Date? = nil,
        revokedAt: Date? = nil
    ) {
        self.id = id
        self.scopeTypeRaw = scopeType.rawValue
        self.scopeKey = scopeKey
        self.key = Self.makeKey(scopeType: scopeType, scopeKey: scopeKey)
        self.displayName = displayName
        self.statusRaw = status.rawValue
        self.promotionSourceRaw = promotionSource.rawValue
        self.recommendationSourceRaw = recommendationSource.rawValue
        self.acceptedEvidenceCount = acceptedEvidenceCount
        self.overrideEvidenceCount = overrideEvidenceCount
        self.undoEvidenceCount = undoEvidenceCount
        self.confidenceSnapshot = confidenceSnapshot
        self.rationaleSummary = rationaleSummary
        self.allowedActionRaws = allowedActions.map(\.rawValue)
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.lastEvidenceAt = lastEvidenceAt ?? createdAt
        self.revokedAt = revokedAt
    }

    func refresh(
        displayName: String,
        promotionSource: TrustedAutomationScopePromotionSource,
        recommendationSource: TrustedAutomationScopeRecommendationSource,
        acceptedEvidenceCount: Int,
        overrideEvidenceCount: Int,
        undoEvidenceCount: Int,
        confidenceSnapshot: Double,
        rationaleSummary: String,
        allowedActions: [TrustedAutomationAllowedAction],
        refreshedAt: Date
    ) {
        self.displayName = displayName
        self.promotionSource = promotionSource
        self.recommendationSource = recommendationSource
        self.acceptedEvidenceCount = acceptedEvidenceCount
        self.overrideEvidenceCount = overrideEvidenceCount
        self.undoEvidenceCount = undoEvidenceCount
        self.confidenceSnapshot = confidenceSnapshot
        self.rationaleSummary = rationaleSummary
        self.allowedActions = allowedActions
        self.lastEvidenceAt = refreshedAt
        self.updatedAt = refreshedAt
    }

    static func makeKey(scopeType: TrustedAutomationScopeType, scopeKey: String) -> String {
        "\(scopeType.rawValue)|\(scopeKey)"
    }
}
