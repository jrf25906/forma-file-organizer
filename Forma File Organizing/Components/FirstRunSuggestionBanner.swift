import SwiftUI

// MARK: - First Run Suggestion Banner

/// Post-onboarding prompt shown at the top of MainContentView.
/// Suggests organizing files in the current folder using PARA template.
/// Dismisses after user acts or after 3 dismissals across sessions.
struct FirstRunSuggestionBanner: View {
    let fileCount: Int
    let folderName: String
    let onOrganize: () -> Void
    let onDismiss: () -> Void

    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: FormaSpacing.standard) {
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.formaSage)

            VStack(alignment: .leading, spacing: 2) {
                Text("Quick first win")
                    .font(.formaCaptionSemibold)
                    .foregroundColor(.formaSage)

                Text("Forma already prepared **\(fileCount) files** from \(folderName). Organize this batch in one tap, or keep reviewing first.")
                    .font(.formaBody)
                    .foregroundColor(.formaLabel)
            }

            Spacer(minLength: 0)

            Button("Organize Batch") {
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
        fileCount: 47,
        folderName: "Downloads",
        onOrganize: {},
        onDismiss: {}
    )
    .padding()
    .background(Color.formaBackground)
}
