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
                triggerSource: .manualPreview,
                status: .completed,
                matchedCount: 3,
                eligibleCount: 3,
                organizedCount: 3,
                heldCount: 0,
                failedCount: 0,
                heldBuckets: [],
                summaryText: "Organized cleanly.",
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
                triggerSource: .automaticPass,
                status: .completed,
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
                triggerSource: .automaticPass,
                status: .completedWithBlockers,
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

            XCTAssertEqual(healthyDetail.health.state, .healthy)
            XCTAssertEqual(quietDetail.health.state, .quiet)
            XCTAssertEqual(brokenBookmarkDetail.health.state, .needsAttention)
            XCTAssertEqual(invalidRuleDetail.health.state, .needsAttention)
            XCTAssertEqual(blockedDetail.health.state, .needsAttention)
            XCTAssertTrue(
                brokenBookmarkDetail.health.messages.contains(where: { $0.localizedCaseInsensitiveContains("permission") })
            )
            XCTAssertTrue(
                invalidRuleDetail.health.messages.contains(where: { $0.localizedCaseInsensitiveContains("disabled") })
            )
            XCTAssertTrue(
                blockedDetail.health.messages.contains(where: { $0.localizedCaseInsensitiveContains("held") })
            )
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
