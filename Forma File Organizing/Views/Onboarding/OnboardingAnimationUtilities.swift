//
//  OnboardingAnimationUtilities.swift
//  Forma - Onboarding Animation Infrastructure
//
//  General-purpose animation utilities used across onboarding and quiz flows.
//  Welcome-screen-specific choreography (convergence, ambient float, mesh gradient)
//  was removed as part of the single-screen onboarding redesign.
//

import SwiftUI

// MARK: - Onboarding Spring Tokens

extension FormaAnimation {
    /// Entrance spring -- used for elements appearing on screen
    static let onboardingEntrance: Animation = .spring(response: 0.55, dampingFraction: 0.78, blendDuration: 0.1)

    /// Settle spring -- used for elements landing in final position
    static let onboardingSettle: Animation = .spring(response: 0.45, dampingFraction: 0.82)

    /// Bounce spring -- used for celebratory/impact moments
    static let onboardingBounce: Animation = .spring(response: 0.35, dampingFraction: 0.65)

    /// Compute a staggered delay for cascading animations
    static func staggerDelay(index: Int, base: Double = 0.08, offset: Double = 0) -> Double {
        offset + Double(index) * base
    }
}

// MARK: - Gradient Shimmer Sweep

/// One-time shimmer sweep effect for buttons and cards.
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
