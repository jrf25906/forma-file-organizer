import Foundation
import SwiftData

@MainActor
struct ProjectSpaceWorkflowProfileService {
    private static let staleMemoryWindow: TimeInterval = 30 * 24 * 60 * 60
    private static let conflictWindow: TimeInterval = 24 * 60 * 60

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func profile(normalizedProjectLabel: String) -> ProjectSpaceWorkflowProfile? {
        let normalizedProjectLabel = ProjectSpaceWorkflowProfile.normalizedProjectLabelValue(normalizedProjectLabel)
        guard !normalizedProjectLabel.isEmpty else {
            return nil
        }

        return existingProfile(for: normalizedProjectLabel)
    }

    func upsertPreferredTemplate(
        _ templateID: String?,
        for normalizedProjectLabel: String,
        at timestamp: Date
    ) throws {
        let normalizedTemplateID = ProjectSpaceWorkflowProfile.normalizedTemplateSignal(templateID)

        if normalizedTemplateID == nil {
            let normalizedProjectLabel = ProjectSpaceWorkflowProfile.normalizedProjectLabelValue(normalizedProjectLabel)
            guard !normalizedProjectLabel.isEmpty else {
                return
            }

            guard let profile = existingProfile(for: normalizedProjectLabel) else {
                return
            }

            profile.preferredWorkflowTemplateID = nil

            if isEffectivelyEmpty(profile) {
                try modelContext.delete(
                    model: ProjectSpaceWorkflowProfile.self,
                    where: #Predicate<ProjectSpaceWorkflowProfile> { profile in
                        profile.normalizedProjectLabel == normalizedProjectLabel
                    },
                    includeSubclasses: false
                )
            } else {
                profile.updatedAt = timestamp
            }

            try modelContext.save()
            return
        }

        guard let profile = profileOrCreate(normalizedProjectLabel: normalizedProjectLabel) else {
            return
        }

