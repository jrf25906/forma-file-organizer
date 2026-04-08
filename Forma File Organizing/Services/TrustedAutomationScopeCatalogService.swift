import Foundation
import SwiftData

@MainActor
final class TrustedAutomationScopeCatalogService {
    private let modelContext: ModelContext
    private let ruleHealthService: RuleHealthService
    private let quietWindow: TimeInterval
    private let recentRunLimit: Int

    init(
        modelContext: ModelContext,
        ruleHealthService: RuleHealthService = RuleHealthService(),
        quietWindow: TimeInterval = 14 * 86_400,
        recentRunLimit: Int = 5
    ) {
        self.modelContext = modelContext
        self.ruleHealthService = ruleHealthService
        self.quietWindow = quietWindow
        self.recentRunLimit = recentRunLimit
    }

    func buildSummarySections(referenceDate: Date = Date()) throws -> [TrustedAutomationScopeSummarySection] {
        let scopes = try fetchScopes()
        let recordsByScopeID = try fetchRunRecordsByScopeID()
        let rulesByID = try fetchRulesByID()
        let healthByRuleID = ruleHealthService.classify(rules: Array(rulesByID.values))

        return TrustedAutomationScopeStatus.allCases.compactMap { status in
            let summaries = scopes
                .filter { $0.status == status }
                .map {
                    makeSummary(
                        scope: $0,
                        recentRecords: recordsByScopeID[$0.id] ?? [],
                        rulesByID: rulesByID,
                        healthByRuleID: healthByRuleID,
                        referenceDate: referenceDate
                    )
                }

            guard !summaries.isEmpty else {
                return nil
            }

            return TrustedAutomationScopeSummarySection(
                status: status,
                title: sectionTitle(for: status),
                summaries: summaries
            )
        }
    }

    func buildDetail(for scopeID: UUID, referenceDate: Date = Date()) throws -> TrustedAutomationScopeDetail? {
        let scopes = try fetchScopes()
        guard let scope = scopes.first(where: { $0.id == scopeID }) else {
            return nil
        }

        let records = try fetchRunRecordsByScopeID()[scope.id] ?? []
        let rulesByID = try fetchRulesByID()
        let healthByRuleID = ruleHealthService.classify(rules: Array(rulesByID.values))
        let summary = makeSummary(
            scope: scope,
            recentRecords: records,
            rulesByID: rulesByID,
            healthByRuleID: healthByRuleID,
            referenceDate: referenceDate
        )

        return TrustedAutomationScopeDetail(
            id: scope.id,
            summary: summary,
            boundaryDescriptor: scope.boundaryDescriptor,
            promotionSource: scope.promotionSource,
            recommendationSource: scope.recommendationSource,
            acceptedEvidenceCount: scope.acceptedEvidenceCount,
            overrideEvidenceCount: scope.overrideEvidenceCount,
            undoEvidenceCount: scope.undoEvidenceCount,
            confidenceSnapshot: scope.confidenceSnapshot,
            rationaleSummary: scope.rationaleSummary,
            selectedWorkflowTemplate: summary.selectedWorkflowTemplate,
            recentRuns: records.prefix(recentRunLimit).map(makeRecentRunSummary)
        )
    }

    private func fetchScopes() throws -> [TrustedAutomationScope] {
        try modelContext.fetch(
            FetchDescriptor<TrustedAutomationScope>(
                sortBy: [
                    SortDescriptor(\.createdAt, order: .forward),
                    SortDescriptor(\.displayName, order: .forward)
                ]
            )
        )
    }

    private func fetchRunRecordsByScopeID() throws -> [UUID: [TrustedAutomationScopeRunRecord]] {
        let records = try modelContext.fetch(
            FetchDescriptor<TrustedAutomationScopeRunRecord>(
                sortBy: [
                    SortDescriptor(\.endedAt, order: .reverse),
                    SortDescriptor(\.startedAt, order: .reverse)
                ]
            )
        )

        return Dictionary(grouping: records, by: \.scopeID)
    }

