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

    private func makeRecommendationServices() throws -> (ModelContainer, ModelContext, TrustedAutomationScopeService, PersonalMemoryService, RuleService) {
        let schema = Schema([
            TrustedAutomationScope.self,
            PersonalMemoryEvent.self,
            PersonalMemoryPreference.self,
            Rule.self,
            ActivityItem.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        return (
            container,
            context,
            TrustedAutomationScopeService(modelContext: context),
            PersonalMemoryService(modelContext: context),
            RuleService(modelContext: context)
        )
    }

    private func withRecommendationServices(
        _ body: (_ context: ModelContext, _ scopeService: TrustedAutomationScopeService, _ memoryService: PersonalMemoryService, _ ruleService: RuleService) throws -> Void
    ) throws {
        let (container, context, scopeService, memoryService, ruleService) = try makeRecommendationServices()
        try withExtendedLifetime(container) {
            try body(context, scopeService, memoryService, ruleService)
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

    func testResumeScope_WhenRevoked_ThrowsAndPreservesRevokedStatus() throws {
        try withService { context, service in
            let scope = try service.createOrReactivateScope(
                scopeType: .rule,
                scopeKey: "rule:receipts",
                displayName: "Receipts rule",
                promotionSource: .reviewFlow,
                recommendationSource: .explicitRule,
                acceptedEvidenceCount: 5,
                overrideEvidenceCount: 0,
                undoEvidenceCount: 0,
                confidenceSnapshot: 0.96,
                rationaleSummary: "Repeated clean review approvals.",
                allowedActions: [.move]
            )

            try service.removeScope(id: scope.id)

            XCTAssertThrowsError(try service.resumeScope(id: scope.id))

            let removed = try XCTUnwrap(context.fetch(FetchDescriptor<TrustedAutomationScope>()).first)
            XCTAssertEqual(removed.status, .revoked)
            XCTAssertNotNil(removed.revokedAt)
        }
    }

    func testRecommendedScope_PrefersRuleThenFolderThenCategory() throws {
        try withRecommendationServices { _, service, memoryService, ruleService in
            let destination = Destination.mockFolder("Documents/Receipts")
            let ruleID = UUID()
            let explicitRule = Rule(
                name: "Receipt Rule",
                conditionType: .fileExtension,
                conditionValue: "pdf",
                actionType: .move,
                destination: destination
            )
            explicitRule.id = ruleID
            try ruleService.createRule(explicitRule, source: .ruleEditor)

            let ruleSnapshot = makeSnapshot(
                fileName: "Receipt.pdf",
                fileExtension: "pdf",
                fileTypeCategory: .documents,
                sourceLocation: .downloads,
                scanRootPath: "/Users/example/Downloads",
                relativeParentPath: nil,
                destination: destination,
                matchedRuleID: ruleID
            )

            for dayOffset in 0..<3 {
                try recordDecision(
                    memoryService: memoryService,
                    snapshot: ruleSnapshot,
                    eventKind: .acceptedSuggestion,
                    timestamp: Date().addingTimeInterval(TimeInterval(dayOffset))
                )
            }

            let explicitRecommendation = try service.recommendedScope(for: ruleSnapshot)
            XCTAssertEqual(explicitRecommendation?.recommendedScope.scopeType, .rule)
            XCTAssertEqual(explicitRecommendation?.recommendedScope.displayName, "Receipt Rule")
            XCTAssertEqual(
                Set(explicitRecommendation?.allScopeChoices.map(\.scopeType) ?? []),
                Set([.rule, .folder, .category])
            )
        }

        try withRecommendationServices { _, service, memoryService, _ in
            let destination = Destination.mockFolder("Documents/Exports")
            let folderSnapshot = makeSnapshot(
                fileName: "Report.csv",
                fileExtension: "csv",
                fileTypeCategory: .documents,
                sourceLocation: .downloads,
                scanRootPath: "/Users/example/Downloads",
                relativeParentPath: "Exports",
                destination: destination
            )

            for dayOffset in 0..<3 {
                try recordDecision(
                    memoryService: memoryService,
                    snapshot: folderSnapshot,
                    eventKind: .acceptedSuggestion,
                    timestamp: Date().addingTimeInterval(TimeInterval(dayOffset))
                )
            }

            let folderRecommendation = try service.recommendedScope(for: folderSnapshot)
            XCTAssertEqual(folderRecommendation?.recommendedScope.scopeType, .folder)
        }

        try withRecommendationServices { _, service, memoryService, _ in
            let destination = Destination.mockFolder("Pictures/Screenshots")
            let categorySnapshot = makeSnapshot(
                fileName: "Screen Shot.png",
                fileExtension: "png",
                fileTypeCategory: .images,
                sourceLocation: .unknown,
                scanRootPath: nil,
                relativeParentPath: nil,
                destination: destination
            )

            for dayOffset in 0..<3 {
                try recordDecision(
                    memoryService: memoryService,
                    snapshot: categorySnapshot,
                    eventKind: .acceptedSuggestion,
                    timestamp: Date().addingTimeInterval(TimeInterval(dayOffset))
                )
            }

            let categoryRecommendation = try service.recommendedScope(for: categorySnapshot)
            XCTAssertEqual(categoryRecommendation?.recommendedScope.scopeType, .category)
        }
    }

    func testRecommendedScope_RequiresEvidenceThresholdAndLowUndoSignal() throws {
        try withRecommendationServices { _, service, memoryService, _ in
            let destination = Destination.mockFolder("Documents/Receipts")
            let lowEvidenceSnapshot = makeSnapshot(
                fileName: "Receipt.pdf",
                fileExtension: "pdf",
                fileTypeCategory: .documents,
                sourceLocation: .downloads,
                scanRootPath: "/Users/example/Downloads",
                relativeParentPath: "Receipts",
                destination: destination
            )

            for dayOffset in 0..<2 {
                try recordDecision(
                    memoryService: memoryService,
                    snapshot: lowEvidenceSnapshot,
                    eventKind: .acceptedSuggestion,
                    timestamp: Date().addingTimeInterval(TimeInterval(dayOffset))
                )
            }

            XCTAssertNil(try service.recommendedScope(for: lowEvidenceSnapshot))
        }

        try withRecommendationServices { _, service, memoryService, _ in
            let destination = Destination.mockFolder("Documents/Receipts")
            let undoSnapshot = makeSnapshot(
                fileName: "Receipt.pdf",
                fileExtension: "pdf",
                fileTypeCategory: .documents,
                sourceLocation: .downloads,
                scanRootPath: "/Users/example/Downloads",
                relativeParentPath: "Receipts",
                destination: destination
            )

            for dayOffset in 0..<4 {
                try recordDecision(
                    memoryService: memoryService,
                    snapshot: undoSnapshot,
                    eventKind: .acceptedSuggestion,
                    timestamp: Date().addingTimeInterval(TimeInterval(dayOffset))
                )
            }

            try recordDecision(
                memoryService: memoryService,
                snapshot: undoSnapshot,
                eventKind: .undoRecovery,
                timestamp: Date().addingTimeInterval(10)
            )

            XCTAssertNil(try service.recommendedScope(for: undoSnapshot))
        }

        try withRecommendationServices { _, service, memoryService, _ in
            let destination = Destination.mockFolder("Documents/Receipts")
            let noisySnapshot = makeSnapshot(
                fileName: "Receipt.pdf",
                fileExtension: "pdf",
                fileTypeCategory: .documents,
                sourceLocation: .downloads,
                scanRootPath: "/Users/example/Downloads",
                relativeParentPath: "Receipts",
                destination: destination
            )

            for dayOffset in 0..<3 {
                try recordDecision(
                    memoryService: memoryService,
                    snapshot: noisySnapshot,
                    eventKind: .acceptedSuggestion,
                    timestamp: Date().addingTimeInterval(TimeInterval(dayOffset))
                )
            }

            try recordDecision(
                memoryService: memoryService,
                snapshot: noisySnapshot,
                eventKind: .acceptedWithOverride,
                suggestedDestination: Destination.mockFolder("Desktop/Hold"),
                timestamp: Date().addingTimeInterval(10)
            )

            XCTAssertNil(try service.recommendedScope(for: noisySnapshot))
        }
    }

    func testPromoteFromReviewDecision_CreatesRuleBackedScopeForDerivedRecommendation() throws {
        try withRecommendationServices { _, service, memoryService, ruleService in
            let destination = Destination.mockFolder("Pictures/Screenshots")
            let snapshot = makeSnapshot(
                fileName: "Screen Shot 2026-04-03.png",
                fileExtension: "png",
                fileTypeCategory: .images,
                sourceLocation: .downloads,
                scanRootPath: "/Users/example/Downloads",
                relativeParentPath: nil,
                destination: destination
            )

            for dayOffset in 0..<3 {
                try recordDecision(
                    memoryService: memoryService,
                    snapshot: snapshot,
                    eventKind: .acceptedSuggestion,
                    timestamp: Date().addingTimeInterval(TimeInterval(dayOffset))
                )
            }

            let recommendation = try XCTUnwrap(service.recommendedScope(for: snapshot))
            XCTAssertEqual(recommendation.recommendedScope.scopeType, .rule)

            let promotedScope = try service.promoteFromReviewDecision(recommendation: recommendation)

            XCTAssertEqual(promotedScope.scopeType, .rule)
            XCTAssertTrue(promotedScope.scopeKey.hasPrefix("rule:"))
            XCTAssertEqual(try service.activeScopes().count, 1)
            XCTAssertEqual(try ruleService.fetchRules().count, 1)
        }
    }

    private func makeSnapshot(
        fileName: String,
        fileExtension: String,
        fileTypeCategory: FileTypeCategory,
        sourceLocation: FileLocationKind,
        scanRootPath: String?,
        relativeParentPath: String?,
        destination: Destination,
        matchedRuleID: UUID? = nil
    ) -> OrganizationMemorySnapshot {
        OrganizationMemorySnapshot(
            fileName: fileName,
            fileExtension: fileExtension,
            fileTypeCategory: fileTypeCategory,
            sourceLocation: sourceLocation,
            scanRootPath: scanRootPath,
            relativeParentPath: relativeParentPath,
            suggestionSource: matchedRuleID == nil ? .personalMemory : .rule,
            suggestedDestination: destination,
            chosenDestination: destination,
            confidenceScore: 0.91,
            matchedRuleID: matchedRuleID
        )
    }

    private func recordDecision(
        memoryService: PersonalMemoryService,
        snapshot: OrganizationMemorySnapshot,
        eventKind: PersonalMemoryEventKind,
        suggestedDestination: Destination? = nil,
        timestamp: Date
    ) throws {
        let chosenDestination = eventKind == .undoRecovery ? nil : snapshot.chosenDestination
        let priorDestination = eventKind == .undoRecovery ? snapshot.chosenDestination : nil

        _ = try memoryService.recordDecision(
            fileName: snapshot.fileName,
            fileExtension: snapshot.fileExtension,
            fileTypeCategory: snapshot.fileTypeCategory,
            sourceLocation: snapshot.sourceLocation,
            scanRootPath: snapshot.scanRootPath,
            relativeParentPath: snapshot.relativeParentPath,
            sourceSurface: eventKind == .undoRecovery ? .undoSurface : .reviewFlow,
            suggestionSource: snapshot.suggestionSource,
            suggestedDestination: suggestedDestination ?? snapshot.suggestedDestination,
            chosenDestination: chosenDestination,
            confidenceScore: snapshot.confidenceScore,
            matchedRuleID: snapshot.matchedRuleID,
            eventKind: eventKind,
            priorDestination: priorDestination,
            timestamp: timestamp
        )
    }
}
