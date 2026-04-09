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
            WorkflowRunRecord.self
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
}
