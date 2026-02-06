import SwiftUI

// MARK: - Progress Bar

struct OnboardingProgressBar: View {
    let currentStep: OnboardingState.OnboardingStep

    private let steps = OnboardingState.OnboardingStep.allCases.filter { $0 != .welcome }

    var body: some View {
        HStack(spacing: FormaSpacing.generous) {
            ForEach(steps, id: \.rawValue) { step in
                ProgressStep(
                    step: step,
                    currentStep: currentStep,
                    isLast: step == steps.last
                )
            }
        }
        .padding(.vertical, FormaSpacing.standard)
    }
}

struct ProgressStep: View {
    let step: OnboardingState.OnboardingStep
    let currentStep: OnboardingState.OnboardingStep
    let isLast: Bool

    private var isCompleted: Bool { step.rawValue < currentStep.rawValue }
    private var isCurrent: Bool { step == currentStep }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: FormaSpacing.tight) {
            // Step indicator - geometric style
            ZStack {
                // Pulsing glow ring for active step
                if isCurrent && !reduceMotion {
                    Circle()
                        .fill(Color.formaSteelBlue.opacity(0.3))
                        .frame(width: 34, height: 34)
                        .scaleEffect(pulseScale)
                        .onAppear {
                            withAnimation(
                                .easeInOut(duration: 1.2)
                                .repeatForever(autoreverses: true)
                            ) {
                                pulseScale = 1.3
                            }
                        }
                        .onDisappear {
                            pulseScale = 1.0
                        }
                }

                // Background shape (rounded square like logo elements)
                RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
                    .fill(fillColor)
                    .frame(width: 28, height: 28)

                // Content: morph between number and checkmark
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.formaCompactSemibold)
                        .foregroundColor(.formaBoneWhite)
                        .contentTransition(.symbolEffect(.replace))
                } else {
                    Text("\(step.rawValue)")
                        .font(.formaBodySemibold)
                        .foregroundColor(isCurrent ? .formaBoneWhite : .formaSecondaryLabel)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .scaleEffect(isCurrent ? 1.05 : 1.0)
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : (isCurrent ? 0 : -5)),
                axis: (x: 0, y: 1, z: 0)
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)

            // Label
            Text(step.title)
                .font(isCurrent ? .formaBodySemibold : .formaBody)
                .foregroundColor(isCurrent ? .formaLabel : .formaSecondaryLabel)

            // Animated connector bar (except for last)
            if !isLast {
                AnimatedConnectorBar(isCompleted: isCompleted, reduceMotion: reduceMotion)
                    .padding(.leading, FormaSpacing.tight)
            }
        }
    }

    private var fillColor: Color {
        if isCompleted {
            return .formaSage
        } else if isCurrent {
            return .formaSteelBlue
        } else {
            return .formaControlBackground
        }
    }
}

// MARK: - Animated Connector Bar

/// Replaces the 3 static rectangles with a single bar that fills left-to-right.
private struct AnimatedConnectorBar: View {
    let isCompleted: Bool
    let reduceMotion: Bool

    // Total width matches original: 3 rectangles * 8px + 2 gaps * 4px = 32px
    private let barWidth: CGFloat = 32
    private let barHeight: CGFloat = 3

    var body: some View {
        ZStack(alignment: .leading) {
            // Background track
            RoundedRectangle(cornerRadius: barHeight / 2, style: .continuous)
                .fill(Color.formaSeparator)
                .frame(width: barWidth, height: barHeight)

            // Animated fill overlay
            GeometryReader { _ in
                RoundedRectangle(cornerRadius: barHeight / 2, style: .continuous)
                    .fill(Color.formaSage)
                    .frame(
                        width: isCompleted ? barWidth : 0,
                        height: barHeight
                    )
            }
            .frame(width: barWidth, height: barHeight)
            .clipped()
            .animation(
                reduceMotion ? nil : FormaAnimation.onboardingSettle,
                value: isCompleted
            )
        }
        .frame(width: barWidth, height: barHeight)
    }
}

// MARK: - Shared Footer

struct OnboardingFooter: View {
    let primaryTitle: String
    let primaryEnabled: Bool
    let primaryAction: () -> Void
    var secondaryTitle: String? = nil
    var secondaryAction: (() -> Void)? = nil
    var tertiaryTitle: String? = nil
    var tertiaryAction: (() -> Void)? = nil
    var hint: String? = nil

    @State private var isHovered: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: FormaSpacing.standard) {
            // Hint text
            if let hint = hint {
                Text(hint)
                    .font(.formaCompact)
                    .foregroundColor(.formaSecondaryLabel)
            }

            HStack(spacing: FormaSpacing.standard) {
                // Back button
                if let secondaryTitle = secondaryTitle, let secondaryAction = secondaryAction {
                    Button(action: secondaryAction) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.formaCompactSemibold)
                            Text(secondaryTitle)
                                .font(.formaBodyLarge).fontWeight(.medium)
                        }
                        .foregroundColor(.formaSecondaryLabel)
                        .padding(.vertical, FormaSpacing.standard - (FormaSpacing.micro / 2))
                        .padding(.horizontal, FormaSpacing.large)
                        .background(
                            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                                .stroke(Color.formaSeparator, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Primary button
                Button(action: primaryAction) {
                    HStack(spacing: 8) {
                        Text(primaryTitle)
                            .font(.formaBodyLarge).fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                            .font(.formaBodySemibold)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .foregroundColor(.formaBoneWhite)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FormaSpacing.standard - (FormaSpacing.micro / 2))
                    .background(
                        RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                            .fill(primaryEnabled ? Color.formaSteelBlue : Color.formaSecondaryLabel.opacity(Color.FormaOpacity.overlay))
                    )
                    .shadow(color: primaryEnabled ? Color.formaSteelBlue.opacity(Color.FormaOpacity.medium) : .clear, radius: 4, x: 0, y: 2)
                    .formaShimmer(isActive: isHovered && primaryEnabled && !reduceMotion)
                    .clipShape(RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!primaryEnabled)
                .formaPressEffect()
                .onHover { hovering in
                    isHovered = hovering
                }
            }

            // Tertiary action (skip/custom)
            if let tertiaryTitle = tertiaryTitle, let tertiaryAction = tertiaryAction {
                Button(action: tertiaryAction) {
                    Text(tertiaryTitle)
                        .font(.formaBody)
                        .foregroundColor(.formaSecondaryLabel)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(FormaSpacing.large)
        .background(
            Rectangle()
                .fill(Color.formaControlBackground)
                .shadow(color: Color.formaObsidian.opacity(Color.FormaOpacity.subtle), radius: 8, x: 0, y: -4)
        )
    }
}

// MARK: - Geometric Brand Illustration

struct OnboardingGeometricIcon: View {
    enum Style {
        case system
    }

    let style: Style

    var body: some View {
        ZStack {
            switch style {
            case .system:
                systemGeometry
            }
        }
    }

    private var systemGeometry: some View {
        ZStack {
            // Grid/system representation
            RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
                .fill(Color.formaSteelBlue)
                .frame(width: 28, height: 28)
                .offset(x: -12, y: -12)

            RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
                .fill(Color.formaSage)
                .frame(width: 28, height: 28)
                .offset(x: 12, y: -12)

            RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
                .fill(Color.formaMutedBlue)
                .frame(width: 28, height: 28)
                .offset(x: -12, y: 12)

            RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
                .fill(Color.formaWarmOrange)
                .frame(width: 28, height: 28)
                .offset(x: 12, y: 12)
        }
    }
}