    private func fetchRulesByID() throws -> [UUID: Rule] {
        let rules = try modelContext.fetch(FetchDescriptor<Rule>())
        return Dictionary(uniqueKeysWithValues: rules.map { ($0.id, $0) })
    }

    private func makeSummary(
        scope: TrustedAutomationScope,
        recentRecords: [TrustedAutomationScopeRunRecord],
        rulesByID: [UUID: Rule],
        healthByRuleID: [UUID: RuleHealthService.RuleHealth],
        referenceDate: Date
    ) -> TrustedAutomationScopeSummary {
        let recentRunSummaries = recentRecords.prefix(recentRunLimit).map(makeRecentRunSummary)
        let health = makeHealthSummary(
            scope: scope,
            recentRecords: recentRecords,
            rulesByID: rulesByID,
            healthByRuleID: healthByRuleID,
            referenceDate: referenceDate
        )

        return TrustedAutomationScopeSummary(
            id: scope.id,
            scopeType: scope.scopeType,
            displayName: scope.displayName,
            boundarySummary: scope.boundarySummary,
            allowedActions: scope.allowedActions,
            selectedWorkflowTemplate: makeWorkflowTemplateSummary(for: scope),
            lifecycle: TrustedAutomationScopeLifecycleSummary(
                status: scope.status,
                createdAt: scope.createdAt,
                updatedAt: scope.updatedAt,
                lastEvidenceAt: scope.lastEvidenceAt,
                pausedAt: scope.pausedAt,
                lastRunAt: scope.lastRunAt,
                revokedAt: scope.revokedAt
            ),
            health: health,
            lastRun: recentRunSummaries.first
        )
    }

    private func makeWorkflowTemplateSummary(
        for scope: TrustedAutomationScope
    ) -> TrustedAutomationScopeWorkflowTemplateSummary? {
        guard let templateID = scope.selectedWorkflowTemplateID else {
            return nil
        }

        if let template = WorkflowTemplateCatalog.template(for: templateID) {
            return TrustedAutomationScopeWorkflowTemplateSummary(
                id: template.id,
                displayName: template.displayName,
                summaryText: template.summaryText,
                allowedActions: template.allowedActions,
                assignedAt: scope.templateAssignedAt
            )
        }

        return TrustedAutomationScopeWorkflowTemplateSummary(
            id: templateID,
            displayName: "Unavailable template",
            summaryText: "This scope references a template that is not available in this build.",
            allowedActions: scope.allowedActions,
            assignedAt: scope.templateAssignedAt
        )
    }

    private func makeRecentRunSummary(_ record: TrustedAutomationScopeRunRecord) -> TrustedAutomationScopeRecentRunSummary {
        TrustedAutomationScopeRecentRunSummary(
            id: record.id,
            triggerSource: record.triggerSource,
            status: record.status,
            startedAt: record.startedAt,
            endedAt: record.endedAt,
            matchedCount: record.matchedCount,
            eligibleCount: record.eligibleCount,
            organizedCount: record.organizedCount,
            heldCount: record.heldCount,
            failedCount: record.failedCount,
            heldBuckets: record.heldBuckets,
            summaryText: record.summaryText,
            exampleFileNames: record.exampleFileNames
        )
    }

    private func makeHealthSummary(
        scope: TrustedAutomationScope,
        recentRecords: [TrustedAutomationScopeRunRecord],
        rulesByID: [UUID: Rule],
        healthByRuleID: [UUID: RuleHealthService.RuleHealth],
        referenceDate: Date
    ) -> TrustedAutomationScopeHealthSummary {
        var messages: [String] = []

        if let destinationMessage = destinationHealthMessage(for: scope.boundaryDescriptor?.destinationSnapshot) {
            messages.append(destinationMessage)
        }

        if let ruleMessage = ruleHealthMessage(
            for: scope.boundaryDescriptor,
            rulesByID: rulesByID,
            healthByRuleID: healthByRuleID
        ) {
            messages.append(ruleMessage)
        }

        if let blockerMessage = recentBlockerMessage(for: recentRecords) {
            messages.append(blockerMessage)
        }

        let lastSuccessfulRunAt = recentRecords
            .first(where: isSuccessfulRun)?
            .endedAt
            ?? recentRecords.first(where: isSuccessfulRun)?.startedAt

        let lastBlockedRunAt = recentRecords
            .first(where: isAttentionWorthyRun)?
            .endedAt
            ?? recentRecords.first(where: isAttentionWorthyRun)?.startedAt

        let state: TrustedAutomationScopeHealthState
        if !messages.isEmpty {
            state = .needsAttention
        } else if isQuiet(scope: scope, recentRecords: recentRecords, referenceDate: referenceDate) {
            state = .quiet
            messages.append("No recent automation activity.")
        } else {
            state = .healthy
        }

        return TrustedAutomationScopeHealthSummary(
            state: state,
            messages: messages,
            lastSuccessfulRunAt: lastSuccessfulRunAt,
            lastBlockedRunAt: lastBlockedRunAt
        )
    }

