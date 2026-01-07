//
//  LiquidGlassComponents.swift
//  Forma - Liquid Glass UI Components
//
//  Implementation of Apple's Liquid Glass material for interactive overlays
//  Requires macOS 26.0+
//

import SwiftUI

// MARK: - Liquid Glass Bubble

/// A reusable liquid glass bubble component that can morph between states
/// Use for selection indicators, highlights, and interactive overlays
struct LiquidGlassBubble: View {
    let tintColor: Color
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    init(tintColor: Color = .formaSteelBlue.opacity(Color.FormaOpacity.overlay), cornerRadius: CGFloat = FormaRadius.card) {
        self.tintColor = tintColor
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        if #available(macOS 26.0, *) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .glassEffect(.regular.tint(tintColor))
        } else {
            // Fallback for older macOS versions
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(tintColor)
                .background(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.formaBoneWhite.opacity(Color.FormaOpacity.medium), lineWidth: 1)
                )
        }
    }
}

// MARK: - Morphing Glass Container

// MARK: - Glass Capsule Indicator

/// A morphing capsule indicator for tab-style navigation
/// Similar to iOS segmented control but with liquid glass
struct GlassCapsuleIndicator: View {
    let tintColor: Color
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    init(tintColor: Color = .formaSteelBlue.opacity(Color.FormaOpacity.overlay)) {
        self.tintColor = tintColor
    }
    
    var body: some View {
        if #available(macOS 26.0, *) {
            Capsule()
                .glassEffect(.regular.tint(tintColor))
        } else {
            Capsule()
                .fill(tintColor)
                .background(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.formaBoneWhite.opacity(Color.FormaOpacity.medium), lineWidth: 1)
                )
        }
    }
}

// MARK: - Glass Effect Modifiers

extension View {
    /// Apply liquid glass effect with Forma brand colors
    /// Automatically falls back to material effect on older macOS versions
    func formaGlassEffect(tint: Color = .formaSteelBlue.opacity(Color.FormaOpacity.overlay)) -> some View {
        if #available(macOS 26.0, *) {
            return AnyView(self.glassEffect(.regular.tint(tint)))
        } else {
            return AnyView(
                self
                    .background(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: FormaRadius.card, style: .continuous)
                            .stroke(Color.formaBoneWhite.opacity(Color.FormaOpacity.medium), lineWidth: 1)
                    )
            )
        }
    }
    
    /// Apply morphing glass effect with ID for smooth transitions
    @available(macOS 26.0, *)
    func formaMorphingGlass<ID: Hashable & Sendable>(
        id: ID,
        in namespace: Namespace.ID,
        tint: Color = .formaSteelBlue.opacity(Color.FormaOpacity.overlay)
    ) -> some View {
        self
            .glassEffect(.regular.tint(tint))
            .glassEffectID(id, in: namespace)
    }
}

// MARK: - Glass Button Background

/// A glass capsule/rounded background for buttons and interactive elements.
/// Uses NSVisualEffectView with .withinWindow blending for proper material rendering.
/// IMPORTANT: When using this as a .background(), apply .foregroundColor() BEFORE .background()
/// to ensure the VisualEffectView blends correctly with the window's layer tree.
struct GlassButtonBackground: View {
    let tint: Color?
    let cornerRadius: CGFloat

    init(tint: Color? = nil, cornerRadius: CGFloat = FormaRadius.pill) {
        self.tint = tint
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26.0, *) {
            shape
                .glassEffect(tint == nil ? .regular : .regular.tint(tint!.opacity(Color.FormaOpacity.overlay)))
                .overlay(shape.stroke(Color.formaBoneWhite.opacity(Color.FormaOpacity.medium), lineWidth: 1))
        } else {
            ZStack {
                VisualEffectView(material: .popover, blendingMode: .withinWindow)
                    .clipShape(shape)

                if let tint {
                    shape.fill(tint.opacity(Color.FormaOpacity.overlay))
                } else {
                    shape.fill(Color.formaBoneWhite.opacity(Color.FormaOpacity.subtle))
                }

                LinearGradient(
                    colors: [
                        Color.formaBoneWhite.opacity(Color.FormaOpacity.medium),
                        Color.formaBoneWhite.opacity(Color.FormaOpacity.subtle),
                        Color.formaBoneWhite.opacity(0),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(shape)

                shape.stroke(Color.formaBoneWhite.opacity(Color.FormaOpacity.medium), lineWidth: 1)
            }
        }
    }
}

// MARK: - Accessibility Helpers

/// Check if liquid glass effects should be used based on OS version and accessibility
var shouldUseLiquidGlass: Bool {
    if #available(macOS 26.0, *) {
        return true
    }
    return false
}

// MARK: - Preview

#Preview("Liquid Glass Bubble") {
    VStack(spacing: FormaSpacing.generous - FormaSpacing.micro) {
        HStack(spacing: FormaSpacing.standard - FormaSpacing.micro) {
            Text("Home")
                .padding(.horizontal, FormaSpacing.standard)
                .padding(.vertical, FormaSpacing.tight)
                .background(LiquidGlassBubble())
            
            Text("Desktop")
                .padding(.horizontal, FormaSpacing.standard)
                .padding(.vertical, FormaSpacing.tight)
                .foregroundColor(.secondary)
        }
        
        HStack(spacing: FormaSpacing.micro) {
            Text("All")
                .padding(.horizontal, FormaSpacing.standard)
                .padding(.vertical, FormaSpacing.tight)
                .background(
                    GlassCapsuleIndicator()
                )
            
            Text("Recent")
                .padding(.horizontal, FormaSpacing.standard)
                .padding(.vertical, FormaSpacing.tight)
                .foregroundColor(.secondary)
            
            Text("Flagged")
                .padding(.horizontal, FormaSpacing.standard)
                .padding(.vertical, FormaSpacing.tight)
                .foregroundColor(.secondary)
        }
    }
    .formaPadding()
    .frame(width: 400, height: 300)
    .background(Color.formaControlBackground.opacity(Color.FormaOpacity.medium))
}
