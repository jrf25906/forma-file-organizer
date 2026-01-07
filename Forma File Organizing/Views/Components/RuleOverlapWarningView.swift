import SwiftUI

/// Warning dialog shown when a rule overlaps with existing rules.
///
/// This view presents detected overlaps to the user in a clear, actionable format.
/// The user can choose to:
/// - **Save Anyway**: Acknowledge the warning and save the rule
/// - **Edit Rule**: Go back and modify the rule
/// - **Cancel**: Discard changes
///
/// ## Design
///
/// - Non-blocking: Users can always proceed with saving
/// - Informative: Each overlap includes an explanation and optional suggestion
/// - Visual hierarchy: Most severe overlaps shown first with clear iconography
///
struct RuleOverlapWarningView: View {
    let overlaps: [RuleOverlapDetector.RuleOverlap]
    let ruleName: String
    let rulePriority: Int

    let onSaveAnyway: () -> Void
    let onEditRule: () -> Void
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider()

            // Overlap list
            ScrollView {
                VStack(spacing: FormaSpacing.standard) {
                    ForEach(overlaps) { overlap in
                        OverlapCard(overlap: overlap)
                    }
                }
                .padding(FormaSpacing.generous)
            }
            .frame(maxHeight: 300)

            // Priority note
            priorityNote

            Divider()

            // Actions
            actionButtons
        }
        .frame(width: 480)
        .background(Color.formaCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.large, style: .continuous))
        .shadow(color: Color.formaObsidian.opacity(Color.FormaOpacity.medium), radius: 20, y: 10)
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(spacing: FormaSpacing.standard) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.formaIconMedium)
                .foregroundColor(.formaWarning)

            VStack(alignment: .leading, spacing: 4) {
                Text("Similar Rules Detected")
                    .font(.formaH2)
                    .foregroundColor(.formaObsidian)

                Text("Your rule \"\(ruleName)\" may overlap with \(overlaps.count) existing \(overlaps.count == 1 ? "rule" : "rules").")
                    .font(.formaBody)
                    .foregroundColor(.formaSecondaryLabel)
            }

            Spacer()
        }
        .padding(FormaSpacing.generous)
        .background(Color.formaWarning.opacity(Color.FormaOpacity.light))
    }

    private var priorityNote: some View {
        HStack(spacing: FormaSpacing.tight) {
            Image(systemName: "info.circle.fill")
                .font(.formaBodyMedium)
                .foregroundColor(.formaSteelBlue)

            Text("Higher-priority rules take precedence. Your rule is currently **priority #\(rulePriority)**.")
                .font(.formaSmall)
                .foregroundColor(.formaSecondaryLabel)

            Spacer()
        }
        .padding(.horizontal, FormaSpacing.generous)
        .padding(.vertical, FormaSpacing.standard)
        .background(Color.formaSteelBlue.opacity(Color.FormaOpacity.subtle))
    }

    private var actionButtons: some View {
        HStack(spacing: FormaSpacing.standard) {
            // Cancel
            Button(action: onCancel) {
                Text("Cancel")
                    .font(.formaBodyMedium)
                    .foregroundColor(.formaSecondaryLabel)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FormaSpacing.standard)
            }
            .buttonStyle(.plain)
            .background(Color.formaSecondaryLabel.opacity(Color.FormaOpacity.light))
            .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))

            // Edit Rule
            Button(action: onEditRule) {
                Text("Edit Rule")
                    .font(.formaBodyMedium)
                    .foregroundColor(.formaSteelBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FormaSpacing.standard)
            }
            .buttonStyle(.plain)
            .background(Color.formaSteelBlue.opacity(Color.FormaOpacity.light))
            .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))

            // Save Anyway
            Button(action: onSaveAnyway) {
                Text("Save Anyway")
                    .font(.formaBodyMedium)
                    .foregroundColor(.formaBoneWhite)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FormaSpacing.standard)
            }
            .buttonStyle(.plain)
            .background(Color.formaSteelBlue)
            .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
        }
        .padding(FormaSpacing.generous)
    }
}

