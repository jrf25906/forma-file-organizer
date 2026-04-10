import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class ProjectSpaceAutomationServiceTests: XCTestCase {
    private func makeService() throws -> (ModelContainer, ModelContext, ProjectSpaceAutomationService) {
        let schema = Schema([
            FileMetadataRecord.self,
            FileOrganizationHistoryEntry.self,
            ProjectSpaceWorkflowProfile.self,
            ProjectSpaceAutomationProfile.self,
            ProjectSpaceAutomationPolicy.self,
            ProjectSpaceAutomationRunRecord.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        return (container, context, ProjectSpaceAutomationService(modelContext: context))
    }

    private func withService(
        _ body: (_ context: ModelContext, _ service: ProjectSpaceAutomationService) throws -> Void
    ) throws {
        let (container, context, service) = try makeService()
        try withExtendedLifetime(container) {
            try body(context, service)
        }
    }

    @discardableResult
    private func insertProjectSpaceRecord(
        using service: FileMetadataFoundationService,
        path: String,
        projectAssociation: String,
        timestamp: Date
    ) throws -> FileMetadataRecord {
        let record = try XCTUnwrap(
            service.upsertRecord(
                for: path,
                displayName: URL(fileURLWithPath: path).lastPathComponent,
                fileExtension: URL(fileURLWithPath: path).pathExtension,
                timestamp: timestamp
            )
        )
        record.projectAssociation = projectAssociation
        return record
    }

    private func addHistory(
        in context: ModelContext,
        to record: FileMetadataRecord,
        eventKind: FileOrganizationHistoryEntry.EventKind,
        timestamp: Date,
        toPath: String,
        destinationDisplayName: String,
        detailsSummary: String
    ) {
        let entry = FileOrganizationHistoryEntry(
            timestamp: timestamp,
            metadataRecord: record,
            fileIdentitySnapshot: record.canonicalIdentity,
            eventKind: eventKind,
            sourceSurface: .review,
            fromPath: record.lastKnownPath,
            toPath: toPath,
            destinationDisplayName: destinationDisplayName,
            detailsSummary: detailsSummary
        )
        context.insert(entry)
        record.historyEntries.append(entry)
    }

    func testProfileFetch_BootstrapsRecommendedPolicyFromWorkflowMemoryRecommendation() throws {
        try withService { context, service in
            let timestamp = Date()
            let workflowProfile = ProjectSpaceWorkflowProfile(
                normalizedProjectLabel: " Alpha ",
                preferredWorkflowTemplateID: " \(BuiltInWorkflowTemplate.StableID.receipts) ",
                successfulTemplateID: " \(BuiltInWorkflowTemplate.StableID.projectDrop) ",
                successfulTemplateCount: 4,
                successfulTemplateLastSucceededAt: timestamp.addingTimeInterval(-120),
                dominantTriggerSurface: .projectPolicyScheduled,
                dominantTriggerSurfaceCount: 4,
                dominantTriggerSurfaceLastSeenAt: timestamp.addingTimeInterval(-120),
                workflowMemoryStatus: .stable,
                updatedAt: timestamp
            )
            context.insert(workflowProfile)
            try context.save()

            let profile = try XCTUnwrap(service.profile(normalizedProjectLabel: "Alpha"))
            let policies = try context.fetch(FetchDescriptor<ProjectSpaceAutomationPolicy>())

            XCTAssertEqual(profile.normalizedProjectLabel, "Alpha")
            XCTAssertEqual(profile.lastLegacyBootstrapAt, timestamp.addingTimeInterval(-120))
            XCTAssertEqual(policies.count, 1)

            let policy = try XCTUnwrap(policies.first)
            XCTAssertEqual(policy.profileID, profile.id)
            XCTAssertEqual(policy.workflowTemplateID, BuiltInWorkflowTemplate.StableID.projectDrop)
            XCTAssertEqual(policy.state, .recommended)
            XCTAssertEqual(policy.triggerKinds, [.scheduledSweep])
            XCTAssertEqual(policy.admissionMode, .automatic)

            let preservedWorkflowProfile = try XCTUnwrap(
                context.fetch(FetchDescriptor<ProjectSpaceWorkflowProfile>()).first
            )
            XCTAssertEqual(preservedWorkflowProfile.preferredWorkflowTemplateID, BuiltInWorkflowTemplate.StableID.receipts)
        }
    }

    func testProfileFetch_BootstrapsRecommendedPolicyFromDestinationFallbackWhenWorkflowMemoryUnavailable() throws {
        try withService { context, service in
            let featureFlags = FeatureFlagService.shared
            featureFlags.resetToDefaults()
            defer { featureFlags.resetToDefaults() }
            featureFlags.setEnabled(.metadataFoundation, true)
            featureFlags.setEnabled(.autoProjectAssociation, true)
            featureFlags.setEnabled(.projectSpaces, true)
            featureFlags.setEnabled(.projectSpaceMemory, true)

            let metadataService = FileMetadataFoundationService(modelContext: context)
            let tempDirectory = try TemporaryDirectory()
            defer { tempDirectory.cleanup() }

            let timestamp = Date()
            let fileURL = try tempDirectory.createFile(name: "Inbox/alpha.txt", contents: "alpha")
            let record = try insertProjectSpaceRecord(
                using: metadataService,
                path: fileURL.path,
                projectAssociation: "Alpha",
                timestamp: timestamp
            )
            addHistory(
                in: context,
                to: record,
                eventKind: .organized,
                timestamp: timestamp.addingTimeInterval(-120),
                toPath: tempDirectory.url.appendingPathComponent("Projects/Alpha/alpha.txt").path,
                destinationDisplayName: "Alpha",
                detailsSummary: "Moved into Alpha."
            )
            addHistory(
                in: context,
                to: record,
                eventKind: .rekeyed,
                timestamp: timestamp.addingTimeInterval(-60),
                toPath: tempDirectory.url.appendingPathComponent("Projects/Alpha/alpha.txt").path,
                destinationDisplayName: "Alpha",
                detailsSummary: "Renamed into Alpha."
            )
            try context.save()

            let detail = try XCTUnwrap(metadataService.fetchProjectSpaceDetail(for: "Alpha"))
            XCTAssertEqual(detail.preferredDestinations.first?.destinationDisplayName, "Alpha")
            XCTAssertEqual(detail.preferredDestinations.first?.eventCount, 2)
            XCTAssertEqual(detail.recentActivity.count, 2)

            let projectedDetail = ProjectSpaceDetail(
                summary: detail.summary,
                files: detail.files,
                overview: detail.overview,
                preferredDestinations: detail.preferredDestinations,
                recentActivity: detail.recentActivity,
                workflowMemory: ProjectSpaceMemoryResolver().resolveWorkflowMemoryProjection(
                    for: detail,
                    profile: nil,
                    now: timestamp
                )
            )
            let recommendation = try XCTUnwrap(
                ProjectSpaceAutomationRecommendationService()
                    .recommendedPolicies(for: projectedDetail, now: timestamp)
                    .first
            )
            XCTAssertEqual(recommendation.workflowTemplateID, BuiltInWorkflowTemplate.StableID.projectDrop)
            XCTAssertEqual(recommendation.triggerKinds, [.manual])
            XCTAssertEqual(recommendation.admissionMode, .automatic)

            let profile = try XCTUnwrap(service.profile(normalizedProjectLabel: "Alpha"))
            let policy = try XCTUnwrap(context.fetch(FetchDescriptor<ProjectSpaceAutomationPolicy>()).first)

            XCTAssertEqual(profile.normalizedProjectLabel, "Alpha")
            XCTAssertEqual(profile.lastLegacyBootstrapAt, timestamp.addingTimeInterval(-60))
            XCTAssertEqual(policy.workflowTemplateID, BuiltInWorkflowTemplate.StableID.projectDrop)
            XCTAssertEqual(policy.triggerKinds, [.manual])
            XCTAssertEqual(policy.admissionMode, .automatic)
            XCTAssertEqual(policy.state, .recommended)
        }
    }

    func testCreatePolicy_PersistsTemplateTriggersAndAdmissionMode() throws {
        try withService { context, service in
            let timestamp = Date(timeIntervalSince1970: 2_000)

            let policy = try service.createOrUpdatePolicy(
                normalizedProjectLabel: " Alpha ",
                workflowTemplateID: " \(BuiltInWorkflowTemplate.StableID.receipts) ",
                triggerKinds: [.manual, .folderWatch, .scheduledSweep, .manual],
                admissionMode: .manualReview,
                state: .active,
                updatedAt: timestamp
            )

            let persistedPolicies = try context.fetch(FetchDescriptor<ProjectSpaceAutomationPolicy>())
            XCTAssertEqual(persistedPolicies.count, 1)

            let persistedPolicy = try XCTUnwrap(persistedPolicies.first)
            XCTAssertEqual(persistedPolicy.id, policy.id)
            XCTAssertEqual(persistedPolicy.workflowTemplateID, BuiltInWorkflowTemplate.StableID.receipts)
            XCTAssertEqual(persistedPolicy.triggerKinds, [.manual, .folderWatch, .scheduledSweep])
            XCTAssertEqual(persistedPolicy.triggerKindRaws, ["manual", "folderWatch", "scheduledSweep"])
            XCTAssertEqual(persistedPolicy.admissionMode, .manualReview)
            XCTAssertEqual(persistedPolicy.state, .active)
            XCTAssertEqual(persistedPolicy.updatedAt, timestamp)
        }
    }

    func testPoliciesMatchingTriggerKind_ReturnActivePoliciesGroupedByProjectLabel() throws {
        try withService { _, service in
            _ = try service.createOrUpdatePolicy(
                normalizedProjectLabel: "Alpha",
                workflowTemplateID: BuiltInWorkflowTemplate.StableID.projectDrop,
                triggerKinds: [.manual, .scheduledSweep],
                admissionMode: .manualReview,
                state: .active,
                updatedAt: Date(timeIntervalSince1970: 2_100)
            )
            _ = try service.createOrUpdatePolicy(
                normalizedProjectLabel: "Beta",
                workflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts,
                triggerKinds: [.scheduledSweep],
                admissionMode: .manualReview,
                state: .active,
                updatedAt: Date(timeIntervalSince1970: 2_200)
            )
            _ = try service.createOrUpdatePolicy(
                normalizedProjectLabel: "Gamma",
                workflowTemplateID: BuiltInWorkflowTemplate.StableID.screenshots,
                triggerKinds: [.manual],
                admissionMode: .manualReview,
                state: .paused,
                updatedAt: Date(timeIntervalSince1970: 2_300)
            )

            let matches = service.policies(
                matching: .manual,
                states: [.active, .recommended]
            )

            XCTAssertEqual(matches.map(\.normalizedProjectLabel), ["Alpha"])
            XCTAssertEqual(matches.map(\.policy.workflowTemplateID), [BuiltInWorkflowTemplate.StableID.projectDrop])
        }
    }

    func testPoliciesMatchingTriggerKind_CollapsesSameProjectToMostRecentActivePolicy() throws {
        try withService { _, service in
            _ = try service.createOrUpdatePolicy(
                normalizedProjectLabel: "Alpha",
                workflowTemplateID: BuiltInWorkflowTemplate.StableID.screenshots,
                triggerKinds: [.manual],
                admissionMode: .manualReview,
                state: .active,
                updatedAt: Date(timeIntervalSince1970: 2_050)
            )
            _ = try service.createOrUpdatePolicy(
                normalizedProjectLabel: "Alpha",
                workflowTemplateID: BuiltInWorkflowTemplate.StableID.projectDrop,
                triggerKinds: [.manual],
                admissionMode: .manualReview,
                state: .active,
                updatedAt: Date(timeIntervalSince1970: 2_150)
            )
            _ = try service.createOrUpdatePolicy(
                normalizedProjectLabel: "Beta",
                workflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts,
                triggerKinds: [.manual],
                admissionMode: .manualReview,
                state: .active,
                updatedAt: Date(timeIntervalSince1970: 2_250)
            )

            let matches = service.policies(
                matching: .manual,
                states: [.active]
            )

            XCTAssertEqual(matches.map(\.normalizedProjectLabel), ["Alpha", "Beta"])
            XCTAssertEqual(
                matches.map(\.policy.workflowTemplateID),
                [BuiltInWorkflowTemplate.StableID.projectDrop, BuiltInWorkflowTemplate.StableID.receipts]
            )
        }
    }

    func testCreatePolicy_BlankProjectLabelFailsClosedWithoutPersistingRows() throws {
        try withService { context, service in
            XCTAssertThrowsError(
                try service.createOrUpdatePolicy(
                    normalizedProjectLabel: "   ",
                    workflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts,
                    triggerKinds: [.manual],
                    admissionMode: .manualReview,
                    state: .active
                )
            )

            XCTAssertEqual(try context.fetch(FetchDescriptor<ProjectSpaceAutomationProfile>()).count, 0)
            XCTAssertEqual(try context.fetch(FetchDescriptor<ProjectSpaceAutomationPolicy>()).count, 0)
        }
    }

    func testPauseAndRevokePolicy_UpdateLifecycleWithoutDeletingRunHistory() throws {
        try withService { context, service in
            let createdAt = Date(timeIntervalSince1970: 3_000)
            let pausedAt = createdAt.addingTimeInterval(60)
            let revokedAt = pausedAt.addingTimeInterval(60)

            let policy = try service.createOrUpdatePolicy(
                normalizedProjectLabel: "Alpha",
                workflowTemplateID: BuiltInWorkflowTemplate.StableID.screenshots,
                triggerKinds: [.folderWatch],
                admissionMode: .automatic,
                state: .active,
                updatedAt: createdAt
            )

            let runRecord = ProjectSpaceAutomationRunRecord(
                policyID: policy.id,
                workflowTemplateID: policy.workflowTemplateID,
                triggerKind: .folderWatch,
                startedAt: createdAt.addingTimeInterval(10),
                endedAt: createdAt.addingTimeInterval(20)
            )
            context.insert(runRecord)
            try context.save()

            try service.pausePolicy(id: policy.id, at: pausedAt)
            try service.revokePolicy(id: policy.id, at: revokedAt)

            let persistedPolicy = try XCTUnwrap(context.fetch(FetchDescriptor<ProjectSpaceAutomationPolicy>()).first)
            XCTAssertEqual(persistedPolicy.state, .revoked)
            XCTAssertEqual(persistedPolicy.pausedAt, pausedAt)
            XCTAssertEqual(persistedPolicy.revokedAt, revokedAt)
            XCTAssertEqual(try context.fetch(FetchDescriptor<ProjectSpaceAutomationRunRecord>()).count, 1)
        }
    }

    func testActivatingPolicy_PausesSiblingActivePoliciesForSameProject() throws {
        try withService { context, service in
            let first = try service.createOrUpdatePolicy(
                normalizedProjectLabel: "Alpha",
                workflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts,
                triggerKinds: [.manual],
                admissionMode: .manualReview,
                state: .active,
                updatedAt: Date(timeIntervalSince1970: 3_100)
            )
            let second = try service.createOrUpdatePolicy(
                normalizedProjectLabel: "Alpha",
                workflowTemplateID: BuiltInWorkflowTemplate.StableID.projectDrop,
                triggerKinds: [.manual],
                admissionMode: .manualReview,
                state: .active,
                updatedAt: Date(timeIntervalSince1970: 3_200)
            )

            let policies = try context.fetch(FetchDescriptor<ProjectSpaceAutomationPolicy>())
            let persistedFirst = try XCTUnwrap(policies.first(where: { $0.id == first.id }))
            let persistedSecond = try XCTUnwrap(policies.first(where: { $0.id == second.id }))

            XCTAssertEqual(persistedFirst.state, .paused)
            XCTAssertEqual(persistedFirst.pausedAt, Date(timeIntervalSince1970: 3_200))
            XCTAssertEqual(persistedSecond.state, .active)
            XCTAssertNil(persistedSecond.pausedAt)
        }
    }

    func testCreatePolicy_TerminalStatesStampAndClearLifecycleMetadata() throws {
        try withService { context, service in
            let pausedAt = Date(timeIntervalSince1970: 4_000)
            let resumedAt = pausedAt.addingTimeInterval(60)
            let revokedAt = resumedAt.addingTimeInterval(60)

            let pausedPolicy = try service.createOrUpdatePolicy(
                normalizedProjectLabel: "Alpha",
                workflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts,
                triggerKinds: [.manual],
                admissionMode: .manualReview,
                state: .paused,
                updatedAt: pausedAt
            )

            XCTAssertEqual(pausedPolicy.state, .paused)
            XCTAssertEqual(pausedPolicy.pausedAt, pausedAt)
            XCTAssertNil(pausedPolicy.revokedAt)

            let resumedPolicy = try service.createOrUpdatePolicy(
                normalizedProjectLabel: "Alpha",
                workflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts,
                triggerKinds: [.manual],
                admissionMode: .manualReview,
                state: .active,
                updatedAt: resumedAt
            )

            XCTAssertEqual(resumedPolicy.state, .active)
            XCTAssertNil(resumedPolicy.pausedAt)
            XCTAssertNil(resumedPolicy.revokedAt)

            let revokedPolicy = try service.createOrUpdatePolicy(
                normalizedProjectLabel: "Alpha",
                workflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts,
                triggerKinds: [.manual],
                admissionMode: .manualReview,
                state: .revoked,
                updatedAt: revokedAt
            )

            XCTAssertEqual(revokedPolicy.state, .revoked)
            XCTAssertNil(revokedPolicy.pausedAt)
            XCTAssertEqual(revokedPolicy.revokedAt, revokedAt)

            let repausedAt = revokedAt.addingTimeInterval(60)
            let pausedAgainPolicy = try service.createOrUpdatePolicy(
                normalizedProjectLabel: "Alpha",
                workflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts,
                triggerKinds: [.manual],
                admissionMode: .manualReview,
                state: .paused,
                updatedAt: repausedAt
            )

            XCTAssertEqual(pausedAgainPolicy.state, .paused)
            XCTAssertEqual(pausedAgainPolicy.pausedAt, repausedAt)
            XCTAssertNil(pausedAgainPolicy.revokedAt)

            let revokedAfterPauseAt = repausedAt.addingTimeInterval(60)
            let revokedAfterPausePolicy = try service.createOrUpdatePolicy(
                normalizedProjectLabel: "Alpha",
                workflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts,
                triggerKinds: [.manual],
                admissionMode: .manualReview,
                state: .revoked,
                updatedAt: revokedAfterPauseAt
            )

            XCTAssertEqual(revokedAfterPausePolicy.state, .revoked)
            XCTAssertEqual(revokedAfterPausePolicy.pausedAt, repausedAt)
            XCTAssertEqual(revokedAfterPausePolicy.revokedAt, revokedAfterPauseAt)
        }
    }

    func testProfileFetch_BootstrapReusesSingleRecommendedPolicyWhenWorkflowMemoryTemplateChanges() throws {
        try withService { context, service in
            let firstTimestamp = Date().addingTimeInterval(-300)
            let secondTimestamp = firstTimestamp.addingTimeInterval(120)

            let workflowProfile = ProjectSpaceWorkflowProfile(
                normalizedProjectLabel: "Alpha",
                preferredWorkflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts,
                successfulTemplateID: BuiltInWorkflowTemplate.StableID.receipts,
                successfulTemplateCount: 3,
                successfulTemplateLastSucceededAt: firstTimestamp.addingTimeInterval(-60),
                dominantTriggerSurface: .projectPolicyManual,
                dominantTriggerSurfaceCount: 3,
                dominantTriggerSurfaceLastSeenAt: firstTimestamp.addingTimeInterval(-60),
                workflowMemoryStatus: .stable,
                updatedAt: firstTimestamp
            )
            context.insert(workflowProfile)
            try context.save()

            let firstProfile = try XCTUnwrap(service.profile(normalizedProjectLabel: "Alpha"))
            XCTAssertEqual(firstProfile.lastLegacyBootstrapAt, firstTimestamp.addingTimeInterval(-60))
            XCTAssertEqual(try context.fetch(FetchDescriptor<ProjectSpaceAutomationPolicy>()).count, 1)

            workflowProfile.successfulTemplateID = BuiltInWorkflowTemplate.StableID.projectDrop
            workflowProfile.successfulTemplateCount = 5
            workflowProfile.successfulTemplateLastSucceededAt = secondTimestamp.addingTimeInterval(-30)
            workflowProfile.dominantTriggerSurface = .projectPolicyScheduled
            workflowProfile.dominantTriggerSurfaceCount = 5
            workflowProfile.dominantTriggerSurfaceLastSeenAt = secondTimestamp.addingTimeInterval(-30)
            workflowProfile.updatedAt = secondTimestamp
            try context.save()

            let secondProfile = try XCTUnwrap(service.profile(normalizedProjectLabel: "Alpha"))
            let policies = try context.fetch(FetchDescriptor<ProjectSpaceAutomationPolicy>())

            XCTAssertEqual(secondProfile.id, firstProfile.id)
            XCTAssertEqual(secondProfile.lastLegacyBootstrapAt, secondTimestamp.addingTimeInterval(-30))
            XCTAssertEqual(policies.count, 1)

            let bridgedPolicy = try XCTUnwrap(policies.first)
            XCTAssertEqual(bridgedPolicy.workflowTemplateID, BuiltInWorkflowTemplate.StableID.projectDrop)
            XCTAssertEqual(bridgedPolicy.state, .recommended)
            XCTAssertEqual(bridgedPolicy.triggerKinds, [.scheduledSweep])
            XCTAssertEqual(bridgedPolicy.admissionMode, .automatic)
        }
    }

    func testProfileFetch_DoesNotCreateDuplicateBridgePolicyAfterWorkflowRecommendationBecomesActive() throws {
        try withService { context, service in
            let bootstrapAt = Date()
            let activatedAt = bootstrapAt.addingTimeInterval(60)

            let workflowProfile = ProjectSpaceWorkflowProfile(
                normalizedProjectLabel: "Alpha",
                preferredWorkflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts,
                successfulTemplateID: BuiltInWorkflowTemplate.StableID.receipts,
                successfulTemplateCount: 4,
                successfulTemplateLastSucceededAt: bootstrapAt.addingTimeInterval(-30),
                dominantTriggerSurface: .projectPolicyManual,
                dominantTriggerSurfaceCount: 4,
                dominantTriggerSurfaceLastSeenAt: bootstrapAt.addingTimeInterval(-30),
                workflowMemoryStatus: .stable,
                updatedAt: bootstrapAt
            )
            context.insert(workflowProfile)
            try context.save()

            _ = try XCTUnwrap(service.profile(normalizedProjectLabel: "Alpha"))
            let bridgedPolicy = try XCTUnwrap(context.fetch(FetchDescriptor<ProjectSpaceAutomationPolicy>()).first)
            XCTAssertEqual(bridgedPolicy.state, .recommended)

            let activatedPolicy = try service.createOrUpdatePolicy(
                normalizedProjectLabel: "Alpha",
                workflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts,
                triggerKinds: [.manual],
                admissionMode: .manualReview,
                state: .active,
                updatedAt: activatedAt
            )
            XCTAssertEqual(activatedPolicy.id, bridgedPolicy.id)
            XCTAssertEqual(activatedPolicy.state, .active)

            let profile = try XCTUnwrap(service.profile(normalizedProjectLabel: "Alpha"))
            let policies = try context.fetch(FetchDescriptor<ProjectSpaceAutomationPolicy>())

            XCTAssertEqual(profile.id, bridgedPolicy.profileID)
            XCTAssertEqual(policies.count, 1)

            let persistedPolicy = try XCTUnwrap(policies.first)
            XCTAssertEqual(persistedPolicy.id, bridgedPolicy.id)
            XCTAssertEqual(persistedPolicy.workflowTemplateID, BuiltInWorkflowTemplate.StableID.receipts)
            XCTAssertEqual(persistedPolicy.state, .active)
        }
    }

    func testProfileFetch_DoesNotRewriteMultipleRecommendedPoliciesWhenWorkflowRecommendationUnavailable() throws {
        try withService { context, service in
            let bootstrapAt = Date(timeIntervalSince1970: 6_500)
            let updateAt = bootstrapAt.addingTimeInterval(60)

            let legacyProfile = ProjectSpaceWorkflowProfile(
                normalizedProjectLabel: "Alpha",
                preferredWorkflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts,
                updatedAt: updateAt
            )
            context.insert(legacyProfile)

            let profile = ProjectSpaceAutomationProfile(
                normalizedProjectLabel: "Alpha",
                createdAt: bootstrapAt
            )
            context.insert(profile)

            let firstRecommended = ProjectSpaceAutomationPolicy(
                profileID: profile.id,
                workflowTemplateID: BuiltInWorkflowTemplate.StableID.projectDrop,
                triggerKinds: [.manual],
                admissionMode: .manualReview,
                state: .recommended,
                createdAt: bootstrapAt
            )
            let secondRecommended = ProjectSpaceAutomationPolicy(
                profileID: profile.id,
                workflowTemplateID: BuiltInWorkflowTemplate.StableID.screenshots,
                triggerKinds: [.manual],
                admissionMode: .manualReview,
                state: .recommended,
                createdAt: bootstrapAt.addingTimeInterval(1)
            )
            context.insert(firstRecommended)
            context.insert(secondRecommended)
            try context.save()

            let resolvedProfile = try XCTUnwrap(service.profile(normalizedProjectLabel: "Alpha"))
            let policies = try context.fetch(FetchDescriptor<ProjectSpaceAutomationPolicy>())

            XCTAssertEqual(resolvedProfile.id, profile.id)
            XCTAssertNil(resolvedProfile.lastLegacyBootstrapAt)
            XCTAssertEqual(policies.count, 2)
            XCTAssertEqual(
                Set(policies.map(\.workflowTemplateID)),
                Set([
                    BuiltInWorkflowTemplate.StableID.projectDrop,
                    BuiltInWorkflowTemplate.StableID.screenshots
                ])
            )
        }
    }

    func testProjectSpaceAutomationFeatureDependsOnProjectMemoryWorkflowAndAutomationFlags() {
        let featureFlags = FeatureFlagService.shared
        featureFlags.resetToDefaults()
        defer { featureFlags.resetToDefaults() }

        XCTAssertFalse(FeatureFlagService.Feature.projectSpaceAutomationBoard.defaultValue)
        XCTAssertFalse(featureFlags.isEnabled(.projectSpaceAutomationBoard))

        featureFlags.setEnabled(.projectSpaceAutomationBoard, true)
        XCTAssertFalse(featureFlags.isEnabled(.projectSpaceAutomationBoard))

        featureFlags.setEnabled(.metadataFoundation, true)
        featureFlags.setEnabled(.autoProjectAssociation, true)
        featureFlags.setEnabled(.projectSpaces, true)
        featureFlags.setEnabled(.projectSpaceMemory, true)
        featureFlags.setEnabled(.workflowEngineV2, true)
        featureFlags.setEnabled(.backgroundMonitoring, true)
        featureFlags.setEnabled(.autoOrganize, true)

        XCTAssertTrue(featureFlags.isEnabled(.projectSpaceAutomationBoard))

        featureFlags.setEnabled(.projectSpaceMemory, false)
        XCTAssertFalse(featureFlags.isEnabled(.projectSpaceAutomationBoard))
    }
}
