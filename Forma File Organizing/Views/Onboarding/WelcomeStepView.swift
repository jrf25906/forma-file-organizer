import SwiftUI

// MARK: - Welcome Step View

/// First step: Welcome screen with value propositions and brand illustration
struct WelcomeStepView: View {
    let onContinue: () -> Void

    @State private var animateIn = false
    @State private var floatingOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero section with animated geometric illustration
            VStack(spacing: FormaSpacing.generous) {
                // Animated logo-inspired illustration
                ZStack {
                    // Floating background shapes (subtle movement)
                    Circle()
                        .fill(Color.formaSage.opacity(Color.FormaOpacity.light))
                        .frame(width: 160, height: 160)
                        .offset(x: -30, y: floatingOffset * 0.5)

                    Circle()
                        .fill(Color.formaSteelBlue.opacity(Color.FormaOpacity.subtle))
                        .frame(width: 120, height: 120)
                        .offset(x: 40, y: -20 + floatingOffset * 0.3)

                    // Main geometric icon
                    OnboardingGeometricIcon(style: .welcome)
                        .scaleEffect(animateIn ? 1.0 : 0.8)
                        .opacity(animateIn ? 1.0 : 0)
                }
                .frame(width: 160, height: 120)
                .padding(.bottom, FormaSpacing.tight)

                VStack(spacing: FormaSpacing.tight) {
                    Text("Welcome to Forma")
                        .font(.formaHero)
                        .foregroundColor(.formaLabel)
                        .opacity(animateIn ? 1.0 : 0)
                        .offset(y: animateIn ? 0 : 10)

                    Text("Your files, finally organized")
                        .font(.formaH3)
                        .foregroundColor(.formaSecondaryLabel)
                        .opacity(animateIn ? 1.0 : 0)
                        .offset(y: animateIn ? 0 : 10)
                }
            }

            Spacer()

            // Value props with geometric accents (not SF Symbols)
            VStack(spacing: FormaSpacing.standard) {
                ValuePropCard(
                    accent: .formaSteelBlue,
                    title: "Smart Rules",
                    description: "Set it once, forget it forever",
                    geometryStyle: .rules
                )
                .opacity(animateIn ? 1.0 : 0)
                .offset(x: animateIn ? 0 : -20)

                ValuePropCard(
                    accent: .formaSage,
                    title: "You're in Control",
                    description: "Preview every move before it happens",
                    geometryStyle: .control
                )
                .opacity(animateIn ? 1.0 : 0)
                .offset(x: animateIn ? 0 : -20)

                ValuePropCard(
                    accent: .formaWarmOrange,
                    title: "Your Style",
                    description: "Pick an organization system that fits you",
                    geometryStyle: .style
                )
                .opacity(animateIn ? 1.0 : 0)
                .offset(x: animateIn ? 0 : -20)
            }
            .padding(.horizontal, FormaSpacing.extraLarge)

            Spacer()

            // CTA with playful hover state
            WelcomeCTAButton(action: onContinue)
                .padding(.horizontal, FormaSpacing.huge)
                .padding(.bottom, FormaSpacing.large)
                .opacity(animateIn ? 1.0 : 0)
                .offset(y: animateIn ? 0 : 20)
        }
        .onAppear {
            // Staggered entrance animation
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1)) {
                animateIn = true
            }
            // Subtle floating animation
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                floatingOffset = 8
            }
        }
    }
}

// MARK: - Value Prop Card

struct ValuePropCard: View {
    let accent: Color
    let title: String
    let description: String
    let geometryStyle: GeometryAccentStyle

