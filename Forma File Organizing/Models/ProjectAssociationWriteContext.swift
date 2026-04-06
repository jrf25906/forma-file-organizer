import Foundation

/// Shared inputs for resolving and writing durable project association metadata.
struct ProjectAssociationWriteContext: Sendable, Equatable {
    /// Inspector-safe source summary categories allowed in v1.
    enum SourceSummaryCategory: String, Sendable, Equatable {
        case destinationFolder = "Derived from destination folder"
        case relatedFilePattern = "Derived from related-file pattern"

        var inspectorCopy: String { rawValue }
    }

    /// Inferred project-like candidate supplied by clustering or related-file signals.
    struct InferredCandidate: Sendable, Equatable {
        let suggestedFolderName: String
        let normalizedLabel: String
        let confidence: Double

        init(
            suggestedFolderName: String,
            normalizedLabel: String? = nil,
            confidence: Double
        ) {
            self.suggestedFolderName = suggestedFolderName
            self.normalizedLabel = normalizedLabel ?? suggestedFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
            self.confidence = confidence
        }
    }

    /// Standardized destination folder path when the source was an explicit organize or rule-backed move.
    let resolvedExplicitDestinationFolderPath: String?

    /// Signals that the caller already knows this is an explicit project-like write path.
    ///
    /// Cluster-driven bulk organize flows can set this to mark the write as explicit without
    /// requiring the resolver to sniff provenance from path shape alone.
    let explicitSourceMode: Bool

    /// All inferred candidates available for a best-winner decision.
    let inferredCandidates: [InferredCandidate]

    init(
        resolvedExplicitDestinationFolderPath: String?,
        explicitSourceMode: Bool,
        inferredCandidates: [InferredCandidate]
    ) {
        self.resolvedExplicitDestinationFolderPath = resolvedExplicitDestinationFolderPath
        self.explicitSourceMode = explicitSourceMode
        self.inferredCandidates = inferredCandidates
    }
}
