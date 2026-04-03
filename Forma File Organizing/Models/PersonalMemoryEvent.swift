import Foundation
import SwiftData

enum PersonalMemoryEventKind: String, Codable, Sendable {
    case acceptedSuggestion
    case acceptedWithOverride
    case manualSelection
    case suggestionDeferred
    case undoRecovery
    case manualCorrection
    case ruleSuggestionAccepted
    case ruleSuggestionDismissed
}

enum PersonalMemorySourceSurface: String, Codable, Sendable {
    case reviewFlow
    case inspector
    case bulkOrganize
    case ruleSuggestion
    case undoSurface
}

@Model
final class PersonalMemoryEvent {
    var id: UUID
    var timestamp: Date

    private var eventKindRaw: String
    private var sourceSurfaceRaw: String
    private var fileTypeCategoryRaw: String
    private var sourceLocationRaw: String

    var fileName: String
    var fileExtension: String
    var scanRootPath: String?
    var relativeParentPath: String?
    var suggestionSourceRaw: String?
    var suggestedDestinationIdentity: String?
    var chosenDestinationIdentity: String?
    var priorDestinationIdentity: String?
    private var suggestedDestinationData: Data?
    private var chosenDestinationData: Data?
    private var priorDestinationData: Data?
    var confidenceScore: Double?
    var matchedRuleID: UUID?
    var relatedDecisionID: UUID?

    var eventKind: PersonalMemoryEventKind {
        get { PersonalMemoryEventKind(rawValue: eventKindRaw) ?? .acceptedSuggestion }
        set { eventKindRaw = newValue.rawValue }
    }

    var sourceSurface: PersonalMemorySourceSurface {
        get { PersonalMemorySourceSurface(rawValue: sourceSurfaceRaw) ?? .reviewFlow }
        set { sourceSurfaceRaw = newValue.rawValue }
    }

    var fileTypeCategory: FileTypeCategory {
        get { FileTypeCategory(rawValue: fileTypeCategoryRaw) ?? .documents }
        set { fileTypeCategoryRaw = newValue.rawValue }
    }

    var sourceLocation: FileLocationKind {
        get { FileLocationKind(rawValue: sourceLocationRaw) ?? .unknown }
        set { sourceLocationRaw = newValue.rawValue }
    }

    var suggestionSource: SuggestionSource? {
        get {
            guard let suggestionSourceRaw else { return nil }
            return SuggestionSource(rawValue: suggestionSourceRaw)
        }
        set {
            suggestionSourceRaw = newValue?.rawValue
        }
    }

    var suggestedDestination: Destination? {
        get { Self.decodeDestination(from: suggestedDestinationData) }
        set {
            suggestedDestinationData = Self.encodeDestination(newValue)
            suggestedDestinationIdentity = Self.destinationIdentity(for: newValue)
        }
    }

    var chosenDestination: Destination? {
        get { Self.decodeDestination(from: chosenDestinationData) }
        set {
            chosenDestinationData = Self.encodeDestination(newValue)
            chosenDestinationIdentity = Self.destinationIdentity(for: newValue)
        }
    }

    var priorDestination: Destination? {
        get { Self.decodeDestination(from: priorDestinationData) }
        set {
            priorDestinationData = Self.encodeDestination(newValue)
            priorDestinationIdentity = Self.destinationIdentity(for: newValue)
        }
    }

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        eventKind: PersonalMemoryEventKind,
        fileName: String,
        fileExtension: String,
        fileTypeCategory: FileTypeCategory,
        sourceLocation: FileLocationKind,
        scanRootPath: String? = nil,
        relativeParentPath: String? = nil,
        sourceSurface: PersonalMemorySourceSurface,
        suggestionSource: SuggestionSource? = nil,
        suggestedDestination: Destination? = nil,
        chosenDestination: Destination? = nil,
        priorDestination: Destination? = nil,
        confidenceScore: Double? = nil,
        matchedRuleID: UUID? = nil,
        relatedDecisionID: UUID? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.eventKindRaw = eventKind.rawValue
        self.sourceSurfaceRaw = sourceSurface.rawValue
        self.fileTypeCategoryRaw = fileTypeCategory.rawValue
        self.sourceLocationRaw = sourceLocation.rawValue
        self.fileName = fileName
        self.fileExtension = fileExtension.lowercased()
        self.scanRootPath = scanRootPath
        self.relativeParentPath = relativeParentPath
        self.suggestionSourceRaw = suggestionSource?.rawValue
        self.suggestedDestinationIdentity = Self.destinationIdentity(for: suggestedDestination)
        self.chosenDestinationIdentity = Self.destinationIdentity(for: chosenDestination)
        self.priorDestinationIdentity = Self.destinationIdentity(for: priorDestination)
        self.suggestedDestinationData = Self.encodeDestination(suggestedDestination)
        self.chosenDestinationData = Self.encodeDestination(chosenDestination)
        self.priorDestinationData = Self.encodeDestination(priorDestination)
        self.confidenceScore = confidenceScore
        self.matchedRuleID = matchedRuleID
        self.relatedDecisionID = relatedDecisionID
    }

    static func destinationIdentity(for destination: Destination?) -> String? {
        guard let destination else { return nil }

        switch destination {
        case .trash:
            return "trash"
        case .folder(_, let displayName):
            let normalized = displayName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            return normalized.isEmpty ? nil : "folder:\(normalized)"
        }
    }

    private static func encodeDestination(_ destination: Destination?) -> Data? {
        destination.flatMap { try? JSONEncoder().encode($0) }
    }

    private static func decodeDestination(from data: Data?) -> Destination? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(Destination.self, from: data)
    }
}
