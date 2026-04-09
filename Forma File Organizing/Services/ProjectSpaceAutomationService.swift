import Foundation
import SwiftData

struct ProjectSpaceAutomationResolvedPolicy {
    let normalizedProjectLabel: String
    let policy: ProjectSpaceAutomationPolicy
}

@MainActor
struct ProjectSpaceAutomationService {
    enum ServiceError: LocalizedError {
        case invalidProjectLabel
        case invalidWorkflowTemplateID

        var errorDescription: String? {
            switch self {
            case .invalidProjectLabel:
                return "A project space automation policy requires a non-empty project label."
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

    func policies(
        matching triggerKind: ProjectSpaceAutomationTriggerKind,
        states: Set<ProjectSpaceAutomationPolicyState>
    ) -> [ProjectSpaceAutomationResolvedPolicy] {
        guard !states.isEmpty else {
            return []
        }

        let profilesByID = Dictionary(uniqueKeysWithValues: allProfiles().map { ($0.id, $0) })
        return allPolicies()
            .filter { policy in
                states.contains(policy.state) && policy.triggerKinds.contains(triggerKind)
            }
            .compactMap { policy in
                guard let profile = profilesByID[policy.profileID] else {
                    return nil
                }
                return ProjectSpaceAutomationResolvedPolicy(
                    normalizedProjectLabel: profile.normalizedProjectLabel,
                    policy: policy
                )
            }
            .sorted { lhs, rhs in
                if lhs.normalizedProjectLabel != rhs.normalizedProjectLabel {
                    return lhs.normalizedProjectLabel < rhs.normalizedProjectLabel
                }
                if lhs.policy.updatedAt != rhs.policy.updatedAt {
                    return lhs.policy.updatedAt < rhs.policy.updatedAt
                }
                return lhs.policy.id.uuidString < rhs.policy.id.uuidString
            }
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
            applyLifecycle(state: state, timestamp: updatedAt, to: existing)
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
        applyLifecycle(state: state, timestamp: updatedAt, to: policy)
        modelContext.insert(policy)
        profile.updatedAt = updatedAt
        try modelContext.save()
        return policy
    }

    func pausePolicy(id: UUID, at timestamp: Date = Date()) throws {
        guard let policy = existingPolicy(id: id) else {
            return
        }

        applyLifecycle(state: .paused, timestamp: timestamp, to: policy)
        try modelContext.save()
    }

    func revokePolicy(id: UUID, at timestamp: Date = Date()) throws {
        guard let policy = existingPolicy(id: id) else {
            return
        }

        applyLifecycle(state: .revoked, timestamp: timestamp, to: policy)
        try modelContext.save()
    }

    @discardableResult
    func recordRun(
        policyID: UUID,
        workflowTemplateID: String,
        triggerKind: ProjectSpaceAutomationTriggerKind,
        workflowRunID: UUID?,
        status: ProjectSpaceAutomationRunStatus,
        startedAt: Date,
        endedAt: Date?,
        createdAt: Date = Date()
    ) throws -> ProjectSpaceAutomationRunRecord {
        let runRecord = ProjectSpaceAutomationRunRecord(
            policyID: policyID,
            workflowRunID: workflowRunID,
            workflowTemplateID: try normalizedTemplateID(workflowTemplateID),
            triggerKind: triggerKind,
            status: status,
            startedAt: startedAt,
            endedAt: endedAt,
            createdAt: createdAt
        )
        modelContext.insert(runRecord)
        try modelContext.save()
        return runRecord
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
        let policies = policies(profileID: profile.id)
        let recommendedPolicies = policies.filter { $0.state == .recommended }
        if let bridgedPolicy = recommendedPolicies.first {
            bridgedPolicy.workflowTemplateID = bootstrapCandidate.templateID
            bridgedPolicy.triggerKinds = [.manual]
            bridgedPolicy.admissionMode = .manualReview
            applyLifecycle(state: .recommended, timestamp: bootstrapCandidate.updatedAt, to: bridgedPolicy)

            for duplicatePolicy in recommendedPolicies.dropFirst() {
                modelContext.delete(duplicatePolicy)
            }
        } else if policies.contains(where: { $0.workflowTemplateID == bootstrapCandidate.templateID }) {
            // A previously bootstrapped policy has been promoted or terminally transitioned.
            // Preserve that row and avoid creating a duplicate recommended bridge.
        } else {
            let policy = ProjectSpaceAutomationPolicy(
                profileID: profile.id,
                workflowTemplateID: bootstrapCandidate.templateID,
                triggerKinds: [.manual],
                admissionMode: .manualReview,
                state: .recommended,
                createdAt: bootstrapCandidate.updatedAt
            )
            applyLifecycle(state: .recommended, timestamp: bootstrapCandidate.updatedAt, to: policy)
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

    private func validatedProjectLabel(_ value: String) throws -> String {
        let normalizedProjectLabel = ProjectSpaceAutomationProfile.normalizedProjectLabelValue(value)
        guard !normalizedProjectLabel.isEmpty else {
            throw ServiceError.invalidProjectLabel
        }
        return normalizedProjectLabel
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

    private func policies(profileID: UUID) -> [ProjectSpaceAutomationPolicy] {
        let descriptor = FetchDescriptor<ProjectSpaceAutomationPolicy>(
            predicate: #Predicate<ProjectSpaceAutomationPolicy> { policy in
                policy.profileID == profileID
            }
        )

        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func allPolicies() -> [ProjectSpaceAutomationPolicy] {
        (try? modelContext.fetch(FetchDescriptor<ProjectSpaceAutomationPolicy>())) ?? []
    }

    private func allProfiles() -> [ProjectSpaceAutomationProfile] {
        (try? modelContext.fetch(FetchDescriptor<ProjectSpaceAutomationProfile>())) ?? []
    }

    private func profileOrCreate(normalizedProjectLabel: String, at timestamp: Date) throws -> ProjectSpaceAutomationProfile {
        let normalizedProjectLabel = try validatedProjectLabel(normalizedProjectLabel)
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

    private func applyLifecycle(
        state: ProjectSpaceAutomationPolicyState,
        timestamp: Date,
        to policy: ProjectSpaceAutomationPolicy
    ) {
        policy.state = state
        policy.updatedAt = timestamp

        switch state {
        case .paused:
            policy.pausedAt = timestamp
            policy.revokedAt = nil
        case .revoked:
            policy.revokedAt = timestamp
        case .draft, .recommended, .active:
            policy.pausedAt = nil
            policy.revokedAt = nil
        }
    }
}
