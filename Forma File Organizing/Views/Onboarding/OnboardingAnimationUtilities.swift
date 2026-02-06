//
//  OnboardingAnimationUtilities.swift
//  Forma - Onboarding Animation Infrastructure
//
//  Centralized animation utilities for the onboarding flow.
//  Builds on FormaAnimation tokens with onboarding-specific choreography.
//

import SwiftUI

// MARK: - Onboarding Spring Tokens

extension FormaAnimation {
    /// Entrance spring -- used for elements appearing on screen
    /// Slightly bouncier than premiumSpring for delight
    static let onboardingEntrance: Animation = .spring(response: 0.55, dampingFraction: 0.78, blendDuration: 0.1)

    /// Converge spring -- used for elements moving toward a target
    /// Longer response for smooth arcing motion
    static let onboardingConverge: Animation = .spring(response: 0.7, dampingFraction: 0.72, blendDuration: 0.1)

    /// Settle spring -- used for elements landing in final position
    /// Tight damping for minimal overshoot
    static let onboardingSettle: Animation = .spring(response: 0.45, dampingFraction: 0.82)

    /// Bounce spring -- used for celebratory/impact moments
    /// Low damping for visible bounce
    static let onboardingBounce: Animation = .spring(response: 0.35, dampingFraction: 0.65)

    /// Compute a staggered delay for cascading animations
    /// - Parameters:
    ///   - index: Element index in the sequence
    ///   - base: Base delay between each element (default 80ms)
    ///   - offset: Initial delay before first element (default 0)
    /// - Returns: Delay in seconds for the given index
    static func staggerDelay(index: Int, base: Double = 0.08, offset: Double = 0) -> Double {
        offset + Double(index) * base
    }
}

// MARK: - Ambient Float Modifier

/// Continuous gentle floating motion with per-element phase offsets.
/// Creates a "breathing" effect where elements drift slightly.
struct AmbientFloatModifier: ViewModifier {
    let xAmplitude: CGFloat
    let yAmplitude: CGFloat
    let duration: Double
    let phaseOffset: Double

    @State private var phase: Double = 0
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    init(
        xAmplitude: CGFloat = 3,
        yAmplitude: CGFloat = 4,
        duration: Double = 3.0,
        phaseOffset: Double = 0
    ) {
        self.xAmplitude = xAmplitude
        self.yAmplitude = yAmplitude
        self.duration = duration
        self.phaseOffset = phaseOffset
    }

    func body(content: Content) -> some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let adjustedTime = elapsed + phaseOffset
            let xOffset = sin(adjustedTime * (2 * .pi / duration)) * Double(xAmplitude)
            let yOffset = cos(adjustedTime * (2 * .pi / (duration * 1.3))) * Double(yAmplitude)

            content
                .offset(x: reduceMotion ? 0 : xOffset, y: reduceMotion ? 0 : yOffset)
        }
    }
}

extension View {
    /// Apply ambient floating motion with unique phase offset
    func ambientFloat(
        xAmplitude: CGFloat = 3,
        yAmplitude: CGFloat = 4,
        duration: Double = 3.0,
        phaseOffset: Double = 0
    ) -> some View {
        self.modifier(AmbientFloatModifier(
            xAmplitude: xAmplitude,
            yAmplitude: yAmplitude,
            duration: duration,
            phaseOffset: phaseOffset
        ))
    }
}

// MARK: - Arc Convergence Values

/// Keyframe values for arc convergence animation.
/// Files move along curved bezier-like paths toward a central point.
struct ArcConvergeValues {
    var offsetX: CGFloat = 0
    var offsetY: CGFloat = 0
    var scale: CGFloat = 1.0
    var opacity: Double = 1.0
    var rotation: Double = 0
}

