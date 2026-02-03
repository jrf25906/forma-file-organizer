import SwiftUI

enum ConfidenceTooltip {
    static func text(for score: Double, matchReason: String?) -> String {
        let tier = ConfidenceTier.forScore(score)
        var text = "Confidence: \(tier.label) (\(Int(score * 100))%)"
        if let reason = matchReason, !reason.isEmpty {
            text += "\n\n\(reason)"
        }
        return text
    }
}

// MARK: - Confidence Badge

struct ConfidenceBadge: View {
    let score: Double
    let matchReason: String?
    var showsChevron: Bool = false
    var isExpanded: Bool = false

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    private var confidenceLevel: ConfidenceTier {
        ConfidenceTier.forScore(score)
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: confidenceLevel.icon)
                .font(.formaCaptionSemibold)
            Text(confidenceLevel.label)
                .font(.formaCaptionSemibold)

            if showsChevron {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.formaCaptionSemibold)
            }
        }
        .foregroundStyle(confidenceLevel.color)
        .padding(.horizontal, FormaSpacing.tight)
        .padding(.vertical, FormaSpacing.micro)
        .background(
            Capsule()
                .fill(confidenceLevel.color.opacity(Color.FormaOpacity.light))
        )
        .overlay(
            Capsule()
                .strokeBorder(confidenceLevel.color.opacity(isHovered ? Color.FormaOpacity.overlay : Color.FormaOpacity.medium), lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
        .animation(reduceMotion ? nil : .spring(response: 0.2, dampingFraction: 0.8), value: isExpanded)
        .help(showsChevron ? "Tap to \(isExpanded ? "hide" : "show") details" : tooltipText)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var tooltipText: String {
        ConfidenceTooltip.text(for: score, matchReason: matchReason)
    }
}

// MARK: - Confidence Dot

/// Ultra-compact confidence indicator - shows color-coded dot with tooltip
struct ConfidenceDot: View {
    let score: Double
    let matchReason: String?
    var size: CGFloat = 8

    private var confidenceLevel: ConfidenceTier {
        ConfidenceTier.forScore(score)
    }

    var body: some View {
        Circle()
            .fill(confidenceLevel.color)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .strokeBorder(confidenceLevel.color.opacity(Color.FormaOpacity.overlay), lineWidth: 1)
            )
            .help(ConfidenceTooltip.text(for: score, matchReason: matchReason))
    }
}