    private func destinationHealthMessage(
        for snapshot: TrustedAutomationScopeBoundaryDescriptor.DestinationSnapshot?
    ) -> String? {
        guard let snapshot else {
            return nil
        }

        switch snapshot.kind {
        case .trash:
            return nil
        case .folder:
            guard let bookmarkData = snapshot.bookmarkData else {
                return "This trusted destination needs permission again."
            }

            let destination = Destination.folder(bookmark: bookmarkData, displayName: snapshot.displayName)
            switch destination.validate() {
            case .valid, .stale:
                return nil
            case .invalid(let reason):
                return "This trusted destination needs permission again. \(reason)"
            }
        }
    }

    private func ruleHealthMessage(
        for descriptor: TrustedAutomationScopeBoundaryDescriptor?,
        rulesByID: [UUID: Rule],
        healthByRuleID: [UUID: RuleHealthService.RuleHealth]
    ) -> String? {
        guard case .rule(let ruleBoundary, _, _) = descriptor else {
            return nil
        }

        guard rulesByID[ruleBoundary.id] != nil else {
            return "This trusted rule no longer exists."
        }

        guard let ruleHealth = healthByRuleID[ruleBoundary.id] else {
            return "This trusted rule needs attention."
        }

        guard !ruleHealth.isReadyLike else {
            return nil
        }

        if let badgeLabel = ruleHealth.badgeLabel, let message = ruleHealth.message {
            return "\(badgeLabel): \(message)"
        }

        if let badgeLabel = ruleHealth.badgeLabel {
            return badgeLabel
        }

        return ruleHealth.message ?? "This trusted rule needs attention."
    }

    private func recentBlockerMessage(for records: [TrustedAutomationScopeRunRecord]) -> String? {
        guard let record = records.first(where: isAttentionWorthyRun) else {
            return nil
        }

        if record.heldCount > 0 {
            return "\(record.heldCount) file(s) were held in a recent run."
        }

        if record.failedCount > 0 {
            return "\(record.failedCount) file(s) failed in a recent run."
        }

        switch record.status {
        case .held:
            return "A recent run was held."
        case .failed:
            return "A recent run failed."
        case .simulated, .executed:
            return nil
        }
    }

    private func isSuccessfulRun(_ record: TrustedAutomationScopeRunRecord) -> Bool {
        record.status == .executed
    }

    private func isAttentionWorthyRun(_ record: TrustedAutomationScopeRunRecord) -> Bool {
        record.status == .held ||
        record.status == .failed ||
        record.heldCount > 0 ||
        record.failedCount > 0
    }

    private func isQuiet(
        scope: TrustedAutomationScope,
        recentRecords: [TrustedAutomationScopeRunRecord],
        referenceDate: Date
    ) -> Bool {
        let lastActivityAt = recentRecords.first?.endedAt
            ?? recentRecords.first?.startedAt
            ?? scope.lastRunAt
            ?? scope.updatedAt

        return referenceDate.timeIntervalSince(lastActivityAt) >= quietWindow
    }

    private func sectionTitle(for status: TrustedAutomationScopeStatus) -> String {
        switch status {
        case .active:
            return "Active"
        case .paused:
            return "Paused"
        case .revoked:
            return "Revoked"
        }
    }
}
