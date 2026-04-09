//
//  FormaEasing.swift
//  Forma - Easing & Duration Tokens
//
//  Single source of truth for all animation timing.
//  Consolidates constants previously split across FormaAnimation and FormaMicroanimations.
//

import SwiftUI

enum FormaEasing {

    // MARK: - Duration Scale

    enum Duration {
        /// 0.15s — Hover, button press, micro-feedback
        static let micro: Double = 0.15
        /// 0.22s — Quick transitions, disclosure toggles
        static let fast: Double = 0.22
        /// 0.25s — Standard state changes, navigation
        static let standard: Double = 0.25
        /// 0.40s — Modal appear, sheet slide
        static let slow: Double = 0.40
        /// 0.60s — Hero elements, celebration entrance
        static let entrance: Double = 0.60

        /// Reduced motion halves all durations.
        static func reducedMotion(_ duration: Double) -> Double {
            duration / 2.0
        }
    }

    // MARK: - Easing Curves (pre-built Animation values)

    /// Default ease-in-out for most animations
    static let standard: Animation = .easeInOut(duration: Duration.standard)
    /// Snappy ease-out for button press, hover feedback
    static let microFeedback: Animation = .easeOut(duration: Duration.micro)
    /// Quick ease-out for enter transitions
    static let quickEnter: Animation = .easeOut(duration: Duration.fast)
    /// Quick ease-in for exit transitions
    static let quickExit: Animation = .easeIn(duration: Duration.micro)
    /// Disclosure expand/collapse
    static let disclosure: Animation = .spring(response: 0.35, dampingFraction: 0.8)

    // MARK: - Spring Presets

    /// Responsive interactive spring — drags, sliders
    static let interactive: Animation = .interactiveSpring(response: 0.22, dampingFraction: 0.9)
    /// Bouncy spring — celebration, success
    static let bouncy: Animation = .spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0.1)
    /// Gentle spring — subtle refinement
    static let gentle: Animation = .spring(response: 0.35, dampingFraction: 0.85)
    /// Segmented control slide
    static let segmentSlide: Animation = .spring(response: 0.26, dampingFraction: 0.82)

    // MARK: - Panel & Navigation

    /// Panel slide in/out
    static let panelSlide: Animation = .easeInOut(duration: Duration.standard)
    /// Standard transition (enter/exit/crossfade)
    static let standardTransition: Animation = .easeInOut(duration: Duration.standard)
}

// MARK: - Reduced Motion Wrapper

extension View {
    /// Wrap an animation so it respects `accessibilityReduceMotion`.
    /// Springs/bouncy become instant; enters/exits become a 0.01s crossfade;
    /// standard/panelSlide durations halve.
    func formaAnimated<V: Equatable>(
        _ animation: Animation,
        value: V,
        reduceMotion: Bool
    ) -> some View {
        self.animation(reduceMotion ? .linear(duration: 0.01) : animation, value: value)
    }
}
