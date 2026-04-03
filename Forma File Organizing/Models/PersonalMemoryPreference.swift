import Foundation
import SwiftData

@Model
final class PersonalMemoryPreference {
    @Attribute(.unique) var key: String

    var fileExtension: String
    private var fileTypeCategoryRaw: String
    private var sourceLocationRaw: String
    var relativeParentPath: String?
    var destinationIdentity: String
    private var preferredDestinationData: Data?

    var acceptCount: Int
    var overrideCount: Int
    var correctionCount: Int
    var undoCount: Int
    var deferCount: Int
    var lastObservedAt: Date

    var fileTypeCategory: FileTypeCategory {
        get { FileTypeCategory(rawValue: fileTypeCategoryRaw) ?? .documents }
        set { fileTypeCategoryRaw = newValue.rawValue }
    }

    var sourceLocation: FileLocationKind {
        get { FileLocationKind(rawValue: sourceLocationRaw) ?? .unknown }
        set { sourceLocationRaw = newValue.rawValue }
    }

    var preferredDestination: Destination? {
        get { Self.decodeDestination(from: preferredDestinationData) }
        set { preferredDestinationData = Self.encodeDestination(newValue) }
    }

    var totalObservations: Int {
        acceptCount + overrideCount + correctionCount + undoCount + deferCount
    }

    var correctionPenalty: Double {
        let totalNegative = Double(correctionCount) * 2.0 + Double(undoCount) * 2.5
        return totalNegative / max(Double(totalObservations), 1.0)
    }

    var stabilityScore: Double {
        let positive = Double(acceptCount) + Double(overrideCount) * 1.5
        let negative = Double(correctionCount) * 2.0 + Double(undoCount) * 2.5 + Double(deferCount) * 0.25
        let normalized = (positive - negative + Double(totalObservations)) / max(Double(totalObservations) * 2.0, 1.0)
        return min(max(normalized, 0.0), 1.0)
    }

    var confidenceAdjustment: Double {
        min(0.25, evidenceScore * 0.05)
    }

    var evidenceScore: Double {
        Double(acceptCount) + Double(overrideCount) * 1.75 - Double(correctionCount) * 2.0 - Double(undoCount) * 2.5 - Double(deferCount) * 0.25
    }

    var ruleReadinessScore: Double {
        let repetitionFactor = min(Double(acceptCount + overrideCount) / 4.0, 1.0)
        return stabilityScore * repetitionFactor
    }

    var isSuppressed: Bool {
        correctionCount > (acceptCount + overrideCount) || undoCount > acceptCount
    }

    var shouldSuggest: Bool {
        !isSuppressed && evidenceScore >= 2.0 && stabilityScore >= 0.55
    }

    init(
        fileExtension: String,
        fileTypeCategory: FileTypeCategory,
        sourceLocation: FileLocationKind,
        relativeParentPath: String? = nil,
        preferredDestination: Destination,
        acceptCount: Int = 0,
        overrideCount: Int = 0,
        correctionCount: Int = 0,
        undoCount: Int = 0,
        deferCount: Int = 0,
        lastObservedAt: Date = Date()
    ) {
        let destinationIdentity = PersonalMemoryEvent.destinationIdentity(for: preferredDestination) ?? "unknown"
        let normalizedRelativeParentPath = Self.normalizedRelativeParentPath(relativeParentPath)

        self.key = Self.makeKey(
            fileExtension: fileExtension,
            fileTypeCategory: fileTypeCategory,
            sourceLocation: sourceLocation,
            relativeParentPath: normalizedRelativeParentPath,
            destinationIdentity: destinationIdentity
        )
        self.fileExtension = fileExtension.lowercased()
        self.fileTypeCategoryRaw = fileTypeCategory.rawValue
        self.sourceLocationRaw = sourceLocation.rawValue
        self.relativeParentPath = normalizedRelativeParentPath
        self.destinationIdentity = destinationIdentity
        self.preferredDestinationData = Self.encodeDestination(preferredDestination)
        self.acceptCount = acceptCount
        self.overrideCount = overrideCount
        self.correctionCount = correctionCount
        self.undoCount = undoCount
        self.deferCount = deferCount
        self.lastObservedAt = lastObservedAt
    }

    func apply(_ eventKind: PersonalMemoryEventKind, observedAt: Date) {
        switch eventKind {
        case .acceptedSuggestion:
            acceptCount += 1
        case .acceptedWithOverride:
            overrideCount += 1
        case .manualSelection:
            acceptCount += 1
        case .manualCorrection:
            correctionCount += 1
        case .undoRecovery:
            undoCount += 1
        case .suggestionDeferred:
            deferCount += 1
        case .ruleSuggestionAccepted, .ruleSuggestionDismissed:
            break
        }

        lastObservedAt = observedAt
    }

    static func makeKey(
        fileExtension: String,
        fileTypeCategory: FileTypeCategory,
        sourceLocation: FileLocationKind,
        relativeParentPath: String?,
        destinationIdentity: String
    ) -> String {
        [
            fileExtension.lowercased(),
            fileTypeCategory.rawValue,
            sourceLocation.rawValue,
            normalizedRelativeParentPath(relativeParentPath) ?? "_",
            destinationIdentity
        ].joined(separator: "|")
    }

    private static func normalizedRelativeParentPath(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\\\", with: "/")
    }

    private static func encodeDestination(_ destination: Destination?) -> Data? {
        destination.flatMap { try? JSONEncoder().encode($0) }
    }

    private static func decodeDestination(from data: Data?) -> Destination? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(Destination.self, from: data)
    }
}
