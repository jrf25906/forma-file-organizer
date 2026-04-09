import Foundation
import SwiftData

@MainActor
struct ProjectSpaceWorkflowProfileService {
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
        guard let profile = profileOrCreate(normalizedProjectLabel: normalizedProjectLabel) else {
            return
        }

        profile.preferredWorkflowTemplateID = ProjectSpaceWorkflowProfile.normalizedOptionalText(templateID)
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

        profile.lastWorkflowRunID = run.id
        profile.lastWorkflowCompletedAt = run.endedAt ?? timestamp
        profile.updatedAt = timestamp
        try modelContext.save()
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
}
