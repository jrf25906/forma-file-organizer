//
//  FormaAnimation.swift
//  Forma - Animation System
//
//  Implementation of Forma's animation principles with accessibility support
//  Premium micro-interactions for Apple Design Award quality
//  Based on Brand Guidelines v2.0 (November 2025)
//

import SwiftUI

/// Forma's animation system
/// Purposeful animations that respect accessibility preferences
struct FormaAnimation {

    // MARK: - Standard Timings

    /// Micro-interaction duration (150ms)
    /// Use for: hover, button press, quick feedback
    static let microDuration: Double = 0.15

    /// Standard transition duration (250ms)
    /// Use for: navigation, state changes, most animations
    static let standardDuration: Double = 0.25

    /// Large transition duration (400ms)
    /// Use for: modal appear, sheet slide, major changes
    static let largeDuration: Double = 0.40

    /// Progressive disclosure duration (200ms)
    /// Use for: expand/collapse actions
    static let disclosureDuration: Double = 0.20

    /// Premium entrance duration (300ms)
    /// Use for: hero elements, important state changes
    static let premiumDuration: Double = 0.30

    // MARK: - Easing Curves

    /// Default easing (ease-in-out) - Use for most animations
    static let defaultEasing: Animation = .easeInOut(duration: standardDuration)

    /// Button press easing (ease-out) - Instant feedback
    static let buttonEasing: Animation = .easeOut(duration: microDuration)

    /// Menu appear easing (ease-out) - Snappy feel
    static let menuEasing: Animation = .easeOut(duration: microDuration)

    /// Modal dismiss easing (ease-in) - Fade away
    static let dismissEasing: Animation = .easeIn(duration: standardDuration)

    /// Spring animation (use sparingly)
    static let springEasing: Animation = .spring(response: 0.3, dampingFraction: 0.8)

    /// Premium spring - bouncy, delightful feel
    static let premiumSpring: Animation = .spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0.1)

    /// Gentle spring - subtle, refined feel
    static let gentleSpring: Animation = .spring(response: 0.35, dampingFraction: 0.85)

    /// Interactive spring - responsive, follows finger
    static let responsiveSpring: Animation = .interactiveSpring(response: 0.25, dampingFraction: 0.7, blendDuration: 0.15)

    // MARK: - Specific Animations

    /// Button press animation (scale to 0.95)
    static let buttonPress: Animation = .easeOut(duration: microDuration)

    /// Progress bar fill animation (linear for real progress)
    static let progressFill: Animation = .linear(duration: standardDuration)

    /// Success state animation
    static let successAppear: Animation = .easeOut(duration: largeDuration)

    /// Card hover animation
    static let cardHover: Animation = .spring(response: 0.25, dampingFraction: 0.8)

    /// Selection toggle animation
    static let selectionToggle: Animation = .spring(response: 0.3, dampingFraction: 0.7)

    /// Progressive disclosure animation
    static let disclosure: Animation = .spring(response: 0.35, dampingFraction: 0.8)

    /// Circular progress animation
    static let circularProgress: Animation = .easeInOut(duration: 0.8)
}

// MARK: - View Extensions with Accessibility Support

extension View {
    
    /// Apply Forma standard animation with reduced motion support
    /// - Parameters:
    ///   - value: The value to animate when changed
    ///   - reduceMotion: Environment value for accessibility
    func formaAnimation<V: Equatable>(
        value: V,
        reduceMotion: Bool = false
    ) -> some View {
        self.animation(
            reduceMotion ? nil : FormaAnimation.defaultEasing,
            value: value
        )
    }
    
    /// Apply button press animation
    func formaButtonAnimation<V: Equatable>(
        value: V,
        reduceMotion: Bool = false
    ) -> some View {
        self.animation(
            reduceMotion ? nil : FormaAnimation.buttonEasing,
            value: value
        )
    }
    
    /// Apply spring animation (use sparingly)
    func formaSpringAnimation<V: Equatable>(
        value: V,
        reduceMotion: Bool = false
    ) -> some View {
        self.animation(
            reduceMotion ? nil : FormaAnimation.springEasing,
            value: value
        )
    }
}

// MARK: - Animated Button Style

