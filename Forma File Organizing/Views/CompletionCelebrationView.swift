import SwiftUI

/// A celebratory view shown when the user clears ALL pending files
/// Provides positive reinforcement with confetti animation and encouraging message
struct CompletionCelebrationView: View {
    let filesOrganized: Int
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isAnimating = false
    @State private var confettiParticles: [ConfettiParticle] = []
    @State private var showContent = false

    // Celebration messages for variety
    private let celebrationMessages = [
        "Inbox zero, who?",
        "Look at you go!",
        "Productivity champion!",
        "Clean slate achieved!",
        "You're on fire!",
        "Organized perfection!"
    ]

    var body: some View {
        ZStack {
            // Confetti layer (behind content)
            confettiLayer

            // Main content
            ScrollView {
                VStack(spacing: FormaSpacing.generous) {
                    Spacer()
                        .frame(height: FormaSpacing.extraLarge)

                    // Trophy/celebration icon
                    celebrationIcon

                    // Main message
                    messageSection

                    // Stats
                    statsSection

                    // Continue button
                    continueButton

                    Spacer()
                }
                .padding(.horizontal, FormaSpacing.generous)
                .padding(.vertical, FormaSpacing.generous)
            }
        }
        .background(Color.formaControlBackground.opacity(Color.FormaOpacity.overlay))
        .onAppear {
            startCelebration()
        }
    }

    // MARK: - Confetti Layer

    private var confettiLayer: some View {
        GeometryReader { geometry in
            ForEach(confettiParticles) { particle in
                ConfettiPiece(particle: particle)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Celebration Icon

    private var celebrationIcon: some View {
        ZStack {
            // Outer glow rings
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.formaWarmOrange.opacity(0.3 - Double(index) * 0.1),
                                Color.formaSage.opacity(0.2 - Double(index) * 0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 140 + CGFloat(index) * 20, height: 140 + CGFloat(index) * 20)
                    .scaleEffect(isAnimating ? 1.0 : 0.8)
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .animation(
                        reduceMotion ? .none : .spring(response: 0.8, dampingFraction: 0.6).delay(Double(index) * 0.1),
                        value: isAnimating
                    )
            }

            // Background circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.formaWarmOrange.opacity(Color.FormaOpacity.light),
                            Color.formaSage.opacity(Color.FormaOpacity.medium)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .scaleEffect(isAnimating ? 1.0 : 0.5)
                .opacity(isAnimating ? 1.0 : 0.0)

            // Trophy/party icon
            Image(systemName: "party.popper.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.formaWarmOrange, Color.formaSage],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(isAnimating ? 1.0 : 0.3)
                .opacity(isAnimating ? 1.0 : 0.0)
                .rotationEffect(.degrees(isAnimating ? 0 : -15))
        }
        .animation(
            reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.7).delay(0.1),
            value: isAnimating
        )
    }

    // MARK: - Message Section

    private var messageSection: some View {
        VStack(spacing: FormaSpacing.tight) {
            Text("All Done!")
                .font(.formaH1)
                .fontWeight(.bold)
                .fontDesign(.rounded)
                .foregroundColor(.formaLabel)
                .opacity(showContent ? 1.0 : 0.0)
                .offset(y: showContent ? 0 : 10)

            Text(celebrationMessages.randomElement() ?? "Great job!")
                .font(.formaBodyMedium)
                .foregroundColor(.formaSecondaryLabel)
                .multilineTextAlignment(.center)
                .opacity(showContent ? 1.0 : 0.0)
                .offset(y: showContent ? 0 : 10)
        }
        .padding(.top, FormaSpacing.standard)
        .animation(
            reduceMotion ? .none : .easeOut(duration: 0.4).delay(0.3),
            value: showContent
        )
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(spacing: FormaSpacing.standard) {
            HStack(spacing: FormaSpacing.standard) {
                StatBadge(
                    icon: "checkmark.circle.fill",
                    value: "\(filesOrganized)",
                    label: filesOrganized == 1 ? "File" : "Files",
                    color: .formaSage
                )
            }

            Text("Your workspace is now organized")
                .font(.formaSmall)
                .foregroundColor(.formaTertiaryLabel)
        }
        .padding(FormaSpacing.large)
        .background(Color.formaCardBackground)
        .formaCornerRadius(FormaRadius.card)
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .stroke(Color.formaSeparator.opacity(Color.FormaOpacity.strong), lineWidth: 1)
        )
        .opacity(showContent ? 1.0 : 0.0)
        .offset(y: showContent ? 0 : 15)
        .animation(
            reduceMotion ? .none : .easeOut(duration: 0.4).delay(0.4),
            value: showContent
        )
    }

    // MARK: - Continue Button

    private var continueButton: some View {
        Button(action: {
            dashboardViewModel.returnToDefaultPanel()
        }) {
            Text("Continue")
                .font(.formaBody)
                .foregroundColor(.formaSecondaryLabel)
        }
        .buttonStyle(.plain)
        .padding(.top, FormaSpacing.large)
        .opacity(showContent ? 1.0 : 0.0)
        .animation(
            reduceMotion ? .none : .easeOut(duration: 0.3).delay(0.6),
            value: showContent
        )
    }

    // MARK: - Animation Helpers

    private func startCelebration() {
        if reduceMotion {
            isAnimating = true
            showContent = true
        } else {
            // Generate confetti particles
            generateConfetti()

            // Animate icon
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
                isAnimating = true
            }

            // Show content with delay
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
                showContent = true
            }
        }
    }

    private func generateConfetti() {
        guard !reduceMotion else { return }

        // Create confetti particles with random properties
        confettiParticles = (0..<30).map { _ in
            ConfettiParticle(
                color: [Color.formaWarmOrange, Color.formaSage, Color.formaSteelBlue, Color.formaMutedBlue].randomElement()!,
                size: CGFloat.random(in: 6...12),
                x: CGFloat.random(in: 0...1),
                startY: CGFloat.random(in: -0.2...0),
                endY: CGFloat.random(in: 1.0...1.3),
                rotation: Double.random(in: 0...360),
                delay: Double.random(in: 0...0.5),
                duration: Double.random(in: 2.0...3.5)
            )
        }
    }
}

