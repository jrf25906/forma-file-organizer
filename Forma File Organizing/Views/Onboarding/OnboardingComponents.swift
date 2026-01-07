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
    private var isPending: Bool { step.rawValue > currentStep.rawValue }

    var body: some View {
        HStack(spacing: FormaSpacing.tight) {
            // Step indicator - geometric style
            ZStack {
                // Background shape (rounded square like logo elements)
                RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
                    .fill(fillColor)
                    .frame(width: 28, height: 28)

                // Content
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.formaCompactSemibold)
                        .foregroundColor(.formaBoneWhite)
                } else {
                    Text("\(step.rawValue)")
                        .font(.formaBodySemibold)
                        .foregroundColor(isCurrent ? .formaBoneWhite : .formaSecondaryLabel)
                }
            }
            .scaleEffect(isCurrent ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)

            // Label
            Text(step.title)
                .font(isCurrent ? .formaBodySemibold : .formaBody)
                .foregroundColor(isCurrent ? .formaLabel : .formaSecondaryLabel)

            // Connector (except for last)
            if !isLast {
                // Geometric connector - small rectangles
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { i in
                        RoundedRectangle(cornerRadius: FormaRadius.micro / 4, style: .continuous)
                            .fill(isCompleted ? Color.formaSage : Color.formaSeparator)
                            .frame(width: 8, height: 3)
                    }
                }
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
                    }
                    .foregroundColor(.formaBoneWhite)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FormaSpacing.standard - (FormaSpacing.micro / 2))
                    .background(
                        RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                            .fill(primaryEnabled ? Color.formaSteelBlue : Color.formaSecondaryLabel.opacity(Color.FormaOpacity.overlay))
                    )
                    .shadow(color: primaryEnabled ? Color.formaSteelBlue.opacity(Color.FormaOpacity.medium) : .clear, radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(!primaryEnabled)
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
        case welcome, folders, style, system
    }

    let style: Style

    var body: some View {
        ZStack {
            switch style {
            case .welcome:
                // Logo-inspired arrangement
                welcomeGeometry
            case .folders:
                foldersGeometry
            case .style:
                styleGeometry
            case .system:
                systemGeometry
            }
        }
    }

    private var welcomeGeometry: some View {
        ZStack {
            // Echoes the logo mark with brand colors
            RoundedRectangle(cornerRadius: FormaRadius.small - (FormaRadius.micro / 4), style: .continuous)
                .fill(Color.formaSteelBlue)
                .frame(width: 28, height: 28)
                .offset(x: -14, y: -14)

            RoundedRectangle(cornerRadius: FormaRadius.small - (FormaRadius.micro / 4), style: .continuous)
                .fill(Color.formaMutedBlue)
                .frame(width: 32, height: 28)
                .offset(x: 14, y: -14)

            RoundedRectangle(cornerRadius: FormaRadius.small - (FormaRadius.micro / 4), style: .continuous)
                .fill(Color.formaMutedBlue)
                .frame(width: 36, height: 36)
                .offset(x: -10, y: 14)

            RoundedRectangle(cornerRadius: FormaRadius.small - (FormaRadius.micro / 4), style: .continuous)
                .fill(Color.formaSage)
                .frame(width: 24, height: 24)
                .offset(x: 20, y: 10)

            RoundedRectangle(cornerRadius: FormaRadius.micro / 2, style: .continuous)
                .fill(Color.formaSoftGreen)
                .frame(width: 24, height: 6)
                .offset(x: 20, y: 28)
        }
    }

    private var foldersGeometry: some View {
        ZStack {
            // Multiple folder shapes stacked
            RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
                .fill(Color.formaSteelBlue.opacity(Color.FormaOpacity.overlay))
                .frame(width: 44, height: 32)
                .offset(x: -6, y: 8)
                .rotationEffect(.degrees(-8))

            RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
                .fill(Color.formaSage.opacity(Color.FormaOpacity.strong))
                .frame(width: 44, height: 32)
                .offset(x: 0, y: 4)
                .rotationEffect(.degrees(-3))

            RoundedRectangle(cornerRadius: FormaRadius.small, style: .continuous)
                .fill(Color.formaSteelBlue)
                .frame(width: 44, height: 32)
                .offset(y: 2)

            // Folder tab
            RoundedRectangle(cornerRadius: FormaRadius.micro - (FormaRadius.micro / 4), style: .continuous)
                .fill(Color.formaSteelBlue.opacity(Color.FormaOpacity.prominent))
                .frame(width: 18, height: 6)
                .offset(x: -11, y: -14)

            // Plus badge
            Circle()
                .fill(Color.formaSage)
                .frame(width: 20, height: 20)
                .offset(x: 20, y: -16)
                .overlay(
                    Image(systemName: "plus")
                        .font(.formaSmallSemibold)
                        .foregroundColor(.formaBoneWhite)
                        .offset(x: 20, y: -16)
                )
        }
    }

    private var styleGeometry: some View {
        ZStack {
            // Personality/style representation with color bars
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: FormaRadius.micro, style: .continuous)
                        .fill(Color.formaSteelBlue)
                        .frame(width: 24, height: 24)
                    RoundedRectangle(cornerRadius: FormaRadius.micro, style: .continuous)
                        .fill(Color.formaSage)
                        .frame(width: 24, height: 24)
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: FormaRadius.micro, style: .continuous)
                        .fill(Color.formaWarmOrange)
                        .frame(width: 24, height: 24)
                    RoundedRectangle(cornerRadius: FormaRadius.micro, style: .continuous)
                        .fill(Color.formaMutedBlue)
                        .frame(width: 24, height: 24)
                }
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
