import Foundation

/// Central resolver for durable project-association writes.
///
/// The resolver keeps all explicit-vs-inferred policy in one place so callers do not
/// duplicate label normalization, exact Projects qualification, or strong-winner gating.
struct MetadataProjectAssociationResolver: Sendable {
    struct ResolvedCandidate: Sendable, Equatable {
        let projectAssociation: String
        let normalizedLabel: String
        let confidence: Double
        let sourceSummaryCategory: ProjectAssociationWriteContext.SourceSummaryCategory
    }

    private static let minimumInferenceConfidence = 0.80
    private static let minimumInferenceMargin = 0.15
    private static let projectsFolderName = "Projects"

    func normalizeLabel(_ label: String) -> String {
        label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func resolveCandidate(from context: ProjectAssociationWriteContext) -> ResolvedCandidate? {
        if let explicit = explicitCandidate(from: context) {
            return explicit
        }

        guard let inferred = strongestInferenceCandidate(from: context.inferredCandidates) else {
            return nil
        }

        return ResolvedCandidate(
            projectAssociation: inferred.suggestedFolderName,
            normalizedLabel: inferred.normalizedLabel,
            confidence: inferred.confidence,
            sourceSummaryCategory: .relatedFilePattern
        )
    }

    func hasExactProjectsParentMatch(for standardizedDestinationFolderPath: String) -> Bool {
        guard let parentFolderName = parentFolderName(for: standardizedDestinationFolderPath) else {
            return false
        }
        return parentFolderName == Self.projectsFolderName
    }

    // MARK: - Explicit Resolution

    private func explicitCandidate(from context: ProjectAssociationWriteContext) -> ResolvedCandidate? {
        guard let standardizedDestinationFolderPath = context.resolvedExplicitDestinationFolderPath else {
            return nil
        }

        guard hasExactProjectsParentMatch(for: standardizedDestinationFolderPath) else {
            return nil
        }

        let destinationURL = URL(fileURLWithPath: standardizedDestinationFolderPath).standardizedFileURL
        let terminalFolderName = destinationURL.lastPathComponent
        let normalizedLabel = normalizeLabel(terminalFolderName)
        guard !normalizedLabel.isEmpty else {
            return nil
        }

        return ResolvedCandidate(
            projectAssociation: terminalFolderName,
            normalizedLabel: normalizedLabel,
            confidence: 1.0,
            sourceSummaryCategory: .destinationFolder
        )
    }

    private func parentFolderName(for standardizedDestinationFolderPath: String) -> String? {
        let destinationURL = URL(fileURLWithPath: standardizedDestinationFolderPath).standardizedFileURL
        let parentFolderName = destinationURL.deletingLastPathComponent().lastPathComponent
        guard !parentFolderName.isEmpty, parentFolderName != "/" else {
            return nil
        }
        return parentFolderName
    }

    // MARK: - Inference

    private func strongestInferenceCandidate(
        from candidates: [ProjectAssociationWriteContext.InferredCandidate]
    ) -> ProjectAssociationWriteContext.InferredCandidate? {
        let normalizedCandidates = candidates.compactMap { candidate -> ProjectAssociationWriteContext.InferredCandidate? in
            let normalizedLabel = normalizeLabel(candidate.normalizedLabel.isEmpty ? candidate.suggestedFolderName : candidate.normalizedLabel)
            guard !normalizedLabel.isEmpty else {
                return nil
            }

            return ProjectAssociationWriteContext.InferredCandidate(
                suggestedFolderName: candidate.suggestedFolderName,
                normalizedLabel: normalizedLabel,
                confidence: candidate.confidence
            )
        }

        let deduplicatedCandidates = bestCandidatesByNormalizedLabel(from: normalizedCandidates)
        guard let topCandidate = deduplicatedCandidates.first,
              topCandidate.confidence >= Self.minimumInferenceConfidence else {
            return nil
        }

        guard let runnerUp = deduplicatedCandidates.dropFirst().first else {
            return topCandidate
        }

        guard topCandidate.confidence - runnerUp.confidence >= Self.minimumInferenceMargin else {
            return nil
        }

        return topCandidate
    }

    private func bestCandidatesByNormalizedLabel(
        from candidates: [ProjectAssociationWriteContext.InferredCandidate]
    ) -> [ProjectAssociationWriteContext.InferredCandidate] {
        let grouped = Dictionary(grouping: candidates, by: \.normalizedLabel)

        return grouped.compactMap { _, group in
            group.max { lhs, rhs in
                if lhs.confidence != rhs.confidence {
                    return lhs.confidence < rhs.confidence
                }
                return lhs.suggestedFolderName > rhs.suggestedFolderName
            }
        }
        .sorted { lhs, rhs in
            if lhs.confidence != rhs.confidence {
                return lhs.confidence > rhs.confidence
            }
            return lhs.normalizedLabel < rhs.normalizedLabel
        }
    }
}
