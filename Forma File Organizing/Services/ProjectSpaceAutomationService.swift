import Foundation
import SwiftData

@MainActor
struct ProjectSpaceAutomationService {
    enum ServiceError: LocalizedError {
        case invalidWorkflowTemplateID

        var errorDescription: String? {
            switch self {
            case .invalidWorkflowTemplateID:
                return "A project space automation policy requires a workflow template ID."
            }
        }
    }

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func profile(normalizedProjectLabel: String) -> ProjectSpaceAutomationProfile? {
        let normalizedProjectLabel = ProjectSpaceAutomationProfile.normalizedProjectLabelValue(normalizedProjectLabel)
        guard !normalizedProjectLabel.isEmpty else {
            return nil
        }

        if let existing = existingProfile(for: normalizedProjectLabel) {
            _ = try? bootstrapFromLegacyWorkflowProfileIfNeeded(
                normalizedProjectLabel: normalizedProjectLabel,
                into: existing
            )
            return existing
        }

        return try? bootstrapFromLegacyWorkflowProfileIfNeeded(normalizedProjectLabel: normalizedProjectLabel)
    }

    @discardableResult
    func createOrUpdatePolicy(
        normalizedProjectLabel: String,
        workflowTemplateID: String,
        triggerKinds: [ProjectSpaceAutomationTriggerKind],
        admissionMode: ProjectSpaceAutomationAdmissionMode,
        state: ProjectSpaceAutomationPolicyState,
        updatedAt: Date = Date()
    ) throws -> ProjectSpaceAutomationPolicy {
        let profile = try profileOrCreate(normalizedProjectLabel: normalizedProjectLabel, at: updatedAt)
        let normalizedTemplateID = try normalizedTemplateID(workflowTemplateID)

        if let existing = existingPolicy(profileID: profile.id, workflowTemplateID: normalizedTemplateID) {
            existing.workflowTemplateID = normalizedTemplateID
            existing.triggerKinds = triggerKinds
            existing.admissionMode = admissionMode
            existing.state = state
            existing.updatedAt = updatedAt
            if state != .paused {
                existing.pausedAt = nil
            }
            if state != .revoked {
                existing.revokedAt = nil
            }
            profile.updatedAt = updatedAt
            try modelContext.save()
            return existing
        }

        let policy = ProjectSpaceAutomationPolicy(
            profileID: profile.id,
            workflowTemplateID: normalizedTemplateID,
            triggerKinds: triggerKinds,
            admissionMode: admissionMode,
            state: state,
            createdAt: updatedAt
        )
        modelContext.insert(policy)
        profile.updatedAt = updatedAt
        try modelContext.save()
        return policy
    }

    func pausePolicy(id: UUID, at timestamp: Date = Date()) throws {
        guard let policy = existingPolicy(id: id) else {
            return
        }

        policy.state = .paused
        policy.pausedAt = timestamp
        policy.updatedAt = timestamp
        try modelContext.save()
    }

    func revokePolicy(id: UUID, at timestamp: Date = Date()) throws {
        guard let policy = existingPolicy(id: id) else {
            return
        }

        policy.state = .revoked
        policy.revokedAt = timestamp
        policy.updatedAt = timestamp
        try modelContext.save()
    }

    @discardableResult
    func bootstrapFromLegacyWorkflowProfileIfNeeded(
        normalizedProjectLabel: String,
        into existingProfile: ProjectSpaceAutomationProfile? = nil
    ) throws -> ProjectSpaceAutomationProfile? {
        let normalizedProjectLabel = ProjectSpaceAutomationProfile.normalizedProjectLabelValue(normalizedProjectLabel)
        guard !normalizedProjectLabel.isEmpty else {
            return nil
        }

        let legacyService = ProjectSpaceWorkflowProfileService(modelContext: modelContext)
        guard let bootstrapCandidate = legacyService.preferredTemplateBootstrapCandidate(
            normalizedProjectLabel: normalizedProjectLabel
        ) else {
            return existingProfile
        }

        let profile: ProjectSpaceAutomationProfile
        if let existingProfile {
            profile = existingProfile
        } else {
            profile = try profileOrCreate(
                normalizedProjectLabel: normalizedProjectLabel,
                at: bootstrapCandidate.updatedAt
            )
        }
        if existingPolicy(profileID: profile.id, workflowTemplateID: bootstrapCandidate.templateID) == nil {
            let policy = ProjectSpaceAutomationPolicy(
                profileID: profile.id,
                workflowTemplateID: bootstrapCandidate.templateID,
                triggerKinds: [.manual],
                admissionMode: .manualReview,
                state: .recommended,
                createdAt: bootstrapCandidate.updatedAt
            )
            modelContext.insert(policy)
        }

        profile.lastLegacyBootstrapAt = bootstrapCandidate.updatedAt
        profile.updatedAt = max(profile.updatedAt, bootstrapCandidate.updatedAt)
        try modelContext.save()
        return profile
    }

    private func normalizedTemplateID(_ value: String) throws -> String {
        if let normalized = ProjectSpaceAutomationPolicy.normalizedTemplateID(value) {
            return normalized
        }

        throw ServiceError.invalidWorkflowTemplateID
    }

    private func existingProfile(for normalizedProjectLabel: String) -> ProjectSpaceAutomationProfile? {
        let descriptor = FetchDescriptor<ProjectSpaceAutomationProfile>(
            predicate: #Predicate<ProjectSpaceAutomationProfile> { profile in
                profile.normalizedProjectLabel == normalizedProjectLabel
            }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func existingPolicy(id: UUID) -> ProjectSpaceAutomationPolicy? {
        let descriptor = FetchDescriptor<ProjectSpaceAutomationPolicy>(
            predicate: #Predicate<ProjectSpaceAutomationPolicy> { policy in
                policy.id == id
            }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func existingPolicy(profileID: UUID, workflowTemplateID: String) -> ProjectSpaceAutomationPolicy? {
        let descriptor = FetchDescriptor<ProjectSpaceAutomationPolicy>(
            predicate: #Predicate<ProjectSpaceAutomationPolicy> { policy in
                policy.profileID == profileID
            }
        )
        return try? modelContext.fetch(descriptor).first(where: { policy in
            policy.workflowTemplateID == workflowTemplateID
        })
    }

    private func profileOrCreate(normalizedProjectLabel: String, at timestamp: Date) throws -> ProjectSpaceAutomationProfile {
        let normalizedProjectLabel = ProjectSpaceAutomationProfile.normalizedProjectLabelValue(normalizedProjectLabel)
        if let existing = existingProfile(for: normalizedProjectLabel) {
            return existing
        }

        let profile = ProjectSpaceAutomationProfile(
            normalizedProjectLabel: normalizedProjectLabel,
            createdAt: timestamp
        )
        modelContext.insert(profile)
        try modelContext.save()
        return profile
    }
}
