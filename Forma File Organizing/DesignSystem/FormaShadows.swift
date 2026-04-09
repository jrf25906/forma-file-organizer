//
//  FormaShadows.swift
//  Forma - Shadow Elevation Tokens
//
//  Consistent shadow levels for depth hierarchy.
//  Dark mode applies 2x radius, 1.5x offset intensification.
//

import SwiftUI

/// Shadow definition with all parameters needed for SwiftUI `.shadow()`.
struct FormaShadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    /// Returns an intensified version for dark mode (2x radius, 1.5x offset).
    var darkMode: FormaShadow {
        FormaShadow(
            color: color.opacity(0.6),
            radius: radius * 2,
            x: x,
            y: y * 1.5
        )
    }
}

// MARK: - Elevation Scale

extension FormaShadow {
    /// No shadow
    static let none = FormaShadow(color: .clear, radius: 0, x: 0, y: 0)

    /// Resting cards and surfaces — subtle depth
    static let resting = FormaShadow(
        color: Color.formaObsidian.opacity(Color.FormaOpacity.light),
        radius: 4, x: 0, y: 2
    )

    /// Selected cards, active controls — enhanced elevation
    static let raised = FormaShadow(
        color: Color.formaSteelBlue.opacity(Color.FormaOpacity.medium),
        radius: 8, x: 0, y: 3
    )

    /// Floating elements, popovers, action bars
    static let floating = FormaShadow(
        color: Color.formaObsidian.opacity(Color.FormaOpacity.medium),
        radius: 16, x: 0, y: 4
    )

    /// Overlay panels, modals, dropdowns
    static let overlay = FormaShadow(
        color: Color.formaObsidian.opacity(Color.FormaOpacity.strong),
        radius: 24, x: 0, y: 8
    )
}

// MARK: - View Modifier

private struct FormaShadowModifier: ViewModifier {
    let shadow: FormaShadow
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let resolved = colorScheme == .dark ? shadow.darkMode : shadow
        return content.shadow(
            color: resolved.color,
            radius: resolved.radius,
            x: resolved.x,
            y: resolved.y
        )
    }
}

extension View {
    /// Apply a Forma shadow that automatically adapts to dark mode.
    func formaShadow(_ shadow: FormaShadow) -> some View {
        modifier(FormaShadowModifier(shadow: shadow))
    }
}
