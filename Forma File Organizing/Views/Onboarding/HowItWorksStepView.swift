import SwiftUI

// MARK: - How It Works Step View

/// Three-step timeline teaching the Write rule -> Preview -> Undo flow.
struct HowItWorksStepView: View {
    let onContinue: () -> Void
    let onBack: () -> Void

    @State private var appeared = false
    @State private var lineProgress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Timeline Data

    private struct TimelineItem {
        let icon: String
        let color: Color
        let title: String
        let description: String
    }

    private let items: [TimelineItem] = [
        TimelineItem(
            icon: "text.cursor",
            color: .formaSteelBlue,
            title: "Write a rule",
            description: "'PDFs with invoice in the name go to Finances.' That's a real rule. No twelve-tab settings panel."
        ),
        TimelineItem(
            icon: "eye.fill",
            color: .formaSage,
            title: "Preview the batch",
            description: "See every file that matched, where it's going, and why. Uncheck anything that shouldn't move."
        ),
        TimelineItem(
            icon: "arrow.uturn.backward",
            color: .formaWarmOrange,
            title: "Undo the batch",
            description: "If something was wrong, reverse the recent batch in Forma without moving everything back by hand."
        ),
    ]

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Header
            VStack(spacing: FormaSpacing.tight) {
                Text("Three steps. No manual.")
                    .font(.formaDisplayHeading)
                    .foregroundColor(.formaLabel)
                    .multilineTextAlignment(.center)
                    .progressiveReveal(isVisible: appeared, index: 0)

                Text("Most file organizers run in the background and hope for the best.\nForma shows you what it's about to do.")
                    .font(.formaBodyLarge)
                    .foregroundColor(.formaSecondaryLabel)
                    .multilineTextAlignment(.center)
                    .progressiveReveal(isVisible: appeared, index: 1)
            }
            .padding(.horizontal, FormaSpacing.extraLarge)

            Spacer()
                .frame(height: FormaSpacing.large)

            // Timeline
            timelineView
                .padding(.horizontal, FormaSpacing.huge)

            Spacer()

            // Footer
            OnboardingFooter(
                primaryTitle: "Continue",
                primaryEnabled: true,
                primaryAction: onContinue,
                secondaryTitle: "Back",
                secondaryAction: onBack
            )
        }
        .onAppear {
            guard !reduceMotion else {
                appeared = true
                lineProgress = 1
                return
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 0.8).delay(0.3)) {
                lineProgress = 1
            }
        }
    }

    // MARK: - Timeline View

    private var timelineView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                timelineRow(item: item, index: index)
                    .progressiveReveal(isVisible: appeared, index: index + 2)

                if index < items.count - 1 {
                    timelineConnector
                }
            }
        }
    }

    private func timelineRow(item: TimelineItem, index: Int) -> some View {
        HStack(alignment: .top, spacing: FormaSpacing.standard) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(item.color.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: item.icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(item.color)
                    // Scale icon to fit within the circle
                    .frame(width: 28, height: 28)
            }

            // Text
            VStack(alignment: .leading, spacing: FormaSpacing.micro) {
                Text(item.title)
                    .font(.formaH3)
                    .foregroundColor(.formaLabel)

                Text(item.description)
                    .font(.formaBody)
                    .foregroundColor(.formaSecondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, FormaSpacing.micro)
        }
    }

    private var timelineConnector: some View {
        Rectangle()
            .fill(Color.formaSeparator)
            .frame(width: 2, height: 24)
            .mask(
                GeometryReader { geo in
                    Rectangle()
                        .frame(height: geo.size.height * lineProgress)
                }
            )
            .padding(.leading, 23) // Center under 48pt circle
    }
}

// MARK: - Preview

#Preview("How It Works") {
    HowItWorksStepView(
        onContinue: {},
        onBack: {}
    )
    .frame(width: 520, height: 520)
    .background(Color.formaBackground)
}
