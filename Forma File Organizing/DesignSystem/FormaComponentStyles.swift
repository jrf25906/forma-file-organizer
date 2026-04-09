//
//  FormaComponentStyles.swift
//  Forma - Component-Level Composite Tokens
//
//  ViewModifiers that compose primitive tokens for high-frequency UI patterns.
//  All composites implement craft guidelines: two-layer borders, state completeness, physical depth.
//

import SwiftUI

// MARK: - Card Style

enum FormaCardVariant {
    case `default`
    case selected
    case interactive
}

struct FormaCardStyleModifier: ViewModifier {
    let variant: FormaCardVariant
    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .formaCardPadding()
            .background(background)
            .formaCornerRadius(FormaRadius.card)
            .formaBorder(
                cornerRadius: FormaRadius.card,
                style: borderStyle,
                innerEdge: true
            )
            .formaShadow(shadowLevel)
            .onHover { hovering in
                if variant == .interactive {
                    isHovered = hovering
                }
            }
    }

    private var background: Color {
        switch variant {
        case .selected:
            return Color.formaSteelBlue.opacity(Color.FormaOpacity.light)
        case .interactive where isHovered:
            return Color.formaControlBackground.opacity(0.9)
        default:
            return Color.formaControlBackground
        }
    }

    private var borderStyle: FormaBorderStyle {
        switch variant {
        case .selected: return .selected
        case .interactive where isHovered: return .hover
        default: return .outer
        }
    }

    private var shadowLevel: FormaShadow {
        switch variant {
        case .selected: return .raised
        case .interactive where isHovered: return .raised
        default: return .resting
        }
    }
}

extension View {
    func formaCardStyle(_ variant: FormaCardVariant = .default) -> some View {
        modifier(FormaCardStyleModifier(variant: variant))
    }
}

// MARK: - Sidebar Row Style

struct FormaSidebarRowStyleModifier: ViewModifier {
    let isSelected: Bool
    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, FormaSpacing.tight)
            .padding(.vertical, FormaSpacing.micro + 2)
            .background(
                RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                    .fill(rowFill)
            )
            .foregroundColor(isSelected ? .formaLabel : .formaSecondaryLabel)
            .onHover { isHovered = $0 }
    }

    private var rowFill: Color {
        if isSelected {
            return Color.formaSteelBlue.opacity(Color.FormaOpacity.light)
        } else if isHovered {
            return Color.formaObsidian.opacity(Color.FormaOpacity.subtle)
        }
        return Color.clear
    }
}

extension View {
    func formaSidebarRowStyle(isSelected: Bool) -> some View {
        modifier(FormaSidebarRowStyleModifier(isSelected: isSelected))
    }
}

// MARK: - Input Style

struct FormaInputStyleModifier: ViewModifier {
    let hasError: Bool
    let isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(FormaSpacing.standard - FormaSpacing.micro)
            .background(Color.formaCardBackground)
            .formaCornerRadius(FormaRadius.control)
            .overlay(
                RoundedRectangle(cornerRadius: FormaRadius.control, style: .continuous)
                    .strokeBorder(
                        hasError
                            ? Color.formaError
                            : (isFocused ? Color.formaSteelBlue : Color.formaSeparator.opacity(Color.FormaOpacity.strong)),
                        lineWidth: hasError || isFocused ? FormaBorderWidth.medium : FormaBorderWidth.thin
                    )
            )
            .formaFocusRing(isFocused: isFocused, cornerRadius: FormaRadius.control)
    }
}

extension View {
    func formaInputStyle(hasError: Bool = false, isFocused: Bool = false) -> some View {
        modifier(FormaInputStyleModifier(hasError: hasError, isFocused: isFocused))
    }
}