/// Computes keyframe-style arc convergence.
/// Instead of using KeyframeAnimator directly (which requires a trigger),
/// this provides interpolated values for a given progress (0...1).
struct ArcConvergence {
    let startX: CGFloat
    let startY: CGFloat
    let startRotation: Double
    let controlPointOffset: CGFloat

    /// Interpolate arc position at a given progress (0 = start, 1 = center)
    func position(at progress: Double) -> (x: CGFloat, y: CGFloat) {
        let t = CGFloat(max(0, min(1, progress)))

        // Perpendicular control point for curved path
        let midX = startX / 2
        let midY = startY / 2
        let perpX = -startY / abs(startX + startY + 1) * controlPointOffset
        let perpY = startX / abs(startX + startY + 1) * controlPointOffset
        let ctrlX = midX + perpX
        let ctrlY = midY + perpY

        // Quadratic bezier: B(t) = (1-t)^2 * P0 + 2(1-t)t * P1 + t^2 * P2
        let oneMinusT = 1 - t
        let x = oneMinusT * oneMinusT * startX + 2 * oneMinusT * t * ctrlX + t * t * 0
        let y = oneMinusT * oneMinusT * startY + 2 * oneMinusT * t * ctrlY + t * t * 0

        return (x, y)
    }
}

// MARK: - Onboarding Step Transition

/// Custom transition for onboarding step changes.
/// Incoming: rises from below with spring
/// Outgoing: scales down slightly and fades
struct OnboardingStepTransition: ViewModifier {
    let isInsertion: Bool

    func body(content: Content) -> some View {
        content
            .offset(y: isInsertion ? 0 : 0) // managed by transition below
    }
}

extension AnyTransition {
    /// Premium onboarding step transition.
    /// Forward: new content rises from below; old content shrinks and fades.
    /// Backward: new content slides from left; old content exits right.
    static func onboardingStep(direction: OnboardingTransitionDirection) -> AnyTransition {
        switch direction {
        case .forward:
            return .asymmetric(
                insertion: .offset(y: 30).combined(with: .opacity),
                removal: .scale(scale: 0.97).combined(with: .opacity)
            )
        case .backward:
            return .asymmetric(
                insertion: .offset(y: -20).combined(with: .opacity),
                removal: .scale(scale: 0.97).combined(with: .opacity)
            )
        }
    }
}

/// Direction for onboarding step transitions
enum OnboardingTransitionDirection {
    case forward
    case backward
}

// MARK: - Animated Mesh Background

/// Slowly morphing mesh gradient background in Forma brand colors.
/// Uses TimelineView for continuous animation at ultra-low opacity.
struct AnimatedMeshBackground: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let slow = t * 0.15 // Very slow drift

            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    // Top row
                    SIMD2<Float>(0.0, 0.0),
                    SIMD2<Float>(0.5 + Float(sin(slow * 0.7)) * 0.05, 0.0),
                    SIMD2<Float>(1.0, 0.0),
                    // Middle row -- drifting control points
                    SIMD2<Float>(0.0, 0.5 + Float(cos(slow * 0.9)) * 0.05),
                    SIMD2<Float>(
                        0.5 + Float(sin(slow * 1.1)) * 0.08,
                        0.5 + Float(cos(slow * 0.8)) * 0.08
                    ),
                    SIMD2<Float>(1.0, 0.5 + Float(sin(slow * 0.6)) * 0.05),
                    // Bottom row
                    SIMD2<Float>(0.0, 1.0),
                    SIMD2<Float>(0.5 + Float(cos(slow * 0.5)) * 0.05, 1.0),
                    SIMD2<Float>(1.0, 1.0),
                ],
                colors: [
                    .formaBackground,
                    .formaBackground,
                    .formaBackground,
                    .formaSteelBlue.opacity(0.04),
                    .formaSage.opacity(0.06),
                    .formaMutedBlue.opacity(0.04),
                    .formaBackground,
                    .formaBackground,
                    .formaBackground,
                ]
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Premium Folder View