// MARK: - Overlap Card

/// Card displaying a single rule overlap.
private struct OverlapCard: View {
    let overlap: RuleOverlapDetector.RuleOverlap

    var body: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.tight) {
            // Header with overlap type
            HStack(spacing: FormaSpacing.tight) {
                Image(systemName: overlap.overlapType.iconName)
                    .font(.formaBodySemibold)
                    .foregroundColor(severityColor)

                Text(overlap.overlapType.displayName)
                    .font(.formaSmallMedium)
                    .foregroundColor(severityColor)

                Spacer()

                // Severity badge
                severityBadge
            }

            // Existing rule info
            HStack(spacing: FormaSpacing.tight) {
                Image(systemName: "doc.text.fill")
                    .font(.formaCompact)
                    .foregroundColor(.formaSecondaryLabel)

                Text(overlap.existingRule.categoryName)
                    .font(.formaCaptionSemibold)
                    .foregroundColor(.formaSecondaryLabel)

                Text("/")
                    .foregroundColor(.formaSecondaryLabel.opacity(Color.FormaOpacity.strong))

                Text(overlap.existingRule.conditionsSummary)
                    .font(.formaSmall)
                    .foregroundColor(.formaObsidian)
                    .lineLimit(1)
            }

            // Destination
            if let destination = overlap.existingRule.destination {
                HStack(spacing: FormaSpacing.tight) {
                    Image(systemName: destination.isTrash ? "trash.fill" : "folder.fill")
                        .font(.formaCaption)
                        .foregroundColor(.formaSecondaryLabel)

                    Text(destination.displayName)
                        .font(.formaCaption)
                        .foregroundColor(.formaSecondaryLabel)
                        .lineLimit(1)
                }
            }

            // Explanation
            Text(overlap.explanation)
                .font(.formaSmall)
                .foregroundColor(.formaObsidian)
                .padding(.top, FormaSpacing.micro)

            // Suggestion (if any)
            if let suggestion = overlap.suggestion {
                HStack(alignment: .top, spacing: FormaSpacing.micro) {
                    Image(systemName: "lightbulb.fill")
                        .font(.formaCaption)
                        .foregroundColor(.formaWarning)

                    Text(suggestion)
                        .font(.formaCaption)
                        .foregroundColor(.formaSecondaryLabel)
                        .italic()
                }
                .padding(.top, FormaSpacing.micro)
            }
        }
        .padding(FormaSpacing.standard)
        .background(Color.formaObsidian.opacity(Color.FormaOpacity.subtle - Color.FormaOpacity.ultraSubtle))
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .stroke(severityColor.opacity(Color.FormaOpacity.overlay), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
    }

    private var severityColor: Color {
        switch overlap.overlapType {
        case .exactDuplicate: return .formaError
        case .conflictingDestination: return .formaWarning
        case .subset, .superset: return .formaWarmOrange
        case .partialOverlap: return .formaInfo
        }
    }

    private var severityBadge: some View {
        Text(severityLabel)
            .font(.formaCaptionSemibold)
            .foregroundColor(.formaBoneWhite)
            .padding(.horizontal, FormaSpacing.tight - (FormaSpacing.micro / 2))
            .padding(.vertical, FormaSpacing.micro / 2)
            .background(severityColor)
            .clipShape(Capsule())
    }

    private var severityLabel: String {
        switch overlap.overlapType.severity {
        case 3: return "HIGH"
        case 2: return "MEDIUM"
        case 1: return "LOW"
        default: return "INFO"
        }
    }
}

// MARK: - Preview

#Preview {
    // Create mock overlaps for preview
    struct PreviewWrapper: View {
        var body: some View {
            RuleOverlapWarningView(
                overlaps: [],
                ruleName: "Move Work PDFs",
                rulePriority: 3,
                onSaveAnyway: {},
                onEditRule: {},
                onCancel: {}
            )
            .padding()
        }
    }

    return PreviewWrapper()
}
