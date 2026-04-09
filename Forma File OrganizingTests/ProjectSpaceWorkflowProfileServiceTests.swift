import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class ProjectSpaceWorkflowProfileServiceTests: XCTestCase {
    private func makeService() throws -> (ModelContainer, ModelContext, ProjectSpaceWorkflowProfileService) {
        let schema = Schema([
            ProjectSpaceWorkflowProfile.self,
            ProjectSpaceAutomationProfile.self,
            ProjectSpaceAutomationPolicy.self,
            ProjectSpaceAutomationRunRecord.self,
            WorkflowRunRecord.self,
            WorkflowFileActionRecord.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        return (container, context, ProjectSpaceWorkflowProfileService(modelContext: context))
    }

    private func withService(
        _ body: (_ context: ModelContext, _ service: ProjectSpaceWorkflowProfileService) throws -> Void
    ) throws {
        let (container, context, service) = try makeService()
        try withExtendedLifetime(container) {
            try body(context, service)
        }
    }

    func testProfileReturnsNilAndDoesNotCreateRowOnMiss() throws {
        try withService { context, service in
            XCTAssertNil(service.profile(normalizedProjectLabel: "  Alpha  "))
            XCTAssertEqual(try context.fetch(FetchDescriptor<ProjectSpaceWorkflowProfile>()).count, 0)
        }
    }

    func testUpsertPreferredTemplateCreatesRowLazilyAndNormalizesLabel() throws {
        try withService { context, service in
            let timestamp = Date(timeIntervalSince1970: 1_000)

            try service.upsertPreferredTemplate(
                " builtin.workflow.receipts.v1 ",
                for: " Alpha ",
                at: timestamp
            )

            let profiles = try context.fetch(FetchDescriptor<ProjectSpaceWorkflowProfile>())
            XCTAssertEqual(profiles.count, 1)

            let profile = try XCTUnwrap(profiles.first)
            XCTAssertEqual(profile.normalizedProjectLabel, "Alpha")
            XCTAssertEqual(profile.preferredWorkflowTemplateID, "builtin.workflow.receipts.v1")
            XCTAssertEqual(profile.updatedAt, timestamp)

            let reloaded = try XCTUnwrap(service.profile(normalizedProjectLabel: "Alpha"))
            XCTAssertEqual(reloaded.id, profile.id)
            XCTAssertEqual(reloaded.preferredWorkflowTemplateID, "builtin.workflow.receipts.v1")
        }
    }

    func testUpsertPreferredTemplateNilOnMissDoesNotCreateRow() throws {
        try withService { context, service in
            try service.upsertPreferredTemplate(nil, for: "Alpha", at: Date(timeIntervalSince1970: 1_000))

            XCTAssertEqual(try context.fetch(FetchDescriptor<ProjectSpaceWorkflowProfile>()).count, 0)
            XCTAssertNil(service.profile(normalizedProjectLabel: "Alpha"))
        }
    }

    func testClearingPreferredTemplateDeletesEmptyProfileWhenNoLatestRunExists() throws {
        try withService { context, service in
            let timestamp = Date(timeIntervalSince1970: 1_000)
            try service.upsertPreferredTemplate(
                "builtin.workflow.receipts.v1",
                for: "Alpha",
                at: timestamp
            )

            try service.upsertPreferredTemplate(nil, for: " Alpha ", at: timestamp.addingTimeInterval(60))

            XCTAssertEqual(try context.fetch(FetchDescriptor<ProjectSpaceWorkflowProfile>()).count, 0)
            XCTAssertNil(service.profile(normalizedProjectLabel: "Alpha"))
        }
    }

    func testClearingPreferredTemplate_PreservesRunDerivedMemoryFacts() throws {
        try withService { context, service in
            let initialTimestamp = Date(timeIntervalSince1970: 1_500)
            try service.upsertPreferredTemplate(
                BuiltInWorkflowTemplate.StableID.projectDrop,
                for: "Alpha",
                at: initialTimestamp
            )

            let run = WorkflowRunRecord(
                scopeID: UUID(),
                workflowTemplateID: BuiltInWorkflowTemplate.StableID.projectDrop,
                triggerSurface: .projectPolicyManual,
                primaryStatus: .succeeded,
                startedAt: Date(timeIntervalSince1970: 1_600),
                endedAt: Date(timeIntervalSince1970: 1_610)
            )
            context.insert(run)
            context.insert(
                WorkflowFileActionRecord(
                    runID: run.id,
                    fileIdentity: "resource|diskA|preferred-clear-file-001",
                    sourcePath: "/Users/example/Inbox/file.pdf",
                    destinationPath: "/Users/example/Projects/Alpha/file.pdf",
                    disposition: .moved,
                    recordedAt: Date(timeIntervalSince1970: 1_609)
                )
            )
            try context.save()
            try service.recordLatestRun(run, for: "Alpha", at: Date(timeIntervalSince1970: 1_611))

            try service.upsertPreferredTemplate(nil, for: "Alpha", at: Date(timeIntervalSince1970: 1_620))

            let profile = try XCTUnwrap(service.profile(normalizedProjectLabel: "Alpha"))
            XCTAssertNil(profile.preferredWorkflowTemplateID)
            XCTAssertEqual(profile.successfulTemplateID, BuiltInWorkflowTemplate.StableID.projectDrop)
            XCTAssertEqual(profile.successfulTemplateCount, 1)
            XCTAssertEqual(profile.dominantTriggerSurface, .projectPolicyManual)
            XCTAssertEqual(profile.dominantTriggerSurfaceCount, 1)
            XCTAssertEqual(profile.latestSuccessfulDestinationSignal, "/Users/example/Projects/Alpha/file.pdf")
            XCTAssertEqual(profile.workflowMemoryStatus, .stable)
        }
    }

    func testProfileReusesExistingRecordForWhitespaceVariants() throws {
        try withService { context, service in
            let timestamp = Date(timeIntervalSince1970: 1_000)

            try service.upsertPreferredTemplate(
                "builtin.workflow.receipts.v1",
                for: "Alpha",
                at: timestamp
            )

            let first = try XCTUnwrap(service.profile(normalizedProjectLabel: "Alpha"))
            let second = try XCTUnwrap(service.profile(normalizedProjectLabel: " Alpha "))

            XCTAssertEqual(first.id, second.id)
            XCTAssertEqual(try context.fetch(FetchDescriptor<ProjectSpaceWorkflowProfile>()).count, 1)
        }
    }

    func testRecordLatestRunLinksLatestRunForTheSameProjectLabel() throws {
        try withService { context, service in
            let timestamp = Date(timeIntervalSince1970: 2_000)
            let runEndedAt = Date(timeIntervalSince1970: 1_950)
            let run = WorkflowRunRecord(
                scopeID: UUID(),
                workflowTemplateID: "builtin.workflow.project-drop.v1",
                primaryStatus: .succeeded,
                startedAt: Date(timeIntervalSince1970: 1_900),
                endedAt: runEndedAt
            )
            context.insert(run)

            try service.recordLatestRun(run, for: "Alpha", at: timestamp)

            let profile = try XCTUnwrap(service.profile(normalizedProjectLabel: "Alpha"))

            XCTAssertEqual(profile.lastWorkflowRunID, run.id)
            XCTAssertEqual(profile.lastWorkflowCompletedAt, runEndedAt)
            XCTAssertEqual(profile.updatedAt, timestamp)
        }
    }

    func testRecordLatestRunPreservesPreferredTemplate() throws {
        try withService { context, service in
            let timestamp = Date(timeIntervalSince1970: 3_000)
            try service.upsertPreferredTemplate(
                "builtin.workflow.screenshots.v1",
                for: "Alpha",
                at: timestamp
            )

            let run = WorkflowRunRecord(
                scopeID: UUID(),
                workflowTemplateID: "builtin.workflow.project-drop.v1",
                primaryStatus: .succeeded,
                startedAt: Date(timeIntervalSince1970: 2_900),
                endedAt: Date(timeIntervalSince1970: 2_950)
            )
            context.insert(run)

            try service.recordLatestRun(run, for: "Alpha", at: timestamp.addingTimeInterval(60))

            let profile = try XCTUnwrap(service.profile(normalizedProjectLabel: "Alpha"))

            XCTAssertEqual(profile.preferredWorkflowTemplateID, "builtin.workflow.screenshots.v1")
            XCTAssertEqual(profile.lastWorkflowRunID, run.id)
            XCTAssertEqual(profile.lastWorkflowCompletedAt, Date(timeIntervalSince1970: 2_950))
        }
    }

    func testPreferredTemplateBootstrapCandidate_NormalizesTemplateWithoutMutatingLegacyProfile() throws {
        try withService { context, service in
            let timestamp = Date(timeIntervalSince1970: 4_000)
            try service.upsertPreferredTemplate(
                " \(BuiltInWorkflowTemplate.StableID.projectDrop) ",
                for: " Alpha ",
                at: timestamp
            )

            let candidate = service.preferredTemplateBootstrapCandidate(normalizedProjectLabel: "Alpha")
            XCTAssertEqual(candidate?.templateID, BuiltInWorkflowTemplate.StableID.projectDrop)
            XCTAssertEqual(candidate?.updatedAt, timestamp)

            let profiles = try context.fetch(FetchDescriptor<ProjectSpaceWorkflowProfile>())
            XCTAssertEqual(profiles.count, 1)
            XCTAssertEqual(profiles.first?.preferredWorkflowTemplateID, BuiltInWorkflowTemplate.StableID.projectDrop)
        }
    }

    func testProfileService_MigratesLegacyPreferredTemplateAndLatestRun() throws {
        try withService { context, service in
            let legacyRunID = UUID()
            let legacyCompletedAt = Date(timeIntervalSince1970: 1_000)
            let legacyProfile = ProjectSpaceWorkflowProfile(
                normalizedProjectLabel: " Alpha ",
                preferredWorkflowTemplateID: " \(BuiltInWorkflowTemplate.StableID.projectDrop) ",
                lastWorkflowRunID: legacyRunID,
                lastWorkflowCompletedAt: legacyCompletedAt,
                workflowMemoryStatus: nil,
                workflowMemorySchemaVersion: nil,
                updatedAt: Date(timeIntervalSince1970: 1_100)
            )
            context.insert(legacyProfile)
            try context.save()

            let run = WorkflowRunRecord(
                scopeID: UUID(),
                workflowTemplateID: " \(BuiltInWorkflowTemplate.StableID.projectDrop) ",
                triggerSurface: .projectPolicyManual,
                primaryStatus: .succeeded,
                startedAt: Date(timeIntervalSince1970: 1_200),
                endedAt: Date(timeIntervalSince1970: 1_250)
            )
            context.insert(run)
            context.insert(
                WorkflowFileActionRecord(
                    runID: run.id,
                    fileIdentity: "resource|diskA|legacy-file-001",
                    sourcePath: "/Users/example/Inbox/legacy.pdf",
                    destinationPath: "/Users/example/Projects/Alpha/legacy.pdf",
                    disposition: .moved,
                    recordedAt: Date(timeIntervalSince1970: 1_245)
                )
            )
            try context.save()

            try service.recordLatestRun(run, for: "Alpha", at: Date(timeIntervalSince1970: 1_260))

            let profile = try XCTUnwrap(service.profile(normalizedProjectLabel: "Alpha"))
            XCTAssertEqual(profile.preferredWorkflowTemplateID, BuiltInWorkflowTemplate.StableID.projectDrop)
            XCTAssertEqual(profile.lastWorkflowRunID, run.id)
            XCTAssertEqual(profile.lastWorkflowCompletedAt, Date(timeIntervalSince1970: 1_250))

            XCTAssertEqual(profile.successfulTemplateID, BuiltInWorkflowTemplate.StableID.projectDrop)
            XCTAssertGreaterThanOrEqual(profile.successfulTemplateCount, 1)
            XCTAssertEqual(profile.successfulTemplateLastSucceededAt, Date(timeIntervalSince1970: 1_250))
            XCTAssertEqual(profile.dominantTriggerSurface, .projectPolicyManual)
            XCTAssertEqual(profile.latestSuccessfulDestinationSignal, "/Users/example/Projects/Alpha/legacy.pdf")
            XCTAssertEqual(profile.workflowMemoryStatus, .stable)
        }
    }

    func testProfileService_LegacyRunEvidenceHydratesBeforePreferredTemplateMutation() throws {
        try withService { context, service in
            let legacyRunID = UUID()
            let legacyCompletedAt = Date(timeIntervalSince1970: 1_700)
            let legacyTemplate = BuiltInWorkflowTemplate.StableID.projectDrop
            let userUpdatedTemplate = BuiltInWorkflowTemplate.StableID.receipts

            let legacyRun = WorkflowRunRecord(
                id: legacyRunID,
                scopeID: UUID(),
                workflowTemplateID: legacyTemplate,
                triggerSurface: .projectPolicyManual,
                primaryStatus: .succeeded,
                startedAt: Date(timeIntervalSince1970: 1_650),
                endedAt: legacyCompletedAt
            )
            context.insert(legacyRun)

            let legacyProfile = ProjectSpaceWorkflowProfile(
                normalizedProjectLabel: "Alpha",
                preferredWorkflowTemplateID: " \(legacyTemplate) ",
                lastWorkflowRunID: legacyRunID,
                lastWorkflowCompletedAt: legacyCompletedAt,
                workflowMemoryStatus: nil,
                workflowMemorySchemaVersion: nil,
                updatedAt: Date(timeIntervalSince1970: 1_750)
            )
            context.insert(legacyProfile)
            try context.save()

            try service.upsertPreferredTemplate(
                userUpdatedTemplate,
                for: "Alpha",
                at: Date(timeIntervalSince1970: 1_800)
            )

            let run = WorkflowRunRecord(
                scopeID: UUID(),
                workflowTemplateID: userUpdatedTemplate,
                triggerSurface: .projectPolicyManual,
                primaryStatus: .failed,
                startedAt: Date(timeIntervalSince1970: 1_810),
                endedAt: Date(timeIntervalSince1970: 1_820)
            )
            context.insert(run)
            try context.save()

            try service.recordLatestRun(run, for: "Alpha", at: Date(timeIntervalSince1970: 1_825))

            let profile = try XCTUnwrap(service.profile(normalizedProjectLabel: "Alpha"))
            XCTAssertEqual(profile.preferredWorkflowTemplateID, userUpdatedTemplate)
            XCTAssertEqual(profile.successfulTemplateID, legacyTemplate)
            XCTAssertEqual(profile.successfulTemplateLastSucceededAt, legacyCompletedAt)
            XCTAssertGreaterThanOrEqual(profile.successfulTemplateCount, 1)
        }
    }

    func testProfileService_LegacyFailedLatestRun_DoesNotBackfillSuccessMemory() throws {
        try withService { context, service in
            let legacyRunID = UUID()
            let legacyTemplate = BuiltInWorkflowTemplate.StableID.projectDrop

            let failedLegacyRun = WorkflowRunRecord(
                id: legacyRunID,
                scopeID: UUID(),
                workflowTemplateID: legacyTemplate,
                triggerSurface: .projectPolicyManual,
                primaryStatus: .failed,
                startedAt: Date(timeIntervalSince1970: 1_850),
                endedAt: Date(timeIntervalSince1970: 1_900)
            )
            context.insert(failedLegacyRun)

            let legacyProfile = ProjectSpaceWorkflowProfile(
                normalizedProjectLabel: "Alpha",
                preferredWorkflowTemplateID: " \(legacyTemplate) ",
                lastWorkflowRunID: legacyRunID,
                lastWorkflowCompletedAt: Date(timeIntervalSince1970: 1_900),
                workflowMemoryStatus: nil,
                workflowMemorySchemaVersion: nil,
                updatedAt: Date(timeIntervalSince1970: 1_950)
            )
            context.insert(legacyProfile)
            try context.save()

            try service.upsertPreferredTemplate(legacyTemplate, for: "Alpha", at: Date(timeIntervalSince1970: 2_000))

            let profile = try XCTUnwrap(service.profile(normalizedProjectLabel: "Alpha"))
            XCTAssertEqual(profile.preferredWorkflowTemplateID, legacyTemplate)
            XCTAssertNil(profile.successfulTemplateID)
            XCTAssertEqual(profile.successfulTemplateCount, 0)
            XCTAssertNil(profile.successfulTemplateLastSucceededAt)
        }
    }

    func testProfileService_LegacySuccessfulRun_UsesRunTemplateForSuccessBackfill() throws {
        try withService { context, service in
            let successfulLegacyRunID = UUID()
            let successfulRunTemplate = BuiltInWorkflowTemplate.StableID.projectDrop
            let changedPreferredTemplate = BuiltInWorkflowTemplate.StableID.receipts
            let successfulRunEndedAt = Date(timeIntervalSince1970: 2_100)

            let successfulLegacyRun = WorkflowRunRecord(
                id: successfulLegacyRunID,
                scopeID: UUID(),
                workflowTemplateID: successfulRunTemplate,
                triggerSurface: .projectPolicyManual,
                primaryStatus: .succeeded,
                startedAt: Date(timeIntervalSince1970: 2_050),
                endedAt: successfulRunEndedAt
            )
            context.insert(successfulLegacyRun)

            let legacyProfile = ProjectSpaceWorkflowProfile(
                normalizedProjectLabel: "Alpha",
                preferredWorkflowTemplateID: changedPreferredTemplate,
                lastWorkflowRunID: successfulLegacyRunID,
                lastWorkflowCompletedAt: successfulRunEndedAt,
                workflowMemoryStatus: nil,
                workflowMemorySchemaVersion: nil,
                updatedAt: Date(timeIntervalSince1970: 2_120)
            )
            context.insert(legacyProfile)
            try context.save()

            try service.upsertPreferredTemplate(changedPreferredTemplate, for: "Alpha", at: Date(timeIntervalSince1970: 2_130))

            let profile = try XCTUnwrap(service.profile(normalizedProjectLabel: "Alpha"))
            XCTAssertEqual(profile.preferredWorkflowTemplateID, changedPreferredTemplate)
            XCTAssertEqual(profile.successfulTemplateID, successfulRunTemplate)
            XCTAssertEqual(profile.successfulTemplateCount, 1)
            XCTAssertEqual(profile.successfulTemplateLastSucceededAt, successfulRunEndedAt)
        }
    }

    func testProfileService_RepeatedSuccessfulRuns_StrengthenDominantTemplateMemory() throws {
        try withService { context, service in
            let projectLabel = "Alpha"
            let templateID = BuiltInWorkflowTemplate.StableID.projectDrop

            let runA = WorkflowRunRecord(
                scopeID: UUID(),
                workflowTemplateID: " \(templateID) ",
                triggerSurface: .projectPolicyManual,
                primaryStatus: .succeeded,
                startedAt: Date(timeIntervalSince1970: 2_000),
                endedAt: Date(timeIntervalSince1970: 2_010)
            )
            context.insert(runA)
            context.insert(
                WorkflowFileActionRecord(
                    runID: runA.id,
                    fileIdentity: "resource|diskA|alpha-file-001",
                    sourcePath: "/Users/example/Inbox/A.pdf",
                    destinationPath: "/Users/example/Projects/Alpha/A.pdf",
                    disposition: .moved,
                    recordedAt: Date(timeIntervalSince1970: 2_009)
                )
            )
            try context.save()
            try service.recordLatestRun(runA, for: projectLabel, at: Date(timeIntervalSince1970: 2_011))

            let runB = WorkflowRunRecord(
                scopeID: UUID(),
                workflowTemplateID: templateID,
                triggerSurface: .projectPolicyManual,
                primaryStatus: .succeeded,
                startedAt: Date(timeIntervalSince1970: 2_100),
                endedAt: Date(timeIntervalSince1970: 2_110)
            )
            context.insert(runB)
            context.insert(
                WorkflowFileActionRecord(
                    runID: runB.id,
                    fileIdentity: "resource|diskA|alpha-file-002",
                    sourcePath: "/Users/example/Inbox/B.pdf",
                    destinationPath: "/Users/example/Projects/Alpha/B.pdf",
                    disposition: .moved,
                    recordedAt: Date(timeIntervalSince1970: 2_109)
                )
            )
            try context.save()
            try service.recordLatestRun(runB, for: " Alpha ", at: Date(timeIntervalSince1970: 2_111))

            let runC = WorkflowRunRecord(
                scopeID: UUID(),
                workflowTemplateID: templateID,
                triggerSurface: .projectPolicyManual,
                primaryStatus: .succeeded,
                startedAt: Date(timeIntervalSince1970: 2_200),
                endedAt: Date(timeIntervalSince1970: 2_210)
            )
            context.insert(runC)
            context.insert(
                WorkflowFileActionRecord(
                    runID: runC.id,
                    fileIdentity: "resource|diskA|alpha-file-003",
                    sourcePath: "/Users/example/Inbox/C.pdf",
                    destinationPath: "/Users/example/Projects/Alpha/C.pdf",
                    disposition: .moved,
                    recordedAt: Date(timeIntervalSince1970: 2_209)
                )
            )
            try context.save()
            try service.recordLatestRun(runC, for: projectLabel, at: Date(timeIntervalSince1970: 2_211))

            let profile = try XCTUnwrap(service.profile(normalizedProjectLabel: projectLabel))
            XCTAssertEqual(profile.successfulTemplateID, templateID)
            XCTAssertEqual(profile.successfulTemplateCount, 3)
            XCTAssertEqual(profile.successfulTemplateLastSucceededAt, Date(timeIntervalSince1970: 2_210))
            XCTAssertEqual(profile.dominantTriggerSurface, .projectPolicyManual)
            XCTAssertEqual(profile.dominantTriggerSurfaceCount, 3)
            XCTAssertEqual(profile.latestSuccessfulDestinationSignal, "/Users/example/Projects/Alpha/C.pdf")
            XCTAssertEqual(profile.latestSuccessfulDestinationAt, Date(timeIntervalSince1970: 2_210))
            XCTAssertEqual(profile.workflowMemoryStatus, .stable)
        }
    }

    func testProfileService_CompletedWithIssues_UsesSuccessfulDestinationActionSignal() throws {
        try withService { context, service in
            let run = WorkflowRunRecord(
                scopeID: UUID(),
                workflowTemplateID: BuiltInWorkflowTemplate.StableID.projectDrop,
                triggerSurface: .projectPolicyManual,
                primaryStatus: .completedWithIssues,
                startedAt: Date(timeIntervalSince1970: 2_500),
                endedAt: Date(timeIntervalSince1970: 2_520)
            )
            context.insert(run)
            context.insert(
                WorkflowFileActionRecord(
                    runID: run.id,
                    fileIdentity: "resource|diskA|destination-success-file",
                    sourcePath: "/Users/example/Inbox/source.txt",
                    destinationPath: "/Users/example/Projects/Alpha/source.txt",
                    disposition: .moved,
                    recordedAt: Date(timeIntervalSince1970: 2_510)
                )
            )
            context.insert(
                WorkflowFileActionRecord(
                    runID: run.id,
                    fileIdentity: "resource|diskA|side-effect-failure-file",
                    sourcePath: "/Users/example/Inbox/source.txt",
                    destinationPath: "/Users/example/Projects/Alpha/incorrect-side-effect.txt",
                    disposition: .failed,
                    failureReason: "Notification delivery failed",
                    recordedAt: Date(timeIntervalSince1970: 2_519)
                )
            )
            try context.save()

            try service.recordLatestRun(run, for: "Alpha", at: Date(timeIntervalSince1970: 2_521))

            let profile = try XCTUnwrap(service.profile(normalizedProjectLabel: "Alpha"))
            XCTAssertEqual(profile.latestSuccessfulDestinationSignal, "/Users/example/Projects/Alpha/source.txt")
        }
    }

    func testProfileService_ConflictingRecentRuns_MarkProfileConflicted() throws {
        try withService { context, service in
            let firstRun = WorkflowRunRecord(
                scopeID: UUID(),
                workflowTemplateID: BuiltInWorkflowTemplate.StableID.projectDrop,
                triggerSurface: .projectPolicyManual,
                primaryStatus: .succeeded,
                startedAt: Date(timeIntervalSince1970: 3_000),
                endedAt: Date(timeIntervalSince1970: 3_010)
            )
            context.insert(firstRun)
            context.insert(
                WorkflowFileActionRecord(
                    runID: firstRun.id,
                    fileIdentity: "resource|diskA|conflict-file-001",
                    sourcePath: "/Users/example/Inbox/A.txt",
                    destinationPath: "/Users/example/Projects/Alpha/A.txt",
                    disposition: .moved,
                    recordedAt: Date(timeIntervalSince1970: 3_009)
                )
            )
            try context.save()
            try service.recordLatestRun(firstRun, for: "Alpha", at: Date(timeIntervalSince1970: 3_011))

            let secondRun = WorkflowRunRecord(
                scopeID: UUID(),
                workflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts,
                triggerSurface: .projectPolicyScheduled,
                primaryStatus: .succeeded,
                startedAt: Date(timeIntervalSince1970: 3_040),
                endedAt: Date(timeIntervalSince1970: 3_050)
            )
            context.insert(secondRun)
            context.insert(
                WorkflowFileActionRecord(
                    runID: secondRun.id,
                    fileIdentity: "resource|diskA|conflict-file-002",
                    sourcePath: "/Users/example/Inbox/B.txt",
                    destinationPath: "/Users/example/Documents/Receipts/B.txt",
                    disposition: .moved,
                    recordedAt: Date(timeIntervalSince1970: 3_049)
                )
            )
            try context.save()
            try service.recordLatestRun(secondRun, for: "Alpha", at: Date(timeIntervalSince1970: 3_051))

            let profile = try XCTUnwrap(service.profile(normalizedProjectLabel: "Alpha"))
            XCTAssertEqual(profile.workflowMemoryStatus, .conflicted)
            XCTAssertEqual(profile.lastWorkflowRunID, secondRun.id)
            XCTAssertEqual(profile.lastWorkflowCompletedAt, Date(timeIntervalSince1970: 3_050))
            XCTAssertEqual(profile.latestSuccessfulDestinationSignal, "/Users/example/Documents/Receipts/B.txt")
            XCTAssertEqual(profile.successfulTemplateID, BuiltInWorkflowTemplate.StableID.projectDrop)
            XCTAssertEqual(profile.successfulTemplateCount, 1)
            XCTAssertEqual(profile.dominantTriggerSurface, .projectPolicyManual)
            XCTAssertEqual(profile.dominantTriggerSurfaceCount, 1)
        }
    }

    func testClearingPreferredTemplate_DoesNotBackfillSuccessMemoryWithoutRunEvidence() throws {
        try withService { context, service in
            let legacyProfile = ProjectSpaceWorkflowProfile(
                normalizedProjectLabel: "Alpha",
                preferredWorkflowTemplateID: " \(BuiltInWorkflowTemplate.StableID.projectDrop) ",
                workflowMemoryStatus: nil,
                workflowMemorySchemaVersion: nil,
                updatedAt: Date(timeIntervalSince1970: 3_500)
            )
            context.insert(legacyProfile)
            try context.save()

            try service.upsertPreferredTemplate(nil, for: "Alpha", at: Date(timeIntervalSince1970: 3_600))

            XCTAssertNil(service.profile(normalizedProjectLabel: "Alpha"))
        }
    }
}