    enum GeometryAccentStyle {
        case rules, control, style
    }

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: FormaSpacing.standard) {
            // Geometric accent instead of SF Symbol
            GeometryAccent(style: geometryStyle, color: accent, isHovered: isHovered)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.formaBodyLarge)
                    .fontWeight(.semibold)
                    .foregroundColor(.formaLabel)

                Text(description)
                    .font(.formaBody)
                    .foregroundColor(.formaSecondaryLabel)
            }

            Spacer()
        }
        .padding(FormaSpacing.standard)
        .background(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .fill(isHovered ? accent.opacity(Color.FormaOpacity.subtle) : Color.formaControlBackground.opacity(Color.FormaOpacity.strong))
        )
        .overlay(
            RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                .stroke(isHovered ? accent.opacity(Color.FormaOpacity.overlay) : Color.clear, lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Geometry Accent

struct GeometryAccent: View {
    let style: ValuePropCard.GeometryAccentStyle
    let color: Color
    let isHovered: Bool

    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: FormaRadius.card - (FormaRadius.micro / 2), style: .continuous)
                .fill(color.opacity(isHovered ? Color.FormaOpacity.medium : Color.FormaOpacity.light))

            // Geometric shapes based on style
            switch style {
            case .rules:
                // Stacked rectangles representing automation
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: FormaRadius.micro / 2, style: .continuous)
                        .fill(color)
                        .frame(width: 20, height: 5)
                    RoundedRectangle(cornerRadius: FormaRadius.micro / 2, style: .continuous)
                        .fill(color.opacity(Color.FormaOpacity.high))
                        .frame(width: 16, height: 5)
                    RoundedRectangle(cornerRadius: FormaRadius.micro / 2, style: .continuous)
                        .fill(color.opacity(Color.FormaOpacity.strong))
                        .frame(width: 12, height: 5)
                }
                .offset(y: isHovered ? -2 : 0)

            case .control:
                // Eye/preview metaphor with circles
                ZStack {
                    Circle()
                        .stroke(color, lineWidth: 2)
                        .frame(width: 20, height: 20)
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                        .scaleEffect(isHovered ? 1.2 : 1.0)
                }

            case .style:
                // Colorful personality blocks
                HStack(spacing: 3) {
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: FormaRadius.micro / 2, style: .continuous)
                            .fill(color)
                            .frame(width: 10, height: 10)
                        RoundedRectangle(cornerRadius: FormaRadius.micro / 2, style: .continuous)
                            .fill(color.opacity(Color.FormaOpacity.strong))
                            .frame(width: 10, height: 10)
                    }
                    VStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: FormaRadius.micro / 2, style: .continuous)
                            .fill(color.opacity(Color.FormaOpacity.high))
                            .frame(width: 10, height: 10)
                        RoundedRectangle(cornerRadius: FormaRadius.micro / 2, style: .continuous)
                            .fill(color.opacity(Color.FormaOpacity.overlay))
                            .frame(width: 10, height: 10)
                    }
                }
                .rotationEffect(.degrees(isHovered ? 5 : 0))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
    }
}

// MARK: - Welcome CTA Button

struct WelcomeCTAButton: View {
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text("Let's get started")
                    .font(.formaBodyLarge)
                    .fontWeight(.semibold)

                // Animated arrow
                Image(systemName: "arrow.right")
                    .font(.formaBodySemibold)
                    .offset(x: isHovered ? 4 : 0)
            }
            .foregroundColor(.formaBoneWhite)
            .frame(maxWidth: .infinity)
            .padding(.vertical, FormaSpacing.standard)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: FormaRadius.large - (FormaRadius.micro / 2), style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.formaSteelBlue, Color.formaSteelBlue.opacity(Color.FormaOpacity.prominent)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Subtle shine on hover
                    if isHovered {
                        RoundedRectangle(cornerRadius: FormaRadius.large - (FormaRadius.micro / 2), style: .continuous)
                            .fill(Color.formaBoneWhite.opacity(Color.FormaOpacity.light))
                    }
                }
            )
            .shadow(
                color: Color.formaSteelBlue.opacity(isHovered ? Color.FormaOpacity.overlay : Color.FormaOpacity.medium),
                radius: isHovered ? 12 : 8,
                x: 0,
                y: isHovered ? 6 : 4
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isHovered = hovering
            }
        }
        .pressEvents {
            withAnimation(.easeInOut(duration: 0.1)) { isPressed = true }
        } onRelease: {
            withAnimation(.easeInOut(duration: 0.1)) { isPressed = false }
        }
    }
}

// MARK: - Press Events Modifier

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress() }
                .onEnded { _ in onRelease() }
        )
    }
}

// MARK: - Preview

#Preview("Welcome Step") {
    WelcomeStepView(onContinue: {})
        .frame(width: 650, height: 720)
        .background(Color.formaBackground)
}
