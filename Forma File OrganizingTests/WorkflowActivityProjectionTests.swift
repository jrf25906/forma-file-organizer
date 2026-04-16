import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class WorkflowActivityProjectionTests: XCTestCase {

    private func makeContainer() throws -> (ModelContainer, ModelContext) {
        let schema = Schema([
            ActivityItem.self,
            WorkflowRunRecord.self,
            WorkflowStepRunRecord.self,
            WorkflowFileActionRecord.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return (container, container.mainContext)
    }

    func testWorkflowRunProjection_UsesTemplateAwareActivityCopy() throws {
        let (container, context) = try makeContainer()
        let store = WorkflowAuditStore(modelContext: context)
        let service = ActivityLoggingService(modelContext: context)

        try withExtendedLifetime(container) {
            let baseTimestamp = Date().addingTimeInterval(-60)
            let run = try store.createRun(
                scopeID: UUID(),
                workflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts,
                startedAt: baseTimestamp,
                primaryStatus: .succeeded
            )
            try store.updateRunStatus(
                runID: run.id,
                primaryStatus: .succeeded,
                endedAt: baseTimestamp.addingTimeInterval(30)
            )

            service.logWorkflowRunSummary(
                run: run,
                triggerSurface: .inspector,
                affectedFileCount: 2
            )

            let activity = try XCTUnwrap(context.fetch(FetchDescriptor<ActivityItem>()).last)
            let projection = try XCTUnwrap(activity.workflowProjection)

            XCTAssertEqual(activity.activityType, .workflowRunCompleted)
            XCTAssertEqual(projection.runID, run.id)
            XCTAssertEqual(projection.templateDisplayName, "Receipt Intake")
            XCTAssertEqual(projection.triggerSurfaceLabel, "Inspector")
            XCTAssertEqual(projection.fileCount, 2)
            XCTAssertTrue(projection.statusText.contains("Succeeded"))
            XCTAssertTrue(activity.details.contains("Inspector"))
            XCTAssertTrue(activity.details.contains("2 file"))
        }
    }

    func testRollbackFailureProjection_DoesNotReadAsSuccess() throws {
        let (container, context) = try makeContainer()
        let store = WorkflowAuditStore(modelContext: context)
        let service = ActivityLoggingService(modelContext: context)

        try withExtendedLifetime(container) {
            let baseTimestamp = Date().addingTimeInterval(-120)
            let run = try store.createRun(
                scopeID: UUID(),
                workflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts,
                startedAt: baseTimestamp,
                primaryStatus: .failed
            )
            try store.updateRollbackStatus(
                runID: run.id,
                rollbackStatus: .failed,
                rollbackReason: "Move rollback lost bookmark access.",
                rollbackRequestedAt: baseTimestamp.addingTimeInterval(10),
                rollbackCompletedAt: baseTimestamp.addingTimeInterval(40)
            )
            try store.updateRunStatus(
                runID: run.id,
                primaryStatus: .failed,
                endedAt: baseTimestamp.addingTimeInterval(5)
            )

            service.logWorkflowRunSummary(
                run: run,
                triggerSurface: .reviewFlow,
                affectedFileCount: 1
            )

            let activity = try XCTUnwrap(context.fetch(FetchDescriptor<ActivityItem>()).last)
            let projection = try XCTUnwrap(activity.workflowProjection)

            XCTAssertEqual(activity.activityType, .workflowRunAttentionNeeded)
            XCTAssertEqual(projection.triggerSurfaceLabel, "Review")
            XCTAssertTrue(projection.statusText.contains("Failed"))
            XCTAssertTrue(projection.rollbackText.contains("Rollback failed"))
            XCTAssertFalse(activity.details.localizedCaseInsensitiveContains("organized"))
            XCTAssertTrue(activity.details.localizedCaseInsensitiveContains("rollback failed"))
        }
    }

    func testWorkflowTriggerSurfaceLabel_ReviewFlow_RemainsReview() {
        XCTAssertEqual(ActivityItem.workflowTriggerSurfaceLabel(.reviewFlow), "Review")
    }

    func testWorkflowProjection_UsesProjectPolicyRealtimeLabel() throws {
        let activity = ActivityItem(
            activityType: .workflowRunCompleted,
            fileName: "Project Drop Zone",
            details: "Realtime project policy workflow run succeeded.",
            affectedFileCount: 2,
            workflowRunID: UUID(),
            workflowTemplateID: BuiltInWorkflowTemplate.StableID.projectDrop,
            workflowTriggerSurface: .projectPolicyRealtime,
            workflowPrimaryStatus: .succeeded,
            workflowRollbackStatus: .notRequested
        )

        let projection = try XCTUnwrap(activity.workflowProjection)

        XCTAssertEqual(projection.triggerSurfaceLabel, "Realtime project policy")
    }

    func testWorkflowRunProjection_UsesOwnerAndPolicySpecificCopy() throws {
        let (container, context) = try makeContainer()
        let store = WorkflowAuditStore(modelContext: context)
        let service = ActivityLoggingService(modelContext: context)

        try withExtendedLifetime(container) {
            let baseTimestamp = Date().addingTimeInterval(-90)
            let run = try store.createRun(
                scopeID: UUID(),
                workflowTemplateID: BuiltInWorkflowTemplate.StableID.projectDrop,
                triggerSurface: .projectPolicyRealtime,
                ownerDisplayName: "Alpha",
                policyName: "Project Drop Zone",
                startedAt: baseTimestamp,
                primaryStatus: .succeeded
            )
            try store.updateRunStatus(
                runID: run.id,
                primaryStatus: .succeeded,
                endedAt: baseTimestamp.addingTimeInterval(30)
            )

            service.logWorkflowRunSummary(
                run: run,
                triggerSurface: .projectPolicyRealtime,
                affectedFileCount: 2
            )

            let activity = try XCTUnwrap(context.fetch(FetchDescriptor<ActivityItem>()).last)

            XCTAssertTrue(activity.details.contains("Alpha"))
            XCTAssertTrue(activity.details.contains("Project Drop Zone"))
            XCTAssertTrue(activity.details.contains("Realtime project policy"))
        }
    }

    func testWorkflowStatusText_CompletedWithIssuesUsesAttentionLanguage() throws {
        let activity = ActivityItem(
            activityType: .workflowRunAttentionNeeded,
            fileName: "Project Drop Zone",
            details: "Workflow completed with issues.",
            affectedFileCount: 3,
            workflowRunID: UUID(),
            workflowTemplateID: BuiltInWorkflowTemplate.StableID.projectDrop,
            workflowTriggerSurface: .scheduledAutomationPass,
            workflowPrimaryStatus: .completedWithIssues,
            workflowRollbackStatus: .notRequested
        )

        let projection = try XCTUnwrap(activity.workflowProjection)

        XCTAssertEqual(projection.templateDisplayName, "Project Drop Zone")
        XCTAssertEqual(projection.triggerSurfaceLabel, "Scheduled trusted scope")
        XCTAssertEqual(projection.statusText, "Completed with issues")
        XCTAssertEqual(projection.rollbackText, "Rollback available")
    }
}
