import SwiftUI

// MARK: - First Run Suggestion Banner

/// Post-onboarding prompt shown at the top of MainContentView.
/// Suggests one concrete first-run quick win based on the current scan results.
struct FirstRunSuggestionBanner: View {
    let suggestion: FirstRunQuickWinSuggestion
    let onOrganize: () -> Void
    let onDismiss: () -> Void

    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: FormaSpacing.standard) {
            Image(systemName: suggestion.iconName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.formaSage)

            VStack(alignment: .leading, spacing: 2) {
                Text("Quick first win")
                    .font(.formaCaptionSemibold)
                    .foregroundColor(.formaSage)

                Text(suggestion.titleText)
                    .font(.formaBodySemibold)
                    .foregroundColor(.formaLabel)

                Text(suggestion.detailText)
                    .font(.formaBody)
                    .foregroundColor(.formaLabel)

                Text("Suggested destination: \(suggestion.destinationSummary)")
                    .font(.formaCaption)
                    .foregroundColor(.formaSecondaryLabel)
            }

            Spacer(minLength: 0)

            Button(suggestion.primaryActionTitle) {
                onOrganize()
            }
            .buttonStyle(.plain)
            .font(.formaBodySemibold)
            .foregroundColor(.formaBoneWhite)
            .padding(.horizontal, FormaSpacing.standard)
            .padding(.vertical, FormaSpacing.tight)
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                    .fill(Color.formaSage)
            )

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.formaSecondaryLabel)
            }
            .buttonStyle(.plain)
        }
        .padding(FormaSpacing.standard)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(Color.formaSage.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                        .stroke(Color.formaSage.opacity(0.2), lineWidth: 1)
                )
        )
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : -10)
        .onAppear {
            if reduceMotion {
                isVisible = true
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                    isVisible = true
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("First Run Banner") {
    FirstRunSuggestionBanner(
        suggestion: FirstRunQuickWinSuggestion(
            kind: .screenshots,
            folderName: "Downloads",
            fileCount: 47,
            destinationSummary: "Pictures/Screenshots",
            primaryActionTitle: "Organize Screenshots",
            candidateKey: "screenshots|Downloads|Pictures/Screenshots"
        ),
        onOrganize: {},
        onDismiss: {}
    )
    .padding()
    .background(Color.formaBackground)
}