struct FormaAnimatedButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var isPressed = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.95 : 1.0)
            .animation(FormaAnimation.buttonPress, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == FormaAnimatedButtonStyle {
    static var formaAnimated: FormaAnimatedButtonStyle {
        FormaAnimatedButtonStyle()
    }
}

// MARK: - Transition Helpers

extension AnyTransition {
    
    /// Forma slide transition (for navigation)
    static var formaSlide: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
    
    /// Forma fade transition (simple, respects reduced motion)
    static var formaFade: AnyTransition {
        .opacity
    }
    
    /// Forma scale transition (for modals)
    static var formaScale: AnyTransition {
        .scale(scale: 0.95).combined(with: .opacity)
    }
}

// MARK: - Progress Animation

struct AnimatedProgressBar: View {
    @Binding var progress: Double
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(Color.formaObsidian.opacity(Color.FormaOpacity.light))
                    .frame(height: 2)
                
                // Fill
                Rectangle()
                    .fill(Color.formaSteelBlue)
                    .frame(width: geometry.size.width * CGFloat(progress), height: 2)
                    .animation(
                        reduceMotion ? nil : FormaAnimation.progressFill,
                        value: progress
                    )
            }
        }
        .frame(height: 2)
    }
}

// MARK: - Success Animation View

struct AnimatedSuccessView: View {
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.formaIcon)
            .foregroundColor(.formaSage)
            .scaleEffect(isVisible ? 1.0 : 0.5)
            .opacity(isVisible ? 1.0 : 0.0)
            .onAppear {
                if reduceMotion {
                    isVisible = true
                } else {
                    withAnimation(FormaAnimation.successAppear) {
                        isVisible = true
                    }
                }
            }
    }
}

// MARK: - Loading Spinner with Reduced Motion

struct AccessibleLoadingSpinner: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let message: String
    
    var body: some View {
        VStack(spacing: FormaSpacing.standard) {
            if reduceMotion {
                // Show static indicator for reduced motion
                Image(systemName: "hourglass")
                    .font(.formaH1)
                    .foregroundColor(.formaObsidian)
            } else {
                ProgressView()
                    .scaleEffect(1.2)
                    .progressViewStyle(CircularProgressViewStyle(tint: .formaObsidian))
            }
            
            Text(message)
                .formaSecondaryStyle()
        }
        .formaPaddingGenerous()
    }
}

// MARK: - Hover Effect Helper

struct FormaHoverEffect: ViewModifier {
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    let scaleAmount: CGFloat
    let opacityAmount: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovering && !reduceMotion ? scaleAmount : 1.0)
            .opacity(isHovering ? opacityAmount : 1.0)
            .animation(FormaAnimation.buttonEasing, value: isHovering)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

extension View {
    /// Add subtle hover effect
    func formaHoverEffect(scale: CGFloat = 1.02, opacity: Double = Color.FormaOpacity.prominent + Color.FormaOpacity.light) -> some View {
        self.modifier(FormaHoverEffect(scaleAmount: scale, opacityAmount: opacity))
    }
}

// MARK: - Premium Card Hover Effect

struct PremiumCardHoverEffect: ViewModifier {
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    let enableScale: Bool
    let enableShadow: Bool
    let enableBrightness: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovering && !reduceMotion && enableScale ? 1.015 : 1.0)
            .brightness(isHovering && enableBrightness ? 0.02 : 0)
            .shadow(
                color: isHovering && enableShadow
                    ? Color.formaObsidian.opacity(Color.FormaOpacity.light + Color.FormaOpacity.ultraSubtle)
                    : Color.formaObsidian.opacity(Color.FormaOpacity.ultraSubtle * 3),
                radius: isHovering && enableShadow ? 12 : 6,
                x: 0,
                y: isHovering && enableShadow ? 6 : 3
            )
            .animation(FormaAnimation.cardHover, value: isHovering)
            .onHover { isHovering = $0 }
    }
}

extension View {
    /// Premium card hover with scale, shadow, and brightness
    func premiumCardHover(
        scale: Bool = true,
        shadow: Bool = true,
        brightness: Bool = true
    ) -> some View {
        self.modifier(PremiumCardHoverEffect(
            enableScale: scale,
            enableShadow: shadow,
            enableBrightness: brightness
        ))
    }
}

// MARK: - Press Effect

