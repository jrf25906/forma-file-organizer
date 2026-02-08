//
//  FormaShaderEffects.swift
//  Forma - Metal Shader Effect Wrappers
//
//  ShaderLibrary wrappers, ViewModifiers, and View extensions
//  for organic texture effects (gradient drift, frosted grain).
//

import SwiftUI

// MARK: - Gradient Drift Modifier

/// Applies a slow-moving hue/brightness drift using Metal shaders.
/// 15fps cap via TimelineView for decorative performance. Respects accessibility settings.
struct FormaGradientDriftModifier: ViewModifier {
    let isAnimating: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceMotion || reduceTransparency || !isAnimating {
            content
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { timeline in
                let elapsed = Float(timeline.date.timeIntervalSinceReferenceDate)
                content
                    .visualEffect { view, proxy in
                        view.colorEffect(
                            ShaderLibrary.gradientDrift(
                                .float2(Float(proxy.size.width), Float(proxy.size.height)),
                                .float(elapsed),
                                .float(1.0)
                            )
                        )
                    }
            }
        }
    }
}

// MARK: - Frosted Texture Modifier

/// Overlays a subtle three-octave grain texture on the view.
/// Static (no animation). Respects Reduce Transparency.
struct FormaFrostedTextureModifier: ViewModifier {
    let intensity: Float

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
        } else {
            content.overlay {
                Color.clear
                    .visualEffect { view, proxy in
                        view.colorEffect(
                            ShaderLibrary.frostedTexture(
                                .float2(Float(proxy.size.width), Float(proxy.size.height)),
                                .float(intensity)
                            )
                        )
                    }
                    .opacity(0.6)
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Apply a slow-moving color drift effect to the view.
    /// Only animates when `isAnimating` is true. Disabled for accessibility.
    func formaGradientDrift(isAnimating: Bool) -> some View {
        modifier(FormaGradientDriftModifier(isAnimating: isAnimating))
    }

    /// Apply a subtle frosted grain texture over the view.
    /// Static effect, no animation. Disabled for Reduce Transparency.
    func formaFrostedTexture(intensity: Float = 1.0) -> some View {
        modifier(FormaFrostedTextureModifier(intensity: intensity))
    }
}
