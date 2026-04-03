import Foundation
import SwiftData

struct PersonalMemorySummary: Equatable, Sendable {
    let learnedDestinationCount: Int
    let reusablePatternCount: Int
    let lastUpdatedAt: Date?
}

@MainActor
final class PersonalMemoryService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func recordDecision(
        fileName: String,
        fileExtension: String,
        fileTypeCategory: FileTypeCategory,
        sourceLocation: FileLocationKind,
        scanRootPath: String?,
        relativeParentPath: String?,
        sourceSurface: PersonalMemorySourceSurface,
        suggestionSource: SuggestionSource? = nil,
        suggestedDestination: Destination?,
        chosenDestination: Destination?,
        confidenceScore: Double?,
        matchedRuleID: UUID?,
        eventKind explicitEventKind: PersonalMemoryEventKind? = nil,
        priorDestination: Destination? = nil,
        relatedDecisionID: UUID? = nil,
        timestamp: Date = Date()
    ) throws -> PersonalMemoryEvent {
        let eventKind = explicitEventKind ?? inferDecisionKind(
            suggestedDestination: suggestedDestination,
            chosenDestination: chosenDestination
        )

        let event = PersonalMemoryEvent(
            timestamp: timestamp,
            eventKind: eventKind,
            fileName: fileName,
            fileExtension: fileExtension,
            fileTypeCategory: fileTypeCategory,
            sourceLocation: sourceLocation,
            scanRootPath: scanRootPath,
            relativeParentPath: relativeParentPath,
            sourceSurface: sourceSurface,
            suggestionSource: suggestionSource,
            suggestedDestination: suggestedDestination,
            chosenDestination: chosenDestination,
            priorDestination: priorDestination,
            confidenceScore: confidenceScore,
            matchedRuleID: matchedRuleID,
            relatedDecisionID: relatedDecisionID
        )

        modelContext.insert(event)

        if let chosenDestination {
            let chosenPreference = findOrCreatePreference(
                fileExtension: fileExtension,
                fileTypeCategory: fileTypeCategory,
                sourceLocation: sourceLocation,
                relativeParentPath: relativeParentPath,
                destination: chosenDestination
            )
            chosenPreference.apply(positiveEventKind(for: eventKind), observedAt: timestamp)
        }

        if shouldPenalizeSuggestedDestination(for: eventKind),
           let suggestedDestination,
           PersonalMemoryEvent.destinationIdentity(for: suggestedDestination) != PersonalMemoryEvent.destinationIdentity(for: chosenDestination) {
            let suggestedPreference = findOrCreatePreference(
                fileExtension: fileExtension,
                fileTypeCategory: fileTypeCategory,
                sourceLocation: sourceLocation,
                relativeParentPath: relativeParentPath,
                destination: suggestedDestination
            )
            suggestedPreference.apply(.manualCorrection, observedAt: timestamp)
        }

        if eventKind == .undoRecovery, let priorDestination {
            let priorPreference = findOrCreatePreference(
                fileExtension: fileExtension,
                fileTypeCategory: fileTypeCategory,
                sourceLocation: sourceLocation,
                relativeParentPath: relativeParentPath,
                destination: priorDestination
            )
            priorPreference.apply(.undoRecovery, observedAt: timestamp)
        }

        try modelContext.save()
        return event
    }

    func suggestion(
        for file: FileMetadata
    ) throws -> PredictedDestination? {
        guard let preference = try bestPreference(
            fileExtension: file.fileExtension,
            fileTypeCategory: FileTypeCategory.category(for: file.fileExtension),
            sourceLocation: file.location,
            relativeParentPath: file.relativeParentPath
        ),
        let destination = preference.preferredDestination else {
            return nil
        }

        let evidenceCount = preference.acceptCount + preference.overrideCount
        let confidence = min(0.98, max(0.55, preference.stabilityScore * 0.7 + 0.25))
        let summary = explanationSummary(for: file, preference: preference, evidenceCount: evidenceCount)
        let reasons = [
            "You have sent similar files here \(evidenceCount) time\(evidenceCount == 1 ? "" : "s").",
            "Corrections and undo behavior remain low in this context."
        ]

        return PredictedDestination(
            path: destination.displayName,
            confidence: confidence,
            source: .personalMemory,
            explanation: PredictionExplanation(summary: summary, reasons: reasons),
            modelVersion: "personal-memory-v1",
            bookmarkData: destination.bookmarkData
        )
    }

    func bestPreference(
        fileExtension: String,
        fileTypeCategory: FileTypeCategory,
        sourceLocation: FileLocationKind,
        relativeParentPath: String?
    ) throws -> PersonalMemoryPreference? {
        let descriptor = FetchDescriptor<PersonalMemoryPreference>()
        let preferences = try modelContext.fetch(descriptor)

        return preferences
            .filter {
                $0.fileExtension == fileExtension.lowercased() &&
                $0.fileTypeCategory == fileTypeCategory &&
                $0.sourceLocation == sourceLocation &&
                $0.relativeParentPath == normalizedRelativeParentPath(relativeParentPath) &&
                $0.shouldSuggest
            }
            .sorted {
                if $0.evidenceScore == $1.evidenceScore {
                    return $0.lastObservedAt > $1.lastObservedAt
                }
                return $0.evidenceScore > $1.evidenceScore
            }
            .first
    }

    func suggestedPatterns(minimumEvidence: Int = 3) throws -> [LearnedPattern] {
        let descriptor = FetchDescriptor<PersonalMemoryPreference>(
            sortBy: [SortDescriptor(\.lastObservedAt, order: .reverse)]
        )
        let preferences = try modelContext.fetch(descriptor)

        return preferences.compactMap { preference in
            let evidenceCount = preference.acceptCount + preference.overrideCount
            guard evidenceCount >= minimumEvidence,
                  preference.ruleReadinessScore >= 0.65,
                  !preference.isSuppressed,
                  preference.relativeParentPath == nil,
                  let destination = preference.preferredDestination else {
                return nil
            }

            let patternDescription = "\(preference.fileExtension.uppercased()) files from \(preference.sourceLocation.displayName) usually go to \(destination.displayName)"
            return LearnedPattern(
                patternDescription: patternDescription,
                fileExtension: preference.fileExtension,
                destinationPath: destination.displayName,
                destinationBookmarkData: destination.bookmarkData,
                occurrenceCount: evidenceCount,
                source: .personalMemory,
                confidenceScore: min(0.98, max(0.55, preference.stabilityScore)),
                lastSeenDate: preference.lastObservedAt,
                conditions: [
                    .fileExtension(preference.fileExtension),
                    .sourceLocation(preference.sourceLocation)
                ],
                logicalOperator: .and
            )
        }
    }

    @discardableResult
    func upsertSuggestedPatterns(minimumEvidence: Int = 3) throws -> Int {
        let desiredPatterns = try suggestedPatterns(minimumEvidence: minimumEvidence)
        let desiredKeys = Set(desiredPatterns.map(patternKey(for:)))

        let descriptor = FetchDescriptor<LearnedPattern>()
        let existingPatterns = try modelContext.fetch(descriptor)
        let existingMemoryPatterns = existingPatterns.filter { $0.source == .personalMemory }
        var existingByKey = Dictionary(
            uniqueKeysWithValues: existingMemoryPatterns.map { (patternKey(for: $0), $0) }
        )

        for desired in desiredPatterns {
            let key = patternKey(for: desired)
            if let existing = existingByKey.removeValue(forKey: key) {
                existing.patternDescription = desired.patternDescription
                existing.destinationPath = desired.destinationPath
                existing.destinationBookmarkData = desired.destinationBookmarkData
                existing.destination = desired.destination
                existing.occurrenceCount = desired.occurrenceCount
                existing.confidenceScore = desired.confidenceScore
                existing.lastSeenDate = desired.lastSeenDate
                existing.conditions = desired.conditions
                existing.logicalOperator = desired.logicalOperator
                existing.source = .personalMemory
            } else {
                modelContext.insert(desired)
            }
        }

        for stalePattern in existingByKey.values where !desiredKeys.contains(patternKey(for: stalePattern)) {
            modelContext.delete(stalePattern)
        }

        try modelContext.save()
        return desiredPatterns.count
    }

    func summary() throws -> PersonalMemorySummary {
        let preferenceDescriptor = FetchDescriptor<PersonalMemoryPreference>()
        let eventDescriptor = FetchDescriptor<PersonalMemoryEvent>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        let preferences = try modelContext.fetch(preferenceDescriptor)
        let lastEvent = try modelContext.fetch(eventDescriptor).first

        return PersonalMemorySummary(
            learnedDestinationCount: preferences.count,
            reusablePatternCount: try suggestedPatterns().count,
            lastUpdatedAt: lastEvent?.timestamp
        )
    }

    func resetAll() throws {
        try deleteAll(PersonalMemoryEvent.self)
        try deleteAll(PersonalMemoryPreference.self)
        try deleteDerivedPatterns()
        try modelContext.save()
    }

    private func inferDecisionKind(
        suggestedDestination: Destination?,
        chosenDestination: Destination?
    ) -> PersonalMemoryEventKind {
        guard let chosenDestination else { return .suggestionDeferred }
        if PersonalMemoryEvent.destinationIdentity(for: suggestedDestination) == PersonalMemoryEvent.destinationIdentity(for: chosenDestination) {
            return suggestedDestination == nil ? .manualSelection : .acceptedSuggestion
        }
        return suggestedDestination == nil ? .manualSelection : .acceptedWithOverride
    }

    private func positiveEventKind(for eventKind: PersonalMemoryEventKind) -> PersonalMemoryEventKind {
        switch eventKind {
        case .acceptedSuggestion,
             .acceptedWithOverride,
             .manualSelection,
             .manualCorrection,
             .suggestionDeferred,
             .ruleSuggestionAccepted,
             .ruleSuggestionDismissed:
            return eventKind
        case .undoRecovery:
            return .manualCorrection
        }
    }

    private func shouldPenalizeSuggestedDestination(for eventKind: PersonalMemoryEventKind) -> Bool {
        switch eventKind {
        case .acceptedWithOverride, .manualCorrection:
            return true
        case .acceptedSuggestion,
             .manualSelection,
             .suggestionDeferred,
             .undoRecovery,
             .ruleSuggestionAccepted,
             .ruleSuggestionDismissed:
            return false
        }
    }

    private func findOrCreatePreference(
        fileExtension: String,
        fileTypeCategory: FileTypeCategory,
        sourceLocation: FileLocationKind,
        relativeParentPath: String?,
        destination: Destination
    ) -> PersonalMemoryPreference {
        let destinationIdentity = PersonalMemoryEvent.destinationIdentity(for: destination) ?? "unknown"
        let key = PersonalMemoryPreference.makeKey(
            fileExtension: fileExtension,
            fileTypeCategory: fileTypeCategory,
            sourceLocation: sourceLocation,
            relativeParentPath: normalizedRelativeParentPath(relativeParentPath),
            destinationIdentity: destinationIdentity
        )

        let descriptor = FetchDescriptor<PersonalMemoryPreference>(
            predicate: #Predicate<PersonalMemoryPreference> { $0.key == key }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            return existing
        }

        let newPreference = PersonalMemoryPreference(
            fileExtension: fileExtension,
            fileTypeCategory: fileTypeCategory,
            sourceLocation: sourceLocation,
            relativeParentPath: normalizedRelativeParentPath(relativeParentPath),
            preferredDestination: destination
        )
        modelContext.insert(newPreference)
        return newPreference
    }

    private func explanationSummary(
        for file: FileMetadata,
        preference: PersonalMemoryPreference,
        evidenceCount: Int
    ) -> String {
        let category = FileTypeCategory.category(for: file.fileExtension).displayName.lowercased()
        return "Based on how you usually organize \(category) from \(file.location.displayName), Forma has seen this choice \(evidenceCount) time\(evidenceCount == 1 ? "" : "s")."
    }

    private func normalizedRelativeParentPath(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\\\", with: "/")
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) throws {
        let descriptor = FetchDescriptor<T>()
        let models = try modelContext.fetch(descriptor)
        for model in models {
            modelContext.delete(model)
        }
    }

    private func deleteDerivedPatterns() throws {
        let descriptor = FetchDescriptor<LearnedPattern>()
        let patterns = try modelContext.fetch(descriptor)
        for pattern in patterns where pattern.source == .personalMemory {
            modelContext.delete(pattern)
        }
    }

    private func patternKey(for pattern: LearnedPattern) -> String {
        let conditionKey = pattern.conditions
            .map(\.displayDescription)
            .sorted()
            .joined(separator: "&")

        return [
            pattern.source.rawValue,
            pattern.fileExtension.lowercased(),
            pattern.destinationPath,
            pattern.logicalOperator.rawValue,
            conditionKey
        ].joined(separator: "|")
    }
}
