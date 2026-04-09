import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class WorkflowAuditStoreTests: XCTestCase {

    private func makeStore() throws -> (ModelContainer, ModelContext, WorkflowAuditStore) {
        let schema = Schema([
            FileMetadataRecord.self,
            TrustedAutomationScopeRunRecord.self,
            WorkflowRunRecord.self,
            WorkflowStepRunRecord.self,
            WorkflowFileActionRecord.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        return (container, context, WorkflowAuditStore(modelContext: context))
    }

    private func withStore(
        _ body: (_ context: ModelContext, _ store: WorkflowAuditStore) throws -> Void
    ) throws {
        let (container, context, store) = try makeStore()
        try withExtendedLifetime(container) {
            try body(context, store)
        }
    }

    func testCreateRun_PersistsRunStepAndFileActionRows() throws {
        try withStore { context, store in
            let scopeID = UUID()
            let startedAt = Date(timeIntervalSince1970: 1_000)
            let run = try store.createRun(
                scopeID: scopeID,
                workflowTemplateID: "builtin.workflow.receipts.v1",
                startedAt: startedAt,
                primaryStatus: .running
            )

            let step = try store.recordStepStatus(
                runID: run.id,
                stepID: "classify",
                status: .succeeded,
                startedAt: Date(timeIntervalSince1970: 1_005),
                endedAt: Date(timeIntervalSince1970: 1_010)
            )

            _ = try store.recordFileAction(
                runID: run.id,
                stepRunID: step.id,
                fileIdentity: "resource|diskA|file-001",
                sourcePath: "/Users/example/Downloads/Invoice-April.pdf",
                destinationPath: "/Users/example/Documents/Receipts/Invoice-April.pdf",
                disposition: .moved,
                compensationStatus: .available,
                compensationPayload: ["undoSourcePath": "/Users/example/Downloads/Invoice-April.pdf"]
            )

            let runs = try context.fetch(FetchDescriptor<WorkflowRunRecord>())
            let steps = try context.fetch(FetchDescriptor<WorkflowStepRunRecord>())
            let fileActions = try context.fetch(FetchDescriptor<WorkflowFileActionRecord>())
            let trustedScopeRuns = try context.fetch(FetchDescriptor<TrustedAutomationScopeRunRecord>())

            XCTAssertEqual(runs.count, 1)
            XCTAssertEqual(steps.count, 1)
            XCTAssertEqual(fileActions.count, 1)
            XCTAssertEqual(trustedScopeRuns.count, 0)

            XCTAssertEqual(runs.first?.scopeID, scopeID)
            XCTAssertEqual(steps.first?.runID, run.id)
            XCTAssertEqual(fileActions.first?.runID, run.id)
            XCTAssertEqual(fileActions.first?.stepRunID, step.id)
            XCTAssertEqual(fileActions.first?.compensationPayload?["undoSourcePath"], "/Users/example/Downloads/Invoice-April.pdf")
        }
    }

    func testLatestRunSummary_ReturnsNewestRunForTrustedScope() throws {
        try withStore { _, store in
            let scopeA = UUID()
            let scopeB = UUID()
            let templateReceipts = "builtin.workflow.receipts.v1"
            let templateScreenshots = "builtin.workflow.screenshots.v1"

            _ = try store.createRun(
                scopeID: scopeA,
                workflowTemplateID: templateReceipts,
                startedAt: Date(timeIntervalSince1970: 100),
                primaryStatus: .succeeded
            )
            let scopeAScreenshotsRun = try store.createRun(
                scopeID: scopeA,
                workflowTemplateID: templateScreenshots,
                startedAt: Date(timeIntervalSince1970: 200),
                primaryStatus: .succeeded
            )
            let scopeAReceiptsNewest = try store.createRun(
                scopeID: scopeA,
                workflowTemplateID: templateReceipts,
                startedAt: Date(timeIntervalSince1970: 300),
                primaryStatus: .failed
            )
            _ = try store.createRun(
                scopeID: scopeB,
                workflowTemplateID: templateReceipts,
                startedAt: Date(timeIntervalSince1970: 400),
                primaryStatus: .succeeded
            )

            let latestForScopeAnyTemplate = try store.latestRunSummary(scopeID: scopeA, workflowTemplateID: nil)
            let latestForScopeReceipts = try store.latestRunSummary(scopeID: scopeA, workflowTemplateID: templateReceipts)
            let latestForScopeScreenshots = try store.latestRunSummary(scopeID: scopeA, workflowTemplateID: templateScreenshots)

            XCTAssertEqual(latestForScopeAnyTemplate?.id, scopeAReceiptsNewest.id)
            XCTAssertEqual(latestForScopeReceipts?.id, scopeAReceiptsNewest.id)
            XCTAssertEqual(latestForScopeScreenshots?.id, scopeAScreenshotsRun.id)
        }
    }

    func testRollbackFields_AreStoredSeparatelyFromPrimaryStatus() throws {
        try withStore { context, store in
            let run = try store.createRun(
                scopeID: UUID(),
                workflowTemplateID: "builtin.workflow.receipts.v1",
                startedAt: Date(timeIntervalSince1970: 500),
                primaryStatus: .failed
            )

            try store.updateRollbackStatus(
                runID: run.id,
                rollbackStatus: .succeeded,
                rollbackReason: "Compensation move completed for all files.",
                rollbackRequestedAt: Date(timeIntervalSince1970: 540),
                rollbackCompletedAt: Date(timeIntervalSince1970: 560)
            )

            let persisted = try XCTUnwrap(
                context.fetch(FetchDescriptor<WorkflowRunRecord>())
                    .first(where: { $0.id == run.id })
            )

            XCTAssertEqual(persisted.primaryStatus, .failed)
            XCTAssertEqual(persisted.rollbackStatus, .succeeded)
            XCTAssertEqual(persisted.rollbackReason, "Compensation move completed for all files.")
            XCTAssertEqual(persisted.rollbackRequestedAt, Date(timeIntervalSince1970: 540))
            XCTAssertEqual(persisted.rollbackCompletedAt, Date(timeIntervalSince1970: 560))
        }
    }

    func testRollbackTransitions_PreserveEarlierMetadataWhenLaterUpdatesOmitFields() throws {
        try withStore { context, store in
            let run = try store.createRun(
                scopeID: UUID(),
                workflowTemplateID: "builtin.workflow.receipts.v1",
                startedAt: Date(timeIntervalSince1970: 1_000),
                primaryStatus: .running
            )

            let endedAt = Date(timeIntervalSince1970: 1_050)
            try store.updateRunStatus(
                runID: run.id,
                primaryStatus: .failed,
                endedAt: endedAt
            )

            try store.updateRunStatus(
                runID: run.id,
                primaryStatus: .failed
            )

            let rollbackReason = "Rollback requested after destination permissions changed."
            let rollbackRequestedAt = Date(timeIntervalSince1970: 1_060)
            let rollbackCompletedAt = Date(timeIntervalSince1970: 1_090)

            try store.updateRollbackStatus(
                runID: run.id,
                rollbackStatus: .requested,
                rollbackReason: rollbackReason,
                rollbackRequestedAt: rollbackRequestedAt
            )

            try store.updateRollbackStatus(
                runID: run.id,
                rollbackStatus: .inProgress
            )

            try store.updateRollbackStatus(
                runID: run.id,
                rollbackStatus: .succeeded,
                rollbackCompletedAt: rollbackCompletedAt
            )

            let persisted = try XCTUnwrap(
                context.fetch(FetchDescriptor<WorkflowRunRecord>())
                    .first(where: { $0.id == run.id })
            )

            XCTAssertEqual(persisted.endedAt, endedAt)
            XCTAssertEqual(persisted.rollbackStatus, .succeeded)
            XCTAssertEqual(persisted.rollbackReason, rollbackReason)
            XCTAssertEqual(persisted.rollbackRequestedAt, rollbackRequestedAt)
            XCTAssertEqual(persisted.rollbackCompletedAt, rollbackCompletedAt)
        }
    }

    func testWorkflowRunPrimaryStatus_CompletedWithIssuesRoundTrips() throws {
        try withStore { context, store in
            let run = try store.createRun(
                scopeID: UUID(),
                workflowTemplateID: BuiltInWorkflowTemplate.StableID.projectDrop,
                startedAt: Date(timeIntervalSince1970: 1_500),
                primaryStatus: .running
            )

            try store.updateRunStatus(
                runID: run.id,
                primaryStatus: .completedWithIssues,
                endedAt: Date(timeIntervalSince1970: 1_560)
            )

            let persisted = try XCTUnwrap(
                context.fetch(FetchDescriptor<WorkflowRunRecord>())
                    .first(where: { $0.id == run.id })
            )

            XCTAssertEqual(persisted.primaryStatus, .completedWithIssues)
            XCTAssertEqual(persisted.workflowTemplateID, BuiltInWorkflowTemplate.StableID.projectDrop)
        }
    }

    func testWorkflowFileDisposition_LoggedAndNotifiedRoundTrips() throws {
        try withStore { context, store in
            let run = try store.createRun(
                scopeID: UUID(),
                workflowTemplateID: BuiltInWorkflowTemplate.StableID.projectDrop,
                startedAt: Date(timeIntervalSince1970: 1_600),
                primaryStatus: .running
            )

            _ = try store.recordFileAction(
                runID: run.id,
                fileIdentity: "resource|diskA|file-logged",
                sourcePath: "/Users/example/Desktop/Shot.png",
                destinationPath: "/Users/example/Desktop/Shot.png",
                disposition: .logged,
                recordedAt: Date(timeIntervalSince1970: 1_610)
            )

            _ = try store.recordFileAction(
                runID: run.id,
                fileIdentity: "resource|diskA|file-notified",
                sourcePath: "/Users/example/Desktop/Shot.png",
                destinationPath: "/Users/example/Projects/Design/Shot.png",
                disposition: .notified,
                recordedAt: Date(timeIntervalSince1970: 1_620)
            )

            let fileActions = try context.fetch(FetchDescriptor<WorkflowFileActionRecord>())
                .sorted(by: { $0.recordedAt < $1.recordedAt })

            XCTAssertEqual(fileActions.map(\.disposition), [.logged, .notified])
        }
    }

    func testLatestRunForFile_ReturnsNewestRunWhenFileAppearsAcrossRuns() throws {
        try withStore { _, store in
            let sharedFileIdentity = "resource|diskA|shared-file-001"

            let olderRun = try store.createRun(
                scopeID: UUID(),
                workflowTemplateID: "builtin.workflow.receipts.v1",
                startedAt: Date(timeIntervalSince1970: 100),
                primaryStatus: .succeeded
            )
            let newerRun = try store.createRun(
                scopeID: UUID(),
                workflowTemplateID: "builtin.workflow.receipts.v1",
                startedAt: Date(timeIntervalSince1970: 200),
                primaryStatus: .succeeded
            )

            _ = try store.recordFileAction(
                runID: olderRun.id,
                fileIdentity: sharedFileIdentity,
                sourcePath: "/Users/example/Downloads/Invoice.pdf",
                destinationPath: "/Users/example/Documents/Receipts/Invoice.pdf",
                disposition: .moved,
                recordedAt: Date(timeIntervalSince1970: 120)
            )

            _ = try store.recordFileAction(
                runID: newerRun.id,
                fileIdentity: sharedFileIdentity,
                sourcePath: "/Users/example/Downloads/Invoice.pdf",
                destinationPath: "/Users/example/Documents/Receipts/Invoice.pdf",
                disposition: .restored,
                recordedAt: Date(timeIntervalSince1970: 220)
            )

            _ = try store.recordFileAction(
                runID: olderRun.id,
                fileIdentity: "resource|diskA|unrelated-file-002",
                sourcePath: "/Users/example/Downloads/Other.pdf",
                destinationPath: "/Users/example/Documents/Receipts/Other.pdf",
                disposition: .moved,
                recordedAt: Date(timeIntervalSince1970: 300)
            )

            let latestForSharedFile = try store.latestRunForFile(fileIdentity: sharedFileIdentity)
            let latestForUnknownFile = try store.latestRunForFile(fileIdentity: "resource|diskA|missing")

            XCTAssertEqual(latestForSharedFile?.id, newerRun.id)
            XCTAssertNil(latestForUnknownFile)
        }
    }

    func testLatestRunForPath_UsesResolvedIdentityWhenMetadataRecordIsMissing() throws {
        try withStore { context, store in
            let tempDirectory = try TemporaryDirectory()
            defer { tempDirectory.cleanup() }

            let fileURL = try tempDirectory.createFile(name: "Inbox/April Receipt.pdf", contents: "receipt")
            let fileIdentity = FileMetadataFoundationService(modelContext: context)
                .resolveIdentity(for: fileURL.path)
                .canonicalIdentity

            let run = try store.createRun(
                scopeID: UUID(),
                workflowTemplateID: "builtin.workflow.receipts.v1",
                startedAt: Date(timeIntervalSince1970: 100),
                primaryStatus: .succeeded
            )

            _ = try store.recordFileAction(
                runID: run.id,
                fileIdentity: fileIdentity,
                sourcePath: fileURL.path,
                destinationPath: fileURL.path,
                disposition: .moved,
                recordedAt: Date(timeIntervalSince1970: 120)
            )

            let latestRun = try store.latestRunForPath(fileURL.path)

            XCTAssertEqual(latestRun?.id, run.id)
        }
    }

    func testLatestRunForPath_PrefersLatestActionWhenMultipleMetadataRecordsSharePath() throws {
        try withStore { context, store in
            let sharedPath = "/Users/example/Inbox/Receipt.pdf"
            let olderIdentity = "resource|diskA|older"
            let newerIdentity = "resource|diskA|newer"

            context.insert(
                FileMetadataRecord(
                    canonicalIdentity: olderIdentity,
                    identityKind: .resourceIdentifier,
                    lastKnownPath: sharedPath,
                    displayName: "Receipt.pdf",
                    fileExtension: "pdf",
                    firstSeenAt: Date(timeIntervalSince1970: 10),
                    lastSeenAt: Date(timeIntervalSince1970: 10)
                )
            )
            context.insert(
                FileMetadataRecord(
                    canonicalIdentity: newerIdentity,
                    identityKind: .resourceIdentifier,
                    lastKnownPath: sharedPath,
                    displayName: "Receipt.pdf",
                    fileExtension: "pdf",
                    firstSeenAt: Date(timeIntervalSince1970: 20),
                    lastSeenAt: Date(timeIntervalSince1970: 20)
                )
            )
            try context.save()

            let olderRun = try store.createRun(
                scopeID: UUID(),
                workflowTemplateID: "builtin.workflow.receipts.v1",
                startedAt: Date(timeIntervalSince1970: 100),
                primaryStatus: .succeeded
            )
            let newerRun = try store.createRun(
                scopeID: UUID(),
                workflowTemplateID: "builtin.workflow.receipts.v1",
                startedAt: Date(timeIntervalSince1970: 200),
                primaryStatus: .succeeded
            )

            _ = try store.recordFileAction(
                runID: olderRun.id,
                fileIdentity: olderIdentity,
                sourcePath: sharedPath,
                destinationPath: "/Users/example/Receipts/Receipt.pdf",
                disposition: .moved,
                recordedAt: Date(timeIntervalSince1970: 120)
            )
            _ = try store.recordFileAction(
                runID: newerRun.id,
                fileIdentity: newerIdentity,
                sourcePath: sharedPath,
                destinationPath: "/Users/example/Receipts/Receipt.pdf",
                disposition: .moved,
                recordedAt: Date(timeIntervalSince1970: 220)
            )

            let latestRun = try store.latestRunForPath(sharedPath)

            XCTAssertEqual(latestRun?.id, newerRun.id)
        }
    }
}
