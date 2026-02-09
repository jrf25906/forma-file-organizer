import SwiftUI

// MARK: - Get Started Step View

/// Permission priming screen — prepares the user for the macOS folder picker.
struct GetStartedStepView: View {
    let onStartOrganizing: () -> Void
    let onBack: () -> Void
    let onSkip: () -> Void

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Info Row Data

    private struct InfoRow {
        let icon: String
        let color: Color
        let text: String
    }

    private let infoRows: [InfoRow] = [
        InfoRow(
            icon: "checkmark.shield.fill",
            color: .formaSage,
            text: "A macOS folder picker will appear"
        ),
        InfoRow(
            icon: "hand.tap.fill",
            color: .formaSteelBlue,
            text: "Select your Downloads folder"
        ),
        InfoRow(
            icon: "bolt.fill",
            color: .formaWarmOrange,
            text: "Forma starts scanning immediately"
        ),
    ]

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero section
            VStack(spacing: FormaSpacing.generous) {
                Image(systemName: "folder.badge.gearshape")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.formaSteelBlue)
                    .font(.system(size: 56))
                    .progressiveReveal(isVisible: appeared, index: 0)

                VStack(spacing: FormaSpacing.tight) {
                    Text("Let Forma see your files")
                        .font(.formaDisplayHeading)
                        .foregroundColor(.formaLabel)
                        .multilineTextAlignment(.center)
                        .progressiveReveal(isVisible: appeared, index: 1)

                    Text("We'll ask to access your Downloads folder.\nThis lets Forma scan and organize files for you.")
                        .font(.formaBodyLarge)
                        .foregroundColor(.formaSecondaryLabel)
                        .multilineTextAlignment(.center)
                        .progressiveReveal(isVisible: appeared, index: 2)
                }
            }
            .padding(.horizontal, FormaSpacing.extraLarge)

            Spacer()
                .frame(height: FormaSpacing.large)

            // Info card
            VStack(spacing: FormaSpacing.standard) {
                ForEach(Array(infoRows.enumerated()), id: \.offset) { index, row in
                    infoRowView(row: row)
                        .progressiveReveal(isVisible: appeared, index: index + 3)
                }
            }
            .padding(FormaSpacing.standard)
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .fill(Color.formaControlBackground)
            )
            .padding(.horizontal, FormaSpacing.extraLarge)

            Spacer()

            // Footer
            OnboardingFooter(
                primaryTitle: "Start Organizing",
                primaryEnabled: true,
                primaryAction: onStartOrganizing,
                secondaryTitle: "Back",
                secondaryAction: onBack,
                tertiaryTitle: "Skip for now",
                tertiaryAction: onSkip
            )
        }
        .onAppear {
            guard !reduceMotion else {
                appeared = true
                return
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                appeared = true
            }
        }
    }

    // MARK: - Info Row

    @ViewBuilder
    private func infoRowView(row: InfoRow) -> some View {
        HStack(spacing: FormaSpacing.standard) {
            Image(systemName: row.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(row.color)
                .frame(width: 24, alignment: .center)

            Text(row.text)
                .font(.formaBody)
                .foregroundColor(.formaSecondaryLabel)

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Preview

#Preview("Get Started") {
    GetStartedStepView(
        onStartOrganizing: {},
        onBack: {},
        onSkip: {}
    )
    .frame(width: 520, height: 520)
    .background(Color.formaBackground)
}
