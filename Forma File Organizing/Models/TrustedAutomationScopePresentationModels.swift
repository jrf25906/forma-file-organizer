import Foundation

enum TrustedAutomationScopeHealthState: String, Sendable, Hashable {
    case healthy
    case quiet
    case needsAttention
}

enum TrustedAutomationScopeWorkflowMemoryState: String, Sendable, Hashable {
    case stable
    case stale
    case conflicted
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

struct TrustedAutomationScopeWorkflowMemorySummary: Sendable, Hashable {
    let state: TrustedAutomationScopeWorkflowMemoryState
    let templateID: String
    let templateDisplayName: String
    let successfulRunCount: Int
    let lastSuccessfulRunAt: Date
    let lastAttentionRunAt: Date?
    let summaryText: String
}

extension TrustedAutomationScopeWorkflowMemorySummary {
    static func derive(
        selectedTemplateID: String?,
        templateAssignedAt: Date? = nil,
        recentRuns: [TrustedAutomationScopeRunRecord],
        latestWorkflowRun: TrustedAutomationScopeWorkflowRunSummary?,
        referenceDate: Date = Date()
    ) -> TrustedAutomationScopeWorkflowMemorySummary? {
        let normalizedSelectedTemplateID = normalizeTemplateID(selectedTemplateID)
        let selectedTemplateIsAvailable = normalizedSelectedTemplateID.flatMap {
            WorkflowTemplateCatalog.template(for: $0)
        } != nil
        let scopedRecentRuns = recentRuns.filter { record in
            guard selectedTemplateIsAvailable,
                  let templateAssignedAt else {
                return true
            }

            guard let recordedAt = recordedAt(record) else {
                return false
            }

            return recordedAt >= templateAssignedAt
        }
        let scopedLatestWorkflowRun: TrustedAutomationScopeWorkflowRunSummary?
        if selectedTemplateIsAvailable,
           let normalizedSelectedTemplateID {
            let normalizedWorkflowTemplateID = normalizeTemplateID(latestWorkflowRun?.templateID)
            scopedLatestWorkflowRun = normalizedWorkflowTemplateID == normalizedSelectedTemplateID
                ? latestWorkflowRun
                : nil
        } else {
            scopedLatestWorkflowRun = latestWorkflowRun
        }

        let latestSuccessfulRecordAt = scopedRecentRuns
            .filter(Self.isSuccessfulRun)
            .compactMap(Self.recordedAt)
            .max()
        let latestAttentionRecordAt = scopedRecentRuns
            .filter(Self.isAttentionWorthyRun)
            .compactMap(Self.recordedAt)
            .max()
        let successfulRunCount = scopedRecentRuns.filter(Self.isSuccessfulRun).count

        let latestWorkflowSuccessAt: Date?
        if let scopedLatestWorkflowRun, Self.isSuccessfulWorkflowRun(scopedLatestWorkflowRun) {
            latestWorkflowSuccessAt = scopedLatestWorkflowRun.completedAt ?? scopedLatestWorkflowRun.startedAt
        } else {
            latestWorkflowSuccessAt = nil
        }
        let latestWorkflowAttentionAt: Date?
        if let scopedLatestWorkflowRun, Self.isAttentionWorthyWorkflowRun(scopedLatestWorkflowRun) {
            latestWorkflowAttentionAt = scopedLatestWorkflowRun.completedAt ?? scopedLatestWorkflowRun.startedAt
        } else {
            latestWorkflowAttentionAt = nil
        }

        let lastSuccessfulRunAt = [latestSuccessfulRecordAt, latestWorkflowSuccessAt].compactMap { $0 }.max()
        let lastAttentionRunAt = [latestAttentionRecordAt, latestWorkflowAttentionAt].compactMap { $0 }.max()
        let resolvedSuccessfulRunCount: Int
        if let latestWorkflowSuccessAt,
           latestWorkflowSuccessAt > (latestSuccessfulRecordAt ?? .distantPast) {
            resolvedSuccessfulRunCount = max(successfulRunCount + 1, 1)
        } else {
            resolvedSuccessfulRunCount = successfulRunCount
        }

        guard resolvedSuccessfulRunCount > 0,
              let lastSuccessfulRunAt else {
            return nil
        }

        let resolvedTemplateID = resolveTemplateID(
            selectedTemplateID: selectedTemplateID,
            latestWorkflowRun: scopedLatestWorkflowRun
        )
        guard let resolvedTemplateID else {
            return nil
        }

        let templateDisplayName = WorkflowTemplateCatalog.template(for: resolvedTemplateID)?.displayName
            ?? "Unavailable template"
        let state = deriveState(
            lastSuccessfulRunAt: lastSuccessfulRunAt,
            lastAttentionRunAt: lastAttentionRunAt,
            referenceDate: referenceDate
        )

        return TrustedAutomationScopeWorkflowMemorySummary(
            state: state,
            templateID: resolvedTemplateID,
            templateDisplayName: templateDisplayName,
            successfulRunCount: resolvedSuccessfulRunCount,
            lastSuccessfulRunAt: lastSuccessfulRunAt,
            lastAttentionRunAt: lastAttentionRunAt,
            summaryText: summaryText(
                state: state,
                templateDisplayName: templateDisplayName,
                lastSuccessfulRunAt: lastSuccessfulRunAt,
                successfulRunCount: resolvedSuccessfulRunCount,
                lastAttentionRunAt: lastAttentionRunAt,
                referenceDate: referenceDate
            )
        )
    }

