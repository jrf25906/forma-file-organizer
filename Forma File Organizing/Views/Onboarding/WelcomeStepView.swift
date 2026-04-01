import SwiftUI
import AppKit

// MARK: - Welcome Step View

/// Single-screen onboarding: trust signals + CTA to request Downloads access.
/// No animation delays — content is immediately visible and actionable.
/// Respects reduceMotion by skipping entrance animations entirely.
struct WelcomeStepView: View {
    let onContinue: () -> Void
    let onSkip: () -> Void

    @State private var fileCount: Int?
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero section
            VStack(spacing: FormaSpacing.generous) {
                // App icon placeholder
                Image(systemName: "folder.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.formaSteelBlue)
                    .font(.system(size: 56))

                VStack(spacing: FormaSpacing.tight) {
                    Text("For the perpetually messy")
                        .font(.formaCaptionSemibold)
                        .tracking(0.6)
                        .foregroundColor(.formaSteelBlue)

                    Text("A file organizer for people who gave up on file organizers.")
                        .font(.formaDisplayHero)
                        .foregroundColor(.formaLabel)
                        .multilineTextAlignment(.center)

                    Text(subtitleText)
                        .font(.formaBodyLarge)
                        .foregroundColor(.formaSecondaryLabel)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, FormaSpacing.large)
                }
            }
            .opacity(appeared || reduceMotion ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 12)

            Spacer()
                .frame(height: FormaSpacing.extraLarge)

            // Trust signals card
            VStack(spacing: FormaSpacing.standard) {
                trustSignalRow(
                    icon: "lock.shield.fill",
                    text: "Files never leave your Mac. Everything is local."
                )
                trustSignalRow(
                    icon: "arrow.uturn.backward",
                    text: "Review first, then undo the recent batch if it was wrong."
                )
                trustSignalRow(
                    icon: "eye.slash.fill",
                    text: "No data sent anywhere. No cloud. No tracking."
                )
            }
            .padding(FormaSpacing.standard)
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                    .fill(Color.formaControlBackground)
            )
            .padding(.horizontal, FormaSpacing.extraLarge)
            .opacity(appeared || reduceMotion ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 8)

            Spacer()

            // CTA section
            VStack(spacing: FormaSpacing.standard) {
                // Primary CTA
                Button(action: onContinue) {
                    HStack(spacing: 10) {
                        Text("Review Your Folders")
                            .font(.formaBodyLarge)
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                            .font(.formaBodySemibold)
                    }
                    .foregroundColor(.formaBoneWhite)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, FormaSpacing.standard)
                    .background(
                        RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                            .fill(Color.formaSteelBlue)
                    )
                    .shadow(
                        color: Color.formaSteelBlue.opacity(Color.FormaOpacity.medium),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                }
                .buttonStyle(.plain)

                // Secondary skip
                Button(action: onSkip) {
                    Text("Explore First")
                        .font(.formaBody)
                        .foregroundColor(.formaSecondaryLabel)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, FormaSpacing.huge)
            .padding(.bottom, FormaSpacing.large)
            .opacity(appeared || reduceMotion ? 1 : 0)
        }
        .onAppear {
            countFiles()
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                appeared = true
            }
        }
    }

    // MARK: - Subtitle

    private var subtitleText: String {
        if let count = fileCount, count > 0 {
            return "You have \(count) files waiting to be sorted. Tell Forma where they should go — in plain English, not regex. Preview the batch. Undo the recent batch if something was wrong."
        }
        return "Tell Forma where your files should go — in plain English, not regex. Preview the batch. Undo the recent batch if something was wrong."
    }

    // MARK: - Trust Signal Row

    @ViewBuilder
    private func trustSignalRow(icon: String, text: String) -> some View {
        HStack(spacing: FormaSpacing.standard) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.formaSteelBlue)
                .frame(width: 24, alignment: .center)

            Text(text)
                .font(.formaBody)
                .foregroundColor(.formaSecondaryLabel)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Lightweight File Count

    private func countFiles() {
        Task.detached(priority: .utility) {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let desktopURL = home.appendingPathComponent("Desktop")
            let downloadsURL = home.appendingPathComponent("Downloads")

            var total = 0
            for folder in [desktopURL, downloadsURL] {
                if let contents = try? FileManager.default.contentsOfDirectory(
                    at: folder,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                ) {
                    total += contents.count
                }
            }

            await MainActor.run {
                if total > 0 {
                    fileCount = total
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Welcome Step") {
    WelcomeStepView(
        onContinue: {},
        onSkip: {}
    )
    .frame(width: 520, height: 520)
    .background(Color.formaBackground)
}
