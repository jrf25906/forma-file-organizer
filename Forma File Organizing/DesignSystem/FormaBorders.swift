//
//  FormaBorders.swift
//  Forma - Border Tokens
//
//  Two-layer border system: outer edge defines shape, inner light edge adds physical depth.
//  Dark mode flips polarity: light inner edges become subtle dark edges.
//

import SwiftUI

// MARK: - Border Width Scale

enum FormaBorderWidth {
    /// 0.5pt — Inner light edges, ultra-subtle separators
    static let hairline: CGFloat = 0.5
    /// 1.0pt — Standard borders, control outlines
    static let thin: CGFloat = 1.0
    /// 1.5pt — Selected/active state borders
    static let medium: CGFloat = 1.5
    /// 2.0pt — Focused/emphasized borders
    static let thick: CGFloat = 2.0
}

// MARK: - Border Styles

struct FormaBorderStyle {
    let width: CGFloat
    let lightColor: Color
    let darkColor: Color

    func color(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkColor : lightColor
    }
}

extension FormaBorderStyle {
    /// Outer shape border — defines the component boundary
    static let outer = FormaBorderStyle(
        width: FormaBorderWidth.hairline,
        lightColor: Color.formaObsidian.opacity(Color.FormaOpacity.subtle),
        darkColor: Color.white.opacity(0.14)  // matches fileSurfaceBorder dark value
    )

    /// Inner light edge — adds physical depth (the "craft" detail)
    /// In dark mode this flips to a subtle dark inner edge
    static let innerLightEdge = FormaBorderStyle(
        width: FormaBorderWidth.hairline,
        lightColor: Color.white.opacity(0.7),
        darkColor: Color.white.opacity(0.06)
    )

    /// Selected state border
    static let selected = FormaBorderStyle(
        width: FormaBorderWidth.medium,
        lightColor: Color.formaSteelBlue,
        darkColor: Color.formaSteelBlue.opacity(0.58)  // matches selectedBorder dark value
    )

    /// Hover state border
    static let hover = FormaBorderStyle(
        width: FormaBorderWidth.thin,
        lightColor: Color.formaObsidian.opacity(Color.FormaOpacity.light),
        darkColor: Color.white.opacity(0.22)  // matches hoverBorder dark value
    )

    /// Error state border
    static let error = FormaBorderStyle(
        width: FormaBorderWidth.medium,
        lightColor: Color.formaError,
        darkColor: Color.formaError.opacity(0.8)
    )
}

// MARK: - Two-Layer Border Modifier

struct FormaTwoLayerBorder: ViewModifier {
    let cornerRadius: CGFloat
    let outerStyle: FormaBorderStyle
    let showInnerEdge: Bool
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(outerStyle.color(for: colorScheme), lineWidth: outerStyle.width)
            )
            .overlay(
                Group {
                    if showInnerEdge {
                        RoundedRectangle(cornerRadius: max(0, cornerRadius - outerStyle.width), style: .continuous)
                            .strokeBorder(
                                FormaBorderStyle.innerLightEdge.color(for: colorScheme),
                                lineWidth: FormaBorderWidth.hairline
                            )
                            .padding(outerStyle.width)
                    }
                }
            )
    }
}

extension View {
    /// Apply the two-layer border system (outer shape + inner light edge).
    func formaBorder(
        cornerRadius: CGFloat = FormaRadius.card,
        style: FormaBorderStyle = .outer,
        innerEdge: Bool = true
    ) -> some View {
        modifier(FormaTwoLayerBorder(
            cornerRadius: cornerRadius,
            outerStyle: style,
            showInnerEdge: innerEdge
        ))
    }
}