        profile.preferredWorkflowTemplateID = normalizedTemplateID
        profile.updatedAt = timestamp
        try modelContext.save()
    }

    func recordLatestRun(
        _ run: WorkflowRunRecord,
        for normalizedProjectLabel: String,
        at timestamp: Date
    ) throws {
        guard let profile = profileOrCreate(normalizedProjectLabel: normalizedProjectLabel) else {
            return
        }

        let completedAt = run.endedAt ?? timestamp
        hydrateLegacyMemoryIfNeeded(profile, fallbackTimestamp: completedAt)

        profile.lastWorkflowRunID = run.id
        profile.lastWorkflowCompletedAt = completedAt

        if isSuccessfulMemoryOutcome(run.primaryStatus) {
            applySuccessfulRunMemory(run, completedAt: completedAt, to: profile)
        } else {
            applyStaleStatusIfNeeded(to: profile, referenceDate: completedAt)
        }

        profile.updatedAt = timestamp
        try modelContext.save()
    }

    func preferredTemplateBootstrapCandidate(
        normalizedProjectLabel: String
    ) -> (templateID: String, updatedAt: Date)? {
        let normalizedProjectLabel = ProjectSpaceWorkflowProfile.normalizedProjectLabelValue(normalizedProjectLabel)
        guard !normalizedProjectLabel.isEmpty,
              let profile = existingProfile(for: normalizedProjectLabel),
              let templateID = ProjectSpaceWorkflowProfile.normalizedTemplateSignal(profile.preferredWorkflowTemplateID) else {
            return nil
        }

        return (templateID, profile.updatedAt)
    }

    private func existingProfile(for normalizedProjectLabel: String) -> ProjectSpaceWorkflowProfile? {
        let descriptor = FetchDescriptor<ProjectSpaceWorkflowProfile>(
            predicate: #Predicate<ProjectSpaceWorkflowProfile> { profile in
                profile.normalizedProjectLabel == normalizedProjectLabel
            }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func profileOrCreate(normalizedProjectLabel: String) -> ProjectSpaceWorkflowProfile? {
        let normalizedProjectLabel = ProjectSpaceWorkflowProfile.normalizedProjectLabelValue(normalizedProjectLabel)
        guard !normalizedProjectLabel.isEmpty else {
            return nil
        }

        if let existing = existingProfile(for: normalizedProjectLabel) {
            return existing
        }

        let profile = ProjectSpaceWorkflowProfile(normalizedProjectLabel: normalizedProjectLabel)
        modelContext.insert(profile)
        return profile
    }

    private func isSuccessfulMemoryOutcome(_ status: WorkflowRunPrimaryStatus) -> Bool {
        status == .succeeded || status == .completedWithIssues
    }

    private func hydrateLegacyMemoryIfNeeded(
        _ profile: ProjectSpaceWorkflowProfile,
        fallbackTimestamp: Date
    ) {
        profile.preferredWorkflowTemplateID = ProjectSpaceWorkflowProfile.normalizedTemplateSignal(profile.preferredWorkflowTemplateID)
        profile.successfulTemplateID = ProjectSpaceWorkflowProfile.normalizedTemplateSignal(profile.successfulTemplateID)
        profile.latestSuccessfulDestinationSignal = ProjectSpaceWorkflowProfile
            .normalizedDestinationSignal(profile.latestSuccessfulDestinationSignal)
        profile.dominantTriggerSurface = ProjectSpaceWorkflowProfile
            .normalizedTriggerSurfaceSignal(profile.dominantTriggerSurface)

        if profile.successfulTemplateID == nil,
           let legacyTemplateID = profile.preferredWorkflowTemplateID,
           profile.lastWorkflowRunID != nil || profile.lastWorkflowCompletedAt != nil {
            profile.successfulTemplateID = legacyTemplateID
            profile.successfulTemplateCount = max(profile.successfulTemplateCount, 1)
            profile.successfulTemplateLastSucceededAt =
                profile.successfulTemplateLastSucceededAt ??
                profile.lastWorkflowCompletedAt ??
                fallbackTimestamp
        }

        if profile.successfulTemplateID == nil {
            profile.successfulTemplateCount = 0
            profile.successfulTemplateLastSucceededAt = nil
        }

        if profile.dominantTriggerSurface == nil {
            profile.dominantTriggerSurfaceCount = 0
            profile.dominantTriggerSurfaceLastSeenAt = nil
        }
    }

    private func applySuccessfulRunMemory(
        _ run: WorkflowRunRecord,
        completedAt: Date,
        to profile: ProjectSpaceWorkflowProfile
    ) {
        let templateSignal = ProjectSpaceWorkflowProfile.normalizedTemplateSignal(run.workflowTemplateID)
        let previousTemplateSignal = profile.successfulTemplateID
        let previousTemplateTimestamp = profile.successfulTemplateLastSucceededAt
        let templateConflict = previousTemplateSignal != nil &&
            templateSignal != nil &&
            previousTemplateSignal != templateSignal &&
            isWithinConflictWindow(previousTemplateTimestamp, comparedTo: completedAt)

        let triggerSignal = ProjectSpaceWorkflowProfile.normalizedTriggerSurfaceSignal(run.triggerSurface)
        let previousTriggerSignal = profile.dominantTriggerSurface
        let previousTriggerTimestamp = profile.dominantTriggerSurfaceLastSeenAt
        let triggerConflict = previousTriggerSignal != nil &&
            triggerSignal != nil &&
            previousTriggerSignal != triggerSignal &&
            isWithinConflictWindow(previousTriggerTimestamp, comparedTo: completedAt)

        if templateConflict || triggerConflict {
            if let destinationSignal = latestDestinationSignal(forRunID: run.id) {
                profile.latestSuccessfulDestinationSignal = destinationSignal
                profile.latestSuccessfulDestinationAt = completedAt
            }
            profile.workflowMemoryStatus = .conflicted
            return
        }

        if let templateSignal {
            if profile.successfulTemplateID == templateSignal {
                profile.successfulTemplateCount = max(1, profile.successfulTemplateCount + 1)
            } else {
                profile.successfulTemplateID = templateSignal
                profile.successfulTemplateCount = 1
            }
            profile.successfulTemplateLastSucceededAt = completedAt
        }

        if let triggerSignal {
            if profile.dominantTriggerSurface == triggerSignal {
                profile.dominantTriggerSurfaceCount = max(1, profile.dominantTriggerSurfaceCount + 1)
            } else {
                profile.dominantTriggerSurface = triggerSignal
                profile.dominantTriggerSurfaceCount = 1
            }
            profile.dominantTriggerSurfaceLastSeenAt = completedAt
        }

        if let destinationSignal = latestDestinationSignal(forRunID: run.id) {
            profile.latestSuccessfulDestinationSignal = destinationSignal
            profile.latestSuccessfulDestinationAt = completedAt
        }

        profile.workflowMemoryStatus = .stable
        applyStaleStatusIfNeeded(to: profile, referenceDate: completedAt)
    }

    private func latestDestinationSignal(forRunID runID: UUID) -> String? {
        let descriptor = FetchDescriptor<WorkflowFileActionRecord>(
            predicate: #Predicate<WorkflowFileActionRecord> { action in
                action.runID == runID
            }
        )

        let latestAction = (try? modelContext.fetch(descriptor))?.max(by: { lhs, rhs in
            if lhs.recordedAt == rhs.recordedAt {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.recordedAt < rhs.recordedAt
        })

        return ProjectSpaceWorkflowProfile.normalizedDestinationSignal(latestAction?.destinationPath)
    }

    private func isWithinConflictWindow(_ baseline: Date?, comparedTo timestamp: Date) -> Bool {
        guard let baseline else { return false }
        return abs(timestamp.timeIntervalSince(baseline)) <= Self.conflictWindow
    }

    private func applyStaleStatusIfNeeded(to profile: ProjectSpaceWorkflowProfile, referenceDate: Date) {
        guard let lastSuccessAt = profile.successfulTemplateLastSucceededAt else {
            return
        }

        if referenceDate.timeIntervalSince(lastSuccessAt) > Self.staleMemoryWindow {
            profile.workflowMemoryStatus = .stale
        }
    }

    private func isEffectivelyEmpty(_ profile: ProjectSpaceWorkflowProfile) -> Bool {
        profile.preferredWorkflowTemplateID == nil &&
        profile.lastWorkflowRunID == nil &&
        profile.lastWorkflowCompletedAt == nil &&
        profile.successfulTemplateID == nil &&
        profile.successfulTemplateCount == 0 &&
        profile.successfulTemplateLastSucceededAt == nil &&
        profile.dominantTriggerSurface == nil &&
        profile.dominantTriggerSurfaceCount == 0 &&
        profile.dominantTriggerSurfaceLastSeenAt == nil &&
        profile.latestSuccessfulDestinationSignal == nil &&
        profile.latestSuccessfulDestinationAt == nil
    }
}
