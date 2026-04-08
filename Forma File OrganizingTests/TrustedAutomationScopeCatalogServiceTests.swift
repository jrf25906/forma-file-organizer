import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class TrustedAutomationScopeCatalogServiceTests: XCTestCase {

    private func makeServices() throws -> (
        ModelContainer,
        ModelContext,
        TrustedAutomationScopeService,
        TrustedAutomationScopeCatalogService
    ) {
        let schema = Schema([
            TrustedAutomationScope.self,
            TrustedAutomationScopeRunRecord.self,
            WorkflowRunRecord.self,
            Rule.self,
            RuleCategory.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        return (
            container,
            context,
            TrustedAutomationScopeService(modelContext: context),
            TrustedAutomationScopeCatalogService(modelContext: context)
        )
    }

    private func withServices(
        _ body: (
            _ context: ModelContext,
            _ scopeService: TrustedAutomationScopeService,
            _ catalogService: TrustedAutomationScopeCatalogService
        ) throws -> Void
    ) throws {
        let (container, context, scopeService, catalogService) = try makeServices()
        try withExtendedLifetime(container) {
            try body(context, scopeService, catalogService)
        }
    }

    func testBuildSummaries_GroupsActivePausedAndRevokedScopes() throws {
        let destinationRoot = try TemporaryDirectory()
        defer { destinationRoot.cleanup() }
        let reviewedDestination = try Destination.folder(
            from: try destinationRoot.createDirectory(name: "Organized")
        )

        try withServices { _, scopeService, catalogService in
            let activeScope = try makeScope(
                service: scopeService,
                scopeType: .folder,
                scopeKey: "/Users/example/Downloads/Active",
                displayName: "Active",
                destination: reviewedDestination
            )
            let pausedScope = try makeScope(
                service: scopeService,
                scopeType: .category,
                scopeKey: FileTypeCategory.images.rawValue,
                displayName: "Images",
                destination: reviewedDestination
            )
            let revokedScope = try makeScope(
                service: scopeService,
                scopeType: .folder,
                scopeKey: "/Users/example/Desktop/Revoked",
                displayName: "Revoked",
                destination: reviewedDestination
            )

            try scopeService.pauseScope(id: pausedScope.id, at: Date(timeIntervalSince1970: 200))
            try scopeService.removeScope(id: revokedScope.id, at: Date(timeIntervalSince1970: 300))

            let sections = try catalogService.buildSummarySections(
                referenceDate: Date(timeIntervalSince1970: 400)
            )

            XCTAssertEqual(sections.map(\.status), [.active, .paused, .revoked])
            XCTAssertEqual(sections[0].summaries.map(\.displayName), ["Active"])
            XCTAssertEqual(sections[1].summaries.map(\.displayName), ["Images"])
            XCTAssertEqual(sections[2].summaries.map(\.displayName), ["Revoked"])
            XCTAssertEqual(sections[0].summaries.first?.lifecycle.status, .active)
            XCTAssertEqual(sections[1].summaries.first?.lifecycle.status, .paused)
            XCTAssertEqual(sections[2].summaries.first?.lifecycle.status, .revoked)
            XCTAssertEqual(activeScope.status, .active)
        }
    }

    func testBuildDetail_DerivesHealthyQuietAndNeedsAttentionStates() throws {
        let healthyRoot = try TemporaryDirectory()
        let quietRoot = try TemporaryDirectory()
        let blockedRoot = try TemporaryDirectory()
        defer { healthyRoot.cleanup() }
        defer { quietRoot.cleanup() }
        defer { blockedRoot.cleanup() }

        let healthyDestination = try Destination.folder(from: try healthyRoot.createDirectory(name: "Healthy"))
        let quietDestination = try Destination.folder(from: try quietRoot.createDirectory(name: "Quiet"))
        let blockedDestination = try Destination.folder(from: try blockedRoot.createDirectory(name: "Blocked"))

        try withServices { context, scopeService, catalogService in
            let rule = Rule(
                name: "Receipt Rule",
                conditionType: .fileExtension,
                conditionValue: "pdf",
                actionType: .move,
                destination: healthyDestination
            )
            rule.isEnabled = false
            context.insert(rule)
            try context.save()

            let healthyScope = try scopeService.createOrReactivateScope(
                scopeType: .folder,
                scopeKey: "/Users/example/Downloads/Healthy",
                displayName: "Healthy Folder",
                boundaryDescriptor: .folder(
                    source: .init(
                        sourceLocation: .downloads,
                        scanRootPath: "/Users/example/Downloads",
                        relativeParentPath: "Healthy"
                    ),
                    destination: .init(healthyDestination)
                ),
                promotionSource: .reviewFlow,
                recommendationSource: .repeatedReviewAcceptance,
                acceptedEvidenceCount: 4,
                overrideEvidenceCount: 0,
                undoEvidenceCount: 0,
                confidenceSnapshot: 0.93,
                rationaleSummary: "Healthy scope",
                allowedActions: [.move],
                refreshedAt: Date(timeIntervalSince1970: 100)
            )
            _ = try scopeService.recordRun(
                scopeID: healthyScope.id,
                triggerSource: .promotionPreview,
                status: .simulated,
                matchedCount: 3,
                eligibleCount: 3,
                organizedCount: 0,
                heldCount: 0,
                failedCount: 0,
                heldBuckets: [],
                summaryText: "Previewed cleanly before promotion.",
                exampleFileNames: ["Receipt.pdf"],
                startedAt: Date(timeIntervalSince1970: 1_999_500),
                endedAt: Date(timeIntervalSince1970: 1_999_550)
            )

            let quietScope = try scopeService.createOrReactivateScope(
                scopeType: .folder,
                scopeKey: "/Users/example/Downloads/Quiet",
                displayName: "Quiet Folder",
                boundaryDescriptor: .folder(
                    source: .init(
                        sourceLocation: .downloads,
                        scanRootPath: "/Users/example/Downloads",
                        relativeParentPath: "Quiet"
                    ),
                    destination: .init(quietDestination)
                ),
                promotionSource: .reviewFlow,
                recommendationSource: .repeatedReviewAcceptance,
                acceptedEvidenceCount: 4,
                overrideEvidenceCount: 0,
                undoEvidenceCount: 0,
                confidenceSnapshot: 0.91,
                rationaleSummary: "Quiet scope",
                allowedActions: [.move],
                refreshedAt: Date(timeIntervalSince1970: 100)
            )
            _ = try scopeService.recordRun(
                scopeID: quietScope.id,
                triggerSource: .scheduledAutomationPass,
                status: .executed,
                matchedCount: 1,
                eligibleCount: 1,
                organizedCount: 1,
                heldCount: 0,
                failedCount: 0,
                heldBuckets: [],
                summaryText: "Organized one file.",
                exampleFileNames: ["Quiet.pdf"],
                startedAt: Date(timeIntervalSince1970: 10),
                endedAt: Date(timeIntervalSince1970: 20)
            )

            let brokenBookmarkScope = try scopeService.createOrReactivateScope(
                scopeType: .folder,
                scopeKey: "/Users/example/Downloads/Broken",
                displayName: "Broken Folder",
                boundaryDescriptor: .folder(
                    source: .init(
                        sourceLocation: .downloads,
                        scanRootPath: "/Users/example/Downloads",
                        relativeParentPath: "Broken"
                    ),
                    destination: .init(.folder(bookmark: Data(), displayName: "Broken"))
                ),
                promotionSource: .reviewFlow,
                recommendationSource: .repeatedReviewAcceptance,
                acceptedEvidenceCount: 3,
                overrideEvidenceCount: 0,
                undoEvidenceCount: 0,
                confidenceSnapshot: 0.88,
                rationaleSummary: "Broken bookmark scope",
                allowedActions: [.move],
                refreshedAt: Date(timeIntervalSince1970: 100)
            )

            let invalidRuleScope = try scopeService.createOrReactivateScope(
                scopeType: .rule,
                scopeKey: "rule:\(rule.id.uuidString)",
                displayName: rule.name,
                boundaryDescriptor: .rule(
                    rule: .init(id: rule.id, name: rule.name),
                    source: .init(
                        sourceLocation: .downloads,
                        scanRootPath: "/Users/example/Downloads",
                        relativeParentPath: "Healthy"
                    ),
                    destination: .init(healthyDestination)
                ),
                promotionSource: .reviewFlow,
                recommendationSource: .explicitRule,
                acceptedEvidenceCount: 3,
                overrideEvidenceCount: 0,
                undoEvidenceCount: 0,
                confidenceSnapshot: 0.89,
                rationaleSummary: "Disabled rule scope",
                allowedActions: [.move],
                refreshedAt: Date(timeIntervalSince1970: 100)
            )

            let blockedScope = try scopeService.createOrReactivateScope(
                scopeType: .folder,
                scopeKey: "/Users/example/Downloads/Blocked",
                displayName: "Blocked Folder",
                boundaryDescriptor: .folder(
                    source: .init(
                        sourceLocation: .downloads,
                        scanRootPath: "/Users/example/Downloads",
                        relativeParentPath: "Blocked"
                    ),
                    destination: .init(blockedDestination)
                ),
                promotionSource: .reviewFlow,
                recommendationSource: .repeatedReviewAcceptance,
                acceptedEvidenceCount: 4,
                overrideEvidenceCount: 0,
                undoEvidenceCount: 0,
                confidenceSnapshot: 0.9,
                rationaleSummary: "Blocked scope",
                allowedActions: [.move],
                refreshedAt: Date(timeIntervalSince1970: 100)
            )
            _ = try scopeService.recordRun(
                scopeID: blockedScope.id,
                triggerSource: .realtimeAutomationPass,
                status: .held,
                matchedCount: 4,
                eligibleCount: 4,
                organizedCount: 2,
                heldCount: 2,
                failedCount: 0,
                heldBuckets: [.init(bucket: "Needs Review", count: 2)],
                summaryText: "Two files were held.",
                exampleFileNames: ["Held-1.pdf", "Held-2.pdf"],
                startedAt: Date(timeIntervalSince1970: 1_999_700),
                endedAt: Date(timeIntervalSince1970: 1_999_760)
            )

            let failedScope = try scopeService.createOrReactivateScope(
                scopeType: .folder,
                scopeKey: "/Users/example/Downloads/Failed",
                displayName: "Failed Folder",
                boundaryDescriptor: .folder(
                    source: .init(
                        sourceLocation: .downloads,
                        scanRootPath: "/Users/example/Downloads",
                        relativeParentPath: "Failed"
                    ),
                    destination: .init(blockedDestination)
                ),
                promotionSource: .reviewFlow,
                recommendationSource: .repeatedReviewAcceptance,
                acceptedEvidenceCount: 4,
                overrideEvidenceCount: 0,
                undoEvidenceCount: 0,
                confidenceSnapshot: 0.87,
                rationaleSummary: "Failed scope",
                allowedActions: [.move],
                refreshedAt: Date(timeIntervalSince1970: 100)
            )
            _ = try scopeService.recordRun(
                scopeID: failedScope.id,
                triggerSource: .manualRefreshInspection,
                status: .failed,
                matchedCount: 2,
                eligibleCount: 2,
                organizedCount: 0,
                heldCount: 0,
                failedCount: 2,
                heldBuckets: [],
                summaryText: "Manual inspection surfaced permission failures.",
                exampleFileNames: ["Failed-1.pdf", "Failed-2.pdf"],
                startedAt: Date(timeIntervalSince1970: 1_999_800),
                endedAt: Date(timeIntervalSince1970: 1_999_850)
            )

            let referenceDate = Date(timeIntervalSince1970: 2_000_000)
            let healthyDetail = try XCTUnwrap(
                catalogService.buildDetail(for: healthyScope.id, referenceDate: referenceDate)
            )
            let quietDetail = try XCTUnwrap(
                catalogService.buildDetail(for: quietScope.id, referenceDate: referenceDate)
            )
            let brokenBookmarkDetail = try XCTUnwrap(
                catalogService.buildDetail(for: brokenBookmarkScope.id, referenceDate: referenceDate)
            )
            let invalidRuleDetail = try XCTUnwrap(
                catalogService.buildDetail(for: invalidRuleScope.id, referenceDate: referenceDate)
            )
            let blockedDetail = try XCTUnwrap(
                catalogService.buildDetail(for: blockedScope.id, referenceDate: referenceDate)
            )
            let failedDetail = try XCTUnwrap(
                catalogService.buildDetail(for: failedScope.id, referenceDate: referenceDate)
            )

            XCTAssertEqual(healthyDetail.health.state, .healthy)
            XCTAssertEqual(quietDetail.health.state, .quiet)
            XCTAssertEqual(brokenBookmarkDetail.health.state, .needsAttention)
            XCTAssertEqual(invalidRuleDetail.health.state, .needsAttention)
            XCTAssertEqual(blockedDetail.health.state, .needsAttention)
            XCTAssertEqual(failedDetail.health.state, .needsAttention)
            XCTAssertEqual(healthyDetail.summary.lastRun?.triggerSource, .promotionPreview)
            XCTAssertEqual(healthyDetail.summary.lastRun?.status, .simulated)
            XCTAssertNil(healthyDetail.health.lastSuccessfulRunAt)
            XCTAssertEqual(quietDetail.summary.lastRun?.triggerSource, .scheduledAutomationPass)
            XCTAssertEqual(quietDetail.summary.lastRun?.status, .executed)
            XCTAssertEqual(quietDetail.health.lastSuccessfulRunAt, Date(timeIntervalSince1970: 20))
            XCTAssertEqual(blockedDetail.summary.lastRun?.triggerSource, .realtimeAutomationPass)
            XCTAssertEqual(blockedDetail.summary.lastRun?.status, .held)
            XCTAssertEqual(blockedDetail.health.lastBlockedRunAt, Date(timeIntervalSince1970: 1_999_760))
            XCTAssertEqual(failedDetail.summary.lastRun?.triggerSource, .manualRefreshInspection)
            XCTAssertEqual(failedDetail.summary.lastRun?.status, .failed)
            XCTAssertEqual(failedDetail.health.lastBlockedRunAt, Date(timeIntervalSince1970: 1_999_850))
            XCTAssertTrue(
                brokenBookmarkDetail.health.messages.contains(where: { $0.localizedCaseInsensitiveContains("permission") })
            )
            XCTAssertTrue(
                invalidRuleDetail.health.messages.contains(where: { $0.localizedCaseInsensitiveContains("disabled") })
            )
            XCTAssertTrue(
                blockedDetail.health.messages.contains(where: { $0.localizedCaseInsensitiveContains("held") })
            )
            XCTAssertTrue(
                failedDetail.health.messages.contains(where: { $0.localizedCaseInsensitiveContains("failed") })
            )
        }
    }

    func testBuildDetail_IncludesSelectedWorkflowTemplateSummary() throws {
        let destinationRoot = try TemporaryDirectory()
        defer { destinationRoot.cleanup() }
        let reviewedDestination = try Destination.folder(
            from: try destinationRoot.createDirectory(name: "Organized")
        )
        let assignedAt = Date(timeIntervalSince1970: 777)

        try withServices { _, scopeService, catalogService in
            let scope = try scopeService.createOrReactivateScope(
                scopeType: .folder,
                scopeKey: "/Users/example/Downloads/Receipts",
                displayName: "Receipts",
                boundaryDescriptor: .folder(
                    source: .init(
                        sourceLocation: .downloads,
                        scanRootPath: "/Users/example/Downloads",
                        relativeParentPath: "Receipts"
                    ),
                    destination: .init(reviewedDestination)
                ),
                promotionSource: .reviewFlow,
                recommendationSource: .repeatedReviewAcceptance,
                acceptedEvidenceCount: 3,
                overrideEvidenceCount: 0,
                undoEvidenceCount: 0,
                confidenceSnapshot: 0.93,
                rationaleSummary: "Template-backed scope",
                allowedActions: [.move],
                selectedWorkflowTemplateID: "builtin.workflow.receipts.v1",
                templateAssignedAt: assignedAt,
                refreshedAt: assignedAt
            )

            let detail = try XCTUnwrap(catalogService.buildDetail(for: scope.id))
            let templateSummary = try XCTUnwrap(detail.selectedWorkflowTemplate)

            XCTAssertEqual(templateSummary.id, "builtin.workflow.receipts.v1")
            XCTAssertEqual(templateSummary.assignedAt, assignedAt)
            XCTAssertEqual(templateSummary.allowedActions, [.rename, .tag, .move])
            XCTAssertEqual(detail.summary.allowedActions, [.rename, .tag, .move])
            XCTAssertFalse(templateSummary.displayName.isEmpty)
            XCTAssertFalse(templateSummary.summaryText.isEmpty)
        }
    }

    func testBuildDetail_IncludesLatestWorkflowStatusAndRollbackAvailability() throws {
        let destinationRoot = try TemporaryDirectory()
        defer { destinationRoot.cleanup() }

        let reviewedDestination = try Destination.folder(
            from: try destinationRoot.createDirectory(name: "Organized")
        )
        let startedAt = Date(timeIntervalSince1970: 880)
        let endedAt = Date(timeIntervalSince1970: 900)

        try withServices { context, scopeService, catalogService in
            let scope = try scopeService.createOrReactivateScope(
                scopeType: .folder,
                scopeKey: "/Users/example/Downloads/Receipts",
                displayName: "Receipts",
                boundaryDescriptor: .folder(
                    source: .init(
                        sourceLocation: .downloads,
                        scanRootPath: "/Users/example/Downloads",
                        relativeParentPath: "Receipts"
                    ),
                    destination: .init(reviewedDestination)
                ),
                promotionSource: .reviewFlow,
                recommendationSource: .repeatedReviewAcceptance,
                acceptedEvidenceCount: 3,
                overrideEvidenceCount: 0,
                undoEvidenceCount: 0,
                confidenceSnapshot: 0.93,
                rationaleSummary: "Template-backed scope",
                allowedActions: [.move],
                selectedWorkflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts,
                templateAssignedAt: startedAt,
                refreshedAt: startedAt
            )

            let store = WorkflowAuditStore(modelContext: context)
            let run = try store.createRun(
                scopeID: scope.id,
                workflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts,
                startedAt: startedAt,
                primaryStatus: .running
            )
            try store.updateRunStatus(runID: run.id, primaryStatus: .succeeded, endedAt: endedAt)

            let detail = try XCTUnwrap(catalogService.buildDetail(for: scope.id))
            let latestWorkflowRun = try XCTUnwrap(detail.latestWorkflowRun)

            XCTAssertEqual(latestWorkflowRun.templateID, BuiltInWorkflowTemplate.StableID.receipts)
            XCTAssertEqual(latestWorkflowRun.primaryStatus, .succeeded)
            XCTAssertEqual(latestWorkflowRun.rollbackStatus, .notRequested)
            XCTAssertEqual(latestWorkflowRun.completedAt, endedAt)
            XCTAssertTrue(latestWorkflowRun.isRollbackAvailable)
        }
    }

    func testPromoteFromReviewDecision_PersistsSelectedWorkflowTemplate() throws {
        let destinationRoot = try TemporaryDirectory()
        defer { destinationRoot.cleanup() }

        let reviewedDestination = try Destination.folder(
            from: try destinationRoot.createDirectory(name: "Receipts Archive")
        )
        let promotedAt = Date(timeIntervalSince1970: 9_000)

        try withServices { _, scopeService, catalogService in
            let recommendation = TrustedAutomationScopeRecommendation(
                recommendedScope: TrustedAutomationScopeRecommendationOption(
                    scopeType: .folder,
                    scopeKey: "/Users/example/Downloads/Receipts",
                    displayName: "Receipts",
                    recommendationSource: .repeatedReviewAcceptance,
                    acceptedEvidenceCount: 5,
                    overrideEvidenceCount: 0,
                    undoEvidenceCount: 0,
                    confidenceSnapshot: 0.96,
                    rationaleSummary: "Receipts are consistently approved."
                ),
                alternativeScopes: [],
                snapshot: OrganizationMemorySnapshot(
                    fileName: "April Receipt.pdf",
                    fileExtension: "pdf",
                    fileTypeCategory: .documents,
                    sourceLocation: .downloads,
                    scanRootPath: "/Users/example/Downloads",
                    relativeParentPath: "Receipts",
                    suggestionSource: .personalMemory,
                    suggestedDestination: reviewedDestination,
                    chosenDestination: reviewedDestination,
                    confidenceScore: 0.96,
                    matchedRuleID: nil
                )
            )

            let promoted = try scopeService.promoteFromReviewDecision(
                recommendation: recommendation,
                selectedScopeType: .folder,
                selectedWorkflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts,
                promotedAt: promotedAt
            )

            XCTAssertEqual(promoted.selectedWorkflowTemplateID, BuiltInWorkflowTemplate.StableID.receipts)
            XCTAssertEqual(promoted.templateAssignedAt, promotedAt)
            XCTAssertEqual(promoted.allowedActions, BuiltInWorkflowTemplate.requiredActionShape)

            let detail = try XCTUnwrap(catalogService.buildDetail(for: promoted.id))
            XCTAssertEqual(detail.selectedWorkflowTemplate?.id, BuiltInWorkflowTemplate.StableID.receipts)
            XCTAssertEqual(detail.selectedWorkflowTemplate?.assignedAt, promotedAt)
            XCTAssertEqual(detail.summary.allowedActions, BuiltInWorkflowTemplate.requiredActionShape)
        }
    }

    func testTemplateNormalization_LegacyMoveOnlyScopeRemainsMoveOnlyUntilExplicitTemplateAssignment() throws {
        let templateAssignedAt = Date(timeIntervalSince1970: 2_000)

        try withServices { _, scopeService, _ in
            let created = try scopeService.createOrReactivateScope(
                scopeType: .folder,
                scopeKey: "/Users/example/Downloads/Legacy",
                displayName: "Legacy Scope",
                promotionSource: .manualSettings,
                recommendationSource: .repeatedReviewAcceptance,
                acceptedEvidenceCount: 2,
                overrideEvidenceCount: 0,
                undoEvidenceCount: 0,
                confidenceSnapshot: 0.8,
                rationaleSummary: "Legacy move-only scope",
                allowedActions: [.move],
                refreshedAt: Date(timeIntervalSince1970: 1_000)
            )
            XCTAssertNil(created.selectedWorkflowTemplateID)
            XCTAssertNil(created.templateAssignedAt)
            XCTAssertEqual(created.allowedActions, [.move])

            let reactivatedLegacy = try scopeService.createOrReactivateScope(
                scopeType: .folder,
                scopeKey: "/Users/example/Downloads/Legacy",
                displayName: "Legacy Scope",
                promotionSource: .manualSettings,
                recommendationSource: .repeatedReviewAcceptance,
                acceptedEvidenceCount: 3,
                overrideEvidenceCount: 0,
                undoEvidenceCount: 0,
                confidenceSnapshot: 0.82,
                rationaleSummary: "Still move-only",
                allowedActions: [.move],
                refreshedAt: Date(timeIntervalSince1970: 1_500)
            )
            XCTAssertNil(reactivatedLegacy.selectedWorkflowTemplateID)
            XCTAssertNil(reactivatedLegacy.templateAssignedAt)
            XCTAssertEqual(reactivatedLegacy.allowedActions, [.move])

            let templated = try scopeService.createOrReactivateScope(
                scopeType: .folder,
                scopeKey: "/Users/example/Downloads/Legacy",
                displayName: "Legacy Scope",
                promotionSource: .manualSettings,
                recommendationSource: .repeatedReviewAcceptance,
                acceptedEvidenceCount: 4,
                overrideEvidenceCount: 0,
                undoEvidenceCount: 0,
                confidenceSnapshot: 0.86,
                rationaleSummary: "Assigned template",
                allowedActions: [.move],
                selectedWorkflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts,
                templateAssignedAt: templateAssignedAt,
                refreshedAt: templateAssignedAt
            )
            XCTAssertEqual(templated.selectedWorkflowTemplateID, BuiltInWorkflowTemplate.StableID.receipts)
            XCTAssertEqual(templated.templateAssignedAt, templateAssignedAt)
            XCTAssertEqual(templated.allowedActions, [.rename, .tag, .move])
        }
    }

    func testTemplateNormalization_ReactivatingTemplatedScopeReforcesCanonicalActionShape() throws {
        let assignedAt = Date(timeIntervalSince1970: 4_000)

        try withServices { context, scopeService, _ in
            let templated = try scopeService.createOrReactivateScope(
                scopeType: .folder,
                scopeKey: "/Users/example/Downloads/Reforce",
                displayName: "Templated Scope",
                promotionSource: .manualSettings,
                recommendationSource: .repeatedReviewAcceptance,
                acceptedEvidenceCount: 4,
                overrideEvidenceCount: 0,
                undoEvidenceCount: 0,
                confidenceSnapshot: 0.9,
                rationaleSummary: "Template active",
                allowedActions: [.move],
                selectedWorkflowTemplateID: BuiltInWorkflowTemplate.StableID.receipts,
                templateAssignedAt: assignedAt,
                refreshedAt: assignedAt
            )
            XCTAssertEqual(templated.allowedActions, [.rename, .tag, .move])

            templated.allowedActions = [.move]
            try context.save()
            XCTAssertEqual(templated.allowedActions, [.move])

            let reactivated = try scopeService.createOrReactivateScope(
                scopeType: .folder,
                scopeKey: "/Users/example/Downloads/Reforce",
                displayName: "Templated Scope",
                promotionSource: .manualSettings,
                recommendationSource: .repeatedReviewAcceptance,
                acceptedEvidenceCount: 5,
                overrideEvidenceCount: 0,
                undoEvidenceCount: 0,
                confidenceSnapshot: 0.92,
                rationaleSummary: "Reactivated",
                allowedActions: [.move],
                refreshedAt: Date(timeIntervalSince1970: 5_000)
            )

            XCTAssertEqual(reactivated.selectedWorkflowTemplateID, BuiltInWorkflowTemplate.StableID.receipts)
            XCTAssertEqual(reactivated.templateAssignedAt, assignedAt)
            XCTAssertEqual(reactivated.allowedActions, [.rename, .tag, .move])
        }
    }

    func testTemplateNormalization_InvalidTemplateInputDoesNotPersistBadTemplateReference() throws {
        let attemptedAssignmentAt = Date(timeIntervalSince1970: 6_000)

        try withServices { _, scopeService, catalogService in
            let scope = try scopeService.createOrReactivateScope(
                scopeType: .folder,
                scopeKey: "/Users/example/Downloads/InvalidTemplate",
                displayName: "Invalid Template Scope",
                promotionSource: .manualSettings,
                recommendationSource: .repeatedReviewAcceptance,
                acceptedEvidenceCount: 1,
                overrideEvidenceCount: 0,
                undoEvidenceCount: 0,
                confidenceSnapshot: 0.7,
                rationaleSummary: "Attempted bad template assignment",
                allowedActions: [.move],
                selectedWorkflowTemplateID: "builtin.workflow.typo.v1",
                templateAssignedAt: attemptedAssignmentAt,
                refreshedAt: attemptedAssignmentAt
            )

            XCTAssertNil(scope.selectedWorkflowTemplateID)
            XCTAssertNil(scope.templateAssignedAt)
            XCTAssertEqual(scope.allowedActions, [.move])

            let detail = try XCTUnwrap(catalogService.buildDetail(for: scope.id))
            XCTAssertNil(detail.selectedWorkflowTemplate)
        }
    }

    func testTemplateNormalization_PreservesPreviouslyStoredUnknownTemplateForCompatibility() throws {
        let legacyTemplateID = "legacy.workflow.template.v1"
        let legacyAssignedAt = Date(timeIntervalSince1970: 7_000)
        let legacyActionShape: [TrustedAutomationAllowedAction] = [.rename, .notify]

        try withServices { context, scopeService, catalogService in
            let legacyScope = TrustedAutomationScope(
                scopeType: .folder,
                scopeKey: "/Users/example/Downloads/LegacyUnknownTemplate",
                displayName: "Legacy Unknown Template Scope",
                promotionSource: .manualSettings,
                recommendationSource: .repeatedReviewAcceptance,
                acceptedEvidenceCount: 2,
                overrideEvidenceCount: 0,
                undoEvidenceCount: 0,
                confidenceSnapshot: 0.75,
                rationaleSummary: "Stored by an older build",
                allowedActions: legacyActionShape,
                selectedWorkflowTemplateID: legacyTemplateID,
                templateAssignedAt: legacyAssignedAt,
                createdAt: Date(timeIntervalSince1970: 6_500)
            )
            context.insert(legacyScope)
            try context.save()

            let refreshed = try scopeService.createOrReactivateScope(
                scopeType: .folder,
                scopeKey: legacyScope.scopeKey,
                displayName: legacyScope.displayName,
                promotionSource: .manualSettings,
                recommendationSource: .repeatedReviewAcceptance,
                acceptedEvidenceCount: 3,
                overrideEvidenceCount: 0,
                undoEvidenceCount: 0,
                confidenceSnapshot: 0.8,
                rationaleSummary: "Refreshed legacy scope",
                allowedActions: [.move],
                refreshedAt: Date(timeIntervalSince1970: 8_000)
            )

            XCTAssertEqual(refreshed.selectedWorkflowTemplateID, legacyTemplateID)
            XCTAssertEqual(refreshed.templateAssignedAt, legacyAssignedAt)
            XCTAssertEqual(refreshed.allowedActions, legacyActionShape)

            let detail = try XCTUnwrap(catalogService.buildDetail(for: refreshed.id))
            XCTAssertEqual(detail.selectedWorkflowTemplate?.id, legacyTemplateID)
            XCTAssertEqual(detail.summary.allowedActions, legacyActionShape)
        }
    }

    private func makeScope(
        service: TrustedAutomationScopeService,
        scopeType: TrustedAutomationScopeType,
        scopeKey: String,
        displayName: String,
        destination: Destination
    ) throws -> TrustedAutomationScope {
        try service.createOrReactivateScope(
            scopeType: scopeType,
            scopeKey: scopeKey,
            displayName: displayName,
            boundaryDescriptor: boundaryDescriptor(
                scopeType: scopeType,
                displayName: displayName,
                scopeKey: scopeKey,
                destination: destination
            ),
            promotionSource: .reviewFlow,
            recommendationSource: .repeatedReviewAcceptance,
            acceptedEvidenceCount: 3,
            overrideEvidenceCount: 0,
            undoEvidenceCount: 0,
            confidenceSnapshot: 0.9,
            rationaleSummary: "Catalog test scope",
            allowedActions: [.move]
        )
    }

    private func boundaryDescriptor(
        scopeType: TrustedAutomationScopeType,
        displayName: String,
        scopeKey: String,
        destination: Destination
    ) -> TrustedAutomationScopeBoundaryDescriptor {
        switch scopeType {
        case .rule:
            return .rule(
                rule: .init(id: UUID(), name: displayName),
                source: .init(sourceLocation: .downloads, scanRootPath: "/Users/example/Downloads", relativeParentPath: nil),
                destination: .init(destination)
            )
        case .folder:
            return .folder(
                source: .init(sourceLocation: .downloads, scanRootPath: scopeKey, relativeParentPath: nil),
                destination: .init(destination)
            )
        case .category:
            return .category(
                fileTypeCategory: .images,
                source: .init(sourceLocation: .downloads, scanRootPath: "/Users/example/Downloads", relativeParentPath: nil),
                destination: .init(destination)
            )
        }
    }
}
