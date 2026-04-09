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

    private struct BootstrapRecommendationCandidate {
        let workflowTemplateID: String
        let triggerKinds: [ProjectSpaceAutomationTriggerKind]
        let admissionMode: ProjectSpaceAutomationAdmissionMode
        let updatedAt: Date
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

    func policies(normalizedProjectLabel: String) -> [ProjectSpaceAutomationPolicy] {
        guard let profile = profile(normalizedProjectLabel: normalizedProjectLabel) else {
            return []
        }

        return policies(profileID: profile.id).sorted { lhs, rhs in
            policySortKey(for: lhs) > policySortKey(for: rhs)
        }
    }

    func policy(id: UUID) -> ProjectSpaceAutomationPolicy? {
        existingPolicy(id: id)
    }

    func workflowExecutionRequest(
        for policy: ProjectSpaceAutomationPolicy,
        projectLabel: String,
        triggerKind: ProjectSpaceAutomationTriggerKind,
        scopeID: UUID = UUID()
    ) -> WorkflowExecutionRequest {
        let policyName = WorkflowTemplateCatalog.template(for: policy.workflowTemplateID)?.displayName
            ?? policy.workflowTemplateID
        return WorkflowExecutionRequest(
            templateID: policy.workflowTemplateID,
            scopeID: scopeID,
            entryPoint: .projectPolicy(
                policyID: policy.id,
                triggerKind: triggerKind,
                projectLabel: projectLabel,
                policyName: policyName
            )
        )
    }

    func latestRun(policyID: UUID) -> ProjectSpaceAutomationRunRecord? {
        let descriptor = FetchDescriptor<ProjectSpaceAutomationRunRecord>(
            predicate: #Predicate<ProjectSpaceAutomationRunRecord> { run in
                run.policyID == policyID
            }
        )

        return (try? modelContext.fetch(descriptor))?
            .sorted { lhs, rhs in
                runSortKey(for: lhs) > runSortKey(for: rhs)
            }
            .first
    }

    func policies(
        matching triggerKind: ProjectSpaceAutomationTriggerKind,
        states: Set<ProjectSpaceAutomationPolicyState>
    ) -> [ProjectSpaceAutomationResolvedPolicy] {
        guard !states.isEmpty else {
            return []
        }

        let profilesByID = Dictionary(uniqueKeysWithValues: allProfiles().map { ($0.id, $0) })
        let candidates: [ProjectSpaceAutomationResolvedPolicy] = allPolicies()
            .filter { policy in
                states.contains(policy.state) && policy.triggerKinds.contains(triggerKind)
            }
            .compactMap { policy -> ProjectSpaceAutomationResolvedPolicy? in
                guard let profile = profilesByID[policy.profileID] else {
                    return nil
                }
                return ProjectSpaceAutomationResolvedPolicy(
                    normalizedProjectLabel: profile.normalizedProjectLabel,
                    policy: policy
                )
            }

        var winnersByProjectLabel: [String: ProjectSpaceAutomationResolvedPolicy] = [:]
        for candidate in candidates {
            if let existing = winnersByProjectLabel[candidate.normalizedProjectLabel] {
                if policySortKey(for: existing.policy) < policySortKey(for: candidate.policy) {
                    winnersByProjectLabel[candidate.normalizedProjectLabel] = candidate
                }
            } else {
                winnersByProjectLabel[candidate.normalizedProjectLabel] = candidate
            }
        }
        return winnersByProjectLabel.keys.sorted().compactMap { winnersByProjectLabel[$0] }
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
            if state == .active {
                pauseSiblingActivePolicies(for: existing, at: updatedAt)
            }
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
        if state == .active {
            pauseSiblingActivePolicies(for: policy, at: updatedAt)
        }
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

    func activatePolicy(id: UUID, at timestamp: Date = Date()) throws {
        guard let policy = existingPolicy(id: id) else {
            return
        }

        pauseSiblingActivePolicies(for: policy, at: timestamp)
        applyLifecycle(state: .active, timestamp: timestamp, to: policy)
        try modelContext.save()
    }

    func resumePolicy(id: UUID, at timestamp: Date = Date()) throws {
        guard let policy = existingPolicy(id: id) else {
            return
        }

        pauseSiblingActivePolicies(for: policy, at: timestamp)
        applyLifecycle(state: .active, timestamp: timestamp, to: policy)
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

        guard let bootstrapCandidate = bootstrapRecommendationCandidate(
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

        // Keep the legacy bridge fresh only while the board still consists of the
        // single bootstrap recommendation. Once any other policy shape exists,
        // stop mutating recommended rows because they may no longer be the bridge.
        if !policies.isEmpty && (policies.count != 1 || recommendedPolicies.count != 1) {
            profile.lastLegacyBootstrapAt = bootstrapCandidate.updatedAt
            profile.updatedAt = max(profile.updatedAt, bootstrapCandidate.updatedAt)
            try modelContext.save()
            return profile
        }

        if let bridgedPolicy = recommendedPolicies.first {
            bridgedPolicy.workflowTemplateID = bootstrapCandidate.workflowTemplateID
            bridgedPolicy.triggerKinds = bootstrapCandidate.triggerKinds
            bridgedPolicy.admissionMode = bootstrapCandidate.admissionMode
            applyLifecycle(state: .recommended, timestamp: bootstrapCandidate.updatedAt, to: bridgedPolicy)

            for duplicatePolicy in recommendedPolicies.dropFirst() {
                modelContext.delete(duplicatePolicy)
            }
        } else if policies.contains(where: { $0.workflowTemplateID == bootstrapCandidate.workflowTemplateID }) {
            // A previously bootstrapped policy has been promoted or terminally transitioned.
            // Preserve that row and avoid creating a duplicate recommended bridge.
        } else {
            let policy = ProjectSpaceAutomationPolicy(
                profileID: profile.id,
                workflowTemplateID: bootstrapCandidate.workflowTemplateID,
                triggerKinds: bootstrapCandidate.triggerKinds,
                admissionMode: bootstrapCandidate.admissionMode,
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

    private func bootstrapRecommendationCandidate(
        normalizedProjectLabel: String,
        now: Date = Date()
    ) -> BootstrapRecommendationCandidate? {
        let workflowProfileService = ProjectSpaceWorkflowProfileService(modelContext: modelContext)
        let workflowProfile = workflowProfileService.profile(normalizedProjectLabel: normalizedProjectLabel)
        let recommendationService = ProjectSpaceAutomationRecommendationService()
        let memoryResolver = ProjectSpaceMemoryResolver()
        let summary = ProjectSpaceSummary(
            normalizedLabel: normalizedProjectLabel,
            fileCount: 0,
            lastActivityAt: now,
            sourceFolderHints: []
        )
        let workflowOnlyDetail = ProjectSpaceDetail(
            summary: summary,
            files: [],
            workflowMemory: memoryResolver.resolveWorkflowMemoryProjection(
                for: ProjectSpaceDetail(summary: summary, files: []),
                profile: workflowProfile,
                now: now
            )
        )

        if let workflowMemory = workflowOnlyDetail.workflowMemory,
           workflowMemory.state != .destinationFallback {
            guard let recommendation = recommendationService
                .recommendedPolicies(for: workflowOnlyDetail, now: now)
                .first else {
                return nil
            }

            return BootstrapRecommendationCandidate(
                workflowTemplateID: recommendation.workflowTemplateID,
                triggerKinds: recommendation.triggerKinds,
                admissionMode: recommendation.admissionMode,
                updatedAt: workflowMemory.successfulTemplateLastSucceededAt
                    ?? workflowProfile?.updatedAt
                    ?? now
            )
        }

        let metadataService = FileMetadataFoundationService(modelContext: modelContext)
        guard let detail = metadataService.fetchProjectSpaceDetail(for: normalizedProjectLabel) else {
            return nil
        }

        let projectedDetail = ProjectSpaceDetail(
            summary: detail.summary,
            files: detail.files,
            overview: detail.overview,
            preferredDestinations: detail.preferredDestinations,
            recentActivity: detail.recentActivity,
            workflowMemory: memoryResolver.resolveWorkflowMemoryProjection(
                for: detail,
                profile: workflowProfile,
                now: now
            )
        )
        guard let recommendation = recommendationService
            .recommendedPolicies(for: projectedDetail, now: now)
            .first else {
            return nil
        }

        return BootstrapRecommendationCandidate(
            workflowTemplateID: recommendation.workflowTemplateID,
            triggerKinds: recommendation.triggerKinds,
            admissionMode: recommendation.admissionMode,
            updatedAt: recommendationService
                .dominantDestination(for: projectedDetail, now: now)?
                .lastUsedAt ?? detail.lastActivityAt
        )
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

    private func policySortKey(for policy: ProjectSpaceAutomationPolicy) -> (Int, Date, Date, String) {
        (
            policyStateRank(policy.state),
            policy.updatedAt,
            policy.createdAt,
            policy.id.uuidString
        )
    }

    private func policyStateRank(_ state: ProjectSpaceAutomationPolicyState) -> Int {
        switch state {
        case .active:
            return 3
        case .recommended:
            return 2
        case .paused:
            return 1
        case .revoked:
            return 0
        case .draft:
            return -1
        }
    }

    private func runSortKey(for run: ProjectSpaceAutomationRunRecord) -> (Date, Date, String) {
        (
            run.endedAt ?? run.startedAt,
            run.startedAt,
            run.id.uuidString
        )
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

    private func pauseSiblingActivePolicies(
        for policy: ProjectSpaceAutomationPolicy,
        at timestamp: Date
    ) {
        for sibling in policies(profileID: policy.profileID) where sibling.id != policy.id && sibling.state == .active {
            applyLifecycle(state: .paused, timestamp: timestamp, to: sibling)
        }
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
