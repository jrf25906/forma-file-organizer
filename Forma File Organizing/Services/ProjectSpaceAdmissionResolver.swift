import Foundation

struct ProjectSpaceAdmissionResolver {
    func resolveAdmission(
        projectLabel: String,
        evidence: ProjectSpaceAdmissionEvidence
    ) -> ProjectSpaceAdmissionDecision {
        let normalizedProjectLabel = normalized(projectLabel) ?? projectLabel
        let existingProjectAssociation = normalized(evidence.existingProjectAssociation)
        let dominantDestinationProjectLabel = normalized(evidence.dominantDestinationProjectLabel)
        let sourceFolderProjectLabel = normalized(evidence.sourceFolderProjectLabel)
        let relatedFileProjectLabel = normalized(evidence.relatedFileProjectLabel)

        let alignedSignals = [
            dominantDestinationProjectLabel == normalizedProjectLabel && !evidence.dominantDestinationIsGenericHint ? ProjectSpaceAdmissionSignal.dominantDestination : nil,
            sourceFolderProjectLabel == normalizedProjectLabel ? .sourceFolder : nil,
            relatedFileProjectLabel == normalizedProjectLabel ? .relatedFile : nil
        ].compactMap { $0 }

        let supportingSignals = [
            existingProjectAssociation == normalizedProjectLabel ? ProjectSpaceAdmissionSignal.existingProjectAssociation : nil,
            dominantDestinationProjectLabel == normalizedProjectLabel && evidence.dominantDestinationIsGenericHint ? .genericDestinationHint : nil,
            dominantDestinationProjectLabel == normalizedProjectLabel && !evidence.dominantDestinationIsGenericHint ? .dominantDestination : nil,
            sourceFolderProjectLabel == normalizedProjectLabel ? .sourceFolder : nil,
            relatedFileProjectLabel == normalizedProjectLabel ? .relatedFile : nil
        ].compactMap { $0 }

        let conflictingProjectLabels = Set<String>(
            [
                existingProjectAssociation,
                dominantDestinationProjectLabel,
                sourceFolderProjectLabel,
                relatedFileProjectLabel
            ]
            .compactMap { label in
                guard let label, label != normalizedProjectLabel else {
                    return nil
                }

                return label
            }
        )
        .sorted()

        let snapshot = ProjectSpaceAdmissionEvidenceSnapshot(
            projectLabel: normalizedProjectLabel,
            existingProjectAssociation: existingProjectAssociation,
            alignedSignalCount: alignedSignals.count,
            genericHintCount: dominantDestinationProjectLabel == normalizedProjectLabel && evidence.dominantDestinationIsGenericHint ? 1 : 0,
            conflictingProjectLabels: conflictingProjectLabels,
            supportingSignals: supportingSignals
        )

        if existingProjectAssociation == normalizedProjectLabel {
            return .existingMember(snapshot)
        }

        if conflictingProjectLabels.isEmpty && alignedSignals.count >= 2 {
            return .strongConfirmed(snapshot)
        }

        return .insufficient(snapshot)
    }

    private func normalized(_ label: String?) -> String? {
        guard let trimmed = label?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }

        return trimmed
    }
}
