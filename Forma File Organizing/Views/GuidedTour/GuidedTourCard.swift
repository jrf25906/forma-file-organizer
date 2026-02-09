//
//  GuidedTourCard.swift
//  Forma File Organizing
//
//  Apple Tips-style tooltip card shown during the guided tour,
//  positioned adjacent to a spotlight cutout.
//

import SwiftUI

// MARK: - GuidedTourCard

struct GuidedTourCard: View {
    let step: GuidedTourStep
    let currentStepIndex: Int
    let totalSteps: Int
    let onNext: () -> Void
    let onSkip: () -> Void

    var body: some View {
        cardBody
            .frame(maxWidth: 300)
            .padding(FormaSpacing.standard)
            .background(
                ZStack {
                    Color.formaCardBackground
                    Rectangle().fill(.ultraThinMaterial)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 4)
            .overlay(arrowOverlay)
    }

    // MARK: - Card Body

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: FormaSpacing.standard) {
            // Icon + Title
            HStack(spacing: FormaSpacing.tight) {
                Image(systemName: step.icon)
                    .font(.system(size: 20))
                    .foregroundColor(.formaSteelBlue)

                Text(step.title)
                    .font(.formaH3)
                    .foregroundColor(.formaLabel)
            }

            // Body text
            Text(step.body)
                .font(.formaBody)
                .foregroundColor(.formaSecondaryLabel)
                .fixedSize(horizontal: false, vertical: true)

            // Feature hint row
            featureHintRow

            // Step dots + action row
            VStack(spacing: FormaSpacing.tight) {
                stepDots
                actionRow
            }
        }
    }

    // MARK: - Step Dots

    private var stepDots: some View {
        HStack(spacing: FormaSpacing.micro) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Circle()
                    .fill(
                        index == currentStepIndex
                            ? Color.formaSteelBlue
                            : Color.formaSecondaryLabel.opacity(0.3)
                    )
                    .frame(width: 6, height: 6)
            }
        }
    }

    // MARK: - Feature Hint Row

    private var featureHintRow: some View {
        let hint = step.featureHint
        return HStack(spacing: FormaSpacing.tight) {
            ForEach(Array(hint.icons.enumerated()), id: \.offset) { _, icon in
                Image(systemName: icon.name)
                    .font(.system(size: 14))
                    .foregroundColor(icon.color)
            }

            Text(hint.label)
                .font(hint.useMonoFont ? .formaMonoSmall : .formaSmall)
                .foregroundColor(.formaTertiaryLabel)
                .lineLimit(1)
        }
        .padding(.horizontal, FormaSpacing.tight)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                .fill(Color.formaControlBackground)
        )
    }

    // MARK: - Action Row

    private var actionRow: some View {
        HStack {
            Button(action: onSkip) {
                Text("Skip tour")
                    .font(.formaSmall)
                    .foregroundColor(.formaSecondaryLabel)
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: onNext) {
                Text(step.isLastStep ? "Done" : "Next")
                    .font(.formaBodySemibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, FormaSpacing.standard)
                    .padding(.vertical, FormaSpacing.micro + 2)
                    .background(Color.formaSteelBlue)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Directional Arrow

    @ViewBuilder
    private var arrowOverlay: some View {
        GeometryReader { geometry in
            let arrowSize: CGFloat = 8
            arrowShape(for: step.tooltipPlacement, size: arrowSize)
                .fill(Color.formaCardBackground)
                .frame(width: arrowSize * 2, height: arrowSize * 2)
                .position(
                    arrowPosition(
                        placement: step.tooltipPlacement,
                        size: geometry.size,
                        arrowSize: arrowSize
                    )
                )
        }
        .allowsHitTesting(false)
    }

    /// Returns a triangle `Shape` rotated to point toward the spotlight
    /// based on the tooltip placement.
    private func arrowShape(for placement: TooltipPlacement, size: CGFloat) -> some Shape {
        ArrowTriangle(placement: placement, size: size)
    }

    /// Computes where the arrow should be positioned on the card edge.
    private func arrowPosition(
        placement: TooltipPlacement,
        size: CGSize,
        arrowSize: CGFloat
    ) -> CGPoint {
        switch placement {
        case .trailing:
            // Card is to the right of the spotlight, arrow points left
            return CGPoint(x: -arrowSize / 2, y: size.height / 2)
        case .leading:
            // Card is to the left of the spotlight, arrow points right
            return CGPoint(x: size.width + arrowSize / 2, y: size.height / 2)
        case .bottom:
            // Card is below the spotlight, arrow points up
            return CGPoint(x: size.width / 2, y: -arrowSize / 2)
        case .top:
            // Card is above the spotlight, arrow points down
            return CGPoint(x: size.width / 2, y: size.height + arrowSize / 2)
        }
    }
}

// MARK: - Arrow Triangle Shape

/// A small triangle that points toward the spotlight cutout.
/// The direction is derived from the tooltip placement.
private struct ArrowTriangle: Shape {
    let placement: TooltipPlacement
    let size: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)

        switch placement {
        case .trailing:
            // Arrow on leading edge, pointing left
            path.move(to: CGPoint(x: center.x - size, y: center.y))
            path.addLine(to: CGPoint(x: center.x, y: center.y - size))
            path.addLine(to: CGPoint(x: center.x, y: center.y + size))
        case .leading:
            // Arrow on trailing edge, pointing right
            path.move(to: CGPoint(x: center.x + size, y: center.y))
            path.addLine(to: CGPoint(x: center.x, y: center.y - size))
            path.addLine(to: CGPoint(x: center.x, y: center.y + size))
        case .bottom:
            // Arrow on top edge, pointing up
            path.move(to: CGPoint(x: center.x, y: center.y - size))
            path.addLine(to: CGPoint(x: center.x - size, y: center.y))
            path.addLine(to: CGPoint(x: center.x + size, y: center.y))
        case .top:
            // Arrow on bottom edge, pointing down
            path.move(to: CGPoint(x: center.x, y: center.y + size))
            path.addLine(to: CGPoint(x: center.x - size, y: center.y))
            path.addLine(to: CGPoint(x: center.x + size, y: center.y))
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#Preview("GuidedTourCard - Trailing Placement") {
    ZStack {
        Color.formaBackground.ignoresSafeArea()

        GuidedTourCard(
            step: .watchedFolders,
            currentStepIndex: 0,
            totalSteps: 5,
            onNext: {},
            onSkip: {}
        )
    }
    .frame(width: 400, height: 300)
}

#Preview("GuidedTourCard - Last Step") {
    ZStack {
        Color.formaBackground.ignoresSafeArea()

        GuidedTourCard(
            step: .organize,
            currentStepIndex: 3,
            totalSteps: 4,
            onNext: {},
            onSkip: {}
        )
    }
    .frame(width: 400, height: 300)
}
