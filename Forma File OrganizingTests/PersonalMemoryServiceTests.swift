import XCTest
import SwiftData
@testable import Forma_File_Organizing

@MainActor
final class PersonalMemoryServiceTests: XCTestCase {

    private func makeService() throws -> (ModelContainer, ModelContext, PersonalMemoryService) {
        let schema = Schema([
            PersonalMemoryEvent.self,
            PersonalMemoryPreference.self,
            LearnedPattern.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        return (container, context, PersonalMemoryService(modelContext: context))
    }

    private func withService(
        _ body: (_ context: ModelContext, _ service: PersonalMemoryService) throws -> Void
    ) throws {
        let (container, context, service) = try makeService()
        try withExtendedLifetime(container) {
            try body(context, service)
        }
    }

    func testRecordAcceptedSuggestionCreatesEventAndPreference() throws {
        try withService { context, service in
            let suggestedDestination = Destination.mockFolder("Documents/Invoices")

            let event = try service.recordDecision(
                fileName: "Invoice-042.pdf",
                fileExtension: "pdf",
                fileTypeCategory: .documents,
                sourceLocation: .downloads,
                scanRootPath: "/Users/example/Downloads",
                relativeParentPath: nil,
                sourceSurface: .reviewFlow,
                suggestionSource: .personalMemory,
                suggestedDestination: suggestedDestination,
                chosenDestination: suggestedDestination,
                confidenceScore: 0.82,
                matchedRuleID: nil
            )

            XCTAssertEqual(event.eventKind, .acceptedSuggestion)
            XCTAssertEqual(event.suggestionSource, .personalMemory)
            XCTAssertEqual(event.chosenDestination?.displayName, "Documents/Invoices")

            let events = try context.fetch(FetchDescriptor<PersonalMemoryEvent>())
            XCTAssertEqual(events.count, 1)

            let preferences = try context.fetch(FetchDescriptor<PersonalMemoryPreference>())
            XCTAssertEqual(preferences.count, 1)

            let preference = try XCTUnwrap(preferences.first)
            XCTAssertEqual(preference.fileExtension, "pdf")
            XCTAssertEqual(preference.sourceLocation, .downloads)
            XCTAssertEqual(preference.preferredDestination?.displayName, "Documents/Invoices")
            XCTAssertEqual(preference.acceptCount, 1)
            XCTAssertEqual(preference.overrideCount, 0)
            XCTAssertEqual(preference.undoCount, 0)
            XCTAssertEqual(preference.correctionCount, 0)
        }
    }

    func testRecordOverrideStrengthensChosenDestinationAndPenalizesSuggestedDestination() throws {
        try withService { context, service in
            let suggestedDestination = Destination.mockFolder("Documents/Invoices")
            let chosenDestination = Destination.mockFolder("Documents/Finance")

            let event = try service.recordDecision(
                fileName: "Invoice-042.pdf",
                fileExtension: "pdf",
                fileTypeCategory: .documents,
                sourceLocation: .downloads,
                scanRootPath: "/Users/example/Downloads",
                relativeParentPath: nil,
                sourceSurface: .reviewFlow,
                suggestionSource: .mlPrediction,
                suggestedDestination: suggestedDestination,
                chosenDestination: chosenDestination,
                confidenceScore: 0.71,
                matchedRuleID: nil
            )

            XCTAssertEqual(event.eventKind, .acceptedWithOverride)

            let preferences = try context.fetch(FetchDescriptor<PersonalMemoryPreference>())
            XCTAssertEqual(preferences.count, 2)

            let chosenPreference = try XCTUnwrap(preferences.first(where: { $0.preferredDestination?.displayName == "Documents/Finance" }))
            XCTAssertEqual(chosenPreference.overrideCount, 1)
            XCTAssertEqual(chosenPreference.correctionCount, 0)

            let rejectedPreference = try XCTUnwrap(preferences.first(where: { $0.preferredDestination?.displayName == "Documents/Invoices" }))
            XCTAssertEqual(rejectedPreference.overrideCount, 0)
            XCTAssertEqual(rejectedPreference.correctionCount, 1)
        }
    }

    func testSuggestionUsesStablePreferenceAfterRepeatedAccepts() throws {
        try withService { _, service in
            let destination = Destination.mockFolder("Documents/Invoices")

            for index in 0..<2 {
                _ = try service.recordDecision(
                    fileName: "Invoice-\(index).pdf",
                    fileExtension: "pdf",
                    fileTypeCategory: .documents,
                    sourceLocation: .downloads,
                    scanRootPath: "/Users/example/Downloads",
                    relativeParentPath: nil,
                    sourceSurface: .reviewFlow,
                    suggestionSource: .personalMemory,
                    suggestedDestination: destination,
                    chosenDestination: destination,
                    confidenceScore: 0.8,
                    matchedRuleID: nil
                )
            }

            let file = FileMetadata(
                path: "/Users/example/Downloads/Invoice-latest.pdf",
                sizeInBytes: 1024,
                creationDate: Date(),
                location: .downloads
            )

            let suggestion = try service.suggestion(for: file)

            XCTAssertEqual(suggestion?.source, .personalMemory)
            XCTAssertEqual(suggestion?.destination?.displayName, "Documents/Invoices")
            XCTAssertGreaterThanOrEqual(try XCTUnwrap(suggestion?.confidence), 0.55)
        }
    }

    func testManualChoiceWithoutSuggestionBuildsPositiveEvidence() throws {
        try withService { context, service in
            let destination = Destination.mockFolder("Documents/Receipts")

            for index in 0..<2 {
                let event = try service.recordDecision(
                    fileName: "Receipt-\(index).pdf",
                    fileExtension: "pdf",
                    fileTypeCategory: .documents,
                    sourceLocation: .downloads,
                    scanRootPath: "/Users/example/Downloads",
                    relativeParentPath: nil,
                    sourceSurface: .reviewFlow,
                    suggestionSource: nil,
                    suggestedDestination: nil,
                    chosenDestination: destination,
                    confidenceScore: nil,
                    matchedRuleID: nil
                )

                XCTAssertNotEqual(event.eventKind, .manualCorrection)
            }

            let preference = try XCTUnwrap(
                try context.fetch(FetchDescriptor<PersonalMemoryPreference>()).first
            )
            XCTAssertEqual(preference.correctionCount, 0)
            XCTAssertGreaterThan(preference.acceptCount + preference.overrideCount, 0)

            let suggestion = try service.suggestion(
                for: FileMetadata(
                    path: "/Users/example/Downloads/Receipt-latest.pdf",
                    sizeInBytes: 1024,
                    creationDate: Date(),
                    location: .downloads
                )
            )

            XCTAssertEqual(suggestion?.destination?.displayName, "Documents/Receipts")
        }
    }

    func testUndoRecoveryPenalizesPreviouslyChosenDestination() throws {
        try withService { context, service in
            let destination = Destination.mockFolder("Documents/Invoices")

            _ = try service.recordDecision(
                fileName: "Invoice-042.pdf",
                fileExtension: "pdf",
                fileTypeCategory: .documents,
                sourceLocation: .downloads,
                scanRootPath: "/Users/example/Downloads",
                relativeParentPath: nil,
                sourceSurface: .reviewFlow,
                suggestionSource: .personalMemory,
                suggestedDestination: destination,
                chosenDestination: destination,
                confidenceScore: 0.82,
                matchedRuleID: nil
            )

            let beforeUndo = try XCTUnwrap(
                try context.fetch(FetchDescriptor<PersonalMemoryPreference>()).first
            )
            let baselineStability = beforeUndo.stabilityScore

            _ = try service.recordDecision(
                fileName: "Invoice-042.pdf",
                fileExtension: "pdf",
                fileTypeCategory: .documents,
                sourceLocation: .downloads,
                scanRootPath: "/Users/example/Downloads",
                relativeParentPath: nil,
                sourceSurface: .undoSurface,
                suggestionSource: .personalMemory,
                suggestedDestination: destination,
                chosenDestination: nil,
                confidenceScore: 0.82,
                matchedRuleID: nil,
                eventKind: .undoRecovery,
                priorDestination: destination
            )

            let preferences = try context.fetch(FetchDescriptor<PersonalMemoryPreference>())
            let preference = try XCTUnwrap(preferences.first)
            XCTAssertEqual(preference.acceptCount, 1)
            XCTAssertEqual(preference.correctionCount, 0)
            XCTAssertEqual(preference.undoCount, 1)
            XCTAssertLessThan(preference.stabilityScore, baselineStability)
        }
    }

    func testUndoRecoveryAfterOverrideDoesNotPenalizeOriginalSuggestionTwice() throws {
        try withService { context, service in
            let suggestedDestination = Destination.mockFolder("Documents/Invoices")
            let chosenDestination = Destination.mockFolder("Documents/Finance")

            _ = try service.recordDecision(
                fileName: "Invoice-042.pdf",
                fileExtension: "pdf",
                fileTypeCategory: .documents,
                sourceLocation: .downloads,
                scanRootPath: "/Users/example/Downloads",
                relativeParentPath: nil,
                sourceSurface: .reviewFlow,
                suggestionSource: .mlPrediction,
                suggestedDestination: suggestedDestination,
                chosenDestination: chosenDestination,
                confidenceScore: 0.71,
                matchedRuleID: nil
            )

            _ = try service.recordDecision(
                fileName: "Invoice-042.pdf",
                fileExtension: "pdf",
                fileTypeCategory: .documents,
                sourceLocation: .downloads,
                scanRootPath: "/Users/example/Downloads",
                relativeParentPath: nil,
                sourceSurface: .undoSurface,
                suggestionSource: .mlPrediction,
                suggestedDestination: suggestedDestination,
                chosenDestination: nil,
                confidenceScore: 0.71,
                matchedRuleID: nil,
                eventKind: .undoRecovery,
                priorDestination: chosenDestination
            )

            let preferences = try context.fetch(FetchDescriptor<PersonalMemoryPreference>())
            let suggestedPreference = try XCTUnwrap(
                preferences.first(where: { $0.preferredDestination?.displayName == "Documents/Invoices" })
            )
            let chosenPreference = try XCTUnwrap(
                preferences.first(where: { $0.preferredDestination?.displayName == "Documents/Finance" })
            )

            XCTAssertEqual(suggestedPreference.correctionCount, 1)
            XCTAssertEqual(suggestedPreference.undoCount, 0)
            XCTAssertEqual(chosenPreference.overrideCount, 1)
            XCTAssertEqual(chosenPreference.undoCount, 1)
        }
    }

    func testUpsertSuggestedPatternsCreatesMemoryBackedPatternAndResetRemovesIt() throws {
        try withService { context, service in
            let destination = Destination.mockFolder("Documents/Invoices")

            for index in 0..<3 {
                _ = try service.recordDecision(
                    fileName: "Invoice-\(index).pdf",
                    fileExtension: "pdf",
                    fileTypeCategory: .documents,
                    sourceLocation: .downloads,
                    scanRootPath: "/Users/example/Downloads",
                    relativeParentPath: nil,
                    sourceSurface: .reviewFlow,
                    suggestionSource: .personalMemory,
                    suggestedDestination: destination,
                    chosenDestination: destination,
                    confidenceScore: 0.84,
                    matchedRuleID: nil
                )
            }

            XCTAssertEqual(try service.upsertSuggestedPatterns(), 1)

            let patterns = try context.fetch(FetchDescriptor<LearnedPattern>())
            let pattern = try XCTUnwrap(patterns.first)
            XCTAssertEqual(pattern.source, .personalMemory)
            XCTAssertEqual(pattern.destination?.displayName, "Documents/Invoices")

            try service.resetAll()

            XCTAssertEqual(try context.fetch(FetchDescriptor<PersonalMemoryEvent>()).count, 0)
            XCTAssertEqual(try context.fetch(FetchDescriptor<PersonalMemoryPreference>()).count, 0)
            XCTAssertEqual(try context.fetch(FetchDescriptor<LearnedPattern>()).count, 0)
        }
    }

    func testSuggestedPatternsCreateSourceScopedRulesOnlyForConvertibleContexts() throws {
        try withService { _, service in
            let rootDestination = Destination.mockFolder("Documents/Invoices")
            let nestedDestination = Destination.mockFolder("Documents/Projects/Alpha")

            for index in 0..<3 {
                _ = try service.recordDecision(
                    fileName: "Invoice-\(index).pdf",
                    fileExtension: "pdf",
                    fileTypeCategory: .documents,
                    sourceLocation: .downloads,
                    scanRootPath: "/Users/example/Downloads",
                    relativeParentPath: nil,
                    sourceSurface: .reviewFlow,
                    suggestionSource: .personalMemory,
                    suggestedDestination: rootDestination,
                    chosenDestination: rootDestination,
                    confidenceScore: 0.84,
                    matchedRuleID: nil
                )

                _ = try service.recordDecision(
                    fileName: "Alpha-\(index).pdf",
                    fileExtension: "pdf",
                    fileTypeCategory: .documents,
                    sourceLocation: .downloads,
                    scanRootPath: "/Users/example/Downloads",
                    relativeParentPath: "Projects/Alpha",
                    sourceSurface: .reviewFlow,
                    suggestionSource: .personalMemory,
                    suggestedDestination: nestedDestination,
                    chosenDestination: nestedDestination,
                    confidenceScore: 0.84,
                    matchedRuleID: nil
                )
            }

            let patterns = try service.suggestedPatterns()
            XCTAssertEqual(patterns.count, 1)

            let rule = LearningService().convertPatternToRule(try XCTUnwrap(patterns.first))
            XCTAssertEqual(rule.conditions.count, 2)
            XCTAssertTrue(
                rule.conditions.contains(.fileExtension("pdf")),
                "Rule should preserve the file extension context"
            )
            XCTAssertTrue(
                rule.conditions.contains(.sourceLocation(.downloads)),
                "Rule should preserve the source-location context"
            )

            let summary = try service.summary()
            XCTAssertEqual(summary.reusablePatternCount, 1)
        }
    }

    func testResetAllClearsEventsAndPreferences() throws {
        try withService { context, service in
            let destination = Destination.mockFolder("Documents/Invoices")

            _ = try service.recordDecision(
                fileName: "Invoice-042.pdf",
                fileExtension: "pdf",
                fileTypeCategory: .documents,
                sourceLocation: .downloads,
                scanRootPath: "/Users/example/Downloads",
                relativeParentPath: nil,
                sourceSurface: .reviewFlow,
                suggestionSource: .personalMemory,
                suggestedDestination: destination,
                chosenDestination: destination,
                confidenceScore: 0.82,
                matchedRuleID: nil
            )

            try service.resetAll()

            XCTAssertEqual(try context.fetch(FetchDescriptor<PersonalMemoryEvent>()).count, 0)
            XCTAssertEqual(try context.fetch(FetchDescriptor<PersonalMemoryPreference>()).count, 0)
        }
    }
}
