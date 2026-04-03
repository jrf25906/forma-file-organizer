import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class TrustedAutomationScopeServiceTests: XCTestCase {

    private func makeService() throws -> (ModelContainer, ModelContext, TrustedAutomationScopeService) {
        let schema = Schema([TrustedAutomationScope.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        return (container, context, TrustedAutomationScopeService(modelContext: context))
    }

    private func withService(
        _ body: (_ context: ModelContext, _ service: TrustedAutomationScopeService) throws -> Void
    ) throws {
        let (container, context, service) = try makeService()
        try withExtendedLifetime(container) {
            try body(context, service)
        }
    }

    func testCreateOrReactivateScope_DeduplicatesByScopeTypeAndKey() throws {
        try withService { context, service in
            let created = try service.createOrReactivateScope(
                scopeType: .folder,
                scopeKey: "folder:downloads",
                displayName: "Downloads",
                promotionSource: .reviewFlow,
                recommendationSource: .repeatedReviewAcceptance,
                acceptedEvidenceCount: 3,
                overrideEvidenceCount: 1,
                undoEvidenceCount: 0,
                confidenceSnapshot: 0.82,
                rationaleSummary: "Approved three times from review.",
                allowedActions: [.move]
            )

            XCTAssertEqual(created.status, .active)
            XCTAssertEqual(created.acceptedEvidenceCount, 3)
            XCTAssertEqual(created.overrideEvidenceCount, 1)
            XCTAssertEqual(created.undoEvidenceCount, 0)

            let firstFetch = try context.fetch(FetchDescriptor<TrustedAutomationScope>())
            XCTAssertEqual(firstFetch.count, 1)
            XCTAssertEqual(firstFetch.first?.scopeType, .folder)
            XCTAssertEqual(firstFetch.first?.scopeKey, "folder:downloads")

            try service.pauseScope(id: created.id)

            let reactivated = try service.createOrReactivateScope(
                scopeType: .folder,
                scopeKey: "folder:downloads",
                displayName: "Downloads Folder",
                promotionSource: .reviewFlow,
                recommendationSource: .explicitRule,
                acceptedEvidenceCount: 6,
                overrideEvidenceCount: 0,
                undoEvidenceCount: 0,
                confidenceSnapshot: 0.94,
                rationaleSummary: "Repeated clean accepts with no undo.",
                allowedActions: [.move]
            )

            let secondFetch = try context.fetch(FetchDescriptor<TrustedAutomationScope>())
            XCTAssertEqual(secondFetch.count, 1)
            XCTAssertEqual(reactivated.id, created.id)
            XCTAssertEqual(reactivated.status, .active)
            XCTAssertEqual(reactivated.displayName, "Downloads Folder")
            XCTAssertEqual(reactivated.acceptedEvidenceCount, 6)
            XCTAssertEqual(reactivated.overrideEvidenceCount, 0)
            XCTAssertEqual(reactivated.recommendationSource, .explicitRule)
        }
    }

    func testPauseResumeAndRemove_UpdateStatusWithoutDeletingDuplicates() throws {
        try withService { context, service in
            let scope = try service.createOrReactivateScope(
                scopeType: .category,
                scopeKey: "category:screenshots",
                displayName: "Screenshots",
                promotionSource: .reviewFlow,
                recommendationSource: .personalMemoryPattern,
                acceptedEvidenceCount: 4,
                overrideEvidenceCount: 0,
                undoEvidenceCount: 0,
                confidenceSnapshot: 0.91,
                rationaleSummary: "Stable screenshot cleanup pattern.",
                allowedActions: [.move]
            )

            XCTAssertEqual(try service.activeScopes().map(\.id), [scope.id])
            XCTAssertTrue(try service.pausedScopes().isEmpty)

            try service.pauseScope(id: scope.id)

            let paused = try XCTUnwrap(context.fetch(FetchDescriptor<TrustedAutomationScope>()).first)
            XCTAssertEqual(paused.status, .paused)
            XCTAssertTrue(try service.activeScopes().isEmpty)
            XCTAssertEqual(try service.pausedScopes().map(\.id), [scope.id])

            try service.resumeScope(id: scope.id)

            let resumed = try XCTUnwrap(context.fetch(FetchDescriptor<TrustedAutomationScope>()).first)
            XCTAssertEqual(resumed.status, .active)
            XCTAssertEqual(try service.activeScopes().map(\.id), [scope.id])
            XCTAssertTrue(try service.pausedScopes().isEmpty)

            try service.removeScope(id: scope.id)

            let removed = try XCTUnwrap(context.fetch(FetchDescriptor<TrustedAutomationScope>()).first)
            XCTAssertEqual(removed.status, .revoked)
            XCTAssertNotNil(removed.revokedAt)
            XCTAssertTrue(try service.activeScopes().isEmpty)
            XCTAssertTrue(try service.pausedScopes().isEmpty)
            XCTAssertEqual(try context.fetch(FetchDescriptor<TrustedAutomationScope>()).count, 1)
        }
    }
}