    var badgeText: String {
        switch state {
        case .stable:
            return "Stable"
        case .stale:
            return "Stale"
        case .conflicted:
            return "Conflicted"
        }
    }

    private static let staleWindow: TimeInterval = 30 * 24 * 60 * 60

    private static func resolveTemplateID(
        selectedTemplateID: String?,
        latestWorkflowRun: TrustedAutomationScopeWorkflowRunSummary?
    ) -> String? {
        let normalizedSelectedTemplateID = normalizeTemplateID(selectedTemplateID)
        let normalizedLatestWorkflowTemplateID = normalizeTemplateID(latestWorkflowRun?.templateID)

        if let normalizedSelectedTemplateID,
           WorkflowTemplateCatalog.template(for: normalizedSelectedTemplateID) != nil {
            return normalizedSelectedTemplateID
        }

        return normalizedLatestWorkflowTemplateID ?? normalizedSelectedTemplateID
    }

    private static func normalizeTemplateID(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func deriveState(
        lastSuccessfulRunAt: Date,
        lastAttentionRunAt: Date?,
        referenceDate: Date
    ) -> TrustedAutomationScopeWorkflowMemoryState {
        if let lastAttentionRunAt, lastAttentionRunAt > lastSuccessfulRunAt {
            return .conflicted
        }

        if referenceDate.timeIntervalSince(lastSuccessfulRunAt) > staleWindow {
            return .stale
        }

        return .stable
    }

    private static func isSuccessfulRun(_ record: TrustedAutomationScopeRunRecord) -> Bool {
        record.status == .executed
    }

    private static func isAttentionWorthyRun(_ record: TrustedAutomationScopeRunRecord) -> Bool {
        record.status == .held ||
        record.status == .failed ||
        record.heldCount > 0 ||
        record.failedCount > 0
    }

    private static func isSuccessfulWorkflowRun(_ run: TrustedAutomationScopeWorkflowRunSummary) -> Bool {
        run.primaryStatus == .succeeded
    }

    private static func isAttentionWorthyWorkflowRun(_ run: TrustedAutomationScopeWorkflowRunSummary) -> Bool {
        run.primaryStatus == .completedWithIssues ||
        run.primaryStatus == .failed ||
        run.primaryStatus == .canceled
    }

    private static func recordedAt(_ record: TrustedAutomationScopeRunRecord) -> Date? {
        record.endedAt ?? record.startedAt
    }

    private static func summaryText(
        state: TrustedAutomationScopeWorkflowMemoryState,
        templateDisplayName: String,
        lastSuccessfulRunAt: Date,
        successfulRunCount: Int,
        lastAttentionRunAt: Date?,
        referenceDate: Date
    ) -> String {
        let recencyText = relativeTimeText(for: lastSuccessfulRunAt, relativeTo: referenceDate)
        let runText = successfulRunCount == 1
            ? "1 successful template-backed run"
            : "\(successfulRunCount) successful template-backed runs"

        switch state {
        case .stable:
            return "Workflow memory is stable: \(templateDisplayName) has \(runText), most recently \(recencyText)."
        case .stale:
            return "Workflow memory is stale: \(templateDisplayName) has \(runText), but the last success was \(recencyText)."
        case .conflicted:
            let attentionText = lastAttentionRunAt.map {
                relativeTimeText(for: $0, relativeTo: referenceDate)
            } ?? "recently"
            return "Workflow memory is conflicted: \(templateDisplayName) has \(runText), but a later run needed attention \(attentionText)."
        }
    }

    private static func relativeTimeText(for date: Date, relativeTo now: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: now)
    }
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
    let workflowMemory: TrustedAutomationScopeWorkflowMemorySummary?
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
        workflowMemory: TrustedAutomationScopeWorkflowMemorySummary? = nil,
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
        self.workflowMemory = workflowMemory
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

    var workflowMemory: TrustedAutomationScopeWorkflowMemorySummary? {
        summary.workflowMemory
    }
}

struct TrustedAutomationScopeSummarySection: Sendable, Hashable {
    let status: TrustedAutomationScopeStatus
    let title: String
    let summaries: [TrustedAutomationScopeSummary]
}
