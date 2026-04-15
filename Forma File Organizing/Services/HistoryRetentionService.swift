import Foundation
import SwiftData

@MainActor
final class HistoryRetentionService {
    private let modelContext: ModelContext
    private let calendar: Calendar

    init(
        modelContext: ModelContext,
        calendar: Calendar = .current
    ) {
        self.modelContext = modelContext
        self.calendar = calendar
    }

    static var workflowRunLimit: Int { FormaConfig.retention.workflowRunLimit }
    static var trustedScopeRunLimitPerScope: Int { FormaConfig.retention.trustedScopeRunLimitPerScope }
    static var personalMemoryEventLimit: Int { FormaConfig.retention.personalMemoryEventLimit }

    static func historyCutoff(referenceDate: Date, calendar: Calendar = .current) -> Date {
        calendar.date(
            byAdding: .day,
            value: -FormaConfig.retention.historyWindowDays,
            to: calendar.startOfDay(for: referenceDate)
        ) ?? referenceDate.addingTimeInterval(
            -Double(FormaConfig.retention.historyWindowDays) * FormaConfig.Timing.secondsInDay
        )
    }

    @discardableResult
    func pruneAllHistory(now: Date = Date()) throws -> Bool {
        var didChange = false
        didChange = try pruneWorkflowAuditHistoryWithoutSaving(now: now) || didChange
        didChange = try pruneTrustedScopeRunHistoryWithoutSaving(now: now) || didChange
        didChange = try prunePersonalMemoryHistoryWithoutSaving(now: now) || didChange

        if didChange {
            try modelContext.save()
        }

        return didChange
    }

    @discardableResult
    func pruneWorkflowAuditHistory(now: Date = Date()) throws -> Bool {
        let didChange = try pruneWorkflowAuditHistoryWithoutSaving(now: now)
        if didChange {
            try modelContext.save()
        }
        return didChange
    }

    @discardableResult
    func pruneTrustedScopeRunHistory(now: Date = Date()) throws -> Bool {
        let didChange = try pruneTrustedScopeRunHistoryWithoutSaving(now: now)
        if didChange {
            try modelContext.save()
        }
        return didChange
    }

    @discardableResult
    func prunePersonalMemoryHistory(now: Date = Date()) throws -> Bool {
        let didChange = try prunePersonalMemoryHistoryWithoutSaving(now: now)
        if didChange {
            try modelContext.save()
        }
        return didChange
    }

    private func pruneWorkflowAuditHistoryWithoutSaving(now: Date) throws -> Bool {
        let cutoff = Self.historyCutoff(referenceDate: now, calendar: calendar)
        let runs = try modelContext.fetch(
            FetchDescriptor<WorkflowRunRecord>(
                sortBy: [
                    SortDescriptor(\.startedAt, order: .reverse),
                    SortDescriptor(\.updatedAt, order: .reverse)
                ]
            )
        )

        var didChange = false
        let staleRuns = runs.filter { $0.startedAt < cutoff }
        if !staleRuns.isEmpty {
            deleteWorkflowRunsAndChildren(staleRuns)
            didChange = true
        }

        let retainedRuns = runs.filter { $0.startedAt >= cutoff }
        if retainedRuns.count > Self.workflowRunLimit {
            deleteWorkflowRunsAndChildren(Array(retainedRuns.dropFirst(Self.workflowRunLimit)))
            didChange = true
        }

        return didChange
    }

    private func pruneTrustedScopeRunHistoryWithoutSaving(now: Date) throws -> Bool {
        let cutoff = Self.historyCutoff(referenceDate: now, calendar: calendar)
        let records = try modelContext.fetch(
            FetchDescriptor<TrustedAutomationScopeRunRecord>(
                sortBy: [
                    SortDescriptor(\.startedAt, order: .reverse)
                ]
            )
        )

        var didChange = false
        let staleRecords = records.filter { $0.startedAt < cutoff }
        if !staleRecords.isEmpty {
            staleRecords.forEach(modelContext.delete)
            didChange = true
        }

        let retainedByScope = Dictionary(grouping: records.filter { $0.startedAt >= cutoff }, by: \.scopeID)
        for retainedRecords in retainedByScope.values {
            let ordered = retainedRecords.sorted(by: trustedScopeRunSortOrder)
            guard ordered.count > Self.trustedScopeRunLimitPerScope else {
                continue
            }

            ordered
                .dropFirst(Self.trustedScopeRunLimitPerScope)
                .forEach(modelContext.delete)
            didChange = true
        }

        return didChange
    }

    private func prunePersonalMemoryHistoryWithoutSaving(now: Date) throws -> Bool {
        let cutoff = Self.historyCutoff(referenceDate: now, calendar: calendar)
        let events = try modelContext.fetch(
            FetchDescriptor<PersonalMemoryEvent>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
        )

        var didChange = false
        let staleEvents = events.filter { $0.timestamp < cutoff }
        if !staleEvents.isEmpty {
            staleEvents.forEach(modelContext.delete)
            didChange = true
        }

        let retainedEvents = events.filter { $0.timestamp >= cutoff }
        if retainedEvents.count > Self.personalMemoryEventLimit {
            retainedEvents
                .dropFirst(Self.personalMemoryEventLimit)
                .forEach(modelContext.delete)
            didChange = true
        }

        return didChange
    }

    private func deleteWorkflowRunsAndChildren<S: Sequence>(_ runs: S) where S.Element == WorkflowRunRecord {
        let runArray = Array(runs)
        let runIDs = Set(runArray.map(\.id))
        guard !runIDs.isEmpty else {
            return
        }

        if let stepRuns = try? modelContext.fetch(FetchDescriptor<WorkflowStepRunRecord>()) {
            stepRuns
                .filter { runIDs.contains($0.runID) }
                .forEach(modelContext.delete)
        }

        if let fileActions = try? modelContext.fetch(FetchDescriptor<WorkflowFileActionRecord>()) {
            fileActions
                .filter { runIDs.contains($0.runID) }
                .forEach(modelContext.delete)
        }

        runArray.forEach(modelContext.delete)
    }

    private func trustedScopeRunSortOrder(
        _ lhs: TrustedAutomationScopeRunRecord,
        _ rhs: TrustedAutomationScopeRunRecord
    ) -> Bool {
        let lhsCompletedAt = lhs.endedAt ?? lhs.startedAt
        let rhsCompletedAt = rhs.endedAt ?? rhs.startedAt
        if lhsCompletedAt == rhsCompletedAt {
            return lhs.id.uuidString > rhs.id.uuidString
        }
        return lhsCompletedAt > rhsCompletedAt
    }
}
