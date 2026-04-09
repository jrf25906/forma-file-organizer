import Foundation

enum TrustedAutomationScopeHealthState: String, Sendable, Hashable {
    case healthy
    case quiet
    case needsAttention
}

struct TrustedAutomationScopeLifecycleSummary: Sendable, Hashable {
    let status: TrustedAutomationScopeStatus
    let createdAt: Date
    let updatedAt: Date
    let lastEvidenceAt: Date
    let pausedAt: Date?
    let lastRunAt: Date?
    let revokedAt: Date?
}

struct TrustedAutomationScopeHealthSummary: Sendable, Hashable {
    let state: TrustedAutomationScopeHealthState
    let messages: [String]
    let lastSuccessfulRunAt: Date?
    let lastBlockedRunAt: Date?
}

struct TrustedAutomationScopeRecentRunSummary: Identifiable, Sendable, Hashable {
    let id: UUID
    let triggerSource: TrustedAutomationScopeRunTriggerSource
    let status: TrustedAutomationScopeRunStatus
    let startedAt: Date
    let endedAt: Date?
    let matchedCount: Int
    let eligibleCount: Int
    let organizedCount: Int
    let heldCount: Int
    let failedCount: Int
    let heldBuckets: [TrustedAutomationScopeRunRecord.HeldBucket]
    let summaryText: String?
    let exampleFileNames: [String]
}

struct TrustedAutomationScopeWorkflowTemplateSummary: Sendable, Hashable {
    let id: String
    let displayName: String
    let summaryText: String
    let allowedActions: [TrustedAutomationAllowedAction]
    let assignedAt: Date?
}

struct TrustedAutomationScopeWorkflowRunSummary: Sendable, Hashable {
    let templateID: String
    let primaryStatus: WorkflowRunPrimaryStatus
    let rollbackStatus: WorkflowRunRollbackStatus
    let startedAt: Date
    let completedAt: Date?

    var isRollbackAvailable: Bool {
        (primaryStatus == .succeeded || primaryStatus == .completedWithIssues) &&
            rollbackStatus == .notRequested
    }
}

struct TrustedAutomationScopeSummary: Identifiable, Sendable, Hashable {
    let id: UUID
    let scopeType: TrustedAutomationScopeType
    let displayName: String
    let boundarySummary: String
    let allowedActions: [TrustedAutomationAllowedAction]
    let selectedWorkflowTemplate: TrustedAutomationScopeWorkflowTemplateSummary?
    let lifecycle: TrustedAutomationScopeLifecycleSummary
    let health: TrustedAutomationScopeHealthSummary
    let lastRun: TrustedAutomationScopeRecentRunSummary?

    init(
        id: UUID,
        scopeType: TrustedAutomationScopeType,
        displayName: String,
        boundarySummary: String,
        allowedActions: [TrustedAutomationAllowedAction],
        selectedWorkflowTemplate: TrustedAutomationScopeWorkflowTemplateSummary? = nil,
        lifecycle: TrustedAutomationScopeLifecycleSummary,
        health: TrustedAutomationScopeHealthSummary,
        lastRun: TrustedAutomationScopeRecentRunSummary?
    ) {
        self.id = id
        self.scopeType = scopeType
        self.displayName = displayName
        self.boundarySummary = boundarySummary
        self.allowedActions = allowedActions
        self.selectedWorkflowTemplate = selectedWorkflowTemplate
        self.lifecycle = lifecycle
        self.health = health
        self.lastRun = lastRun
    }
}

struct TrustedAutomationScopeDetail: Identifiable, Sendable, Hashable {
    let id: UUID
    let summary: TrustedAutomationScopeSummary
    let boundaryDescriptor: TrustedAutomationScopeBoundaryDescriptor?
    let promotionSource: TrustedAutomationScopePromotionSource
    let recommendationSource: TrustedAutomationScopeRecommendationSource
    let acceptedEvidenceCount: Int
    let overrideEvidenceCount: Int
    let undoEvidenceCount: Int
    let confidenceSnapshot: Double
    let rationaleSummary: String
    let selectedWorkflowTemplate: TrustedAutomationScopeWorkflowTemplateSummary?
    let latestWorkflowRun: TrustedAutomationScopeWorkflowRunSummary?
    let recentRuns: [TrustedAutomationScopeRecentRunSummary]

    init(
        id: UUID,
        summary: TrustedAutomationScopeSummary,
        boundaryDescriptor: TrustedAutomationScopeBoundaryDescriptor?,
        promotionSource: TrustedAutomationScopePromotionSource,
        recommendationSource: TrustedAutomationScopeRecommendationSource,
        acceptedEvidenceCount: Int,
        overrideEvidenceCount: Int,
        undoEvidenceCount: Int,
        confidenceSnapshot: Double,
        rationaleSummary: String,
        selectedWorkflowTemplate: TrustedAutomationScopeWorkflowTemplateSummary? = nil,
        latestWorkflowRun: TrustedAutomationScopeWorkflowRunSummary? = nil,
        recentRuns: [TrustedAutomationScopeRecentRunSummary]
    ) {
        self.id = id
        self.summary = summary
        self.boundaryDescriptor = boundaryDescriptor
        self.promotionSource = promotionSource
        self.recommendationSource = recommendationSource
        self.acceptedEvidenceCount = acceptedEvidenceCount
        self.overrideEvidenceCount = overrideEvidenceCount
        self.undoEvidenceCount = undoEvidenceCount
        self.confidenceSnapshot = confidenceSnapshot
        self.rationaleSummary = rationaleSummary
        self.selectedWorkflowTemplate = selectedWorkflowTemplate
        self.latestWorkflowRun = latestWorkflowRun
        self.recentRuns = recentRuns
    }

    var health: TrustedAutomationScopeHealthSummary {
        summary.health
    }

    var lifecycle: TrustedAutomationScopeLifecycleSummary {
        summary.lifecycle
    }
}

struct TrustedAutomationScopeSummarySection: Sendable, Hashable {
    let status: TrustedAutomationScopeStatus
    let title: String
    let summaries: [TrustedAutomationScopeSummary]
}