struct FormaPressEffect: ViewModifier {
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed && !reduceMotion ? 0.96 : 1.0)
            .brightness(isPressed ? -0.05 : 0)
            .animation(FormaAnimation.buttonPress, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

extension View {
    /// Add press-down effect for buttons
    func formaPressEffect() -> some View {
        self.modifier(FormaPressEffect())
    }
}

// MARK: - Bounce Effect (for celebrations/success)

struct FormaBounceEffect: ViewModifier {
    @State private var isBouncing = false
    let trigger: Bool
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isBouncing && !reduceMotion ? 1.1 : 1.0)
            .animation(FormaAnimation.premiumSpring, value: isBouncing)
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    isBouncing = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        isBouncing = false
                    }
                }
            }
    }
}

extension View {
    /// Add bounce effect triggered by a boolean
    func formaBounce(trigger: Bool) -> some View {
        self.modifier(FormaBounceEffect(trigger: trigger))
    }
}

// MARK: - Pulse Effect (for attention)

struct FormaPulseEffect: ViewModifier {
    @State private var isPulsing = false
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing && isActive && !reduceMotion ? 0.7 : 1.0)
            .animation(
                isActive && !reduceMotion
                    ? Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                    : .default,
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

extension View {
    /// Add gentle pulse effect
    func formaPulse(isActive: Bool) -> some View {
        self.modifier(FormaPulseEffect(isActive: isActive))
    }
}

// MARK: - Shimmer Effect (for loading states)

struct FormaShimmerEffect: ViewModifier {
    @State private var shimmerOffset: CGFloat = -1
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    if isActive && !reduceMotion {
                        LinearGradient(
                            colors: [
                                Color.formaBoneWhite.opacity(Color.FormaOpacity.ultraSubtle - Color.FormaOpacity.ultraSubtle),
                                Color.formaBoneWhite.opacity(Color.FormaOpacity.overlay),
                                Color.formaBoneWhite.opacity(Color.FormaOpacity.ultraSubtle - Color.FormaOpacity.ultraSubtle)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 0.5)
                        .offset(x: shimmerOffset * geometry.size.width)
                        .onAppear {
                            withAnimation(
                                Animation.linear(duration: 1.5)
                                    .repeatForever(autoreverses: false)
                            ) {
                                shimmerOffset = 1.5
                            }
                        }
                    }
                }
            )
            .clipped()
    }
}

extension View {
    /// Add shimmer loading effect
    func formaShimmer(isActive: Bool) -> some View {
        self.modifier(FormaShimmerEffect(isActive: isActive))
    }
}

// MARK: - Slide In Effect

struct FormaSlideInEffect: ViewModifier {
    @State private var hasAppeared = false
    let edge: Edge
    let delay: Double
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func body(content: Content) -> some View {
        content
            .offset(
                x: hasAppeared || reduceMotion ? 0 : (edge == .leading ? -30 : (edge == .trailing ? 30 : 0)),
                y: hasAppeared || reduceMotion ? 0 : (edge == .top ? -20 : (edge == .bottom ? 20 : 0))
            )
            .opacity(hasAppeared || reduceMotion ? 1 : 0)
            .animation(
                FormaAnimation.gentleSpring.delay(delay),
                value: hasAppeared
            )
            .onAppear {
                hasAppeared = true
            }
    }
}

extension View {
    /// Slide in from edge on appear
    func formaSlideIn(from edge: Edge = .bottom, delay: Double = 0) -> some View {
        self.modifier(FormaSlideInEffect(edge: edge, delay: delay))
    }
}

// MARK: - Staggered Animation Helper

// MARK: - Preview

#Preview("Animated Success") {
    AnimatedSuccessView()
        .frame(width: 200, height: 200)
}

#if DEBUG
private struct AnimatedProgressPreviewView: View {
    @State private var progress: Double = 0.0

    var body: some View {
        VStack(spacing: 20) {
            AnimatedProgressBar(progress: $progress)
                .frame(width: 300)

            HStack {
                Button("0%") { progress = 0.0 }
                Button("50%") { progress = 0.5 }
                Button("100%") { progress = 1.0 }
            }
        }
        .padding()
    }
}
#endif

#Preview("Animated Progress") {
    AnimatedProgressPreviewView()
}

#Preview("Loading Spinner") {
    AccessibleLoadingSpinner(message: "Scanning your files...")
}
