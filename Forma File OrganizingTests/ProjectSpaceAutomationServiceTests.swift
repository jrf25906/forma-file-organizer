import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class ProjectSpaceAutomationServiceTests: XCTestCase {
    private func makeService() throws -> (ModelContainer, ModelContext, ProjectSpaceAutomationService) {
        let schema = Schema([
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

    func testProfileFetch_BootstrapsRecommendedPolicyFromLegacyWorkflowProfile() throws {
        try withService { context, service in
            let legacyProfile = ProjectSpaceWorkflowProfile(
                normalizedProjectLabel: " Alpha ",
                preferredWorkflowTemplateID: " \(BuiltInWorkflowTemplate.StableID.projectDrop) ",
                updatedAt: Date(timeIntervalSince1970: 1_000)
            )
            context.insert(legacyProfile)
            try context.save()

            let profile = try XCTUnwrap(service.profile(normalizedProjectLabel: "Alpha"))
            let policies = try context.fetch(FetchDescriptor<ProjectSpaceAutomationPolicy>())

            XCTAssertEqual(profile.normalizedProjectLabel, "Alpha")
            XCTAssertEqual(policies.count, 1)

            let policy = try XCTUnwrap(policies.first)
            XCTAssertEqual(policy.profileID, profile.id)
            XCTAssertEqual(policy.workflowTemplateID, BuiltInWorkflowTemplate.StableID.projectDrop)
            XCTAssertEqual(policy.state, .recommended)
            XCTAssertEqual(policy.triggerKinds, [.manual])

            let preservedLegacyProfile = try XCTUnwrap(
                context.fetch(FetchDescriptor<ProjectSpaceWorkflowProfile>()).first
            )
            XCTAssertEqual(preservedLegacyProfile.preferredWorkflowTemplateID, BuiltInWorkflowTemplate.StableID.projectDrop)
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
        }
    }

    func testProfileFetch_BootstrapReusesSingleRecommendedPolicyWhenLegacyTemplateChanges() throws {
        try withService { context, service in
            let firstTimestamp = Date(timeIntervalSince1970: 5_000)
            let secondTimestamp = firstTimestamp.addingTimeInterval(120)

            let legacyProfile = ProjectSpaceWorkflowProfile(
                normalizedProjectLabel: "Alpha",
                preferredWorkflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts,
                updatedAt: firstTimestamp
            )
            context.insert(legacyProfile)
            try context.save()

            let firstProfile = try XCTUnwrap(service.profile(normalizedProjectLabel: "Alpha"))
            XCTAssertEqual(firstProfile.lastLegacyBootstrapAt, firstTimestamp)
            XCTAssertEqual(try context.fetch(FetchDescriptor<ProjectSpaceAutomationPolicy>()).count, 1)

            legacyProfile.preferredWorkflowTemplateID = BuiltInWorkflowTemplate.StableID.projectDrop
            legacyProfile.updatedAt = secondTimestamp
            try context.save()

            let secondProfile = try XCTUnwrap(service.profile(normalizedProjectLabel: "Alpha"))
            let policies = try context.fetch(FetchDescriptor<ProjectSpaceAutomationPolicy>())

            XCTAssertEqual(secondProfile.id, firstProfile.id)
            XCTAssertEqual(secondProfile.lastLegacyBootstrapAt, secondTimestamp)
            XCTAssertEqual(policies.count, 1)

            let bridgedPolicy = try XCTUnwrap(policies.first)
            XCTAssertEqual(bridgedPolicy.workflowTemplateID, BuiltInWorkflowTemplate.StableID.projectDrop)
            XCTAssertEqual(bridgedPolicy.state, .recommended)
            XCTAssertEqual(bridgedPolicy.triggerKinds, [.manual])
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
