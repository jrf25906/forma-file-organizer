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
            let pausedAt = Date(timeIntervalSince1970: 1_234)
            let resumedAt = Date(timeIntervalSince1970: 2_345)
            let revokedAt = Date(timeIntervalSince1970: 3_456)
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
            XCTAssertNil(scope.pausedAt)
            XCTAssertNil(scope.lastRunAt)

            try service.pauseScope(id: scope.id, at: pausedAt)

            let paused = try XCTUnwrap(context.fetch(FetchDescriptor<TrustedAutomationScope>()).first)
            XCTAssertEqual(paused.status, .paused)
            XCTAssertEqual(paused.pausedAt, pausedAt)
            XCTAssertNil(paused.lastRunAt)
            XCTAssertTrue(try service.activeScopes().isEmpty)
            XCTAssertEqual(try service.pausedScopes().map(\.id), [scope.id])

            try service.resumeScope(id: scope.id, at: resumedAt)

            let resumed = try XCTUnwrap(context.fetch(FetchDescriptor<TrustedAutomationScope>()).first)
            XCTAssertEqual(resumed.status, .active)
            XCTAssertNil(resumed.pausedAt)
            XCTAssertEqual(resumed.updatedAt, resumedAt)
            XCTAssertNil(resumed.lastRunAt)
            XCTAssertEqual(try service.activeScopes().map(\.id), [scope.id])
            XCTAssertTrue(try service.pausedScopes().isEmpty)

            try service.removeScope(id: scope.id, at: revokedAt)

            let removed = try XCTUnwrap(context.fetch(FetchDescriptor<TrustedAutomationScope>()).first)
            XCTAssertEqual(removed.status, .revoked)
            XCTAssertEqual(removed.revokedAt, revokedAt)
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
            XCTAssertEqual(folderRecommendation?.recommendedScope.scopeKey, "/Users/example/Downloads/Exports")
            XCTAssertEqual(folderRecommendation?.recommendedScope.displayName, "Exports")
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

    func testRecommendedScope_FolderEvidenceStaysBoundToReviewedSubtree() throws {
        try withRecommendationServices { _, service, memoryService, _ in
            let destination = Destination.mockFolder("Documents/Exports")
            let exportsSnapshot = makeSnapshot(
                fileName: "Report.csv",
                fileExtension: "csv",
                fileTypeCategory: .documents,
                sourceLocation: .downloads,
                scanRootPath: "/Users/example/Downloads",
                relativeParentPath: "Exports",
                destination: destination
            )
            let receiptsSnapshot = makeSnapshot(
                fileName: "Receipt.csv",
                fileExtension: "csv",
                fileTypeCategory: .documents,
                sourceLocation: .downloads,
                scanRootPath: "/Users/example/Downloads",
                relativeParentPath: "Receipts",
                destination: destination
            )

            for dayOffset in 0..<2 {
                try recordDecision(
                    memoryService: memoryService,
                    snapshot: exportsSnapshot,
                    eventKind: .acceptedSuggestion,
                    timestamp: Date().addingTimeInterval(TimeInterval(dayOffset))
                )
                try recordDecision(
                    memoryService: memoryService,
                    snapshot: receiptsSnapshot,
                    eventKind: .acceptedSuggestion,
                    timestamp: Date().addingTimeInterval(TimeInterval(dayOffset + 10))
                )
            }

            XCTAssertNil(
                try service.recommendedScope(for: exportsSnapshot),
                "Evidence from sibling subfolders should not pool into folder or category trust for a specific reviewed boundary."
            )
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
                eventKind: .manualCorrection,
                suggestedDestination: Destination.mockFolder("Desktop/Hold"),
                timestamp: Date().addingTimeInterval(10)
            )

            XCTAssertNil(try service.recommendedScope(for: noisySnapshot))
        }
    }

    func testRecommendedScope_IgnoresNonReviewEvidenceSurfaces() throws {
        try withRecommendationServices { _, service, memoryService, _ in
            let destination = Destination.mockFolder("Documents/Receipts")
            let snapshot = makeSnapshot(
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
                    snapshot: snapshot,
                    eventKind: .manualSelection,
                    sourceSurface: .inspector,
                    timestamp: Date().addingTimeInterval(TimeInterval(dayOffset))
                )
            }

            XCTAssertNil(
                try service.recommendedScope(for: snapshot),
                "Only review-earned evidence should unlock trusted-scope recommendations."
            )
        }
    }

    func testRecommendedScope_DoesNotPromoteRuleWhenReviewOverridesItsDestination() throws {
        try withRecommendationServices { _, service, memoryService, ruleService in
            let suggestedDestination = Destination.mockFolder("Documents/Receipts")
            let chosenDestination = Destination.mockFolder("Desktop/Hold")
            let ruleID = UUID()
            let explicitRule = Rule(
                name: "Receipt Rule",
                conditionType: .fileExtension,
                conditionValue: "pdf",
                actionType: .move,
                destination: suggestedDestination
            )
            explicitRule.id = ruleID
            try ruleService.createRule(explicitRule, source: .ruleEditor)

            let snapshot = OrganizationMemorySnapshot(
                fileName: "Receipt.pdf",
                fileExtension: "pdf",
                fileTypeCategory: .documents,
                sourceLocation: .downloads,
                scanRootPath: "/Users/example/Downloads",
                relativeParentPath: "Receipts",
                suggestionSource: .rule,
                suggestedDestination: suggestedDestination,
                chosenDestination: chosenDestination,
                confidenceScore: 0.91,
                matchedRuleID: ruleID
            )

            for dayOffset in 0..<3 {
                try recordDecision(
                    memoryService: memoryService,
                    snapshot: snapshot,
                    eventKind: .acceptedWithOverride,
                    chosenDestination: chosenDestination,
                    suggestedDestination: suggestedDestination,
                    sourceSurface: .reviewFlow,
                    timestamp: Date().addingTimeInterval(TimeInterval(dayOffset))
                )
            }

            let recommendation = try XCTUnwrap(service.recommendedScope(for: snapshot))
            XCTAssertEqual(recommendation.recommendedScope.scopeType, .folder)
            XCTAssertFalse(recommendation.allScopeChoices.contains(where: { $0.scopeType == .rule }))
        }
    }

    func testRecommendedScope_DoesNotPromoteRuleWhenDistinctBookmarksShareDisplayName() throws {
        let originalRoot = try TemporaryDirectory()
        let overrideRoot = try TemporaryDirectory()
        let suggestedDestination = try Destination.folder(from: try originalRoot.createDirectory(name: "Shared"))
        let chosenDestination = try Destination.folder(from: try overrideRoot.createDirectory(name: "Shared"))

        XCTAssertNotEqual(suggestedDestination, chosenDestination)

        try withRecommendationServices { _, service, memoryService, ruleService in
            let ruleID = UUID()
            let explicitRule = Rule(
                name: "Shared Folder Rule",
                conditionType: .fileExtension,
                conditionValue: "pdf",
                actionType: .move,
                destination: suggestedDestination
            )
            explicitRule.id = ruleID
            try ruleService.createRule(explicitRule, source: .ruleEditor)

            let snapshot = OrganizationMemorySnapshot(
                fileName: "Receipt.pdf",
                fileExtension: "pdf",
                fileTypeCategory: .documents,
                sourceLocation: .downloads,
                scanRootPath: "/Users/example/Downloads",
                relativeParentPath: "Receipts",
                suggestionSource: .rule,
                suggestedDestination: suggestedDestination,
                chosenDestination: chosenDestination,
                confidenceScore: 0.91,
                matchedRuleID: ruleID
            )

            for dayOffset in 0..<3 {
                try recordDecision(
                    memoryService: memoryService,
                    snapshot: snapshot,
                    eventKind: .acceptedWithOverride,
                    chosenDestination: chosenDestination,
                    suggestedDestination: suggestedDestination,
                    sourceSurface: .reviewFlow,
                    timestamp: Date().addingTimeInterval(TimeInterval(dayOffset))
                )
            }

            let recommendation = try XCTUnwrap(service.recommendedScope(for: snapshot))
            XCTAssertEqual(recommendation.recommendedScope.scopeType, .folder)
            XCTAssertFalse(recommendation.allScopeChoices.contains(where: { $0.scopeType == .rule }))
        }
    }

    func testPromoteFromReviewDecision_DoesNotReuseMatchedRuleWhenDistinctBookmarksShareDisplayName() throws {
        let originalRoot = try TemporaryDirectory()
        let overrideRoot = try TemporaryDirectory()
        let suggestedDestination = try Destination.folder(from: try originalRoot.createDirectory(name: "Shared"))
        let chosenDestination = try Destination.folder(from: try overrideRoot.createDirectory(name: "Shared"))

        XCTAssertNotEqual(suggestedDestination, chosenDestination)

        try withRecommendationServices { _, service, _, ruleService in
            let staleRuleID = UUID()
            let staleRule = Rule(
                name: "Shared Folder Rule",
                conditionType: .fileExtension,
                conditionValue: "pdf",
                actionType: .move,
                destination: suggestedDestination
            )
            staleRule.id = staleRuleID
            staleRule.isEnabled = false
            try ruleService.createRule(staleRule, source: .ruleEditor)

            let snapshot = OrganizationMemorySnapshot(
                fileName: "Receipt.pdf",
                fileExtension: "pdf",
                fileTypeCategory: .documents,
                sourceLocation: .downloads,
                scanRootPath: "/Users/example/Downloads",
                relativeParentPath: "Receipts",
                suggestionSource: .rule,
                suggestedDestination: suggestedDestination,
                chosenDestination: chosenDestination,
                confidenceScore: 0.91,
                matchedRuleID: staleRuleID
            )

            let requestedOption = TrustedAutomationScopeRecommendationOption(
                scopeType: .rule,
                scopeKey: "rule:\(staleRuleID.uuidString)",
                displayName: staleRule.name,
                recommendationSource: .explicitRule,
                acceptedEvidenceCount: 4,
                overrideEvidenceCount: 0,
                undoEvidenceCount: 0,
                confidenceSnapshot: 0.91,
                rationaleSummary: "Pinned for promotion from review."
            )

            let recommendation = TrustedAutomationScopeRecommendation(
                recommendedScope: requestedOption,
                alternativeScopes: [],
                snapshot: snapshot
            )

            let promotedScope = try service.promoteFromReviewDecision(
                recommendation: recommendation,
                selectedScopeType: .rule
            )

            let rules = try ruleService.fetchRules()
            let stalePersistedRule = try XCTUnwrap(rules.first(where: { $0.id == staleRuleID }))
            let promotedRule = try XCTUnwrap(rules.first(where: { $0.id.uuidString == promotedScope.scopeKey.replacingOccurrences(of: "rule:", with: "") }))

            XCTAssertFalse(stalePersistedRule.isEnabled)
            XCTAssertEqual(stalePersistedRule.destination, suggestedDestination)
            XCTAssertNotEqual(promotedScope.scopeKey, "rule:\(staleRuleID.uuidString)")
            XCTAssertEqual(promotedRule.destination, chosenDestination)
            XCTAssertTrue(promotedRule.isEnabled)
        }
    }

    func testPromoteFromReviewDecision_ReusesExistingExactRuleWhenStaleRuleSharesDisplayName() throws {
        let originalRoot = try TemporaryDirectory()
        let correctRoot = try TemporaryDirectory()
        let staleDestination = try Destination.folder(from: try originalRoot.createDirectory(name: "Shared"))
        let correctDestination = try Destination.folder(from: try correctRoot.createDirectory(name: "Shared"))

        XCTAssertNotEqual(staleDestination, correctDestination)

        try withRecommendationServices { _, service, _, ruleService in
            let staleRuleID = UUID()
            let staleRule = Rule(
                name: "Shared Folder Rule",
                conditionType: .fileExtension,
                conditionValue: "pdf",
                actionType: .move,
                destination: staleDestination
            )
            staleRule.id = staleRuleID
            try ruleService.createRule(staleRule, source: .ruleEditor)

            let correctRuleID = UUID()
            let correctRule = Rule(
                name: "Shared Folder Rule",
                conditionType: .fileExtension,
                conditionValue: "pdf",
                actionType: .move,
                destination: correctDestination
            )
            correctRule.id = correctRuleID
            correctRule.isEnabled = false
            try ruleService.createRule(correctRule, source: .ruleEditor)

            let snapshot = OrganizationMemorySnapshot(
                fileName: "Receipt.pdf",
                fileExtension: "pdf",
                fileTypeCategory: .documents,
                sourceLocation: .downloads,
                scanRootPath: "/Users/example/Downloads",
                relativeParentPath: "Receipts",
                suggestionSource: .rule,
                suggestedDestination: staleDestination,
                chosenDestination: correctDestination,
                confidenceScore: 0.91,
                matchedRuleID: staleRuleID
            )

            let requestedOption = TrustedAutomationScopeRecommendationOption(
                scopeType: .rule,
                scopeKey: "rule:\(staleRuleID.uuidString)",
                displayName: staleRule.name,
                recommendationSource: .explicitRule,
                acceptedEvidenceCount: 4,
                overrideEvidenceCount: 0,
                undoEvidenceCount: 0,
                confidenceSnapshot: 0.91,
                rationaleSummary: "Pinned for promotion from review."
            )

            let recommendation = TrustedAutomationScopeRecommendation(
                recommendedScope: requestedOption,
                alternativeScopes: [],
                snapshot: snapshot
            )

            let promotedScope = try service.promoteFromReviewDecision(
                recommendation: recommendation,
                selectedScopeType: .rule
            )

            let rules = try ruleService.fetchRules()
            XCTAssertEqual(rules.count, 2)
            XCTAssertEqual(promotedScope.scopeKey, "rule:\(correctRuleID.uuidString)")
            XCTAssertEqual(try XCTUnwrap(rules.first(where: { $0.id == staleRuleID })).destination, staleDestination)
            XCTAssertTrue(try XCTUnwrap(rules.first(where: { $0.id == correctRuleID })).isEnabled)
        }
    }

    func testPromoteFromReviewDecision_DerivedRuleUsesReviewedBookmarkWhenSameNameInspectorHistoryExists() throws {
        let inspectorRoot = try TemporaryDirectory()
        let reviewRoot = try TemporaryDirectory()
        let inspectorDestination = try Destination.folder(from: try inspectorRoot.createDirectory(name: "Shared"))
        let reviewDestination = try Destination.folder(from: try reviewRoot.createDirectory(name: "Shared"))

        XCTAssertNotEqual(inspectorDestination, reviewDestination)

        try withRecommendationServices { _, service, memoryService, ruleService in
            let snapshot = OrganizationMemorySnapshot(
                fileName: "Receipt.pdf",
                fileExtension: "pdf",
                fileTypeCategory: .documents,
                sourceLocation: .downloads,
                scanRootPath: "/Users/example/Downloads",
                relativeParentPath: nil,
                suggestionSource: .personalMemory,
                suggestedDestination: reviewDestination,
                chosenDestination: reviewDestination,
                confidenceScore: 0.91,
                matchedRuleID: nil
            )

            for dayOffset in 0..<3 {
                try recordDecision(
                    memoryService: memoryService,
                    snapshot: snapshot,
                    eventKind: .manualSelection,
                    chosenDestination: inspectorDestination,
                    suggestedDestination: inspectorDestination,
                    sourceSurface: .inspector,
                    timestamp: Date().addingTimeInterval(TimeInterval(dayOffset))
                )

                try recordDecision(
                    memoryService: memoryService,
                    snapshot: snapshot,
                    eventKind: .acceptedSuggestion,
                    chosenDestination: reviewDestination,
                    suggestedDestination: reviewDestination,
                    sourceSurface: .reviewFlow,
                    timestamp: Date().addingTimeInterval(TimeInterval(dayOffset + 10))
                )
            }

            let recommendation = try XCTUnwrap(service.recommendedScope(for: snapshot))
            XCTAssertEqual(recommendation.recommendedScope.scopeType, .rule)

            let promotedScope = try service.promoteFromReviewDecision(recommendation: recommendation)
            let promotedRule = try XCTUnwrap(
                try ruleService.fetchRules().first(where: { $0.id.uuidString == promotedScope.scopeKey.replacingOccurrences(of: "rule:", with: "") })
            )

            XCTAssertEqual(promotedRule.destination, reviewDestination)
            XCTAssertNotEqual(promotedRule.destination, inspectorDestination)
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

    func testPromoteRuleScope_PersistsFullRuleBoundaryDescriptor() throws {
        let destinationRoot = try TemporaryDirectory()
        let reviewedDestination = try Destination.folder(
            from: try destinationRoot.createDirectory(name: "Receipts Archive")
        )

        try withRecommendationServices { context, service, _, ruleService in
            let ruleID = UUID()
            let rule = Rule(
                name: "Receipt Rule",
                conditionType: .fileExtension,
                conditionValue: "pdf",
                actionType: .move,
                destination: reviewedDestination
            )
            rule.id = ruleID
            try ruleService.createRule(rule, source: .ruleEditor)

            let snapshot = OrganizationMemorySnapshot(
                fileName: "Receipt.pdf",
                fileExtension: "pdf",
                fileTypeCategory: .documents,
                sourceLocation: .downloads,
                scanRootPath: "/Users/example/Downloads",
                relativeParentPath: "Clients/Acme",
                suggestionSource: .rule,
                suggestedDestination: reviewedDestination,
                chosenDestination: reviewedDestination,
                confidenceScore: 0.93,
                matchedRuleID: ruleID
            )
            let recommendation = TrustedAutomationScopeRecommendation(
                recommendedScope: TrustedAutomationScopeRecommendationOption(
                    scopeType: .rule,
                    scopeKey: "rule:\(ruleID.uuidString)",
                    displayName: rule.name,
                    recommendationSource: .explicitRule,
                    acceptedEvidenceCount: 4,
                    overrideEvidenceCount: 0,
                    undoEvidenceCount: 0,
                    confidenceSnapshot: 0.93,
                    rationaleSummary: "Reviewed rule is consistently accepted."
                ),
                alternativeScopes: [],
                snapshot: snapshot
            )

            let promoted = try service.promoteFromReviewDecision(
                recommendation: recommendation,
                selectedScopeType: .rule
            )
            let persisted = try XCTUnwrap(
                context.fetch(FetchDescriptor<TrustedAutomationScope>()).first(where: { $0.id == promoted.id })
            )

            XCTAssertEqual(
                persisted.boundaryDescriptor,
                .rule(
                    rule: .init(id: ruleID, name: "Receipt Rule"),
                    source: .init(
                        sourceLocation: .downloads,
                        scanRootPath: "/Users/example/Downloads",
                        relativeParentPath: "Clients/Acme"
                    ),
                    destination: .init(reviewedDestination)
                )
            )
        }
    }

    func testPromoteFolderScope_PersistsSubtreeBoundaryAndDestinationSnapshot() throws {
        let destinationRoot = try TemporaryDirectory()
        let reviewedDestination = try Destination.folder(
            from: try destinationRoot.createDirectory(name: "Receipts Archive")
        )

        try withService { context, service in
            let snapshot = OrganizationMemorySnapshot(
                fileName: "Receipt.pdf",
                fileExtension: "pdf",
                fileTypeCategory: .documents,
                sourceLocation: .downloads,
                scanRootPath: "/Users/example/Downloads",
                relativeParentPath: "Clients/Acme",
                suggestionSource: .personalMemory,
                suggestedDestination: reviewedDestination,
                chosenDestination: reviewedDestination,
                confidenceScore: 0.91,
                matchedRuleID: nil
            )
            let recommendation = TrustedAutomationScopeRecommendation(
                recommendedScope: TrustedAutomationScopeRecommendationOption(
                    scopeType: .folder,
                    scopeKey: "/Users/example/Downloads/Clients/Acme",
                    displayName: "Acme",
                    recommendationSource: .repeatedReviewAcceptance,
                    acceptedEvidenceCount: 4,
                    overrideEvidenceCount: 0,
                    undoEvidenceCount: 0,
                    confidenceSnapshot: 0.91,
                    rationaleSummary: "Reviewed subtree is consistently organized."
                ),
                alternativeScopes: [],
                snapshot: snapshot
            )

            let promoted = try service.promoteFromReviewDecision(
                recommendation: recommendation,
                selectedScopeType: .folder
            )
            let persisted = try XCTUnwrap(context.fetch(FetchDescriptor<TrustedAutomationScope>()).first)

            XCTAssertEqual(promoted.id, persisted.id)
            XCTAssertEqual(persisted.scopeType, .folder)
            XCTAssertEqual(persisted.scopeKey, "/Users/example/Downloads/Clients/Acme")
            XCTAssertEqual(
                persisted.boundaryDescriptor,
                .folder(
                    source: .init(
                        sourceLocation: .downloads,
                        scanRootPath: "/Users/example/Downloads",
                        relativeParentPath: "Clients/Acme"
                    ),
                    destination: .init(reviewedDestination)
                )
            )
            XCTAssertEqual(persisted.boundarySummary, "Acme -> Receipts Archive")
        }
    }

    func testPromoteCategoryScope_ReusesOnlyTheSameTrustedBoundary() throws {
        let firstDestinationRoot = try TemporaryDirectory()
        let secondDestinationRoot = try TemporaryDirectory()
        let firstDestination = try Destination.folder(from: try firstDestinationRoot.createDirectory(name: "Shared"))
        let secondDestination = try Destination.folder(from: try secondDestinationRoot.createDirectory(name: "Shared"))

        XCTAssertNotEqual(firstDestination, secondDestination)

        try withService { context, service in
            let firstPromotionDate = Date(timeIntervalSince1970: 1_000)
            let secondPromotionDate = Date(timeIntervalSince1970: 2_000)

            let firstRecommendation = TrustedAutomationScopeRecommendation(
                recommendedScope: TrustedAutomationScopeRecommendationOption(
                    scopeType: .category,
                    scopeKey: FileTypeCategory.images.rawValue,
                    displayName: FileTypeCategory.images.displayName,
                    recommendationSource: .repeatedReviewAcceptance,
                    acceptedEvidenceCount: 3,
                    overrideEvidenceCount: 0,
                    undoEvidenceCount: 0,
                    confidenceSnapshot: 0.9,
                    rationaleSummary: "Reviewed images are consistently trusted."
                ),
                alternativeScopes: [],
                snapshot: OrganizationMemorySnapshot(
                    fileName: "Screen Shot.png",
                    fileExtension: "png",
                    fileTypeCategory: .images,
                    sourceLocation: .unknown,
                    scanRootPath: nil,
                    relativeParentPath: nil,
                    suggestionSource: .personalMemory,
                    suggestedDestination: firstDestination,
                    chosenDestination: firstDestination,
                    confidenceScore: 0.9,
                    matchedRuleID: nil
                )
            )

            let firstScope = try service.promoteFromReviewDecision(
                recommendation: firstRecommendation,
                selectedScopeType: .category,
                promotedAt: firstPromotionDate
            )

            let refreshedScope = try service.promoteFromReviewDecision(
                recommendation: TrustedAutomationScopeRecommendation(
                    recommendedScope: firstRecommendation.recommendedScope,
                    alternativeScopes: [],
                    snapshot: OrganizationMemorySnapshot(
                        fileName: "Screen Shot 2.png",
                        fileExtension: "png",
                        fileTypeCategory: .images,
                        sourceLocation: .unknown,
                        scanRootPath: nil,
                        relativeParentPath: nil,
                        suggestionSource: .personalMemory,
                        suggestedDestination: firstDestination,
                        chosenDestination: firstDestination,
                        confidenceScore: 0.94,
                        matchedRuleID: nil
                    )
                ),
                selectedScopeType: .category,
                promotedAt: secondPromotionDate
            )

            let distinctBoundaryScope = try service.promoteFromReviewDecision(
                recommendation: TrustedAutomationScopeRecommendation(
                    recommendedScope: firstRecommendation.recommendedScope,
                    alternativeScopes: [],
                    snapshot: OrganizationMemorySnapshot(
                        fileName: "Screen Shot 3.png",
                        fileExtension: "png",
                        fileTypeCategory: .images,
                        sourceLocation: .downloads,
                        scanRootPath: "/Users/example/Downloads",
                        relativeParentPath: "Screenshots",
                        suggestionSource: .personalMemory,
                        suggestedDestination: secondDestination,
                        chosenDestination: secondDestination,
                        confidenceScore: 0.95,
                        matchedRuleID: nil
                    )
                ),
                selectedScopeType: .category,
                promotedAt: Date(timeIntervalSince1970: 3_000)
            )

            let persistedScopes = try context.fetch(FetchDescriptor<TrustedAutomationScope>())
            let refreshedPersisted = try XCTUnwrap(persistedScopes.first(where: { $0.id == firstScope.id }))
            let distinctPersisted = try XCTUnwrap(persistedScopes.first(where: { $0.id == distinctBoundaryScope.id }))

            XCTAssertEqual(persistedScopes.count, 2)
            XCTAssertEqual(refreshedScope.id, firstScope.id)
            XCTAssertNotEqual(distinctBoundaryScope.id, firstScope.id)
            XCTAssertEqual(refreshedPersisted.createdAt, firstPromotionDate)
            XCTAssertEqual(refreshedPersisted.updatedAt, secondPromotionDate)
            XCTAssertEqual(
                refreshedPersisted.boundaryDescriptor,
                .category(
                    fileTypeCategory: .images,
                    source: .init(
                        sourceLocation: .unknown,
                        scanRootPath: nil,
                        relativeParentPath: nil
                    ),
                    destination: .init(firstDestination)
                )
            )
            XCTAssertEqual(
                distinctPersisted.boundaryDescriptor,
                .category(
                    fileTypeCategory: .images,
                    source: .init(
                        sourceLocation: .downloads,
                        scanRootPath: "/Users/example/Downloads",
                        relativeParentPath: "Screenshots"
                    ),
                    destination: .init(secondDestination)
                )
            )
            XCTAssertEqual(refreshedPersisted.boundarySummary, "Images -> Shared")
            XCTAssertEqual(distinctPersisted.boundarySummary, "Images -> Shared")
        }
    }

    func testRecommendedScope_DoesNotOfferAmbiguousRootlessCategoryScope() throws {
        try withRecommendationServices { _, service, memoryService, _ in
            let destination = Destination.mockFolder("Pictures/Screenshots")
            let snapshot = makeSnapshot(
                fileName: "Screen Shot.png",
                fileExtension: "png",
                fileTypeCategory: .images,
                sourceLocation: .downloads,
                scanRootPath: nil,
                relativeParentPath: "Clients/Acme",
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

            XCTAssertNil(
                try service.recommendedScope(for: snapshot),
                "Boundary-specific category trust needs a persisted root; rootless nested sources should not be recommended."
            )
        }
    }

    func testRecommendedScope_DoesNotOfferAmbiguousRootlessExplicitRuleScope() throws {
        try withRecommendationServices { _, service, memoryService, ruleService in
            let destination = Destination.mockFolder("Documents/Receipts")
            let ruleID = UUID()
            let rule = Rule(
                name: "Receipt Rule",
                conditionType: .fileExtension,
                conditionValue: "pdf",
                actionType: .move,
                destination: destination
            )
            rule.id = ruleID
            try ruleService.createRule(rule, source: .ruleEditor)

            let snapshot = makeSnapshot(
                fileName: "Receipt.pdf",
                fileExtension: "pdf",
                fileTypeCategory: .all,
                sourceLocation: .downloads,
                scanRootPath: nil,
                relativeParentPath: "Clients/Acme",
                destination: destination,
                matchedRuleID: ruleID
            )

            for dayOffset in 0..<3 {
                try recordDecision(
                    memoryService: memoryService,
                    snapshot: snapshot,
                    eventKind: .acceptedSuggestion,
                    timestamp: Date().addingTimeInterval(TimeInterval(dayOffset))
                )
            }

            XCTAssertNil(
                try service.recommendedScope(for: snapshot),
                "Explicit rule trust should not be recommended when the reviewed subtree lacks root identity."
            )
        }
    }

    func testRecommendedScope_CategoryEvidenceStaysBoundToReviewedSourceBoundary() throws {
        try withRecommendationServices { _, service, memoryService, _ in
            let destination = Destination.mockFolder("Pictures/Archive")
            let screenshotsSnapshot = makeSnapshot(
                fileName: "Screen Shot.png",
                fileExtension: "png",
                fileTypeCategory: .images,
                sourceLocation: .downloads,
                scanRootPath: "/Users/example/Downloads",
                relativeParentPath: "Screenshots",
                destination: destination
            )
            let cameraSnapshot = makeSnapshot(
                fileName: "Camera Roll.png",
                fileExtension: "png",
                fileTypeCategory: .images,
                sourceLocation: .downloads,
                scanRootPath: "/Users/example/Downloads",
                relativeParentPath: "Camera",
                destination: destination
            )

            for dayOffset in 0..<2 {
                try recordDecision(
                    memoryService: memoryService,
                    snapshot: screenshotsSnapshot,
                    eventKind: .acceptedSuggestion,
                    timestamp: Date().addingTimeInterval(TimeInterval(dayOffset))
                )
                try recordDecision(
                    memoryService: memoryService,
                    snapshot: cameraSnapshot,
                    eventKind: .acceptedSuggestion,
                    timestamp: Date().addingTimeInterval(TimeInterval(dayOffset + 10))
                )
            }

            XCTAssertNil(
                try service.recommendedScope(for: screenshotsSnapshot),
                "Category trust should come from the reviewed boundary itself, not pooled sibling evidence."
            )
        }
    }

    func testRecommendedScope_ExplicitRuleEvidenceStaysBoundToReviewedSourceBoundary() throws {
        try withRecommendationServices { _, service, memoryService, ruleService in
            let destination = Destination.mockFolder("Documents/Receipts")
            let ruleID = UUID()
            let rule = Rule(
                name: "Receipt Rule",
                conditionType: .fileExtension,
                conditionValue: "pdf",
                actionType: .move,
                destination: destination
            )
            rule.id = ruleID
            try ruleService.createRule(rule, source: .ruleEditor)

            let receiptsSnapshot = makeSnapshot(
                fileName: "Receipt.pdf",
                fileExtension: "pdf",
                fileTypeCategory: .all,
                sourceLocation: .downloads,
                scanRootPath: "/Users/example/Downloads",
                relativeParentPath: "Receipts",
                destination: destination,
                matchedRuleID: ruleID
            )
            let invoicesSnapshot = makeSnapshot(
                fileName: "Invoice.pdf",
                fileExtension: "pdf",
                fileTypeCategory: .all,
                sourceLocation: .downloads,
                scanRootPath: "/Users/example/Downloads",
                relativeParentPath: "Invoices",
                destination: destination,
                matchedRuleID: ruleID
            )

            for dayOffset in 0..<2 {
                try recordDecision(
                    memoryService: memoryService,
                    snapshot: receiptsSnapshot,
                    eventKind: .acceptedSuggestion,
                    timestamp: Date().addingTimeInterval(TimeInterval(dayOffset))
                )
                try recordDecision(
                    memoryService: memoryService,
                    snapshot: invoicesSnapshot,
                    eventKind: .acceptedSuggestion,
                    timestamp: Date().addingTimeInterval(TimeInterval(dayOffset + 10))
                )
            }

            XCTAssertNil(
                try service.recommendedScope(for: receiptsSnapshot),
                "Explicit rule trust should only count evidence from the current persisted source boundary."
            )
        }
    }

    func testRecommendedScope_DerivedRuleEvidenceStaysBoundToReviewedSourceBoundary() throws {
        try withRecommendationServices { _, service, memoryService, _ in
            let destination = Destination.mockFolder("Documents/Receipts")
            let downloadsSnapshot = makeSnapshot(
                fileName: "Receipt.pdf",
                fileExtension: "pdf",
                fileTypeCategory: .all,
                sourceLocation: .downloads,
                scanRootPath: "/Users/example/Downloads",
                relativeParentPath: nil,
                destination: destination
            )
            let externalSnapshot = makeSnapshot(
                fileName: "Receipt.pdf",
                fileExtension: "pdf",
                fileTypeCategory: .all,
                sourceLocation: .downloads,
                scanRootPath: "/Volumes/Archive/Downloads Mirror",
                relativeParentPath: nil,
                destination: destination
            )

            for dayOffset in 0..<2 {
                try recordDecision(
                    memoryService: memoryService,
                    snapshot: downloadsSnapshot,
                    eventKind: .acceptedSuggestion,
                    timestamp: Date().addingTimeInterval(TimeInterval(dayOffset))
                )
                try recordDecision(
                    memoryService: memoryService,
                    snapshot: externalSnapshot,
                    eventKind: .acceptedSuggestion,
                    timestamp: Date().addingTimeInterval(TimeInterval(dayOffset + 10))
                )
            }

            XCTAssertNil(
                try service.recommendedScope(for: downloadsSnapshot),
                "Derived rule trust should not pool evidence across different persisted source roots."
            )
        }
    }

    func testRecommendedScope_DoesNotOfferAmbiguousRootlessFolderScope() throws {
        try withRecommendationServices { _, service, memoryService, _ in
            let destination = Destination.mockFolder("Documents/Exports")
            let snapshot = makeSnapshot(
                fileName: "Report.csv",
                fileExtension: "csv",
                fileTypeCategory: .documents,
                sourceLocation: .downloads,
                scanRootPath: nil,
                relativeParentPath: "Clients/Acme",
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

            XCTAssertNil(
                try service.recommendedScope(for: snapshot),
                "Nested folder scopes need root identity, and category fallback should not recreate the same ambiguous boundary."
            )
        }
    }

    func testPromoteFromReviewDecision_RejectsAmbiguousRootlessCategoryBoundary() throws {
        let destinationRoot = try TemporaryDirectory()
        let destination = try Destination.folder(from: try destinationRoot.createDirectory(name: "Screenshots"))

        try withService { context, service in
            let recommendation = TrustedAutomationScopeRecommendation(
                recommendedScope: TrustedAutomationScopeRecommendationOption(
                    scopeType: .category,
                    scopeKey: FileTypeCategory.images.rawValue,
                    displayName: FileTypeCategory.images.displayName,
                    recommendationSource: .repeatedReviewAcceptance,
                    acceptedEvidenceCount: 4,
                    overrideEvidenceCount: 0,
                    undoEvidenceCount: 0,
                    confidenceSnapshot: 0.93,
                    rationaleSummary: "Reviewed images are consistently trusted."
                ),
                alternativeScopes: [],
                snapshot: OrganizationMemorySnapshot(
                    fileName: "Screen Shot.png",
                    fileExtension: "png",
                    fileTypeCategory: .images,
                    sourceLocation: .downloads,
                    scanRootPath: nil,
                    relativeParentPath: "Clients/Acme",
                    suggestionSource: .personalMemory,
                    suggestedDestination: destination,
                    chosenDestination: destination,
                    confidenceScore: 0.93,
                    matchedRuleID: nil
                )
            )

            XCTAssertThrowsError(
                try service.promoteFromReviewDecision(
                    recommendation: recommendation,
                    selectedScopeType: .category
                )
            )
            XCTAssertTrue(try context.fetch(FetchDescriptor<TrustedAutomationScope>()).isEmpty)
        }
    }

    func testPromoteFromReviewDecision_RejectsAmbiguousRootlessRuleBoundary() throws {
        let destinationRoot = try TemporaryDirectory()
        let destination = try Destination.folder(from: try destinationRoot.createDirectory(name: "Receipts"))

        try withRecommendationServices { context, service, _, ruleService in
            let recommendation = TrustedAutomationScopeRecommendation(
                recommendedScope: TrustedAutomationScopeRecommendationOption(
                    scopeType: .rule,
                    scopeKey: "rule:\(UUID().uuidString)",
                    displayName: "Receipt Rule",
                    recommendationSource: .explicitRule,
                    acceptedEvidenceCount: 4,
                    overrideEvidenceCount: 0,
                    undoEvidenceCount: 0,
                    confidenceSnapshot: 0.95,
                    rationaleSummary: "Reviewed rule is consistently trusted."
                ),
                alternativeScopes: [],
                snapshot: OrganizationMemorySnapshot(
                    fileName: "Receipt.pdf",
                    fileExtension: "pdf",
                    fileTypeCategory: .documents,
                    sourceLocation: .downloads,
                    scanRootPath: nil,
                    relativeParentPath: "Clients/Acme",
                    suggestionSource: .rule,
                    suggestedDestination: destination,
                    chosenDestination: destination,
                    confidenceScore: 0.95,
                    matchedRuleID: nil
                )
            )

            XCTAssertThrowsError(
                try service.promoteFromReviewDecision(
                    recommendation: recommendation,
                    selectedScopeType: .rule
                )
            )
            XCTAssertTrue(try context.fetch(FetchDescriptor<TrustedAutomationScope>()).isEmpty)
            XCTAssertTrue(try ruleService.fetchRules().isEmpty)
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
        chosenDestination: Destination? = nil,
        suggestedDestination: Destination? = nil,
        sourceSurface: PersonalMemorySourceSurface? = nil,
        timestamp: Date
    ) throws {
        let resolvedChosenDestination = eventKind == .undoRecovery ? nil : (chosenDestination ?? snapshot.chosenDestination)
        let priorDestination = eventKind == .undoRecovery ? (chosenDestination ?? snapshot.chosenDestination) : nil

        _ = try memoryService.recordDecision(
            fileName: snapshot.fileName,
            fileExtension: snapshot.fileExtension,
            fileTypeCategory: snapshot.fileTypeCategory,
            sourceLocation: snapshot.sourceLocation,
            scanRootPath: snapshot.scanRootPath,
            relativeParentPath: snapshot.relativeParentPath,
            sourceSurface: sourceSurface ?? (eventKind == .undoRecovery ? .undoSurface : .reviewFlow),
            suggestionSource: snapshot.suggestionSource,
            suggestedDestination: suggestedDestination ?? snapshot.suggestedDestination,
            chosenDestination: resolvedChosenDestination,
            confidenceScore: snapshot.confidenceScore,
            matchedRuleID: snapshot.matchedRuleID,
            eventKind: eventKind,
            priorDestination: priorDestination,
            timestamp: timestamp
        )
    }
}