/// High-quality folder icon using SF Symbol with hierarchical rendering.
/// Replaces the crude stacked-rectangles approach.
struct PremiumFolderView: View {
    let isPulsing: Bool
    var size: CGFloat = 72
    var color: Color = .formaSteelBlue

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        ZStack {
            // Subtle glow behind folder
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.15), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.8
                    )
                )
                .frame(width: size * 2, height: size * 2)

            // SF Symbol folder with hierarchical rendering
            Image(systemName: "folder.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(color)
                .font(.system(size: size))
                .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .scaleEffect(isPulsing && !reduceMotion ? 1.12 : 1.0)
        .animation(
            reduceMotion ? nil : FormaAnimation.onboardingBounce,
            value: isPulsing
        )
    }
}

// MARK: - Gradient Shimmer Sweep

/// One-time shimmer sweep effect for buttons and cards.
/// Sweeps a highlight across the view once, then stops.
struct GradientShimmerSweep: ViewModifier {
    let trigger: Bool
    let delay: Double

    @State private var shimmerPosition: CGFloat = -0.3
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    if !reduceMotion {
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.formaBoneWhite.opacity(0.15),
                                Color.clear,
                            ],
                            startPoint: UnitPoint(x: shimmerPosition - 0.1, y: 0),
                            endPoint: UnitPoint(x: shimmerPosition + 0.1, y: 1)
                        )
                        .allowsHitTesting(false)
                    }
                }
            )
            .clipped()
            .onChange(of: trigger) { _, newValue in
                guard newValue && !reduceMotion else { return }
                shimmerPosition = -0.3
                withAnimation(.easeInOut(duration: 0.8).delay(delay)) {
                    shimmerPosition = 1.3
                }
            }
    }
}

extension View {
    /// Apply a one-time gradient shimmer sweep
    func gradientShimmerSweep(trigger: Bool, delay: Double = 0) -> some View {
        self.modifier(GradientShimmerSweep(trigger: trigger, delay: delay))
    }
}

// MARK: - Progressive Reveal Helper

/// Coordinates staggered reveal of multiple elements.
/// Each element has its own delay based on index.
struct ProgressiveReveal: ViewModifier {
    let isVisible: Bool
    let index: Int
    let baseDelay: Double
    let offsetY: CGFloat

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isVisible || reduceMotion ? 1 : 0)
            .offset(y: isVisible || reduceMotion ? 0 : offsetY)
            .animation(
                reduceMotion ? nil :
                    FormaAnimation.onboardingEntrance
                    .delay(FormaAnimation.staggerDelay(index: index, base: baseDelay)),
                value: isVisible
            )
    }
}

extension View {
    /// Reveal with staggered delay based on index
    func progressiveReveal(
        isVisible: Bool,
        index: Int = 0,
        baseDelay: Double = 0.12,
        offsetY: CGFloat = 16
    ) -> some View {
        self.modifier(ProgressiveReveal(
            isVisible: isVisible,
            index: index,
            baseDelay: baseDelay,
            offsetY: offsetY
        ))
    }
}

// MARK: - Preview

#Preview("Animated Mesh Background") {
    AnimatedMeshBackground()
        .frame(width: 650, height: 720)
}

#Preview("Premium Folder") {
    VStack(spacing: 40) {
        PremiumFolderView(isPulsing: false)
        PremiumFolderView(isPulsing: false, size: 48, color: .formaSage)
    }
    .frame(width: 400, height: 400)
    .background(Color.formaBackground)
}

#Preview("Ambient Float") {
    ZStack {
        ForEach(0..<5, id: \.self) { i in
            Circle()
                .fill(Color.formaSteelBlue)
                .frame(width: 20, height: 20)
                .offset(x: CGFloat(i - 2) * 50)
                .ambientFloat(phaseOffset: Double(i) * 1.2)
        }
    }
    .frame(width: 400, height: 200)
    .background(Color.formaBackground)
}
