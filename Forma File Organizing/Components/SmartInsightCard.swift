import SwiftUI

/// Actionable insight card with optional action button.
struct SmartInsightCard: View {
    let insight: SmartInsight
    var onAction: (() -> Void)?
    var onDismiss: (() -> Void)?

    @State private var isHovered = false

    private var iconColor: Color {
        switch insight.category {
        case .cleanup:
            return .formaWarning
        case .organization:
            return .formaSteelBlue
        case .automation:
            return .formaSage
        case .celebration:
            return .formaSoftGreen
        }
    }

    private var backgroundColor: Color {
        switch insight.category {
        case .celebration:
            return Color.formaSoftGreen.opacity(0.08)
        default:
            return Color.formaControlBackground
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: FormaSpacing.standard) {
            // Icon
            Image(systemName: insight.icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 32)

            // Content
            VStack(alignment: .leading, spacing: FormaSpacing.tight) {
                // Title with priority badge
                HStack {
                    Text(insight.title)
                        .font(.formaBodyBold)
                        .foregroundColor(.formaObsidian)

                    if insight.priority == .high {
                        priorityBadge
                    }
                }

                // Detail
                Text(insight.detail)
                    .font(.formaSmall)
                    .foregroundColor(.formaSecondaryLabel)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                // Action button
                if let actionLabel = insight.actionLabel {
                    Button(action: { onAction?() }) {
                        HStack(spacing: 4) {
                            Text(actionLabel)
                            Image(systemName: "arrow.right")
                                .font(.formaSmall)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(actionButtonTint)
                    .controlSize(.small)
                    .padding(.top, FormaSpacing.tight)
                }
            }

            Spacer()

            // Dismiss button
            if onDismiss != nil {
                Button(action: { onDismiss?() }) {
                    Image(systemName: "xmark")
                        .font(.formaSmall)
                        .foregroundColor(.formaSecondaryLabel)
                }
                .buttonStyle(.plain)
                .opacity(isHovered ? 1 : 0.5)
            }
        }
        .padding(FormaSpacing.generous)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(
                    isHovered
                        ? Color.formaObsidian.opacity(Color.FormaOpacity.light)
                        : Color.formaObsidian.opacity(Color.FormaOpacity.subtle)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(
                    Color.formaObsidian.opacity(isHovered ? Color.FormaOpacity.medium : Color.FormaOpacity.light),
                    lineWidth: 1
                )
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var priorityBadge: some View {
        Text("Important")
            .font(.formaMicro)
            .foregroundColor(.formaWarning)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.formaWarning.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous))
    }

    private var actionButtonTint: Color {
        switch insight.category {
        case .cleanup:
            return .formaWarning
        case .organization:
            return .formaSteelBlue
        case .automation:
            return .formaSage
        case .celebration:
            return .formaSoftGreen
        }
    }

    private var borderColor: Color {
        switch insight.category {
        case .celebration:
            return Color.formaSoftGreen.opacity(0.3)
        default:
            return Color.formaSeparator.opacity(Color.FormaOpacity.overlay)
        }
    }
}

// MARK: - Insight List

/// A list of smart insight cards.
struct SmartInsightList: View {
    let insights: [SmartInsight]
    var onAction: ((SmartInsight) -> Void)?
    var onDismiss: ((SmartInsight) -> Void)?

    var body: some View {
        if insights.isEmpty {
            emptyState
        } else {
            VStack(spacing: FormaSpacing.standard) {
                ForEach(insights) { insight in
                    SmartInsightCard(
                        insight: insight,
                        onAction: { onAction?(insight) },
                        onDismiss: onDismiss != nil ? { onDismiss?(insight) } : nil
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: FormaSpacing.tight) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title)
                .foregroundColor(.formaSoftGreen)

            Text("All optimized!")
                .font(.formaBodyBold)
                .foregroundColor(.formaObsidian)

            Text("No recommendations at this time. Great job keeping your files organized!")
                .font(.formaSmall)
                .foregroundColor(.formaSecondaryLabel)
                .multilineTextAlignment(.center)
        }
        .padding(FormaSpacing.generous)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(Color.formaObsidian.opacity(Color.FormaOpacity.subtle))
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .strokeBorder(Color.formaObsidian.opacity(Color.FormaOpacity.light), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview("Smart Insight Cards") {
    let sampleInsights = [
        SmartInsight(
            title: "Screenshot Buildup Detected",
            detail: "70% of your screenshots (45 files) haven't been touched in over a week.",
            icon: "camera.fill",
            actionLabel: "Auto-Archive Screenshots",
            actionType: .archiveScreenshots,
            priority: .high,
            category: .cleanup
        ),
        SmartInsight(
            title: "Automation is Working!",
            detail: "Your rules handled 85% of file organization this period. Nice work!",
            icon: "wand.and.stars",
            priority: .low,
            category: .celebration
        ),
        SmartInsight(
            title: "Downloads Folder Growing",
            detail: "Your Downloads folder contains 2.4 GB. Consider reviewing large or old files.",
            icon: "arrow.down.circle.fill",
            actionLabel: "Review Large Files",
            actionType: .cleanDownloads,
            priority: .medium,
            category: .cleanup
        )
    ]

    VStack(alignment: .leading, spacing: FormaSpacing.large) {
        Text("Smart Insights")
            .font(.formaH2)
            .foregroundColor(.formaObsidian)

        SmartInsightList(
            insights: sampleInsights,
            onAction: { insight in print("Action: \(insight.title)") },
            onDismiss: { insight in print("Dismiss: \(insight.title)") }
        )
    }
    .padding()
    .background(Color.formaBoneWhite)
    .frame(width: 500)
}