// MARK: - Confetti Particle Model

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let size: CGFloat
    let x: CGFloat          // Horizontal position (0-1)
    let startY: CGFloat     // Starting Y position (normalized)
    let endY: CGFloat       // Ending Y position (normalized)
    let rotation: Double    // Initial rotation
    let delay: Double       // Animation delay
    let duration: Double    // Animation duration
}

// MARK: - Confetti Piece View

struct ConfettiPiece: View {
    let particle: ConfettiParticle
    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let xPosition = particle.x * geometry.size.width
            let startYPosition = particle.startY * geometry.size.height
            let endYPosition = particle.endY * geometry.size.height

            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(particle.color)
                .frame(width: particle.size, height: particle.size * 1.5)
                .rotationEffect(.degrees(particle.rotation + (isAnimating ? 360 : 0)))
                .position(
                    x: xPosition,
                    y: isAnimating ? endYPosition : startYPosition
                )
                .opacity(isAnimating ? 0 : 1)
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(
                        .easeOut(duration: particle.duration)
                        .delay(particle.delay)
                    ) {
                        isAnimating = true
                    }
                }
        }
    }
}

// MARK: - Stat Badge Component

private struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: FormaSpacing.tight) {
            Image(systemName: icon)
                .font(.formaBodyMedium)
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.formaH3)
                    .fontWeight(.semibold)
                    .foregroundColor(.formaLabel)

                Text(label)
                    .font(.formaCaption)
                    .foregroundColor(.formaSecondaryLabel)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CompletionCelebrationView(filesOrganized: 12)
        .environmentObject(DashboardViewModel())
        .frame(width: 360, height: 600)
        .background(.regularMaterial)
}
